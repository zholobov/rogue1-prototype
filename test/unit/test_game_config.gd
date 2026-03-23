extends GutTest

var config: GameConfig

func before_each():
    config = GameConfig.new()

func test_has_player_speed():
    assert_not_null(config.player_speed)
    assert_typeof(config.player_speed, TYPE_FLOAT)

func test_has_player_max_health():
    assert_not_null(config.player_max_health)
    assert_typeof(config.player_max_health, TYPE_INT)

func test_has_gravity():
    assert_not_null(config.gravity)
    assert_typeof(config.gravity, TYPE_FLOAT)

func test_has_mouse_sensitivity():
    assert_not_null(config.mouse_sensitivity)
    assert_typeof(config.mouse_sensitivity, TYPE_FLOAT)

func test_has_jump_speed():
    assert_not_null(config.jump_speed)
    assert_typeof(config.jump_speed, TYPE_FLOAT)

func test_has_max_players():
    assert_not_null(config.max_players)
    assert_eq(config.max_players, 4)
