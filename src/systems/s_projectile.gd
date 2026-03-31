class_name S_Projectile
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Projectile])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        var proj := entity.get_component(C_Projectile) as C_Projectile
        var parent = entity.get_parent()
        if parent is Node3D:
            parent.position += proj.direction * proj.speed * delta
