# ADR-0002: 互動驗證只驗水平——信但要綁

## Status
Proposed

## Date
2026-09-27

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6.3 LTS (6000.3.24f1)、NGO 2.13.2（client-server 拓撲、Relay WSS） |
| **Domain** | Networking（Host 端 RPC 驗證）；觸及 Core（#5 機台互動組的驗證契約） |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `VERSION.md`、`deprecated-apis.md`、`modules/multiplayer.md`、`modules/networking.md`；ADR-0001；unity-specialist 逐行對照 NGO `v2.13.2` 原始碼（`NetworkTransform.cs`、`NetworkTimeSystem.cs`、`RpcTargets/*.cs`、`NetworkMessageManager.cs`，見文末） |
| **Post-Cutoff APIs Used** | ① NGO 2.0+ 通用 `[Rpc(SendTo.Server)]`＋尾端 `RpcParams rpcParams = default`（`deprecated-apis.md`；`SendTo` 為 enum，`RpcTarget.cs:9`）② 執行期 `RpcTarget.Single(clientId, RpcTargetUse.Temp)`（`RpcTarget.cs:257`）③ `NetworkVariable<struct>` 承載 `IsClaimed`＋`ClaimedBy`＋`ClaimGeneration`（netcode Core Rule #4） |
| **Verification Required** | ① 🔴 **`host_view_lag_p95_sec` 必須實測**：在 `TickRate = 10` 與真實 Relay RTT 分佈（東京 p95 94.5 ms／預設 region 335.8 ms／跨洲 217–306 ms，`netcode-session.md:1238`）下，量 Host 讀到的複製位置與 owner 真值的落差分佈。暫定 0.50 s 只是保守下限 ② Host 對自己的 `[Rpc(SendTo.Server)]` 走 `LocalSendRpcTarget` 同步遞迴（`RpcTargets/LocalSendRpcTarget.cs:42-47`）——確認 Request→Validate→Response 在同一呼叫堆疊內無重入問題（NGO 為此提供 `LocalDeferMode.Defer`）③ Relay **WSS** 上 RPC 的順序保證：NGO 預設 `ReliableFragmentedSequenced`，但 NGO repo 不含任何 WebSocket 字眼，該保證是否在 UTP 的 WSS driver 上成立**查不到，需實測** |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（Proposed）——「Host 只有 (pos, yaw)、且為內插後的複製品」由它的 `remote_player_pose` 立場與「不繼承 `NetworkTransform`」共同鎖定 |
| **Enables** | #5 機台互動組 GDD（驗證設計不再是未知數）；#4 攜帶與交付的交接驗證（Core Rule #6「Host 驗證雙方距離/朝向」可沿用同一述詞） |
| **Blocks** | #5 的所有 Integration 型 story |
| **Ordering Note** | ADR-0001 須先 Accepted；`station_reach_m` 由 #5 擁有，本 ADR 只給暫定值；**對 netcode 的 levy**（`interpolation_buffer_ms` 不對應 NGO 機制）須登記進 `systems-index.md` 前向義務表 |

## Context

### Problem Statement

機台互動一律 request → Host validate → broadcast（netcode Core Rule #3）。但第一人稱控制器 C6 裁決視線俯仰不同步，ADR-0001 把它固定為 `NetworkTransform` 只同步 position ＋ yaw。**Host 手上沒有發起端的俯仰、沒有射線**——「Host 驗證玩家是否瞄準機台」在資料上不可能。FP GDD 給 #5 的硬拒絕③明寫「互動驗證只能驗水平距離與水平朝向」；本 ADR 把那句話變成可實作的述詞、容差與 RPC 契約。

第一版草稿以為 Host 可以用複製品加一個小容差（`v × interact_rtt_p95_ms` = 0.441 m）直接驗。unity-specialist 逐行查證 NGO 2.13.2 後推翻了它，三條事實改變了設計：

1. **Host 讀到的永遠是內插後的值。** 非權威端的 `transform.position`／`GetSpaceRelativePosition()`／`GetSpaceRelativeRotation()` 每幀被 `ApplyAuthoritativeState()` 覆寫成插值器輸出（`NetworkTransform.cs:2708-2718→2809`；`OnUpdate` `:4441`）。位置有一條 `UseHalfFloatPrecision` 旁路，**旋轉沒有**——而述詞需要 yaw。
2. **唯一取得未內插樣本的鉤子 `OnNetworkTransformStateUpdated`（`:3292`）是 protected virtual，必須繼承 `NetworkTransform`**——與 ADR-0001 Decision 6「不繼承」直接衝突。此路不通。
3. 🔴 **`interpolation_buffer_ms = 150` 這個專案常數不對應 NGO 2.13.2 的實際機制。** 真實內插延遲 = `max(1, NetworkTimeSystem.TickLatency + InterpolationBufferTickOffset)` 個 tick（`:4250/4280`）；`InterpolationBufferTickOffset` 預設 0（`:4677`，XML 文件寫 1 是過期的）；`TickLatency` 由量測 RTT 回推、**下限鎖 2 ticks**（`NetworkTimeSystem.cs:238`）。在本專案 10 Hz 下即 **≥ 200 ms 起跳、隨 RTT 上升**。150 ms 這個數字找不到來源。

所以 Host 看到的 client 位置落後 owner 真值**至少** `單程 + 2 ticks`，跨洲最壞約 0.5 s ＝ 0.735 m。若用「複製品 ＋ 胖容差」驗證，合法玩家的接受半徑會膨脹到約 1.8 m，離開即中斷半徑跟著 ≥ 2 m——精度換不誤拒的代價太高。

### Constraints

- Host 對每個 client 只有內插後的 `(position, yaw)`（ADR-0001；本節事實 1-2）。
- 約束⑧：`RTT + 2 幀 + 處理時間 ≤ interact_rtt_p95_ms (300 ms)`；互動請求／回應一律走 RPC，不得以 `NetworkVariable` 承載結果。
- Core Rule #4：站台 `IsClaimed`＋`ClaimedBy`＋`ClaimGeneration` 同一 replicated struct；首次 claim 請求帶所讀到的現行世代，不符即拒。
- Core Rule #5：被拒後播「撲空」，不做位置回滾。
- FP 硬拒絕④：站台「離開即中斷」半徑 > `2·r_c` = 0.6 m。
- `player_move_speed_max = 1.47`、`r_c = 0.30`、`network_tick_rate = 10`、`claim_lock_timeout_sec = 5`（`entities.yaml`）。
- **`NetworkVariable` 更新與 RPC 送達順序無保證**：兩者共用同一條 per-client FIFO（`NetworkMessageManager.cs:75`）但入列時機不同（NetworkVariable 每 tick 收集，RPC 呼叫當下入列），官方文件明講 NetworkVariable 只是 eventually consistent。

### Requirements

- 驗證述詞為純函式，可在 T0 測試（不碰 NGO）。
- 合法請求在 `RTT ≤ interact_rtt_p95_ms` 下不得因延遲被拒。
- 合法玩家的接受半徑**不因網路延遲膨脹**。
- 作弊包絡有界且可量化。
- 拒絕原因可區分（供遙測與判準 1 的歸因）。

## Decision

**瞄準是本機的事；驗證是 Host 的事；client 自報姿態，但 Host 用複製品把自報綁在一個有界的包絡裡。**

1. **瞄準（哪一台）在本機決定。** client 用自己的俯仰與射線起點（FP GDD 介面表：#5 取得「僅本機的俯仰與射線起點」）做 raycast 選出 `stationId`，據此顯示提示、播樂觀動畫（≤ `optimistic_anim_max_ms` = 100 ms）。**俯仰與射線永遠不出本機。**

2. **RPC 請求帶 `stationId`、`claimGenerationSeen`，以及自報的水平姿態 `(selfX, selfZ, selfYawDeg)`。** 自報的是 owner 真值（發送當下）。

   ```csharp
   // 宣告在玩家自己的 NetworkBehaviour 上（不是站台的）
   [Rpc(SendTo.Server)]
   void RequestInteractRpc(int stationId, uint claimGenerationSeen,
                           float selfX, float selfZ, float selfYawDeg,
                           RpcParams rpcParams = default)
   ```

3. **Host 驗證述詞**（純 C#，`NightShift.Interaction.Core`；順序即短路順序）：

   ```
   Validate(req, station, replica) :=
     ① station 存在
     ② !station.IsClaimed || station.ClaimedBy == requester                    — Core Rule #4
     ③ req.claimGenerationSeen == station.ClaimGeneration                      — Core Rule #4
     ④ 綁：HorizontalDistance(req.self.xz, replica.xz) ≤ tol_lag              — 反作弊包絡
     ⑤ 精確：HorizontalDistance(req.self.xz, station.anchor.xz) ≤ station_reach_m + r_c
     ⑥ 朝向：AngleBetween(YawForward(req.self.yaw), station.anchor.xz − req.self.xz) ≤ facing_half_angle_deg
   ```

   - **④ 綁的是位置，不綁 yaw**：yaw 的複製品落後 ≥ 200 ms，玩家轉頭一圈只要幾百毫秒，綁不住；而假報 yaw 的作弊價值為零——client 本來就是自己選站台，述詞⑥驗的是「自報的朝向對得上自報的位置」，防的是程式錯不是作弊。
   - **`tol_lag = player_move_speed_max × host_view_lag_p95_sec`**。`host_view_lag_p95_sec` 🔴 **必須實測**（Verification ①）；暫定 **0.50 s**（`interact_rtt_p95_ms` 0.300 ＋ 10 Hz 下 2-tick 內插下限 0.200）⇒ `tol_lag` 暫定 **0.735 m**。⚠ 這是保守下限，未含 `TickLatency` 隨 RTT 的增長。
   - **`facing_half_angle_deg` = 60°**（2026-09-27 arlong 裁決；暫定，需 playtest）。
   - **`station_reach_m`：#5 擁有**，本 ADR 暫定 0.8 m 供驗算。
   - 述詞只看 xz 平面與 yaw——沒有 y、沒有 pitch，`HostPose`／`SelfPose` 型別構造上取不到。

   **為什麼作弊包絡與「複製品＋胖容差」相同、體驗卻不同**：兩種模型下，作弊者最多都只能把自己「說成」在複製品外 `tol_lag` 處；但本模型裡合法玩家被精確驗證（半徑 `reach + r_c` ≈ 1.1 m），不是 `reach + r_c + tol_lag` ≈ 1.8 m。**容差只花在反作弊上，不花在合法玩家身上。**

4. **拒絕原因列舉並回傳**：`Ok | NoSuchStation | Claimed | StaleGeneration | PoseOutOfBound | OutOfReach | NotFacing`。client 對所有非 `Ok` 播同一個「撲空」（Core Rule #5）。**遙測分開計數**：`PoseOutOfBound` 在誠實 client 上的比率是 Verification ① 的直接量測；`OutOfReach`／`NotFacing` 的比率是 60° 與 `station_reach_m` 的 playtest 訊號。

5. **回應以執行期定址送回發起者**：`RpcTarget.Single(rpcParams.Receive.SenderClientId, RpcTargetUse.Temp)`（`RpcTarget.cs:257`）。**不用 `SendTo.Everyone`**（其他人靠 `ClaimState` 的一般複寫得知站台被佔，不需要收到別人的 `RejectReason`，且容易誤播撲空給無關的人）；**不用 `SendTo.Owner`**（它解析的是掛載 RPC 的 `NetworkObject` 的 owner——若日後有人把方法搬到站台的 `NetworkBehaviour` 上，回應會悄悄送給 Host 自己而不報錯）。

6. **Host 自己也是 client 時走同一條路徑。** `[Rpc(SendTo.Server)]` 在 Host 上經 `LocalSendRpcTarget` **同步、同一呼叫堆疊**執行（`LocalSendRpcTarget.cs:42-47`），不進佇列、不經 transport。含義：Host 玩家的複製品就是真值，述詞④恆過；但 Request→Validate→Response 是遞迴跑完的，Verification ② 要確認無重入問題。**不得為 Host 玩家走捷徑直接改狀態**——否則 Host 玩家與其他玩家的驗證語意不一致（Host 玩家手上有俯仰，述詞刻意不用）。

7. **站台「離開即中斷」三層**（FP 硬拒絕④；`station_leave_m` 由 #5 擁有，本 ADR 給關係式）：
   - **owner 端即時**：owner 有自己的真值，離開 `station_leave_m` 即送 `InterruptRpc`，體感零延遲；
   - **Host 備援**：Host 以複製品 ＋ `tol_lag` 檢查，抓「claim 之後走遠但沒送中斷」的 client；
   - **`claim_lock_timeout_sec` = 5**：最後的保險絲，兩層都失效時站台仍會解鎖（netcode 既有）。

   關係式：`station_leave_m ≥ station_reach_m + r_c + leave_hysteresis_m`，且 `> 2·r_c`（FP GDD 已推導「任何人從他身後走過都會把他推離站台」，中斷半徑必須大於一次解除穿透的最大位移 0.6 m）。暫定 `leave_hysteresis_m = 0.20`。**因為第一層用的是 owner 真值，`tol_lag` 不進這個式子**——那是「複製品＋胖容差」模型才需要的膨脹。

8. **client 不得假設「收到 `Ok` 回應時本機 `ClaimGeneration` 已更新」。** RPC 與 `NetworkVariable` 共用 FIFO 但入列時機不同，順序無保證（Constraints 末條）。client 端所有依賴 claim 狀態的顯示都讀 `NetworkVariable` 的回呼，不讀 RPC 回應。

### Architecture Diagram

```
client（owner）                                        Host（權威）
──────────────────────────────                         ────────────────────────────────────────────
本機 pitch + ray ──► stationId                          NetworkObject 圖：requester 的複製 (pos, yaw)
  │ 提示、樂觀動畫 ≤100ms                                    ▲ 內插後，落後 ≥ 200 ms（無旁路，不繼承）
  ▼                                                          │
RequestInteractRpc(stationId, gen, selfX, selfZ, selfYaw) ──RPC──► Validate(req, station, replica)  純 C#
                                                              │ ④ |self − replica| ≤ tol_lag   ← 綁
                                                              │ ⑤⑥ self vs station（精確）
                                                              │ Ok → claim
  ◄──── RpcTarget.Single(sender) ─────────────────────────────┘
  Ok → 正式動畫｜reject → 撲空（無回滾）
  claim 狀態顯示 ← NetworkVariable 回呼（不讀 RPC）

離開即中斷：owner 真值 → InterruptRpc（即時）；Host 複製品 + tol_lag（備援）；5 s claim 逾時（保險絲）
```

### Key Interfaces（`NightShift.Interaction.Core`，純 C#）

```csharp
public struct SelfPose  { readonly double X, Z; readonly double YawDeg; }   // client 自報；刻意無 Y、無 Pitch
public struct HostPose  { readonly double X, Z; readonly double YawDeg; }   // Host 的複製品（內插後）
public struct StationDef { readonly int Id; readonly double AnchorX, AnchorZ; readonly double ReachM; }
public struct ClaimState { bool IsClaimed; ulong ClaimedBy; uint ClaimGeneration; }   // Host 寫、全員讀
public enum RejectReason { Ok, NoSuchStation, Claimed, StaleGeneration, PoseOutOfBound, OutOfReach, NotFacing }

public static class InteractValidator {
    static RejectReason Validate(int stationId, uint genSeen, ulong requester,
                                 SelfPose self, HostPose replica, StationDef station, ClaimState claim,
                                 double tolLagM, double facingHalfAngleDeg);
}
```

## Alternatives Considered

### Alternative 1: 複製品 ＋ 實測的胖容差（不自報）
- **Description**: Host 只用自己的複製品驗，半徑加 `tol_lag`。
- **Pros**: RPC 最簡單（只帶 `stationId`）；Host 不信 client 任何一個字。
- **Cons**: 合法玩家的接受半徑膨脹到 `reach + r_c + tol_lag` ≈ 1.8 m，離開即中斷半徑 ≥ 2 m，站台間距要與它一起設計；精度被延遲吃掉。
- **Rejection Reason**: 作弊包絡與本決策**完全相同**（都是 `tol_lag`），卻把容差花在合法玩家身上。2026-09-27 arlong 裁決採「信但要綁」。

### Alternative 2: client 自報 pos／yaw／pitch，Host 照單全收（不綁）
- **Pros**: 能驗俯仰；零延遲問題。
- **Cons**: Host 權威建立在 client 的話上——改封包即可隔牆互動。
- **Rejection Reason**: 「綁」這一步的成本是一次距離比較，換到的是有界的作弊包絡。不綁沒有理由。

### Alternative 3: 改同步俯仰，Host 驗完整瞄準射線
- **Rejection Reason**: 推翻 C6 與 ADR-0001 `remote_player_pose`；剪影上看不見的軸每 tick 多送一個 float；射線驗證要 Host 端有場景幾何查詢。本作互動沒有命中判定，精度無用途。

### Alternative 4: 繼承 `NetworkTransform` 以覆寫 `OnNetworkTransformStateUpdated` 取得未內插樣本
- **Rejection Reason**: 直接違反 ADR-0001 Decision 6。且只解決 Host 端讀值，不解決 client 自報與精度問題。

## Consequences

### Positive
- 合法玩家被精確驗證，接受半徑不隨延遲膨脹；離開即中斷體感零延遲。
- 作弊包絡有一個具名常數（`tol_lag`）可量化、可實測、可收緊。
- 驗證述詞純函式，T0 可測；與 ADR-0001 同一分層哲學。
- 交接驗證（Core Rule #6）可沿用同一述詞（雙方各自自報、各自綁）。

### Negative
- RPC 多 12 bytes（三個 float）。
- 述詞多一個分支、多一個拒絕原因、多一條遙測。
- `host_view_lag_p95_sec` 在實測前是保守估計；估太小會讓誠實 client 在跨洲房吃到 `PoseOutOfBound`，估太大則作弊包絡變寬。**兩個方向的錯都可觀測**（`PoseOutOfBound` 比率 vs 包絡寬度）。

### Risks
- **`host_view_lag_p95_sec` 估計錯** → Verification ①；上線前必須有實測分佈，不得以 0.50 出貨。
- **`TickLatency` 隨 RTT 增長超過估計** → 同上；跨洲房是最壞情境，T3 要在節流至 RTT 300 ms 下量。
- **Host 自呼遞迴重入** → Verification ②。
- **WSS 上 RPC 順序** → Verification ③；若不成立，`claimGenerationSeen` 的過期判定會出現假 `StaleGeneration`。
- **有人把 RPC 搬到站台的 `NetworkBehaviour`** → Decision 5 已改用執行期定址，搬了也送對人。
- **有人在 client 端讀 RPC 回應當 claim 狀態** → Decision 8 明文禁止；code review 抓。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| first-person-controller.md | C6 俯仰不同步 ⇒ 給 #5 的硬拒絕③「只能驗水平」 | 述詞只取 xz ＋ yaw；`SelfPose`／`HostPose` 構造上無 pitch |
| first-person-controller.md | 硬拒絕④ 離開即中斷半徑 > 0.6 m | `station_leave_m` 關係式；三層中斷 |
| first-person-controller.md | 介面表：#5 取得僅本機的俯仰與射線起點 | 瞄準在本機，永不上網 |
| netcode-session.md | Core Rule #3 request→validate→broadcast | RPC 契約；回應執行期定址 |
| netcode-session.md | Core Rule #4 claim 三元組與世代 | 述詞②③；Decision 8 的順序警告 |
| netcode-session.md | Core Rule #5 撲空不回滾 | 拒絕回應 |
| netcode-session.md | 約束⑧ 300 ms 上限、結果走 RPC | `host_view_lag_p95_sec` 含 `interact_rtt_p95_ms`；回應為 RPC |

## Performance Implications
- **CPU**: 每請求 O(1)：兩次距離、一次角度。
- **Network**: 請求約 20 bytes；回應含 reason。無 per-frame 流量。

## Migration Plan
無既有程式碼。`InteractValidator` 與 ADR-0001 的 Core 同一分層，測試落點 `Tests/EditMode/Interaction/`。

## Validation Criteria
- T0：述詞六個分支各一組向量；④ 邊界 `tol_lag ± ε`；⑤ 邊界 `reach + r_c ± ε`；⑥ 邊界 60° ± ε；`SelfPose`／`HostPose` 型別無 pitch 欄位（反射）；Host 自呼時 `replica == self` ⇒ ④ 恆過。
- T3（雙行程，節流至 RTT = 300 ms）：誠實 client 貼站台請求的 `PoseOutOfBound` 比率 < 1%；**同時記錄 `|replica − self|` 的分佈**——這就是 Verification ① 的數據。
- playtest：`NotFacing`／`OutOfReach` 比率與「我明明在看它」的回報並列。

## Related Decisions
- ADR-0001（`remote_player_pose`、不繼承 `NetworkTransform`）
- `design/gdd/netcode-session.md` Core Rules #3–#6、約束⑧、`:1238` RTT 實測
- `design/gdd/first-person-controller.md` C6、給 #5 的硬拒絕、介面總表
- 🔴 **對 netcode GDD 的 levy**（須登記 `systems-index.md`）：`interpolation_buffer_ms = 150` 不對應 NGO 2.13.2 的內插機制（真實延遲 = `max(1, TickLatency + Offset)` ticks，`TickLatency` 下限 2 且隨 RTT 增長）。連帶：FP GDD F1 的敏感度分析（「砍到 100 ms 買 18% 速度」）與 `L_p95 = 0.339` 的重建（含 150 ms 項）都建立在一個可能不存在的旋鈕上，須重推。
- 外部原始碼（unity-specialist 查證，NGO pinned tag `v2.13.2`）：`Runtime/Components/NetworkTransform.cs`（`:1670` `GetSpaceRelativePosition`、`:2643` `ApplyAuthoritativeState`、`:3292` `OnNetworkTransformStateUpdated`、`:4250/4280` 內插延遲、`:4441` `OnUpdate`、`:4677` `InterpolationBufferTickOffset`）；`Runtime/Timing/NetworkTimeSystem.cs:95,238`；`Runtime/Messaging/RpcTargets/RpcTarget.cs:9,257`、`LocalSendRpcTarget.cs:42-47`；`Runtime/Messaging/NetworkMessageManager.cs:75`
