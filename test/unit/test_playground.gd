extends GutTest

# --- TileRules.get_profile_weights ---

func test_get_profile_weights_normal():
    var w = TileRules.get_profile_weights("normal")
    assert_eq(w.room, 1.5)
    assert_eq(w.spawn, 1.5)
    assert_almost_eq(w.cor, 0.4, 0.001)
    assert_almost_eq(w.door, 0.2, 0.001)
    assert_eq(w.wall, 3.5)
    assert_eq(w.empty, 1.0)

func test_get_profile_weights_dense():
    var w = TileRules.get_profile_weights("dense")
    assert_eq(w.room, 2.5)

func test_get_profile_weights_boss():
    var w = TileRules.get_profile_weights("boss")
    assert_eq(w.room, 3.0)
    assert_almost_eq(w.cor, 0.2, 0.001)

func test_get_profile_weights_unknown_returns_normal():
    var w = TileRules.get_profile_weights("nonexistent")
    assert_eq(w.room, 1.5)
