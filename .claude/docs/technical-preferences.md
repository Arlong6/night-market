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
- **Platform Notes**: Web build size is a first-class constraint (see Build Size below —
  the ceiling is set by load time, not by storage). Unity Web builds are inherently larger
  than Godot's. Networking must use WebSocket transport — WebGL has no UDP. No autoplay
  audio before first user gesture. Strip engine code + managed stripping High where safe.
- **Compression（2026-09-18 定案，實測後由 Brotli 改為 Gzip）**：
  `compressionFormat = Gzip` ＋ **`decompressionFallback = false`**。
  Brotli 體積較小，但 itch.io 只能靠 `.br` 副檔名辨識而那條路是壞的（會被解壓後重送）；
  改用 fallback 則讓 Unity 的 **JS** 解壓器接手，吞吐僅 16.3 MB/s，
  而瀏覽器原生 gzip 有 85 MB/s。gzip 多 1.34 倍體積，換掉 5.2 倍的解壓 CPU，划算。
  詳見 `docs/engine-reference/unity/modules/web.md`。

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
- **Build Size**: **≤ 44 MB**，以**實際出貨的 gzip 位元組**計（2026-09-18 由 ≤50MB 修訂，W1 實測後 arlong 裁決）
  - ⚠ **單位一定要講清楚，否則會算錯 34%**：本值指 `Build/` 底下 `.gz` 檔加 `loader.js`
    的實際大小總和。若換算成 brotli 等效約 33 MB——**那是另一個單位，不是本硬標**。
  - 原本的 50MB 是**只算下載**推出來的，而 `T_load` 還有一項與頻寬無關的**解壓 CPU**，
    當初完全沒算進去。
  - 44MB 的來源（全為 W1 實測常數）：
    `S÷2.5`（20Mbps 下載）＋ `5s`（多資源 TTFB）＋ `S×3.641÷85`（原生 gzip 解壓）
    ＋ `0.37s`（wasm 編譯與引擎初始化）≤ 25s。
    其中 3.641 是 **gzip** 的解壓膨脹比（brotli 是 4.89，**兩者不可互換**）。
  - **扣掉 9.4 MB 的地板（netcode ＋ IL2CPP 執行環境，W1 gzip 版實測），內容預算約 35 MB。**
  - 驗算：現有探針 build 9.38MB → `3.75 ＋ 5 ＋ 0.40 ＋ 0.37 = 9.5s`，
    而其解壓＋固定項預測 0.77s、本機實測 CPU **770ms**，模型吻合。
  - ⚠ 此值綁定「gzip ＋ 原生解壓 ＋ itch.io」這組前提。若日後改用支援 brotli 的主機
    （已驗證 GitLab Pages 可行），可再放寬——但那需要重新裁決發行通路。

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

真相源是 `docs/registry/architecture.yaml` 的 `forbidden_patterns` 節；此處只列指標。

- **`movement_logic_outside_core`**（ADR-0001）— 移動／碰撞決策邏輯不得住在任何引用 UnityEngine 的組件
- **`owner_truth_in_collision`**（ADR-0001）— 碰撞解算不得讀他人的權威位置，只讀內插後 transform
- **`charactercontroller_adds_motion`**（ADR-0001）— `stepOffset`／`slopeLimit`／`enableOverlapRecovery` 必須歸零
- **`networktransform_setstate_on_local`**（ADR-0001）— 本機 `NetworkTransform` 永不呼叫 `SetState()`

## Allowed Libraries / Addons

- **`com.unity.inputsystem` 1.14–1.15**（2026-09-26，ADR-0001）：project-wide actions；第一人稱控制器的
  Movement action map 恰為 `{Move2D, Look2D}`（AC1③）。舊版 Input Manager 禁用。
- [Netcode for GameObjects / Relay / Lobby packages will be added here when the netcode prototype
  is promoted from `prototypes/w1-netcode/`]

## Architecture Decisions Log

- **ADR-0001**（2026-09-26，Proposed）— 移動求解器為純 C#，Unity 只是轉接層。
  `docs/architecture/adr-0001-pure-csharp-movement-solver.md`
- **ADR-0002**（2026-09-27，Proposed）— 互動驗證只驗水平——信但要綁。
  `docs/architecture/adr-0002-horizontal-only-interaction-validation.md`
- **ADR-0003**（2026-09-28，Proposed）— 膠囊與 PassThrough 查詢介面（owner-write NetworkVariable 遮罩）。
  `docs/architecture/adr-0003-solid-capsule-query.md`

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
