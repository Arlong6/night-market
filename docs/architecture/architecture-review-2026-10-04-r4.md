# Architecture Review Report r4 — 大夜班 (Night Shift)

> **Date**: 2026-10-04（觸發＝ADR-0006 r2＋ADR-0005 r2 寫入，commit `b46a8f0`）
> **Mode**: `/architecture-review` full（增量審查：只有 3 個輸入變動，其餘延續 r3 判定並逐列重判受影響的列）
> **Engine**: Unity 6.3 LTS（6000.3.24f1）、C# 9.0、IL2CPP＋Managed Stripping High、Web (WebGL)；NGO 2.13.2、MPS 2.3.1、UTP 2.7.4（PackageCache 實際解析值）
> **GDDs Reviewed**: 5（`netcode-session.md` #1/#2、`first-person-controller.md` #3、`machine-interaction.md` #5、`product-database.md` #6、`game-concept-night-shift.md`）＋ `systems-index.md`——自 r3 起皆未變動
> **ADRs Reviewed**: 5（ADR-0001／0002／0003 未變；ADR-0005 r2、ADR-0006 r2；皆 **Proposed**；ADR-0004 保留編號未寫）
> **前幾輪**: r3 `architecture-review-2026-10-03-r3.md`（FAIL）、r2 `architecture-review-2026-10-01-r2.md`（FAIL）、首輪 `architecture-review-2026-10-01.md`（FAIL）——四份並存，本檔不覆寫它們
> **自 r3 以來的變動**: ADR-0006（r2，619→959 行、98→217 KB）、ADR-0005（r2，287→354 行）、`docs/registry/architecture.yaml`（27 條：23 修訂、4 新增）。GDD、ADR-0001／0002／0003、`tr-registry.yaml`、`traceability-index.md` 皆未動（`git diff d7c1dbf b46a8f0 --stat` 為證）
> **證據來源**: 套件原始碼 `prototypes/w1-netcode/Library/PackageCache/`（NGO、MPS、UTP、Authentication、Core、Wire、Collections）；本機 Unity 6000.3.24f1 內建 Roslyn（`-langversion:9` 編譯重現）；W1 的 Bee／linker 產物；HTML／Fetch 規範、Blink／WebKit／Gecko 原始碼、wpt.fyi；本機 Playwright 1.63 實測（Chrome 154.0.8037.97 stable、Chromium 153、Firefox 155、WebKit 26.6）；UGS Lobby REST preflight 實測（2026-10-04，主審親自重跑）
> **審查方式**: 平行審查 7 份＋對抗式反駁 2 份（見 §10）；主審親自抽查 K1、K3、K10、R4D-1、R4B-6、UGS preflight
> **不在範圍**: `docs/architecture/architecture.md`、`control-manifest.md`、`docs/consistency-failures.md`、`production/epics/` 皆不存在（Phase 3b、Phase 6、Reflexion log 跳過）

---

## 0. 一句話

**r3 的 7 條必修全數修好，FV-1 的修法經原始碼 15 跳逐行確認成立：被截止擋下的中途加入者確實留在 session 內。但 r2 新寫的機制（延後 spawn、沙盒 Core、H2 的 `Failed`、`NotAMember` pending）各自長出沒定義的邊；另有一條從 r0 就在、四輪沒人走過的主路徑：client 在 Settlement 收到 #23a 斷線時沒有轉移，照寫每班結束 client 全員回主選單。覆蓋 +1，另補登一條漏抽的 TR（Gap +1）。**

Accept 前必修由 7 條變 9 條（🔴 1、🟡 8），全部是補一句規則、一個事件或一段白名單的局部修法，沒有一條需要重新裁決方向。ADR-0005 r2 本身沒有必修，但必須與 ADR-0006 成對 Accept。

---

## 1. Traceability Summary

| 項目 | 首輪 | r2 | r3 | **r4** | r3→r4 |
|---|---|---|---|---|---|
| **Total requirements** | 227 | 228 | 228 | **229** | +1（TR-netcode-047） |
| ✅ Covered | 50 | 71 | 71（31.1%） | **72（31.4%）** | +1（netcode-010） |
| ⚠️ Partial | 70 | 74 | 74（32.5%） | **73（31.9%）** | −1 |
| ❌ Gap | 107 | 83 | 83（36.4%） | **84（36.7%）** | +1（netcode-047，Core 層） |
| **Foundation 層 Gap** | 30 | 20 | 20 | **20** | 0 |

| GDD | TR | ✅ | ⚠️ | ❌ | 本輪變化 |
|---|---|---|---|---|---|
| `netcode-session.md` | 47 | 26 | 18 | 3 | 010 ⚠️→✅；新增 047 ❌ |
| `first-person-controller.md` | 44 | 26 | 11 | 7 | 無 |
| `machine-interaction.md` | 57 | 7 | 18 | 32 | 無 |
| `product-database.md` | 34 | 0 | 5 | 29 | 無 |
| `game-concept-night-shift.md` | 19 | 7 | 9 | 3 | 無 |
| `systems-index.md` | 28 | 6 | 12 | 10 | 無 |

**新 TR**：TR-netcode-047（AC51「Lobby\* 畫面顯示在場隊友人數」，前幾輪漏抽；arlong 2026-10-04 裁決登記），layer Core，判 ❌——沒有 NGO 的端讀不到 `Roster`，`shift_eta` 沒有人數欄（GF-25）。

**Foundation 層 20 條 Gap 不變**：product 13（TR-product-001–007、014、016、018、020–022）、machine 4（TR-machine-010、023、027、054）、fpc 2（TR-fpc-029、040）、netcode 1（TR-netcode-033）。r2 的修訂範圍碰不到 G2／G4／G5／G6／G7／G8／ADR-0004。

### 狀態變動（1 列）

| TR | r3 | r4 | 理由 |
|---|---|---|---|
| **TR-netcode-010** | ⚠️ | ✅ | r3 降級的三個理由都已處理：確認框有了介面 `SetLeaveConfirmation`（0005:147）；只在 `pagehide` 送出，`beforeunload` 只掛確認框（0006:232-236）；REST 路徑寫完整（0006:237-240）。殘留：V10 未實測（但本輪本機實測已證明跨站 iframe 的 keepalive DELETE＋preflight 會送達，見 §6）。**本列對 GF-21 敏感**：若裁決 Lobby 也要掛確認框，退回 ⚠️ |

### 刻意沒有升級的列

- **TR-netcode-046**（⚠️）：時間基準（FV-2）與入口（FV-1）都已修。但 `IsPrivate = true` 讓加入前讀不到任何屬性，TR 點名的「Lobby 預檢」這個讀者被設計刪掉了。GDD r5 回填 GF-9、TR 措辭同步後即可轉 ✅。
- **TR-netcode-028**（⚠️）：ADR 自承班次交界的合流靠看門狗，是「緩解，不是消除」（0006:718）；本輪 M1（Settlement 轉移）、M9（LobbyWaiting 轉移）又找到兩條沒定義的邊。
- **TR-netcode-033**（❌，邊界案例）：r2 替 avatar 與 `SessionRoot` 兩件物件定了動態 spawn，但「同步物件一律動態 spawn、禁 scene-placed、與 Addressables 共存」這條全專案規則仍無擁有者（歸 G2）；同性質的 TR-machine-027 也維持 ❌。若改判 ⚠️，Foundation Gap 會變 19。

理由有變、狀態不變的 23 列見附錄 A。

### ADR 自報與本審查判定的差異

- ADR-0006 r2 把 r3 點名的 8 列「部分」與 8 列補列全數補上，刪掉了沒有 TR-ID 的 C10／C20 列。**漏報**：TR-netcode-030（TickRate 自 r2 起歸 0006 擁有）、TR-index-027（心跳 D6 與離開通知 D9 都是本 ADR 的決策）、TR-concept-003（D9 定了確認框在跨源 iframe 的行為）。可選補列：TR-netcode-007、020、033、034。0006:771 的 TR-fpc-027 列寫「本機 avatar 的 `OnNetworkSpawn` 就是 `local_ready`」，漏了 Host 的特例（0006:203）。
- ADR-0005 r2 補了 r3 要求的四列。**漏報**：TR-netcode-020（D6 就是它的決策）；表內 7 列以 GDD 規則號書寫、沒附 TR-ID（#17、#28、[P-19]、tick、C14、C16、#20 onLine）。

---

## 2. r3 修訂項核對

### 2A. Accept 前必修 7 條

| r3 項 | 判定 | 依據 |
|---|---|---|
| **FV-1** Lobby\* 入口不可達 | ✅ **已修** | 自有 `SessionNetworkHandler`，被拒不 throw（0006:95-111）。MPS 原始碼逐跳核對 15 跳：handler 正常返回 → 模組設 `Started`、不發 `StartFailed`（`NetworkModule.cs:470-477`）→ `SessionManager` 只在例外時走 `CleanupSessionAsync`／`LeaveAsync`（`SessionManager.cs:311-347`）→ `SaveCurrentPlayerDataAsync` → `RegisterSession` → 回傳 `ISession`，玩家仍是成員。整個 MPS Runtime 只有預設 handler 訂閱 NGO 事件；MPS 從不把 `AllocationId` 送上 Lobby。`Bind` 的必要性成立（初始化路徑上 handler 讀不到 session，`SessionManager.cs:249-270`、`NetworkConfiguration.cs:13-121`）。從 `JoinSessionByCodeAsync` 到下一班合流 12 步，每步都有 ADR 行號定義。**V13 未實跑** |
| **FV-3** Host 自核准的第 4 項與掛點 | ✅ 已修，**但修法引入 M2** | `IsHostSelf` 只判第 1–3 項（0006:175、:428）；第三道防線掛 `OnServerStarted`（三種模式通用）。NGO 原始碼確認時序：Host 自核准 → `OnServerStarted` → `OnClientConnectedCallback(0)`，三者都在 `StartHost` 內、早於 MPS 發布 `_session_network`；`IsHostSelf` 的判別可靠。新缺陷見 M2 |
| **CX-2** `session_events` 在非 Host 端沒有來源 | ✅ 已修 | 分端來源表（0006:280-292）；非 Host 端以 avatar spawn／despawn 為在場來源；`RosterEntry.Phase`；`ShutdownInProgress` 排除條件經原始碼核對成立 |
| **EA-1** REST 路徑寫錯、404 被吞 | ✅ 已修 | 完整 URL 常數、只帶 `Authorization`、只有 204 算成功（0006:237-240）。UGS preflight 主審 2026-10-04 親自重跑：兩條路徑都回 204、`Access-Control-Allow-Origin: *`、`Allow-Methods` 含 DELETE、`Allow-Headers: authorization`、`Max-Age: 600`，與 ADR 一字不差。反射守門測試可行（要用 `GetField`＋`NonPublic`，R4D-10） |
| **FV-4** `beforeunload` 才是實際送出點 | ✅ 已修 | 只在 `pagehide` 送出；`beforeunload` 只掛 Host InShift 的確認框；`persisted` 一律送並重載（裁決③，偏離 r3 Resolution 第二點，理由自洽）。本機 Playwright 實測：跨站 iframe 在 `pagehide` 送出的 keepalive DELETE＋Authorization＋preflight，在 Chrome 154 stable、Firefox 155、WebKit 26.6 都在頁面死後送達 |
| **FV-5** `SessionConfig` 分層 | ✅ 已修 | Core 純 C#；`Session.Unity` 的 `SessionConfigAsset.ToCore()`（0006:261） |
| **EA-4** 自我註冊組件與 asmdef 環 | ✅ 已修 | 組合根 `NightShift.Platform.Composition`＋一處 `#if`（裁決④）。W1 的 linker 確實只把兩個組件當 root、8 個組件整包剝除，自我註冊在 Stripping High 下有實際失效路徑。附註見 R4E-5／R4E-6（LOW） |

### 2B. 應修 4 條與 LOW 項

| r3 項 | 判定 | 殘留 |
|---|---|---|
| FV-2 `shift_eta` 對晚到讀者失效 | ✅ | `published_utc_ms`＋`shift_seq`＋clamp |
| FV-6／CX-5 離開通知生命週期 | ✅ | `LeaveBeaconPlan` 宣告式保鮮；但 Teardown 第 4 步在 leave 失敗時也清掉離開通知（K13） |
| EA-2 NGO 設定雜湊先於 approval | ✅，**但修法引入 M5** | 兩層閘門成立；`build_token` 相符→`Failed` 的分支是死路 |
| EA-3 transport 切換時機 | ✅ | `OnServerStopped`／`OnClientStopped` 公開、`OnStopped` internal（原始碼確認）；stopped 事件觸發時 transport 已關，在其中換指派安全；Host 先觸發 Client 再觸發 Server |
| FV-7、FV-8、FV-9、FV-10、EA-5、EA-6、EA-7、N5、CX-3、CX-4、CX-6、CX-7、CX-8 | ✅ | 承重行號抽查全吻合（`RpcMessages.cs:67-72`、`ProxyMessage.cs:45-70`、`FixedString.gen.cs:2652`＝61 等） |
| EA-8 | ✅（**r3 前提錯**） | SDK 確實吞 `PlayerNotFound`（`WrappedLobbyService.cs:336-347`），r2 的更正成立 |
| EA-9 | ✅ | `InstallLeaveBeacon(url, method, authorization)` 三字串 |
| CX-9 registry 漂移 5 處 | ⚠️ 修 4 處 | `player_identity_key` 的 PlayerId 範圍仍比 ADR 自己的用法窄（漏 avatar `PlayerId` NV、Roster、`PeerLostContext`、離開通知 URL） |
| EA 跨 ADR（WSS reliable 順序） | ⚠️ | 前提 3 (b) 已回指 ADR-0002 V③；但 Decision 13 不變式 (a)（0006:289）又把同一前提寫成事實 |
| X1／CX-1 身份傳播 | ❌ 未落地 | 依計畫在 ADR-0006 Accepted 之後（Migration 3 已列齊） |

---

## 3. ADR-0006 r2／ADR-0005 r2 的新缺陷

嚴重度：🔴 HIGH＝Accept 前必修，且照寫會在主路徑失效；🟡 MEDIUM；LOW／NOTE。每條都經反駁者以 ADR 全文與原始碼試圖推翻，標示最終判定。

### 3A. Accept 前必修 9 條（全部屬 ADR-0006）

**M1 🔴 client 在 Settlement 收到 #23a 斷線時沒有轉移；原因字串與 Host 主動離房相同 → 照寫每班結束 client 全員回主選單**【R4C-6；反駁者 V2 CONFIRMED；主審抽查原始碼】
- **原始碼**：有 peer 的 Host 關機時，NGO 對每個 client 送同一個原因 `"Disconnected due to host shutting down."`（`NGO Core/NetworkManager.cs:556-566`）。#23a 經 H5 `Shutdown()`（0006:105），Host 關頁的 Teardown 第 2 步也是 `Shutdown()`（0006:226）——client 分不出兩者。#23a 移除 `_session_network` 的存檔又排在 `ResetAsync` 之後（`NetworkModule.cs:697-706`），所以 client 先看到 NGO 斷線、後看到屬性變更。
- **ADR**：全文沒有 client「Settlement 中收到 NGO 斷線」的轉移。#18 排歧表（Decision 8，0006:220）三個結論全走 Teardown；序 4（Host 仍是成員）判 `Undetermined`。GDD 兩處互相拉扯：:761「#23a teardown → Lobby」對 :763-765「Settlement 的 socket close 一律視為離開」；矩陣 #18 Settle＝Y（:732）。
- **影響**：主路徑，每班結束都會遇到。r0–r3 四輪都沒有人從 client 端走過 #23a。
- **修法**：Host 在 `StopNetworkAsync` 之前對每個 client `DisconnectClient(id, "ShiftEnded")`。PostLateUpdate 先跑 `ProcessClientsToDisconnect`、再跑 `ProcessServerShutdown`（`NetworkManager.cs:497-515`），所以這個原因一定先到。Core 定義「Settlement（含剛進 Lobby）收到 `NetworkStopped(ShiftEnded)` → Lobby」，其他原因才進 #18。`ShiftEnded` 加進原因字串的列舉。GDD r5 把 :763 的 socket close 限定為 MPS／Wire 層（GF-28）。T1 (g) 加 client 端斷言：#23a 後 client 停在 Lobby、仍是成員。

**M2 🟡 Host 的 slot 0：`PlayerJoined(0)` 的來源兩處矛盾，NGO 隨後觸發的 `OnClientConnectedCallback(0)` 沒有處置規則**【R4A-1＋R4E-1＋R4C-7，三位審查者獨立找到；V1 CONFIRMED；主審抽查】
- **原始碼**：`HostServerInitialize` 依序：Host 自核准（`NetworkManager.cs:1507-1516`）→ `OnServerStarted`（:1530）→ `OnClientStarted` → `OnStarted` → `InvokeOnClientConnectedCallback(0)`（:1537），全在 `StartHost` 內同步。
- **ADR**：0006:175 由轉接層在 `OnServerStarted` 內「發 Host 的 `PlayerJoined(0)`」，且在 `HostShiftStarted` 之前；0006:284 與 T0 (e)（0006:819）卻要求 `PlayerJoined` 是 Core `Step` 的輸出、同 Step 出 `SpawnAvatar`。0006:203 的 (i)/(ii) 分流發生在「approval 指派 slot 時」，Host 的指派早於 `ShiftCohort` 快照、而且 Host 被排除在 `ShiftCohort` 之外 → 照字面落 (ii) Onboarding，定長過場後再發一次 `PlayerJoined(0)`。全文只有 0006:198 守**斷線**方向的 `ServerClientId` 回呼。
- **影響**：照字面實作會二度 spawn Host avatar（舊的那具不再是 PlayerObject、永遠清不掉，0006:203 自己寫的陷阱）；若 `PlayerJoined(0)` 不是 Core 輸出，`SlotTable` 不一定把 slot 0 標為 Online，`OnlineCount` 少算 Host，連帶影響 #14 重取樣、寬限與 `host_solo` 旗標，而且不報錯。R4E-1 稱 Host 會對自己跑心跳、8 s 後把自己移出 MPS——V1 降級：0006:255 暗示 Host 不是自己的 peer，registry 的守衛會擋下第 6 步，就算發生也是大聲失敗；修法已涵蓋。
- **修法**：D7 前提 4／D13 加一句：`OnClientConnectedCallback(ServerClientId)` 不送 Core、不啟動心跳；0006:198 的守衛範圍改成與 registry 一致（序列入口）。slot 0 改由 Core 處理 `HostShiftStarted` 的同一個 `Step` 輸出 `PlayerJoined(0)`＋`SpawnAvatar(0)`、`PeerPhase[0] = InShift`；0006:175 改為「…→ `HostShiftStarted` → 執行 `SpawnAvatar(0)` → 斷言」。T0 (e) 加 slot 0 案例。

**M3 🟡 沙盒 Core 的輸出沒有作用域**【R4C-1；V1 由 🔴 降為 🟡，仍必修】
- **ADR**：只限制了沙盒 Core 的**輸入**（0006:110 `NgoOwner` 路由、0006:256「互不相通」）。**輸出**全文無一句：沙盒 Core 收 `HostShiftStarted` 進 InShift（0006:182）；`SetLeaveConfirmation(true)` 以「Host 進 InShift」為條件、未分 mode（0006:234）；Teardown 執行器只有一套（0006:224-230）；`LeaveBeaconPlan` 「每次階段變更」重算未指明哪一台（0006:241）；`ConnectionState` 是「唯一」來源（0006:279）。GDD 矩陣沒有 mode 維度（#12、#17、#17a InShift＝Y）。
- **情境**：① 等待者開沙盒 → 沙盒 Core 進 InShift → client 頁面掛上確認框，`AbortSandbox` 後沒有任何一台 Core 走「離開 InShift」，永遠不解除。② 每次 `AbortSandbox`，沙盒停機的 stopped 回呼依 0006:110 送進沙盒 Core——它在 InShift 收到後怎麼轉移完全沒定義，而這條**每次合流必經**。③ 若實作者把 `IPageLifecycle` 也送進沙盒 Core，切分頁 > 5 s 就會讓共用的 Teardown 執行器退訂等待者的 Online session（V1 認為需實作者另做兩個未規定的選擇，故降級）。
- **修法**：Decision 10 加沙盒 Core 效果白名單：只准作用於沙盒自己的 NGO、`SessionRoot` 與練習 HUD；`SetLeaveConfirmation`、`Install/ClearLeaveBeacon`、`ConnectionStateChanged`、Teardown、ISession 訂閱只由 Online Core 驅動；沙盒 Core 不接 `IPageLifecycle`。`AbortSandbox` 先把沙盒 Core 標為棄置（其後的 stopped 回呼丟棄），再 `Shutdown()`。T1 (k′) 加「沙盒中切分頁 6 s」「沙盒中關分頁」兩案（斷言零確認框、恰 1 筆 client `DELETE`）。順帶交 GDD r5：從 Idle 進的 Solo 是否套 #12／#17（AC42a 已暗示 N=1 不跳框）。

**M4 🟡 #23a 的存檔失敗沒有出口；失敗後 Host 每次 `LobbyChanged` 都會拋 NRE**【R4C-2＋V2 補充 1；V1 由 🔴 降為 🟡；主審抽查】
- **原始碼**：`StopNetworkAsync` 存檔拋例外時設 `State = Started`、發 `StopFailed`、rethrow（`NetworkModule.cs:711-716`）。R4C-2 原稱「此房永遠開不了下一班」——**被推翻**：`ValidateStartNetwork()` 在 try 內，第一次 #26 拋出後 catch 會把 State 歸回 `Stopped`（:236-241、:362-370），第二次就能啟網。另外，本機留下 `_session_network = null`、伺服器仍有該 key 時，`UpdateDerivedProperties` 的 `property.Value != …`（`SessionHandler.cs:1131`）沒有 null 檢查，**之後每一次 `LobbyChanged` 都拋 NRE**，`LobbyHostChanged`／`PlayerHasLeft`／heartbeat 排程被跳過（傳播效果 INFERRED）。
- **ADR**：只處理了 #26 側的同型失敗（H4、`ShiftStartAborted`，0006:104、:181）。0006:116 的 `min_lobby_dwell_ms` 從「#23a 移除屬性的存檔完成後」起算，照字面永不起算；client 看不到屬性移除，模組停在 `Started`，下一班的新值被 `NetworkModule.cs:537` 吃掉，全員改走看門狗＋復原。
- **修法**：Decision 5「寫入配對」補一段：#23a 完成＝`StopNetworkAsync` 成功返回；拋例外時依 Decision 14 退避**重呼 `StopNetworkAsync`**（H5 冪等，本機仍 Modified 的 `shift_eta(Lobby)` 隨同一次存檔送出），成功後才起算 dwell；重試期間鎖 #26、Host Core 停在 Lobby。明文禁止依賴「下一次 Start 會把 State 歸零」。Host 端不得留下未存出的 null 值。T1 (p) 加「#23a 存檔 429」一案。

**M5 🟡 H2「連線前通用字串＋`build_token` 相符 → `Failed`」是靜默死路；它要照顧的 approval 逾時根本不送通用字串**【R4A-2＋R4C-4＋R4A-3＋R4E-4；V1 CONFIRMED，並推翻 R4B-1】
- **原始碼**：approval 逾時走 `NetworkConnectionManager.cs:834` → 類別內唯一的多載 `internal DisconnectClient(ulong, string reason = null)`（:1600），reason 為 null 時不送 `DisconnectReasonMessage`（:917-930）。通用字串只出自公開單參數多載（`NetworkManager.cs:1570`），連線前只有 `ConnectionRequestMessage.cs:136,149`（訊息不完整、雜湊不符）會呼叫——所以**連線前看到通用字串，就代表 NGO 已證明 build 不相容**。
- **ADR**：0006:162 說 approval 逾時也送通用字串（錯）；同段「approval 是同步的」與 0006:168 新增的 Pending 矛盾。`StartOutcomeKind.Failed`（0006:595）全文沒有 Core 反應：handler 正常返回時 MPS 不發 `StartFailed`，復原不觸發；`attemptedSeq` 已是當前 seq，看門狗也不武裝。dev build（`BuildId = 0`）就走得到。
- **修法**：H2 與 0006:162 改為「連線前看到通用字串一律 `StaleBuild`」；`build_token` 相符時只記診斷 log（代表 `BuildId` 漏了 `GetConfig(false)`，交 G4），刪除 `Failed` 分支。更正：approval 逾時沒有原因字串，落 H3。刪「approval 是同步的」。registry 現行寫法即為正確目標，不用改。

**M6 🟡 `NotAMember` 先 pending 再重判：完成時不檢查 client 是否仍在 → 鬼 client、無人 avatar**【R4E-3＋R4C-5＋R4C-14；V1 CONFIRMED】
- **原始碼**：`ClientsToApprove` 只在非 Pending 回應與 Initialize 時移除（`NetworkConnectionManager.cs:856,878-906,1649`）；pending 期間 client 斷線或 Host 端 10 s 逾時都不清。之後回應改為 Approved，`AddClient` 無條件加入 `ConnectedClients`（:1000、:1239-1258），照樣觸發 `OnClientConnectedCallback`（:1062-1063）。0006:203 的在線檢查 ① 只看 `ConnectedClients`，擋不住。
- **ADR**：0006:168 只寫「整段要在 10 s 之內」，沒有執行機制；`RefreshAsync` 是單次 REST、無逾時參數（`SessionHandler.cs:846-854`）。`ApprovalGate.Evaluate` 宣稱純函式，卻沒有任何輸入能區分「第一次」與「重判」（0006:425）。
- **影響**：鬼 client 生成一具沒人操作的 avatar；8 s 後心跳走 #24，第 6 步可能把正以復原重新加入的同一 `PlayerId` 移出（INFERRED）。觸發條件（refresh 超過約 10 s，或 refresh 期間關分頁）不常見，但觸發時 NGO 狀態被靜默汙染。
- **修法**：0006:168 補三句：完成 pending 前檢查 `NetworkManager.PendingClients.ContainsKey(clientId)` 與 session 世代，不在就放棄；`RefreshAsync` 以 `ClientConnectionBufferTimeout − 2 s` 為上限，逾時或拋例外（含 429）就以 `NotAMember` 拒；`ApprovalRequest` 加 `bool IsMemberRefreshRetry`。T1 (r) 補兩案。

**M7 🟡 `SessionRoot.Ready` 是實例事件，avatar 先到時無處可訂閱**【R4G-CX-3＋R4C-18；V1 CONFIRMED】
- **原始碼**：晚加入者收到的初始快照遍歷 `HashSet<NetworkObject>`（`NetworkSpawnManager.cs:34`、`ConnectionApprovedMessage.cs:75,157`），逐物件 spawn（:343-347），`SessionRoot` 與 avatar 誰先到沒有保證。
- **ADR**：0006:549 `public event System.Action Ready;` 是實例成員；0006:188 要 avatar／HUD「不得假設 `SessionRoot` 已存在，改訂閱 ready 訊號或讀它的現值」——兩個選項都要先拿到實例；0006:792、:795 把它列為 ADR-0001 r1 與 G2 的義務。
- **修法**：Key Interfaces 改為 `NgoBridge` 上的入口：事件 `SessionRootSpawned`＋`SessionRoot Current { get; }`；依 `NgoOwner` 只觸發 Online 端的訂閱者。0006:188、:792、:795 同步改名。

**M8 🟡 各階段的輸入開放沒有事件、也沒有擁有者**【R4G-CX-2＋R4C-15＋R4B-7；V2 CONFIRMED ①】
- **ADR**：0006:203 把「Host 的輸入要等 #26 轉場結束（開班同批全數 `PlayerJoined` 或 `T_spawn` 到期）才開放」交給「ADR-0001 r1 與 GDD r5」，但判準只有 Host Core 知道；0006:140 把「Settlement 沒有移動」當前提；0006:279 的事件清單、Migration 3 的 ADR-0001 項（0006:792）都沒有對應訊號。registry `avatar_ownership_callback_side_effects` 又要求綁定掛 `OnNetworkSpawn`，而 Host 的 avatar 在 `OnServerStarted` 就 spawn。ADR-0001 的轉接層若自己判斷，就違反 `session_logic_outside_core`。
- **修法**：D13 加 Core 事件 `LocalInputGateChanged(bool open)`。打開時點：Host＝開班同批全數 `PlayerJoined` 或 `T_spawn` 到期；client＝本機 avatar spawn。進 Settlement 或 Teardown 時關閉。Migration 3 的 ADR-0001 項加「`adoptInput` 另受此事件閘控；綁定可在 spawn 時完成，採納要等閘門開」；0006:771 補 Host 特例。Host 與 client 的開放時點不對稱（同批有人慢時 client 最多比 Host 早 10 s 行動）是否接受，交 GDD r5 一句話裁決。

**M9 🟡 看門狗從 LobbyWaiting 觸發復原時，Core 何時離開 LobbyWaiting 沒有定義**【R4C-8；V2 ADJUSTED】
- **ADR**：看門狗可在 LobbyWaiting 武裝（0006:114），復原動作（0006:120）沒寫 Core 何時離開 LobbyWaiting。GDD Lobby\* 只有「前一班進 Lobby」一個出口（:758）；H1 ② 的 `NetworkJoinRequested` 只在沙盒在跑時才送（0006:101）。等待者是 #26 當下的成員，在 `ShiftCohort` 內 → 走 (i)，avatar 在 Host 的 `OnClientConnectedCallback` 就生成，早於加入回傳。
- V2 推翻了 R4C-8 的「從 Lobby 復原」那一支（Core 在 Lobby 收到本機 avatar spawn → InShift 就是一般的 #26 轉移，0006:284）；0006:395 介面註解與正文的矛盾降為 LOW。
- **修法**：復原動作第一步明定 Core `LobbyWaiting → Lobby`（看門狗到期即證明前一班已結束：`shift_seq` 前進且 `phase == InShift`）；Decision 13 本機列補「JoiningRoom／Lobby 收到本機 avatar spawn → InShift」。0006:395 註解改為「(i) approval 時即 InShift；(ii) Onboarding → `PlayerJoined` 時 InShift」。

### 3B. 應修（MEDIUM，非 Accept 阻擋）

| ID | 內容 | 修法 |
|---|---|---|
| **K12**（R4D-1） | Host 本機屬性字典不是穩定暫存：每次 `LobbyChanged` 的 `UpdateDerivedProperties` 會刪掉伺服器沒有的 key、把值不同的 key 改回伺服器值（`SessionHandler.cs:1114-1139`）；`SavePropertiesAsync` 在呼叫當下定格、await 後無條件清 `Modified`（:1044、:1055-1056），沒有鎖也沒有佇列。**現行 #26／#23a 的配對成立**：從 `OnServerStarted` 寫入到 MPS 定格之間全是同步程式碼（`NetworkModule.cs:303-359`），#23a 靠 H5 回傳已完成的 Task——但這兩點都是隱性前提 | H4 補「`StartHost()` 回 true 後同步完成 Task，不得 await 或延後一幀（H1 ⑦ 只適用 client）」；Host 屬性的所有寫入由 `SessionServices` 單一寫入者排成序列 |
| **K13**（R4D-2＋R4C-22） | 殘留成員：加入時 `UpdatePlayer` 失敗、復原或 Teardown 的 `LeaveAsync` 失敗，服務端仍是成員；以同碼重新加入撞 409 時，衝突解析器在 `lobbyId == null` 時直接放棄（`WrappedLobbyService.cs:225,724-739`），得到 `SessionConflict`，不是 Type 衝突。T1 (n) 的期望寫錯；Teardown 第 4 步在 leave 失敗時也清掉離開通知 | leave 失敗時以公開 API `LobbyService.Instance.RemovePlayerAsync(session.Id, PlayerId)` 退避重試，確認已不是成員之前不設 `leaveTaskEnded`；重新加入得到 `SessionConflict`（非 `Duplicate`）時先清理再試一次；T1 (n) 改斷言「最終在班」 |
| R4C-10 | H4 ② 的屬性撤回只改本機、不存檔；`ShiftStartAborted` 時 `shift_seq` 不前進。存檔「失敗但伺服器已套用」時，client 的看門狗對真正那一班失明；本機 null 值還會觸發 M4 的 NRE | H4 ② 改為立即以退避重試存出撤回；`shift_seq` 每次 #26 嘗試都前進、不回收 |
| R4C-12 | `NgoOwner`「stopped 回呼結束後的下一幀清除」與 handler「距 stopped 至少 1 幀才設 Online」落在同一幀，先後未定。清除若在後，Online 的回呼被丟掉，client 心跳不啟動，Host 8 s 後判它離線 | 改成「比較後清除」：只有 `NgoOwner` 仍等於被停那次運行的 token（擁有者＋世代）時才清 |
| R4C-13 | handler 入口沒有世代檢查；`NgoOwner` 只有 Online／Sandbox 兩值，Solo 也設 `Sandbox`，遲到的 Teardown 會把玩家的 Solo 關掉；T1 (s) 要斷言的「遲到的加入回傳」根本不會發生（handler 先 throw、SDK leave） | H6 補「`StartAsync` 入口世代不符就 throw」；遲到 Teardown 的 `Shutdown()` 限 `NgoOwner == Online` 且世代相符；`NgoOwner` 加 `Solo`；T1 (s) 改注入 `AttemptStarted` 之前的延遲 |
| R4A-4 | 初始化路徑上，handler 的結果何時、以什麼事件交給 Core 沒有定義；Core 與 handler 的 `T_spawn` 同時在 `AttemptStarted` 起算。拒絕發生在接近上限時，Core 先逾時回 Idle，遲到的回傳接著被 Teardown，本該進 Lobby\* 的人被移出 | 定義 `JoinCompleted(outcome)`：等加入回傳、H7、`Bind`、`build_token` 比對都完成才送進 Core；Core 的 `T_spawn` 在 handler 結束時停表，回傳前另給一小段預算 |
| **T1-Web 測試規格**（F 的 R4F-1、R4F-2、R4F-4） | 本機實測：① 預設 `page.close()` 只跳過 `beforeunload`，`pagehide` 照跑、DELETE 送達 → (l5) 斷言「零 DELETE」必紅，132 s／30 s 的退化路徑沒有案例真正驗到；② Playwright 預設關掉 bfcache → (l4) 照寫拿不到 `persisted = true`；③ Playwright WebKit 在包裝頁沒有 `beforeunload` 監聽器時，`runBeforeUnload` 關閉會卡住；WebKit 跨源 iframe 不跳框，(l1) 不適用 WebKit | (l5) 改用真正的強殺（`browser.process().kill('SIGKILL')` 或 CDP `Page.crash`）；(l4) 只在 Chromium 跑並寫明 `ignoreDefaultArgs: ['--disable-back-forward-cache']`＋`goBack({ waitUntil: 'commit' })`，WebKit 併入真實 Safari 人工驗收；包裝頁固定加空的 `beforeunload` 監聽器；(l1) 標「WebKit 不適用」。0006:842 改述 |
| **Chrome bfcache 與 WebSocket**（F 的 R4F-3） | 0006:233、:235、:948、0005:88、:148 說 Chrome 149+ 進 bfcache 時「主動關閉 WebSocket……連線都已經斷了」。Blink 原始碼：凍結時 `channel_->Fail()` 只把拆除 post 到該 frame 的 networking task runner，凍結中不會跑；Chrome 154 實測（n＝3）連線在 bfcache 中維持 ESTABLISHED ≥ 30 s，恢復時才送 close。**裁決③不受影響，反而更站得住** | 五處改述為「Chrome 149+ 可進 bfcache；WebSocket 在頁面層判為失敗，但網路連線要到恢復或逐出才關（Chrome 154 實測 ≥ 30 s）；Safari 進入即關；Firefox 不進」；(l4) 加伺服器端觀測 |
| **Safari 讀不到 `?code=`**（F 的 R4F-5） | WebKit 官方政策：所有第三方 referrer 預設降為 origin，包含 `document.referrer`。itch.io 頁面載入 `html-classic.itch.zone` 是跨站，Safari 下 iframe 的 referrer 只剩 `https://<user>.itch.io/`，永遠沒有 query（政策 CONFIRMED；「itch.io 上恆為 null」INFERRED，未用真實 Safari 驗）。設計不會壞（null 已是正常情況、輸碼備援保留），但 ADR-0005 Verification ④ 在 Safari 上必然失敗 | ④ 限定 Chrome（與 Firefox 預設模式）；0005:89 明寫 Safari 恆為 null；GDD #8 補註（GF-27） |

### 3C. LOW／NOTE

| ID | 內容 | 修法 |
|---|---|---|
| R4B-6 | `ShiftEndTs` 初值寫成 `nowMs + shift_length_sec`（0006:178），毫秒加秒；照字面 T0 (b) 會當場失敗（主審抽查） | `nowMs + shift_length_sec × 1000` |
| K7（R4C-3＋R4A-7＋R4B-2） | 看門狗：Key Interfaces 註解（0006:457）只列 `Changed` 與嘗試結束兩個呼叫時點，漏了週期呼叫；Decision 2、registry、修訂紀錄三處都寫計時器驅動，T1 (n) 會攔下錯誤讀法。T0 (j)「#26 時不武裝」與武裝規則字面矛盾 | 0006:457 補「轉接層另以固定週期呼叫」；T0 (j) 改述；registry 補 Core 階段守衛 |
| K11（R4E-2） | 延後 spawn 的在線檢查 ① 擋不住第 5a 步的延後斷線窗口；實際觸發源只剩 `LeaveRequested`（窗口很窄） | `SpawnAvatar` 帶占用世代，執行前比對 `SlotTable.ClientOf(slot) == clientId`（順帶解 R4C-21） |
| R4G-CX-4 | Host 端「排除本機 avatar」若用即時 `IsLocalPlayer`，T2 路徑（`RemoveOwnership` 後）會漏清；0006:201 前提 2 已大致涵蓋 | 0006:290 的排除規則補「以 `OnNetworkSpawn` 時快取的旗標判斷」；V14 加 Host 端斷言 |
| R4C-16＋R4A-6 | V13／T1 (l) 要求 LobbyWaiting 停 150 s，GDD 旋鈕上限只有 120 s；`MaxPlayers = max_players`（MVP 2）時第三個實例進不了房，(i′)(l)(o)、V12、V14 都需要 ≥ 3 人 | Validation 開頭註明多實例案例用測試專用 `SessionConfig`（`MaxPlayers = 4`、`late_join_cutoff_sec ≥ 160`），並寫明 `Validate()` 對測試組態怎麼放行 |
| R4A-5＋R4E-8 | `NetworkConfig.ConnectionData` 何時、由誰寫沒定義；先玩未登入 Solo 再建房，payload 仍是 `SoloLocalPlayerId` → 每次 #26 都 `StartFailed`（會出聲但沒出口） | H1 ⑤、H4、`UseSinglePlayer` 都在 `Start*()` 之前寫入當下身分的 payload |
| R4C-11 | 關分頁後 8 s 內以快取重開會被判 `Duplicate`；需要 8 s 內完成重載＋登入＋加入，罕見 | T1 (q) 加一案；可選：`Duplicate` 比照 `NotAMember` 先 pending |
| R4C-17 | `LeaveBeaconPlan.TryFor` 沒有世代參數，T0 (h) 的世代案例只能測恆等式 | 宣告式規則收進 Core 的小類別，回傳 `Install`／`Clear`／`NoChange` |
| R4C-19 | 復原規則「換值時不復原，模組會在下一次變更自己啟網」與 MPS 原始碼不符 | 改述 |
| R4C-20 | 看門狗「同一個 seq 只武裝一次」與復原「每個 `shift_seq` 最多 2 次」不一致 | 統一 |
| R4C-21 | `SpawnAvatar(slot, playerId)` 不帶占用世代 | 併 K11 |
| R4C-23 | `PeerConnected` 的觸發時點描述有誤 | 改述 |
| R4C-24 | `SessionConfig.Validate()` 沒涵蓋 r2 新增的 `MaxPlayers` | 補一條 |
| R4C-25（0005） | `pageshow(persisted)` 一律重載，`RestoredFromBackForwardCache` 實際上沒有消費者 | 擇一：刪事件或寫明消費者 |
| R4C-26（0005） | `.Web` 在 Editor 永不編譯，C# 錯誤只會在 WebGL player build 時浮現 | CI 加一次 WebGL 腳本編譯 |
| R4B-3 | `player_identity_key` 漏列 PlayerId 允許出現的位置（即 CX-9 殘留） | 補列 |
| R4B-4 | `presence_from_connection_events` 與「Roster 冪等補強」互相牴觸，也沒涵蓋 Host 端 PeerLost 第 1–3 步 | 改述 |
| R4B-5 | 「T1、T2 觸發源」與測試層名稱撞名（:18、:286、:291、:837） | 觸發源改名 |
| R4B-2、R4B-8–11 | registry `session_layer_split` 漏條件；`LeaveBeaconPlan` 註解殘留「null 即 Clear」；D13 (a) 未回指 V③；跨班次 `PlayerLeft` 保證只在同班內成立；commit 訊息的「13 條 revised」實為 23 條 | 逐條更正 |
| R4B-1 | **REFUTED**（V1）：registry 寫「連線前通用字串歸 `StaleBuild`」才是正確目標 | — |
| R4D-3–11 | 建房時 `SavePropertiesAsync` 不在清理範圍（孤兒房）；續發 token 被拒實走 30 s 重試；`StateChanged(None)` 先於 `Expired`；`Bind` 段例證不精確；`Type` 預設已是新 GUID；漏列第三條啟網路徑 `MigrateClientNetworkAsync`；`LobbyFull` 被轉成 `Unknown`，無法顯示「這班人滿了」；反射測試規格；文件漂移 | 逐條更正（R4D-9 影響店語，建議與 GDD 一併處理） |
| R4E-5、R4E-6 | 「Stripping High 下 `[RuntimeInitializeOnLoadMethod]` 本來就是 root」只在組件會被 linker 處理時成立（`AlwaysLinkAssembly` 文件原文）；組合根「住在 Assembly-CSharp」不足以保證可達，可達性其實由消費者保證 | 0005 改述，Verification 斷言實作型別已能抓到 |
| R4E-7 | 同類陷阱：`NightShift.Session.Editor` 會遮蔽 `UnityEditor.Editor`（已以 Roslyn 重現 CS0118） | 與 `global::` 規則並列 |
| R4F-6–10 | Playwright 驗不到「沒有 activation 就不跳框」；瀏覽器下限改為「Firefox ≥ 133（仍在延長支援的 ESR 115 沒有）；Safari 在 WPT 上 ≥ 17.5 已通過」，Risks 兩處補 Safari；UGS 回應帶 `Cross-Origin-Resource-Policy: same-origin` 但 CORS mode 不受影響；HTML 規範仍寫「有 WebSocket 就 unsalvageable」（PR whatwg/html#12349 open）；Firefox 155 關分頁時 `visibilitychange` 先於 `pagehide` | 逐條更正 |
| N-a（0005） | Constraints :51 對 `[Preserve]` 的說法與 Decision 4 :80 矛盾（r1 起就有） | 統一 |

---

## 4. Cross-ADR Conflicts（Phase 4）

> **Known conflict-prone areas**：`docs/consistency-failures.md` 不存在。r3 指出的模式「SDK 自己的控制流程替我們做了決定」本輪仍是主因（M1：NGO 對所有關機送同一原因字串；M4：MPS 存檔失敗回滾模組狀態、`UpdateDerivedProperties` 的 null NRE；M5：NGO 的 internal 多載不送原因；M6：`ClientsToApprove` 不隨斷線清除）。**本輪新增一個模式：新機制只定義了輸入、沒定義輸出與邊界事件**——沙盒 Core（M3）、延後 spawn 的 slot 0（M2）、輸入閘門（M8）、`SessionRoot.Ready`（M7）。r2 每一條都沿 SDK 呼叫鏈寫了，但沒有從「另一端」（client 端的 #23a、Host 自身的 connected 回呼）走一遍。

| ID | 嚴重度 | 衝突 | 修法 |
|---|---|---|---|
| **CX-1** | 🔴 HIGH（擋 0001／0002／0003 Accept；不擋 0005／0006） | **r2 X1 延續、原封未動**。ADR-0001 `CapsuleGhost.Id: string`（:132）、`Solve(…, string selfId, …)`（:140-141）、以玩家 id 為鍵（:111、:144、:220）；ADR-0002 `ulong ClaimedBy`（:137）、`Validate(…, ulong requester, …)`（:141）；ADR-0003「不以 slot 為鍵」（:46、:167）。三者都違反 registry `player_identity_key` 與 `clientid_as_player_identity` | 依 ADR-0006 Migration 3（0006:792-794，已列齊含 `selfId` 與 Depends On）改鍵 |
| M8（R4G-CX-2） | 🟡 必修（列在 §3A） | 輸入閘門：0006 把義務交給 0001 r1，但判準只有 0006 的 Core 有 | 見 M8 |
| M7（R4G-CX-3） | 🟡 必修（列在 §3A） | `SessionRoot.Ready` 交給 0001 r1 與 G2，照寫拿不到實例 | 見 M7 |
| R4G-CX-5 | LOW | TickRate 在 ADR-0001 r1 之前有兩個宣告者（0001:42、:215 vs 0006:63、:84、:270）；值相同、宣告層無環 | 已列入 Migration 3，r1 落地即解 |
| R4G-CX-6 | LOW | WSS reliable 順序的前提在 0006 兩處有兩種地位（前提 3 (b) 待 ADR-0002 V③；D13 (a) 當成事實） | D13 (a) 回指 ADR-0002 V③ 與 V14 |
| R4G-CX-7 | LOW | ADR-0002 的 Host→發起者回應 RPC（`InteractResponseRpc`）有 EA-5 同樣的代轉偽造面；只影響表現層 | ADR-0002 r1 或 ADR-0004：Host→client RPC 一律 `InvokePermission = Server`；registry 加通則 |
| R4G-CX-8 | LOW | Migration 3 給 0002／0003 的只有「ownership 回呼紀律」，registry 已把綁定時點規則擴及兩者 | 兩項改為「全條遵守 registry `avatar_ownership_callback_side_effects`」 |
| R4G-CX-9 | LOW | ADR-0001／0002／0003 的 T1 夾具前提是 NGO 自動建 player object，r2 起不成立 | Migration 3 加一句：T1 夾具走 `SpawnAvatar`；registry 寫明測試夾具是否豁免 `ngo_start_outside_session_handler` |
| R4G-CX-10 | LOW | `SpawnAvatar` 由誰執行、avatar `Slot`／`PlayerId` NV 的擁有者沒有唯一答案（0006:203 說轉接層、0006:24／:795 說 G2）；registry 沒有這兩個 NV | 一句話定案；registry 加 state `avatar_identity_nv` |
| R4G-CX-11 | NOTE | ADR-0003 的 NPC 在場讀 NV（0003:98），與 0006 D13 (c)「NV delta 晚於 Destroy」有張力 | ADR-0003 r1 補「NPC despawn 時亦清」 |
| R4G-CX-12 | NOTE | ADR-0001 r1 的 Depends On 也該列 ADR-0005（0005:24 Enables 列了 `adoptInput` 供給側） | Migration 3 補列 |

**三條新 forbidden pattern**（`ngo_start_outside_session_handler`、`disconnectclient_without_reason`、`presence_from_connection_events`）逐條對照：ADR-0001／0002／0003 的現行文字**都不直接違反**。唯一字面落差是 ADR-0003:95 的「`player_left` 時清」，Migration 3 已列為義務。

### 4A. ADR Dependency Ordering

```
現行宣告（X ──► Y 表示 X Depends On Y）
  0002 ──► 0001 ◄── 0003
  0006 ──► 0005
  0001、0005：無依賴          拓撲：L0 {0001, 0005} → L1 {0002, 0003, 0006}     無環

正文裡的隱性回指（⇢）
  0006 ⇢ 0002   前提 3 (b)／D13 (a) 待 V③（證據層）
  0006 ⇢ 0003   NPC id 冷卻只引用不重述（引用）
  0005 ⇢ 0006   桌面列描述 0006 的 Teardown（驗證層）
  0005 ⇢ 0001   pointer lock 交棒、焦點來源（Related）
  0006 ⇢ 0001   r2 已全部移除（TickRate 歸 0006）

Migration 義務落地後
  0005 ◄── 0006 ◄── 0001 r1 ◄── {0002 r1 ∥ 0003 r1}
  G2 ──► 0006、0001、0003        0004 ──► 0002、0006、G2、0005
  宣告層無環
```

- r3 指出的潛在兩點環 0001↔0006 已由 TickRate 歸 0006 拆除（CX-4 ✅）。
- 落地後只剩弱環 `0001 r1 → 0006 → 0005 ⇢ 0001`，`⇢` 是 Related（pointer lock 交棒），不是決策輸入。條件：ADR-0005 不把 0001 列回 Depends On。
- ⚠ 每一條依賴邊都是 Proposed 依賴 Proposed。ADR-0006 依賴的是 ADR-0005 **r2**（`InstallLeaveBeacon(url, method, authorization)`、`SetLeaveConfirmation`、`RestoredFromBackForwardCache`、`PlatformComposition.Create()`），兩者必須成對 Accept。
- **建議的 Accept 順序**：ADR-0005 r2＋ADR-0006 r3（成對，先修 §3A 九條）→ ADR-0001 r1 → ADR-0002 r1 ∥ ADR-0003 r1 → G2 → ADR-0004 → G4 → G8 → G5 → G7 → G6 → G9。

### 4B. 資料所有權與效能預算

- 沒有兩份 ADR 對同一個執行期狀態都宣告寫入權。唯一未登記的是 avatar 的 `Slot`／`PlayerId` NV（R4G-CX-10）。
- CPU 遠低於 16.6 ms，記憶體可忽略。網路粗估：4 人房 Host 轉送 NT `3×3×10 Hz×約 40 B ≈ 3.6 KB/s`＋心跳 69 B/s，在 GDD OQ#12 的 15–25 KB/s 之內（40 B 是估計，未實測）。「Host 出站總預算」仍無 ADR 擁有（TR-netcode-018）。

---

## 5. GDD Revision Flags（Phase 5b）

共 28 條：🔴 HIGH 3／🟡 MEDIUM 11／LOW 14。r3 的 20 條中 GF-20 由 HIGH 降為 LOW（設計層已解）；本輪新增 8 條（GF-21–28）。GDD 自 r3 以來沒有改動。

### 5A. r3 旗標的現況

| ID | GDD 行 | r4 狀態 | 說明 | Migration 4 |
|---|---|---|---|---|
| GF-1 | netcode :1188、:1256、AC23 | 🔴 仍在 | `interpolation_buffer_ms = 150` 模型錯誤，歸 G8 | 不屬 0006 |
| GF-2 | FPC F1 :564-578 | 🔴 仍在 | `L_p95 = 0.339`，歸 G8 | 不屬 0006 |
| GF-7 | netcode #24 :580-605、AC56 | 🔴 內容微變 | 結論不變；AC56 多兩個前置：avatar 要先經 `PlayerJoined` 生成；強制 `DisconnectClient` 要帶非空 reason，斷言至少等一幀 | ✅ 0006:800（兩個前置未列） |
| GF-20 | netcode :758、AC51 | **🔴→LOW** | handler 被拒不 throw → :758「approval 拒絕但 MPS 成員已成立」成立。只需補一句機制；:755 JoiningRoom 列「→下一局 Lobby」改為「→ Lobby\*（LobbyWaiting）」；註明多一次 Relay join 與握手 | ✅ 0006:798（:755 未列） |
| GF-8 | FPC :397-399、AC19 | 🟡 措辭微變 | Migration 4 的文字已是 r2 語意；SI:22 備註仍寫「`PlayerLeft(slot)` 必清」 | ✅ |
| GF-9 | netcode #9 :161-162 | 🟡 內容有變 | FV-2 已修；`IsPrivate` 讓加入前的預檢不存在，GDD:161-162 應**刪除**預檢 | ✅ |
| GF-12 | machine C13、C20 | 🟡 仍在 | 「地面」狀態、持有者欄、`OwnerClientId` 掛錯手 | ◑ G2 已承接，MI 側未列 |
| GF-14 | netcode :205-209、:232-233 | 🟡 內容有變 | 送出點只剩 `pagehide`；`persisted` 一律送並重載；Safari 跨源 iframe 不跳框 | ✅ |
| GF-15 | netcode 矩陣 | 🟡 內容有變 | #24a 改為各讀一半；#9 Lobby 欄只會被 Host 自身請求讀到 | ◑ #9 Lobby 欄未列 |
| GF-16 | netcode :723、:739、:756、AC37 | 🟡 內容有變 | 延後 spawn 後沒有殭屍 avatar；仍須釋放 slot、`RemovePlayerAsync`、切 NGO、不發 `PlayerLeft`。新問題：AC37「roster 從未出現其名字」對上 `RosterEntry.Phase = Onboarding`，ADR 沒寫 Roster 何時寫入 | ◑ :1095-1096 與 roster 語意未列 |
| GF-17 | netcode #24 | 🟡 內容微增 | Settlement 跳步、`Release`、`try { await }` | ✅ |
| GF-3、4、5、6、10 | — | LOW 仍在 | 同 r3 | GF-10 ✅；其餘未列（輕微） |
| GF-11 | netcode :379、:381-383 | LOW 一半已列 | 「序號與秒數混用」未列 | ◑ |
| GF-13 | netcode :789、:800-802 | LOW 內容有變 | 另有 :785「`OnClientConnectedCallback` → roster 建立」對中途加入者已不成立；:800 `local_ready` 方向反轉 | ◑ |
| GF-18 | netcode :140-142、:846-847 | LOW 仍在 | [P-4]「未驗證」、「高風險假設」已過時 | **✗ 漏列** |
| GF-19 | SI:38 | LOW 加重 | Lobby\* 沙盒以獨立 Solo Core 運行，是 MVP 路徑；#19 仍排 Alpha | **✗ 漏列** |

### 5B. 新旗標

| ID | 嚴重度 | GDD 行 | 假設 → 現實 | 修法 |
|---|---|---|---|---|
| **GF-21** | 🟡 需裁決 | netcode #12 :195-198、矩陣 :724 | GDD 要 Lobby 與 InShift 都掛確認框 → ADR 只在 InShift 掛（0006:234；AC42 只測 InShift） | 擇一：GDD r5 把 #12 縮到 InShift（理由：Lobby 刪房有 1.14 s 的優雅路徑）；或 ADR 在 Lobby 也掛。**決定 TR-netcode-010 是 ✅ 還是 ⚠️** |
| **GF-22** | 🟡 需設計釐清 | netcode #10 :181-183、:1097-1098、AC4 :1396、AC40 :1465；FPC :453-462 | 原假設：可移動的角色在本機就有，與世界同步無關 → 延後 spawn 後，client 的「進場」是 Host 在 Onboarding 計時結束後送來的 avatar spawn 訊息；過場實際長度＝Host 計時＋（spawn 單程延遲－approval 單程延遲），WSS 單一 TCP 的 HOL 會放大 | GDD r5 擇一：① AC40 明定被延遲的是世界狀態 NV、不含本機 avatar spawn；② Host 的 Onboarding 計時扣掉預期單程延遲；③「可移動」改以 avatar 抵達為準，AC4 寫明哪一端量 |
| GF-23 | LOW | netcode :800、:759；FPC :55、:475、:878-880 | `local_ready` 不再由 #3 送出，而是 #2 從 avatar `OnNetworkSpawn` 推得；Host 在 `OnServerStarted` 就是 InShift，轉場仍在進行 | GDD r5 改契約表方向；States 表註明 |
| GF-24 | LOW | netcode :275、:206 | #17a 一律寫 `LeaveAsync` → Host 必須 `DeleteAsync`。**Migration 4（0006:797）要把 :206、:275、:609 一律改名為 `LeaveAsync`，照做會把錯寫進 GDD** | Migration 4 改為「client `LeaveAsync`／Host `DeleteAsync`」；TR-netcode-014 措辭同步 |
| GF-25 | LOW | AC51 :1485 | Lobby\* 畫面要顯示「在場隊友人數」→ 沒有 NGO 的端讀不到 `Roster`；`shift_eta` 沒有人數；MPS 成員數 ≠ `online_player_count` | `shift_eta` 加 `online_count`，或 GDD 改顯示成員數並註明口徑。前幾輪漏抽，本輪登記為 **TR-netcode-047**（❌） |
| GF-26 | LOW | SI:39 | #20 Depends On 寫 `sendBeacon` → keepalive fetch、只在 `pagehide` | SI:39 改字；TR-index-027 措辭同步 |
| **GF-27** | 🟡 | netcode #8 :140-142（帶碼連結為主要入口）；TR-netcode-007 | 「開連結就帶碼進房」→ Safari 對跨站 iframe 的 `document.referrer` 一律降為 origin，itch.io 上恆為 null，Safari 使用者每次都要輸碼（F R4F-5） | GDD #8 補 Safari 註記；要不要為 Safari 另找入口（例如 itch.io 以外的直開頁）是產品決策 |
| **GF-28** | 🟡 | netcode :763-765（Settlement 的 socket close 一律視為離開）、矩陣 #18 Settle＝Y（:732） | 與 :761「#23a teardown → Lobby」互相拉扯；照前者，#23a 的 NGO 斷線會讓 client 走 #18 → Teardown（M1） | GDD r5 把 :763 的 socket close 限定為 MPS／Wire 層；#18 Settle 欄註明「`ShiftEnded` 原因除外」 |

### 5C. Migration 4 的涵蓋核對

- 已涵蓋：GF-7、8、9、10、14、17、20。
- 部分：GF-11、12、13、15、16（各漏一處，見 5A）。0006:936 自稱 GF-15、GF-16 已列入，逐條核對只做到部分。
- 漏列：GF-18、19、21、22（只定了 `local_ready`）、25、26、27、28；輕微的 GF-3、4、5。
- **GF-24 不只是漏列**：Migration 4 的改名指令本身會把錯誤帶進 GDD。

### 5D. `systems-index.md` 備註應更新的內容

- **#1／#2**：GF-20 改為「已裁決 (a)，:758 成立，只需補一句機制並改 :755（降 LOW）」；GF-16 改為延後 spawn 後的版本（roster 語意、:1095-1096）；GF-9 改為「#9 :161-162 應刪除預檢」；新增 r4 一段：GF-21、22、23、24、25、27、28，GF-14 補 `persisted`／Safari，GF-17 補 Settlement 跳步，#26 補 `ShiftStartAborted` 邊與 `shift_end_ts` 建立時刻，GF-18。
- **#3**：r2 那句改為「以 `PeerKey` 為鍵；本端該 slot 的 avatar despawn 時清除（Host 端排除本機 avatar 時用 spawn 當下快取的旗標）」；新增 GF-22、GF-23、TR-fpc-019、GF-3。
- **#5**：維持 Needs Revision；可補 `InteractResponseRpc` 應 `InvokePermission = Server`（R4G-CX-7）。
- **#19**：補 GF-19（沙盒是 MVP 路徑）。
- **#20**：GF-26。

---

## 6. Engine Compatibility（Phase 5）

### Engine Audit Results

Engine：Unity 6.3 LTS（6000.3.24f1）／NGO 2.13.2／MPS 2.3.1／UTP 2.7.4
ADRs with Engine Compatibility section：**5 / 5**

- **版本一致性**：五份彼此一致，也與 PackageCache 相符；ADR-0005 r2 已釘成 UTP 2.7.4、6000.3.24f1（r3 §6 NOTE ✅）。ADR-0006 沒釘 Authentication 3.7.4、Services Core 1.18.0、Wire 1.5.0（R4D-11，LOW）。
- **Deprecated API References**：實際使用 **0**。兩份 ADR 只用 `[Rpc]`，不用 `[ServerRpc]`／`[ClientRpc]`／`RequireOwnership`；只用 `RelayNetworkOptions(string region = null, bool preserveRegion = false)`；用到的 NGO API 皆無 `[Obsolete]`。`RequireOwnership` 與 `InvokePermission` 同時宣告時 ILPP 報錯（`NetworkBehaviourILPP.cs:1695-1714`），ADR 已避開。
- **Stale Version References**：無。
- **C# 版本**：兩份 ADR 的程式片段沒有 C# 10+ 語法（設計攻擊者逐段檢查）；命名空間遮蔽陷阱（`NightShift.Session.Unity` 遮蔽根命名空間 `Unity`）已以 6000.3.24f1 內建 Roslyn `-langversion:9` 重現屬實，另有同類的 `NightShift.Session.Editor`（R4E-7）。
- **Post-Cutoff API Conflicts**：ADR-0005／0006 之間的 `InstallLeaveBeacon` 簽章、`SetLeaveConfirmation`、組合根、WSS 規則一致；與 ADR-0001／0002／0003 無新的 API 衝突。

### Engine Specialist Findings

依記憶 `feedback_specialist_maxturns_in_reviews`：unity-specialist 的 agent 定義 `maxTurns: 20` 會截斷原始碼追蹤，本輪由不設上限的 agent 扮演 unity-specialist，分 MPS 與 NGO 兩份。

**MPS／Lobby／Authentication／Wire**（9 組承重主張、96 處引用）
- 承重前提全部 CONFIRMED：自有 handler 被拒時正常返回 → 不 leave、仍是成員（15 跳逐行）；`Bind` 的必要性；`WithNetworkHandler<T>` 簽章與 `NetworkHandler` setter 只在 `Stopped` 可用；Lobby REST 路徑、方法、204、只需 Bearer；`IsPrivate` 可以碼加入。
- r2 修訂紀錄的「7 條新發現」：1、2、6、7 CONFIRMED；3 的機制 CONFIRMED；5 PARTIAL；4 由 NGO 稽核 CONFIRMED。
- 引用 96 處中 91 處吻合；:221 兩處偏移 2 行；:93 內容部分不符（那是檢查，不是登記）；:18、:104、:115 前綴歧義。
- 新發現：K12、K13（§3B）；R4D-3–11（§3C）。

**NGO／UTP／IL2CPP**（61 條主張、約 95 處引用）
- 承重主張大多 CONFIRMED：延後 spawn 下 Host 不自建 avatar；晚加入者的初始同步不依賴 player object；Host 時序（自核准 → `OnServerStarted` → `OnClientConnectedCallback(0)`）；遠端請求必在 `OnServerStarted` 之後；stopped 事件順序與 transport 狀態；EA-5 列舉名、代轉改寫發送者；ConfigHash 組成；`SpawnAsPlayerObject` 對已斷線 clientId 造鬼 client（r2 新發現 4）；W1 linker 只把兩個組件當 root。
- 推翻：0006:162「approval 逾時送通用字串」（→ M5）。
- 新發現：M2、M6、K11（§3）；R4E-4–9。
- 無法驗證：include-only 的 `.Web` 在 Editor 不編譯——目前沒有實例可證，ADR 已如實標為推論。

**瀏覽器平台**（32 條主張；一手文件＋引擎原始碼＋本機實測）
- 承重主張全部成立：`beforeunload` 先於 `pagehide`（HTML §7.4.2.4／§7.3.1.6）；按「留下」不送；Chrome／Firefox 跨源 iframe 跳框需 sticky activation、Safari 不跳；Firefox ≥ 133；WPT 數據；UGS preflight；keepalive 64 KiB；`sendBeacon` 不能帶自訂標頭。
- **本機實測首次直接證明**：跨站 iframe 在 `pagehide` 送出的 keepalive DELETE＋Authorization＋preflight，在 Chrome 154 stable、Playwright 版 Firefox 155／WebKit 26.6 都在頁面死後送達（三 origin 重現 itch.io 形狀，接收端延遲 800 ms 回應）。限制：loopback HTTP、Firefox／WebKit 是 Playwright 修補版、真實 Safari 與真實 itch.io 未測。V10 仍待在真實環境跑。
- 需修：T1-Web 測試規格、Chrome bfcache WebSocket 敘述、Safari referrer（§3B）；R4F-6–10（§3C）。

**UGS preflight**（主審 2026-10-04 09:07 UTC 親自重跑，未帶憑證）

```
OPTIONS /v1/test-lobby-id                         → HTTP/2 204
OPTIONS /v1/test-lobby-id/players/test-player     → HTTP/2 204
  access-control-allow-origin: *
  access-control-allow-methods: GET,POST,PUT,DELETE,PATCH,HEAD
  access-control-allow-headers: authorization
  access-control-max-age: 600
```

### 參考庫（`docs/engine-reference/unity/`）缺口

參考庫自 09-28（`20aa076`）之後沒動過。**r3 列的 15 條全部仍缺**（含 r2 遺留的 4 條）。本輪新增 7 條：

| 檔 | 缺口 |
|---|---|
| multiplayer.md | 有 peer 的 Host 關機時，NGO 對所有 client 送同一個原因字串 `"Disconnected due to host shutting down."`；要區分原因須先 `DisconnectClient(id, reason)`（M1） |
| multiplayer.md | MPS `UpdateDerivedProperties` 會回滾 Host 未存出的屬性；本機 null 值＋伺服器有 key → NRE；`StopNetworkAsync` 存檔失敗把模組設回 `Started`（M4、K12） |
| multiplayer.md | NGO approval 逾時走 internal 多載、不送原因字串；通用字串只代表訊息不完整或雜湊不符（M5） |
| multiplayer.md | `ClientsToApprove` 不隨斷線清除；pending 核准晚到會 `AddClient` 造鬼 client（M6） |
| multiplayer.md | 自訂 `INetworkHandler` 的實際契約（H1–H7 的原始碼依據），以及它違反兩句官方註解這件事 |
| web.md | 「離開通知」一節的本輪實測素材：keepalive＋preflight 三引擎送達；Chrome bfcache 中 WebSocket 不立即斷；Safari 第三方 referrer 降為 origin；Playwright 的 `page.close()` 會跑 `pagehide`、預設關 bfcache、WebKit `runBeforeUnload` 卡住 |
| current-best-practices.md | 命名空間遮蔽陷阱：專案命名空間不得有 `Unity`、`Editor` 這類與引擎根命名空間同名的段 |

---

## 7. Architecture Document Coverage（Phase 6）

`docs/architecture/architecture.md`、`control-manifest.md` 仍不存在。建議在 G2、ADR-0004、G4 落地後跑 `/create-architecture`。

---

## 8. Verdict

### **FAIL**（覆蓋 +1、補登 TR-netcode-047；ADR-0006 r2 仍不能 Accept——r3 的 7 條必修全數修好，新必修 9 條，全部局部修法）

依本 skill 判準「FAIL：Foundation／Core 層需求無 ADR，或有 blocking 的跨 ADR 衝突」。Foundation 層仍有 **20 條 Gap**，CX-1 仍擋 ADR-0001／0002／0003。

**走勢**：

| 指標 | 首輪 | r2 | r3 | r4 |
|---|---|---|---|---|
| Total TR | 227 | 228 | 228 | 229 |
| ✅ Covered | 50 | 71 | 71 | 72 |
| Foundation Gap | 30 | 20 | 20 | 20 |
| ADR-0006 Accept 前必修 | — | 4 | 7 | 9（🔴 1、🟡 8） |
| 上一輪必修的修好率 | — | — | 3.5／4 | **7／7** |
| 需要設計裁決的必修 | — | 0 | 1（FV-1） | **0** |
| 承重原始碼主張經對抗驗證被推翻 | — | 0 | 0／9 | 0（K3、K12 的強主張被推翻，屬審查者高估） |

必修數上升，不是 r2 退步。新的 9 條分三類：

- **r2 新機制沒定義的邊**（6 條）：M2（延後 spawn 的 slot 0）、M3（沙盒 Core 的輸出）、M5（H2 的 `Failed`）、M6（`NotAMember` pending）、M7（`SessionRoot.Ready`）、M9（LobbyWaiting 的復原）。
- **一直存在、四輪沒人從另一端走過**（2 條）：M1（client 端的 #23a）、M4（#23a 的存檔失敗；r2 只處理了 #26 側）。
- **把義務交給下游，但判準只在本 ADR**（1 條）：M8（輸入閘門）。

沒有一條需要重新裁決方向，FV-1 的方向經原始碼證實正確。

### Blocking Issues（解除後方能 PASS）

1. **Foundation 無 ADR**（20 條，與 r3 同）：G4（product-001–005、014、016）、G5（product-018、020–022；machine-054）、G6（product-006、007）、G2（netcode-033；machine-010、027）、G7（fpc-029）、G8（fpc-040）、ADR-0004（machine-023）。
2. **ADR-0004 未寫**；ADR-0002 與 machine C20 的 8 處分叉不變（首輪 D1）。
3. **`interpolation_buffer_ms` 模型錯誤**仍在兩份 GDD 的數值骨幹裡（GF-1、GF-2）。
4. **身份契約已裁決、未傳播**（CX-1）：擋 ADR-0001／0002／0003 的 Accept。
5. **ADR-0006 的 Accept 前必修 9 條**：
   - M1 🔴 client 在 Settlement 收到 #23a 斷線沒有轉移（每班結束 client 全員回主選單）
   - M2 Host 的 slot 0：`PlayerJoined(0)` 來源矛盾、`OnClientConnectedCallback(0)` 無處置
   - M3 沙盒 Core 的輸出沒有作用域
   - M4 #23a 存檔失敗沒有出口（含 MPS null NRE）
   - M5 H2 的 `Failed` 是靜默死路
   - M6 `NotAMember` pending 造鬼 client
   - M7 `SessionRoot.Ready` 是實例事件
   - M8 輸入閘門沒有事件
   - M9 LobbyWaiting 的復原轉移

### Non-blocking（CONCERNS，進 PASS 前應收斂）

- **ADR 本身**：§3B（K12、K13、R4C-10、R4C-12、R4C-13、R4A-4、T1-Web 測試規格、Chrome bfcache 敘述、Safari referrer）；§3C 全部；§4 的 R4G-CX-5–12。
- **GDD**：§5 的 MEDIUM／LOW 旗標，其中 GF-21、GF-22 需裁決或設計釐清。
- **參考庫**：§6 的 22 條缺口（r3 的 15＋本輪 7）。
- **首輪延續**：C2–C4、D4、D6、D9／D10。

### Required ADRs（最 Foundation 者優先）

| 序 | ADR | Layer | Engine Risk | 理由 |
|---|---|---|---|---|
| 1 | **ADR-0006 r3**（＋ADR-0005 小修，成對 Accept） | Foundation | HIGH | §3A 九條必修（全部局部）；順手收 §3B 的 K12（隱性前提寫明）、R4C-10、R4C-12、R4C-13、T1-Web 規格。ADR-0005 只需 §3B 的 Chrome／Safari 敘述與 Verification ④ 限定 |
| 2 | **ADR-0001／0002／0003 r1** | Core | — | CX-1 身份傳播；M7／M8 的下游義務（`SessionRootSpawned`、`LocalInputGateChanged`）；pointer lock T1-Web（TR-fpc-019）；R4G-CX-7–9、12 |
| 3 | **G2** 同步物件生命週期與所有權轉移 | Foundation／Core | HIGH | 15 條 TR（3 條 Foundation Gap）；`SpawnAvatar`／`DespawnAvatar` 的歸屬與 avatar 身分 NV（R4G-CX-10）；掉落路由；道具「地面」狀態（GF-12） |
| 4 | **ADR-0004** 機台互動組 Core | Core | MEDIUM | 29 條 TR；吸收 ADR-0002 的 8 處分叉；`InteractResponseRpc` 的 `InvokePermission`（R4G-CX-7） |
| 5 | **G4** SKU 資料格式與序列化凍結 | Foundation | MEDIUM | 16 條 TR（7 條 Foundation Gap）；`BuildId` 雜湊輸入含 `ProductCatalogAsset` 與 `GetConfig(false)` |
| 6 | **G8** 延遲模型與容差 | Core | HIGH | 解 GF-1、GF-2；GF-22 的時間語意也落在這裡 |
| 7 | **G5** 建置期資料治理閘門與 CI | Foundation | MEDIUM | 不變；R4C-26 的 WebGL 腳本編譯也該進 CI |
| 8 | **G7** 攝影機與渲染基線 | Core／Pres | HIGH | 不變 |
| 9 | **G6** 資產繫結與載入 | Foundation | MEDIUM | 不變；可併 G4 |
| 10 | **G9** 遊戲時鐘與班次時基 | Foundation | LOW | 先 `/design-system 遊戲時鐘` |

---

## 9. arlong 裁決（Phase 8，2026-10-04）

| 問題 | 裁決 |
|---|---|
| 寫入範圍 | 三份都寫：本報告另存 `architecture-review-2026-10-04-r4.md`（r3、r2、首輪保留）；`traceability-index.md` 就地更新為 r4；`tr-registry.yaml` 升 version 5（TR-netcode-010 partial→covered；TR-netcode-030 的 `adr` 欄 0001→0006；新增 TR-netcode-047；無 deprecated） |
| `systems-index.md` | 依 §5D 更新 #1／#2／#3／#5／#19／#20 備註；Status 不變（#1／#2／#3／#5 已是 Needs Revision） |
| TR-netcode-047 | 登記（AC51 在場隊友人數；Core 層；gap） |
| TR 措辭（附錄 B） | 主審採用的預設（未另問）：暫不改。GDD 自 r3 起未變，依 registry 規則等 GDD r5 回填後同步 |

---

## 10. 審查方法與可信度

| 階段 | agent | 結果 |
|---|---|---|
| 審查 | r3 必修／應修核對；r3 LOW 項＋registry＋交叉引用；設計攻擊（r2 新內容）；MPS／Lobby／Auth 原始碼稽核；NGO／UTP／IL2CPP 原始碼稽核；瀏覽器平台查證；追溯＋跨 ADR＋GDD 旗標——共 7 份，全部完成 | 原始發現：必修核對 7 條新缺陷；registry 11 條；設計攻擊 26 條（🔴 2）；MPS 11 條；NGO 9 條；瀏覽器 10 條；跨 ADR 12 條＋GDD 旗標 26 條 |
| 去重 | 主審 | 同一缺陷被 2–4 位審查者獨立找到的合併為 13 組（K1–K13） |
| 對抗驗證 | 2 個反駁者，分組試圖以 ADR 全文與原始碼推翻 K1–K13 與其餘 MEDIUM | 0 組整條被推翻；🔴 2 條皆降為 🟡（R4C-1 需實作者另做未規定的選擇；R4C-2「永遠開不了下一班」被原始碼推翻）；K10 經 V2 確認、主審判為 🔴；K12、R4B-1、候選描述的 R4F-2 被推翻 |
| 主審抽查 | K1（`NetworkManager.cs:1495-1545`）、K3（`NetworkModule.cs:228-250,340-382,630-642,685-718`）、K10（`NetworkManager.cs:545-575`＋ADR Decision 8）、R4D-1（`SessionHandler.cs:1010-1060,1105-1145`）、R4B-6（0006:178）、UGS preflight 實測 | 全部吻合 |

**方法註記**：
- unity-specialist 的 `maxTurns: 20` 會截斷原始碼追蹤（r3 已記），本輪兩份引擎稽核都由不設上限的 agent 扮演 unity-specialist，各自讀完原始碼。
- 瀏覽器查證者第一次回報說已寫出結果檔，**實際上沒有寫出**；主審要求補寫後，它另做了本機 Playwright 實測，結論比第一次的摘要更完整，也修正了第一次摘要裡兩處說法（Chrome 不是「不進 bfcache」，而是「進了但連線不立即斷」）。本報告只採用寫成檔、附腳本與來源 URL 的第二版。

**未經對抗驗證**：瀏覽器的實測結論（單一查證者，腳本留存於工作目錄）；LOW 級的 R4B／R4C／R4D／R4E／R4F；GDD 旗標。

**不確定之處**（照實標註）：
- M4 的 NRE 傳播後的效果（`LobbyHostChanged` 等被跳過）是推論。
- M6「8 s 後移出正在重新加入的合法成員」是推論。
- K12 的「handler 先讓出過，MPS 的接續仍同步執行」依 C# await 語意推論，套件內查不到原始碼。
- K13 服務端對重複加入回 409 是推論。
- Safari「itch.io 上 referrer 恆為 null」是依 WebKit 政策推論，未用真實 Safari 開 itch.io 驗。
- Chrome bfcache 的逐出時限長度未查證；實測只到 ≥ 30 s。
- 瀏覽器實測的限制：loopback、Playwright 修補版 Firefox／WebKit、無真實網路延遲。
- V1、V10、V11、V13–V16 全部仍待實跑；FV-1 的修法目前只有原始碼證據，W1 從未測過遠端 client 被拒。

---

## 附錄 A — 本輪理由有變、狀態不變的列

| ID | r4 | 理由更新 |
|---|---|---|
| TR-netcode-008 | ✅ | FV-3 已修（`ShiftEndTs` 在 `OnServerStarted` 固定）；FV-1 已修（被拒者留在 session）。`IsPrivate` 取消了加入前預檢，TR 原文「MPS custom data 預檢非權威」措辭交 GF-9 |
| TR-netcode-009 | ✅ | 兩層閘門（EA-2）；加入後比對 `build_token`；但 `Failed` 分支是死路（M5） |
| TR-netcode-011 | ⚠️ | `AttemptStarted` 一觸發就從 `T_lobby` 改計 `T_spawn`；`T_load` 仍只有 stall 偵測；「auth 預熱並行」無決策 |
| TR-netcode-014 | ✅ | Host 走 `DeleteAsync`，TR 與 GDD #17a 只寫 `LeaveAsync`（GF-24） |
| TR-netcode-017 | ✅ | `InvokePermission = Server`（EA-5）；slot 重用時重置（FV-10） |
| TR-netcode-019 | ✅ | 自有 handler 是 NGO 啟停唯一擁有者，FV-1 從根上解決；但 #23a 失敗無出口（M4） |
| TR-netcode-024 | ✅ | 第 6 步 `try { await }`；`MaxPlayers = max_players` |
| TR-netcode-028 | ⚠️ | FV-8、FV-1 已修；殘留看門狗「緩解」、M1、M9、`ShiftStartAborted` 邊未回 GDD |
| TR-netcode-029 | ⚠️ | CX-2 已修；`local_ready` 有定義；GDD 的 `OnTransportFailure` 在 0006 零命中；下游契約多歸未寫 ADR |
| TR-netcode-030 | ⚠️ | **ADR 欄改為 0006**（TickRate 自 r2 起歸 0006）；「NV 10 Hz 的連帶效應」仍無人評估 |
| TR-netcode-031 | ⚠️ | 延後 spawn 後，「同步未完仍準時進場」改由 Host 送來的 avatar spawn 決定，與 AC40 衝突（GF-22） |
| TR-netcode-033 | ❌ | 邊界案例，見 §1 |
| TR-netcode-036 | ✅ | 初值在 `OnServerStarted` 寫入；但單位錯（R4B-6） |
| TR-netcode-039 | ✅ | Host 自身請求只判第 1–3 項；但 slot 0 的 `PlayerJoined` 來源矛盾（M2） |
| TR-netcode-041 | ✅ | `SessionConfig` 改為 Core 純 C#；`Validate()` 12 條，漏 `MaxPlayers`（R4C-24） |
| TR-netcode-046 | ⚠️ | 見 §1 |
| TR-fpc-011 | ⚠️ | CX-3 的加重理由已因延後 spawn 消失；CX-1 仍在 |
| TR-fpc-019 | ❌ | 交棒已登記為 ADR-0001 r1 的 T1-Web 義務；「不自動重鎖、吞掉重鎖點擊、鎖定狀態輸出給 HUD」仍無決策 |
| TR-fpc-020 | ⚠️ | 同上；「焦點≠隱藏」已由 0005:85 裁決 |
| TR-fpc-027 | ⚠️ | `local_ready` 已有定義；AC40 的時間語意（GF-22）；0006:771 漏 Host 特例 |
| TR-fpc-028 | ⚠️ | 非 Host 端在場來源已定；各階段的輸入採納沒有事件（M8） |
| TR-index-027 | ⚠️ | FV-4、EA-1 已修；Rich Presence 那一半歸 Alpha；V10 未實測；TR 原文 `sendBeacon` 待改（GF-26） |
| TR-concept-003 | ⚠️ | 確認框瀏覽器矩陣、跨源 preflight 證據已補；pointer lock 的 T1-Web 交棒已登記但 ADR-0001 未承接；Safari 讀不到帶碼 referrer（GF-27） |

## 附錄 B — Phase 8 的 TR 措辭建議（同一意圖、ID 不變）

- **TR-netcode-046**：「Lobby 預檢、Lobby\* 等待畫面」改為「加入後的 Lobby、Lobby\* 等待畫面（私人房在加入前讀不到屬性）」。改完即可轉 ✅。
- **TR-netcode-008**：「MPS custom data 預檢非權威」改為「加入後讀 `shift_eta` 僅供顯示、非權威」。
- **TR-netcode-010**：「`beforeunload`＋`pagehide`→`sendBeacon`／`DeleteAsync`」改為「只在 `pagehide` 以 keepalive fetch 送出，`beforeunload` 只掛確認框」。
- **TR-netcode-014**：「`ISession.LeaveAsync()`」改為「client `LeaveAsync()`／Host `DeleteAsync()`」。
- **TR-netcode-030**：ADR 欄 0001 → 0006。
- **已登記 TR-netcode-047**（arlong 2026-10-04）：AC51「Lobby\* 畫面顯示在場隊友人數」（GF-25）。
- 以上五條措辭修改暫不寫入 registry：GDD 自 r3 起未變，依 registry 規則「GDD 措辭改了才改 requirement」，待 GDD r5 回填後同步。
