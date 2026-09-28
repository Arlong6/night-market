# ADR-0003: 膠囊與 PassThrough 查詢介面

## Status
Proposed

## Date
2026-09-28

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6.3 LTS (6000.3.24f1)、NGO 2.13.2（client-server 拓撲、Relay WSS、TickRate 10） |
| **Domain** | Core（跨系統唯讀查詢）；觸及 Networking（旗標複製）、Navigation（#7 避讓為消費端） |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `modules/multiplayer.md`、`modules/navigation.md:151-167`、`deprecated-apis.md`、`breaking-changes.md`；ADR-0001、ADR-0002；unity-specialist 逐行對照 NGO `v2.13.2` 的 `NetworkVariable.cs`／`NetworkVariableBase.cs` |
| **Post-Cutoff APIs Used** | `NetworkVariable<T>` 以 **owner 寫入權限**——✅ 已查證 client-server 拓撲完全支援：`CanClientWrite` 只比對 `OwnerClientId`，不看拓撲（`NetworkVariableBase.cs:403-418`）；非 owner 可讀（`ReadPermission.Everyone` 為預設，`:220`、`:391-392`）；Host 可讀（`:394`）；只在值變更時送（`NetworkVariable.cs:158-165`，`AreEqual` 後才 `SetDirty`）；遲加入者取得現值（`WriteFieldSynchronization`，`NetworkVariableBase.cs:496-498`）。⚠ `multiplayer.md:24` 只寫「DA 中預設 owner 寫」，容易被誤讀成 client-server 不支援——**顯式指定 `Owner` 在兩種拓撲下行為相同** |
| **Verification Required** | ① T1：兩個遮罩的 `WritePerm == NetworkVariableWritePermission.Owner`（見 Decision 1 的陷阱）② T3：兩端對同一 NPC 的實體性答案不一致窗口 ≤ 1 tick ＋ 單程 ③ 🟡 `NavMeshObstacle` 是否真的無法 per-agent 排除——`navigation.md` 只記載全域 carve 開關、6.1–6.3 破壞性變更無 Navigation 項，**但該參考檔深度不足，#7 的 ADR 作者須另行對 6.3 ScriptReference 查證** |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（`PairMachine`、Core 組件、`CapsuleGhost`、C16 邊緣觸發） |
| **Enables** | #7 客人系統 GDD 的避讓節；#11 HUD 的 `PassThrough` 雙向可見顯示（同一旗標） |
| **Blocks** | #7 涉及避讓的 Integration story |
| **Ordering Note** | ADR-0001 須先 Accepted；`PassThrough` 旗標的網路承載由本 ADR 定，#11 不得另建；**對 #7 的三條 levy**（`npc_id_reuse_cooldown_sec`、在場狀態訊號來源、避讓演算法二選一）須登記進 `systems-index.md` |

## Context

### Problem Statement

第一人稱控制器 AC17：「GIVEN 一對降級為 `PassThrough`，WHEN #7 查詢該對任一方的碰撞膠囊，THEN 該膠囊不再被回傳，且恢復 `Separated` 時重新回傳。」理由是 Edge Cases 那句：否則客人會繞一個已經可以穿過去的身體，**NPC 的本地路徑分岔無界累積**。

三件事讓這條 AC 不只是「加一個 if」：

1. **NPC 是里程碑事件制**（`NpcStateChanged(npcId, state, waypointId, ts)`，最小間隔 0.2 s，`netcode-session.md:803`），每一端在里程碑之間**本地**推進 NPC，所以本地避讓在**每一端**都跑——Host 跑的是權威路徑，client 跑的是本地平滑。
2. **實體性是 per-(player→npc) 有向對的**（C11：NPC 側永遠 `Separated`，所以只有玩家那一側的 `PassThrough` 有意義），**而 C10 的計時器只在擁有者那一端**——Host 與其他 client 不知道玩家 P 對客人 N 已降級。
3. **Unity `NavMeshObstacle` 是全域的**（`navigation.md:151-166`）：一個障礙對所有 agent 同時存在或消失，表達不出「對 N 不是實體、對 M 是」。

### Constraints

- `PairMachine` 是 `directed_pair_state` 的唯一擁有者（registry，ADR-0001）；查詢不得另設狀態來源。
- 查詢實作住在 Core（`movement_logic_outside_core`）；回傳位置為該端渲染位置（`owner_truth_in_collision`）。
- 對外廣播必須邊緣觸發（C16）。
- 狀態實例以玩家 id 為鍵，不以 slot 為鍵（AC19）。
- NPC 在場狀態有兩條並行管道（`NpcStateChanged` RPC 與 NetworkVariable），netcode `:823-826` 裁定**狀態真相走 NetworkVariable，RPC 只驅動表現層**；兩者送達順序無保證（ADR-0002）。
- `npc_pin_timeout_sec = 1.5`、`max_players = 4`（MVP 2）。

### Requirements

- 每幀、每隻 NPC 一次查詢，零配置。
- 每一端（含 Host）對同一 (player, npc) 的答案**最終一致**；不一致窗口有上界。
- 遲加入者能取得現值。
- T0 可測。

## Decision

**實體性由擁有者決定，以 owner 寫的 `NetworkVariable` 位元遮罩複製到每一端；查詢是每幀拉的零配置快照，住在 Core。**

1. **旗標承載**：每個玩家的 `NetworkObject` 上掛兩個 `NetworkVariable`，**寫入權限必須在建構子指定**：

   ```csharp
   // ⚠ DefaultWritePerm 是 Server（NetworkVariableBase.cs:225），WritePerm 為 get-only、無 setter（:261-267），
   //   唯一入口是建構子。漏掉 writePerm 參數 ⇒ owner 的寫入被 CannotWrite() 丟棄（NetworkVariable.cs:151-152），
   //   遮罩永遠是 0 ⇒ AC17 整條靜默失效，而 T0 測不到（問題只存在於 Unity 轉接層的建構呼叫）。
   public NetworkVariable<ulong> PassThroughNpcMask =
       new NetworkVariable<ulong>(0UL, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);
   public NetworkVariable<byte>  PassThroughPlayerMask =
       new NetworkVariable<byte>(0, NetworkVariableReadPermission.Everyone, NetworkVariableWritePermission.Owner);
   ```

   - `PassThroughNpcMask` bit i ＝ 對 NPC id i 已降級；Host 於一班內指派 NPC id ∈ [0, 64)。
   - `PassThroughPlayerMask` bit s ＝ 對 slot s 的玩家已降級（`max_players` 4）。
   - 擁有者端在 `PairMachine` 的 `Overlapping→PassThrough` 與 `PassThrough→Separated` 轉移時以 `.Value = newMask` 賦值。**只在轉移時寫；`Value` setter 以 `AreEqual` 比較後才 `SetDirty`（`NetworkVariable.cs:158-165`），所以「只在轉移時寫」自動等於「只在轉移時送」**——C16 的邊緣觸發由構造保證，不需要額外偵測。
   - 轉接層 `OnNetworkSpawn()` 斷言兩者的 `WritePerm == NetworkVariableWritePermission.Owner`（仿 ADR-0001 對 `AuthorityMode` 的 runtime guard）。

2. **查詢介面**（Core，純 C#，供 #7 每幀呼叫）：

   ```csharp
   public interface ISolidCapsuleQuery {
       // 回傳對 npcId 為實體的玩家膠囊數，位置為本端渲染位置。零配置：填入呼叫者緩衝。
       int FillSolidCapsules(int npcId, CapsuleGhost[] buffer);
   }
   ```

   實作規則，對每位在場玩家 P：
   - P 是本機玩家 → 實體 iff `PairMachine.Get(P→npcId) != PassThrough`（本機真值，最新）
   - P 是遠端玩家 → 實體 iff `P.PassThroughNpcMask` 的第 `npcId` 位 == 0（複製品，落後 ≤ 1 tick ＋ 單程）
   - 位置：本機玩家用自己的位置；遠端用內插後 transform（同 ADR-0001 `CapsuleGhost`）。

3. **Host 與 client 的答案不一致是預期的，且有界——而「有界」要疊兩份文件的保證才成立。** 擁有者端先知道（本機 `PairMachine`），其他端晚 ≤ 1 tick ＋ 單程。Host 權威路徑在這個窗口內會依陳舊值決策（多繞或少繞一個玩家），**但不會固化**：查詢是逐幀重問的，下一幀讀到新值即修正；而 NPC 位置本身是里程碑制，`netcode-session.md:881-882` 已保證「本地路徑分岔於下一筆 milestone 收斂、不瞬跳」。兩者疊起來：**錯誤的實體性最多影響一個窗口內的 steering 方向，且被下一筆里程碑吸收。** 不做跨端仲裁（C8 的同一原則）。

4. **重用窗口：玩家與 NPC 的保護來源不同，必須分開講。**
   - **玩家 slot 重用**：擁有者在 `player_left` 時 `PairMachine` 銷毀該對（AC20①）→ 位元清零 → 送出。新玩家可能在清零抵達前讀到陳舊位元——**但真正頂住風險的不是 tick 時序，是更衣室過場的 3.0 s 硬下限**（`netcode-session.md:177`）：新玩家的 `NetworkObject` 物理上不可能在舊玩家離線後 100 ms 內存在。
   - **NPC id 重用**：**沒有對應的結構性延遲**——客人幾秒內離店再補進是常態，一班超過 64 位客人時 id 必須回收。失效路徑：P 對 #37 降級 → #37 離店 → P 的清零抵達其他端之前，Host 把 37 分給新客 → 任何在窗口內讀到舊遮罩的人把 P 誤判為對從未接觸的新客 `PassThrough`——正是 AC17 要防的症狀換了個受害者，T0／T1 都測不到。
     **裁決（2026-09-28 arlong）：`npc_id_reuse_cooldown_sec ≥ 1.0`，levy 給 #7**——Host 回收一個 NPC id 前至少等 1 秒，遠大於清零窗口（≤ 1 tick ＋ 單程 ≈ 0.4 s 最壞），且客人進店動畫本來就更久。與玩家案例的保護同形（結構性延遲），零新欄位。
   - **NPC 在場狀態的訊號來源**：擁有者端判定「NPC despawn → 銷毀該對 → 清零」時，**必須讀 NPC 的 NetworkVariable 狀態，不得讀 `NpcStateChanged` RPC**——兩者順序無保證，讀 RPC 會在錯的時刻清零。

5. **#11 的「雙向可見」用同一個遮罩**，不另建管道。

6. **本 ADR 不決定 #7 的避讓演算法，但把選項的後果講死**：若 #7 選 Unity 內建 `NavMeshAgent` 避讓，玩家必須以 `NavMeshObstacle` 存在，而它無法 per-pair 排除——**AC17 在那條路上做不到**。#7 的 ADR 必須在「自訂 steering（消費本查詢）」與「內建避讓 ＋ 明文放棄 AC17」之間選一個，並自行對 6.3 ScriptReference 查證 `NavMeshObstacle` 的排除能力（本 ADR 的參考檔深度不足以 100% 斷言）。

7. **留給後人的一句**：`ChangeOwnership` 不會清 `NetworkVariable` 的值（unity-specialist 掃過 `NetworkVariableBase`／`NetworkVariable<T>` 全檔，ownership 變更不觸碰 `m_InternalValue`）。本 ADR 不受影響（slot 重用是新 `NetworkObject`），但**若日後有人改用 `ChangeOwnership` 重用同一物件——Core Rule #6 的道具交接就是這麼做的——舊遮罩會原樣留給新 owner，必須顯式清零。**

### Architecture Diagram

```
擁有者端                                              每一端（含 Host）
PairMachine(P→N) 轉移 ──► .Value = newMask ──NetworkVariable（AreEqual 後才 dirty）──► 複製品
  ▲ NPC 在場：讀 NetworkVariable，不讀 RPC                     │
                                                              │
#7 每幀：query.FillSolidCapsules(N, buf) ◄────────────────────┤ 本機玩家：PairMachine 真值
                                                              │ 遠端玩家：遮罩位元 + 內插後 transform
Host 權威路徑：依當幀答案 steering；錯誤窗口 ≤ 1 tick + 單程，被下一筆里程碑吸收（netcode:881-882）
```

### Key Interfaces

見 Decision 1–2。`CapsuleGhost` 沿用 ADR-0001。

## Alternatives Considered

### Alternative 1: 本地限定（不上網）
- **Rejection Reason**: 零新訊息，但 Host 權威路徑會持續繞一個已穿過去的玩家，分岔上界 1.5 s 且每次都發生——AC17 的理由正是要消除這個分岔。

### Alternative 2: 邊緣觸發 RPC `SendTo.Everyone`
- **Rejection Reason**: 遲加入者拿不到現值；RPC 與 NetworkVariable 順序無保證（ADR-0002 已查證）。

### Alternative 3: 玩家掛 `NavMeshObstacle` 並切換
- **Rejection Reason**: 全域、無法 per-pair（`navigation.md:151-166`；6.1–6.3 破壞性變更無 Navigation 項）。

### Alternative 4: `NetworkList<PassThroughEntry>`（以 id 而非位元）
- **Pros**: 天然避開 id 重用窗口。
- **Rejection Reason**: 每筆變更是 list delta、序列化較重；MVP 規模（≤ 4 玩家、NPC 併發 < 64）位元遮罩 ＋ 1 s 冷卻已足夠。若 NPC 併發 > 64，再改本項或分頁遮罩。

### Alternative 5: NPC 世代計數（仿 `ClaimGeneration`）
- **Rejection Reason**: 正確性不靠時間，但 64 位遮罩帶不了世代，要改 `NetworkList` 或讀端交叉比對 NPC 自己的世代 NetworkVariable——MVP 規模下是過度工程。2026-09-28 arlong 裁決採冷卻。

## Consequences

### Positive
- 查詢零配置、純函式、T0 可測。
- 旗標邊緣觸發由構造保證；遲加入者安全——兩者都是 NGO 已驗證的既有性質，不是新機制。
- #11 與 #7 共用同一個真相源。
- 玩家與 NPC 的重用保護同形（結構性延遲），不引入世代欄位。

### Negative
- NPC id 上限 64／班；每玩家多兩個 `NetworkVariable`（payload 8＋1 bytes，未含訊息封套）。
- 兩端答案有 ≤ 1 tick ＋ 單程的不一致窗口。
- `npc_id_reuse_cooldown_sec` 成為 #7 的義務；#7 選內建避讓的話 AC17 作廢。

### Risks
- **建構子漏 `WritePermission.Owner`** → AC17 靜默失效、T0 測不到 → Decision 1 明寫 ＋ T1 guard。
- **NPC 併發 > 64** → 改 Alternative 4 或分頁遮罩。
- **#7 從 RPC 事件判在場** → 清零時機錯 → Decision 4 明文禁止；registry 登記。
- **有人重用 `NetworkObject` 而非重 spawn** → 舊遮罩殘留 → Decision 7。
- **`NavMeshObstacle` 其實可 per-agent 排除**（信心非 100%）→ 只會讓 #7 多一個選項，不改變本 ADR。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| first-person-controller.md | AC17 停供 | `FillSolidCapsules` 依 `PassThrough` 排除 |
| first-person-controller.md | C11 NPC 側永遠 Separated | 只看 player→npc 方向 |
| first-person-controller.md | C16 邊緣觸發 | `NetworkVariable` 只送變更（原始碼確認） |
| first-person-controller.md | AC19 以 id 為鍵 | `PairMachine` 為真相源；遮罩位元只是傳輸編碼；NPC 側以冷卻補齊同等保護 |
| first-person-controller.md | AC20① despawn 銷毀 | 清零觸發點；訊號來源限定 NetworkVariable |
| first-person-controller.md | levy 給 #11：PassThrough 雙向可見 | 同一遮罩 |
| netcode-session.md | Core Rule #1 Host NPC 權威；`:803` 里程碑事件；`:823-826` 狀態真相走 NetworkVariable；`:881-882` 收斂保證 | Host 亦消費查詢；不一致窗口被里程碑吸收 |

## Performance Implications
- **CPU**: 每幀每 NPC ≤ 4 次位元／狀態檢查。
- **Network**: 只在轉移時送；payload 8＋1 bytes（未含 `NetworkObjectId`／變數索引／封套，數量級不影響決策）。

## Migration Plan
無既有程式碼。`ISolidCapsuleQuery` 實作與 `PairMachine` 同住 Core；遮罩 `NetworkVariable` 住轉接層。

## Validation Criteria
- T0：`FillSolidCapsules` 在 (a) 本機 `PassThrough` (b) 遠端遮罩位元 (c) 恢復 `Separated` 三種情形的回傳集合；零配置（無 GC）。
- T1：`OnNetworkSpawn()` guard 存在；owner 寫入後非 owner 端讀到變更；遲加入者連線即讀到現值；**兩個遮罩的 `WritePerm == Owner`**。
- T3：兩端答案不一致窗口 ≤ 1 tick ＋ 單程；NPC id 回收後 1 s 內無新客沿用該 id。

## Related Decisions
- ADR-0001（`PairMachine`、`CapsuleGhost`、`directed_pair_state`）、ADR-0002（RPC／NetworkVariable 順序無保證）
- `design/gdd/first-person-controller.md` AC17／AC19／AC20、C10／C11／C16、Edge Cases「若 PassThrough 降級生效」
- `design/gdd/netcode-session.md` `:177`（更衣室 3.0 s）、`:803`、`:823-826`、`:881-882`
- 外部原始碼（unity-specialist 查證，NGO pinned tag `v2.13.2`）：`Runtime/NetworkVariable/NetworkVariableBase.cs`（`:220` 預設讀權限、`:225` 預設寫權限、`:261-267` `WritePerm` get-only、`:376-396` `CanClientRead`、`:403-418` `CanClientWrite`、`:496-498` 遲加入者同步）；`Runtime/NetworkVariable/NetworkVariable.cs`（`:70-73` 建構子、`:151-152` `CannotWrite`、`:158-165` `AreEqual`→`SetDirty`）
- ⚠ **`docs/engine-reference/unity/modules/multiplayer.md:24` 建議回填**：「顯式指定 `NetworkVariableWritePermission.Owner` 在 client-server 與 DA 兩種拓撲下行為相同；DA 只是改了預設值。」
