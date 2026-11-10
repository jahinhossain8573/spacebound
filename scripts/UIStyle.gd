extends RefCounted

const WHITE := Color("ffffff")
const BLACK := Color("000000")
const ORANGE := Color("ff8811")
const BLUE := Color("279af1")
const PANEL := Color("101214")
const MUTED := Color("a5abb2")

static func box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(12)
	return style
