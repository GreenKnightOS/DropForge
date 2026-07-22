@tool
extends EditorPlugin


var dropforge_dock: EditorDock
var png_dialog: EditorFileDialog
var selected_file_label: Label
var image_info_label: Label
var status_label: Label


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
    description.text = "Select a PNG to inspect."
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

    print("DropForge disabled")


func _on_select_png_pressed() -> void:
    png_dialog.popup_centered_clamped(Vector2i(900, 600))


func _on_png_selected(path: String) -> void:
    selected_file_label.text = path.get_file()
    selected_file_label.tooltip_text = path

    var image := Image.load_from_file(path)

    if image == null or image.is_empty():
        image_info_label.text = "Dimensions: unavailable\nTransparency: unavailable"
        status_label.text = "Status: FAILED TO LOAD"
        push_error("DropForge could not load PNG: " + path)
        return

    var size := image.get_size()
    var has_transparency := image.detect_alpha() != Image.ALPHA_NONE
    var transparency_text := "Yes" if has_transparency else "No"

    image_info_label.text = (
        "Dimensions: %d x %d px\nTransparency: %s"
        % [size.x, size.y, transparency_text]
    )

    status_label.text = "Status: PNG VALID"

    print(
        "DropForge validated: %s | %d x %d px | transparency: %s"
        % [path, size.x, size.y, transparency_text]
    )