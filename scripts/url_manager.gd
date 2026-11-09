class_name UrlManager
extends RefCounted
## Reads and writes the `?DATA=` parameter, using exactly the same alphabet and
## layout as choochooworld.com so shared links work in both games.

const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
const DEFAULT_TRACK_CODE := "DFFBHFIJB"
const DEFAULT_COLOR_PALETTE_CODE := "0"
const DEFAULT_DAY_CODE := "D"

var track_code := DEFAULT_TRACK_CODE
var color_palette_code := DEFAULT_COLOR_PALETTE_CODE
var day_code := DEFAULT_DAY_CODE


static func encode(codes: Array) -> String:
	var out := ""
	for c in codes:
		var i := int(c)
		if i >= 0 and i < ALPHABET.length():
			out += ALPHABET[i]
	return out


static func decode(code: String) -> Array:
	var out: Array = []
	for i in code.length():
		var v := ALPHABET.find(code[i])
		if v >= 0:
			out.append(v)
	return out


func read_from_url(url: String) -> void:
	var data := ""
	var idx := url.find("DATA=")
	if idx >= 0:
		var rest := url.substr(idx + 5)
		var amp := rest.find("&")
		data = rest if amp < 0 else rest.substr(0, amp)
	data = data.strip_edges()
	if data == "":
		track_code = DEFAULT_TRACK_CODE
		color_palette_code = DEFAULT_COLOR_PALETTE_CODE
		day_code = DEFAULT_DAY_CODE
		return
	var parts := data.split("/", false)
	if parts.size() >= 1 and parts[0] != "":
		track_code = parts[0]
	if parts.size() >= 2 and parts[1] != "":
		color_palette_code = parts[1]
	if parts.size() >= 3 and parts[2] != "":
		day_code = parts[2]


func write_to_url(base_url: String) -> String:
	var sep := "&" if base_url.find("?") >= 0 else "?"
	return "%s%sDATA=%s/%s/%s" % [base_url, sep, track_code, color_palette_code, day_code]


## The piece types described by the shared code.
func decoded_layout() -> Array:
	var out: Array = []
	for code in decode(track_code):
		var t: String = TrackData.CODE_TO_TYPE.get(code, "")
		if t != "":
			out.append(t)
	return out
