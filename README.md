# DropForge

DropForge is a Godot 4 editor plugin that converts external PNG artwork into ready-to-use static 2D scenes.

## Current Features

- Select PNG files from anywhere on the computer
- Validate image dimensions
- Detect transparency
- Copy assets into the Godot project
- Generate a Node2D scene with Sprite2D
- Generate simplified alpha-based collision
- Optionally generate an Area2D interaction region
- Create a StaticBody2D with CollisionPolygon2D
- Use safe Godot resource paths and filenames

## Generated Structure

```text
dropforge_output/
├── assets/
│   └── asset_name.png
└── scenes/
    └── asset_name.tscn

```

Generated scenes use this structure:

```text
AssetName
├── Sprite2D
└── StaticBody2D
    └── CollisionPolygon2D
```

## Installation

Copy the `addons/dropforge` folder into a Godot 4 project, then enable DropForge under:

`Project > Project Settings > Plugins`

## Usage

1. Open the DropForge dock.
2. Click `Select PNG`.
3. Choose an external PNG.
4. Review its dimensions and transparency.
5. Click `Build Static Scene`.
6. Open the generated scene under `res://dropforge_output/scenes/`.

## Current Limitations

- Static 2D assets only
- One PNG at a time
- Existing generated files are overwritten
- No animation or sprite-sheet support
- Interaction areas currently reuse the asset outline

## Development Status

Version 0.2 is under active development.

Tested with Godot 4.7.