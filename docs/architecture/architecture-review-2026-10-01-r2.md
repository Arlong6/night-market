# Architecture Review Report r2 — 大夜班 (Night Shift)

> **Date**: 2026-10-01（同日第二輪；觸發＝ADR-0006 寫入）
> **Mode**: `/architecture-review` full
> **Engine**: Unity 6.3 LTS (6000.3)、C# 9.0、IL2CPP＋Managed Stripping High、Web (WebGL)；NGO 2.13.2、MPS 2.3.1、UTP 2.7.4（本輪以 `prototypes/w1-netcode/Library/PackageCache/*/package.json` 核對）
> **GDDs Reviewed**: 5（`netcode-session.md` #1/#2、`first-person-controller.md` #3、`machine-interaction.md` #5、`product-database.md` #6、`game-concept-night-shift.md`）＋ `systems-index.md`
> **ADRs Reviewed**: 5（ADR-0001／0002／0003／0005／0006，皆 **Proposed**；ADR-0004 保留編號未寫）
> **前一輪**: `docs/architecture/architecture-review-2026-10-01.md`（09:21，FAIL）——本檔不覆寫它，兩份並存
> **自前一輪以來的變動**: ADR-0006 新增；GDD 只有 6 處小改（`machine-interaction.md:268` `ClaimedBy` ulong→byte；`netcode-session.md:206／:275／:609` `LeaveSessionAsync`→`LeaveAsync`，`:379／:865` 心跳補 `host_now_ms`）；`architecture.yaml` 新增 15 條立場、8 條既有條目補 `referenced_by`。**ADR-0001／0002／0003／0005 與 FP／商品資料庫／概念／系統索引皆未動**——前一輪對它們的發現全數延續（§3D、§4）。
> **本輪新增的證據來源**: NGO／MPS **套件原始碼**（`prototypes/w1-netcode/Library/PackageCache/`），主審與 unity-specialist 都直接引用行號
> **不在範圍**: 同前一輪；`docs/architecture/architecture.md`、`control-manifest.md`、`docs/consistency-failures.md`、`production/epics/` 皆不存在（Phase 3b、Phase 6、Reflexion log 跳過）

---

## 1. Traceability Summary

| 項目 | 前一輪 | 本輪 | 變化 |
|---|---|---|---|
| **Total requirements** | 227 | **228**（新增 TR-netcode-046，arlong 2026-10-01 裁決，見 §8） | +1 |
| ✅ Covered | 50（22.0%） | **71（31.1%）** | +21 |
| ⚠️ Partial | 70（30.8%） | **74（32.5%）** | +4（含新增的 TR-netcode-046） |
| ❌ Gap | 107（47.1%） | **83（36.4%）** | −24 |
| **Foundation 層 Gap** | 30（前一輪報告寫 29，漏算 TR-fpc-040；以 registry `layer` 欄重算為 30） | **20** | −10 |

| GDD | TR | ✅ | ⚠️ | ❌ | 本輪變化 |
|---|---|---|---|---|---|
| `netcode-session.md` | 46 | 25 | 19 | 2 | 7／18／20 → 25／19／2（ADR-0006 的主戰場；含新增的 046） |
| `first-person-controller.md` | 44 | 26 | 11 | 7 | TR-fpc-011 **✅→⚠️**（唯一退步，§3 X1） |
| `machine-interaction.md` | 57 | 7 | 18 | 32 | 049 →✅；019、045 →⚠️ |
| `product-database.md` | 34 | 0 | 5 | 29 | 026 →⚠️（`BuildId` 內容雜湊） |
| `game-concept-night-shift.md` | 19 | 7 | 9 | 3 | 002／009／012 →✅；007 →⚠️ |
| `systems-index.md` | 28 | 6 | 12 | 10 | 021 →⚠️ |

**Foundation 層剩餘 20 條 Gap**：product 13（TR-product-001–007、014、016、018、020–022）、machine 4（TR-machine-010、023、027、054）、fpc 2（TR-fpc-029 攝影機、040 延遲實測）、netcode 1（TR-netcode-033 動態 spawn）。netcode 的 Foundation Gap 由 9 降到 1。

### ADR-0006 自報與本審查判定的差異

ADR-0006 的「GDD Requirements Addressed」自報 25 條。本審查判 **18 ✅、7 ⚠️**：

| TR | 判 ⚠️ 的原因 |
|---|---|
| TR-netcode-011 | `T_lobby`／`T_spawn` 已是 Core 狀態計時；`T_load` 只有 stall 偵測，auth 預熱並行未定 |
| TR-netcode-018 | `MaxSendQueueSize` 顯式化與監控點已定，值與 Host 出站上限留待 W2（V6） |
| TR-netcode-028 | 適用性矩陣的模型有缺陷（§3 E4） |
| TR-netcode-044 | session 核心的 Core 組件補上了；公式③的歸屬與測試鉤子的 build flag 隔離仍未定 |
| TR-concept-010、TR-index-021、TR-index-022 | ADR-0006 自己把實質裁決交給 G2／ADR-0004，只提供事件與數字 |

ADR-0006 沒有自報、但實際覆蓋的：TR-netcode-010、014、TR-concept-002、TR-machine-001（型別）、049 → ✅；TR-netcode-013、023、031、TR-product-026、TR-machine-019、045、TR-concept-007 → ⚠️。ADR-0006 r1 應把這些補進它的對照表。

---

## 2. Coverage Gaps — 剩餘分群

前一輪的 G1 已由 ADR-0006 承接（Proposed）。其餘分群更新如下；各 TR 的新理由見附錄。

| 群 | ADR | Layer | Engine Risk | 收 | 本輪變化 |
|---|---|---|---|---|---|
| G1 | ✅ **ADR-0006**（Proposed） | Foundation | HIGH | — | 殘留 Partial：TR-netcode-011、013、018、023、028、031、044；r1 待修 §3C |
| G2 | 同步物件生命週期與所有權轉移 | Foundation／Core | HIGH | TR-netcode-005、006、023（第 2／5 步語意）、033；TR-machine-008、009、010、012、013、027；TR-product-023、024、025；TR-index-007、008 | **新增必登記契約**：avatar prefab `DontDestroyWithOwner = true`；斷線掉落必須在 avatar despawn 訊息之前對所有 client 可見（§3C E1，與 machine C13 的 `AutoObjectParentSync = false` 協調）；`owner_write_networkvariable_on_transferable_object`（前一輪 C3）；掉落後再拾取受 ≥ 6 tick 冷卻（§5 NEW-2） |
| G3 | ADR-0004 機台互動組 Core 分層與 RPC 契約 | Core | MEDIUM | TR-machine-002、003、004、007、014、015、017、019（其餘觸發源）、020、021、024、025、033、040、041、042、045（班次結束拒收 RPC）、048、051、052、053；TR-index-003、004、005、021（公平窗口）、022（租約）、024、025；TR-product-027 | 上游已就緒：`PeerKey`、`PlayerDisconnected`、斷線只放 claim 的參與者位置（優先序 20）、Host 自身 RPC 零往返的數字 |
| G4 | SKU 資料格式、ID 與序列化凍結 | Foundation | MEDIUM | TR-product-001–005、008–017；TR-machine-007 | 新增一句：`BuildId` 的雜湊輸入必須含 `ProductCatalogAsset`（TR-product-026） |
| G5 | 建置期資料治理閘門與 CI 守門 | Foundation | MEDIUM | TR-product-018–022；TR-netcode-041 的建置期斷言；TR-index-026 | ADR-0006 D12 的「建置期斷言專案值已套用」成為第四個押在同一塊 CI 上的客戶 |
| G6 | 資產繫結與載入 | Foundation | MEDIUM | TR-product-006、007、032；TR-netcode-033 的 `NetworkPrefabsList`；TR-concept-014 | 不變 |
| G7 | 攝影機與渲染基線 | Core／Pres | HIGH | TR-fpc-029、TR-index-028、TR-concept-015、TR-machine-056、TR-product-030 | 不變 |
| G8 | 延遲模型與容差 | Core | HIGH | TR-fpc-040；TR-netcode-016、030、043；TR-index-020；TR-machine-030 | ADR-0006 給了 Host 自身 RPC 與同區單程的數字，可直接引用 |
| G9 | 遊戲時鐘與班次時基 | Foundation | LOW | TR-concept-007、TR-machine-045（`ServerTime.Tick` 時基）、TR-netcode-013（公式③） | **部分前進**：`ShiftEndTs` 真相與複製已在 ADR-0006 D13；仍須先寫 #9 遊戲時鐘 GDD |
| G10 | ADR-0005 **r1** | — | — | TR-netcode-007、013、026、027；TR-fpc-019、020；TR-concept-003、016、018；TR-index-027 | 新增 ADR-0006 加諸的三項（§3 X2／X3）與 Depends On 改向（§3B） |
| G11 | ADR-0002 **r1** | — | — | TR-machine-006、016、018、022、032；TR-index-024 | 新增 `ClaimedBy`／`requester` 改 slot、`RejectReason` 改名（§3 X1／X4） |
| G12 | 延後／需先有 GDD | — | — | 同前一輪 | 不變 |

---

## 3. Cross-ADR Conflicts（Phase 4）

> **Known conflict-prone areas**：`docs/consistency-failures.md` 不存在。本專案反覆出現的模式是「引擎預設值靜默生效、沒有錯誤訊息」（`enableOverlapRecovery`、`NetworkVariable` 建構子寫權限、Editor stub 假值、`AuthorityMode`）。**本輪又找到兩條同型**：avatar 的 `DontDestroyWithOwner` 預設 false（E1）、Solo 模式的 Host approval 被 NGO 靜默強制核准（E2）。

### 3A. ADR-0006 對既有 ADR：已宣告、尚未落地的契約衝突

**X1 [BLOCKING for Accept of 0001／0002／0003] 玩家身份編碼**——Integration＋State
- ADR-0006 D4 與 registry `player_identity_key`、`clientid_as_player_identity`（皆 active）：玩家鍵一律為 slot（`PeerKey`），clientId 不得進 Core。
- ADR-0001：`CapsuleGhost.Id: string`、`PairMachine`「以玩家 id 為鍵（AC18／AC19）」、`MoveSolver.Solve(…, string selfId, …)`。
- ADR-0002：`ClaimState.ClaimedBy: ulong`、`InteractValidator.Validate(…, ulong requester, …)`。
- ADR-0003：Constraints「狀態實例以玩家 id 為鍵，不以 slot 為鍵（AC19）」；GDD 對照表「AC19 以 id 為鍵」列；`FillSolidCapsules(int npcId, …)`。
- **Impact**：registry 現在禁止兩份 Proposed ADR 白紙黑字寫的東西；照 0001／0002 實作就違反一條 active forbidden pattern。
- **現況**：前一輪的 C1 BLOCKING 在**裁決層面已解**（D4 的三 id 表與 `PlayerLeft(slot)` 孤兒回收時刻都站得住）；傳播尚未做。ADR-0006 Ordering Note 把它定性為「邊界轉換待補」。
- **ADR-0006 Migration Plan 漏列三項**：① ADR-0002 的 `Validate(…, ulong requester, …)` 也是 Core 內的 `ulong`，同樣要改 slot；② ADR-0003 的 Constraints 那一行與 GDD 對照表的 AC19 列；③ **FPC GDD :397-399 與 AC19 標題**（item 4 只列了 netcode 與 machine 的 GDD 回填）。
- **Resolution**：0001／0002／0003 r1 照 ADR-0006 Migration item 3 改鍵，並補上述三項；FPC AC19 改寫見 §4。

**X2 [CONCERN] 離開通知**——ADR-0006 D9 vs ADR-0005 D5、Key Interfaces、registry `unload_notifier`
- ADR-0006：`pagehide`＋`beforeunload` 都掛；因 `sendBeacon` 帶不了 `Authorization`，改走 `fetch(url, { keepalive: true, headers })`；`InstallLeaveBeacon` 須增 `headers`。
- ADR-0005 與 registry 仍是 r0：`InstallLeaveBeacon(string url, string payload)`、`beforeunload → sendBeacon`。
- 已宣告為 ADR-0005 r1 義務；V10（keepalive＋Bearer 自 itch.io iframe 打 UGS Lobby REST）未驗。⚠ 我不確定各瀏覽器在 unload 期間對「需要 CORS preflight 的 keepalive 請求」的支援程度，V10 實測時應涵蓋 Chrome／Firefox／Safari。

**X3 [CONCERN] 帶碼連結來源**——ADR-0006 Migration（`document.referrer`）vs ADR-0005 D5 與 registry `launch_params`（「自身 query → iframe 父頁 query」）。即前一輪 D7，現已宣告為 ADR-0005 r1 義務。

**X4 [LOW] 型別撞名**——Pattern
- `RejectReason`：ADR-0006 `NightShift.Session.Core.RejectReason`（approval 六值）與 ADR-0002 `NightShift.Interaction.Core.RejectReason`（互動七值，machine GDD 已擴為八值）同名不同義。HUD 轉接層兩者都要顯示。
- `SessionState`：ADR-0006 Core 的 12 態 enum 與 MPS 的 `SessionState`（None／Connected／Disconnected／Deleted）同名；**ADR-0006 自己的 D2 與 T1 (g) 寫的 `SessionState.Connected` 指的是 MPS 那個**。`NightShift.Session.Unity` 必須同時 using 兩個命名空間。
- 後果是編譯期 CS0104（會出聲），但文件層面是兩份 ADR 用同一個字指不同的東西。**Resolution**：ADR-0006 r1 改名（例：`SessionPhase`、`JoinRejectReason`）。

**X5 [LOW→會導向靜默失效] registry `session_events.consumers` 指派錯誤**
- 條目寫「`customer-system` # `PlayerLeft(slot)`：遮罩位元清零（ADR-0003 r1）」。但 ADR-0003 D1 的兩個遮罩是 **owner-write**，只有該玩家自己的端能寫；#7 只讀。
- 照 registry 實作的人若在 #7（Host）上清別人的遮罩，會撞上 ADR-0003 警告過的 `CannotWrite()` 靜默丟棄。
- **Resolution**：清零的消費者是 `first-person-controller`（擁有者端，`PairMachine` 在 `PlayerLeft` 時銷毀該對→遮罩轉移）；#7 從消費者清單移除這一行。

### 3B. ADR Dependency Ordering

```
Foundation（無依賴）
  1. ADR-0001 移動求解器為純 C#                     Proposed  Depends On: None
依賴 Foundation
  2. ADR-0002 互動驗證只驗水平                       Proposed  Depends On: ADR-0001 ⚠
  3. ADR-0003 膠囊與 PassThrough 查詢介面            Proposed  Depends On: ADR-0001 ⚠
  4. ADR-0005 平台抽象層                             Proposed  Depends On: ADR-0001 ⚠
  5. ADR-0006 連線會談生命週期                       Proposed  Depends On: ADR-0005 ⚠
待寫
  6. G2 同步物件生命週期與所有權轉移                 預期 Depends On: ADR-0006
  7. ADR-0004 機台互動組 Core                        預期 Depends On: ADR-0002、ADR-0006、G2、ADR-0005
```

- **宣告的圖無循環。**
- ⚠ 五份皆 Proposed。ADR-0006 實際上依賴的是 ADR-0005 的 **r1**（`InstallLeaveBeacon` 帶 headers），而 r1 排在 ADR-0006 Accepted 之後——兩者必須**成對** Accept（ADR-0006 Ordering Note 已寫「須一起過 review」）。
- **本輪指定檢查項：ADR-0002／0003／0005 的 Depends On 是否已補列 ADR-0006 → 三份都沒有**（自 ADR-0006 寫入前即未再動）。ADR-0002、0003 的 r1 應補列，不會成環。**ADR-0005 不應補列**：ADR-0006 已依賴 ADR-0005，反向再補即成 0005↔0006 兩點環；ADR-0005 應改在 **Enables** 列 ADR-0006。
- 🔴 **LATENT DEPENDENCY CYCLE（ADR-0001 r1 落地時成形）**：`PeerKey` 定義在 `NightShift.Session.Core`（ADR-0006），ADR-0001 r1 改用它就必須 Depends On ADR-0006；而 ADR-0006 → ADR-0005 → ADR-0001。結果是 **ADR-0001 → ADR-0006 → ADR-0005 → ADR-0001**。另有一條較弱的 **ADR-0003 ↔ ADR-0006**：ADR-0006 D4 說 NPC id 值域「由 ADR-0003 的 64 位元遮罩決定」，ADR-0003 r1 又要取用 ADR-0006 的 `PeerKey`。
  - **Resolution 1（推薦）**：
    - ADR-0005 的「Depends On ADR-0001」改為 Related。它依賴的是分層紀律 `movement_logic_outside_core`，那已是 registry 的全專案 forbidden pattern，不是 ADR-0001 的決策輸出；真正的消費方向是 ADR-0001 的轉接層取用 ADR-0005 的 `IPageLifecycle`。
    - ADR-0006 D4 自己擁有 NPC id 值域（`npc_id_max = 64`），ADR-0003 的遮罩寬度由它推導並靜態斷言。
    - `PeerKey` 移到零依賴的小組件（例：`NightShift.Identity`，`noEngineReferences = true`），`Movement.Core` 不必為一個兩欄 struct 引用整個 `Session.Core`。
  - **Resolution 2**：把 identity 契約拆成獨立的小 ADR（無依賴），0001／0002／0003／0006 都依賴它。拓撲最乾淨，但推翻 arlong 2026-10-01「identity 併入 ADR-0006」的裁決，需要 arlong 重裁。
- **建議的 Accept 順序（採 Resolution 1）**：ADR-0005 r1＋ADR-0006 r1（成對）→ ADR-0001 r1 → ADR-0002 r1、ADR-0003 r1 → G2 → ADR-0004 → G4 → …
  ⚠ 這代表 ADR-0001 不再是「最先可 Accept」的那份。先 Accept ADR-0001 r0 再改鍵，會讓 #3 的 story 先以 `string Id` 寫下去，不建議。

### 3C. ADR-0006 本身的缺陷（以套件原始碼佐證；r1 修）

嚴重度：🔴 HIGH＝Accept 前必修且會靜默失效；🟡 MEDIUM＝Accept 前應修；LOW＝隨 r1 一併處理。**Accept 前必修四條：E1、E2、E6、E8**（與 unity-specialist 的結論一致，見 §5）。

**E1 [🔴 HIGH，必修] 斷線時手持物在 Host 存活、在每個 client 消失**——State
- ADR-0006 D7：三個觸發源匯流為一個 `PeerLost`，`DisconnectSequencer` 依 1 `FreezeInput` → 2 `DropHeldItems` → … → 5 `DespawnAvatar` 固定順序「同一幀同步完成」。
- **觸發源為 `OnClientDisconnectCallback` 時，序列跑之前 NGO 已經處置完畢**：`NetworkConnectionManager.cs:1366-1392`，PlayerObject 在 `!DontDestroyWithOwner`（**預設**）時直接 despawn＋destroy；`DontDestroyWithOwner = true` 的 owned 物件走 `RemoveOwnership()`；之後才在 :1567 呼叫回呼。`multiplayer.md:63-74` 早已記載，GDD #24 的前置條件卻只要求道具設 `true`。最常走到這條路的是最常見的離開方式：client 主動離開走 `Shutdown()`，Host 0.08 s 就收到回呼，遠早於 8 s 心跳。
- **Host 端**：`NetworkSpawnManager.cs:1714-1761` 在 despawn 父物件時把子 `NetworkObject` 移到根節點（走 `InternalTrySetParent`，不檢查 `AutoObjectParentSync`），道具留在 avatar 最後的世界座標，存活。
- **client 端（unity-specialist NEW-1，主審抽查確認）**：client 走 `OnDespawnNonAuthorityObject`（:1664），移到根節點的那段被 `IsServer || distributedAuthority` 擋掉。道具以 `Transform.SetParent` 掛在 avatar 的手部 socket（machine C13，`AutoObjectParentSync = false`），於是隨 avatar 一起被銷毀。**Host 有這件道具，所有 client 都沒有。**
- **心跳觸發源也逃不掉**：即使序列先跑、第 2 步在 Host 端 unparent，`AutoObjectParentSync = false` 下這個 unparent 不會複製出去，第 5 步的 despawn 一到 client 照樣把道具一起帶走。
- **後果**：AC10（≤ 2 s 掉在原地）與 AC14（不消失不複製）只在真實斷線時紅燈，而且是兩端不一致的靜默 desync。
- **Resolution**：① avatar prefab 也必須 `DontDestroyWithOwner = true`，讓 NGO 只收回所有權、由序列掌握順序；② 第 2 步的掉落必須在第 5 步的 despawn 訊息**之前**對所有 client 可見——例如同一幀先送一則 RPC（與 despawn 訊息走同一條有序的 reliable 佇列），或讓可攜道具改用 NGO 的 parent sync。後者與 machine C13 的 `AutoObjectParentSync = false` 衝突，須在 G2 協調。ADR-0006 D7 把這兩條列為前提，G2 負責實作。

**E2 [🔴 HIGH，必修] Solo 模式的 approval 會被 NGO 靜默強制核准**——Integration（ADR 內部 D5 × D10）
- D10：Solo 不初始化 UGS、不登入，沒有 MPS session，也就沒有 `PlayerId`；同條卻寫「approval（本機 client 0 走同一閘門、slot 0）」。
- D5 第 2 項：`PlayerId` 不在 `session.Players` → `NotAMember`。Solo 下 `HostView.MemberIds` 沒有定義，等於必拒。
- `NetworkManager.cs:1499-1518`（`HostServerInitialize`）：approval callback 對 Host 本機 client 確實會跑，`Approved = false` 只記一行警告，之後無條件 `HandleConnectionApproval`。結果是 `SlotTable` 沒有 slot 0、沒有任何錯誤。ADR 自己的 Risks 點出了這個機制，但 T0 (b) 只涵蓋 Online Host。Lobby\* 沙盒走同一條 Solo 路徑，也會中。
- **Resolution**：定義 Solo 的 `HostView`（`MemberIds = { 本機合成 id }`）與 payload 的 `PlayerId`，或 Solo 下跳過第 2 項；T0 (b) 增加 Solo 案例；轉接層在 Host 自核准後斷言 `SlotTable.SlotOf(0) == 0`。

**E3 [LOW] NGO 已內建 `SinglePlayerTransport`，ADR 卻手刻 `OfflineTransport`**——Engine
- NGO 2.13.2 `Runtime/Transports/SinglePlayer/SinglePlayerTransport.cs`；CHANGELOG 2.4.0「Added `SinglePlayerTransport`」；2.13.1 起 `Documentation~/advanced-topics/singleplayer.md` 附「開 Host 前把 `NetworkConfig.NetworkTransport` 在它與 `UnityTransport` 之間切換」的範例，正是 D10 想做的事。Alternatives 沒提到它。
- unity-specialist 核對：手刻版**功能上安全**——Host 本機的 approval、連線、spawn 與 RPC 都不經 transport（`NetworkManager.cs:1501-1537`、`NetworkBehaviour.cs:121-140,242-253`）。
- **Resolution**：改用官方版，由 NGO 團隊維護、隨版本演進；V3 改為「`SinglePlayerTransport` 在 WebGL IL2CPP 下 `StartHost()` 成功」。

**E4 [🟡 MEDIUM] 適用性矩陣不是單一狀態機的守衛表**——Pattern
- GDD 矩陣實為 **32 列**（含 #15a、#17a、#23a、#24a）× **11 欄**（Booting／LoadFailed 合欄）。ADR 寫「28 × 12」，T0 (a) 照字面只測 28 條，會漏掉 #17a（teardown 不變式）與 #24a（MPS 成員唯一寫入者）——偏偏是本 ADR 最核心的兩條。
- 列的主詞混用：#24 由 Host 執行，但它的 Onb＝N、Disc＝Y 指的是**斷線那個 peer 的狀態**（Host 永遠不會處於 Onboarding 或 Disconnected）；#9 的 Joining＝Y 指加入者，InShift／Settle 指 Host。D3「–」格在 Core 一律 `throw` 的規則若套在本機狀態上，會把這些列實作錯。
- D4 在 approval 時就指派 slot，但 Onboarding 期間斷線＝「視同從未加入」（#24 Onb＝N）——這種情況的 slot 回收路徑沒有定義（D4 唯一的回收點是 #24 第 4 步）。
- **Resolution**：逐列標出執行者與主詞（本機／受影響 peer）；列滿 32 列；補「Onboarding 期間斷線：釋放 slot、不發 `PlayerLeft`、不計 #15a」。

**E5 [🟡 MEDIUM] 預檢與 Lobby\* 的剩餘時間沒有共同時間基準**——State
- D5 以 session property 發布 `shift_end_ts` 供 UI 預檢；D13 的 `ShiftEndTs` 是 Host 單調時鐘（`IPageLifecycle.NowMs`＝`performance.now()`，原點是 Host 分頁載入時刻）。
- Lobby 與 Lobby\* 的端沒有 NGO 連線、沒有心跳 offset，拿到這個值無法換算。GDD Lobby\* 約束 (c) 卻要求「畫面必須同時可見前一班還剩多久」。
- **Resolution**：property 改發「發布當下的剩餘秒數」（或 `join_locked` 旗標），client 以收到時刻的本機單調時鐘錨定；必要時 Host 定期重發。精度約等於屬性傳播延遲，對非權威提示足夠。

**E6 [🟡 MEDIUM，必修] 心跳判定的 `PeerLost` 不切斷 NGO 連線**
- GDD #24 與 D7 都沒有呼叫 `NetworkManager.DisconnectClient`。心跳逾時或單向失效判定後，該 client 在 NGO 層仍是 connected client 與 observer，直到 UTP `DisconnectTimeoutMS`（30 s）。期間 Host 照樣對它複製；`NetworkConnectionManager.cs:592-596` 只看傳輸層是否連著，它送來的 RPC 會被照常處理，而 sender 在 `SlotOf()` 查不到（`NoSlot`），ADR 沒定這種情況怎麼辦。
- 推論（未實測）：`NoSlot` 與「無人」共用 255。若轉接層沒有明文丟棄這類 RPC，未被 claim 的站台可能被判給「無人」，卡到 5 s 保險絲。
- **Resolution**：第 4 步之後呼叫 `DisconnectClient(clientId, reason)`，reason **必須非空**——非空時 NGO 先送 `DisconnectReasonMessage`、再排入延後斷線佇列（`NetworkConnectionManager.cs:912-930`），不會在同一幀重入序列；空 reason 則同步斷線並重入。另明定「`SlotOf` 回 `NoSlot` 的 RPC 一律丟棄」。

**E7 [LOW] 離開通知的冪等寫錯了地方**
- D9：「服務端處理必須冪等（以 `(sessionId, playerId, nonce)` 去重）」；payload「皆附 nonce，服務端重複請求回 2xx 不報錯」。服務端是 UGS Lobby，不會認我們自訂的 nonce；對已刪除的 lobby 再送一次 `DELETE` 會回錯誤碼（效果冪等，回應不冪等）。
- **Resolution**：`pagehide`／`beforeunload` 雙觸發（相隔 1–24 ms）在送出端以 JS 單發旗標去重；第二次的 404 視為成功。

**E8 [🟡 MEDIUM，必修] 心跳 payload 照 Key Interfaces 寫不會過 ILPP**
- `HeartbeatPayload` 宣告在 `NightShift.Session.Core`（`noEngineReferences = true`），不能實作 NGO 介面，卻直接當 `SessionRoot` 的 RPC 參數。unity-specialist 核對 `NetworkBehaviourILPP.cs:2654,3194`：RPC 參數必須是 `INetworkSerializable`、`INetworkSerializeByMemcpy`，或有可解析的 `FastBufferWriter.WriteValueSafe<T>`，否則在 **ILPP 建置階段**就報錯。會大聲失敗，不是靜默，但 Key Interfaces 照寫不能編。
- **Resolution**：Core 的 struct 只加 `System.IEquatable<HeartbeatPayload>`（純 BCL，不違反 `noEngineReferences`）；`NightShift.Session.Unity` 的 RPC 簽章改收 `ForceNetworkSerializeByMemcpy<HeartbeatPayload>`（`ForceNetworkSerializeByMemcpy.cs:10`，約束 `unmanaged, IEquatable<T>`）。
- 大小也寫錯：「16 bytes」與型別不符，`ushort＋ushort＋long＋long` 邏輯上是 20 bytes；依預設 Sequential 佈局 8-byte 對齊，memcpy 實送 `sizeof`＝24 bytes。同一錯誤出現在 D6（:128）、Key Interfaces（:277）、registry `session_heartbeat`、netcode GDD :379。

**E9 [LOW] `SessionConfig.Validate()` 宣稱涵蓋約束①–⑮**
- 約束④（情境分析）、⑧（架構規則＋執行期 RTT）、⑭（AC 撰寫規則，GDD 自註「非數值不等式」）、⑮（執行期 RTT／region 模型）都不是組態不等式。可機械驗證的是①②③⑤⑥⑦⑨⑩⑪⑫⑬，共 11 條。T0 (f) 照字面無法實作。
- **Resolution**：列舉 11 條；其餘交 T1／T3 或 code review。

**E10 [LOW] 指派冷卻讓 `Full` 變得可達**
- T0 (e)「回收後 3.0 s 內不得重派同 slot」與 `SlotTable.Release` 註解「記錄回收時刻以保證 3.0 s 地板」，對上 D5 第 5 項「`Full`（理論上到不了，MPS 已擋）」。MVP 2 人房裡有人回收後 3 s 內重新加入，唯一的空位在冷卻中，於是被判 `Full`、看到「這班人滿了」。
- D4 自己的推理已靠更衣室過場（approval 到 `PlayerJoined` ≥ 3.0 s）保證間隔，顯式冷卻是多餘的。
- **Resolution**：拿掉指派冷卻，保留「`PlayerLeft` 先於同 slot 的 `PlayerJoined`」斷言。

**E11 [LOW-MEDIUM] Lobby\* 沙盒與 MPS 成員端自動加入共用同一個 `NetworkManager`**
- MPS `NetworkModule.cs:505-541`：成員端在 session 變更時，若網路屬性**值改變**且本機網路未啟動，就 `JoinNetworkAsync` 一次；`m_Property` 在嘗試前就更新，失敗不重試。這也是 V1「client 自動啟網」的機制（正面證據）。
- D10 讓 Lobby\* 沙盒在同一個 `NetworkManager` 上跑 NGO Host。若下一班的網路屬性出現時 `AbortSandbox` 尚未完成，自動加入會失敗且不重試，這位玩家就靜靜錯過整班。
- forbidden pattern `lobby_with_live_relay` 寫「Lobby／Lobby\* 期間不得存在 Relay allocation 或 NGO 連線」，與 D10 在 Lobby\* 跑本機 NGO Host 字面衝突。
- **Resolution**：新增 V11 驗證時序；client 在屬性觸發加入前斷言 `NetworkManager` 未在執行；forbidden pattern 改為「不得存在 Relay allocation 或對外 NGO 連線（Solo 沙盒的本機 Host 除外）」。

**E12 [LOW] 文件層缺漏與行號**
- GDD Requirements 對照表漏列實際覆蓋的 TR-netcode-010、014、TR-concept-002、TR-machine-001、049；Migration item 4 漏 FPC AC19 與 netcode GDD :794／:801／:807。
- Key Interfaces 的 `public const byte NoSlot` 寫在 namespace 層級（C# 不允許），而 machine GDD 已引用 `NoSlot = 255`——r1 應定它住在哪個型別。
- `RelayNetworkOptions` 三個 `[Obsolete]` 建構子實際在 `RelayNetworkOptions.cs:57、87、121`，ADR 引的 :258、288、322 不對（非 obsolete 的 :163 正確）。主審已抽查確認。
- D11 只映射 `IClientSessionNetwork.MigrationFailed`；`IHostSessionNetwork` 也有同名事件（`IHostSessionNetwork.cs:29`），應一併映射。

**E13 [NOTE] D9 的 teardown 順序會觸發 MPS 的警告，但無害**
- 先 `NetworkManager.Shutdown()` 再 `LeaveAsync()`：MPS 會記「Do not call NetworkManager.Shutdown when using a session. Use ISession.LeaveAsync instead.」（`NetworkManagerSession.cs:424`）；`LeaveAsync()` 內的網路模組動作與已執行的 `Shutdown()` 重疊，由 per-module try/catch 吞掉（`SessionHandler.cs:770-781`）。
- 這個順序有理由（`Shutdown()` 同步、對端 80 ms 得知；`LeaveAsync()` 在 unload 時多半送不出去），**應保留**。r1 註明這條警告是預期的，免得日後有人為了消警告把順序改掉。ADR-0005 的桌面退出路徑同理。

### 3D. 前一輪項目的現況

| 前一輪 | 內容 | 現況 |
|---|---|---|
| C1 BLOCKING | 身份編碼無轉換契約 | **裁決已解**（ADR-0006 D4）；傳播待 r1 → 改記為 X1 |
| C2 | registry `directed_pair_state.interface` 與 ADR-0003 消費入口不一致 | 不變（registry `revised` 仍空） |
| C3 | owner-write NV 掛在可轉移物件上的禁令未登記 | 不變 → G2 |
| C4 | 三份文件押在不存在的 CI 上 | 惡化：ADR-0006 D12 的建置期斷言成為第四個客戶 |
| C5 | product 分層與 ADR-0001 不一致 | 不變 → G4 |
| C6 | ADR-0005 R1 漏 pointer lock／`AudioContext` | 不變 → ADR-0005 r1 |
| D1 | ADR-0002 與 machine C20 分叉 8 處 | 不變 → ADR-0004 |
| D2 | Host claim 公平窗口 | ADR-0006 提供數字，裁決仍歸 ADR-0004 |
| D3 | `interpolation_buffer_ms = 150` | **不變**：netcode GDD :1188／:1256／:1433、FPC GDD :634／:638／:642／:655／:1009／:1036、`entities.yaml:1460` 原封未動 |
| D4 | `remote_step_tolerance` 無 ADR | 不變 → G8 |
| D5 | registry 漂移 | 新增兩條：`session_heartbeat` 的「16 bytes」、`session_events` 的消費者指派（X5） |
| D6 | 約束⑧ 兩種讀法 | 不變 → G2 |
| D7／D8 | ADR-0005 與 W1 實測不符（referrer、pagehide） | 已由 ADR-0006 宣告為 ADR-0005 r1 義務 → X2／X3 |
| D9／D10 | OQ-M14 雙擁有者；`ICheckoutCustomerQuery` 漏列 | 不變 |
| specialist 前一輪 | ADR-0001 D8 `UseQuaternionSynchronization`、ADR-0005 D3 asmdef `"WebGL"` 字串、ADR-0001 D2 動態 Rigidbody | 不變（ADR 未改） |

---

## 4. GDD Revision Flags（Phase 5b）

### 延續（前一輪標出、本輪仍未處理）

| GDD | 假設 | 嚴重度 |
|---|---|---|
| `netcode-session.md` | `interpolation_buffer_ms = 150`（:1188、:1256、AC23 :1433 GIVEN） | 🔴 HIGH |
| `first-person-controller.md` | F1 `L_p95 = 0.339` 含 150 ms 項；`player_move_speed_max = 1.47` 須重推 | 🔴 HIGH |
| `first-person-controller.md` | :61 頭註「本系統不引用任何 ADR」 | LOW |
| `machine-interaction.md` | OQ-M14 第 6 項已由 ADR-0005 承接 | LOW |
| `game-concept-night-shift.md` | 體積未標單位、「Unity Relay + Lobby」、「CLAUDE.md 釘的是 Godot 4.6」 | LOW |
| `systems-index.md` | 「19 個系統」 | LOW |

### 本輪新增

| GDD | 假設 | 現實（ADR／原始碼） | 行動 | 嚴重度 |
|---|---|---|---|---|
| `netcode-session.md` | #24 前置條件（:580-592）只要求**可攜道具** `DontDestroyWithOwner = true`；序列第 2 步「掉落」排在第 5 步「despawn avatar」之前 | NGO 2.13.2 `NetworkConnectionManager.cs:1366-1392`：PlayerObject 在 `!DontDestroyWithOwner`（預設）時，於 `OnClientDisconnectCallback`（:1567）**之前**就被 despawn。Host 端子物件被 NGO 移到根節點而存活；**client 端沒有這層保護**（`NetworkSpawnManager.cs:1664,1714`），掛在手部 socket 的道具隨 avatar 消失；Host 端的 unparent 在 `AutoObjectParentSync = false`（machine C13）下也不會複製出去 | 前置條件補「avatar prefab 亦須 `DontDestroyWithOwner = true`」；第 2 步明定「掉落須在第 5 步的 despawn 訊息之前對所有 client 可見」，複製途徑交 G2 | 🔴 HIGH |
| `first-person-controller.md` | :397-399「狀態實例必須以玩家 id 為鍵，不得以 slot 為鍵」；AC19（必達 T0）標題「以玩家 id 為鍵，不以 slot 為鍵」 | ADR-0006 D4：玩家鍵＝slot（`PeerKey`）；「不繼承」改由 `PlayerLeft(slot)` 必清＋同 slot 的 `PlayerJoined` 至少相隔 3.0 s 保證 | 規則改寫為「以 `PeerKey` 為鍵；`PlayerLeft(slot)` 時清除該 slot 的一切條目」；AC19 改名為「slot 重用不繼承」，THEN 子句不變（它本來就在測結果） | 🟡 MEDIUM |
| `netcode-session.md` | #9 :161 UI 預檢讀 MPS custom data 的 `shift_end_ts`；Lobby\* 約束 (c) :776「畫面必須同時可見前一班還剩多久」 | ADR-0006 D13：`ShiftEndTs` 是 **Host 單調時鐘**（`performance.now()`，原點＝Host 分頁載入時刻）。Lobby／Lobby\* 的端沒有 NGO 連線，也就沒有心跳 offset，無法換算 | property 改發「發布當下的剩餘秒數」或 `join_locked` 旗標；client 以收到時刻的本機單調時鐘錨定。精度約等於屬性傳播延遲，對非權威提示足夠 | 🟡 MEDIUM |
| `netcode-session.md` | OQ#4（:1650）、OQ#18（:1665）仍列為未決；#24a 未補「NGO approval 二次驗證 `PlayerId` 必為 MPS 成員」；`max_players` 型別註記未補 | ADR-0006 D10／D11／D5 已裁決；ADR-0006 Migration item 4 自列為 GDD r5 回填，尚未做 | 標已裁決並指回 ADR-0006 | LOW |
| `netcode-session.md` | :379 心跳 payload「16 bytes」 | ADR-0006 的型別 `ushort＋ushort＋long＋long` 合計 20 bytes | 改數字或改型別 | LOW |
| `machine-interaction.md` | C13（:220-221）`AutoObjectParentSync = false` 為 prefab 契約、禁 `TrySetParent()`、零位置同步 | 這使任何 Host 端的 unparent（斷線掉落）都不會複製到 client（§3C E1） | C13 註明「斷線掉落的複製途徑由 G2 提供」，避免 G2 與 C13 各自以為對方負責 | LOW |
| `netcode-session.md` | :794 輸入訊號表「`beforeunload`＋`sendBeacon`」；:801「`InteractResult(stationId, clientId, …)`」；:807「`RequestHandoff(itemId, targetId)`」 | ADR-0006 D9 改 keepalive fetch＋headers＋`pagehide`；D4 遊戲層玩家鍵＝slot；machine C20 已取代 :801 的 RPC 形狀 | 同步三列表格 | LOW |

`systems-index.md` 的 #1／#2／#3 已在前一輪標為 **Needs Revision**；本輪在備註欄補上新增的三條（#24 avatar 前置條件、AC19 鍵型別、預檢時間基準），已依 §8 裁決寫入。

---

## 5. Engine Compatibility（Phase 5）

### Engine Audit Results

Engine：Unity 6.3 LTS (6000.3)／NGO 2.13.2／MPS 2.3.1／UTP 2.7.4（套件 `package.json` 實讀）
ADRs with Engine Compatibility section：**5 / 5**

- **Deprecated API References**：ADR-0006 **零命中**（只用通用 `[Rpc]`、不 override `NetworkTransform.Update`、走 MPS Sessions）。
  - 觀察：離開通知直打 UGS Lobby REST（`DELETE lobbies/{id}`、`DELETE lobbies/{id}/players/{playerId}`）。這不是棄用表上的「獨立 Lobby 套件 API」，但它繞過 Sessions SDK，把「session id ＝ lobby id、REST 路徑、Bearer 授權」變成沒有編譯期保護的契約，MPS 升版時不會報錯。建議登記進 registry `api_decisions` 並留在 V10。
- **Stale Version References**：無。只有 ADR-0006 把 UTP 釘到 2.7.4，其他寫 2.x，彼此相容。
- **Post-Cutoff API Conflicts**：ADR 之間無相反假設（`RpcTarget.Single(…, RpcTargetUse.Temp)` 與 ADR-0002 一致；`NetworkVariable` 預設 Server 寫與 ADR-0003 的顯式 Owner 寫各自正確）。**但 ADR-0006 與引擎原始碼有四處不符**：E1（斷線處置先後與 client 端子物件）、E8（RPC 參數型別過不了 ILPP）、E3（內建 `SinglePlayerTransport`）、E11（MPS 成員端自動加入）。
- **C# 層**：ADR-0006 Key Interfaces 的 `public const byte NoSlot = byte.MaxValue;` 寫在 namespace 層級，C# 不允許（CS0116）。屬示意碼錯誤，但 machine GDD 已引用 `NoSlot = 255`，r1 應定它住在哪個型別。其餘符合 C# 9。

### 參考庫本輪新增的缺口

| 檔 | 問題 | 影響 |
|---|---|---|
| `modules/multiplayer.md` | 未記載 NGO 2.4.0 起內建的 `SinglePlayerTransport` | ADR-0006 因此手刻了一個（E3） |
| `modules/multiplayer.md` | 未記載 MPS 成員端的自動加入機制（`NetworkModule.cs:505-541`），也未記載「在 session 中呼叫 `NetworkManager.Shutdown()` 會被 SDK 警告」（`NetworkManagerSession.cs:411-428`） | V1 與 D9 的 teardown 順序在參考庫內無法驗證 |
| `modules/multiplayer.md` :124-140 | 「房間碼流程」範例在建 session 時就 `WithRelayNetwork()` | 正是 registry `lobby_with_live_relay` 禁止的寫法；範例應加註 |
| `modules/multiplayer.md` :63-74 | 已正確記載「處置發生在 `OnClientDisconnectCallback` 之前」 | ADR-0006 D7 沒有引用它（E1）——參考庫是對的，ADR 沒跟上 |
| 延續 | `current-best-practices.md` 的 Brotli、`web.md` 50 vs 44 MB、`networking.md` 的 NGO 1.x 範例、`physics.md` 缺 CC 旗標、`input.md` 引 1.11、`VERSION.md` 驗證日期 | 不變 |

### Engine Specialist Findings（unity-specialist）

unity-specialist 以 4 個平行分支對 NGO／MPS／UTP 原始碼獨立查證、交叉比對。主審依其建議抽查 F3、F5、NEW-1、F9(d) 與 V2 的原始碼行，全部吻合。

| 項 | 結論 | 證據（`prototypes/w1-netcode/Library/PackageCache/`） | specialist 嚴重度 | 主審裁定 |
|---|---|---|---|---|
| F1 | 手刻 `OfflineTransport` 功能上安全；仍建議改用官方 `SinglePlayerTransport` | `NetworkManager.cs:1501-1537`；`NetworkBehaviour.cs:121-140,242-253` | CONCERN | 採納；E3 降為 LOW |
| F2 | avatar 預設在回呼前就被 despawn；Host 端子物件被移到根節點而存活 | `NetworkConnectionManager.cs:1344-1392`；`NetworkSpawnManager.cs:1714-1761` | BLOCKING-for-Accept | 採納，併入 E1 |
| NEW-1 | client 端沒有「移到根節點」的保護，手持物隨 avatar 消失，Host 與 client 不一致 | `NetworkSpawnManager.cs:1664-1679` 與 :1714 的 `IsServer` 條件；`DestroyObjectMessage.cs:122-166` | BLOCKING-for-Accept | 採納（主審抽查確認），併入 E1 |
| F3 | 心跳觸發的 `PeerLost` 須呼叫 `DisconnectClient(clientId, reason)`；reason 非空時先送原因、再延後斷線，不會同幀重入 | `NetworkManager.cs:1569,1577`；`NetworkConnectionManager.cs:592-596,917-927,1600-1627` | BLOCKING-for-Accept（兩分支分歧，從嚴） | 採納為必修；主審評 MEDIUM（E6） |
| F4 | Host 本機的 approval 會跑，但拒絕只記警告就照樣核准 | `NetworkManager.cs:1499-1518` | BLOCKING-for-Accept | 採納（E2） |
| F5 | `HeartbeatPayload` 過不了 ILPP；修法＝Core 加 `IEquatable`、轉接層用 `ForceNetworkSerializeByMemcpy<T>`；邏輯 20 bytes、memcpy 24 bytes | `NetworkBehaviourILPP.cs:2654,3194`；`ForceNetworkSerializeByMemcpy.cs:10` | BLOCKING-for-Accept | 採納為必修；主審評 MEDIUM，因為它會在建置期大聲失敗（E8） |
| F6 | `SessionState`／`RejectReason` 分屬不同命名空間，單獨不構成編譯碰撞 | MPS `SessionState.cs:6-24` | NOTE | 採納；X4 維持 LOW（同檔同時 using 兩個命名空間時才撞） |
| F7a | `SessionMigrated`、`MigrationFailed`（client 與 host 兩側都有）、`NetworkState.Migrating` 都存在；MPS 設 Relay 時只呼叫 `SetRelayServerData`，不覆寫 D12 的 UTP 常數 | `SessionHandler.cs:305,556,1250,1252`；`IClientSessionNetwork.cs:29`；`IHostSessionNetwork.cs:29`；`NetworkState.cs:31`；`GameObjectsNetcodeNetworkHandler.cs:166-189` | NOTE（正向） | V9「MPS 是否覆寫常數」結案；host 側 `MigrationFailed` 補進 D11（E12） |
| F7b | approval 拒絕先送 `DisconnectReasonMessage` 再斷線，遠端可讀 `NetworkManager.DisconnectReason`；`MaxSendQueueSize` 預設 0，此時由 `DisconnectTimeoutMS` 推算；`RosterState`／`RosterEntry` 的介面組合合規 | `NetworkConnectionManager.cs:889,917-927`；`NetworkManager.cs:659`；UTP `UnityTransport.cs:142,154-157,1578-1591`；`NetworkParams.cs:31,39,47`；`NetworkBehaviourILPP.cs:359-372` | NOTE（正向） | **V2 由「待查證」改為「原始碼已證實」**，仍建議 T1 (h) 實跑一次；V6、V9 的欄位名與預設值結案 |
| F8 | `SessionRoot` spawn 前送到的心跳 RPC 進 deferred 佇列，spawn 後重放（`SpawnTimeout` 10 s） | `RpcMessages.cs:22-25`；`DeferredMessageManager.cs:32-67,132-150`；`NetworkConfig.cs:147-148` | NOTE | 採納，不列缺陷 |
| F9 | (a)(b) 無誤；(c) `Shutdown()` 與 `LeaveAsync()` 的網路動作重疊但無害；(d) Obsolete 建構子行號引錯 | `SessionHandler.cs:770-820`；MPS `RelayNetworkOptions.cs:56-57,86-87,120-121` | CONCERN (c)／NOTE | (c)→E13；(d)→E12（主審抽查確認） |
| NEW-2 | 掉落後若在 6 tick（10 Hz 下 600 ms）內被撿起，觸發快速所有權變更警告，owner-write NV 可能遺失 | NGO `k_MaximumTickOwnershipChangeMultiplier = 6`（`multiplayer.md` 已記載） | CONCERN | 歸 G2／ADR-0004；TR-netcode-006 已有 ≥ 6 tick 的要求 |

**specialist 總評（摘要）**：ADR-0006 的 API 存在性幾乎全數查證正確，誤差多在行號與位元數這類文件精確度，不影響拓撲與分層方向。F2＋NEW-1、F3、F4、F5 四項會讓系統在最基本的情境下失效，但都是局部修法：設一個 bool、補一次呼叫、換一個包裝型別、協調一個旗標。四項補上修法與對應的 T1 測試後，ADR-0006 即可 Accept。

---

## 6. Architecture Document Coverage（Phase 6）

`docs/architecture/architecture.md` 仍不存在，`control-manifest.md` 也不存在。建議在 G2、ADR-0004、G4 落地後跑 `/create-architecture`。

---

## 7. Verdict

### **FAIL**（覆蓋率仍失敗；ADR-0006 讓 netcode 的 Foundation 缺口 9→1，但商品資料庫 13 條與機台 4 條 Foundation 缺口未動，且 ADR-0006 本身有四條 Accept 前必修）

依本 skill 判準「FAIL：Foundation／Core 層需求無 ADR，或有 blocking 的跨 ADR 衝突」。Foundation 層仍有 **20 條 Gap**。跨 ADR 衝突全部是「已宣告、待 r1 傳播」的型態（X1–X3），沒有哪兩份 ADR 對同一件事做出無人收拾的相反決定；但 X1 在傳播前擋住 0001／0002／0003 的 Accept。

**這一輪的進展是真的**：ADR-0006 把前一輪唯一的 BLOCKING（身份契約）在裁決層面解掉，netcode 從 7 條 ✅ 升到 25 條，而且它的大多數決策都能回指到 W1 實測或套件原始碼。**失敗的是覆蓋與傳播，不是 ADR-0006 的方向。**

### Blocking Issues（解除後方能 PASS）

1. **Foundation 無 ADR**（共 20 條）：G4（product-001–005、014、016）、G5（product-018、020–022；machine-054）、G6（product-006、007）、G2（netcode-033；machine-010、027）、G7（fpc-029）、G8（fpc-040）、ADR-0004（machine-023）。
2. **ADR-0004 未寫**，ADR-0002 與 machine C20 的 8 處分叉不變（前一輪 D1）。
3. **`interpolation_buffer_ms` 模型錯誤仍在兩份 GDD 的數值骨幹裡**（§4 延續）。
4. **身份契約已裁決、未傳播**（X1）：0001／0002／0003 的 Key Interfaces 違反 active forbidden pattern `clientid_as_player_identity`；FPC AC19 字面與 ADR-0006 相反。
5. **潛在依賴環**（§3B）：ADR-0001 r1 一落地就成環，必須先改 ADR-0005 的依賴邊、並把 NPC id 值域收歸 ADR-0006。
6. **ADR-0006 r1 的四條必修**（§3C）：E1 斷線時手持物在 Host 存活、在每個 client 消失；E2 Solo 的 approval 被 NGO 靜默強制核准、`SlotTable` 沒有 slot 0；E6 心跳判定的斷線不切 NGO 連線，鬼連線的 RPC 可被處理達 30 s；E8 心跳 payload 照 Key Interfaces 寫過不了 ILPP。

### Non-blocking（CONCERNS，進 PASS 前應收斂）

§3C E3–E5、E7、E9–E13；§3A X2–X5；§3D 延續的 C2–C6、D4–D6、D9／D10；前一輪三條 specialist CONCERN／NOTE；§5 參考庫缺口。

### Required ADRs（最 Foundation 者優先）

| 序 | ADR | Layer | Engine Risk | 理由 |
|---|---|---|---|---|
| 1 | **ADR-0006 r1 ＋ ADR-0005 r1**（成對） | Foundation | HIGH | 必修 E1、E2、E6、E8；應修 E4、E5；X2／X3、依賴邊改向（§3B）；V1／V3／V10 列入 W2 第一批（V2 已由原始碼證實） |
| 2 | **ADR-0001／0002／0003 r1** | Core | — | X1 身份傳播＋前一輪各自的待補項 |
| 3 | **G2** 同步物件生命週期與所有權轉移 | Foundation／Core | HIGH | 15 條 TR（3 條 Foundation Gap）；必須登記 avatar `DontDestroyWithOwner = true`、掉落對 client 可見的途徑、owner-write 禁令 |
| 4 | **ADR-0004** 機台互動組 Core | Core | MEDIUM | 29 條 TR（含 ADR-0006 明確交棒的 machine-019 其餘觸發源、045、index-021 公平窗口、022 租約）；吸收 ADR-0002 的 8 處分叉 |
| 5 | **G4** SKU 資料格式與序列化凍結 | Foundation | MEDIUM | 16 條 TR，其中 7 條是 Foundation Gap；可併 G6 |
| 6 | **G8** 延遲模型與容差 | Core | HIGH | 解 §4 的兩條 HIGH GDD 旗標 |
| 7 | **G5** 建置期資料治理閘門與 CI | Foundation | MEDIUM | 現有四個客戶押在同一塊不存在的 CI 上 |
| 8 | **G7** 攝影機與渲染基線 | Core／Pres | HIGH | 近裁面錯一格，安全速度掉 40% 且症狀被歸因成網路 |
| 9 | **G6** 資產繫結與載入 | Foundation | MEDIUM | 2 條 Foundation Gap（product-006、007）；可併 G4 |
| 10 | **G9** 遊戲時鐘與班次時基 | Foundation | LOW | 先 `/design-system 遊戲時鐘` |

---

## 8. arlong 裁決（Phase 8，2026-10-01）

| 問題 | 裁決 |
|---|---|
| 寫入範圍 | 三份都寫：本報告另存 `architecture-review-2026-10-01-r2.md`（上午那份保留）；`traceability-index.md` 就地更新；`tr-registry.yaml` 升 version 3，更新 33 條狀態、修訂 4 條措辭 |
| TR-netcode-046 | **新增**：「未建 NGO 連線的端（Lobby 預檢、Lobby\* 等待畫面）須能顯示班次剩餘時間；表示法不得依賴心跳 offset」，⚠️ Partial（§3C E5） |
| `systems-index.md` | #1／#2／#3 的 Needs Revision 備註補上本輪三條新旗標，狀態字串不動 |
| 下一步 | 新 session 修 **ADR-0006 r1＋ADR-0005 r1**（成對），之後重跑 `/architecture-review` |

---

## 附錄 — 本輪狀態或理由有變的列（完整矩陣見 `traceability-index.md`）

| ID | 需求（摘） | Layer | 首輪 | r2 | ADR | 理由 |
|---|---|---|---|---|---|---|
| TR-netcode-001 | Host 權威：NPC／波次／計分／班次時鐘／共用道具／結算 | Foundation | ⚠️ | ✅ | 0006/0003 | ADR-0006 D1 正式裁決 client-as-host（Host＝權威）；D13 `ShiftEndTs` Host 寫；NPC 權威 0003 |
| TR-netcode-007 | 房間碼＝`session.Code`，大小寫不敏感、可貼上；輸碼必備備援；帶碼連結須解析 … | Feature | ⚠️ | ⚠️ | 0005（0006 r1 義務） | 房間碼走 `JoinSessionByCodeAsync`（0006 D2）；`document.referrer` 只列在 0006 Migration 給 0005 r1 的義務，0005 本文仍寫父頁 query（X3） |
| TR-netcode-008 | 截止閘門唯一執行點＝`ConnectionApprovalCallback`，Host 側… | Core | ❌ | ✅ | 0006 | 0006 D5 判定順序第 4 項（含端點）；預檢非權威。預檢的時間基準有缺陷，見 §3C E5 |
| TR-netcode-009 | approval payload 帶 build/protocol version，不符即… | Core | ❌ | ✅ | 0006 | 0006 D5 payload（`PayloadVersion`／`ProtocolVersion`／`BuildId`）＋第 1 項 `StaleBuild` 先於任何資料交換 |
| TR-netcode-010 | Host 關頁＝局終（無 migration）；`beforeunload`+`pageh… | Core | ⚠️ | ✅ | 0006（＋0005 r1） | 0006 D9 `pagehide`＋`beforeunload` 雙掛、keepalive fetch、冪等；D11 無 migration。冪等寫成「UGS 以 nonce 去重」不可行，見 §3C E7 |
| TR-netcode-011 | 進房預算 T_load≤25／T_lobby≤10／T_spawn≤10 各自硬閘門；au… | Foundation | ❌ | ⚠️ | 0006 | 0006 D14 `T_lobby`／`T_spawn` 為 Core 狀態計時＋`MaxConnectAttempts=10`；`T_load` 只有 stall 偵測（TR-026 仍 Partial）；auth 預熱並行未定 |
| TR-netcode-012 | 離線立即重取樣 `online_player_count`；grace／`host_sol… | Core | ❌ | ✅ | 0006 | 0006 D7 第 7 步重取樣＋grace／`host_solo`；D4 #15a 以 `PlayerId` 為鍵、班次範圍；D13 `OnlinePlayerCountChanged` |
| TR-netcode-013 | `visibilitychange` 於 `.jslib` 以 `performance.… | Core | ⚠️ | ⚠️ | 0005/0006 | >5 s 分支已是 0006 D9 的 Teardown 邊；≤5 s 的公式③ catch-up 仍無擁有者（G9） |
| TR-netcode-014 | teardown 不變式：任何 InShift→Idle 先 `Shutdown()`+`… | Core | ⚠️ | ✅ | 0006 | 0006 D9：每條進 Idle 的邊恰一個 `Teardown` 效果，固定順序 `Shutdown()`→`LeaveAsync()`／`DeleteAsync()`→切 UI（與 MPS 警告的關係見 §5） |
| TR-netcode-015 | Host 消失排歧：MPS 層與 Relay 層獨立；序：session 事件→`onLi… | Core | ⚠️ | ✅ | 0006 | 0006 D8 `HostLossDisambiguator` 實作 GDD 六列優先表 |
| TR-netcode-017 | app 心跳 2s/8s 自 NGO 連線起；payload `{seq,last_pee… | Foundation | ❌ | ✅ | 0006 | 0006 D6 全條（`SessionRoot` 承載、Unreliable RPC、4 拍單向失效、EMA offset）；payload 實為 20 bytes 非 16，見 §3C E8 |
| TR-netcode-018 | UTP send queue 溢位防護：Host 每 tick payload 上限＋佇列… | Foundation | ❌ | ⚠️ | 0006 | 0006 D12 `MaxSendQueueSize` 顯式＋監控點必備；值與 Host 出站上限待 `[P-16]`（V6，W2） |
| TR-netcode-019 | Lobby 延後建連：`WithNetworkOptions(WSS)` 不啟動；開始上班… | Foundation | ⚠️ | ✅ | 0006 | 0006 D2 兩層壽命＋forbidden `lobby_with_live_relay`；V1 client 自動啟網待驗（MPS `NetworkModule.cs:505-541` 顯示機制存在） |
| TR-netcode-021 | UTP 常數契約：`HeartbeatTimeoutMS=500` 不得動（兼 Relay… | Foundation | ❌ | ✅ | 0006 | 0006 D12 常數表＋registry `utp_constants_contract` |
| TR-netcode-023 | 道具 `DontDestroyWithOwner=true`、Host 自行 unpare… | Core | ❌ | ⚠️ | 0006（＋G2） | 0006 D7 定序與 2 s 上限；第 2／5 步語意歸 G2。`OnClientDisconnectCallback` 觸發源下 NGO 已先處置 avatar，順序不成立，見 §3C E1 |
| TR-netcode-024 | MPS 成員唯一寫入者＝Host（`AsHost().RemovePlayerAsync`… | Core | ❌ | ✅ | 0006 | 0006 D7 第 6 步 `RemovePlayerAsync`（Host 唯一寫入者）；`SlotTable.OnlineCount` 與 `session.PlayerCount` 分離 |
| TR-netcode-025 | Lobby Host 離開＝訂閱 `ISession` 事件＋本地 `lobby_host… | Core | ❌ | ✅ | 0006 | 0006 D8 末段：Lobby 訂閱 `ISession` 事件＋Core 計時 30 s，不等服務端 |
| TR-netcode-027 | Relay region 貼著 Host：`.jslib` `Intl` 查表→fallb… | Core | ⚠️ | ⚠️ | 0005/0006 | 0006 D2 定 `IRegionSelector`→`RelayNetworkOptions(region)` 於 #26；跨區降級契約（AC22a）仍無 |
| TR-netcode-028 | 狀態機 11 態＋適用性矩陣；Disconnected 僅由 InShift 進入；Lob… | Core | ❌ | ⚠️ | 0006 | 0006 D3 12 態＋守衛表；但矩陣實為 32 列 × 11 欄、列的主詞混用本機與受影響 peer、Onboarding 期間斷線的 slot 回收未定，見 §3C E4 |
| TR-netcode-029 | 本層輸入訊號表（NGO 四 callback、MPS 事件、瀏覽器三組）＋下游 11 系統… | Core | ⚠️ | ⚠️ | 0006/0002/0003/0005 | 0006 D13 `session_events` 補齊大部分下游；`local_ready` 未定義；GDD :801 契約列仍用 clientId |
| TR-netcode-031 | 單一場景、不啟用 `NetworkSceneManager`；更衣室為本地 UI 疊層、定… | Foundation | ❌ | ⚠️ | 0006 | 0006 D1 `EnableSceneManagement=false`；D4 依賴更衣室 3.0 s 下限；「同步未完仍進場」runtime 規則無 ADR |
| TR-netcode-035 | 重連身分 `PlayerId`↔slot 自建對照（ClientId 會變）；Post 重… | Core | ❌ | ✅ | 0006 | 0006 D4 identity 契約：`PlayerId↔slot↔clientId`、MVP 重連＝新加入；Post-MVP 保留窗口列 V8 |
| TR-netcode-036 | 班次時鐘真相＝Host `shift_end_ts` NetworkVariable；`e… | Core | ❌ | ✅ | 0006 | 0006 D13 `SessionRoot.ShiftEndTs`（Host 寫 NV）；`end_shift_early` 直接改寫 |
| TR-netcode-039 | 上游 UGS 初始化／匿名登入失敗→ServiceError；單人模式不經 UGS | Foundation | ❌ | ✅ | 0006 | 0006 D10 Solo 零 UGS；`ServiceError` 後仍可玩。Solo 的 approval 路徑有缺陷，見 §3C E2 |
| TR-netcode-040 | 退路 plan B：Distributed Authority（官方 Web 支援）／自架… | Foundation | ❌ | ✅ | 0006 | 0006 D1 兩條退路與觸發條件 |
| TR-netcode-041 | 常數 data-driven 登錄 registry；約束①–⑮ 非法組態應可機械驗證 | Foundation | ❌ | ✅ | 0006 | 0006 D12 `SessionConfig`（由 registry 生成）＋`Validate()`；④⑧⑭⑮ 不是組態不等式，見 §3C E9 |
| TR-netcode-044 | 測試分層：EditMode 純邏輯（心跳／公式③④／排歧／世代）；PlayMode 多實例… | Foundation | ⚠️ | ⚠️ | 0006/0001/0002/0003/0005 | 0006 D3 `Session.Core`（noEngineReferences）＋T0／T1／T1-Web 分層補上 session 核心；公式③ 歸屬與測試鉤子的 build flag 隔離仍未定 |
| TR-netcode-045 | `connection_state` 枚舉→店語字串表 data-driven，禁技術詞 | Presentation | ❌ | ✅ | 0006 | 0006 D13 `ConnectionState` 為 UI 唯一連線狀態來源，店語表 data-driven |
| TR-fpc-011 | 狀態實例以玩家 id 為鍵非 slot；一端 despawn 銷毀兩實例；無膠囊不建實例 | Core | ✅ | ⚠️ | 0001/0003 ⟂ 0006 | 0001／0003 以玩家 id 為鍵（符合 GDD）；0006 D4 改以 slot（`PeerKey`）為鍵。「不繼承」的意圖由 `PlayerLeft(slot)` 必清＋3.0 s 地板保住，但 GDD :397-399 與 AC19 字面相反，見 §3A X1、§4 |
| TR-fpc-027 | 過場結束即可移動（netcode AC40）；`local_ready`＝已有可收輸入的角… | Feature | ⚠️ | ⚠️ | 0001/0006 | OQ-F8 已由 0006 D1 回答（單一場景、`EnableSceneManagement=false`）；`local_ready` 訊號仍未定 |
| TR-fpc-028 | 與 #2 事件介面：送 `local_ready`、消費 `player_joined/l… | Feature | ⚠️ | ⚠️ | 0003/0006 | 0006 D13 `PlayerJoined/PlayerLeft(slot)`、D7 `FreezeInput` 參與者；`local_ready` 與過場／結算期間誰翻 `adoptInput` 仍無 ADR |
| TR-machine-001 | `ClaimState{bool IsClaimed; ulong ClaimedBy; … | Foundation | ✅ | ✅ | 0006（型別）/0002 | GDD :268 已改 `byte ClaimedBy`（slot）並註「型別歸 ADR-0006」；0006 D4 定案。0002 Key Interfaces 仍為 `ulong`，待 r1（X1） |
| TR-machine-019 | 強制釋放（保險絲／斷線／走開／E0.3）只放 claim：`IsClaimed→false… | Core | ❌ | ⚠️ | 0006（＋ADR-0004） | 0006 D7 第 3 步：斷線只釋放 claim、`ClaimGeneration+1`、不判 Failed；D13 `ShiftEndTs`。其餘觸發源（保險絲／走開／E0.3）與 `Restocking→Idle` 歸 ADR-0004 |
| TR-machine-020 | `ClaimGeneration` 每次 true→false +1、`Idle→Clai… | Core | ⚠️ | ⚠️ | 0002/0006 | 0006 D7 第 3 步重申斷線路徑 +1；完整遞增規則與仲裁仍歸 ADR-0004 |
| TR-machine-045 | 時基 `ServerTime.Tick`（`WorkStartTick`）與 `shift… | Foundation | ❌ | ⚠️ | 0006（＋G9／ADR-0004） | 0006 D13 `ShiftEndTs` 真相；`ServerTime.Tick` 時基與「班次結束拒收站台 RPC」未定 |
| TR-machine-049 | 斷線實走保險絲（Host 判定 8–87 s）；「強制釋放 ≤ 2 s」為判定後預算；Ho… | Foundation | ❌ | ✅ | 0006 | 0006 D6 心跳 8 s 判定、D7 判定後 ≤ 2 s 全序列、Host 自身消失不跑序列 |
| TR-product-026 | 兩端 SKU 表一致性依 `[P-17]` 版本 token，其粒度須涵蓋純內容變更（或自… | Core | ❌ | ⚠️ | 0006 | 0006 D5 `BuildId`＝建置期內容雜湊，版本不符於 approval 拒絕；雜湊輸入是否含 `ProductCatalogAsset` 未明寫；dev build 以 0 放行 |
| TR-concept-001 | Web/WebGL、開連結＋房間碼即玩、進房 ≤60 s | Foundation | ⚠️ | ⚠️ | 0005/0006 | 0006 D14 `T_lobby`／`T_spawn` 硬閘門；`T_load` 只有 stall 偵測 |
| TR-concept-002 | 2–4 人（MVP 2）、一班 8–10 分、連續值班 30–90 分 | Foundation | ⚠️ | ✅ | 0006/0003 | 0006 Constraints：`max_players` 容器按 4、MVP 2；D2 session 跨班次存活（連續值班） |
| TR-concept-007 | 兩段式節奏：波次導演＋遊戲時鐘（含突發事件） | Feature | ❌ | ⚠️ | 0006 | 0006 D13 定時鐘真相與複製（`ShiftEndTs` NV＋心跳 offset）；波次導演無 ADR，#9 遊戲時鐘無 GDD |
| TR-concept-009 | 房間碼進房、大廳、斷線重連；Session 走 MPS Sessions | Foundation | ⚠️ | ✅ | 0006 | 0006 D2 房間碼／大廳兩層會談；D4 MVP 重連＝新加入；D8 Lobby Host 離開 |
| TR-concept-010 | 斷線基本保障（MVP）：偵測、物品掉落、站台解鎖、留守者降載 | Core | ⚠️ | ⚠️ | 0006（＋G2／ADR-0004） | 偵測（0006 D6）與降載（D7 第 7 步）已定；掉落歸 G2、解鎖歸 ADR-0004 |
| TR-concept-012 | NGO client-server ＋ Relay ＋ Sessions、client-h… | Foundation | ⚠️ | ✅ | 0006 | 0006 D1 正式裁決拓撲 |
| TR-index-018 | 版本 token 涵蓋純內容變更；兩平台同版本同時發版 | Platform | ⚠️ | ⚠️ | 0005/0006 | 0006 D5 `BuildId` 內容雜湊即「涵蓋純內容變更」的版本 token；雜湊輸入範圍未明寫 |
| TR-index-021 | 撲空對稱：房主永不撲空 | Core | ❌ | ⚠️ | 0006（數字） | 0006 只提供數字（Host 自身 RPC 零往返、同區單程 ≈ 44–47 ms）；公平窗口的裁決歸 ADR-0004 |
| TR-index-022 | claim 租約續期（每次接受動作 RPC 重設）；到期只釋放 claim | Core | ⚠️ | ⚠️ | 0002/0006 | 0006 D7 第 3 步：斷線只釋放 claim；租約續期語意歸 ADR-0004 |
| TR-index-027 | #20 平台鉤子：region／背景分流／sendBeacon／帶碼連結↔Rich Pre… | Platform | ⚠️ | ⚠️ | 0005/0006 | 心跳已由 0006 D6 承接；離開通知改 keepalive fetch＋headers 待 0005 r1；Rich Presence 歸 Alpha |
| TR-netcode-046（r2 新增） | 未建 NGO 連線的端（Lobby 預檢、Lobby\* 等待畫面）須能顯示班次剩餘時間；表示法不得依賴心跳 offset | Core | — | ⚠️ | 0006 | 0006 D5 以 session property 發布 `shift_end_ts`，但 `ShiftEndTs` 為 Host 單調時鐘基準，無 offset 的端無法換算，見 §3C E5 |
