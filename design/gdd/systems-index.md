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
| 3 | 第一人稱控制器 | Core | MVP | Not Started | — | 網路同步層 |
| 4 | 攜帶與交付 | Gameplay | MVP | Not Started | — | FP控制器, 機台互動組, 客人系統, **商品資料庫** |
| 5 | 機台互動組 | Gameplay | MVP | Not Started | — | 網路同步層, 商品資料庫 |
| 6 | 商品資料庫 | Core | MVP | **In Review (r3 修訂完＋原型已跑 2026-09-21)** — 純 C# 原型 44 PASS / 0 FAIL、Design Test 撞 3/5，**不再開散文輪**；下一輪對象是 Unity 實作（`prototypes/product-database-core/`） | [product-database.md](product-database.md) | — |
| 7 | 客人系統 | Gameplay | MVP | Not Started | — | 網路同步層, 商品資料庫 |
| 8 | 波次導演 | Gameplay | MVP | Not Started | — | 客人系統, 遊戲時鐘, **商品資料庫**（軟） |
| 9 | 遊戲時鐘 | Core | MVP | Not Started | — | — |
| 10 | 窗外天色系統 | UI/Presentation | Vertical Slice | Not Started | — | 遊戲時鐘 |
| 11 | HUD 與需求 icon | UI | MVP | Not Started | — | 機台互動組, 客人系統, **商品資料庫** |
| 12 | 大廳 UI 與流程 | UI | MVP(輸碼加入)/VS(完整) | Not Started | — | Session |
| 13 | 結算畫面 | UI | MVP | Not Started | — | 評分邏輯, **商品資料庫**（軟） |
| 14 | 音效系統 | Audio | MVP(機台音效)/VS(全套) | Not Started | — | 機台互動組, 客人系統 |
| 15 | 評分邏輯 | Gameplay | MVP | Not Started | — | 商品資料庫 |
| 16 | 進度與解鎖 | Progression | Alpha/Full | Not Started | — | 評分邏輯 |
| 17 | 教學／第一班 | Meta | Alpha | Not Started | — | 波次導演 |
| 18 | 設定與無障礙 | Persistence | Alpha | Not Started | — | — |
| 19 | 單人練習模式 | Meta | Alpha | Not Started | — | 波次導演 |

## Priority Tiers

| Tier | Definition | 本作對應 |
|------|-----------|---------|
| **MVP** | 核心假設無法驗證就不算數的系統 | 1-9, 11, 13, 14(最小), 15, 12(僅輸碼) |
| **Vertical Slice** | 一班完整體驗（熬到天亮的情緒弧） | 10, 12(完整), 14(全套) |
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
3. 機台互動組 — depends on: 網路同步層, 商品資料庫
4. 客人系統 — depends on: 網路同步層, 商品資料庫
5. 評分邏輯 — depends on: 商品資料庫（純邏輯，EditMode 可測）

### Feature Layer
1. 攜帶與交付 — depends on: FP控制器, 機台互動組, 客人系統, 商品資料庫（搬運 ProductInstance）
2. 波次導演 — depends on: 客人系統, 遊戲時鐘, 商品資料庫（依站台配重抽樣，軟依賴）
3. 單人練習縮放 — depends on: 波次導演

### Presentation Layer
1. HUD 與需求 icon — depends on: 機台互動組, 客人系統, 商品資料庫（icon 查詢鍵）
2. 窗外天色系統 — depends on: 遊戲時鐘
3. 大廳 UI 與流程 — depends on: Session
4. 結算畫面 — depends on: 評分邏輯, 商品資料庫（display_label，軟依賴）
5. 音效系統 — depends on: 機台互動組, 客人系統

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
| **#11 HUD 與需求 icon** | ①~~層級標記的具體圖形~~ **已於 2026-09-20 由 art-director 裁定**（Ink 挖空方塊／橫條，從填充裡挖空而非外加，故 icon 外接矩形不變、不影響多 icon 擺位）②**回填門檻 6 的測試尺寸**（第一版場景量測；32×32 是暫代值，全專案沒有人量過頭頂 icon 的實際螢幕像素）③⚠ **r3 新增：多 icon 擺位仍是 #11 的，但受兩條本表才能授予的約束**——任何需求符號**不得小於門檻 6 驗證用的回填尺寸**（所以多槽**不得靠縮小 icon 解決**），且一張訂單的 N 個槽在頭頂就是 **N 個符號實例** | `product-database.md` 門檻 5／6／Visual-Audio |
| **#15 評分邏輯** | **必須**包含槽位分配的整合測項並反向引用商品資料庫的「槽位分配規則」。商品資料庫的 AC13 只覆蓋規則本身——**它的綠燈會加劇「兩邊都以為對方測過」，不是消除它** | `product-database.md` 槽位分配規則 |
| **netcode GDD** | ①版本 token 的**粒度必須涵蓋純內容變更**（SKU 表隨 build 出貨）。⚠ 目前 `netcode-session.md` 對商品資料庫**零筆紀錄**，而 OQ-P8 的擁有者正是它——不回填這一行，那條 OQ 會變成孤兒 ②⚠ **r3 新增：裁決約束⑧ 的讀法。** `:1233` 的原文是「不得以 NetworkVariable 承載**結果**」，而 `:1635` 又收窄成「owner-write NetworkVariable」——**netcode GDD 自己不一致**。**若廣義讀法勝出，`is_spoiled` 是互動結果，商品資料庫關閉 OQ-P9 的整條裁決要重做。** | `product-database.md` 規則 2／OQ-P8／OQ-P9 |
| **technical-director ＋ devops** | **ADR-XXX 建置期資料治理閘門**。⚠ **r3 拆成兩軸，範圍縮小**：r2 寫「15 條 AC 的 BLOCKING 效力取決於它」並整批降為 ADVISORY——但那把 **AC6c 也掃了進去，而 build hook 對一條型別建構測試無事可做**。現在：**軸 1（證據閘，沒有通過的測試就不得標 Done）今天就生效、不降級**；**軸 2（建置期強制）**才取決於本 ADR，且只適用於**資料不變量**（14 條，不含 AC6c） | `product-database.md`「『BLOCKING』的兩軸」 |
| **art-director** | ~~解決 §3.3 vs §8.6 的自相矛盾~~ **已於 2026-09-20 裁決（OQ-P14 關閉）**：兩者是同一顆 icon 的填充層與輪廓層；需求 icon **是**貼圖；原則 2 射程限縮為**有體積的物件**；白描邊改 `Ink_Contour #23282A`（對白牆 1.17:1 → 12.71:1）；`Atlas_Ui` mipmap **關改開**；`sku_nameable_max` 依形狀預算 **8 → 6**。**剩餘待辦**：①把 9 處裁決落回美術聖經②`Ui_IconTier_*` 納入 §8.6 例外清單並依 §8.9 留裁決紀錄③⚠ **升級 arlong 決定射程**：白描邊改 Ink 會波及**所有互動黃物件**（收銀條碼、集點貼紙…），可限縮為「僅頭頂 icon」 | `product-database.md` OQ-P14／Visual-Audio |
| **creative-director** | ①**遊戲內語音是否進 MVP**（准入門檻 1-4 預設有語音，本作沒有）②**受眾範圍**應明示裁決，不該是三個欄位寬度的副作用 | `product-database.md` OQ-P13／OQ-P17 |
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

19 systems: 2 Revised r4 (待原型) / 1 In Review (**r3 修訂完，待實作回填**) / 0 Approved / 16 Not Started
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
