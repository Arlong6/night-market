# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: Forward+ (development); Compatibility renderer for HTML5 export
- **Physics**: Godot Physics 2D (built-in)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: Web (HTML5 export)
- **Input Methods**: Keyboard, Touch
- **Primary Input**: Keyboard
- **Gamepad Support**: Partial (browsers expose Gamepad API; treat as optional bonus)
- **Touch Support**: Partial (mobile browsers — add on-screen controls if mobile play matters)
- **Platform Notes**: HTML5 export uses the Compatibility renderer for broad browser support. Keep total download small (<20MB ideal) for fast page loads. No autoplay audio on the first frame — browsers require a user gesture first.

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables**: snake_case (e.g., `move_speed`)
- **Signals/Events**: snake_case past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: [TO BE CONFIGURED]
- **Frame Budget**: [TO BE CONFIGURED]
- **Draw Calls**: [TO BE CONFIGURED]
- **Memory Ceiling**: [TO BE CONFIGURED]

## Testing

- **Framework**: GUT (Godot Unit Test) — installed as Asset Library addon at `res://addons/gut/`
- **Install path**: Project → AssetLib (in Godot editor) → search "GUT" → Install → Enable in Project Settings → Plugins
- **Test file convention**: `tests/unit/[system]/[system]_[feature]_test.gd`; each test function named `test_[scenario]_[expected]`
- **Runner**: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit` (run from `src/`; `-ginclude_subdirs` is required — GUT 9.6 does not recurse by default)
- **Single test file**: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/[system]/test_[file].gd -gexit`
- **Class cache refresh**: After adding a new `class_name`, run `godot --headless --editor --quit` once to update the global class cache before running tests — else parse error "Identifier X not declared"
- **Minimum Coverage**: Every Logic-type story AC covered by ≥1 test function (no global percentage target for weekend scope)
- **Required Tests**: All Logic + Integration stories per `production/stories/` INDEX

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only — not expected for this project)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
