class_name S_HpRegen
extends System

# Float accumulator to avoid integer truncation (2.0/s at 60fps = 0.033 per frame → rounds to 0)
var _regen_accum: Dictionary = {}  # entity instance_id -> float

func query() -> QueryBuilder:
    return q.with_all([C_Health, C_PlayerStats])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var ps := entity.get_component(C_PlayerStats) as C_PlayerStats
        if ps.hp_regen <= 0.0:
            continue
        var health := entity.get_component(C_Health) as C_Health
        if health.current_health >= health.max_health or health.current_health <= 0:
            continue
        var eid = entity.get_instance_id()
        var accum = _regen_accum.get(eid, 0.0) + ps.hp_regen * delta
        if accum >= 1.0:
            var heal = int(accum)
            health.current_health = mini(health.current_health + heal, health.max_health)
            accum -= heal
        _regen_accum[eid] = accum
