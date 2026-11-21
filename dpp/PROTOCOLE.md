# Protocole DysCoach Play (DPP) — contrat d'interface hôte ⇄ jeu

## 1. Le problème

Le guide de conception impose que les jeux et la plateforme dyscoach.com puissent évoluer
**indépendamment** : un jeu est développé dans Godot par une équipe, la plateforme en
Next.js par une autre, sans jamais se recompiler l'un contre l'autre. Le seul point de
contact est le couple iframe + postMessage. Pour que ce point de contact soit stable, il
doit être **contractualisé** : un schéma versionné, testé des deux côtés, avec des
implémentations de référence. C'est exactement le rôle du répertoire `dpp/` de ce dépôt.

## 2. Principe : le contrat comme source de vérité, pas le code

Le protocole vit dans **ce dépôt**, versionné avec les jeux :

```
dpp/
├── protocol.json          ← schéma machine de tous les messages (source de vérité)
├── PROTOCOLE.md           ← spécification lisible (ce que vous lisez)
├── host/                  ← implémentation de référence côté hôte (JS, ~200 lignes)
│   └── dyscoach-host.js
└── game/                  ← implémentation de référence côté jeu (déjà dans core/bridge.gd)
```

Règles d'indépendance :
1. **Le schéma est le contrat.** Tout changement de `protocol.json` incrémente
   `protocol_version` (semver : nouveau message = minor, champ retiré/renommé = major).
2. **Compatibilité par tolérance**, pas par synchronisation : un jeu ignore tout message
   de type inconnu et tout champ inconnu (déjà implémenté dans `GameConfig.parse` et
   `Bridge._handle_message`). Une plateforme peut donc parler DPP 1.1 à un jeu 1.0.
3. **Chaque partie teste l'autre via le contrat**, jamais via son propre code : les tests
   `tests/test_core.gd` rejouent des messages du schéma, et la page `tools/host_test.html`
   est une implémentation hôte réelle utilisable par l'équipe plateforme comme bac à sable.

## 3. Schéma des messages (protocol.json, version 1.2)

### 3.1 Enveloppe commune

```json
{ "type": "string", "protocol": 1 }
```

Tous les messages jeu → hôte portent aussi `seq` (entier strictement croissant) et
`t_ms` (temps relatif en ms depuis le démarrage du jeu). Aucune donnée personnelle dans
aucun message (ni prénom, ni texte libre) — le prénom éventuel voyage dans `config`.

### 3.2 Hôte → jeu

| type | payload | remarques |
|---|---|---|
| `config` | configuration complète de la partie (voir §4) | envoyé à la réception de `ready` ; rejouable pour redémarrer |
| `pause` / `resume` | — | gel du compteur de temps actif |
| `audio_ended` | `{ "id": "a12" }` | accusé de lecture ; débloque le timeout du jeu |
| `stop` | — | fin immédiate propre → le jeu répond `session_end{reason:"stopped"}` |
| `config_error` | `{ "code": "config_provider_failed\|config_invalid_host_side", "retry": true }` | **v1.1** la plateforme n'a pas pu produire la config ; le jeu affiche l'écran d'erreur calme, `Réessayer` réémet `ready` |

### 3.3 Jeu → hôte

| type | payload | remarques |
|---|---|---|
| `ready` | `{ "version": "1.0.0", "protocol": 1 }` | porteur vide ; peut partir sans restriction d'origine (démarrage en iframe sandboxée) |
| `play_audio` | `{ "id", "url", "kind": "prompt\|word\|feedback" }` | la hôte joue avec un `<audio>` ; déverrouillage mobile de sa responsabilité |
| `stop_audio` | — | coupe tout |
| `event` | `{ "name", "data", "seq", "t_ms" }` | noms réservés listés en §5 ; tout champ inattendu de `data` est refusé côté serveur |
| `session_end` | `{ "reason": "completed\|time_limit\|stopped\|error", "active_ms", "items_done" }` | un seul par session |
| `error` | `{ "code", "message" }` | codes réservés : `audio_missing`, `phoneme_audio_missing`, `image_missing`, `story_unchecked`, `config_invalid`, `config_missing`, `game_unknown`, `origin_rejected` |

### 3.4 Sécurité (invariant, jamais négociable)

- Origine de chaque message entrant vérifiée contre `config/allowed_origins.json` (fixée à
  l'export) ; message d'une autre origine ignoré + compteur `bridge_message_rejected`.
- Envois ciblés sur l'origine hôte apprise ; unique exception : `ready` (porteur vide,
  nécessaire pour amorcer le dialogue depuis une iframe sandboxée).
- Iframe côté hôte : `sandbox="allow-scripts"` au minimum ; jamais `allow-same-origin`
  avec du contenu tiers.
- Aucune évaluation de code construite avec des données reçues.

## 4. Schéma de configuration (`config`)

Champs communs obligatoires : `schema_version`(=1), `session_id`, `game_id`, `locale`,
`age_band` ∈ {6-8, 9-11, 12-14, 15-16}, `session_limits{max_active_minutes ≤ 30,
soft_end_at_minutes}`, `items[]`. Optionnels : `display_name` (jamais journalisé),
`theme{id,skin}`, `interaction{input,validation}`, `a11y{reduce_motion,music,
show_time_digits}`, `difficulty{level,hints}`, `focus`, `collection_state`.

Chaque jeu ajoute ses champs d'items validés par un validateur dédié
(`GameConfig.validate_*_items`). Une configuration invalide **ne plante jamais** :
écran d'erreur calme + `error{code:"config_invalid"}` + proposition « Réessayer ».

## 5. Catalogue des événements (`event.name`)

Communs : `session_started`, `item_presented`, `item_answered`, `item_completed`,
`hint_shown`, `audio_replayed`, `break_started`, `session_ended`.
Sonimaux : `episode_started`, `zone_started`, `zone_completed`, `carnet_opened`,
`episode_ended`, `creature_evolved`.

`item_answered.data` dépend du jeu (detail) : forge = `{expected, chosen, tile_pair,
mode}` ; chasse = `{phoneme_id, has_target, tapped_target, position}` ; duo =
`{pair_id, chosen_word, expected_word, contrast_label}` ; mémo =
`{pair_id, kind, flips_to_match}` ; syllabo = `{expected_count, tapped_count,
auto_validated}` ; radar = `{target, tapped, was_target}`.
Le serveur de la plateforme valide ces schémas et **refuse tout champ inattendu**.

## 6. Cycle de vie garanti

```
hôte                              jeu
 │                                 │
 │◄─────── ready {protocol} ───────┤  (jeu démarré, écoute posée)
 │──── config {payload} ──────────►│  (validation ; erreur calme si invalide)
 │   OU config_error {code,retry} ─│  (v1.1 : échec provider signalé, jamais le silence)
 │◄──── event session_started ─────┤
 │         ... partie ...          │
 │──────── pause / resume ────────►│  (onglet masqué, bouton parent)
 │◄──── play_audio / audio_ended ──┤  (chaque consigne vocale)
 │──────── stop ──────────────────►│  (facultatif)
 │◄──── event session_ended ───────┤
 │◄──── session_end ───────────────┤  (exactement un, avec reason)
 │                                 │
```

Garanties : **chaque `ready` reçoit exactement une réponse — `config` OU
`config_error`, jamais le silence** (v1.1) ; exactement un `session_end` par session ;
`seq` strictement croissant ; le jeu continue sans planter si un audio manque
(`error audio_missing` envoyé) ; le jeu ne stocke rien (sans état) — la plateforme
possède toutes les données.

En iframe hôte, si aucun des deux n'arrive dans les 8 s (`host_config_timeout_ms`),
le jeu affiche lui-même l'écran d'erreur calme (toujours récupérable : `Réessayer`
réémet `ready`). Le repli par fichier dev (`dev/config_*.json`) n'existe qu'en
exécution locale autonome (`window.parent === window`) — jamais en iframe, jamais
en production.

## 7. Comment les deux équipes travaillent indépendamment

1. **L'équipe plateforme** développe son GameFrame contre `dpp/host/dyscoach-host.js`
   (implémentation de référence) et teste ses jeux avec `tools/host_test.html` servi en
   local — aucun Godot requis.
2. **L'équipe jeux** développe contre `tools/host_test.html` aussi (il joue les audios,
   renvoie `audio_ended`, journalise tout) — aucun Next.js requis.
3. **Les deux côtés valident le même `protocol.json`.** Une évolution du protocole =
   un commit du schéma + un bump de version des deux implémentations de référence.
4. Le serveur de la plateforme revalide à l'arrivée : schéma de l'enveloppe, catalogues
   de `event.name` et `error.code`, refus de tout champ inattendu, quota par session
   opaque, plafond quotidien `max_active_minutes` contrôlé **avant** de lancer la partie.

## 8. Extension (déjà prévue par le socle)

- Nouveau jeu = nouveau `game_id` + validateur d'items + entrée dans la table `GAMES`
  de `main/main.gd`. La plateforme n'a rien à changer si elle ne fait que produire la
  configuration du nouveau `game_id`.
- Nouveau champ de config = optionnel → toléré par les jeux anciens (champ ignoré).
- Champ retiré = bump majeur du protocole (les jeux anciens ne peuvent pas être cassés).
- Les dessins/images restent hors contrat : le jeu affiche une carte neutre si
  `image_id` n'a pas de ressource correspondante et signale `error image_missing`.

## 9. Contrat DEF (v1.2.0 — section `def` de protocol.json)

Le **DEF (Dyscoach Exercise Format)** est le scénario pédagogique versionné que
la plateforme génère (déterministe aujourd'hui, modèle IA demain) et dont elle
déduit la `config` DPP envoyée au jeu. Règle fondamentale : **l'IA ne produit
jamais de code Godot, uniquement des données DEF**.

- **Contenu public / corrigé privé séparés** : `answer_key` (item → réponse +
  explication) reste sur le serveur ; le jeu soumet ses réponses à
  `POST /api/game/v1/sessions/{id}/attempts` qui revalide côté plateforme.
- **Projection publique** : config DPP = DEF moins `answer_key`, plus
  session_id/limits/a11y de la session. Tout champ DEF inconnu du jeu est
  ignoré (tolerant_reader).
- **Validé avant service** : toute génération passe le validateur DEF serveur
  (`src/lib/def.ts`) AVANT stockage ; côté moteur, `core/def_validator.gd`
  verrouille les invariants sur la config reçue (aucun champ de corrigé à
  aucune profondeur, mots interdits, prénoms, bornes metadata).
- **Routes de la façade** : `GET /api/game/v1/templates`,
  `POST /exercises/generate`, `GET /exercises/{id}`, `POST /sessions`,
  `POST /sessions/{id}/attempts|events|complete` (auth JWT plateforme).
- **Métadonnées** : matière/niveau/compétence/difficulté (1-5) et adaptations
  (consigne courte, audio, densité visuelle, guidage) — jamais de prénom ni de
  diagnostic médical, uniquement des besoins fonctionnels.
