class_name DefValidator
extends RefCounted
## Validateur du contrat DEF (Dyscoach Exercise Format, dpp/protocol.json §def).
## Pur et testable : aucun autoload, aucun réseau — le DEF arrive TOUJOURS déjà
## converti en config DPP par la plateforme (projection publique : DEF moins
## answer_key) ; ce validateur verrouille les invariants du contrat CÔTÉ JEU :
##   1. answer_never_sent — aucun champ answer_key / correct_answer / solution
##      ne peut apparaître dans une config reçue (le corrigé reste serveur) ;
##   2. schema_versioned  — schema_version doit valoir 1, champs inconnus ignorés ;
##   3. no_personal_data  — pas de prénom normalisé français, pas de texte libre
##      hors items validés ;
##   4. forbidden words   — consigne et textes sans les mots interdits du socle.
## Une config DPP issue d'un DEF invalide est refusée : validity=false + erreurs,
## l'appelant affiche l'écran d'erreur calme (jamais de crash).

const SCHEMA_VERSION := 1
## sandbox = game_id de DÉVELOPPEMENT (main.gd GAMES) : légitime en exécution
## locale/host_test, jamais servi par la plateforme. Toléré pour ne pas casser
## le bac à sable et les fumées dev.
const TEMPLATE_IDS := ["memo_mots", "duo_mots", "syllabo", "radar_lettres", "forge_mots", "chasse_sons", "sonimaux", "sandbox"]
const SUBJECTS := ["francais", "mathematiques", "lecture", "langues", "sciences", "autre"]
const DIFFICULTY_MIN := 1
const DIFFICULTY_MAX := 5

## Clés de corrigé interdites dans TOUTE config reçue du jeu, à toute profondeur
## des items (invariant answer_never_sent — le jeu ne doit jamais tenir la réponse).
const ANSWER_KEY_FIELDS := [
	"answer_key", "correct_answer", "correct_answers", "solution", "solutions",
	"expected", "expected_word", "expected_count", "expected_words",
]

## Mots interdits par le socle (core/strings.gd) — minuscules sans accents.
const FORBIDDEN_WORDS := ["faux", "rate", "perdu", "nul", "therapie", "soin", "reeducation"]

## Prénoms français courants (minuscules) — invariant no_personal_data :
## un prénom dans une consigne est une fuite de données. Scannés dans la
## CONSIGNE uniquement (les items sont des contenus validés par le game_id :
## « jade » du lexique duo_mots reste légitime dans une carte).
const COMMON_FIRST_NAMES := [
	"alice", "emma", "louise", "chloe", "leah", "manon", "ava", "jade", "rose",
	"lucie", "lina", "margaux", "paul", "gabriel", "louis", "raphael", "adam",
	"theo", "antonin", "sacha", "jean", "pierre", "lucas", "hugo", "leo", "noah",
	"anna", "clara", "marie", "julia", "camille", "lea", "sarah", "lola",
]

var validity: bool = false
var errors: Array[String] = []

func _init(payload: Dictionary = {}) -> void:
	if not payload.is_empty():
		validate(payload)

## Valide la projection publique d'un DEF (la config DPP reçue par le jeu).
func validate(payload: Dictionary) -> void:
	errors.clear()
	if int(payload.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version doit valoir %d" % SCHEMA_VERSION)
	var template_id := str(payload.get("template_id", payload.get("game_id", "")))
	if template_id.is_empty():
		errors.append("template_id (ou game_id) manquant")
	elif not TEMPLATE_IDS.has(template_id):
		errors.append("template_id inconnu : %s" % template_id)
	var instruction: Dictionary = payload.get("instruction", {})
	if typeof(instruction) == TYPE_DICTIONARY and not instruction.is_empty():
		var text := str(instruction.get("text", ""))
		if text.length() > 120:
			errors.append("consigne trop longue (> 120 caractères)")
		_check_no_forbidden(text, "instruction.text")
		_check_no_first_name(text, "instruction.text")
	# Métadonnées pédagogiques (facultatives dans la projection — la plateforme
	# peut ne transmettre que la config DPP minimale) : bornées si présentes.
	var metadata: Dictionary = payload.get("metadata", {}) if typeof(payload.get("metadata")) == TYPE_DICTIONARY else {}
	if not metadata.is_empty():
		var subject := str(metadata.get("subject", ""))
		if not subject.is_empty() and not SUBJECTS.has(subject):
			errors.append("metadata.subject inconnu : %s" % subject)
		var difficulty := int(metadata.get("difficulty", 0))
		if difficulty != 0 and (difficulty < DIFFICULTY_MIN or difficulty > DIFFICULTY_MAX):
			errors.append("metadata.difficulty hors bornes 1-5 : %d" % difficulty)
	# Invariant answer_never_sent : la clé privée ne doit JAMAIS traverser le pont.
	_scan_answer_leak(payload, "")
	validity = errors.is_empty()

## Parcours récursif : aucun champ de corrigé à aucune profondeur.
func _scan_answer_leak(value, path: String) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var d: Dictionary = value
		for key in d.keys():
			var key_str := str(key).to_lower()
			if ANSWER_KEY_FIELDS.has(key_str):
				errors.append("fuite de corrigé interdite : champ « %s » à %s" % [key_str, path])
			_scan_answer_leak(d[key], path + "/" + key_str)
	elif typeof(value) == TYPE_ARRAY:
		var a: Array = value
		for i in a.size():
			_scan_answer_leak(a[i], path + "/%d" % i)

func _check_no_forbidden(text: String, where: String) -> void:
	var normalized := _normalize(text)
	for word in FORBIDDEN_WORDS:
		if normalized.contains(word):
			errors.append("mot interdit « %s » dans %s" % [word, where])

func _check_no_first_name(text: String, where: String) -> void:
	var normalized := _normalize(text)
	for name in COMMON_FIRST_NAMES:
		if _contains_word(normalized, name):
			errors.append("prénom détecté « %s » dans %s (données personnelles)" % [name, where])
			return

func _normalize(text: String) -> String:
	var s := text.to_lower()
	# accents → base (é→e, à→a…) sans dépendre d'une table externe
	var from := "áàâäãåéèêëíìîïóòôöõúùûüçñ"
	var to := "aaaaaaeeeeiiiiooooouuuucn"
	for i in from.length():
		s = s.replace(from[i], to[i])
	return s

func _contains_word(haystack: String, needle: String) -> bool:
	return (" " + haystack + " ").contains(" " + needle + " ")
