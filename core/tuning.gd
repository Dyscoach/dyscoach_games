class_name Tuning
extends RefCounted
## TOUTES les valeurs de réglage du projet sont ici (aucune valeur magique ailleurs).

# --- Cibles tactiles et espacement (accessibilité) ---
const TOUCH_TARGET_MIN := 144.0      # cible tactile minimale générale (px)
const TOUCH_TARGET_CHILD := 200.0    # cible tactile minimale pour la tranche 6-8 ans (px)
const TOUCH_SPACING_MIN := 24.0      # espacement minimal entre deux cibles (px)

# --- Minuteur (temps actif) ---
const IDLE_TIMEOUT_MS := 30000       # sans interaction pendant 30 s, le temps n'est plus actif
const MAX_ACTIVE_MINUTES_DEFAULT := 20
const MAX_ACTIVE_MINUTES_CEILING := 30
const SOFT_END_MINUTES_DEFAULT := 17

# --- Audio ---
const AUDIO_TIMEOUT_MS := 15000      # au-delà, on considère l'audio manquant et on continue
const SFX_VOLUME_DB := -6.0

# --- Aides Forge-Mots ---
const FORGE_GLOW_AFTER_IDLE_MS := 10000   # inaction de 10 s → tuile qui brille
const FORGE_GLOW_AFTER_ERRORS := 2        # 2 erreurs sur la même case → tuile qui brille
const FORGE_SPELL_OUT_AFTER_ERRORS := 3   # 3 erreurs → décomposition sonore + mot à revoir
const FORGE_MAX_REINSERTIONS := 1         # le mot marqué "à revoir" revient au plus 1 fois

# --- Chasse-Sons ---
const CHASSE_DRIFT_AMPLITUDE := 18.0      # dérive très lente des éléments (px)
const CHASSE_DRIFT_PERIOD_S := 6.0        # période de la dérive (s)
const CHASSE_ROUND_TARGETS_CHILD := 2     # cibles par manche pour 6-8 ans
const CHASSE_ROUND_TARGETS := 3           # cibles par manche ensuite
const CHASSE_ELEMENTS_MAX_CHILD := 3      # éléments affichés max pour 6-8 ans
const CHASSE_ELEMENTS_MAX := 6            # éléments affichés max ensuite

# --- Duo-Mots ---
const DUO_COMPARE_SLOW_GAP_MS := 900      # silence entre les deux mots comparés (ms)

# --- Mémo-Mots ---
const MEMO_FLIP_BACK_MS := 1600           # délai avant de retourner deux cartes sans paire
const MEMO_CARDS_LEVEL1 := 4              # nombre de paires par partie, niveau 1
const MEMO_CARDS_LEVEL2 := 6              # nombre de paires par partie, niveau 2

# --- Syllabo ---
const SYLLABO_AUTOVALIDATE_MS := 3000     # validation automatique après 3 s sans toucher
const SYLLABO_AUTOVALIDATE_ENABLED := true

# --- Radar à Lettres ---
const RADAR_SESSION_MAX_MS := 120000      # plafond : 2 minutes d'activité par séance

# --- Sonimaux ---
const SONIMAUX_LINE_MAX_WORDS_CHILD := 12  # longueur max d'une ligne d'histoire (6-8 ans)
const SONIMAUX_LINE_MAX_WORDS := 20        # longueur max d'une ligne d'histoire (9 ans et +)

# --- Pastilles de progression ---
const PROGRESS_DOT_RADIUS := 13.0          # rayon d'une pastille (px)
const PROGRESS_DOT_GAP := 14.0             # espacement entre pastilles (px)

# --- FX et style ---
const UI_CORNER_RADIUS := 28.0
const UI_CORNER_RADIUS_SMALL := 18.0
const FX_SPARKLE_COUNT := 22              # particules d'une gerbe d'étincelles
const FX_SHAKE_ANGLE_DEG := 4.0           # amplitude du tremblement doux (rotation, degrés)
const FX_SUCCESS_PULSE_SCALE := 1.12      # pulsation d'un élément réussi
const FX_APPEAR_STAGGER_S := 0.05         # décalage d'apparition en cascade (s)
const FX_CELEBRATION_MS := 1600           # durée du moment de célébration de fin (ms)
const FONT_SIZE_TITLE := 64
const FONT_SIZE_BODY := 44
const FONT_SIZE_TILE := 72
const FONT_SIZE_TILE_SMALL := 48
const FONT_SIZE_GRID := 96

# --- Paires de graphèmes/lettres considérées « proches » (confusions à signaler) ---
const CONFUSION_PAIRS := [
	["an", "on"], ["in", "ain"], ["o", "au"], ["o", "eau"], ["au", "eau"],
	["b", "d"], ["b", "p"], ["d", "q"], ["p", "q"], ["f", "ph"],
	["s", "ss"], ["c", "ç"], ["g", "j"], ["ou", "u"], ["é", "er"],
]

# --- thèmes visuels d'habillage (Chasse-Sons etc.) : jamais les règles du jeu ---
const SKIN_BUBBLES := "bulles"
const SKIN_EGGS := "oeufs"
