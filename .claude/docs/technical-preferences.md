# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

> **Active project**: 大夜班 (Night Shift) — Unity 6.3 LTS.
> Legacy Godot projects (夜市, word-suika, road-rage) use the frozen snapshot at
> `technical-preferences-godot.md` — do not apply Unity conventions to `.gd` files.

## Engine & Language

- **Engine**: Unity 6.3 LTS
- **Language**: C#
- **Rendering**: URP (Universal Render Pipeline) — Web-friendly, stylized low-poly target
- **Physics**: Unity Physics (PhysX) — interaction-event driven; no networked physics precision required

## Input & Platform

- **Target Platforms**: Web (Unity Web / WebGL build target)
- **Input Methods**: Keyboard/Mouse, Touch
- **Primary Input**: Keyboard/Mouse (first-person movement + interact)
- **Gamepad Support**: Partial (browser Gamepad API; optional bonus)
- **Touch Support**: Partial (mobile browsers are secondary — desktop browser first)
- **Platform Notes**: Web build size is a first-class constraint (target <50MB compressed;
  Unity Web builds are inherently larger than Godot's). Networking must use WebSocket
  transport — WebGL has no UDP. No autoplay audio before first user gesture. Compression:
  Brotli. Strip engine code + managed stripping High where safe.

## Naming Conventions

- **Classes**: PascalCase (e.g., `CustomerController`)
- **Public fields/properties**: PascalCase (e.g., `MoveSpeed`)
- **Private fields**: _camelCase (e.g., `_moveSpeed`)
- **Methods**: PascalCase (e.g., `TakeOrder()`)
- **Events/Actions**: PascalCase, past tense for notifications (e.g., `OrderCompleted`)
- **Files**: PascalCase matching class (e.g., `CustomerController.cs`)
- **Prefabs/Scenes**: PascalCase (e.g., `CustomerDrunk.prefab`, `StoreMain.unity`)
- **Constants**: PascalCase (e.g., `MaxPatience`)

## Performance Budgets

- **Target Framerate**: 60 fps (desktop browser)
- **Frame Budget**: 16.6 ms
- **Draw Calls**: ≤ 300 per frame (Web target; low-poly + URP batching should stay well under)
- **Memory Ceiling**: ≤ 512 MB heap (WebGL memory is fixed-size; mobile browsers are strict)
- **Build Size**: ≤ 50 MB compressed download（支柱「開連結就開玩」的硬指標）

## Testing

- **Framework**: Unity Test Framework (UTF, NUnit-based) — EditMode for pure logic, PlayMode for integration
- **Test assembly convention**: `Tests/EditMode/` and `Tests/PlayMode/` with their own .asmdef
- **Test file convention**: `[System][Feature]Tests.cs`; test methods `Test_[Scenario]_[Expected]`
- **Runner (CLI)**: `Unity -batchmode -projectPath . -runTests -testPlatform EditMode -testResults results.xml`
- **Minimum Coverage**: Every Logic-type story AC covered by ≥1 test method
- **Required Tests**: All Logic + Integration stories per `production/stories/` INDEX
- **Netcode note**: keep game logic engine-agnostic where possible (plain C# classes) so it
  is EditMode-testable without spinning up NGO

## Forbidden Patterns

- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

- [None configured yet — add as dependencies are approved; Netcode for GameObjects /
  Relay / Lobby packages will be added here when the netcode prototype begins]

## Architecture Decisions Log

- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

- **Primary**: unity-specialist
- **Language/Code Specialist**: unity-specialist (C# review — primary covers it)
- **Shader Specialist**: unity-shader-specialist (Shader Graph, HLSL, URP/HDRP materials)
- **UI Specialist**: unity-ui-specialist (UI Toolkit UXML/USS, UGUI Canvas, runtime UI)
- **Additional Specialists**: unity-dots-specialist (ECS, Jobs system, Burst compiler), unity-addressables-specialist (asset loading, memory management, content catalogs)
- **Routing Notes**: Invoke primary for architecture and general C# code review. Invoke DOTS specialist for any ECS/Jobs/Burst code. Invoke shader specialist for rendering and visual effects. Invoke UI specialist for all interface implementation. Invoke Addressables specialist for asset management systems.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.cs files) | unity-specialist |
| Shader / material files (.shader, .shadergraph, .mat) | unity-shader-specialist |
| UI / screen files (.uxml, .uss, Canvas prefabs) | unity-ui-specialist |
| Scene / prefab / level files (.unity, .prefab) | unity-specialist |
| Native extension / plugin files (.dll, native plugins) | unity-specialist |
| General architecture review | unity-specialist |
| Legacy Godot files (.gd, .tscn, .gdshader) | godot-gdscript-specialist / godot-specialist（見 technical-preferences-godot.md） |
