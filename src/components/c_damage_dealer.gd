class_name C_DamageDealer
extends Component

@export var damage: int = 10
@export var element: String = ""  # empty = non-elemental
@export var owner_entity_id: int = -1  # prevent self-damage
@export var hit_actors: Array[int] = []  # track already-hit actors to prevent multi-hit
