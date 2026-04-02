class_name S_Weapon
extends System

signal projectile_requested(owner_body: Node3D, weapon: C_Weapon)

func query() -> QueryBuilder:
    return q.with_all([C_Weapon, C_NetworkIdentity])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var weapon := entity.get_component(C_Weapon) as C_Weapon
        var net_id := entity.get_component(C_NetworkIdentity) as C_NetworkIdentity

        # Tick cooldown
        if weapon.cooldown_remaining > 0:
            weapon.cooldown_remaining -= delta

        # Fire if requested and ready
        if weapon.is_firing and weapon.cooldown_remaining <= 0 and net_id.is_local:
            weapon.cooldown_remaining = weapon.fire_rate
            var body = entity.get_parent()
            if body:
                projectile_requested.emit(body, weapon)
            var wv = entity.get_component(C_WeaponVisual)
            if wv:
                wv.just_fired = true
