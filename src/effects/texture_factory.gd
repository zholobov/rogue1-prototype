class_name TextureFactory
extends RefCounted

static var _cache: Dictionary = {}

static func generate_for_theme(theme: ThemeData) -> Dictionary:
	var result: Dictionary = {}

	var tex: Texture2D
	if theme.floor_pattern.size() > 0:
		tex = generate_texture(theme.floor_pattern)
		if tex != null:
			result["floor"] = tex
	if theme.wall_pattern.size() > 0:
		tex = generate_texture(theme.wall_pattern)
		if tex != null:
			result["wall"] = tex
	if theme.monster_skin.size() > 0:
		tex = generate_texture(theme.monster_skin)
		if tex != null:
			result["monster"] = tex
	if theme.corridor_floor_pattern.size() > 0:
		tex = generate_texture(theme.corridor_floor_pattern)
		if tex != null:
			result["corridor_floor"] = tex
	if theme.ceiling_pattern.size() > 0:
		tex = generate_texture(theme.ceiling_pattern)
		if tex != null:
			result["ceiling"] = tex

	_cache = result
	return result

static func get_cached() -> Dictionary:
	return _cache

static func generate_texture(params: Dictionary) -> Texture2D:
	if params.size() == 0:
		return null

	var tex_type = params.get("type", "")
	match tex_type:
		"noise":
			return _generate_noise(params)
		"gradient":
			return _generate_gradient(params)
		"image_gen":
			return _generate_image(params)
	return null

static func _generate_noise(params: Dictionary) -> NoiseTexture2D:
	var tex = NoiseTexture2D.new()
	var noise = FastNoiseLite.new()

	var noise_type_str = params.get("noise_type", "simplex")
	match noise_type_str:
		"cellular":
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		"simplex":
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		"perlin":
			noise.noise_type = FastNoiseLite.TYPE_PERLIN
		"value":
			noise.noise_type = FastNoiseLite.TYPE_VALUE

	noise.frequency = params.get("frequency", 0.05)
	noise.fractal_octaves = params.get("octaves", 3)
	tex.noise = noise
	tex.width = params.get("width", 256)
	tex.height = params.get("height", 256)

	if params.has("color_ramp"):
		tex.color_ramp = params["color_ramp"]

	return tex

static func _generate_gradient(params: Dictionary) -> GradientTexture2D:
	var tex = GradientTexture2D.new()
	var grad = Gradient.new()
	var c_from = params.get("color_from", Color.BLACK)
	var c_to = params.get("color_to", Color.WHITE)
	grad.set_color(0, c_from)
	grad.set_color(1, c_to)
	tex.gradient = grad
	tex.width = params.get("width", 256)
	tex.height = params.get("height", 64)
	return tex

static func _generate_image(params: Dictionary) -> ImageTexture:
	var w: int = params.get("width", 256)
	var h: int = params.get("height", 256)
	var c1: Color = params.get("color1", Color(0.4, 0.4, 0.4))
	var c2: Color = params.get("color2", Color(0.3, 0.3, 0.3))
	var pattern: String = params.get("pattern", "bricks")

	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	match pattern:
		"bricks":
			_draw_bricks(img, w, h, c1, c2)
		"grid":
			_draw_grid(img, w, h, c1, c2)
		"scales":
			_draw_scales(img, w, h, c1, c2)
		"flagstone":
			_draw_flagstone(img, w, h, c1, c2)
		"cobblestone":
			_draw_cobblestone(img, w, h, c1, c2)
		"ashlar":
			_draw_ashlar(img, w, h, c1, c2)
		"slabs":
			_draw_slabs(img, w, h, c1, c2)
		_:
			img.fill(c1)

	return ImageTexture.create_from_image(img)

static func _draw_bricks(img: Image, w: int, h: int, brick_color: Color, mortar_color: Color) -> void:
	var brick_w: int = maxi(int(w / 8), 4)
	var brick_h: int = maxi(int(h / 16), 2)
	var mortar: int = 1

	for y in range(h):
		for x in range(w):
			var row = int(y / brick_h)
			var offset = int(brick_w / 2) * (row % 2)
			var bx = (x + offset) % brick_w
			var by = y % brick_h
			if bx < mortar or by < mortar:
				img.set_pixel(x, y, mortar_color)
			else:
				img.set_pixel(x, y, brick_color)

static func _draw_grid(img: Image, w: int, h: int, bg_color: Color, line_color: Color) -> void:
	var spacing: int = maxi(int(w / 8), 4)
	img.fill(bg_color)
	for y in range(h):
		for x in range(w):
			if x % spacing == 0 or y % spacing == 0:
				img.set_pixel(x, y, line_color)

static func _draw_scales(img: Image, w: int, h: int, c1: Color, c2: Color) -> void:
	var scale_w: int = maxi(int(w / 8), 4)
	var scale_h: int = maxi(int(h / 8), 4)
	for y in range(h):
		for x in range(w):
			var row = int(y / scale_h)
			var offset = int(scale_w / 2) * (row % 2)
			var sx = (x + offset) % scale_w
			var sy = y % scale_h
			var cx = float(sx) / scale_w - 0.5
			var cy = float(sy) / scale_h - 0.5
			var dist = sqrt(cx * cx + cy * cy)
			if dist < 0.4:
				img.set_pixel(x, y, c1)
			else:
				img.set_pixel(x, y, c2)

static func _draw_flagstone(img: Image, w: int, h: int, stone_color: Color, mortar_color: Color) -> void:
	var slab_w: int = maxi(int(w / 4), 8)
	var slab_h: int = maxi(int(h / 4), 8)
	var mortar: int = 2
	for y in range(h):
		for x in range(w):
			var row = int(y / slab_h)
			var offset = int(slab_w * 0.4) * (row % 2)
			var sx = (x + offset) % slab_w
			var sy = y % slab_h
			if sx < mortar or sy < mortar:
				img.set_pixel(x, y, mortar_color)
			else:
				var slab_id = int(x / slab_w) * 31 + row * 17
				var variation = (slab_id % 5) * 0.02 - 0.04
				var c = Color(
					clampf(stone_color.r + variation, 0.0, 1.0),
					clampf(stone_color.g + variation, 0.0, 1.0),
					clampf(stone_color.b + variation, 0.0, 1.0)
				)
				img.set_pixel(x, y, c)

static func _draw_cobblestone(img: Image, w: int, h: int, stone_color: Color, mortar_color: Color) -> void:
	var stone_size: int = maxi(int(w / 8), 4)
	var mortar: int = 2
	for y in range(h):
		for x in range(w):
			var row = int(y / stone_size)
			var offset = int(stone_size / 2) * (row % 2)
			var sx = (x + offset) % stone_size
			var sy = y % stone_size
			var cx = float(sx) / stone_size - 0.5
			var cy = float(sy) / stone_size - 0.5
			var dist = sqrt(cx * cx + cy * cy)
			if dist > 0.38:
				img.set_pixel(x, y, mortar_color)
			else:
				var slab_id = int((x + offset) / stone_size) * 13 + row * 7
				var variation = (slab_id % 7) * 0.015 - 0.045
				var c = Color(
					clampf(stone_color.r + variation, 0.0, 1.0),
					clampf(stone_color.g + variation, 0.0, 1.0),
					clampf(stone_color.b + variation, 0.0, 1.0)
				)
				img.set_pixel(x, y, c)

static func _draw_ashlar(img: Image, w: int, h: int, stone_color: Color, mortar_color: Color) -> void:
	var block_w: int = maxi(int(w / 4), 8)
	var block_h: int = maxi(int(h / 6), 4)
	var mortar: int = 2
	for y in range(h):
		for x in range(w):
			var row = int(y / block_h)
			var offset = int(block_w / 2) * (row % 2)
			var bx = (x + offset) % block_w
			var by = y % block_h
			if bx < mortar or by < mortar:
				img.set_pixel(x, y, mortar_color)
			else:
				var block_id = int((x + offset) / block_w) * 23 + row * 11
				var variation = (block_id % 5) * 0.015 - 0.03
				var c = Color(
					clampf(stone_color.r + variation, 0.0, 1.0),
					clampf(stone_color.g + variation, 0.0, 1.0),
					clampf(stone_color.b + variation, 0.0, 1.0)
				)
				img.set_pixel(x, y, c)

static func _draw_slabs(img: Image, w: int, h: int, slab_color: Color, gap_color: Color) -> void:
	var panel_w: int = maxi(int(w / 3), 8)
	var panel_h: int = maxi(int(h / 3), 8)
	var gap: int = 2
	for y in range(h):
		for x in range(w):
			var row = int(y / panel_h)
			var offset = int(panel_w / 3) * (row % 2)
			var px = (x + offset) % panel_w
			var py = y % panel_h
			if px < gap or py < gap:
				img.set_pixel(x, y, gap_color)
			else:
				img.set_pixel(x, y, slab_color)
