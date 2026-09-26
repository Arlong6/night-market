# ADR-0001: 移動求解器為純 C#，Unity 只是轉接層

## Status
Proposed

## Date
2026-09-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6.3 LTS (6000.3.24f1)、NGO 2.13.2、Input System 1.14–1.15 |
| **Domain** | Core（移動求解器架構）；觸及 Physics（CharacterController）、Input、Networking（NetworkTransform） |
| **Knowledge Risk** | HIGH——6.1／6.2／6.3 皆在 LLM 訓練截止之後（`VERSION.md`） |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md`、`breaking-changes.md`、`deprecated-apis.md`、`current-best-practices.md`、`modules/multiplayer.md`、`modules/physics.md`、`modules/input.md`、`modules/web.md`；unity-specialist 另對照 6.3 ScriptReference 與 NGO `v2.13.2` 原始碼（見文末） |
| **Post-Cutoff APIs Used** | ① `NetworkTransform.AuthorityMode = AuthorityModes.Owner`——NGO 2.x 在 client-server 拓撲下預設 `Server = 0`，**必須顯式設定**（`multiplayer.md:27-32`）② `InputSystem.actions` project-wide actions（`current-best-practices.md:16-17`）③ `[field: SerializeField]` 供 auto-property 序列化——6.3 起 `[SerializeField]` 只准用在欄位（`breaking-changes.md:31-32`）。⚠ **不使用** `NetworkTransform.OnUpdate`：那是給繼承 `NetworkTransform` 的子類覆寫的鉤子，且只對 observer 實例呼叫；本設計不繼承、不覆寫 |
| **Verification Required** | ① `CharacterController.Move()` 在 `stepOffset = 0`、`slopeLimit = 0`、`enableOverlapRecovery = false` 下**是否仍會注入求解器以外的位移**——須同時在「完全平坦」與「有接縫誤差」兩種地板網格上測（`physics.md` 未涵蓋這三個屬性的邊界行為）② `CharacterController` 的最小移動距離設定是否會吞掉解除穿透尾端的極小 delta（`0.5·p` 當 `p → 0`）——參考檔未記載其預設值 ③ IL2CPP ＋ Managed Stripping High 下，AC1 的反射列舉若日後要對出貨 build 跑，需 `link.xml` 在**型別層級** `preserve="all"`（`[Preserve]` 只保成員不保型別存活；`current-best-practices.md:31` 的 NGO 先例） |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None（本專案首份 ADR） |
| **Enables** | 第一人稱控制器（#3）epic 的 story 建立；後續 #5（互動驗證只驗水平，C6 的連帶）、#7（膠囊／`PassThrough` 查詢介面）的 ADR |
| **Blocks** | 第一人稱控制器（#3）的全部 Logic 型 story——本 ADR Accepted 前不得開工 |
| **Ordering Note** | `technical-preferences.md` Allowed Libraries 須同步登記 `com.unity.inputsystem`；`docs/registry/architecture.yaml` 目前四節全空，本 ADR 是第一批立場 |

## Context

### Problem Statement

第一人稱控制器 GDD（`design/gdd/first-person-controller.md`）的驗收節有 31 條 T0 條目，前提是「移動求解器是純 C#，不碰 Unity 型別／PhysX／NGO」。這個前提在 2026-09-26 已被實測證明可行：`prototypes/fp-controller-core/` 以 Unity 內附 Mono 編譯純 C# 核心，**32/32 通過**，並抓到一條十位專家散文評審全漏的 AC 矛盾（AC8a③ 與 AC3 互斥）。GDD 的 OQ-F11 明寫「這個 ADR 的答案值 31 條 AC」，並把實作模式——`CharacterController` vs `Rigidbody`、要不要繼承 `NetworkTransform`——一律標為「→ ADR」（`first-person-controller.md:154-155`）。本 ADR 就是那個 ADR。

它同時必須回答評審中兩位專家（unity-specialist、gameplay-programmer）獨立撞上的同一個洞：**GDD 的 C12「單幀位移預算涵蓋一切」只列了輸入與解除穿透兩項來源；場景幾何碰撞——`CharacterController.Move()` 自己注入的位移——算不算進預算，GDD 零字。**

### Constraints

- Unity 6.3 LTS、**C# 9.0**（無 file-scoped namespace／`required`／primary constructor，`deprecated-apis.md` 語言層警告）、Web 目標 IL2CPP、Managed Stripping High。
- netcode GDD Core Rule #2（`netcode-session.md:96`）：玩家移動與朝向是 **owner 權威**；G2（`first-person-controller.md:487`）：本機不做預測、不做對帳，他人角色一律內插。
- `technical-preferences.md` Testing：「keep game logic engine-agnostic where possible (plain C# classes) so it is EditMode-testable」。
- `network_tick_rate = 10 Hz` 為專案值，**引擎預設是 30**，須顯式設定 `NetworkConfig.TickRate`（`netcode-session.md:1185`，已進 `entities.yaml`）。
- 專案目前無 `Assets/`、無 CI；測試證據靠人跑。
- 建置 ≤ 44 MB gzip；60 fps；≤ 512 MB heap。

### Requirements

- 31 條 T0 AC 必須能在**不引用 `UnityEngine` 的組件**內執行（GDD「執行分層」節）。
- 求解器介面在**型別上**取不到他人的 owner 真值（AC8b）；無 `SetPosition`／`Teleport`（AC12②）。
- 每幀淨位移 ≤ `player_move_speed_max × min(dt, movement_max_step_sec)`（C12／AC3），且此上界在**整條鏈路**（含 Unity 層）成立。
- 對外廣播邊緣觸發（C16／AC28）；payload 不含俯仰、不含走／停狀態。
- 分頁隱藏／失去指標鎖定時不採納輸入但**仍可被推**（C14／C15／AC25／AC26）。

## Decision

**移動／碰撞的全部決策邏輯住在一個不引用 `UnityEngine` 的組件裡；Unity 層是薄轉接層，只做三件事：讀輸入、餵渲染位置、套用位移。**

1. **兩個組件（asmdef）**
   - `NightShift.Movement.Core`：`noEngineReferences = true`。內含常數 `K`、`MoveSolver`、`PairMachine`（有向對狀態機）、`LookState`、`Warn`（F7 述詞）。**不得引用 `UnityEngine`、`Unity.Netcode`、`UnityEngine.InputSystem`。**
     ⚠ `noEngineReferences` 只擋**隱式**自動參照的引擎模組，擋不了有人手動在 asmdef `references` 加一條 `Unity.Netcode.Runtime`——所以 Validation 的 grep 檢查不是冗餘，是第二道鎖。
   - `NightShift.Movement.Unity`：MonoBehaviour 轉接層，引用 Core。

2. **每幀資料流**——在 `MonoBehaviour.Update()` 內，**不用 `FixedUpdate()`**（C1 無物理模擬；C13 要求以夾制後的 `dt` 推進且不補跑，而 fixed timestep 的 catch-up 正是補跑）。

   ```
   InputSystem.actions("Move2D","Look2D") ──────────────► MovementInput
   遠端玩家 NetworkTransform 內插後的 transform.position ──► CapsuleGhost(IsNpc=false)   ← C8：本端渲染位置
   NPC transform.position ──────────────────────────────► CapsuleGhost(IsNpc=true)
   netcode 的 visibilitychange 通道 ／ Cursor.lockState ──► adoptInput
                          │
                          ▼
   SolveResult r = MoveSolver.Solve(input, ghosts, Time.deltaTime, adoptInput, pairs, selfId, selfPos)
                          │
                          ▼
   characterController.Move(new Vector3(r.Delta.X, 0, r.Delta.Y))
                          │
                          ▼
   本機 transform（owner 真值，只出不進）──► NetworkTransform（AuthorityMode = Owner，顯式）──► 網路
   ```

3. **場景幾何碰撞在預算之外，且只能縮短。** `CharacterController.Move()` 在求解器輸出 delta 之後套用。轉接層必須設定：
   - `stepOffset = 0`
   - `slopeLimit = 0`（或等效關閉）
   - **`enableOverlapRecovery = false`**——此屬性預設 `true`，會在角色與**靜態**幾何重疊時由 PhysX 依重疊深度自動推出，**推出量不受每幀預算夾制、方向與 delta 無關**。netcode AC40 要求「過場結束即可移動，即使世界狀態尚未同步完成」，正是會踩到它的情境。

   契約：**`Move()` 的實際位移在 `r.Delta` 方向上的投影 ≤ `|r.Delta|`**。這個不等式容許 collide-and-slide 改變方向（法線分量歸零、保留切線分量），只約束沿原方向的淨前進量不得超過預算。**貼牆滑行時 AC3 的下界子句（≥ 0.9 × 預算）可以不成立，此為預期行為，不視為 C12 違反。**

   代價要明講：關掉 `enableOverlapRecovery` 之後，「spawn／傳送進幾何內」不再被引擎悄悄且違反預算地修好，而是完全回到 GDD 已承認的缺口（C2／F5：場景幾何卡住無保險絲，歸 #11 死巷清查）。**這不是新增風險，是把隱性風險變顯性。** 純 C# 求解器不感知靜態幾何——刻意的；「牆＋隊友推力」的三明治不在 C10 保險絲射程內，已登記給 #11。

4. **本機玩家不走 `NetworkTransform` 內插。** 本機 transform 由求解器直接驅動（G2）；`NetworkTransform` 對本機只負責**送出**。遠端玩家的 `NetworkTransform` 開內插，其內插後的 transform 就是 C8 所謂「本端當下渲染出來的位置」。**不使用 `AnticipatedNetworkTransform`**（`multiplayer.md:33`）——owner 權威下本機沒有東西要預測。

   ✅ 已查證安全：NGO 2.13.2 的 `CanCommitToTransform = IsServerAuthoritative() ? IsServer : IsOwner`；authority 實例被排除在每幀 `ApplyAuthoritativeState()` 更新清單之外（註冊時排除 ＋ `OnUpdate()` 內再擋一次）。**正常運作下 `NetworkTransform` 不會回寫本機 transform。**

5. **`AuthorityMode = Owner` 必須顯式設定，且要有 runtime guard。** client-server 拓撲下 NGO 2.x 的 `NetworkTransform` 預設 server 權威（`AuthorityModes.Server = 0`）；只有 distributed authority 拓撲才強制 owner 權威（`multiplayer.md:27-32`）。
   🔴 **忘記設定的後果不是「偶爾被拉回」**：對非 host 的 owner，`CanCommitToTransform` 為 `false`，該物件被當成 observer，**每一幀**都被 `ApplyAuthoritativeState()` 蓋掉 `CharacterController` 走出來的位置——整個 owner 權威架構對非 host 玩家靜默失效，**沒有任何錯誤訊息**。故除 AC33 的 T1 測試外，轉接層在 `OnNetworkSpawn()` 必須 `Debug.Assert`／`LogError` 檢查自己的 `NetworkTransform.AuthorityMode == AuthorityModes.Owner`。

6. **不繼承 `NetworkTransform`。** 用 stock 元件。GDD 把「要不要繼承」列為 ADR 問題（`first-person-controller.md:154-155`）——答案是不。連帶：`NetworkTransform.OnUpdate` 這個子類覆寫鉤子在本設計無處可掛，也不需要。

7. **輸入走 Input System 套件，project-wide actions**（`current-best-practices.md:16-17`）。本模組引用的 **Movement action map** 恰為 `{Move2D, Look2D}`——AC1③ 的反射列舉範圍是**這個 action map**，不是整個 project-wide `.inputactions` 資產（後者通常含 UI Toolkit 的 Navigate／Submit／Cancel）。互動鍵歸 #5，日後加入時 AC1③ 須明文豁免。`com.unity.inputsystem` 登記進 `technical-preferences.md` Allowed Libraries。

8. **對外送出走 stock `NetworkTransform`，不另建管道。** C16 的「邊緣觸發、不含俯仰、不含走／停」對應到：`NetworkTransform` 的 per-axis 同步關掉 pitch 軸（只同步位置與 yaw）；沿用其內建門檻式髒檢查（`PositionThreshold`／`RotAngleThreshold`，`multiplayer.md:49-50`）——那本身就是邊緣觸發；每 tick 至多送一次且無 per-instance 頻率設定（`multiplayer.md:44-48`）。**Core 裡的 `PoseBroadcaster`／`PosePayload` 是 T0 驗證「邊緣觸發政策」的測試替身，不進轉接層。** 否則就是兩套發送機制並存、雙倍頻寬——正是 C16 最怕的事。

9. **指標鎖定與背景分頁不由 Core 偵測。** Core 只收 `adoptInput` 布林；`Cursor.lockState` 與 netcode 已裁決的 `visibilitychange` 通道由轉接層消費（C13：本系統不自建偵測）。Web 背景分頁下 `Update()` 節流至 1 Hz、最大間隔 1601 ms（`web.md:42-48`）；Core 以 `min(dt, 0.10)` 夾制，不依賴 dt 的具體恢復值（AC24／AC25）。

### Architecture Diagram

```
┌─────────────────── NightShift.Movement.Core（asmdef: noEngineReferences = true）───────────────────┐
│  K（具名常數，對應 entities.yaml）                                                                   │
│  MoveSolver.Solve(input, ghosts, dt, adoptInput, pairs, selfId, selfPos) → SolveResult{Delta,…}     │
│  PairMachine（有向對 Separated／Overlapping／PassThrough，以玩家 id 為鍵）                           │
│  LookState（F6：線性、硬夾、不回彈）  Warn.ShouldWarn（F7 述詞）  PoseBroadcaster（僅供 T0）          │
└──────────▲──────────────────────────────────────────────────────────────────────┬──────────────────┘
           │ MovementInput / CapsuleGhost[] / dt / adoptInput                     │ Delta / InputWasCanceled
┌──────────┴──────────────────────────────────────────────────────────────────────▼──────────────────┐
│  NightShift.Movement.Unity（MonoBehaviour 轉接層）                                                   │
│   InputSystem.actions → MovementInput                                                               │
│   遠端 NetworkTransform（內插後 transform）→ CapsuleGhost      NPC transform → CapsuleGhost(IsNpc)  │
│   visibilitychange／Cursor.lockState → adoptInput                                                   │
│   CharacterController.Move(Delta)   [stepOffset=0, slopeLimit=0, enableOverlapRecovery=false]      │
│   OnNetworkSpawn(): Assert(NetworkTransform.AuthorityMode == Owner)                                 │
└─────────────────────────────────────────────┬───────────────────────────────────────────────────────┘
                                              │ 本機 transform（只出不進；永不呼叫 SetState()）
                                              ▼
                       NetworkTransform（stock；AuthorityMode = Owner；同步 pos + yaw，不同步 pitch）
```

### Key Interfaces（Core 組件，純 C#）

```csharp
// 取得他人位置的唯一途徑。readonly、無 setter、無任何 owner 真值欄位。（AC8b）
public struct CapsuleGhost { readonly string Id; readonly Vec2 RenderedPosition; readonly double Radius; readonly bool IsNpc; }

public struct MovementInput { readonly Vec2 Move2D; readonly Vec2 Look2D; }   // 恰為兩項（AC1③）

public struct SolveResult { Vec2 Delta; Vec2 DepenetrationPart; Vec2 InputPart; double Budget; bool InputWasCanceled; }

public class MoveSolver {
    // 對外只有 Solve → delta。無 SetPosition／Teleport（AC12②）。
    SolveResult Solve(MovementInput input, IList<CapsuleGhost> others, double dt,
                      bool adoptInput, PairMachine pairs, string selfId, Vec2 selfPos);
}

public class PairMachine {   // 有向對，以玩家 id 為鍵（AC18／AC19）
    PairState Get(PairKey k);              // #7 用此判定是否停供膠囊（AC17）
    void Step(PairKey k, bool overlapping, bool inputCanceled, double dt);
}
```

**轉接層契約（`NightShift.Movement.Unity`）**：
- 不得重新實作任何一段 Core 已算過的邏輯（不得「因為 CharacterController 格式不同所以在轉接層再夾一次」）。
- `Move()` 實際位移在 `r.Delta` 方向上的投影 ≤ `|r.Delta|`；以 T1 測試斷言。
- 讀他人位置**只能**從內插後的 transform；不得讀 `NetworkTransform` 的權威狀態或任何 RPC 攜帶的位置。
- **本機玩家自己的 `NetworkTransform` 永不呼叫 `SetState()`**——那是 authority 端唯一會直接回寫 transform 的公開 API（`SetStateInternal` → `transform.SetPositionAndRotation`）。C12 推論 3「班次中零傳送」在 Unity 層的對應就是這一條；日後 #11 若需傳送，必須先為 AC23 加明文豁免。
- `OnNetworkSpawn()` 斷言 `AuthorityMode == AuthorityModes.Owner`。

## Alternatives Considered

### Alternative 1: 傳統 Unity FPS 寫法——邏輯住在 MonoBehaviour 裡直接驅動 CharacterController
- **Description**: 一個 `PlayerController : MonoBehaviour`，在 `Update` 裡讀輸入、算速度、查 `Physics.OverlapCapsule`、呼叫 `Move()`。
- **Pros**: 最少檔案、最多範例可抄、與 Unity 教學一致。
- **Cons**: 31 條 T0 塌成 T1／T2；解除穿透邏輯與 PhysX 查詢綁死，AC21 的排列不變性、AC8a 的差分向量都要靠假場景；`technical-preferences.md` 的測試慣例明文反對。
- **Rejection Reason**: GDD 自我評分「今天可執行率 72% 還是接近 0」就是在問這個選項。原型已證明純 C# 路徑可行，選這條等於放棄已到手的 32 條測試。

### Alternative 2: Kinematic Rigidbody ＋ 手動 sweep（`Rigidbody.MovePosition`／`SweepTest`）
- **Description**: 以 kinematic `Rigidbody` 承載角色，求解器輸出後用 `SweepTest` 自己做場景碰撞，完全繞開 `CharacterController` 的內建行為。
- **Pros**: 沒有 step offset／slope limit／overlap recovery 的隱性位移；場景碰撞可納入同一預算。
- **Cons**: 要自己重寫 `CharacterController` 已提供的滑行與去穿透；`FixedUpdate` 的 catch-up 與 C13「不補跑」直接衝突；PhysX 進入每一條與場景有關的測試。
- **Rejection Reason**: 換來的「預算涵蓋牆面」在設計上不需要——牆只能縮短位移，不會讓 C12 的上界失效；而 `FixedUpdate` 補跑與 C13 直接衝突。

### Alternative 3: 場景碰撞納入 Core（`ISceneQuery` 抽象）
- **Description**: 定義膠囊 sweep 介面由轉接層實作，Core 自己算牆面解除穿透並吃同一預算。
- **Pros**: C12「涵蓋一切」字面成立；牆＋隊友三明治可在 Core 內處理。
- **Cons**: T0 需要假場景；Core 變重；重實作 `CharacterController` 已有的事。
- **Rejection Reason**: 2026-09-26 arlong 裁決採「預算之外，只能縮短」。

## Consequences

### Positive
- 31 條 Logic 型 AC 在無 `Assets/`、無 CI 的今天就能跑（已實證 32/32），成本一個 `.cs` 檔。
- AC8b「型別上取不到 owner 真值」由 asmdef 與 `readonly struct` 雙重強制，不靠實作者自律。
- 求解器可在任何 .NET runtime 上跑（Mono／IL2CPP／未來 CoreCLR），與引擎版本解耦。
- 排列不變性（AC21）、差分向量（AC8a）這類「原本要靠 PhysX 才觀察得到」的性質變成純函式的輸入輸出。
- 不繼承 `NetworkTransform`、不另建發送管道：頻寬只有 stock 元件那一份。

### Negative
- 場景幾何碰撞的正確性（AC34）只能在 T2 驗證；Core 對牆一無所知。
- 兩個組件、兩層型別轉換（`Vec2` ↔ `Vector3`），每幀固定封裝成本（可忽略，但存在）。
- `CharacterController` 的三個 inspector 值（`stepOffset`、`slopeLimit`、`enableOverlapRecovery`）成為**契約的一部分**，必須以 T1 測試釘住，否則有人在 inspector 改一格就靜默破壞 C12。
- 關掉 `enableOverlapRecovery` 後，spawn 進幾何的情形不再被引擎修好——這條缺口現在**完全**由 #11 死巷清查承擔。

### Risks
- **`Move()` 注入求解器以外的位移** → 三個旗標歸零；T1 斷言投影不等式；Verification ①（含平坦與有接縫兩種地板）。
- **最小移動距離吞掉解除穿透尾端的極小 delta** → 設為 0；Verification ②。
- **`AuthorityMode` 忘設 Owner** → 非 host 玩家每幀被蓋、無錯誤訊息 → AC33 T1 ＋ `OnNetworkSpawn()` runtime guard。
- **有人呼叫 `SetState()`** → 契約明文禁止；code review 抓；C12 推論 3 的 AC12② 在 Unity 層沒有型別保護，只有紀律。
- **IL2CPP 剝除讓 AC1 反射失效** → AC1 是 T0（Mono）；若日後對 build 跑，`link.xml` 型別層級 `preserve="all"`；Verification ③。
- **`slopeLimit = 0` 在有接縫的地板上卡住或打滑** → 參考檔未涵蓋，Verification ① 明列兩種地板。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| first-person-controller.md | OQ-F11：求解器是否純 C#（值 31 條 AC） | Core 組件 `noEngineReferences = true` ＋ grep 雙重鎖 |
| first-person-controller.md | C8：碰撞一律以本機渲染位置解算 | 轉接層只把內插後 transform 封成 `CapsuleGhost`；Core 無其他位置來源 |
| first-person-controller.md | C9／C11：雙向自我解除穿透、NPC 零寫入 | Core 內實作，`PeerWrites`／`NpcWrites` 恆 0 |
| first-person-controller.md | C12：單幀預算涵蓋輸入＋解除穿透 | Core 夾制；場景碰撞在預算之外且只能縮短（本 ADR 裁決）；`enableOverlapRecovery = false` |
| first-person-controller.md | C12 推論 3：班次中零傳送 | AC12② 型別保護 ＋ 轉接層「永不 `SetState()`」 |
| first-person-controller.md | C13／C14：夾制 dt、不補跑、隱藏時歸零但仍可被推 | Core 收 `adoptInput`；`Update()` 非 `FixedUpdate()` |
| first-person-controller.md | C15：指標鎖定三態 | 轉接層消費 `Cursor.lockState`，Core 只收布林 |
| first-person-controller.md | C16：邊緣觸發廣播、不含俯仰 | stock `NetworkTransform` per-axis 關 pitch ＋ 內建門檻；`PoseBroadcaster` 僅供 T0 |
| first-person-controller.md | AC1③：Movement action map 恰為 {Move2D, Look2D} | Input System project-wide actions；範圍限定於本模組的 action map |
| first-person-controller.md | AC8b／AC12②：型別層約束 | `readonly struct CapsuleGhost`；`MoveSolver` 無位置 setter |
| netcode-session.md | Core Rule #2 owner 權威（`:96`） | `AuthorityMode = Owner` 顯式 ＋ runtime guard |
| netcode-session.md | `network_tick_rate = 10`（`:1185`，引擎預設 30） | `NetworkConfig.TickRate = 10` 顯式設定 |
| first-person-controller.md | G2 本地即時／遠端內插（`:487`） | 本機不走內插、只送不收 |

## Performance Implications
- **CPU**: 四人房 12 個有向對的向量運算 ＋ NPC 數量的線性掃描，每幀微秒級；目標零配置（固定大小緩衝、struct）。
- **Memory**: `PairMachine` 以 id 為鍵的三個字典，四人房 12 筆；可忽略。
- **Load Time**: 無資產；Core 組件極小。
- **Network**: Core 不送任何封包；stock `NetworkTransform` 每 tick 至多一次（10 Hz，專案值），無第二條管道。

## Migration Plan

無既有產品程式碼。`prototypes/fp-controller-core/` **不遷移**——依 `.claude/rules/prototype-code.md` 重寫為產品標準（doc comments、資料驅動常數、DI），但其 32 條測試的**斷言**逐條搬進 `Tests/EditMode/FirstPersonController/`。`PoseBroadcaster`／`PosePayload` 留在測試組件，不進轉接層。

## Validation Criteria
- `NightShift.Movement.Core.asmdef` 的 `noEngineReferences` 為 true，**且** 組件內 grep `UnityEngine`／`Unity.Netcode`／`InputSystem` 零命中（建置期檢查；兩者缺一不可，理由見 Decision 1）。
- 32/32 T0 在 Core 組件內通過（EditMode）。
- T1：`AuthorityMode == Owner`（AC33）；轉接層「投影 ≤ |delta|」斷言；`stepOffset == 0 && slopeLimit == 0 && enableOverlapRecovery == false`；`OnNetworkSpawn()` guard 存在。
- T2：AC34 無穿牆（平坦與有接縫兩種地板）；AC37 分頁失焦後按住的鍵不造成持續移動。
- 第一次雙人 playtest：無人回報「隊友從我臉上穿過去」（F1 近裁面餘裕的體感驗證）。

## Related Decisions
- `design/gdd/first-person-controller.md` §Acceptance Criteria「執行分層」、OQ-F11（`:1605`）、G2（`:487`）、`:154-155`「實作模式一律標 → ADR」
- `design/gdd/netcode-session.md` Core Rule #2（`:96`）、`network_tick_rate`（`:1185`）
- `design/gdd/reviews/first-person-controller-review-log.md`（2026-09-26）
- `prototypes/fp-controller-core/README.md`（實證）
- 後續 ADR：#5 互動驗證只驗水平（C6 的連帶）、#7 膠囊查詢介面
- 外部原始碼（unity-specialist 查證，NGO pinned tag）：`https://github.com/Unity-Technologies/com.unity.netcode.gameobjects/blob/v2.13.2/com.unity.netcode.gameobjects/Runtime/Components/NetworkTransform.cs`（`CanCommitToTransform`、`OnUpdate` 對 authority 的排除、`SetStateInternal`）；`https://docs.unity3d.com/6000.3/Documentation/ScriptReference/CharacterController-enableOverlapRecovery.html`
- ⚠ `docs/engine-reference/unity/modules/physics.md` **未涵蓋** `enableOverlapRecovery`／`minMoveDistance`——建議補寫，這是本 ADR 第一版漏掉 B1 的直接成因
