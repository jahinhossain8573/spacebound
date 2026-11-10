extends Control

const UI = preload("res://scripts/UIStyle.gd")
var links: Array = []
var extent := Vector2.ZERO

func _draw() -> void:
	for x in range(0, int(extent.x), 32):
		draw_line(Vector2(x, 0), Vector2(x, extent.y), Color(1, 1, 1, 0.035))
	for y in range(0, int(extent.y), 32):
		draw_line(Vector2(0, y), Vector2(extent.x, y), Color(1, 1, 1, 0.035))
	for link in links:
		var a: Vector2 = link.from
		var b: Vector2 = link.to
		var tint: Color = UI.BLUE if GameManager.research_status(link.id) == "Owned" else Color("48515b")
		var mid := (a.x + b.x) / 2.0
		draw_polyline(PackedVector2Array([a, Vector2(mid, a.y), Vector2(mid, b.y), b]), tint, 2.0, true)
		draw_colored_polygon(PackedVector2Array([b, b + Vector2(-8, -4), b + Vector2(-8, 4)]), tint)
