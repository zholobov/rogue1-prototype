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

# --- ConfigEditor ---

func test_config_editor_get_values():
    var editor = ConfigEditor.new()
    add_child_autofree(editor)
    editor.setup([{
        "title": "Test",
        "properties": [
            {"label": "Width", "key": "width", "type": "int", "value": 12, "min_value": 1, "max_value": 50, "step": 1, "options": []},
            {"label": "Speed", "key": "speed", "type": "float", "value": 1.5, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
        ]
    }])
    var vals = editor.get_values()
    assert_almost_eq(vals["width"], 12.0, 0.001)  # SpinBox.value is always float
    assert_almost_eq(vals["speed"], 1.5, 0.001)

func test_config_editor_set_property_value():
    var editor = ConfigEditor.new()
    add_child_autofree(editor)
    editor.setup([{
        "title": "Test",
        "properties": [
            {"label": "Width", "key": "width", "type": "int", "value": 12, "min_value": 1, "max_value": 50, "step": 1, "options": []},
        ]
    }])
    editor.set_property_value("width", 20)
    var vals = editor.get_values()
    assert_almost_eq(vals["width"], 20.0, 0.001)

func test_config_editor_emits_property_changed():
    var editor = ConfigEditor.new()
    add_child_autofree(editor)
    editor.setup([{
        "title": "Test",
        "properties": [
            {"label": "Flag", "key": "flag", "type": "bool", "value": false, "min_value": 0, "max_value": 0, "step": 0, "options": []},
        ]
    }])
    watch_signals(editor)
    # Programmatically toggle the CheckButton to trigger signal
    editor._controls["flag"].button_pressed = true
    assert_signal_emitted(editor, "property_changed")

# --- LevelPlayground smoke test ---

func test_playground_instantiates():
    var playground = LevelPlayground.new()
    add_child_autofree(playground)
    # Should have built UI without crashing
    assert_not_null(playground)
    assert_true(playground.get_child_count() > 0, "Playground should build UI children")

func test_grid_preview_renders_empty():
    var preview = LevelPlayground.GridPreview.new()
    add_child_autofree(preview)
    preview.set_grid([])
    # Should not crash on empty grid
    assert_not_null(preview)

func test_grid_preview_renders_grid():
    var preview = LevelPlayground.GridPreview.new()
    preview.size = Vector2(200, 200)
    add_child_autofree(preview)
    var grid = [
        ["wall", "wall", "wall"],
        ["wall", "room", "wall"],
        ["wall", "wall", "wall"],
    ]
    preview.set_grid(grid)
    # Should not crash; grid stored
    assert_eq(preview._grid.size(), 3)
