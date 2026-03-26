class_name C_BossAI
extends Component

@export var ranged_cooldown: float = 2.0
@export var ranged_cooldown_remaining: float = 0.0
@export var projectile_damage: int = 15
@export var projectile_speed: float = 20.0
@export var is_boss: bool = false  # true only for actual boss, not armed regular monsters
