@tool
extends EditorPlugin


var dropforge_dock: EditorDock
var png_dialog: EditorFileDialog
var selected_file_label: Label
var image_info_label: Label
var status_label: Label
var build_button: Button
var selected_png_path: String = ""


func _enter_tree() -> void:
    dropforge_dock = EditorDock.new()
    dropforge_dock.name = "DropForgeDock"
    dropforge_dock.title = "DropForge"
    dropforge_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_BL
    dropforge_dock.icon_name = &"ImageTexture"

    var content := VBoxContainer.new()
    content.name = "DropForge"

    var heading := Label.new()
    heading.text = "Static 2D Asset Builder"
    content.add_child(heading)

    var description := Label.new()
    description.text = "Select a PNG, validate it, and build a Godot scene."
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(description)

    var select_button := Button.new()
    select_button.text = "Select PNG"
    select_button.pressed.connect(_on_select_png_pressed)
    content.add_child(select_button)

    selected_file_label = Label.new()
    selected_file_label.text = "No PNG selected"
    selected_file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(selected_file_label)

    image_info_label = Label.new()
    image_info_label.text = "Dimensions: pending\nTransparency: pending"
    content.add_child(image_info_label)

    build_button = Button.new()
    build_button.text = "Build Static Scene"
    build_button.disabled = true
    build_button.pressed.connect(_on_build_scene_pressed)
    content.add_child(build_button)

    status_label = Label.new()
    status_label.text = "Status: WAITING"
    content.add_child(status_label)

    dropforge_dock.add_child(content)
    add_dock(dropforge_dock)

    png_dialog = EditorFileDialog.new()
    png_dialog.access = FileDialog.ACCESS_FILESYSTEM
    png_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    png_dialog.add_filter("*.png", "PNG Images")
    png_dialog.file_selected.connect(_on_png_selected)
    add_child(png_dialog)

    print("DropForge enabled")


func _exit_tree() -> void:
    if is_instance_valid(png_dialog):
        png_dialog.queue_free()

    if is_instance_valid(dropforge_dock):
        remove_dock(dropforge_dock)
        dropforge_dock.queue_free()

    png_dialog = null
    dropforge_dock = null
    selected_file_label = null
    image_info_label = null
    status_label = null
    build_button = null
    selected_png_path = ""

    print("DropForge disabled")


func _on_select_png_pressed() -> void:
    png_dialog.popup_centered_clamped(Vector2i(900, 600))


func _on_png_selected(path: String) -> void:
    selected_file_label.text = path.get_file()
    selected_file_label.tooltip_text = path

    var image := Image.load_from_file(path)

    if image == null or image.is_empty():
        selected_png_path = ""
        build_button.disabled = true
        image_info_label.text = "Dimensions: unavailable\nTransparency: unavailable"
        status_label.text = "Status: FAILED TO LOAD"
        push_error("DropForge could not load PNG: " + path)
        return

    var size := image.get_size()
    var has_transparency := image.detect_alpha() != Image.ALPHA_NONE
    var transparency_text := "Yes" if has_transparency else "No"

    selected_png_path = path
    build_button.disabled = false

    image_info_label.text = (
        "Dimensions: %d x %d px\nTransparency: %s"
        % [size.x, size.y, transparency_text]
    )

    status_label.text = "Status: PNG VALID"

    print(
        "DropForge validated: %s | %d x %d px | transparency: %s"
        % [path, size.x, size.y, transparency_text]
    )


func _on_build_scene_pressed() -> void:
    if selected_png_path.is_empty():
        status_label.text = "Status: SELECT A PNG"
        return

    var asset_name := (
        selected_png_path
        .get_file()
        .get_basename()
        .to_snake_case()
        .validate_filename()
    )

    if asset_name.is_empty():
        asset_name = "dropforge_asset"

    var root_name := asset_name.to_pascal_case()

    var assets_res_dir := "res://dropforge_output/assets"
    var scenes_res_dir := "res://dropforge_output/scenes"

    var assets_abs_dir := ProjectSettings.globalize_path(assets_res_dir)
    var scenes_abs_dir := ProjectSettings.globalize_path(scenes_res_dir)

    var assets_dir_error := DirAccess.make_dir_recursive_absolute(assets_abs_dir)
    if assets_dir_error != OK:
        _show_build_error(
            "DropForge could not create assets directory. Error: %d"
            % assets_dir_error
        )
        return

    var scenes_dir_error := DirAccess.make_dir_recursive_absolute(scenes_abs_dir)
    if scenes_dir_error != OK:
        _show_build_error(
            "DropForge could not create scenes directory. Error: %d"
            % scenes_dir_error
        )
        return

    var texture_res_path := assets_res_dir.path_join(asset_name + ".png")
    var scene_res_path := scenes_res_dir.path_join(asset_name + ".tscn")

    var texture_abs_path := ProjectSettings.globalize_path(texture_res_path)
    var scene_abs_path := ProjectSettings.globalize_path(scene_res_path)

    var copy_error := DirAccess.copy_absolute(
        selected_png_path,
        texture_abs_path
    )

    if copy_error != OK:
        _show_build_error(
            "DropForge could not copy PNG. Error: %d"
            % copy_error
        )
        return

    var scene_text := (
        "[gd_scene load_steps=2 format=3]\n\n"
        + "[ext_resource type=\"Texture2D\" path=\""
        + texture_res_path
        + "\" id=\"1_texture\"]\n\n"
        + "[node name=\""
        + root_name
        + "\" type=\"Node2D\"]\n\n"
        + "[node name=\"Sprite2D\" type=\"Sprite2D\" parent=\".\"]\n"
        + "texture = ExtResource(\"1_texture\")\n"
    )

    var scene_file := FileAccess.open(scene_abs_path, FileAccess.WRITE)

    if scene_file == null:
        _show_build_error(
            "DropForge could not create scene file. Error: %d"
            % FileAccess.get_open_error()
        )
        return

    scene_file.store_string(scene_text)
    scene_file.close()

    EditorInterface.get_resource_filesystem().scan()

    status_label.text = "Status: SCENE BUILT"

    print("DropForge copied texture: ", texture_res_path)
    print("DropForge built scene: ", scene_res_path)


func _show_build_error(message: String) -> void:
    status_label.text = "Status: BUILD FAILED"
    push_error(message)