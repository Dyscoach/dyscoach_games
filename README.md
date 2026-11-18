# DysCoach Jeux — socle commun

Activités d'entraînement guidé pour enfants porteurs de troubles DYS (6 à 16 ans).
Modules Godot 4.7 sans état, affichés en iframe dans la plateforme dyscoach.com.

**Godot 4.7.2, GDScript 2.0 typé, rendu Compatibility (WebGL 2.0), export web single-thread.**

## Hypothèses (fautes d'information dans le cahier des charges)

1. **Version** : Godot 4.7.2 stable (dernière disponible dans l'environnement).
2. **Audio web** : le jeu ne décode et ne joue AUCUN audio lui-même sur le web (pas de
   AudioStreamMP3 à partir d'URL distantes en export web sans threads) — tout passe par
   `play_audio` vers la page hôte, qui joue avec un élément `<audio>` et renvoie `audio_ended`.
   Hors web (éditeur), AudioService est en mode "local" et ne joue que des bips synthétisés.
3. **Images** : aucune image de mot n'est fournie dans le socle — les jeux affichent des
   cartes neutres avec le mot en grand texte quand `image_id` n'a pas d'équivalent local.
4. **Origine hôte** : en export web, l'origine est déduite de `window.parent.location.origin`
   ; si inaccessible, la première origine de `config/allowed_origins.json` est utilisée.
5. **Polices** : OpenDyslexic Regular/Bold (SIL OFL), reconstruites depuis les WOFF du
   dépôt officiel antijingoist/opendyslexic (voir CREDITS.md).

## Arborescence

```
core/     Bridge, GameConfig, Telemetry, SessionTimer, AudioService, ThemeService, Strings, Tuning
base/     MiniGame (classe de base) + UIKit (boutons, cartes, tuiles, jauge, écrans repos/erreur)
games/    sandbox/ (preuve du socle) + un dossier par jeu
dev/      configs de développement + panneau de debug (touche D ou triple toucher en haut à gauche)
tools/    host_test.html — page hôte de test (config, pause/resume/stop, journal des événements)
tests/    tests automatiques (validation de config, minuteur simulé, séquence, origines)
config/   allowed_origins.json (fixé à l'export)
```

## Les 7 jeux

| Jeu (game_id) | Mécanique | Commit |
|---|---|---|
| Forge-Mots | dictée à tuiles de graphèmes (tap_tap + glisser, per_item/at_end, homophones, phrases) | 9e8df5a |
| Chasse-Sons | discrimination auditive par phonème isolé, éléments flottants, ECAR | 622d67a |
| Duo-Mots | paires minimales, 2-3 cartes de même taille, l'autre cible après erreur | add1f9f |
| Les Sonimaux | aventure 3 actes assemblant les mini-jeux + collection (stades fournis) | 8a95f58 |
| Mémo-Mots | paires mot-image / homophones-phrase, mots à revoir fournis | 73470bb |
| Syllabo | tambour : 1 frappe = 1 wagon, découpage fourni, validation auto 3 s | e08c934 |
| Radar à Lettres | échauffement 2 min, grille fournie en ordre fixe | dd840c8 |

Rapport de conformité (prompt auditeur du guide) : docs/CONFORMITE.md.

## Lancer en mode développement

```bash
godot --path . # éditeur, ou :
godot --path . # scène principale : sandbox d'abord, bascule dès la config reçue
```

Sans configuration reçue en 2 secondes, le jeu charge `res://dev/config_sandbox.json`.

## Page hôte de test

```bash
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server 8090 --directory build/web
# recopier tools/host_test.html et dev/config_*.json dans build/web/
python3 -m http.server 8091 --directory tools  # page hôte (au choix)
# ouvrir http://localhost:8090/host_test.html
```

La page hôte envoie la config au signal `ready`, joue les audios demandés
(`play_audio`) et journalise chaque `event`, `session_end` et `error`.

## Protocole postMessage (résumé)

- Hôte → jeu : `config`, `pause`, `resume`, `audio_ended`, `stop`
- Jeu → hôte : `ready`, `play_audio`, `stop_audio`, `event`, `session_end`, `error`
- Origines autorisées : `config/allowed_origins.json` ; messages d'une autre origine ignorés.
- Les envois ciblent l'origine hôte, jamais `*`. Aucune donnée personnelle dans les événements.

## Ce qui n'a pas été vérifié (limites connues)

- Safari/iPhone non testé (aucun appareil disponible) — WebGL2 requis sans repli.
- Le temps actif dépend de `visibilitychange` (web) : testé en logique simulée, pas en réel onglet masqué.
- Les audios des configs de dev sont des URLs fictives : la page hôte journalise l'échec
  de lecture et renvoie `audio_ended` ; le jeu continue avec le texte affiché (mot en grand).
