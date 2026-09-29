# Active Session State

> Last Updated: 2026-09-24
> Purpose: Living checkpoint. Read this first after compaction or new session.

**目前唯一在推進的專案＝大夜班 (Night Shift)。** Road Rage 與其他遊戲皆為已完成／暫停
的歷史紀錄，本檔往下排序即依此：現行專案在前，歷史在後。

---

# 現行專案：大夜班 (Night Shift)

**階段：Pre-production。** 2026-09-03 開案，至今 13 天。

## 目前任務（2026-09-29）

- **Task**：設計 #5 機台互動組 GDD（`/design-system 機台互動組`）
- **File**：`design/gdd/machine-interaction.md`
- **Status**：✅ **完成（2026-09-29）**——803 行、11 節零 placeholder、45 AC（必達 6）；registry +5 formulas +11 constants、10 條 referenced_by；索引 #5 Designed、#7／#15 補登、前向義務表 +4 列；CD-GDD-ALIGN 依 solo 跳過
- **未 commit**：machine-interaction.md、systems-index.md、entities.yaml、active.md——待 arlong 指示
- **Next**：新 session 跑 `/design-review design/gdd/machine-interaction.md`（不得在本 session）；`/architecture-review`（三份 ADR）；ADR-0004 候選（#5 Core 分層，OQ-M14）；`/ux-design` hud（UX 旗標）
- **Sections done**：A Overview（2026-09-28；裁決：維護動作歸 #5 但 MVP 只做補貨；五台全設計、逐台點亮歸 #17）；B Player Fantasy（2026-09-28；框架 A「手會記得」＋ B 的撲空判準；關東煮永遠不出包；發現 2、3 已登記 netcode）；C Detailed Design（2026-09-28；C1–C19；裁決：走開時 Working 自主繼續、Ready 隊友可拿、獨立 Interaction map、Faulted 預留不實作；levy 登記 #4/#7/#11/#14/netcode）；D Formulas（2026-09-29；F1–F9；淨旋鈕九個：reach 0.8／hysteresis 0.20／buffer 2／微波 18／咖啡 22／寬限 18+18（2026-09-29 由 16 修正：qa-lead 抓到 grace ≥ T_max+B = 17 在原稿不成立；F3 改成 T_max／T_min 端點式）／d_peak 3 未測量／restock 4；推導量 leave 1.3、ray 1.4、whiff 200+150=350→400；T=crossing_time 11–15 暫借無出處；`ready_item_spoil_sec` 明寫不存在；`action_min_interval_ms` 不登記）；E Edge Cases（2026-09-29；systems-designer 16 條＋追加 4 條全納入；四個新概念回寫 C：SKU 槽（射線回 (stationId, sku)、OutOfStock 為每 SKU 全域條件）、庫存決定 Shelf 手勢語意（>0 點按拿、==0 按住補）、對另一台 claim＝離開前一台（第四觸發源）、第一下＝claim＋動作一則 RPC；Ready→Spoiled 換件；新拒絕值 NothingToTake；同 tick 先 RPC 後逾時掃描；四條 ⏳ levy 待 Phase 5 登記：ADR-0002／#7／#15／#11 關卡佈局）；F Dependencies（2026-09-29；上游 9／下游 6；索引 #7、#15 列缺本系統 → Phase 5 補）；G Tuning Knobs（2026-09-29；九個旋鈕＋「不是旋鈕」表；T 不是旋鈕，換版面＝重跑 F3）；Visual/Audio（2026-09-29；art-director＋audio-director；裁決：Spoiled 每家族一款、Ready 疊互動黃、空排面無中間態；訂正 C2／Fantasy 關東煮 MVP 無界）；H Acceptance Criteria（2026-09-29；qa-lead AC1–40 ＋ 主 session AC41–45；必達 19/24/25/32/37/39；覆蓋矩陣）
- **上游已鎖定**：ADR-0002 定了驗證模型；商品資料庫規則 3b／4；FP 四條硬拒絕；三份 ADR 皆 Proposed
- **本週里程碑**（2026-09-26～28，四個 commit）：FP GDD 十位專家評審 → 修訂 → 32/32 T0 純 C# 實測；
  OQ-F1 itch.io pointer lock 實測通過；ADR-0001／0002／0003 寫入，registry 3/3/5/8
- **下次新 session 先做**：`/architecture-review`（三份 ADR 的覆蓋率與互相一致性，不得在本 session 跑）

## 一句話現況

**設計深度夠，但只深在一個系統上；正式程式碼還是零。**（2026-09-28 補：現在深在兩個系統上，且純 C# 原型 32/32。）

| 項目 | 狀態 |
|---|---|
| 遊戲概念 | ✅ 完成 — `design/gdd/game-concept-night-shift.md` |
| 引擎決策與環境 | ✅ 完成 — Unity 6.3 LTS（arlong 指定），參考文件已建 |
| 美術聖經 | ✅ 第 1-4、8 節 — `design/art/art-bible-night-shift.md`（5/6/7/9 刻意延到原型後） |
| 系統索引 | ✅ 19 系統盤點，MVP 14 項 — `design/gdd/systems-index.md` |
| **GDD** | **19 份完成 2 份，第 3 份進行中** — `netcode-session.md`（#1、#2，r1-r4）＋ `product-database.md`（#6，**r3 複審完成 2026-09-21，裁定為最後一輪散文評審**）＋ `first-person-controller.md`（#3，**2026-09-24 完成，待獨立複審**） |
| **原型（非 W1）** | `prototypes/product-database-core/` — 純 C# 核心，**50 PASS / 0 FAIL**，r3 終審 Design Test 撞 3/5，AC15a 已成活絆線（三次汙染測試皆亮紅） |
| W1 原型 | 第 0-4 批；20 條假設**結案 9 條** |
| **正式程式碼** | **0 行。大夜班沒有 Unity 專案。** |

⚠ 目前所有 Unity 程式碼都在 `prototypes/w1-netcode/`，依 `.claude/rules/prototype-code.md`
那是**拋棄式的**——結論若支持進生產，程式碼**重寫而非搬移**，且生產程式碼不得引用該目錄。

## 目前任務（2026-09-24）

**Task**: #3 第一人稱控制器 GDD — ✅ **完成**
**File**: `design/gdd/first-person-controller.md`（1390 行，11 節，**零 placeholder**）
**Status**: **Designed，待獨立複審**（`/design-review` 必須另開 session）

**射程**：移動 ＋ 視角 ＋ 碰撞。不含互動（#5）與攜帶（#4）。

🔴 **硬交付已兌現**：`player_move_speed_max = 1.39 m/s`
→ netcode 的 `blocked-by: 第一人稱控制器 GDD` 已解除（`netcode-session.md:1256/1433/1538` 已改）。
⚠ **但擋路石是換人不是消失**：U1 指出 **AC23 的 `≤ v × dt` 在構造上餘裕為零**
（遠端內插在 owner 全速時恰好等於它），會在正確的實作上隨機紅燈。
**AC15 是同一個形式而原本沒被標**，現已與 AC23 一起改標 `blocked-by: remote_step_tolerance`（暫定 1.5，歸屬 netcode）。

**registry `formulas` 4 → 7 筆**：`player_frame_budget`、`depenetration_delta`、`should_warn`
（2026-09-24 `/consistency-check` 補登；三條都是跨系統事實，#4／#5 消費前兩者產生的位置）。

**八個 registry 常數已登記**（含四個「不是旋鈕」的架構推導值）。
**AC 節 43 條，今天可執行 24 條（56%）全在純 C#**——但前提是移動求解器為純 C#（OQ-F11）。

### 本輪關閉／裁決的事
- OQ-P13（遊戲內語音）**已關閉**：MVP 不做語音，非語音 ping 欠 #11
- Player Fantasy 採 A＋B 合寫；六條「擁擠」判準全收，判準 3／5／6 依專家意見改寫
- G12（碰撞權威）裁決：**本機渲染位置解算、雙向自我解除穿透、零訊息**
- 跳躍／衝刺／蹲下**全部不做**；移動**刻意沒有狀態機**

### 待決（三條給 CD、三條給 TD，已登記索引）
- 🔴 **itch.io iframe pointer lock**（TD）——風險最高、成本最低，約 1 小時
- 🔴 **移動求解器是否純 C#**（TD／ADR）——**值 24 條 AC**
- 🔴 **視野角在 MVP 無擁有者**（CD）＋ #18 的 Alpha 時序矛盾

## 系統 #4-#19 仍 Not Started

GDD 一份都沒有：攜帶與交付、機台互動組、客人系統、波次導演、遊戲時鐘、窗外天色、
HUD、大廳 UI、結算畫面、音效、評分邏輯、進度解鎖、教學、設定無障礙、單人練習。

**這個分布是刻意的**：系統索引把「網路同步層」標為 high-risk 並註明「GDD 後直衝原型」，
理由是新引擎 ＋ WebGL 多人**沒有官方端到端範例**，這條不通則後面十八個系統全部白做。

而它確實抓到東西了——被推翻的假設裡有四條是**照原文實作會出事、且本地測試永遠看不出來**的：
權威模型寫反、斷線處置序列建立在假前提上、itch.io 解壓 Brotli 導致傳輸量兩倍、
Relay region 不選就直接違反 AC22。

## 下一步

1. **複審 `product-database.md`** —— 首審已於 2026-09-20 完成（NEEDS REVISION，
   30 blocking 全數處理完畢）。**複審必須在全新 session 跑**：首審已經違規在同場進行，
   creative-director 判定殘餘偏誤是「不利綜合的缺席」，不可再犯第二次
2. **開大夜班的正式 Unity 專案**，把網路層依 GDD **重寫**成生產程式碼
3. **繼續寫 GDD** —— 依系統索引設計順位，下一份是 **③第一人稱控制器**

### 2026-09-19：②商品資料庫 GDD 完成（514 行，12 節）

`design/gdd/product-database.md`。四位專家（creative-director／systems-designer／
unity-specialist／gameplay-programmer／qa-lead）逐節投入，arlong 逐節核准。

**關鍵裁決**：
- 範圍只收**互動層 SKU**（估 20-40 筆）；貨架背景排面是共享圖集貼圖，不進資料
- **需求分兩級**：家族級為主（`machine_family` 4 值）＋指名為輔（僅 `nameable == true`
  者，每個必須配專屬 icon＝內容配額的天然剎車）。此裁決源於一個硬矛盾：
  美術聖經 §3.3 的需求 icon 只有 4 個且綁「需求類別」，而嚴格 SKU 比對會讓玩家
  在尖峰看不出黑輪與米血的差別
- **兩層 ID**：`sku_id`(string, 永不改名) ＋ `network_index`(byte, 永不重用)
- **加工狀態機歸 #5**，DB 只定義 `ProductInstance { network_index, is_spoiled }`
- 數量用**重複槽位**表達，不做 qty 欄位；修飾語若有玩法效果就做成獨立原子 SKU
- `Matches()` 雙模式純函式＋槽位分配規則（**Named 優先於 Family**，理由：稀缺先鎖定）

**發現的既有文件問題**：美術聖經 §8.2 poly 表**沒有「手持商品」這一列**（400 vs 150
差 2.7 倍）；需求 icon **缺兩個**（Microwave、Shelf）；`RequestHandoff` 的 `itemId`
語義未標型別，可能與 SKU 混淆（OQ-P7，七條懸案裡唯一會造成返工的）。

**Registry 已登錄**：`product_matches` 公式 ＋ 4 常數（`machine_family_values`、
`sku_network_index_type`、`sku_display_label_max_chars`、`sku_count_target`）。
`items:` 仍空——具體 SKU 清單屬內容製作，尚未裁決。


### 2026-09-20：②商品資料庫首審 NEEDS REVISION，同日修訂完畢

`/design-review` 六位對抗式專家（全部零背景新 agent）＋ creative-director 終審。
**30 blocking／20 recommended，CD 合併為 6 個根因。** 詳見
`design/gdd/reviews/product-database-review-log.md`。

**CD 的一句話診斷**：「這份文件的架構是對的，但它的三個安全故事目前是虛構的。」

修訂後 514 → 768 行，AC 12→17 條，OQ 7→12 條。四項使用者裁決：
`display_label` 拆兩個常數（新增 `sku_holler_max_chars = 4`）／Player Fantasy 補家族級
錨點／`Matches()` 改回傳 `MatchResult` enum／「擋建置」明寫 `IPreprocessBuildWithReport`。

**最值得記住的三條發現**：
1. **enum 序列化重排**——Unity 存的是底層整數不是名稱，重排 `MachineFamily` 宣告會讓
   既有資產語意靜默錯位且**測試套件會一起漂移然後互相對上**。全套唯一「安靜、不可回復、
   會出貨」的失敗模式，修法兩行。
2. **`[P-17]` 擋不住純內容變更**——netcode GDD 全文未定義 token 產生規則，唯一證據是
   `payload=w1-proto-v1`（字面量、命名為 proto）。原文件把一道沒查證的閘當成已證成立的
   防線引用。已改為 OQ-P8，指派 technical-director。
3. **准入門檻稽核了錯誤的頻道**——四條門檻全是聽覺判準，但尖峰的高風險管道是玩家永遠
   不會聽到的 icon。已擴充為六條（新增層級標記、32×32 花色不撞）。

⚠ **程序教訓**：首審與撰寫同場進行（使用者知情裁決）。CD 判定「沒有偵測到壓制，
殘餘偏誤是**不利綜合的缺席**」——零背景專家保護的是**輸入**，不是**接合**。
下次同場評審應指派一位專家專職交叉引用他人發現，或要求彙整者以自己無從選擇的順序呈現。

## 待 arlong 裁決（皆不擋進度）

- **OQ#18**：MVP 是否啟用 host migration（MPS 2.3.1 顯示它是一等公民，故「無 migration」
  是**選擇**而非限制）
- **OQ#10**：行動瀏覽器的背景回收行為（桌面 Chrome 已實測為只節流到 1Hz）

## W1 假設表：**15/20 結案，其餘 5 項本來就屬 W2**（2026-09-18）

✅ **第 4 批已完成**：`[P-18]` sendBeacon（8/8 送達，含 iframe 父分頁關閉）、
JS 解壓 CPU（→ 壓縮改 gzip，build 硬標 44MB）、`[P-20](b)` ownership（→ OQ#17 消解）。

⚠ **但 W1 沒做完。盤點後仍有四項未測，全屬 NGO／WebSocket 傳輸層**——
第 1 批測的是 MPS session 層（Lobby，依 #23 尚無 NGO 連線），兩層語義不同，不能互相代答：
**`[P-8]`**（Relay 斷線傳播 ≤2s）、**`[P-13]`**（關分頁時 WebSocket close frame 是否可靠，
今天測的 sendBeacon 走 HTTP 是不同機制）、**`[P-14]`**（行程被強制終止 → 心跳路徑 ≤12s）、
**`[P-15]`**（`Shutdown()` 在 WebGL 是否即時 flush close frame）。
器材已齊：雙進程 harness 可共用於 P-8／P-14／P-15；P-13 需瀏覽器端。

另有五項本來就屬 W2（P-2／P-5／P-11／P-12／P-16）。
行動端缺口需真實裝置：OQ#10 ＋ `[P-18]` 的 visibilitychange 路徑。

---

## 詳細歷程（時序記錄，新的在後）

### 開案與 pre-production（2026-09-03 起）
/brainstorm COMPLETE (solo mode, all gates skipped). Concept doc:
`design/gdd/game-concept-night-shift.md`. Co-op FP party game: Taiwan convenience
store night shift, 2-4p online, browser, Overcooked-like with star rating.
KEY USER DECISIONS: fellowship-first (co-op requested); FP required; timeline
relaxed ("慢慢做但要做好"); scenario chosen over 躲鬼(horror uncertain) and 亂流(空服);
**ENGINE = UNITY (user's explicit choice over recommended Godot)** — CLAUDE.md still
pins Godot, /setup-engine must run. Networking plan: Unity NGO + Relay/Lobby
(WebGL = WebSocket). FIRST PROTOTYPE = netcode chain validation (biggest risk:
new engine + WebGL multiplayer).
/setup-engine DONE (2026-09-03): Unity 6.3 LTS pinned (6000.3, LTS until 2027-12).
CLAUDE.md + technical-preferences.md switched to Unity/C# (Godot snapshot kept at
technical-preferences-godot.md; legacy games note added to CLAUDE.md). Engine reference
docs researched via 2 web-research subagents and written: docs/engine-reference/unity/
{VERSION, breaking-changes, deprecated-apis, current-best-practices, modules/{web,
multiplayer}}.md. HIGH RISK version (6.1-6.3 post-cutoff).
/art-bible DONE (2026-09-03): design/art/art-bible-night-shift.md sections 1-4+8
(5/6/7/9 deferred until prototype). All drafted by art-director/technical-artist
subagents, user approved each. KEY RULES: 慘白預設/彩色是特權 (interact yellow #FFD23F
+ alert red #E0392B are the ONLY 2 privileged hues, quota rule: density scales, hue
count never); 店內恆白不准變暗, all mood via window sky (窗外=隱形時鐘: darkest sky
01-04h = peak intensity; dawn = release); shape=identity (customer archetypes = 主導
幾何+掛載物 silhouette formulas); oden pot = hero (only cylinder + highest saturation
+ steam). Brand: 好鄰居超商 #2B2B54+#E8873B. HARD LIMITS: Simple Lit only (3-shader
rule, URP Lit forbidden), chars ≤800 tris, scene ≤120K, ≤150 draw calls target, baked
interior + 1 realtime directional for window sky, no skeletal anim (all tween), BGM
must stream. Conflicts resolved+logged in §8.9.
/map-systems DONE (2026-09-04): design/gdd/systems-index.md (Night Shift版; 舊夜市索引
git mv → systems-index-night-market.md). 19 systems, MVP=14項, design order: ①網路同步
層+Session ②商品資料庫 ③FP控制器 ④機台互動組 ⑤客人系統 ⑥評分邏輯 ⑦波次導演+時鐘
⑧攜帶交付 ⑨HUD ⑩結算… High-risk: 網路同步層(GDD後直衝原型). Next: /design-system
網路同步層+Session.

/design-system netcode-session DONE (2026-09-04): design/gdd/netcode-session.md 279行
全 11 章完成 (user approved every section). KEY DECISIONS: host-authoritative + owner
移動 + request→validate→broadcast; 搶奪=Host先到先得+撲空動畫(不回滾); NPC=里程碑事件
同步不逐幀+本地插值; 移動10Hz; reconnect 30s (NP的20-30勝過SD的90); late-join 3-5s過場;
房間碼=Sessions API原生(SD自訂碼公式作廢); Host關分頁=局終(no migration, UI明示);
Host分頁節流=最大風險(>500ms→時鐘2s追趕); 進房≤35s(硬標60); 連線狀態全用店語(去後場
拿貨/店長把鐵門拉下來了). 18條AC(qa-lead驗證+6條補強)+測試基建註記. Registry +5常數
(reconnect_window_sec=30, max_players=4, join_time_budget_sec=60, interact_rtt_p95_ms
=300, player_count_sampling=wave_boundary). Systems index #1#2→Designed.
/design-review netcode-session DONE (2026-09-05): 5 adversarial specialists + CD synthesis
→ NEEDS REVISION (14 blocking). ALL 14 FIXED same session. 關鍵修訂: (1) Provisional
Assumptions 表 P-1~P-6 含 fallback 欄 (未驗證引擎行為不再與定案規則混寫); (2) 留守者
保護 Core Rules #14-16 — 離線立即降載+15s寬限期(不生新客/耐心×1.5/「老闆出來擋一下」),
補上支柱5對留守者的保護; (3) 背景節流改 visibilitychange, ≤5s catch-up / >5s 視同斷線
(frame delta 在分頁全停時量不到); (4) MVP 分層 (CD裁決): 斷線基本保障=MVP、30s原位恢復
=Post-MVP, 已同步回寫 game-concept; (5) 更衣室過場定案(不推給UX); (6) 清除 HP 模板殘留;
(7) 新增 ServiceError 狀態(UGS失敗); (8) AC 18→26條+層級欄+測試基準環境數值; (9) 單一
場景不啟用 NetworkSceneManager. Registry 12 常數(+grace_window/claim_lock/late_join
_cutoff/background_disconnect). Review log: design/gdd/reviews/netcode-session-review-log.md
/design-review netcode-session 複審 DONE (2026-09-05, 新 session): 6 specialists (gd/sd/np/
unity/qa/ux) + CD → NEEDS REVISION (7 blocking, 皆局部補洞; systems-designer 獨判 MAJOR,
CD 裁 NEEDS). ALL 7 FIXED same session (r2), user 決策: 心跳 2s/8s app-level; MVP 離線名額
立即釋放; 全部 Host 動態 spawn 禁 scene-placed. 修訂內容: Core Rule #20 心跳; #18 改 client
端偵測 Host 消失; 公式③ rate=1+drift/2 (上界 3.5x); 狀態真相 NetworkVariable; 公式⑤ 冷啟動
讀取條標「未解」→ OQ#8 (web-platform ADR + /ux-design); AC8 MVP=2人/VS=4人; States
Disconnected 拆 MVP/Post; Onboarding 斷線; 寬限期不疊加; P-5 改測跨 channel; 新增 P-7 (.jslib)
P-8 (Relay 傳播) P-9 (內建逾時≥8s); AC 26→33. Registry +2 (heartbeat_interval_sec=2,
heartbeat_timeout_sec=8). Index #1#2 → In Review (r2). CD 列「順手可做不擋審」未動:
Rule #3 空窗搬回/Rule #9 寫 ≤30s/Host 於 Settlement 關分頁/AC23 跨文件引用/AC20 容忍窗.
/design-review netcode-session 第三輪 DONE (2026-09-06, 新 session): 6 specialists (gd/sd/np/
unity/qa/ux) + CD → NEEDS REVISION (24 blocking 含 3 結構前置, 21 recommended; sd+ux 判 MAJOR,
CD 裁 NEEDS). r2 7/7 確認已修、公式③數學全員複核 OK; 本輪全為新發現. 支柱級三洞: (1) #17/#18/
#20 未限 InShift → Host 在 Lobby 切分頁貼連結會殺自己的房; (2) client 分不清 Host 消失 vs 自己
斷線; (3) 退出→立刻重連可無限刷寬限期. CD 診斷: 三輪 blocking 只有四類 (範圍未限/常數未定/
層級未掃/未驗證前提), 清單式修訂只修被點名實例 → 改掃描式, 先建三張結構表.
ALL 24 FIXED same session (r3). user 決策 4 項: 鐵律改分域＋客製 Web Template 列 MVP; Host 獨留
續戰＋提前收班; Lobby 延後建連 (a) 為預設; settlement_timeout 20s. 修訂內容: 適用性矩陣 23×9/
常數三欄表/旋鈕約束 7 條; #17/#18/#20 限 InShift; 新 #21 Host 獨留, #22 結算逾時, #23 Lobby
延後建連 [P-10]＋複製連結鈕; #18 三訊號排歧表＋誠實預設文案; client 主動 teardown; 心跳
Unreliable [P-11]; 班次時鐘=wall-clock 真相、模擬不快轉、catch-up 暫緩 resync; #15 寬限期 rejoin
即結束; #6 交接完成=Host 提交; ClaimGeneration 入 NetworkVariable struct; UI 翻譯表加層級欄
＋MVP 文案改真; #10 更衣室 runtime 準時進場; 預算 25/10/10=45s＋AC7a; AC6a/6b [P-13/14];
P-7 加 [Preserve]; #8 輸碼大小寫不敏感; #12 beforeunload; AC 33→45 (新 34-43); P 9→14;
OQ#9-11. Registry +patience_mult/+settlement_timeout_sec, bg_threshold/max_players/
join_budget 註記更新. Index #1#2 → In Review (r3). Review log r3 條目已附.
未動 recommended (待批): AC9 拆重試/放棄; 碼失效 AC; #16/#17 AC; 寬限結束退場訊息;
測試專用 UGS 專案; 寬限期音效.
/design-review netcode-session 第四輪 DONE (2026-09-13, 新 session): 5 專家 (gd/np/sd/qa/ux)
+ 4 位獨立對抗驗證者 + CD → NEEDS REVISION (17 組). unity-specialist 三度因 API 用量上限中斷,
主審依 docs/engine-reference/unity/ 自行補交叉檢查 (scratchpad/r4-unity-crosscheck.md).
**另跑 2 張機械檢查**, 抓到的比六位專家加起來還多: AC 時間算術 37 條含時限 AC 中 **16 條不閉合**
(專家只找到 4 條) + 5 條無法驗算; 常數雙向對照 16 個常數中 **7 個假引用**、19 項應登錄未登錄、
**約束區塊 7 條全部與 Tuning Knobs 安全範圍矛盾**.
最嚴重 B4: #18 排歧表訊號三被誤述為「雲端側對 Host member 的觀察」(引擎文件只說「連線狀態」),
且其 fallback「退化為兩訊號」會讓「Host 消失」分支**永遠不可達**, 殺掉 AC6b (自標必達) 與 AC28
——全輪唯一 **fallback 自己不成立** 的假設.
**CD 流程裁定 (比 verdict 更重要): r4 是最後一輪散文式評審, 不再開 r5.** 理由: 四輪的 blocking
都長在上一輪修補的縫隙裡, 且約四成確認項是對一個沒人跑過的系統的斷言.

ALL FIXED same session (r4). 698 行 → **1224 行**; registry 常數 13 → **34**.
user 決策 3 項: (1) Settlement 期間加入者的支柱 5 出口＝**開放單人練習沙盒**;
(2) 留守者保護防濫用＝**同一玩家同班次第 2 次起仍降載但不給寬限期** (#15a);
(3) 現在就修.
修訂內容: 新增 8 條 Core Rule (#15a/#17a/#23a/#23b/#24 斷線處置原子序列/#24a MPS 成員唯一寫入者/
#25 Lobby Host 離開偵測/#26 開始上班轉場/#27 冷啟動 stall); #18 排歧表改雙路徑 (MPS 事件推播 +
roster 輪詢) 使「Host 消失」分支在 fallback 下仍可達; #20 刪除 Unreliable/HOL 錯誤立論 (HOL 在
TCP 層、在 pipeline 之下), 心跳範圍改「NGO 連線存在期間」, payload 一包三用並刪 60s resync;
#9 截止閘門移至 ConnectionApprovalCallback + 版本閘; 班次時鐘真相改 **Host 權威 shift_end_ts**
+ offset 掛心跳 + shift_length_sec 登錄; #23 降級為高風險架構假設 + 補完整替代設計;
States 新增 Booting/LoadFailed/Lobby*(前一班進行中), 刪孤兒名詞「Lobby 倒數」;
矩陣擴為 30 列 x 11 欄; **Tuning Knobs 安全範圍改為公式而非固定區間**; 約束 7 → **11 條**;
AC 46 → **57 條** (16 條不閉合全修 + 5 條拆分 + 新增 AC44-54) + 5 條 AC 撰寫規則;
[P] 14 → **20 條全部補「影響」欄** (META-I1) + 新增 P-15~P-20; OQ 新增 #12-#16.
約束驗算實跑: 11 條中 9 PASS / 2 待原型 / 1 條 (⑧ tick×RTT) 在 P-3 為全域 tick 時 FAIL
——**設計意圖如此**, 讓問題在回填當下自己跳出來.

**原型 W1 優先序 (r4 重排)**: **P-10 (升第一, 一次回答四項 blocking)** → P-4/P-6/P-19 (同一次
itch.io 部署) → P-7 → **P-3 + OQ#1 (必須與 AC22 聯測)** → P-13/P-14/P-15 → P-9/P-16 →
P-17/P-18/P-20. **P-11 移出 W1** (它問的是基於錯誤前提的問題).
P-4 讓位理由: 它的 fallback 是全表最健康的一條 (不轉發 → 輸碼成為唯一入口, AC2 已保底).
**W1 成功判準**: 原型報告必須回填 [P] 表的「影響」欄, 每條被推翻的假設要明講殺掉哪幾條 AC.

三張機械檢查 DONE (2026-09-13): 抓到的比六位專家加起來還多, 也抓到修訂本身的殘留與新洞.
AC 時間算術 50 條含時限: 閉合 32/不閉合 10/無法驗算 8, 其中 **6 條同源於單點缺陷**
(`t_disconnect` 在公式①是「Host 判定時刻」、在測試基建是「socket.close() 時刻」, 差 2s).
常數雙向: 三欄表 16 項「待補登」全為誤標 + 1 項假 Y + 4 處正文殘留.
[P]→影響 (首次執行): **20 條中 17 條影響欄不完整**; 7 條 fallback 會殺 MVP AC (5 條未標).
**最關鍵: B4 未修好只推遲一層** —— 排歧表兩條路徑共用 MPS session 層載體, 同層不可用時
序 1/3/4/5 一起死. 修法＝補「roster 查詢是 Lobby 設計既有前提」的載體論證.
**判準主詞未定義** —— 已新增 **MVP-必達** 層級 (AC6b/AC53/AC54/AC7).
ALL FIXED (r4 二次修訂): 1224 → **1291 行**; registry 34 → **40 常數**; 約束 11 → **14 條**
(⑧改條件式, 新增⑫⑬⑭); AC 修 11 條 + 新增 AC45a/AC55; P-2/P-20 拆半; P-6/7/9/17/18 標
fallback 不可行; 優先序新增**第 0 批 (零成本文件查詢)**, **P-17 從最後移到第 1 批**.
修訂協定新增兩條: (A) 影響欄須**反向掃描機械產生**不得手填; (B) fallback 寫「可行」前**須代入數字驗算**.
約束驗算實跑: 14 條 **PASS 10 / FAIL 0 / 待原型或非數值 4**.

W1 第 0 批 DONE (2026-09-13, 純文件查詢零成本): 三條假設查證完畢, 全部對照 NGO 2.13.2
**實際原始碼** + 官方文件, 附 URL 與原文.

**三個改變設計的發現**:
1. **AC22 的「不可達」解除 —— 約束⑧的前提是錯的**. `RPC 完全不受 network tick 影響`
   (每『幀』於 PostLateUpdate 批次送出, 非 tick-gated); 受 tick 影響的是 NetworkVariable
   與 NetworkTransform. 新預算 ~235-250ms <= 300ms, 餘裕 50-65ms. 約束⑧已重寫 + 追加硬規則:
   **互動結果一律走 RPC, 不得用 NetworkVariable 承載** (後者 10Hz 下單邊 +100ms 即超標).
2. **GDD 的權威模型寫錯了**. #2 原文「Owner 權威(NGO NetworkTransform 預設, 不改寫)」——
   client-server 下 AuthorityMode **預設是 Server**, 只有 DA 才強制 owner.
   **不是「不改寫」而是「必須改寫」**. 引擎參考 modules/multiplayer.md 同句錯誤也已更正.
3. **#24 斷線序列第 2 步隱含為假的假設**. DontDestroyWithOwner **預設 false = 預設銷毀**,
   且銷毀在 OnClientDisconnectCallback **之前**同一 call stack → 第 2 步「掉落」時物件已不存在.
   已補前置條件 (prefab 須先勾選). ⚠ RemoveOwnership() **不做 unparent**,「掉落在原地」須自行實作.

**一個讓 #23 升格的發現**: Relay 對每個 client 連線 TTL = **10 秒** (無 allocation idle timeout
這種東西), 靠 NGO 自動 PING 重置. **瀏覽器節流背景分頁 → PING 停送 → 背景 10s 即被踢**.
若 Lobby 已建 Relay 連線, AC34a(30s)/AC34b(120s) **必然失敗**, 且失敗在 Relay 層(比 MPS 服務層更早).
→ **P-10(b)「能否拆分 Relay」不是效能優化, 是整條 Lobby 設計成立與否的問題**. 新增 #23c.

其他寫進文件的引擎事實: DisconnectTimeoutMS 預設 30s >> 8s (約束⑤成立, 欄位名無更名);
HeartbeatTimeoutMS **雙重用途不得調動**; ClientConnectionBufferTimeout=10s 影響 #9 閘門;
ChangeOwnership 回傳 void **失敗靜默** → #6a 須回讀 OwnerClientId; 兩次 ownership 變更需隔
**6 tick** → 新常數, **10Hz 下即 600ms** 對快節奏交接可感知 → 新增 OQ#17 (是否把 tick 提到 20-30Hz);
OwnershipStatus 那套**只在 DA 有效**; DontDestroyWithOwner 在 2.4.0 前是壞的(2.13.2 已修);
docs-multiplayer.unity3d.com **已全數 301 轉址**.

新增 AC56(MVP-必達, 斷線後道具須存活+已 unparent, **唯一能在 CI 擋住手持物蒸發的測試**,
本地 host 模式測不出來) 與 AC57(交接冷卻).

檔案: GDD 1303 → **1364 行**; registry 40 → **42 常數**; modules/multiplayer.md 76 → **171 行**.
回填後驗算: ④分情境成立 / ⑤ PASS(8s<=30s) / ⑧ PASS(250ms<=300ms, 餘裕 50ms).

W1 第 1 批 DONE (2026-09-13): 建原型專案 prototypes/w1-netcode (Unity 6000.3.24f1 + NGO 2.13.2
+ MPS 2.3.1 + UTP **2.7.4**). EditMode 12/12 + PlayMode 5/5 通過.
**大廳延後建連可行且優於預期**(不帶 network 的 session 連 NGO 單例都不需要; StartRelayNetworkAsync
可延後; StopNetworkAsync 讓 #23a 有 API). **B4 徹底解決**(ISession 直接有 Host/HasPlayer).
**RemovePlayerAsync 存在** → r4 唯一無退路的查證項解除. 房間碼 6 碼全大寫、字集無母音無易混淆字元
→ **刪掉一條設計規則**. 身分 = AuthenticationService.PlayerId, 跨 session 延續.
🔴 **Host kill -9 後大廳其他人要 132.61s 才知道; 優雅離開只要 1.14s (差 116 倍)**
→ #12 beforeunload 升格為關鍵機制; 慢路徑經 arlong 裁決採「本地逾時提示」(新常數
lobby_host_silence_timeout_sec=30). 意外: **host migration 是 MPS 一等公民** → OQ#18 待裁決.

W1 第 2 批 DONE (2026-09-14): Release Web build (IL2CPP/Stripping High/Brotli) + 部署到
arlong666.itch.io/w1-netcode-probe-internal-test (草稿).
**.jslib 雙向在 Stripping High 下全通過** → [Preserve] 有效.
🔴 **帶碼連結不會穿過 iframe**: location.search 被換成 itch.io 的 ?v=, 父視窗跨域
→ **document.referrer 是唯一路徑**, 且可被隱私設定削減 → 輸碼備援不可砍.
🔴 **itch.io 不支援 Brotli 且會解壓 .br 再重送** → 傳輸 **2.00 倍**(資料檔 4.32 倍).
**遊戲照樣能跑, 壞消息全在傳輸量裡.** 解法已驗證: decompressionFallback=true (產出 .unityweb)
→ 回到 **0.99 倍**. **這是強制建置規範**, 已寫進 engine ref.
🔴 **iframe allow 無 clipboard-write** → 複製連結必須降級為可全選文字框.
⚠ **這三項在本地全是綠的** —— 「必須真的部署」本身就是結論.
另: **Unity 預設字型無 CJK**, 網頁上中文完全不渲染 → 必須打包字型, 子集化列為 MVP 建置步驟
(壓在已歸零的 T_load 餘裕上). Build size 地板 7.0MB (netcode+IL2CPP), 留給內容約 43MB.


W1 第 3 批 DONE (2026-09-14): 把問題從「session 多久被回收」改問「背景分頁時主迴圈是停止
還是節流」—— 後者是立刻可讀的數字, 且回答的是更上游的問題。macOS 桌面 Chrome 實測六分半鐘:
**穩定節流到 1 Hz, 未觸發 Page Freezing**。MPS heartbeat(10s) 照常送、Relay PING 節流後約 1s
一次仍遠低於 10s TTL → **[P-10](a) 假設為假, 背景分頁不會讓 session 被回收**。
**#23b/#23c 的擔憂皆不成立; #23 從「必需」回到「好設計」**; AC34a/AC34b 應可通過;
lobby_bg_safety_factor 失去用途。
⚠ 邊界: 桌面 Chrome、分頁背景化、六分半鐘。**行動瀏覽器不在此列** → OQ#10 仍有效。
⚠ 1Hz 意味背景期間 deltaTime 約 1 秒 → **任何以每幀累加的模擬在背景都會行為異常**,
實作時要確認模擬確實凍結而非以 1 秒步長繼續跑。

W1 第 4 批 (RTT/tick/region) DONE (2026-09-15): 雙進程經真實 Relay WSS, 每組 20 樣本。
跑法 `prototypes/w1-rtt-run.sh [tick] [region]`, tick 與 region 由命令列帶入,
**對照組與實驗組跑完全同一份程式碼**。

**(1) tick 的問題釘死了**: tick=10Hz → p95 335.8ms; **tick=1Hz → p95 333.0ms**。
tick 改十倍、往返一毫秒未動。選 1Hz 當對照是刻意的——若 RPC 真按 tick 閘門批次送出,
每筆最長等 1 秒, p95 必落在秒級。**「RPC 非 tick-gated」由原始碼推論升格為實測事實,
約束⑧ 原前提作廢, AC22 不再受 tick 威脅。**

**(2) 但真正的威脅在 region, 這是意外撿到的**: 上述兩組都是**預設 region**, 而
interact_rtt_p95_ms 上限是 300ms → **p95 335.8ms, 遊戲邏輯一行都還沒跑就已超標**。
只改 region 為 asia-northeast1: **p95 94.5ms**。3.7 倍。
補測 europe-west4 (p95 437.8ms) 把模型釘死: 兩進程都在台灣故 RTT = 4 × d(台灣,R),
三點反推單程 (東京 22.2 / 美中 82.8 / 荷蘭 108.6 ms) 皆合理 → **模型可推未量測組合**。
**沒有自動解**: Relay 的 QoS 在 Web 上拋 PlatformNotSupportedException (不支援 WebGL),
而本作 Web-only。

**(3) arlong 裁決 OQ#20「讓國外的人也可以參與」(2026-09-15)** → 不能寫死任一大區。
解法不是折衷而是可證明的: RTT_i = 2 × (d(i,R) + d(R,H)), 由三角不等式,
**R = H 讓每個 client 同時拿到各自的理論下限**; 移向任一 client 只會讓其他人變差。
⚠ 修正一個先前的錯誤前提: **Host 不付這筆延遲**(它是權威, 自身互動本地結算),
最佳化目標是所有 *client* 的延遲, Host 不計入。
→ **Core Rule #28: relay 貼著 Host 選**, 由時區查表決定、可覆寫。
時區須用 .jslib 讀 Intl.DateTimeFormat().resolvedOptions().timeZone,
**不可用 .NET TimeZoneInfo** (Unity Web 時區資料庫不完整)。
registry 新增兩張對照表: relay_region_by_timezone / relay_region_offset_fallback。
**推論: 誰當房主決定了房裡所有人的延遲** —— 多數人在歐洲卻由台灣的人開房, 全體被綁在
2 × d(自己,台灣); 換歐洲的人開房即消失。這是 Lobby UI 該告知的資訊, 也給了 OQ#18 實際用途。
**殘留代價如實記錄**: 歐洲玩家在台灣 Host 房中裸往返由已測值夾擠得 **217-306ms** ——
能玩但正好壓在 300ms 邊緣。故 **AC22 拆三條**: AC22 同區必達 300ms(實測 94.5ms, 餘裕 205ms)/
AC22a 跨區**降級契約**(不設時間上限, 但須正確、有回饋、不卡死、不得給會被推翻的樂觀結果)/
AC22b 自動選區＋可覆寫(**留空即為缺陷**)。
⚠ 217-306ms 是**夾擠推得非直接量測**, 待有海外測試者時補量。

**(4) 過程中撞出兩個協定陷阱**(都是測試連續失敗兩次逼出來的, 非查文件得知):
(a) Relay 協定**只能在建 session 當下**經 SessionOptions.WithNetworkOptions() 指定
—— RelayNetworkOptions(RelayProtocol) 已 Obsolete, 而延後建連用的 StartRelayNetworkAsync
沒有 protocol 參數。**好消息是 WithNetworkOptions 只設定不啟動** → #23 延後建連與指定 WSS
可並存 (實測 CreateSessionAsync 後 NetworkState 仍為 Stopped)。
(b) **協定不會從 Host 傳染給加入者** —— Host 設好 WSS 且 IsListening=True 後,
加入端只傳房間碼照樣拋 Mismatched Relay configuration and network interface;
JoinSessionOptions 必須自己再宣告一次。→ **協定設定必須集中成共用 helper**,
漏掉任一條加入路徑會**只在該路徑失敗而 Host 端一切正常** —— 與第 2 批 itch.io 那三項
「本地全綠」同類的不對稱失敗。
另: EnableSceneManagement 兩端必須一致, 否則 NGO 握手階段就拒絕連線。

⚠ 順帶修正一句先前寫太絕對的話: region 的固定範圍是**一個班次**不是整局 ——
它傳給 StartRelayNetworkAsync, 而依 #23 那是「開始上班」才呼叫、依 #23a 局間會拆掉。
理論上每班次可重選 (若日後啟用 host migration, region 得以跟著新 Host 走),
但**此為 API 形狀推論, 未實測**。

⚠ 檢查 GDD 表格時發現**三列格式本來就壞**(AC45 內文含 |、P-6 與 P-10 兩列跨行),
git diff 確認非本次動到, 未修, 待 arlong 決定。

---

# 歷史紀錄（已完成／暫停的專案）

## 橫衝直撞 (Road Rage) — **已完成／暫停**，standalone `road-rage/`, Godot 4.6

> 歷史紀錄。以下內容保留供參考，**非目前工作項目**。

Boot scene = `scenes/fp_main.tscn` (`fp_main.gd`). A third-person 3D GTA-like sandbox
built entirely from primitive meshes (no art assets). The 2D top-down build
(`scenes/main.tscn`) still exists but is not the boot scene.

Spec/plan: `docs/superpowers/specs/2026-06-27-road-rage-design.md`, `docs/superpowers/plans/2026-06-27-road-rage.md`.

### CRITICAL: renderer
`rendering_method = forward_plus` (NOT gl_compatibility). The window-closing crash
the user hit was GL-compat on Apple M3 (OpenGL-over-Metal) choking on load — headless
never caught it because it is GPU-side. Forward+ = native Metal = stable. Consequence:
no HTML5/web export in this mode; a GL-compat-lite variant would be needed for web.

### Features implemented (all verified: scan/boot/23 unit tests + headless checks)
- Driving: third-person chase cam, big detailed car, nitro (Shift), handbrake (Space),
  reverse with inverted steering, grip handling, FOV-with-speed, MAX_SPEED 33.
- On foot: FPWalker — E to enter/exit car, WASD move + aim relative to a rotatable
  camera (, / .), J or left-click auto-fire hitscan (tracers + sparks + recoil),
  Space jump, Shift sprint. Carjack ANY nearby car (own or traffic) with E.
- Destruction: props/cars/peds knocked away as physics bodies; buildings collapse when
  rammed fast; explosive barrels (40) with chain reactions; hit-stop on big smashes.
- Cops: cruisers (ram damage) + foot cops (chase + shoot) scale with a wanted-heat
  star system; police destroyable by gun/ram; helicopter at 5 stars (searchlight,
  shoots, leaves when heat drops).
- Player health: 體力 bar, damage from cops/heli/explosions, regen when safe, respawn
  at spawn (brings the car — never lost). Health packs (16) heal.
- World: procedural city (grid 30, TILE3D 14), designed buildings w/ windows/roofs,
  pedestrians + drifting traffic (car-shaped), street trees, neon signs, curbs,
  crosswalks, 5 tall landmark towers, day/dusk/night toggle (T), cone test-track.
- Look/feel: procedural sky + SSAO + SSR + bloom + fog + shadows; screen flash on
  explosions; combo callouts (失控!/瘋狂!/大屠殺!); minimap (player/police/heli/pickups).
- JUICE (2026-07-24): trauma camera shake (car + walker, quadratic decay, offset+fov
  punch+roll) routed through fp_main._add_shake() for every impact; bigger hit-stop on
  building/blast; explosions add a ground-plane shockwave ring (TorusMesh, NO rotation —
  it's already flat) + tumbling debris chunks on top of the fireball.
- CROWD + FEEDBACK (2026-07-25): FPPed flee state (panic) — bolt from a fast car nearby
  (passive) or from gunfire/blast/kill via fp_main.alarm_peds() broadcast (group
  "pedestrian"). Directional damage indicator: _damage(amt, source_pos) — all 4 call
  sites pass source; FPDamageIndicator (scripts/fp_damage_indicator.gd) draws a red arc
  at screen centre pointing at the hit, angle from the ACTIVE camera forward (works in
  car + foot). Feature check now asserts ped_panic + dmg_indicator.
- PANIC POLISH + FIRE MODE (2026-07-26): panicked peds throw arms overhead + flail
  (sin wave) and zig-zag flee (re-roll heading every ~0.25-0.5s, +/-57deg jitter).
  Gun fire mode: FPWalker._auto_fire toggled with F — 連發 hold-to-spray / 單發 tap.
  "fire" input action now includes MOUSE_BUTTON_LEFT (walker fire loop covers mouse+J;
  fp_main's old left-click handler removed to avoid double-fire). HUD shows 連發/單發 [F]
  on foot. Feature check asserts fire_mode_toggle.
- GUN + SCREAM JUICE (2026-07-28): FPWalker recoil spread (_spread bloom grows while
  spraying up to ~3.4deg, decays at rest) + brass shell ejection per shot (tumbling
  arc, freed 0.7s). RRAudio.scream() procedural yelp with per-ped pitch; FPPed cries
  out ~30% only on the calm->panic transition (no spam).
- MULTI-WEAPON (2026-07-28): data-driven _weapons table in FPWalker — 手槍/衝鋒槍/散彈槍,
  switch with keys 1/2/3. Per-weapon pellets/rate/spread/bloom_max/range/pitch + viewmodel
  len/thick/col (reshaped in _apply_weapon_visual). Firing loops pellets via _fire_ray()
  (shotgun = 8-pellet cone). RRAudio.gunshot(pitch). HUD firemode label now shows weapon
  name. Feature check asserts weapons[switch]. Damage still via shoot_hit() (1 hit/pellet)
  — no per-damage refactor; differentiation comes from pellets * fire rate.
- ROCKET LAUNCHER (2026-07-30): 4th weapon 火箭筒 (key 4). Weapon entry has "rocket": true;
  _do_fire branches to _fire_rocket() which spawns FPRocket (scripts/fp_rocket.gd) — a
  Node3D flying 48u/s with smoke trail, raycasting ahead; on impact/95u it spawns an
  FPExplosive + connects exploded->game._on_explosion + explode(), reusing the whole
  blast path. Feature check asserts rocket[ok].
- CROSSHAIR + PICKUPS + DRIVE-BY (2026-08-04):
  * Dynamic crosshair: 4 arms in _ch_arms, gap = 4 + FPWalker.current_spread()*520 each
    frame (tight pistol, wide shotgun, blooms with SMG spray, 0 for rocket).
  * Weapon pickups: ownership on FPMain._weapons_owned [pistol,SMG owned; shotgun,rocket
    locked]; set_owned(arr,start) on _exit_car, _cur_weapon saved in _board_car.
    FPWeaponPickup (scripts/fp_weapon_pickup.gd) crates unlock+equip on walk-over.
    _spawn_weapon_pickups() = 2 shotgun + 2 rocket near spawn. grant_weapon() unlocks.
  * Drive-by: fp_car mounted gun — _car_fire() hitscan from the nose while active+fire
    held (GUN_RATE 0.11), tracer/spark/muzzle + alarm_peds. Feature check car_gun.
  Feature check now 12 items: ...weapons[lock+grant], rocket[ok], weapon_pickups=4, car_gun.
- MISSIONS + VARIETY (2026-08-04): timed objectives, random type each round, escalating.
  4 types (const MTYPE_*): DEMOLISH/RAMPAGE/EXPLODE/COMBO. _mission_event(type) routed
  from _on_building_collapsed/_on_smashed/_on_explosion; COMBO tracks _combo.multiplier()
  live in _update_mission. Top-centre banner (_ui_mission); big _ui_callout on start
  (blue) / success (green +bonus) / fail (red) — _maybe_callout resets modulate to white.
  Reward: score target*150+num*50, heal 30, flash, RRAudio.fanfare(); fail RRAudio.buzz().
  Cooldown banner shows '已完成 N'. Feature check #13 mission[start,done,rampage]. 13 items.
- GANG + TUNING (2026-08-05): FPGang (scripts/fp_gang.gd) — dark-hoodie + red-bandana
  hostile enemies, roam then hunt+shoot within AGGRO_RANGE 48 (game._damage -> dir arc),
  hp 3, group "gang"+"blastable", killable. _manage_gangs() keeps 5 (respawn at dist 70),
  seeded in _ready + on police timer. Minimap orange blips. Tuning: explode mission
  target mini(2+n/2,5)/42s + barrels 40->60; knockback UP halved (fp_ped/fp_target);
  weapon pickups 4->2. Feature check #14 gang[spawn hurt kill_scores]. 14 items.
- GANG REVIEW FIXES (2026-08-05, adversarial review workflow): 5 gangs -> 3, SHOOT_INTERVAL
  1.3->1.8, SHOT_DMG 6->5 (five always-hostile gangs out-DPS'd regen = ~4s softlock).
  FPGang now emits smashed(60,6,pos) on death (connected in _manage_gangs) so kills score +
  count for rampage. FPGang preloaded to match convention. (Review's 'missing preload crash'
  was a false positive — class_name = global; verified working.)
- ROADMAP (user wants 1->2->3->4 + 手機版本): #1 title+music DONE, #2 mobile (touch+web/GL)
  NEXT, #3 more content, #4 gang territory. Tasks #8-11 track these.
- TITLE + MUSIC (2026-08-06, step 1/4): _build_title() CanvasLayer(layer 10) title overlay
  over live city; _input() starts on first key/mouse/TOUCH (Web-audio gesture); _start_game
  hides title + plays music; missions + enemy spawns gated on _started. RRAudio.make_music_stream
  (4s loop bass+kick), AudioStreamPlayer -16dB, M toggles (_toggle_music). Feature check #15
  title[music]. 15 items. NOTE: music unauditioned headlessly — user judges sound.
- MOBILE GROUNDWORK (2026-08-06, step 2/4): renderer override project.godot
  renderer/rendering_method.web + .mobile = gl_compatibility (desktop stays forward_plus;
  web=WebGL2 != desktop ANGLE that crashed on M3). export_presets.cfg (Web, nothreads,
  excludes addons/gut+tests). Web export works (pck 3.6MB, wasm 37MB). FPTouch
  (scripts/fp_touch.gd): left joystick->move actions, right drag->touch_look, buttons
  射擊/上下車/氮氣/跳-煞/換槍; shown on _is_touch()/web/_force_touch. fp_main.touch_look/
  cycle_weapon. _lite (=touch/web) drops SSR/SSAO/glow + shadow dist + thins entities.
  Feature check #16 touch[built,look,cycle]. 16 items. build/ gitignored.
  PENDING: runtime browser test (Chrome remote-debug was blocked here) — user opens
  http://localhost:8777 (desktop) or http://192.168.68.54:8777 (phone, same WiFi);
  python3 -m http.server 8777 runs from road-rage/build/web. Confirms WebGL2 renders.
  >>> USER CONFIRMED 2026-08-08: web build RUNS in the browser. Mobile path is viable.
- RAMPS (2026-08-08, step 3 more-content): FPRamp (scripts/fp_ramp.gd) visual tilted slab
  (NO blocking collision — CharacterBody can't climb) + ground launch Area over footprint;
  fast car -> FPCar.launch(speed*0.7+8, cap 26), applied after on-floor zeroing. 4 ramps
  (_spawn_ramps). Air-time stunt bonus in _process (car): land after >0.6s -> int(air*260)
  + '空中特技!' callout. Feature check #17 ramps[count=4 launch=true]. 17 items.
  step 3 remaining options: weather, more vehicle types. step 4 = gang territory.
- WEATHER (2026-08-09, step 3 #2): V cycles clear/rain. _cycle_weather/_apply_weather/
  _start_rain/_stop_rain in fp_main. Rain = player-following CPUParticles3D downpour
  (800/300 lite) + sun 1.35->0.7 + fog 0.0016->0.007 grey. _process repositions rain
  above player. Feature check #18 weather[rain,clear]. 18 items. Roadmap step 3 DONE
  (ramps+weather; more vehicle types optional). NEXT = step 4 gang territory.
- GANG TERRITORY (2026-08-10, step 4): _spawn_turf() 2 turf zones (紅蛇幫/黑爪幫) = emissive
  ground disc + floating name; _update_turf() flags _in_turf + red HUD '危險：幫派地盤';
  _manage_gangs swells 3->6 + spawns closer (40u) in turf. Feature check #19 turf[swarm6].
  19 items. >>> ROADMAP 1-2-3-4 ALL COMPLETE.
- QA PASS (2026-08-10): full adversarial review workflow (5 lenses x verify, 16 raised /
  7 confirmed). Fixed: touch-stuck (FPTouch._on_press releases stale finger + _release_all
  on FOCUS_OUT), ramp retrigger (1.2s cooldown), board-airborne-car (_enter_car guard
  global_position.y<3.0 — is_on_floor was too strict, broke foot check), grant_weapon
  ownership guard, lite shadow dist 80->55. Skipped ACES-on-web (gl_compat supports it;
  confirmed running) + combo-callout tint (cosmetic). All 19 checks green. Web re-exported
  with all features + fixes (pck ~3.6MB). Server http://192.168.68.54:8777 (phone).
  Next options: deploy to shareable host, run summary/game-loop, more content.
- CITY UPGRADE (2026-08-11): varied skyline — fp_buildings.make storeys now 8% skyscraper
  (16-28), 20% mid (8-15), rest low (1-6); tall ones taper 80%. Palette 6->10 tones. Grid
  30->34, BUILDING_CHANCE 0.28->0.36. _lite skips ~28% buildings. All 19 checks green.
- DEPLOY: web re-exported with new city (pck 3.6MB). Package ready: build/web/ folder +
  build/road-rage-web.zip (13MB, nothreads = any static host, no COOP/COEP). Publish needs
  USER's account: recommend itch.io (upload zip, tick 'play in browser') or Netlify Drop
  (drag build/web). Server still at http://192.168.68.54:8777 for LAN phone testing.
- WEAPONS UNLOCKED + FIXES (2026-08-11/12): all 4 weapons owned from start (_weapons_owned
  all true) — 3/4 were gated behind crates + gave no feedback (user confused). Blast-death
  'crash/跳掉' = web gl_compat light budget: on _lite, explosions skip OmniLight + fewer
  particles, streetlights skip OmniLight (emissive still glows), rocket glow skipped —
  desktop was fine (repro respawns clean). Music: percussive loop -> calm ambient sine pad,
  vol -16->-22, M toggles. All 19 checks green. Web re-exported. UNVERIFIED: on-device web
  blast-death (can't run web here) — user must re-confirm on phone; music can't be auditioned.
- VEHICLE KINDS + COMMIT/DEPLOY (2026-08-25): FPVehicleKinds (scripts/fp_vehicle_kinds.gd)
  data-driven catalogue (6 kinds: 肌肉車[player, weight 0]/轎車/跑車/廂型車/卡車/公車;
  5 spawn as traffic). Traffic spawns a
  weighted mix; carjack hands the player that kind's drive profile (bus top 33.7->25.1,
  clumsier turn). Touch overlay: feature check asserts CJK glyphs in button font (Web
  fallback font renders tofu — bundled TTF) + overlay hidden on desktop. New tests:
  web_blast_check(.gd/.tscn), run_vehicle_shot, run_screenshot, dump_music; tools/
  web_blast_check.sh. Feature check #20 vehicles[...]. 20 items green, 23/23 unit tests.
  Committed (2 commits: road-rage work + meta notify-hook/docs). Web re-exported
  (pck 4.1MB) + road-rage-web.zip rebuilt (13.2MB). LAN server up: build/web on :8777,
  Mac IP NOW 192.168.0.144 (was 192.168.68.54 — DHCP changed) -> phone URL
  http://192.168.0.144:8777. STILL UNVERIFIED on device: web blast-death + CJK touch
  labels + music feel — user must confirm on phone/browser.
- ITCH.IO PUBLISH (2026-08-28..09-01): user confirmed on-device web test PASSED
  (blast-death + CJK labels + music OK). Published via butler v15.30.0 (~/.local/bin/butler,
  creds saved) to arlong666/rad-rage:html5 — NOTE slug is 'rad-rage' (user typo'd on page
  creation), title on itch = RUNRUNRUN. Build ✓ #1934691 v1 LIVE on channel html5.
  Push saga: (a) email had to be verified first; (b) uploads to GCS
  (commondatastorage.googleapis.com) die with 'use of closed network connection' on this
  network — curl works, butler's Go HTTP/2 long uploads get cut. FIX: GODEBUG=http2client=0
  (HTTP/1.1) + butler retries + run detached via nohup (session-killed background tasks
  killed 3 earlier attempts). PENDING USER STEPS: itch edit page → tick 'This file will
  be played in the browser' on the html5 upload, embed 960x540 (project viewport),
  mobile-friendly + fullscreen button on, then Draft -> Public.
  >>> 2026-09-01 DONE: user set embed + flipped Public. Verified live: HTTP 200 +
  Run-game embed at https://arlong666.itch.io/rad-rage. GAME IS PUBLISHED.
  Future updates = re-export web + one command:
  GODEBUG=http2client=0 ~/.local/bin/butler push road-rage/build/web arlong666/rad-rage:html5
  (run via nohup detached if from Claude Code; butler retries survive this network).
- Audio: procedural impact/explosion/gunshot. Engine drone DISABLED (user found the
  looping pitch sound annoying).

### Controls
Car (3rd-person): WASD drive, Shift nitro, Space handbrake, E exit, , / . look. T day/night.
Foot (FIRST-PERSON, 2026-07-24): WASD move, MOUSE look (yaw+pitch, vertical aim),
J/left-click shoot, Shift sprint, Space jump, E enter/carjack, Esc free/lock cursor.
Mouse captured on foot, released in car. Centre crosshair (HUD, on-foot only).
Fire travels along camera forward → can aim up and shoot the helicopter.

### FIXED 2026-07-23: orphaned WorldEnvironment (major visual bug)
`_build_environment()` created the WorldEnvironment (`we`) but never `add_child(we)`,
so the entire sky/ambient/fog/SSAO/SSR/bloom/ACES pipeline was inert — the game
rendered as a murky dark street lit only by sun + streetlight omnis. This is almost
certainly what the user meant by "沒看到更新" (they saw a dim, flat scene). One-line
fix `add_child(we)` restored the bright daytime look. Then tuned sky (vivid blue,
energy_multiplier 1.15) + lighter fog (0.0016). Proven by before/after screenshots.

### SCREENSHOT WORKFLOW (how to actually SEE the game headlessly-ish)
`tests/run_screenshot.gd` instantiates fp_main NON-headless, renders ~90 frames,
saves a PNG we can Read. Scratchpad dir must exist first (mkdir -p). Run:
`"$GODOT" --path road-rage -s res://tests/run_screenshot.gd` (NO --headless — needs GPU).
Then Read the PNG. This is the ground-truth check for any visual change.

### Verification (per delivery contract — always attach evidence)
- `GODOT=~/Downloads/godot-4.6.2/Godot.app/Contents/MacOS/Godot`
- Scan+cache: `"$GODOT" --headless --editor --quit`
- Unit tests (23): `"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`
- Feature check: `"$GODOT" --headless -s res://tests/run_feature_check.gd` → prints
  FEATURE_CHECK carjack/respawn/camera/explosion/heli — all must be true.
- Run for the user: `"$GODOT" --path road-rage` (GUI; feel/visuals need a real run).
  Launch WITHOUT piping to head so the output file captures the Metal/Forward+ banner + any crash.

### Next candidates (offered)
Weapon pickups, mission/objective framing, ramps/jumps, more vehicle types, weather,
shoot-down the heli (needs vertical aim), more environment variety.

---

<!-- STATUS -->
Epic: 大夜班 Pre-production
Feature: GDD 撰寫
Task: ②商品資料庫 r1 修訂完畢（768 行，待新 session 複審）→ 下一份 ③第一人稱控制器
<!-- /STATUS -->

**Unity KEY FACTS**（每次動 Unity 程式碼前重讀）：C# 9.0 only；`[SerializeField]` fields-only；
URP render-graph only（Compatibility Mode 在 6.3 移除）；NGO 2.13.2 ＋ Multiplayer Services
2.3.1 ＋ UTP **2.7.4**；Sessions API 的 `session.Code` 自帶房間碼（固定 6 碼全大寫，字集
`689BCDFGHJKLMPQRTW`，已無易混淆字元）；Web 需 `UseWebSockets = true` ＋ Relay 協定 WSS；
Relay 免費額度 50 平均 CCU 免綁卡；**Web build 強制 `compressionFormat = Gzip` ＋ `decompressionFallback = false`**（2026-09-18 定案，取代原本的 fallback=true）；**build size 硬標 ≤44MB（以實際出貨的 gzip 位元組計；brotli 等效約 33MB——兩個單位不可混用）**（由 50MB 修訂）；
**Unity 預設字型無 CJK，必須打包子集化字型**。


## Other games (paused, intact)
- Night Market (夜市) — boot game in `src/`, v0.59, 553 tests. word-suika (一字一句) — juiced + title. Lexicon Village — shelved.

## Solo Mode
`production/review-mode.txt` = `solo`.
