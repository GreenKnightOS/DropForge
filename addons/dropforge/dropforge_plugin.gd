@tool
extends EditorPlugin


var dropforge_dock: EditorDock
var png_dialog: EditorFileDialog
var selected_file_label: Label
var image_info_label: Label
var status_label: Label
var build_button: Button
var interaction_checkbox: CheckBox
var collision_mode_option: OptionButton
var footprint_width_spinbox: SpinBox
var footprint_depth_spinbox: SpinBox
var interaction_padding_spinbox: SpinBox
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

    interaction_checkbox = CheckBox.new()
    interaction_checkbox.text = "Add interaction area"
    interaction_checkbox.button_pressed = false
    interaction_checkbox.tooltip_text = (
        "Generate an Area2D using the asset outline."
    )
    interaction_checkbox.toggled.connect(
        _on_interaction_area_toggled
    )
    content.add_child(interaction_checkbox)

    var collision_mode_label := Label.new()
    collision_mode_label.text = "Collision Mode"
    content.add_child(collision_mode_label)

    collision_mode_option = OptionButton.new()
    collision_mode_option.add_item("Alpha Outline")
    collision_mode_option.add_item("Isometric Footprint")
    collision_mode_option.select(0)
    collision_mode_option.item_selected.connect(
        _on_collision_mode_selected
    )
    content.add_child(collision_mode_option)

    var footprint_width_label := Label.new()
    footprint_width_label.text = "Footprint Width"
    content.add_child(footprint_width_label)

    footprint_width_spinbox = SpinBox.new()
    footprint_width_spinbox.min_value = 4.0
    footprint_width_spinbox.max_value = 512.0
    footprint_width_spinbox.step = 1.0
    footprint_width_spinbox.value = 64.0
    footprint_width_spinbox.suffix = " px"
    footprint_width_spinbox.editable = false
    content.add_child(footprint_width_spinbox)

    var footprint_depth_label := Label.new()
    footprint_depth_label.text = "Footprint Depth"
    content.add_child(footprint_depth_label)

    footprint_depth_spinbox = SpinBox.new()
    footprint_depth_spinbox.min_value = 4.0
    footprint_depth_spinbox.max_value = 256.0
    footprint_depth_spinbox.step = 1.0
    footprint_depth_spinbox.value = 24.0
    footprint_depth_spinbox.suffix = " px"
    footprint_depth_spinbox.editable = false
    content.add_child(footprint_depth_spinbox)

    var interaction_padding_label := Label.new()
    interaction_padding_label.text = "Interaction Padding"
    content.add_child(interaction_padding_label)

    interaction_padding_spinbox = SpinBox.new()
    interaction_padding_spinbox.min_value = 0.0
    interaction_padding_spinbox.max_value = 128.0
    interaction_padding_spinbox.step = 1.0
    interaction_padding_spinbox.value = 12.0
    interaction_padding_spinbox.suffix = " px"
    interaction_padding_spinbox.editable = false
    interaction_padding_spinbox.tooltip_text = (
        "Extra reach added around an isometric footprint."
    )
    content.add_child(interaction_padding_spinbox)

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
    interaction_checkbox = null
    collision_mode_option = null
    footprint_width_spinbox = null
    footprint_depth_spinbox = null
    interaction_padding_spinbox = null
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


func _on_collision_mode_selected(index: int) -> void:
    var use_footprint := index == 1

    footprint_width_spinbox.editable = use_footprint
    footprint_depth_spinbox.editable = use_footprint
    interaction_padding_spinbox.editable = (
        interaction_checkbox.button_pressed
        and use_footprint
    )

    var mode_name := "Alpha Outline"

    if use_footprint:
        mode_name = "Isometric Footprint"

    print("DropForge collision mode: ", mode_name)


func _on_interaction_area_toggled(is_enabled: bool) -> void:
    var use_footprint := collision_mode_option.selected == 1

    interaction_padding_spinbox.editable = (
        is_enabled and use_footprint
    )

    print("DropForge interaction area enabled: ", is_enabled)


func _on_build_scene_pressed() -> void:
    if selected_png_path.is_empty():
        status_label.text = "Status: SELECT A PNG"
        return

    var source_image := Image.load_from_file(selected_png_path)

    if source_image == null or source_image.is_empty():
        _show_build_error("DropForge could not reload the selected PNG.")
        return

    var asset_name := (
        selected_png_path
        .get_file()
        .get_basename()
        .to_snake_case()
        .validate_filename()
    )

    var dimension_suffix_regex := RegEx.create_from_string(
        "(\\d+)x_(\\d+)"
    )

    asset_name = dimension_suffix_regex.sub(
        asset_name,
        "$1x$2",
        true
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

    var collision_nodes_text := ""
    var interaction_nodes_text := ""
    var collision_count := 0
    var use_footprint := collision_mode_option.selected == 1

    if use_footprint:
        var half_width := float(
            footprint_width_spinbox.value
        ) / 2.0

        var half_depth := float(
            footprint_depth_spinbox.value
        ) / 2.0

        var footprint_center_y := -half_depth

        var footprint_polygon := PackedVector2Array([
            Vector2(
                0.0,
                footprint_center_y - half_depth
            ),
            Vector2(
                half_width,
                footprint_center_y
            ),
            Vector2(
                0.0,
                footprint_center_y + half_depth
            ),
            Vector2(
                -half_width,
                footprint_center_y
            ),
        ])

        var footprint_point_values := PackedStringArray()

        for point in footprint_polygon:
            footprint_point_values.append(
                str(snappedf(point.x, 0.01))
            )
            footprint_point_values.append(
                str(snappedf(point.y, 0.01))
            )

        collision_nodes_text = (
            "\n[node name=\"CollisionPolygon2D\" "
            + "type=\"CollisionPolygon2D\" "
            + "parent=\"StaticBody2D\"]\n"
            + "polygon = PackedVector2Array("
            + ", ".join(footprint_point_values)
            + ")\n"
        )

        collision_count = 1

        if interaction_checkbox.button_pressed:
            var interaction_padding := float(
                interaction_padding_spinbox.value
            )

            var interaction_half_width := (
                half_width + interaction_padding
            )

            var interaction_half_depth := (
                half_depth + interaction_padding
            )

            var interaction_polygon := PackedVector2Array([
                Vector2(
                    0.0,
                    footprint_center_y
                    - interaction_half_depth
                ),
                Vector2(
                    interaction_half_width,
                    footprint_center_y
                ),
                Vector2(
                    0.0,
                    footprint_center_y
                    + interaction_half_depth
                ),
                Vector2(
                    -interaction_half_width,
                    footprint_center_y
                ),
            ])

            var interaction_point_values := (
                PackedStringArray()
            )

            for point in interaction_polygon:
                interaction_point_values.append(
                    str(snappedf(point.x, 0.01))
                )
                interaction_point_values.append(
                    str(snappedf(point.y, 0.01))
                )

            interaction_nodes_text = (
                "\n[node name=\"InteractionCollisionPolygon2D\" "
                + "type=\"CollisionPolygon2D\" "
                + "parent=\"InteractionArea\"]\n"
                + "polygon = PackedVector2Array("
                + ", ".join(interaction_point_values)
                + ")\n"
            )

            var interaction_width := (
                footprint_width_spinbox.value
                + interaction_padding * 2.0
            )

            var interaction_depth := (
                footprint_depth_spinbox.value
                + interaction_padding * 2.0
            )

            print(
                "DropForge interaction footprint: %d x %d px"
                % [
                    int(interaction_width),
                    int(interaction_depth)
                ]
            )

    else:
        var bitmap_rect := Rect2i(
            Vector2i.ZERO,
            source_image.get_size()
        )

        var bitmap := BitMap.new()
        bitmap.create_from_image_alpha(source_image, 0.1)

        # Close tiny gaps and remove thin alpha fragments.
        bitmap.grow_mask(2, bitmap_rect)
        bitmap.grow_mask(-2, bitmap_rect)

        var polygons := bitmap.opaque_to_polygons(
            bitmap_rect,
            4.0
        )

        var image_area := float(
            source_image.get_width()
            * source_image.get_height()
        )

        var minimum_polygon_area := image_area * 0.0025

        var image_center := Vector2(
            source_image.get_width(),
            source_image.get_height()
        ) / 2.0

        for polygon in polygons:
            if polygon.size() < 3:
                continue

            if _polygon_area(polygon) < minimum_polygon_area:
                continue

            var point_values := PackedStringArray()

            for point in polygon:
                var centered_point: Vector2 = (
                    point - image_center
                )

                point_values.append(
                    str(snappedf(centered_point.x, 0.01))
                )
                point_values.append(
                    str(snappedf(centered_point.y, 0.01))
                )

            collision_count += 1

            var collision_name := "CollisionPolygon2D"

            if collision_count > 1:
                collision_name += str(collision_count)

            collision_nodes_text += (
                "\n[node name=\""
                + collision_name
                + "\" type=\"CollisionPolygon2D\" "
                + "parent=\"StaticBody2D\"]\n"
                + "polygon = PackedVector2Array("
                + ", ".join(point_values)
                + ")\n"
            )

            if interaction_checkbox.button_pressed:
                var interaction_collision_name := (
                    "InteractionCollisionPolygon2D"
                )

                if collision_count > 1:
                    interaction_collision_name += str(
                        collision_count
                    )

                interaction_nodes_text += (
                    "\n[node name=\""
                    + interaction_collision_name
                    + "\" type=\"CollisionPolygon2D\" "
                    + "parent=\"InteractionArea\"]\n"
                    + "polygon = PackedVector2Array("
                    + ", ".join(point_values)
                    + ")\n"
                )

    if collision_count == 0:
        _show_build_error(
            "DropForge could not generate collision."
        )
        return

    var collision_mode_name := (
        "Isometric Footprint"
        if use_footprint
        else "Alpha Outline"
    )

    print(
        "DropForge generated collision mode: ",
        collision_mode_name
    )

    var interaction_area_text := ""

    if interaction_checkbox.button_pressed:
        interaction_area_text = (
            "\n[node name=\"InteractionArea\" "
            + "type=\"Area2D\" parent=\".\"]\n"
            + "collision_layer = 0\n"
            + "collision_mask = 1\n"
            + interaction_nodes_text
        )

    var sprite_position_text := ""

    if use_footprint:
        var sprite_y := snappedf(
            -float(source_image.get_height()) / 2.0,
            0.01
        )

        sprite_position_text = (
            "position = Vector2(0, "
            + str(sprite_y)
            + ")\n"
        )

        print("DropForge anchor mode: Bottom Center")
    else:
        print("DropForge anchor mode: Center")

    var scene_text := (
        "[gd_scene load_steps=2 format=3]\n\n"
        + "[ext_resource type=\"Texture2D\" path=\""
        + texture_res_path
        + "\" id=\"1_texture\"]\n\n"
        + "[node name=\""
        + root_name
        + "\" type=\"Node2D\"]\n\n"
        + "[node name=\"Sprite2D\" type=\"Sprite2D\" parent=\".\"]\n"
        + sprite_position_text
        + "texture = ExtResource(\"1_texture\")\n\n"
        + "[node name=\"StaticBody2D\" type=\"StaticBody2D\" parent=\".\"]\n"
        + collision_nodes_text
        + interaction_area_text
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

    status_label.text = (
        "Status: SCENE BUILT (%d COLLIDERS)"
        % collision_count
    )

    print("DropForge copied texture: ", texture_res_path)
    print("DropForge built scene: ", scene_res_path)
    print("DropForge collision polygons: ", collision_count)


func _polygon_area(polygon: PackedVector2Array) -> float:
    var area := 0.0

    for index in range(polygon.size()):
        var current_point: Vector2 = polygon[index]
        var following_point: Vector2 = polygon[
            (index + 1) % polygon.size()
        ]

        area += (
            current_point.x * following_point.y
            - following_point.x * current_point.y
        )

    return absf(area) * 0.5


func _show_build_error(message: String) -> void:
    status_label.text = "Status: BUILD FAILED"
    push_error(message)
