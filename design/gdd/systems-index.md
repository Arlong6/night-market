# Systems Index: 大夜班 (Night Shift)

> **Created**: 2026-09-04
> **Concept**: `design/gdd/game-concept-night-shift.md`
> **Art Bible**: `design/art/art-bible-night-shift.md`
> **Engine**: Unity 6.3 LTS / C# / Web
> **Review mode**: solo（TD-SYSTEM-BOUNDARY、PR-SCOPE、CD-SYSTEMS 已跳過）
> 舊專案（夜市）索引已改名為 `systems-index-night-market.md`。

## Overview

2-4 人連線第一人稱合作派對遊戲，共 19 個系統。連線是最大技術風險（新引擎＋
Web transport 未驗證），因此設計與原型順序以網路層優先。MVP 假設：「兩個朋友
透過瀏覽器連線，在一間超商裡合作應付客潮，能連玩 30 分鐘以上還想再開一班。」

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Session／房間系統 | Core | MVP | **Revised r4 (2026-09-13) — 待原型驗證，不再散文複審**（併入 netcode GDD） | [netcode-session.md](netcode-session.md) | — |
| 2 | 網路同步層 | Core | MVP | **Revised r4 (2026-09-13) — 待原型驗證，不再散文複審** | [netcode-session.md](netcode-session.md) | Session |
| 3 | 第一人稱控制器 | Core | MVP | 🟢 **Revised (2026-09-26) — `/design-review` 十位專家評審後的修訂已套用，待重新複審** ｜ 評審判決 NEEDS REVISION，四個根因：①**攝影機是無擁有者的子系統**（近裁面從未宣告 ⇒ 實作者拿 URP 預設 0.30 時速度超標 **67%**）②**levy 表只登記三分之二**（#5 四條硬拒絕、#8 整列缺）③**自我稽核文字四處算錯**（AC6 應 13 幀非 26、分層表應 72% 非 56%）④`W=0.9` 與 Player Fantasy 散文互斥。**零 Core Rule／零介面／零 levy 需改，硬交付站得住。** 🟢 **OQ-F1 已實測通過**（itch.io iframe 內 pointer lock 可用；結構性原因：該 iframe 無 `sandbox` 屬性。探針 `prototypes/w1-pointerlock-probe/`）｜ **本次修訂**：新增 F0 攝影機常數節（`camera_near_clip_m`=0.10 等）；`player_move_speed_max` **1.39→1.47**（margin 由「挑的 0.79」變「推導的 0.831」）；`npc_pin_timeout_sec` **4.0→1.5**（AC13③ 方向反了，客人實為隊友的 1.9 倍黏）；AC5 新增子句 j／k；OQ-F1／F3／F9 關閉；`L_p95` 標示更正 ｜ 🟢 **31 條 T0 已跑：PASS 32/32**（`prototypes/fp-controller-core/`）。檢定成立——C8／C9 碰撞模型健全；另抓到 AC8a③ 與 AC3 矛盾（十位專家全漏）及三項規格空白，已補回 GDD。**下一步：T1（借 w1-netcode 跑 AC32/33）或直接進 ADR（OQ-F11 純 C# 求解器）** | [first-person-controller.md](first-person-controller.md) | 網路同步層 |
| 4 | 攜帶與交付 | Gameplay | MVP | Not Started | — | FP控制器, 機台互動組, 客人系統, **商品資料庫** |
| 5 | 機台互動組 | Gameplay | MVP | Not Started | — | 網路同步層, 商品資料庫, **第一人稱控制器**（座標／yaw／射線起點，2026-09-23 補登） |
| 6 | 商品資料庫 | Core | MVP | **In Review (r3 修訂完＋原型已跑 2026-09-21)** — 純 C# 原型 44 PASS / 0 FAIL、Design Test 撞 3/5，**不再開散文輪**；下一輪對象是 Unity 實作（`prototypes/product-database-core/`） | [product-database.md](product-database.md) | — |
| 7 | 客人系統 | Gameplay | MVP | Not Started | — | 網路同步層, 商品資料庫, 第一人稱控制器（角色膠囊，軟，2026-09-23 補登） |
| 8 | 波次導演 | Gameplay | MVP | Not Started | — | 客人系統, 遊戲時鐘, **商品資料庫**（軟） |
| 9 | 遊戲時鐘 | Core | MVP | Not Started | — | — |
| 10 | 窗外天色系統 | UI/Presentation | Vertical Slice | Not Started | — | 遊戲時鐘 |
| 11 | HUD 與需求 icon | UI | MVP | Not Started | — | 機台互動組, 客人系統, **商品資料庫**, **第一人稱控制器**（攝影機 transform，2026-09-23 補登） |
| 12 | 大廳 UI 與流程 | UI | MVP(輸碼加入)/VS(完整) | Not Started | — | Session |
| 13 | 結算畫面 | UI | MVP | Not Started | — | 評分邏輯, **商品資料庫**（軟） |
| 14 | 音效系統 | Audio | MVP(機台音效)/VS(全套) | Not Started | — | 機台互動組, 客人系統, 第一人稱控制器（位置，供腳步與碰撞音空間化，軟，2026-09-23 補登） |
| 15 | 評分邏輯 | Gameplay | MVP | Not Started | — | 商品資料庫 |
| 16 | 進度與解鎖 | Progression | Alpha/Full | Not Started | — | 評分邏輯 |
| 17 | 教學／第一班 | Meta | Alpha | Not Started | — | 波次導演 |
| 18 | 設定與無障礙 | Persistence | Alpha | Not Started | — | — |
| 19 | 單人練習模式 | Meta | Alpha | Not Started | — | 波次導演 |

## Priority Tiers

| Tier | Definition | 本作對應 |
|------|-----------|---------|
| **MVP** | 核心假設無法驗證就不算數的系統 | 1-9, 11, 13, **14(機台音效＋角色碰撞音)**, 15, 12(僅輸碼) |
| **Vertical Slice** | 一班完整體驗（熬到天亮的情緒弧） | 10, 12(完整), **14(全套，含角色腳步音)** |
| **Alpha** | 機制齊備粗胚 | 16, 17, 18, 19 |
| **Full Vision** | 內容完整（店型/裝飾全集） | 16 的長尾內容 |

## Dependency Map

### Foundation Layer (no dependencies)
1. Session／房間系統 — 一切連線的入口（MPS Sessions＋房間碼）
2. 商品資料庫 — 資料驅動之法：所有需求與 SKU 的單一真相源
3. 遊戲時鐘 — 21:00→08:00，導演與天色的共同骨幹

### Core Layer
1. 網路同步層 — depends on: Session（NGO 物件所有權、互動同步、RPC 慣例、重連）
2. 第一人稱控制器 — depends on: 網路同步層
3. 機台互動組 — depends on: 網路同步層, 商品資料庫, **第一人稱控制器**
4. 客人系統 — depends on: 網路同步層, 商品資料庫, 第一人稱控制器（膠囊，軟）
5. 評分邏輯 — depends on: 商品資料庫（純邏輯，EditMode 可測）

### Feature Layer
1. 攜帶與交付 — depends on: FP控制器, 機台互動組, 客人系統, 商品資料庫（搬運 ProductInstance）
2. 波次導演 — depends on: 客人系統, 遊戲時鐘, 商品資料庫（依站台配重抽樣，軟依賴）
3. 單人練習縮放 — depends on: 波次導演

### Presentation Layer
1. HUD 與需求 icon — depends on: 機台互動組, 客人系統, 商品資料庫（icon 查詢鍵）, **第一人稱控制器**（攝影機 transform）
2. 窗外天色系統 — depends on: 遊戲時鐘
3. 大廳 UI 與流程 — depends on: Session
4. 結算畫面 — depends on: 評分邏輯, 商品資料庫（display_label，軟依賴）
5. 音效系統 — depends on: 機台互動組, 客人系統, 第一人稱控制器（位置，軟）

### Polish Layer
1. 進度與解鎖 — depends on: 評分邏輯
2. 教學／第一班 — depends on: 波次導演
3. 設定與無障礙 — depends on: —

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | 網路同步層＋Session（合併設計） | MVP | Foundation/Core | technical-director, network-programmer | M |
| 2 | 商品資料庫 | MVP | Foundation | systems-designer | S |
| 3 | 第一人稱控制器 | MVP | Core | gameplay-programmer, game-designer | S |
| 4 | 機台互動組 | MVP | Core | game-designer, systems-designer | M |
| 5 | 客人系統 | MVP | Core | game-designer, ai-programmer | M |
| 6 | 評分邏輯 | MVP | Core | systems-designer | S |
| 7 | 波次導演＋遊戲時鐘（合併設計） | MVP | Feature | game-designer, systems-designer | M |
| 8 | 攜帶與交付 | MVP | Feature | game-designer | S |
| 9 | HUD 與需求 icon | MVP | Presentation | ux-designer, ui-programmer | S |
| 10 | 結算畫面 | MVP | Presentation | game-designer, ux-designer | S |
| 11 | 大廳 UI 與流程（MVP 版） | MVP | Presentation | ux-designer | S |
| 12 | 音效系統（機台音效） | MVP | Presentation | sound-designer | S |
| 13 | 窗外天色系統 | VS | Presentation | technical-artist | S |
| 14 | 其餘（16-19） | Alpha+ | — | — | — |

## Circular Dependencies

- None found。
- 注意「攜帶與交付 ↔ 客人系統」的介面邊界：客人只認「收到符合需求的商品」事件，
  不知道商品怎麼來——用事件契約切開，避免日後互相糾纏。

## High-Risk Systems

1. **網路同步層（最高風險）**：新引擎＋NGO 2.x＋Relay WSS on Web 無官方端到端範例
   ——**GDD 寫完直接做技術原型驗證，不等其他系統**
2. **機台互動組**：五站小手感是「忙得有節奏」的爽感來源，需大量調校
3. **波次導演**：「忙到爽 vs 忙到煩」一線之隔，數值全走商品資料庫以便快速迭代

## 跨系統前向義務（2026-09-20 新增）

已定案的 GDD 會對「尚不存在的系統」創造義務。**在義務被登記到本節之前，它等於不存在**
——寫在來源文件第 N 行的一句話，目標系統的作者沒有理由讀到。
每個系統開工前必須先讀本節屬於它的列。

⚠ **本節是前向義務的唯一真相源（2026-09-20 r3）。** 先前來源 GDD 裡也各留了一份副本，而商品資料庫那一份**在誕生當天就已經與本節長度不同**（本節 10 列、副本 6 列）。一張只會漂移、而且已經漂移了的副本不是冗餘備份，是未來的矛盾來源。**來源 GDD 只保留指向本節的一行指標。**

| 欠誰 | 義務 | 來源 |
|---|---|---|
| **#4 攜帶與交付** | ①擁有**跨訂單分配**：同一份商品同時被不同客人的訂單接受時歸誰（判準：東西給你遞給的那個客人）。商品資料庫的 Named-先於-Family 只在單一訂單內成立 ②⚠ **r3 新增：不得以 `NetworkVariable`／`NetworkList` 承載 `ProductInstance` 的集合**。多槽攜帶（「米血！兩串！」）的自然形狀是 `NetworkList<ProductInstance>`，它要求 `T: unmanaged + IEquatable<T> +` NGO 可序列化——而那會逼 `ProductInstance` 的擁有組件引用 NGO，違反 AC14。**本專案已踩過這坑**（netcode 的 `ClaimGeneration`）。要如此須先做 W1 式實測並重新裁決 AC14 | `product-database.md` 槽位分配規則／刻意不處理／OQ-P12 |
| **#5 機台互動組** | ①提供 `Shelf` 家族的**可得性查詢**（⚠ r3：**三個產生器家族也不是無界的**，站台一次只服務一人，量詞應推廣，見 GDD）②`is_spoiled`／`network_index` 依商品資料庫的裁決為 **server-write、且必須在 `NetworkObject.Spawn()` 之前寫入、之後不可變**，不得自行發明寫入路徑——⚠ **r3 補上「Spawn 之前」這一句，而它是整條裁決唯一讓它成立的條件**：寫在 Spawn 之後會變成 tick-gated delta，在 10Hz 下製造一個與實測交接時間同量級（約 100ms）的窗口，接收端讀到 `network_index == 0` 並在 NGO 訊息迴圈裡拋例外，**而本地與 host-only 測試 100% 綠**③**不得以 `NetworkVariable`／`NetworkList` 承載 `ProductInstance` 的集合**（要如此須先 W1 式實測並重裁 AC14）④**若 #5 提供「列出 SKU 的機台選單」，`nameable` 的內容配額剎車當場歸零**（§3.3 禁文字 → 每筆 SKU 都要符號）——若要做，須先回頭重裁 `sku_nameable_max` | `product-database.md` 刻意不處理／Interactions／OQ-P12 |
| **#7 客人系統** | ①定下**指名需求出現比例**上限並反向引用（商品資料庫明確**不**擁有此值）②包含驗收「同時在場相異需求符號數上限」的測項，計數單位是**槽**不是客人 ③在 #5 的可得性查詢存在前，**不得從 `Shelf` 家族抽 `Named`** ④⚠ **r3：`sku_concurrent_distinct_max` 現在有值了（4，PROVISIONAL）**——r2 把這條約束 levy 出去卻沒給值，於是 #7 被要求為一個無值變數寫一條**不可能失敗**的測項 ⑤⚠ **不得以「收緊指名池」作為平衡手段而使 `nameable` 實際可用數降到 2 以下**（MVP 下限已由 arlong 裁為 2；破壞它不會讓任何一條 AC 變紅） | `product-database.md` Player Fantasy／Tuning Knobs |
| **#11 HUD 與需求 icon** | ①~~層級標記的具體圖形~~ **已於 2026-09-20 由 art-director 裁定**（Ink 挖空方塊／橫條，從填充裡挖空而非外加，故 icon 外接矩形不變、不影響多 icon 擺位）②**回填門檻 6 的測試尺寸**（第一版場景量測；32×32 是暫代值，全專案沒有人量過頭頂 icon 的實際螢幕像素）③⚠ **r3 新增：多 icon 擺位仍是 #11 的，但受兩條本表才能授予的約束**——任何需求符號**不得小於門檻 6 驗證用的回填尺寸**（所以多槽**不得靠縮小 icon 解決**），且一張訂單的 N 個槽在頭頂就是 **N 個符號實例** ④🔴 **2026-09-22 新增：非語音的「我要這個」ping**。arlong 裁決 MVP 不做遊戲內語音，而支柱 4 帶進來的陌生人因此**沒有任何語言頻道**——需求溝通的 100% 載荷落在 icon 與這個 ping 上。它是唯一對聽障玩家、吵雜環境、陌生人房都成立的版本 ⑤**單方可解的走道幾何**：列舉店面所有走道段落，不得存在「兩具身體互相釘死」的幾何（深度剛好兩人份的死巷）。⚠ 這是第一人稱控制器**提出而無權擁有**的請求 | `product-database.md` 門檻 5／6／Visual-Audio；`first-person-controller.md` Player Fantasy |
| **#5 機台互動組**（第一人稱控制器新增，**四條硬拒絕**；⚠ **2026-09-26 補登——本表先前完全漏列，而來源 GDD 自 2026-09-23 起就宣稱「已登記」**） | ①🔴 **不得鎖住玩家移動**。站定需求以「離開站台即中斷」實作，不以鎖移動實作——netcode 已為「不會動的人形」付出一條 Core Rule ＋ AC49，不該從另一個入口把它放回來 ②**不得設計任何需要蹲下／跳躍／特定身高或垂直對位才能觸及的互動點**（C2／C4 已刪除這三個狀態；彎腰是動畫不是狀態，不得改碰撞體、不得改移動、不得同步）③🔴 **Host 驗不了瞄準**：俯仰不同步（C6），Host 手上沒有發起端的俯仰值，**互動驗證只能驗水平距離與水平朝向**——這會改變 #5 的驗證設計，必須在動工前知道 ④🔴 **站台的「離開即中斷」半徑必須大於 `2·r_c`（0.6 m）**：被鎖在站台前的玩家**仍然執行解除穿透**，所以任何人從他身後走過都會把他推離站台；若中斷半徑小於 0.6 m，**任何人走過都會中斷別人的互動**，而那是判準 1 完全無法歸因的失敗——被中斷的人根本不知道是誰、也不知道為什麼 | `first-person-controller.md` C4／C6／C7／硬拒絕「給 #5 三條」（實為四條）／Edge Cases「下游違反硬拒絕時」 |
| **#8 波次導演**（第一人稱控制器新增；⚠ **2026-09-26 補登——本表先前無任何 #8 列**） | 🔴 **定義「節拍邊界」，因為第一人稱控制器的兩條判準把分母壓在它身上** ①**判準 3（有限性）**：「單次非自願阻塞不得跨越兩個波次節拍」——節拍邊界由 #8 定義，**在它存在之前這條判準無法寫出可判定的 AC** ②**判準 6（與節奏同步）**：非自願阻塞必須跟著波次起落；若空檔也在**非自願**阻塞，那是坪數問題不是節奏問題 ③⚠ **一個尚未驗算的交叉約束**：來源 GDD 宣稱判準 3 的上界「已由 AC14（4.0 s 必降級）＋ AC23 覆蓋」，**而那句話只在節拍長度 ≥ 2 秒時成立**（兩個節拍 ≥ 4.0 s）。若 #8 定出比 2 秒短的節拍，該覆蓋宣稱即為假，須補驗算 `2 × beat_length ≥ player_pin_timeout_sec` ④**「穿越店面所需時間上限」需 #8／#11／#3 三方聯署**：上界取決於 #8 對「一單需要幾次跑動、每次可接受多久」的設計，而速度已被 F1 焊死、坪數受支柱 3 約束 | `first-person-controller.md` Player Fantasy 判準 3／判準 6／「刻意不設 AC」／levy 表 |
| **#11 HUD／關卡佈局**（第一人稱控制器新增） | ①**隊友「不在」的指示**——按 Esc 的隊友仍在場且可被推，畫面上必須看得出他不在，否則直接撞上「他是不是故意不讓我」②`PassThrough` 降級**雙向可見**（靜默降級破判準 1）③恢復指標鎖定的點擊目標須規定**面積下限**（解鎖後游標位置各瀏覽器不明）④**走道死巷清查**：不得存在「兩具身體互相釘死」的幾何 ⑤一個具名的「穿越店面所需時間上限」常數——它是拒絕衝刺之後欠下的債 | `first-person-controller.md` Interactions |
| **#14 音效系統**（⚠ **2026-09-26 重寫：原文是祈使句，實為跨 tier 範圍請求**） | 🔴 **`14(最小)` 的 MVP 射程擴大為「機台音效 ＋ 角色碰撞音」**（2026-09-26 arlong 裁決；本表第 44 行 Priority Tiers 已同步）。**腳步音留在 `14(全套)`／Vertical Slice。** ⚠ **這條先前以「必須進 MVP 射程」的祈使句寫成 levy，但它其實是要求推翻一條已裁決的 tier 指派**，未經任何裁決流程——已補走。**拆法沿用來源 GDD 自己的 MUST／SHOULD 切分**：判準 1（可歸因性，**MUST**）的觸發是**離散事件**（此刻被擋、被誰擋），一顆撞擊音＋隊友／客人兩種音色即可；判準 5（可預見性，**已由 MUST 降為 SHOULD**）的觸發是**連續逼近**，那才是貴的——空間化品質、循環、以及**「步頻」這個常數**（⚠ walk bob 被 MVP 排除後，本專案已無步幅／每秒步數的既有來源，#14 必須自行提案並與 `player_move_speed_max` 連動，比照 F1 對 `player_speed_ramp_sec` 的連帶要求）。⇒ **MUST 以約 15% 的成本交付，SHOULD 與它所需的新常數一起延後。** ⚠ **仍缺的規格（#14 動工前須補齊，來源 GDD 只給了三句話）**：①遠端隊友的碰撞音觸發——依 C16「不另設管道，從內插後的位置微分導出」，**#14 須在收端自行微分，不是收事件** ②衰減曲線 ③同時發聲數上限與搶聲策略 ④遮蔽（MVP 建議明文「不做」，不得留白）⑤混音優先序 ⑥可區分性的可證偽驗收門檻（比照 AC41 的 n≥6 格式，不得只寫結論句）⑦自己的碰撞音是否可聞 | `first-person-controller.md` Visual/Audio Requirements／Player Fantasy 判準 1、判準 5 |
| **#18 設定與無障礙**（第一人稱控制器新增） | ①🔴 **動暈保護整項目前無人登記**——第一人稱＋鏡頭位移有實質曝險，而本節先前唯一登記給 #18 的是光敏性 ②靈敏度入口 ③視野角的射程裁決 ④鍵位重綁。⚠ **時序矛盾**：#18 是 Alpha，而前三項在 MVP 就有曝險，需 arlong 裁決 | `first-person-controller.md` Interactions |
| **#15 評分邏輯** | **必須**包含槽位分配的整合測項並反向引用商品資料庫的「槽位分配規則」。商品資料庫的 AC13 只覆蓋規則本身——**它的綠燈會加劇「兩邊都以為對方測過」，不是消除它** | `product-database.md` 槽位分配規則 |
| **netcode GDD** | ①版本 token 的**粒度必須涵蓋純內容變更**（SKU 表隨 build 出貨）。⚠ 目前 `netcode-session.md` 對商品資料庫**零筆紀錄**，而 OQ-P8 的擁有者正是它——不回填這一行，那條 OQ 會變成孤兒 ②⚠ **r3 新增：裁決約束⑧ 的讀法。** `:1233` 的原文是「不得以 NetworkVariable 承載**結果**」，而 `:1635` 又收窄成「owner-write NetworkVariable」——**netcode GDD 自己不一致**。**若廣義讀法勝出，`is_spoiled` 是互動結果，商品資料庫關閉 OQ-P9 的整條裁決要重做。** | `product-database.md` 規則 2／OQ-P8／OQ-P9 |
| **netcode GDD**（第一人稱控制器新增，**五條**更正；原本誤記為四條，而下方列了五項） | ①🔴 **端到端落後量未區分觀看對**：client↔client 走 **4 段 relay 腿**（A→R→Host→R→B）不是 2 段，東京 relay 下約 239–339ms、預設 region 約 481–581ms ②🔴 **AC23 不覆蓋「可預見性」**——它測單幀平滑性，與**前置時間正交**，「落後很大但完美平滑」會拿到綠燈 ③🔴 **黏鍵 × 背景 1Hz 會讓 AC15／AC23 給假綠燈**：判準是「單幀位移 ≤ 速度上限 × 時間步長」，**時間步長放大時上限跟著放大**，形式上不違反、視覺上是瞬移 ④**分頁隱藏與焦點遺失是兩個不同事件**，上游只裁了前者 ⑤🔴 **AC23 在構造上餘裕為零**：遠端內插的每幀位移在 owner 全速時**恰好等於** `v × dt`（一個 tick 的位移攤在 0.1s 渲染時間上），任何 dt 抖動、HOL 後 burst、兩端幀率不對等都會超線——**這條 AC 會在正確的實作上隨機紅燈**。建議改為 `≤ v × dt × remote_step_tolerance`（暫定 1.5）並記錄比值 p99 分佈。⚠ **第一人稱控制器交出了 `player_move_speed_max` 解除了 AC23 的封鎖，但 AC23 本身需要這個容差項才會是可用的測試——解除封鎖與修封鎖是兩件事**。✅ **2026-09-24 已代為改上游文字**（`netcode-session.md:1256/1433/1538`，並補 `:1418`）：AC15、AC23 的判準改成帶容差項的形式，兩條同標 `blocked-by: remote_step_tolerance`，舊的 `blocked-by: 第一人稱控制器 GDD` 標為解除。**剩下的是 netcode 定義 1.5 這個值**（OQ-F7）。⚠ **AC15 原本沒有 blocked-by 標記**，本輪才與 AC23 對齊——它是同一個形式，而背景恢復本身就保證 dt 抖動，處境更差。⚠⚠ **容差項不解決 ③**：`× dt` 仍在式子裡，所以黏鍵／背景 1Hz 下上限照樣跟著時間步長放大，**乘上 1.5 只是讓那個假綠燈的門再寬 50%**。③ 需要的是對 `dt` 本身設上限（例如以 `movement_max_step_sec` 夾制判準側的 dt），那是另一條修正，仍未動。 | `first-person-controller.md` Interactions／Formulas U1 |
| **technical-director**（第一人稱控制器新增，三條） | ①🔴 **itch.io iframe 內指標鎖定可不可用**——W1 量到的 `allow` 字串**不含 `pointer-lock`**，而同一條實測已證明 `clipboard-write` 缺席確實導致 Clipboard API 被擋。**失敗則第一人稱視角在既定發行通路上不成立，不是調參數是重畫。成本約 1 小時，W1 部署管線已存在——全檔風險最高、驗證成本最低的一項** ②🔴 **移動求解器是不是純 C#（ADR）**——這個 ADR 的答案**值 24 條 AC**：若把移動邏輯綁進 `CharacterController`，AC 節的 T0 層會整層塌掉，今天可執行率從 56% 掉到接近 0。⚠ 而 `technical-preferences.md` 的測試慣例正好要求相反方向 ③`remote_step_tolerance` 的定義與歸屬（AC23 零餘裕） | `first-person-controller.md` OQ-F1／OQ-F11／OQ-F7 |
| **technical-director ＋ devops** | **ADR-XXX 建置期資料治理閘門**。⚠ **r3 拆成兩軸，範圍縮小**：r2 寫「15 條 AC 的 BLOCKING 效力取決於它」並整批降為 ADVISORY——但那把 **AC6c 也掃了進去，而 build hook 對一條型別建構測試無事可做**。現在：**軸 1（證據閘，沒有通過的測試就不得標 Done）今天就生效、不降級**；**軸 2（建置期強制）**才取決於本 ADR，且只適用於**資料不變量**（14 條，不含 AC6c） | `product-database.md`「『BLOCKING』的兩軸」 |
| **art-director** | ~~解決 §3.3 vs §8.6 的自相矛盾~~ **已於 2026-09-20 裁決（OQ-P14 關閉）**：兩者是同一顆 icon 的填充層與輪廓層；需求 icon **是**貼圖；原則 2 射程限縮為**有體積的物件**；白描邊改 `Ink_Contour #23282A`（對白牆 1.17:1 → 12.71:1）；`Atlas_Ui` mipmap **關改開**；`sku_nameable_max` 依形狀預算 **8 → 6**。**剩餘待辦**：①把 9 處裁決落回美術聖經②`Ui_IconTier_*` 納入 §8.6 例外清單並依 §8.9 留裁決紀錄③⚠ **升級 arlong 決定射程**：白描邊改 Ink 會波及**所有互動黃物件**（收銀條碼、集點貼紙…），可限縮為「僅頭頂 icon」 | `product-database.md` OQ-P14／Visual-Audio |
| **creative-director** | ①~~遊戲內語音是否進 MVP~~ **已於 2026-09-22 裁決：MVP 不做語音**，ping 改欠 #11 ②**受眾範圍**應明示裁決（OQ-P17，仍未裁）③🔴 **視野角在 MVP 沒有擁有者**——它是移動速度處置順序的**第一步**（唯一不進任何不等式的槓桿），而射程裁決掛在 #18、#18 是 Alpha。「太慢」這個最可能的 playtest 回報在 MVP 只剩最危險的那條路 ④🔴 **#18 的時序矛盾**：動暈保護、靈敏度入口、視野角射程**三項在 MVP 就有曝險**，而 #18 是 Alpha | `product-database.md` OQ-P13（已關）／OQ-P17；`first-person-controller.md` OQ-F3／OQ-F9 |
| **#18 設定與無障礙** | **光敏性**：多顆同時閃爍的需求 icon 是設計意圖，但全專案無閃爍率上限、無關閉選項。⚠ **r3 兩項修正**：①商品資料庫的並發上限**不是**光敏性上限（r2 如此宣稱，那是錯的——危害取決於**面積與頻率**，與花色種類數無關，而 §4.3 明許「十顆黃 icon 同亮」）；②§8.3 的共享材質全域脈動意味著所有閃爍**同相，面積會相加**。**本項無人提供任何保護**，且「關閉閃爍」之後超時要改用什麼編碼也無規格 | `product-database.md` OQ-P16 |

## ⚠ `design/gdd/` 混著兩款遊戲（2026-09-21 `/consistency-check` 記錄，暫不處理）

**21 個 GDD 裡只有 4 個是大夜班的**：`product-database.md`、`netcode-session.md`、
本索引、`game-concept-night-shift.md`。其餘 **14 個屬 Lexicon Village／夜市**
（`game-session-state.md`、`symbol-binding.md`、`cascade-shimmer.md`、`vignette-*.md`、
`village-scene-layout.md`、`notebook-ui.md`、`dialogue-display.md`、`input-system.md`、
`boot-scene-flow.md`、`camera-viewport.md`、`npc-sprite-tableau.md`、
`procedural-generator.md`、`title-screen.md`、`lexicon-village-elder-question.md`），
索引在 `systems-index-night-market.md`。

`design/registry/entities.yaml` 同樣混著：59 條常數裡 `total_semantic_slots`、
`vignette_count`、`slots_per_vignette_range` 與 `unresolved_count`／`vignette_valid`
兩條公式屬 Lexicon Village。

**目前不產生實際衝突**（兩邊命名空間不重疊），**但這是一顆定時炸彈**：
`/consistency-check` 的規格是「比對**所有** GDD」，所以一旦兩款遊戲出現同名常數
（`shift_length_sec`、`max_players`、`slots_*` 這類通用詞很容易撞），
**它會把兩款遊戲的值當成矛盾來報，而報告不會告訴你它們根本不是同一個遊戲。**

**裁決（2026-09-21 arlong）**：先只記錄，不搬目錄。理由是 Lexicon Village 目前無人推進，
而搬目錄會打斷大量跨檔連結。**真的撞名時再動**——屆時的選項是
①搬到 `design/gdd/lexicon-village/` ②只拆 registry（加 `game:` 欄位）。

## 評審紀錄的效力規則（2026-09-20 新增）

> **`design/gdd/reviews/*-review-log.md` 的條目只能記錄「作者宣稱已處理」。
> 「已解決」只能由獨立的再評審寫入。**

理由（r2 從商品資料庫身上學到的）：r1 的 log 由**修訂者自己**簽發「全部 blocking
已處理」，而 r2 以九位零背景專家查出六個根因中**兩個未修、三個只修表面**。
沒有再驗證步驟的自簽 log 有一個結構性性質——**修法越淺，log 越綠**。

### 何時停止評審、改去建東西（2026-09-20 r3 新增，第二次判例）

> **一輪評審若其產出單位與文件的失敗單位是同一個單位，它在構造上會製造下一輪的工作。**

netcode GDD 在 r4、商品資料庫在 r3，各自由 creative-director 裁定「最後一輪散文式評審」。
兩次的理由是同一個，而 r3 把它量化了：

- **缺陷在追著修訂跑。** r3 嚴重度／成本比前 10 名裡，**9 條落在 r2 那一輪自己寫下的
  文字上**；而「改了定義處、漏了引用處」這個 r2 自己命名的模式，在 r2 自己的修訂裡
  復發約 20 次，其中 6 次落在 r2 這一輪編輯或新建的 artefact 上。
- **散文評審沒有可以反駁自己的儀器。** 商品資料庫 30 條 AC 裡今天真能跑的只有 1 條；
  r3 自己的發現裡**有八條是編譯器一個下午免費回答的**。
- **系統太小。** 全部公開表面是 4 個型別、1 個介面 6 個成員、2 個純函式、4 個 enum、
  20-40 筆資料。1,586 行文件、三輪、十一位專家，去規格一個能在一個下午寫完的資料層。
  **文件本身現在是這個系統最大的風險資產**——它是唯一一個會漂移、會自相矛盾、
  且沒有編譯器檢查的東西。

**判準（下次要用這個問，不要靠感覺）**：
1. 本輪的發現裡，**有幾條是編譯器或一次實跑會免費回答的**？過半 → 停。
2. 本輪的 AC 裡，**今天真能跑的有幾條**？趨近於零 → 停。
3. **缺陷落在誰寫的文字上**？多數落在上一輪的新文字上 → 停（缺陷產生率已是修訂速率的函數）。

**若仍須再開一輪散文評審，強制兩條**：
- **回報淨斷言變化量 Δ**（如同 r3 強制回報駁回率）。**Δ 為正的一輪，在構造上必然
  製造下一輪的工作。** ⚠ r3 自己的修訂 Δ 是 **+301 行**——本判例的第一個反例就是它自己。
- **禁止「新增斷言」作為預設修法**；每條建議須標明它是**新增**還是**刪除／合併**。

## Progress Tracker

19 systems: 2 Revised r4 (待原型) / 1 In Review (商品資料庫 **r3 修訂完＋純 C# 原型已跑**) / **1 Designed (第一人稱控制器 2026-09-24，1390 行，待獨立複審)** / 0 Approved / 15 Not Started
⚠ r3 修正：本行原本寫「r1 修訂完」，而同檔第 24 行已經改成 r2——**改了定義處、漏了引用處，發生在同一個檔案裡相隔 118 行**。這正是商品資料庫三輪下來唯一反覆復發的缺陷類型。
（#1 Session＋#2 網路同步層 → netcode-session.md，2026-09-04 首版；r3 修訂 2026-09-06；
r4 修訂 2026-09-13，698→1224 行）

> **netcode GDD 的流程狀態（creative-director 於 r4 裁定）**：
> **r4 是最後一輪散文式評審，不再開 r5 六專家複審。** 四輪下來每一輪的 blocking 都長在
> 上一輪修補的縫隙裡，而約四成的確認項是「對一個沒人跑過的系統的斷言」——散文評審沒有
> 可以反駁它們的儀器。下一步是 (1) 重跑三張機械檢查、(2) **直接開 W1 技術原型**。
> 原型回填造成的變更走「回填 diff 複核」，不再開全審。
> **原型 W1 優先序**：P-10 → P-4/P-6/P-19（同一次 itch.io 部署）→ P-7 → P-3 ＋ OQ#1（與 AC22 聯測）
> → P-13/P-14/P-15 → P-9/P-16 → P-17/P-18/P-20。
> **W1 成功判準**：原型報告必須回填 [P] 表的「影響」欄——每條被推翻的假設要明講它殺掉了哪幾條 AC。
