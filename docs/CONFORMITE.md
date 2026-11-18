# Rapport de conformité — dépôt dyscoach_games

Audit réalisé selon la grille du prompt auditeur (partie B du guide de conception).
Recherches exécutées sur core/, base/, games/, dev/, tools/ (hors .godot et build).

## Résumé

| Règle | Constat | Gravité |
|---|---|---|
| R2 Aucun échec (vies, game over, score négatif, chrono éliminatoire) | 0 occurrence dans les jeux | ✅ conforme |
| R3 Aucun classement ni comparaison | 0 occurrence (leaderboard/rank/best score) | ✅ conforme |
| R4 Aucune récompense aléatoire ni série punitive | `shuffle` utilisé uniquement pour l'ordre d'affichage des tuiles/cartes (jamais pour des récompenses) | ✅ conforme |
| R5 Aucune publicité, achat, lien sortant | 0 occurrence de OS.shell_open ; seules URLs = fichiers audio fournis par la configuration | ✅ conforme |
| R9 Le jeu n'invente aucun mot | tous les textes de jeu proviennent de la configuration ; Strings.gd ne contient que des retours génériques sans mots de vocabulaire ; données d'essai confinées dans dev/ | ✅ conforme |
| R10 Vie privée | 0 FileAccess en écriture, 0 localStorage, 0 cookie ; `display_name` lu mais jamais affiché ni journalisé ; les 2 FileAccess en lecture sont allowed_origins.json et la config dev | ✅ conforme |
| Sécurité du pont | origine de chaque message entrant vérifiée contre allowed_origins.json (testé) ; un seul `postMessage(json, "*")` pour le message `ready` qui ne porte AUCUNE donnée (type+version) — tous les messages avec données ciblent l'origine hôte ; aucune évaluation de code construite avec des données reçues (le seul eval JS est un try/catch statique sur parent.location.origin) | ⚠️ mineur (acceptable, documenté README) |
| Langage | 0 occurrence de « faux », « raté », « perdu », « nul », « thérapie », « soin », « rééducation » dans Strings.gd et les jeux ; retour d'erreur standard = « Presque ! » | ✅ conforme |
| Accessibilité | cibles tactiles centralisées dans Tuning (144 px, 200 px pour 6-8 ans), espacement ≥ 24 px vérifié par test ; OpenDyslexic partout ; reduce_motion testé (aucune particule créée) ; aucun clignotement > 3 Hz (aucune animation clignotante du tout) | ✅ conforme |
| Minuteur | temps actif = visible + interaction ≤ 30 s (testé avec horloge réelle) ; pause hôte gérée ; soft end puis scène de repos ; aucune alarme ni message anxiogène ; jauge sans chiffres (digits seulement si a11y.show_time_digits) | ✅ conforme |
| Audio | toute consigne a un audio OU signale `audio_missing` et continue (testé) ; l'audio du phonème isolé est exigé en Chasse-Sons (refus sinon) | ✅ conforme |

## Constat détaillé du point mineur pont

- `core/bridge.gd:134` : le message `ready` est envoyé avec targetOrigin `"*"` quand l'origine
  hôte est inconnue (démarrage en iframe sandboxée/cross-origin où `parent.location` est
  inaccessible). Contenu : `{"type":"ready","version":"1.0.0"}` — aucune donnée personnelle ni
  pédagogique. Dès que la hôte répond (config), l'origine est apprise et TOUS les messages
  suivants (events, session_end, error, play_audio) sont ciblés. Testé dans Chrome.
- Alternative possible (corrigeable plus tard) : lire `document.referrer` côté hôte ou convenir
  d'une origine fixe passée dans l'URL de l'iframe.

## Ce que l'audit n'a pas pu vérifier

- Safari/iOS et Android réels (aucun appareil mobile disponible) : WebGL2 requis, audio
  déverrouillé au premier geste côté hôte — à recetter en recette avec de vrais enfants.
- Le comportement du minuteur avec un vrai onglet masqué (la logique `visibilitychange` est
  codée et testée en simulation ; le rAF se gèle naturellement en onglet caché, ce qui
  borne aussi le temps actif).
- La recette pédagogique (annexe 2 du guide) : choix des images non ambiguës, qualité des
  audios de phonèmes isolés — dépend d'un orthophoniste et des assets définitifs.

## Corrections à appliquer en premier (aucune bloquante)

1. (mineur) Après intégration réelle à dyscoach.com, verrouiller `ready` sur l'origine de
   production dans allowed_origins.json pour supprimer l'unique `"*"`.
2. (mineur) Brancher les vraies images (`img_{mot}.png`, annexe 1) à la place des cartes neutres.
3. (mineur) Ajouter un test d'export web automatisé (taille du pck + hash) au portail de tests.
