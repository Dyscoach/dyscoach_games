class_name GameConfig
extends RefCounted
## Chargement et validation du JSON de configuration.
## Une configuration invalide ne plante jamais le jeu : validity=false + liste d'erreurs,
## l'écran d'erreur calme est affiché par le jeu et un événement "error" est envoyé.
## Le jeu ne modifie jamais une valeur de la configuration ; les champs inconnus sont ignorés.

const AGE_BANDS := ["6-8", "9-11", "12-14", "15-16"]
const INPUTS := ["tap", "drag", "tap_tap"]
const VALIDATIONS := ["per_item", "at_end"]

var validity: bool = false
var errors: Array[String] = []
var raw: Dictionary = {}

# champs communs obligatoires
var schema_version: int = 0
var session_id: String = ""
var game_id: String = ""
var locale: String = "fr-FR"
var age_band: String = "9-11"
var display_name: String = ""          # transmis par la plateforme, jamais journalisé
var items: Array = []
var interaction_input: String = "tap_tap"
var interaction_validation: String = "per_item"
var difficulty_level: int = 1
var hints_enabled: bool = true
var max_active_minutes: float = Tuning.MAX_ACTIVE_MINUTES_DEFAULT
var soft_end_minutes: float = Tuning.SOFT_END_MINUTES_DEFAULT

func _init(data: Dictionary = {}) -> void:
	if not data.is_empty():
		parse(data)

func parse(data: Dictionary) -> void:
	raw = data
	errors.clear()
	schema_version = int(data.get("schema_version", 0))
	session_id = str(data.get("session_id", ""))
	game_id = str(data.get("game_id", ""))
	locale = str(data.get("locale", "fr-FR"))
	age_band = str(data.get("age_band", ""))
	display_name = str(data.get("display_name", ""))
	var interaction: Dictionary = data.get("interaction", {})
	interaction_input = str(interaction.get("input", "tap_tap"))
	interaction_validation = str(interaction.get("validation", "per_item"))
	var difficulty: Dictionary = data.get("difficulty", {})
	difficulty_level = int(difficulty.get("level", 1))
	hints_enabled = bool(difficulty.get("hints", true))
	var limits: Dictionary = data.get("session_limits", {})
	max_active_minutes = float(limits.get("max_active_minutes", Tuning.MAX_ACTIVE_MINUTES_DEFAULT))
	max_active_minutes = minf(max_active_minutes, Tuning.MAX_ACTIVE_MINUTES_CEILING)
	soft_end_minutes = float(limits.get("soft_end_at_minutes", minf(Tuning.SOFT_END_MINUTES_DEFAULT, max_active_minutes - 1)))
	items = data.get("items", [])

	_validate()

func _validate() -> void:
	if schema_version != 1:
		errors.append("schema_version doit valoir 1 (reçu : %s)" % str(schema_version))
	if session_id.is_empty():
		errors.append("session_id manquant")
	if game_id.is_empty():
		errors.append("game_id manquant")
	if not AGE_BANDS.has(age_band):
		errors.append("age_band invalide (reçu : %s)" % age_band)
	if not INPUTS.has(interaction_input):
		errors.append("interaction.input invalide (reçu : %s)" % interaction_input)
	if not VALIDATIONS.has(interaction_validation):
		errors.append("interaction.validation invalide (reçu : %s)" % interaction_validation)
	if max_active_minutes <= 0:
		errors.append("session_limits.max_active_minutes doit être positif")
	if items.is_empty() and game_id != "sonimaux":
		# l'aventure Sonimaux ne porte pas d'items racine : chaque zone a sa propre game_config
		errors.append("items manquants ou vides")
	if items is Array:
		for i in items.size():
			var item = items[i]
			if typeof(item) != TYPE_DICTIONARY:
				errors.append("items[%d] doit être un objet" % i)
			elif not item.has("item_id"):
				errors.append("items[%d].item_id manquant" % i)
	validity = errors.is_empty()

## Surcharge par jeu : validation spécifique des items (retourne les erreurs).
func validate_items(game_id_check: String) -> Array[String]:
	var errs: Array[String] = []
	for i in items.size():
		var item: Dictionary = items[i] if typeof(items[i]) == TYPE_DICTIONARY else {}
		errs.append_array(_validate_item(item, game_id_check, i))
	return errs

func _validate_item(_item: Dictionary, _gid: String, _idx: int) -> Array[String]:
	return []  # surchargé par les jeux via des helpers statiques dédiés

# --- accès aux items ---

func item_count() -> int:
	return items.size()

func item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	return items[index]

# --- validations statiques par jeu (appelées avant instanciation) ---

static func validate_forge_items(items: Array) -> Array[String]:
	var errs: Array[String] = []
	for i in items.size():
		var item: Dictionary = items[i] if typeof(items[i]) == TYPE_DICTIONARY else {}
		var itype := str(item.get("item_type", "word"))
		if item.get("item_id", "").is_empty():
			errs.append("items[%d].item_id manquant" % i)
		match itype:
			"word":
				var graphemes: Array = item.get("graphemes", [])
				if graphemes.size() < 2:
					errs.append("items[%d] : un mot doit avoir au moins 2 tuiles" % i)
				if str(item.get("word", "")).is_empty():
					errs.append("items[%d].word manquant" % i)
			"homophone":
				var choices: Array = item.get("choices", [])
				if choices.size() < 2:
					errs.append("items[%d] : homophone doit proposer au moins 2 choix" % i)
				if str(item.get("answer", "")).is_empty():
					errs.append("items[%d].answer manquant" % i)
				if str(item.get("sentence_before", "")).is_empty():
					errs.append("items[%d].sentence_before manquant" % i)
			"sentence":
				var words: Array = item.get("words", [])
				if words.size() < 2:
					errs.append("items[%d] : phrase doit avoir au moins 2 mots" % i)
			_:
				errs.append("items[%d] : item_type inconnu (%s)" % [i, itype])
	return errs

static func validate_chasse_config(config: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var target: Dictionary = config.get("target", {})
	if target.is_empty() or str(target.get("phoneme_id", "")).is_empty():
		errs.append("target.phoneme_id manquant")
	if str(target.get("audio_phoneme", "")).is_empty():
		errs.append("target.audio_phoneme manquant (le son isolé doit être un fichier fourni)")
	var items: Array = config.get("items", [])
	var targets := 0
	for i in items.size():
		var item: Dictionary = items[i] if typeof(items[i]) == TYPE_DICTIONARY else {}
		if str(item.get("word", "")).is_empty():
			errs.append("items[%d].word manquant" % i)
		if item.get("has_target", false):
			targets += 1
		if not ["start", "middle", "end"].has(str(item.get("position", ""))):
			errs.append("items[%d].position invalide" % i)
	if targets < 2:
		errs.append("moins de 2 éléments cibles dans la manche")
	return errs

static func validate_duo_items(items: Array) -> Array[String]:
	var errs: Array[String] = []
	for i in items.size():
		var item: Dictionary = items[i] if typeof(items[i]) == TYPE_DICTIONARY else {}
		if str(item.get("pair_id", "")).is_empty():
			errs.append("items[%d].pair_id manquant" % i)
		var cards: Array = item.get("cards", [])
		if cards.size() < 2 or cards.size() > 3:
			errs.append("items[%d] : 2 ou 3 cartes attendues" % i)
		var ti := int(item.get("target_index", -1))
		if ti < 0 or ti >= cards.size():
			errs.append("items[%d].target_index hors limites" % i)
	return errs

static func validate_syllabo_items(items: Array) -> Array[String]:
	var errs: Array[String] = []
	for i in items.size():
		var item: Dictionary = items[i] if typeof(items[i]) == TYPE_DICTIONARY else {}
		var syllables: Array = item.get("syllables", [])
		if syllables.is_empty():
			errs.append("items[%d].syllables manquant (découpage fourni par la plateforme, jamais calculé)" % i)
		var sc := int(item.get("syllable_count", 0))
		if sc != syllables.size():
			errs.append("items[%d] : syllable_count != syllables.size()" % i)
		if sc < 1:
			errs.append("items[%d] : au moins 1 syllabe" % i)
	return errs

static func validate_memo_items(items: Array) -> Array[String]:
	var errs: Array[String] = []
	var pair_counts := {}
	for i in items.size():
		var item: Dictionary = items[i] if typeof(items[i]) == TYPE_DICTIONARY else {}
		var pid := str(item.get("pair_id", ""))
		if pid.is_empty():
			errs.append("items[%d].pair_id manquant" % i)
		pair_counts[pid] = int(pair_counts.get(pid, 0)) + 1
		var ka: Dictionary = item.get("card_a", {})
		var kb: Dictionary = item.get("card_b", {})
		if ka.is_empty() or kb.is_empty():
			errs.append("items[%d] : card_a et card_b obligatoires" % i)
	for pid in pair_counts:
		if pair_counts[pid] != 1:
			errs.append("pair_id %s : chaque item doit porter une paire card_a/card_b unique" % pid)
	return errs

static func validate_radar_items(items: Array) -> Array[String]:
	var errs: Array[String] = []
	for i in items.size():
		var item: Dictionary = items[i] if typeof(items[i]) == TYPE_DICTIONARY else {}
		var grid: Array = item.get("grid", [])
		if grid.is_empty():
			errs.append("items[%d].grid manquant (grille fournie, ordre fixe)" % i)
		var tc := int(item.get("target_count", 0))
		if tc <= 0:
			errs.append("items[%d].target_count invalide" % i)
		var found := 0
		var target := str(item.get("target", ""))
		if target.is_empty():
			errs.append("items[%d].target manquant" % i)
		for g in grid:
			if str(g) == target:
				found += 1
		if found != tc:
			errs.append("items[%d] : %d cibles dans la grille, target_count=%d" % [i, found, tc])
	return errs

static func validate_sonimaux_config(config: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var story: Dictionary = config.get("story", {})
	if story.is_empty():
		errs.append("story manquant")
		return errs
	if not bool(story.get("safety_checked", false)):
		errs.append("story.safety_checked est faux : l'épisode est refusé")
	for line in story.get("intro_lines", []):
		if typeof(line) == TYPE_DICTIONARY and str(line.get("audio", "")).is_empty():
			errs.append("chaque ligne d'histoire doit avoir son audio")
	return errs
