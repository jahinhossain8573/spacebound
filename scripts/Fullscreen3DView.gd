extends TextureRect

const MAX_RENDER_EDGE := 4096.0

var viewport: SubViewport

func _ready() -> void:
	expand_mode = EXPAND_IGNORE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport = get_node_or_null("Viewport") as SubViewport
	if viewport == null:
		viewport = SubViewport.new()
		viewport.name = "Viewport"
		viewport.own_world_3d = true
		add_child(viewport)
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	texture = viewport.get_texture()
	get_viewport().size_changed.connect(_resize_viewport, CONNECT_DEFERRED)
	_resize_viewport()

func _resize_viewport() -> void:
	# Full-screen controls use logical units, which can differ from the render target.
	var output_size := Vector2(get_window().size)
	if minf(output_size.x, output_size.y) < 2.0:
		return
	var scale_limit := minf(1.0, MAX_RENDER_EDGE / maxf(output_size.x, output_size.y))
	viewport.size = Vector2i((output_size * scale_limit).round())

func to_viewport_delta(delta: Vector2) -> Vector2:
	return delta * Vector2(viewport.size) / size.max(Vector2.ONE)
