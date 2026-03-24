class_name C_MonsterAI
extends Component

enum AIState { IDLE, CHASE, ATTACK }

@export var state: AIState = AIState.IDLE
@export var detection_range: float = 15.0
@export var attack_range: float = 2.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var attack_element: String = ""
@export var move_speed: float = 3.0
@export var cooldown_remaining: float = 0.0
