extends Control
## Low-cost 2D minimap of city roads and interactive merchants.

var player_ref: Node3D
var city_ref: Node3D
const MAP_WORLD_HALF: float = 112.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _to_canvas(pos: Vector3) -> Vector2:
	var factor: float = minf(size.x, size.y) / (MAP_WORLD_HALF * 2)
	return Vector2(size.x * 0.5 + pos.x * factor, size.y * 0.5 + pos.z * factor)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.13, 0.18, 0.87), true)
	if size.x < 5 or size.y < 5:
		return
	for line in range(-4, 5):
		var p: float = float(line) * 24.0
		draw_line(_to_canvas(Vector3(p, 0, -MAP_WORLD_HALF)), _to_canvas(Vector3(p, 0, MAP_WORLD_HALF)), Color(0.37, 0.47, 0.48), 3)
		draw_line(_to_canvas(Vector3(-MAP_WORLD_HALF, 0, p)), _to_canvas(Vector3(MAP_WORLD_HALF, 0, p)), Color(0.37, 0.47, 0.48), 3)
	if city_ref != null:
		var indicators: Dictionary = {
			"employer": Color(0.2, 0.67, 0.98),
			"supplier": Color(0.34, 0.92, 0.48),
			"stall": Color(1.0, 0.63, 0.26),
			"shop": Color(0.96, 0.85, 0.42),
			"rival": Color(0.97, 0.34, 0.4),
			"delivery": Color(0.76, 0.42, 0.96)
		}
		for marker in indicators:
			if city_ref.LOCATIONS.has(marker):
				draw_circle(_to_canvas(city_ref.LOCATIONS[marker]), 4.0, indicators[marker])
	if player_ref != null:
		var center: Vector2 = _to_canvas(player_ref.position)
		draw_circle(center, 6, Color.WHITE)
		var facing := Vector2(-sin(player_ref.rotation.y), -cos(player_ref.rotation.y))
		draw_line(center, center + facing * 11.0, Color.WHITE, 2.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.81, 0.72, 0.50, 0.70), false, 2)
