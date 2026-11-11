extends Control

const UI = preload("res://scripts/UIStyle.gd")
var links: Array = []
var extent := Vector2.ZERO

func _draw() -> void:
	# Deep KSP R&D blueprint background
	draw_rect(Rect2(Vector2.ZERO, extent), Color("0a101b"))
	# Minor grid lines (24 px)
	for x in range(0, int(extent.x), 24):
		draw_line(Vector2(x, 0), Vector2(x, extent.y), Color(0.18, 0.28, 0.45, 0.16), 1.0)
	for y in range(0, int(extent.y), 24):
		draw_line(Vector2(0, y), Vector2(extent.x, y), Color(0.18, 0.28, 0.45, 0.16), 1.0)
	# Major grid lines (120 px)
	for x in range(0, int(extent.x), 120):
		draw_line(Vector2(x, 0), Vector2(x, extent.y), Color(0.26, 0.40, 0.62, 0.28), 1.2)
	for y in range(0, int(extent.y), 120):
		draw_line(Vector2(0, y), Vector2(extent.x, y), Color(0.26, 0.40, 0.62, 0.28), 1.2)

	# Orthogonal chamfered KSP tech-tree connector lines + arrowheads
	for link in links:
		var a: Vector2 = link.from
		var b: Vector2 = link.to
		var owned: bool = link.get("owned", false) or (link.has("id") and GameManager.research_status(str(link.id)) == "Owned")
		var tint := Color("65d83b") if owned else Color("7c8796")
		var mid := (a.x + b.x) * 0.5
		var dy := b.y - a.y
		var pts := PackedVector2Array()
		if absf(dy) < 3.0:
			pts.append(a)
			pts.append(b)
		else:
			var r := minf(10.0, minf(absf(mid - a.x) * 0.45, absf(dy) * 0.45))
			var sy := signf(dy)
			pts.append(a)
			pts.append(Vector2(mid - r, a.y))
			pts.append(Vector2(mid, a.y + sy * r))
			pts.append(Vector2(mid, b.y - sy * r))
			pts.append(Vector2(mid + r, b.y))
			pts.append(b)
		draw_polyline(pts, tint, 2.2, true)
		draw_colored_polygon(PackedVector2Array([b, b + Vector2(-8, -4.5), b + Vector2(-8, 4.5)]), tint)
