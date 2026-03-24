class_name C_ActorTag
extends Component

enum ActorType { PLAYER, MONSTER, NEUTRAL }

@export var actor_type: ActorType = ActorType.NEUTRAL
@export var team: int = 0  # 0 = players, 1 = monsters
