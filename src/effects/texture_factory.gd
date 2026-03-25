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
        _:
            img.fill(c1)

    return ImageTexture.create_from_image(img)

static func _draw_bricks(img: Image, w: int, h: int, brick_color: Color, mortar_color: Color) -> void:
    var brick_w: int = maxi(w / 8, 4)
    var brick_h: int = maxi(h / 16, 2)
    var mortar: int = 1

    for y in range(h):
        for x in range(w):
            var row = y / brick_h
            var offset = (brick_w / 2) * (row % 2)
            var bx = (x + offset) % brick_w
            var by = y % brick_h
            if bx < mortar or by < mortar:
                img.set_pixel(x, y, mortar_color)
            else:
                img.set_pixel(x, y, brick_color)

static func _draw_grid(img: Image, w: int, h: int, bg_color: Color, line_color: Color) -> void:
    var spacing: int = maxi(w / 8, 4)
    img.fill(bg_color)
    for y in range(h):
        for x in range(w):
            if x % spacing == 0 or y % spacing == 0:
                img.set_pixel(x, y, line_color)

static func _draw_scales(img: Image, w: int, h: int, c1: Color, c2: Color) -> void:
    var scale_w: int = maxi(w / 8, 4)
    var scale_h: int = maxi(h / 8, 4)
    for y in range(h):
        for x in range(w):
            var row = y / scale_h
            var offset = (scale_w / 2) * (row % 2)
            var sx = (x + offset) % scale_w
            var sy = y % scale_h
            var cx = float(sx) / scale_w - 0.5
            var cy = float(sy) / scale_h - 0.5
            var dist = sqrt(cx * cx + cy * cy)
            if dist < 0.4:
                img.set_pixel(x, y, c1)
            else:
                img.set_pixel(x, y, c2)
