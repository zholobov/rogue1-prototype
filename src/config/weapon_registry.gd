extends Node

var weapons: Array = []	 # Array of WeaponDefinition

func _ready() -> void:
	_register_weapons()

func get_weapon(index: int) -> WeaponDefinition:
	if index >= 0 and index < weapons.size():
		return weapons[index]
	return null

func weapon_count() -> int:
	return weapons.size()

func _register_weapons() -> void:
	# --- Pistol ---
	var pistol = WeaponDefinition.new()
	pistol.weapon_name = "Pistol"
	pistol.damage = 10
	pistol.fire_rate = 0.3
	pistol.speed = 40.0
	pistol.element = ElementNames.NONE
	pistol.build_viewmodel = func() -> Node3D:
		var root = WeaponModelFactory._build_pistol_viewmodel()
		root.name = "WeaponViewmodel"
		WeaponModelFactory._apply_element_glow(root, ElementNames.NONE)
		return root
	pistol.build_world_model = func() -> Node3D:
		var root = WeaponModelFactory._build_pistol_world()
		root.name = "WeaponWorldModel"
		root.scale = Vector3(1.2, 1.2, 1.2)
		WeaponModelFactory._apply_element_glow(root, ElementNames.NONE)
		return root
	pistol.build_hud_icon = func() -> Control:
		var root = Control.new()
		root.custom_minimum_size = Vector2(64, 48)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		WeaponModelFactory._build_pistol_icon(root, ElementNames.NONE)
		return root
	weapons.append(pistol)

	# --- Flamethrower ---
	var flame = WeaponDefinition.new()
	flame.weapon_name = "Flamethrower"
	flame.damage = 5
	flame.fire_rate = 0.1
	flame.speed = 25.0
	flame.element = ElementNames.FIRE
	flame.build_viewmodel = func() -> Node3D:
		var root = WeaponModelFactory._build_flamethrower_viewmodel()
		root.name = "WeaponViewmodel"
		WeaponModelFactory._apply_element_glow(root, ElementNames.FIRE)
		return root
	flame.build_world_model = func() -> Node3D:
		var root = WeaponModelFactory._build_flamethrower_world()
		root.name = "WeaponWorldModel"
		root.scale = Vector3(1.2, 1.2, 1.2)
		WeaponModelFactory._apply_element_glow(root, ElementNames.FIRE)
		return root
	flame.build_hud_icon = func() -> Control:
		var root = Control.new()
		root.custom_minimum_size = Vector2(64, 48)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		WeaponModelFactory._build_flamethrower_icon(root, ElementNames.FIRE)
		return root
	weapons.append(flame)

	# --- Ice Rifle ---
	var ice = WeaponDefinition.new()
	ice.weapon_name = "Ice Rifle"
	ice.damage = 15
	ice.fire_rate = 0.8
	ice.speed = 35.0
	ice.element = ElementNames.ICE
	ice.build_viewmodel = func() -> Node3D:
		var root = WeaponModelFactory._build_ice_rifle_viewmodel()
		root.name = "WeaponViewmodel"
		WeaponModelFactory._apply_element_glow(root, ElementNames.ICE)
		return root
	ice.build_world_model = func() -> Node3D:
		var root = WeaponModelFactory._build_ice_rifle_world()
		root.name = "WeaponWorldModel"
		root.scale = Vector3(1.2, 1.2, 1.2)
		WeaponModelFactory._apply_element_glow(root, ElementNames.ICE)
		return root
	ice.build_hud_icon = func() -> Control:
		var root = Control.new()
		root.custom_minimum_size = Vector2(64, 48)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		WeaponModelFactory._build_ice_rifle_icon(root, ElementNames.ICE)
		return root
	weapons.append(ice)

	# --- Water Gun ---
	var water = WeaponDefinition.new()
	water.weapon_name = "Water Gun"
	water.damage = 3
	water.fire_rate = 0.05
	water.speed = 30.0
	water.element = ElementNames.WATER
	water.build_viewmodel = func() -> Node3D:
		var root = WeaponModelFactory._build_water_gun_viewmodel()
		root.name = "WeaponViewmodel"
		WeaponModelFactory._apply_element_glow(root, ElementNames.WATER)
		return root
	water.build_world_model = func() -> Node3D:
		var root = WeaponModelFactory._build_water_gun_world()
		root.name = "WeaponWorldModel"
		root.scale = Vector3(1.2, 1.2, 1.2)
		WeaponModelFactory._apply_element_glow(root, ElementNames.WATER)
		return root
	water.build_hud_icon = func() -> Control:
		var root = Control.new()
		root.custom_minimum_size = Vector2(64, 48)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		WeaponModelFactory._build_water_gun_icon(root, ElementNames.WATER)
		return root
	weapons.append(water)
