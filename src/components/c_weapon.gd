class_name C_Weapon
extends Component

@export var damage: int = 10
@export var fire_rate: float = 0.3  # seconds between shots
@export var projectile_speed: float = 30.0
@export var element: String = ""  # element applied by this weapon
@export var weapon_range: float = 50.0
@export var cooldown_remaining: float = 0.0
@export var is_firing: bool = false
