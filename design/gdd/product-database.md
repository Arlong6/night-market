# 商品資料庫 (Product Database)

> **Status**: In Design
> **System**: #6（Core / Foundation / MVP）
> **Author**: arlong + design-system skill
> **Last Updated**: 2026-09-20
> **Design Review (首審)**: NEEDS REVISION 2026-09-20 → 本次修訂已處理全部 blocking
>   （評審紀錄：`design/gdd/reviews/product-database-review-log.md`）
> **Implements Pillar**: 支柱 2「台灣人秒懂」（主）、支柱 1「忙得有節奏」（次）
> **Concept**: `design/gdd/game-concept-night-shift.md`
> **Systems Index**: `design/gdd/systems-index.md`

## Overview

商品資料庫是本作所有「可被玩家操作的品項」的**單一真相源**。每一筆資料描述一樣商品的
身份（它是什麼、屬於哪個機台家族）、它在店裡的取得路徑（從哪裡拿、要不要加工），
以及它被端到客人面前時算不算數。

機台互動組（#5）、客人系統（#7）、評分邏輯（#15）三個系統**都不自帶商品知識**，
一律向這張表查詢：客人的需求是一個商品 ID，機台的產出是一個商品 ID，評分比對的是
兩個 ID 是否相符。這使得「加一樣新商品」是改資料，不是改程式碼——正是編碼標準
「Gameplay values must be data-driven, never hardcoded」在本作的落點。
⚠ **但「單一真相源」的射程是身份與歸屬，不是加工參數**：加工時間、燒焦閾值、
溢出閾值是**逐 SKU 且逐機台形狀不同**的值，依 States and Transitions 的分層論證歸 #5。
新增一筆需要專屬加工邏輯的 SKU，**仍需同步編輯 #5 自己的資料**——本表擋不住那張表漂移。
⚠ **但「不用改程式碼」不等於「不用重出 build」**：SKU 表隨主 build 一起序列化出貨，
新增品項仍必須重新出一次 Web build 才會出現在玩家手上。要做到免出 build 的內容更新，
需要 Addressables 遠端目錄＋一個內容 host，那是獨立於本 GDD 的技術決策（見 Open Questions）。

**範圍刻意畫得很窄**：只有「能被撈起、加熱、刷條碼、補上貨架」的品項進表，
估 20-40 筆。貨架上那幾百個商品排面依美術聖經 §5.1 是單張共用圖集的貼圖，
**不是資料**——它們負責「像超商」，不負責「被玩」。這一刀讓資料庫維持在系統索引
標定的 S 規模。
⚠ **但它不足以保證 44MB 硬標不被品項數吃掉**：規則 2 的「`deprecated` 永不刪除」
是一個**永久、單調成長**的承諾，若條目直接強引用 Mesh／Sprite／AudioClip，
下架品項的美術資產會**永遠留在打包依賴鏈裡**。身份資料與資產引用必須分離，
見規則 2 與 OQ-P10。

而在玩家那一側，這個系統**從頭到尾不會被看見**。玩家感受到的是另一件事：走進店裡，
架上是茶葉蛋、黑輪、米血、飯糰、大熱狗、冰沙——每一樣都是他自己在凌晨三點
買過的東西，而且**不屬於任何一家**（反支柱 `NOT 真實品牌`）。支柱 2「台灣人秒懂」的設計測試（*一個新內容若需要說明書才懂 →
換成大家都親身經歷過的真梗*）實際上就是這張表的**准入門檻**：判準不是「這個商品
有趣嗎」，而是「台灣人看到它需不需要被解釋」。

反支柱在這裡劃了另一條線：本作 **NOT 寫實經營模擬**。表裡不會有進貨成本、利潤率、
庫存損益這類欄位；商品的價值只以它對當下這一單的貢獻衡量，不以金錢衡量。
（商品是否需要帶一個純演出用的售價供結帳畫面顯示，見 Open Questions。）

## Player Fantasy

這是一個**間接型**幻想：玩家永遠不會看見這張表，就像他不會看見自己腦裡那份
「便利商店有賣什麼」的清單。他會知道的是——**這鍋湯他撈過。**

**錨點時刻（多數）**：尖峰。有人喊一聲「**關東煮！**」，你順手撈了就走——
根本沒空看是哪一串，也不需要看。這是一整班裡發生最多次的事。

**錨點時刻（少數，但情緒最高）**：你卡在咖啡機前抽不開身，微波爐在叫，
第三個客人按鈴。你頭也不回，往後喊一聲「**米血！兩串！**」——三秒後有隻手
從你肩膀旁邊伸過來，串好的放進盒子。你沒有回頭確認過那是誰，
也沒有解釋過米血長什麼樣子。**這一局裡沒有一個人需要問「那是什麼」。**

⚠ **兩個場景的比例是刻意的，而且順序不可顛倒讀。** 依規則 3，家族級是多數、
指名是少數。第二個場景情緒更高，但**它不是常態**——下游 #7／#8 不得為了復刻它
而擅自加重指名比例，因為指名的可讀性成本（一筆一張專屬 icon）由本表的
`nameable` 與 Tuning Knobs 的並發上限共同約束。

這張表不是給程式查的，是給**隔著兩排貨架的隊友喊的**。情緒是默契。

**准入門檻（本節唯一的硬產出，可證偽）**：一筆 SKU 必須通過「隔著貨架喊」測試。
前四條稽核**口語頻道**（玩家喊出來的名字），後兩條稽核**視覺頻道**（頭頂 icon）——
r1 評審指出原本只有前四條，等於**稽核了錯誤的頻道**：尖峰時真正的高風險管道是
玩家永遠不會聽到的 icon。

| # | 門檻 | 頻道 | 可自動化 |
|---|---|---|---|
| 1 | **`display_label` ≤ `sku_holler_max_chars`（4 字）** | 口語 | **可**（字數檢查） |
| 2 | 對方不看畫面就知道是什麼 | 口語 | 否 |
| 3 | 不與表內任何其他品項**聽**錯（「米血」vs「米糕」不得同場） | 口語 | 部分（注音距離輔助，最終判準是耳朵） |
| 4 | 台灣人秒懂，**但不屬於任何一家**（反支柱 `NOT 真實品牌`） | 口語 | 否——**且必須走商標查核流程**，見 AC12 |
| 5 | **層級可辨**：家族級與指名級 icon 必須攜帶一個與圖形內容無關、可套用於任意 icon 的**層級標記**（邊框／底板／徽章三擇一） | 視覺 | 可（資產存在性檢查） |
| 6 | **花色不撞**：任兩個 `nameable` icon 的剪影在 **32×32 縮圖測試**下不得混淆 | 視覺 | 否（人工，與門檻 3 對稱） |

門檻 5 只規定**必須存在**一個層級標記；**具體是邊框、底板還是徽章，歸 #11 與美術**。
門檻 6 刻意重用美術聖經 §3.1 已經對客人 archetype 用過的那把尺——
**專案已經有這件儀器了，不要發明第二把。**

⚠ **門檻 4 光靠「意識到」是擋不住的**：撰寫本文件當天，作者把「思樂冰」與「大亨堡」
（皆為 7-ELEVEN 商品名）寫進 Overview，**四條門檻一條都沒攔住**，是 creative-director
用領域知識抓出來的。越是好用、秒懂的詞，越可能就是命中商標的那個詞。
因此 AC12 的審查紀錄**強制**要有「已搜尋此詞的商標登記狀態／已知品牌關聯」一欄。

**邊界**：難度歸動線與時間，不歸解讀。任何讓人停下來想半秒的品項，
都是從尖峰偷走半秒——**那半秒是支柱 1 的**。

**本節不負責**：貨架上幾百個排面的辨識感由美術聖經 §5.1 的共享圖集負責，
不在本表射程；機台的撈／按／刷手感歸 #5 機台互動組；客人的語氣與個性歸 #7 客人系統。

## Detailed Design

### Core Rules

#### 規則 1：一筆 SKU 的欄位集合

| 欄位 | 型別 | 範圍 | 用途 | 誰讀它 |
|---|---|---|---|---|
| `sku_id` | string (snake_case) | 專案內唯一，**永不改名** | 設計期權威識別鍵；GDD、registry、文件互相引用都用它 | 人；不進封包 |
| `network_index` | byte | **1-255**，循序指派，**永不重用**；**0 保留為 `Invalid`** | 封包裡的實際識別碼 | 網路同步層、#4、#5、#7、#15 |
| `display_label` | string | **≤4 漢字**（`sku_holler_max_chars`，服務准入門檻 1）**且** ≤6 漢字（`sku_display_label_max_chars`，服務 #13 排版）——前者較嚴，實務上生效的是 4 | **這就是玩家隔著貨架喊的那個名字**，准入門檻 1-4 對本欄位生效；同時用於開發／QA／#13 結算逐項列表。**不含客人 NPC 的口白台詞**（那是 #7／#14 的內容） | 內容作者、QA、#13、准入審查 |
| `machine_family` | enum，**必須明確指定整數值** `{Invalid=0, Shelf=1, Oden=2, Microwave=3, CoffeeMachine=4}` | 4 個有效值＋1 哨兵 | **三重用途**：#5 查自己的菜單／#7、#8 依站台配重抽樣／#11 查家族級 HUD icon | #5、#7、#8、#11 |
| `nameable` | bool | — | 這筆 SKU 是否可被「指名客」點名。**true 才需要專屬 icon 資產** | #7（抽指名需求）、#11（icon）、內容審查 |

#### 規則 1b：零值即無效——沒有任何預設值可以是合法值

C# 的值型別預設為 0。若 `network_index` 的 0 是第一個合法索引、`machine_family` 的
第一個成員是 `Shelf`，那麼**任何忘記賦值的 bug 都會安靜產出一筆「看起來像 index 0
的新鮮商品」或一個「Family: Shelf 需求」**——不報錯、不 assert、看起來完全正常。

文件別處主張「為機率趨近於零的情境設計是過度設計」。**這一條不適用於此**：
忘記賦值不是趨近於零，**它是最常見的初始化 bug 模式**。因此：

- `network_index` **從 1 開始指派，0 永久保留為 `Invalid`**。
- `machine_family` 的 `Invalid = 0` 是哨兵，**不得指派給任何 SKU**。
- **enum 必須明確指定整數值，且只可附加、不可重排、不可改變既有數值。**
  理由：Unity 對 enum 欄位序列化存的是**底層整數值，不是成員名稱**。重排宣告
  （插入新家族、「順手」依字母排序）會讓既有資產的語意**靜默錯位**——`Oden`
  可能一夜變成 `Microwave`，不編譯錯誤、不拋例外。**規則 2 的「永不重用」保護的是
  手動指派的 `network_index`，完全保護不到這個走不同機制的攻擊面。** 由 AC15 守護。

**刻意不存在的欄位**：成本、售價、利潤、庫存量、取得路徑分類、組合配方、加工時間閾值。
前四項由反支柱 `NOT 寫實經營模擬` 擋掉（含「剩幾個」——庫存是 #5 貨架站台的運作狀態，
不是商品身份）；取得路徑可由 `machine_family` 完全推導，獨立欄位是對同一件事問兩次，
兩個欄位遲早漂移；後兩項歸 #5。

#### 規則 2：兩層 ID，各司其職

- **`sku_id` 是權威身份**。一旦上線永不改名。品項下架時**不刪除，標成 `deprecated`**
  ——比照 `design/registry/entities.yaml` 現行慣例，理由相同：避免殘留引用變成幽靈字串。
- **`network_index` 是線路身份**。新增時取下一個未用過的整數（**從 1 起**）；
  **下架後號碼永久保留、不重新分配**。
- ⚠ **`deprecated` 保留的是「身份資料」，不是「美術資產引用」。** 條目**不得**直接
  強引用 Mesh／Sprite／AudioClip——否則每一筆下架 SKU 的資產都會永遠留在打包依賴鏈裡，
  而「永不刪除」是一個單調成長的承諾。資產以**可斷開的引用鍵**繫結（命名約定或
  Addressables label），下架時由美術流程斷開。見 OQ-P10。

**為什麼線路上不必傳字串**：這張表不需要跨端同步。它隨 build 一起序列化出貨，
而所有人從同一個連結進同一個 build，兩端內容保證一致。RPC 只需要傳「表格第幾格」。
這也順帶回答了「商品資料庫要不要接網路同步層」——**不要**，它是載入期就固定的靜態內容，
不是執行期狀態。

**版本一致性不需要另建防線**：netcode GDD 的 `[P-17]` 版本閘在任何資料交換之前就會擋下
build 不符的 client。因為 SKU 表與遊戲邏輯是同一份 build 出來的，**不存在「build 版本
一致但 SKU 表不一致」的中間態**。本 GDD 只引用既有版本閘，不發明第二套。

#### 規則 3：需求分兩級（家族級為主，指名為輔）

客人的需求有兩種：

- **家族級需求**（**多數，這是常態路徑**）：「一份關東煮」——`machine_family == Oden`
  的任何 SKU 都算對。
  ⚠ **HUD 的家族 icon 目前只有一半存在。** 美術聖經 §3.3 的四個既有 icon
  （碗＝關東煮、杯＝咖啡、條碼＝結帳、箱＝包裹）**不是為 `machine_family` 畫的**
  ——它們是為「服務類型」畫的，只有碗、杯兩個字面上重疊；條碼是每張單共通的結尾動作、
  箱是包裹代收，兩者都不對應任何商品家族。`Microwave` 與 `Shelf` **無對應符號**。
  這不是「補兩個洞」，是四個 icon 的**整套分類基底要重新核對是否仍適用**。見 OQ-P1。
- **指名需求**（少數）：「米血」——必須是那一筆 SKU。**只有 `nameable == true` 的品項
  可以被指名，而每一個都必須配一個專屬 icon 資產。**

指名需求的出現比例是 #7／#8 的旋鈕，不是本表的欄位——但其**並發上限**由本表的
Tuning Knobs 約束（見「同時在場相異需求符號數上限」）。

#### 規則 3b：為什麼是 4 個家族，而概念文件說 5 台機台

`machine_family` 只有 4 個有效值，而 `game-concept-night-shift.md` 的 MVP 明講
「五種互動：關東煮、微波、咖啡機、收銀刷條碼、貨架補貨」。**兩個數字都對，
差異在於收銀不是商品的來源**：刷條碼是**交付／驗證動作**，消耗一個已存在的
`ProductInstance` 並比對訂單，沒有任何商品「從收銀機產出」。
**MVP 5 機台 ＝ 4 個產出家族 ＋ 1 個交付動作。**

`nameable` 有一個刻意的副作用：**它是內容配額的天然剎車**。想讓一樣商品可被指名，
就得畫一個新 icon——成本落在提出需求的人身上，而不是默默膨脹。

#### 規則 4：單一真相源的射程

**必須只在這裡定義**：SKU 身份（兩層 ID）、`machine_family` 歸屬、`ProductInstance`
的欄位形狀、以及「兩個東西算不算相符」的判定純函式。

**明確不歸這裡**：貨架排面視覺（美術聖經 §5.1 共享圖集）／加工手感與計時（#5）／
客人想要什麼、波次怎麼組（#7、#8）／星級怎麼算、耐心怎麼扣（#15）／庫存與過期
（#5 貨架站台）／icon 圖形資產本身（#11，本表只提供查詢鍵）。

### States and Transitions

商品資料庫本身**沒有執行期狀態**——它是載入期就固定的靜態表。本節描述的是兩個狀態空間，
兩者都不是「資料庫的狀態」。

**A：SKU 條目的編輯期生命週期**

| 狀態 | 意義 | 轉移 |
|---|---|---|
| `active` | 可被機台產出、可被需求抽中 | → `deprecated` |
| `deprecated` | 下架。ID 與號碼永久保留，不再被抽中也不再被產出 | **終態**——不得復活成新意義 |

執行期不會改變。存在的唯一理由是規則 2 的「永不重用」。

**B：商品實體的執行期狀態**

玩家手上那一份不是資料庫的一列，是一個兩欄位 struct：

```
ProductInstance { network_index: byte, is_spoiled: bool }
```

| 狀態 | 意義 |
|---|---|
| Fresh（`is_spoiled == false`） | 可以交付，能滿足需求 |
| Spoiled（`is_spoiled == true`） | 不能滿足任何需求（無論商品對不對） |

轉移**只有一個方向，而且不由資料庫執行**：Fresh → Spoiled，由產出它的機台（#5）
在交出成品時蓋章。沒有反向轉移（燒焦的便當不會自己好起來），沒有中間態。

**為什麼加工狀態機不在這裡**：微波是計時持續按、關東煮是撈起瞬間完成、
咖啡機是沖煮等待——三種形狀天差地遠。硬塞同一張通用狀態表只有兩種下場：
表被迫長出「只有某幾筆 SKU 用得到」的欄位（微波專屬燒焦閾值、咖啡專屬溢出閾值），
自己分裂成好幾種形狀；或為了統一做成好／壞二元——那就等於現在這個方案，
只是多一層無用的間接。

更根本的是分層：加工手感是系統索引標的**高風險高迭代**項。若閾值寫在 Foundation 層，
每次手感調校都要回頭改上游。**上游穩定、下游易變，這條不能倒過來。**

**代價（明講）**：沒有「有點焦但還能吃」。這是刻意的——多一個中間態就要回答
「它算不算符合需求、算幾星」，那是 #15 星級公式變複雜的起點，而本作不是精細評分模擬。

**什麼時候會反咬**：Alpha 期若新增一台形狀不同的機器（現烤地瓜、代收包裹），
走另一條路（狀態機在資料庫）會被迫回頭改 Foundation schema；走這條不會——
新機器自帶自己的狀態機，最後一樣蓋一個 `is_spoiled`。

### Interactions with Other Systems

對外只有三個唯讀查詢加兩條純函式，**沒有任何系統寫入資料庫**：

```
IProductCatalog
    Get(network_index)              -> ProductEntry     // 含 deprecated；未指派值拋例外
    GetByMachineFamily(family)      -> IReadOnlyList<ProductEntry>   // active only
    GetOrderable()                  -> IReadOnlyList<ProductEntry>   // active only
    Matches(instance, demand)       -> MatchResult
    AllocateSlot(order, instance)   -> int              // 槽位索引，無可用槽回 -1
```

**契約明講（不得靠 AC 側面推導）**：
- `GetByMachineFamily()` 與 `GetOrderable()` **只回傳 `active` 條目**。
  若不過濾，**下架的商品會被機台繼續產出**，直接打臉規則 2。
- `Get()` **完整回傳 `deprecated` 條目**（它是選拔池的濾網，不是存在性的開關），
  但對**從未指派過的** `network_index`（含 `0 = Invalid`）**拋例外**。
- 兩個查詢的結果在 catalog 建置時**算一次並快取**，回傳同一份 `IReadOnlyList<T>`
  引用——#7／#8 會在尖峰高頻呼叫，現場 LINQ 過濾會在熱路徑產生 GC alloc。

**型別身份（r1 評審要求定案）**：
- `ProductEntry`、`ProductInstance`、`CustomerDemand` **皆為 immutable POCO／struct，
  不繼承 `UnityEngine.Object`**。
- `ProductDefinition : ScriptableObject` **僅是作者期的序列化容器**，
  在 catalog 建置時**一次性轉換**為 POCO 陣列；轉換層歸本系統所有，不歸 #5。
- 因此 `Matches()`／`AllocateSlot()` 完全脫離 `UnityEngine` 命名空間，
  測試不需要處理 SO 的生命週期（否則每個測試方法都得記得 `DestroyImmediate`，
  否則洩漏到下個測試，違反 coding-standards 的 Isolation 要求）。

**Assembly 邊界（否則「不啟動 NGO」只是湊巧沒用到，不是架構保證）**：

| asmdef | 可引用 | 不得引用 |
|---|---|---|
| `NightShift.ProductDatabase` | UnityEngine.CoreModule（為了 ScriptableObject 容器） | **`Unity.Netcode.Runtime`** |
| `NightShift.ProductDatabase.Tests.EditMode` | 上者 | NGO、場景相依組件 |
| `NightShift.MachineInteraction`（#5） | `NightShift.ProductDatabase`、NGO | — |

由 AC14 守護。

| 系統 | 流進 | 流出 | 介面擁有者 |
|---|---|---|---|
| #5 機台互動組 | `GetByMachineFamily()` 決定菜單 | 建立 `ProductInstance`、蓋 `is_spoiled` | DB 擁有查詢與 struct 形狀；#5 擁有執行期實例化與狀態邏輯 |
| #7 客人系統 | `GetOrderable()`、`nameable` | 無 | DB 提供字典；**抽樣權重、偏好、指名比例全歸 #7／#8** |
| #15 評分邏輯 | `Matches()` | 無 | DB 提供單槽判定；**聚合成星等完全歸 #15** |
| #11 HUD 與需求 icon | `machine_family`／`network_index` | 無 | DB 只給查詢鍵，圖形資產歸 #11 與美術 |
| #4 攜帶與交付 | 搬運 `ProductInstance` | 無 | DB 只定義 struct 形狀 |

**關鍵釐清——`ProductInstance` 不是 NetworkObject**：netcode GDD 的
`RequestHandoff(itemId, targetId)` 裡的 `itemId` 與本表的 SKU 身份**是兩個不同的東西**。
交接操作的是一個已經 spawn 的 NetworkObject 實例（**哪一個**），
SKU 是資料表的列（**哪一種**）。

**本表的建議（r1 評審後可先封口，不必等 #5）**：`itemId` 型別應為
**`NetworkObjectId (ulong)`**——依 `docs/engine-reference/unity/modules/multiplayer.md:78-93`，
本專案 ownership transfer 的唯一 API 是 `NetworkObject.ChangeOwnership(ulong)`，
操作對象就是它。`ProductInstance` 的兩個欄位是**該 NetworkObject 上的資料**，
不是另一個可交接的識別鍵；spawn 時設定好，接收端本地查一次即可，不需每次交接重傳。

⚠ **但「誰能寫 `is_spoiled`」仍未定案，見 OQ-P9。** 本表定義這個欄位存在、
定義它餵給 `Matches()`，但**沒有定義它附著在哪個 NetworkObject 上、寫入權限怎麼設**
——這是全文唯一一個「決定評分結果、由別的系統寫入、要跨端傳」卻沒有線路規格的欄位。
Edge Cases 那句「`ProductInstance` 只應由 host-authoritative 的 #5 建立」
**是勸告，不是機制**。

**需求結構（本表定義形狀，內容歸 #7）**：

```
CustomerDemand { kind: {Family|Named}, family: machine_family, network_index: byte }
CustomerOrder  { slots: CustomerDemand[] }
```

「兩串米血」是**兩個都指向米血的槽**，不是一個帶 `qty=2` 的槽。這與本專案
`game-session-state.md` 已進 registry 的 `slots_in_vignette` 模式一致，
並且避開「交了一份還差一份」的部分完成狀態。

**修飾語（「加酸黃瓜」）不做成資料結構**。若某個口味變體真的有玩法效果，
它應該是**一筆獨立的原子 SKU**，且必須自己通過 Player Fantasy 的四條准入門檻；
若只是台詞風味，它只能活在 #7 的口白層，不得進入判定。
另註：「大熱狗一支，加酸黃瓜」這個例子**本身就違反門檻第 1 條**（2-3 音節喊得完）
——若真心想要修飾詞玩法，正確做法是回頭修改 Player Fantasy 的准入標準，
而不是繞過它加在資料結構裡。

## Formulas

本系統有兩條純函式，沒有數值參數、沒有可調權重——所有加權與聚合都在 #15。

`Matches` 判定「一份商品能不能滿足一個需求槽，不能的話是哪一種不能」：

```
Matches(instance, demand) -> MatchResult:
    entry = Get(instance.network_index)        // 兩個分支都先查，未指派值在此拋例外
    if instance.is_spoiled            : return Spoiled
    if demand.kind == Family:
        return entry.machine_family == demand.family ? Match : WrongFamily
    else:                                       // Named
        if instance.network_index == demand.network_index : return Match
        return entry.machine_family == Get(demand.network_index).machine_family
               ? WrongSku : WrongFamily
```

⚠ **`Get()` 必須在兩個分支之前呼叫。** 原版的 Named 分支只比兩個 byte、
**結構性地繞過了 `Get()` 的 fail-fast 防線**：若 `demand.network_index` 是垃圾值
（#7 抽樣 bug），`Matches()` 不報錯、只安靜回 false，那張指名訂單**從此永遠
不可能完成**，而真正的 bug 根源被完全吃掉。Edge Cases 花三段論證「刻意快速失敗」，
這個不對稱是它的漏洞，不是它的例外。

**為什麼回傳 enum 而不是 bool**：不是因為布林會銷毀資訊（不會——#15 手上握著兩個
輸入，加一次 `Get()` 就能自己導出）。理由是**判例一致性**：槽位分配規則因為
「避免 #15 重新發明一套不一致的規則」而留在本表，失敗分類的情況一模一樣，
沒有理由結論相反。

**變數**

| 變數 | 型別 | 範圍 | 說明 |
|---|---|---|---|
| `instance.network_index` | byte | 已登錄且 `active` 的 SKU 之一 | 實際交付的那一份商品的身份 |
| `instance.is_spoiled` | bool | {true, false} | 由產出它的機台（#5）蓋章。**資料庫定義這個欄位存在，但從不寫入它** |
| `demand.kind` | enum | {`Family`, `Named`} | 這個需求槽是家族級還是指名 |
| `demand.family` | enum | 4 值 | `kind == Family` 時有效 |
| `demand.network_index` | byte | 已登錄 SKU 之一 | `kind == Named` 時**有效**；該 SKU 的 `nameable` 必須為 true |
| 回傳 | enum `MatchResult` | {`Match`, `WrongFamily`, `WrongSku`, `Spoiled`} | **只有 `Match` 算滿足**；其餘三值供 #13／#15 做差異化回饋 |

⚠ **`CustomerDemand` 是攤平的 tagged union**：`kind == Family` 時 `network_index`
**必須為 0（`Invalid`）**，`kind == Named` 時 `family` **必須為 `Invalid`**。
`Matches()` 自己只讀該讀的分支所以安全，但**下游任何直接讀裸欄位而忘記先檢查 `kind`
的程式碼**（#11 選 icon 查詢鍵、#8 統計家族配重）會讀到未使用欄位——若不強制哨兵，
那個欄位會剛好長得像合法值 `Shelf`。下游**應透過存取器讀取**，存取器對錯誤分支拋例外。

**輸出範圍**：四值列舉。不夾取、不加權、**無部分分數、無近似匹配**——
「不是 `Match`」就是不滿足，三種失敗原因只影響**回饋呈現**，不影響判定結果。

**為什麼不做近似匹配**：Player Fantasy 的准入門檻第 3 條已經要求 SKU 之間**刻意不可能
混淆**。若判定又對「接近但不對」給部分分數，等於在懲罰邏輯裡引入一個資料庫本身宣稱
不該存在的模糊地帶——自相矛盾。近似匹配只在「品項本身容易混淆」的遊戲裡有意義，
本作明確不是。

「送對大半也該有分」的體驗改由**訂單內槽位命中率**表達（`已命中槽數 / 總槽數`），
不改動單槽判定的嚴格度。該聚合公式歸 #15，不在本文件。

**Worked examples**

| # | instance | demand | 結果 | 理由 |
|---|---|---|---|---|
| 1 | 米血, fresh | Family: `Oden` | **true** | 家族相符 |
| 2 | 黑輪, fresh | Family: `Oden` | **true** | 同家族，家族級需求不分哪一串 |
| 3 | 咖啡, fresh | Family: `Oden` | **false** | 家族不符 |
| 4 | 米血, fresh | Named: 米血 | **true** | 指名命中 |
| 5 | 黑輪, fresh | Named: 米血 | **false** | 同家族仍不算——指名就是指名 |
| 6 | 米血, **spoiled** | Named: 米血 | **false** | 品項對，但壞了 |
| 7 | 米血, **spoiled** | Family: `Oden` | **`Spoiled`** | `is_spoiled` 先短路，家族對也沒用 |

（第 3 列回 `WrongFamily`、第 5 列回 `WrongSku`、第 6/7 列回 `Spoiled`，
其餘回 `Match`。）

第 2 列與第 5 列並列是這條公式的重點：**同一份米血，在家族級需求下可被黑輪替代，
在指名需求下不行。** 這正是「家族級為主、指名為輔」在程式上的全部差異。
而第 3 列與第 5 列的區別（`WrongFamily` vs `WrongSku`）正是玩家需要做**不同修正行為**
的兩種失敗：前者要換一台機器，後者只要換同一鍋裡的另一串。

### 槽位分配規則

`Matches()` 的定義域只到「單槽 vs 單商品」。當一份商品**同時被同一張訂單的多個槽接受**時
（訂單 `[Family:Oden, Named:米血]` 收到一份新鮮米血），公式本身不回答該消耗哪一槽。
補充規則：

```
消耗優先序 = Named 先於 Family
同優先序內 = 取 slots 陣列中索引較小、且尚未填滿的槽
一份商品只消耗一槽
```

**安全性**：r1 評審的 systems-designer 手推 6 組（含 3 槽混合、任意交付順序、
跨家族混合、零槽、全 Named、全 Family 同家族），**未找到死鎖**，並給出交換論證——
Named 槽的匹配條件是「恰好一個 SKU」（稀缺），Family 槽是「同家族任一」（彈性），
**稀缺資源先鎖定**是標準的「先滿足窄需求」交換論證，對這個二層優先結構可證明安全。

**三槽 worked example**（原本只有 2 槽，舉證不足）：

訂單 `[0]=Family:Oden, [1]=Named:米血, [2]=Family:Oden`

| 交付序 | 商品 | 分配到 | 理由 |
|---|---|---|---|
| 1 | 黑輪 (fresh) | 槽 0 | 不符任何 Named 槽，落到索引最小的可用 Family 槽 |
| 2 | 米血 (fresh) | 槽 1 | **Named 優先於 Family**，即使槽 2 也接受它 |
| 3 | 黑輪 (fresh) | 槽 2 | 唯一剩餘可用槽 |

若步驟 2 讓 Family 先吃掉米血，而整個波次只會出一份米血，槽 1 就**永遠等不到**
——訂單變成不可能完成。這就是優先序不可顛倒的原因。

**跨家族混合訂單合法**（例：`[Family:Oden, Named:某咖啡]`）——Named 與 Family
分屬不同商品域，永遠不產生候選槽衝突。

**歸屬**：本規則的**整合**（交付判定點接線、槽位佔用狀態維護）歸 #15／#4；
但**規則本身是全函式、不依賴任何下游資料**，故 `AllocateSlot()` 列入 `IProductCatalog`
並由 **AC13** 在本系統測掉。
⚠ **本文件的測試只覆蓋規則本身，不解除 #15 的整合測試義務。**
#15 的 GDD **必須**包含整合測項並反向引用本節，否則這條規則會變成
「兩邊都以為對方測過」的死角——而本系統的綠燈會**加劇**這個風險，不是消除它。

## Edge Cases

### 雙模式判定

- **若一份商品同時符合訂單裡不只一槽**（訂單 `[Family:Oden, Named:米血]`，交出新鮮米血）：
  **Named 優先於 Family；同優先序內取 `slots` 陣列索引較小且尚未填滿的槽。**
  理由：Named 是稀缺資源、Family 是彈性資源。若 Family 先吃，而整個波次只會出一份米血，
  Named 槽就永遠等不到第二份，訂單變成**不可能完成**；Named 先鎖定則 Family 槽事後
  可被任何黑輪、貢丸補上。**稀缺的先鎖定，才不會浪費彈性資源的替代能力。**
  （本規則同時記於 Formulas 節「槽位分配規則」。）
- **若訂單有兩個 Named 槽指向同一 SKU**（「兩串米血」）：第一份填索引較小的槽，
  第二份填另一槽——**一份商品只消耗一槽**，對應「你只交出一件東西」。

### 內容合法性（擋在建置期，不做 runtime 降級）

⚠ **「擋建置」必須靠一個明寫的機制，否則它只是「測試會紅」。**
Unity **沒有**任何內建機制讓 EditMode 測試綠燈成為 Build 的前置條件，
而 `.claude/docs/coding-standards.md` 白紙黑字寫著 **CI is not set up yet**——
現況下打開 Editor、不跑測試、直接 Build Web，下列四條不變量**全部放行**。

**本文件指定的機制**：每一條下列不變量除了 EditMode 測試之外，
**必須同時實作在 `UnityEditor.Build.IPreprocessBuildWithReport.OnPreprocessBuild`
裡，驗證失敗即 `throw new BuildFailedException(...)`** —— 那是 Unity 唯一能真正
中止 `BuildPipeline` 的鉤子。測試與 build hook 共用同一份驗證邏輯，不得各寫一份。

⚠ **這塊建置期資料治理閘門是跨切面基礎設施，沒有任何系統擁有它**，而本文件四條
不變量全部押在它身上。它應拆成獨立的 ADR ＋工具任務，**不得吸收進「實作商品資料庫」
的估算**——否則會少算「在沒有 CI 的情況下從零架起建置期強制」這一整段。見 OQ-P11。

- **若某 SKU `nameable == true` 但找不到專屬 icon 資產**：**視為內容錯誤，擋建置。**
  icon 資產命名綁定 `sku_id`（`Ui_Icon_[sku_id]`），一條 EditMode 測試掃描所有
  `nameable == true` 條目確認對應資產存在。理由：`nameable` 的設計目的就是當內容配額的
  剎車，**剎車失靈（宣稱可指名卻沒配 icon）比放行更危險**，必須硬擋而非軟降級。
- **若兩筆 `active` SKU 的 `display_label` 相同**（大小寫、全形半形正規化後比對）：擋建置。
  雖然它不參與 `Matches()` 判定，但會出現在 #13 結算畫面的逐項列表上——讓玩家讀到兩個
  一樣的字樣卻對應不同商品，違反准入門檻第 3 條的精神。
- **若某 `machine_family` 底下一筆 `active` SKU 都沒有**：擋建置。那代表對應機台變成
  一個造不出任何東西的空殼站台。須有常駐 EditMode 測試檢查「4 個家族每個都 ≥1 筆 active」。
- **若其他資料表（波次配置、教學腳本）引用了已 `deprecated` 的 `sku_id`**：擋建置。
  這是 deprecation 的**唯一真實風險**——runtime 不可能遇到指向 `deprecated` 的需求，
  因為 #7 只能從 `GetOrderable()`（只回 `active`）抽樣，且 SKU 表隨 build 靜態出貨，
  一個班次全程使用同一份表（重連亦然，重連只重新同步既有執行期狀態）。

### 介面契約（刻意快速失敗，不優雅降級）

- **若 `Get()` 查詢一個 `deprecated` 條目**：**完整回傳該筆資料，不丟例外、不回 null。**
  `Matches()` 內部會呼叫 `Get(...).machine_family`，這個保證確保任何合法輸入都不會讓
  判定邏輯意外拋錯而讓交付流程當機。**deprecated 是選拔池的濾網，不是資料存在性的開關。**
- **若 `Get()` 收到從未被指派過的 `network_index`**（垃圾值或封包損毀）：
  **直接 assert／丟例外，不靜默降級、不回傳假資料。** `ProductInstance` 只應由
  host-authoritative 的 #5 建立；讓它安靜通過只會把 #5 或序列化層的真 bug 藏到更下游、
  更難定位的地方才爆炸。
- **若 `GetByMachineFamily()` 查一個零筆 `active` 的家族**：回傳空陣列，不丟例外。
  DB 的契約是誠實回報「沒有」，不保證「一定有」；呼叫方（#8）有義務在抽樣前檢查非空。

### 資料損毀（安靜、不可回復、會出貨）

- **若有人重排 `MachineFamily` 的 enum 宣告**（插入新家族、依字母排序「順手整理」）：
  既有 SO 資產存的是**底層整數值**，語意會**靜默錯位**——`Oden` 可能變成 `Microwave`，
  不編譯錯誤、不拋例外、直接出貨給玩家。
  **防線**：規則 1b 的「明確整數值＋只可附加不可重排」＋ **AC15 的名稱快照**。
  ⚠ **現有的其他 AC 系統性抓不到它**：AC3（每家族 ≥1 active）在重排後多半仍通過
  （SKU 只是被重分配到四個桶，很少剛好清空一桶）；AC5-AC10 若用假 catalog 測，
  根本沒碰到真實資產裡的整數——**測試碼與被汙染的資料會一起漂移然後互相對上，
  紅燈永遠不會亮。** 這是全套發現裡嚴重度／成本比最高的一條，修法兩行。

### 刻意不處理

- **`network_index` 255 格用完**：不設計 runtime 分支。MVP 20-40 筆、Full Vision
  內容量表（4 店型／10+ 服務／12+ 客人，且互動層 SKU 定義刻意窄縮）保守估計全內容
  生涯遠低於 100 筆，含 `deprecated` 永久燒掉的號碼亦然。真逼近上限的修法是型別換
  `ushort`——一行 wire-format 改動，既有數值原樣放進更大型別，不需資料遷移。
  **為機率趨近於零的情境設計執行期路徑，正是本文件一路在警戒的過度設計。**
- **槽位是否已被填過**：`Matches()` 是無狀態純函式，對同樣輸入永遠給同樣答案。
  槽位佔用狀態歸 #15／#4 自己維護，明確不在 DB 射程。
- **場上現在有幾份某 SKU 存在**（供給稀缺性、多名玩家搶同一份指名商品）：本表完全不追蹤。
  `Matches()` 只判斷「已送到手上的這一份」合不合格，稀缺性與競爭仲裁歸 #4／#5／#7。
- **零槽訂單**：本表只定義容器形狀，不設下限約束；是否允許由 #7 自行決定。
- **交付的商品與訂單裡所有槽都不匹配**：`AllocateSlot()` 回傳 `-1`，
  **本表到此為止**。該商品是被退回、掉在地上、還是計入失誤，歸 #4／#15。
  （此條補齊 r1 評審指出的模式斷裂——本節其餘每一項刻意不處理的情境都有明列，
  唯獨這一項原本連「不處理」都沒說。）

## Dependencies

### 上游（本系統依賴誰）

**無。** 商品資料庫是 Foundation 層、零上游依賴——這正是它能排在第二個設計的唯一理由。
它**不接網路同步層**（規則 2：靜態表不跨端同步）、不接遊戲時鐘、不接任何執行期系統。

唯一的非執行期耦合有兩處：美術資產（icon／模型／音效）依 `sku_id` 命名綁定；
以及 netcode GDD 的 `[P-17]` 版本閘——**引用，不重建**。

### 下游（誰依賴本系統）

| 系統 | 強度 | 介面 | 系統索引已宣告 |
|---|---|---|---|
| #5 機台互動組 | **硬**——沒有它機台不知道自己能產出什麼 | `GetByMachineFamily()`、建立 `ProductInstance` | 是 |
| #7 客人系統 | **硬**——沒有它客人不知道能要什麼 | `GetOrderable()`、`nameable` | 是 |
| #15 評分邏輯 | **硬**——沒有它無法判定對錯 | `Matches()` | 是 |
| #4 攜帶與交付 | **硬**——它搬運的就是 `ProductInstance` | struct 形狀 | **否** |
| #11 HUD 與需求 icon | **硬**——icon 查詢鍵來自本表 | `machine_family`／`network_index` | **否** |
| #13 結算畫面 | **軟**——逐項列表用 `display_label`；缺它仍可顯示星等 | `display_label` | **否** |
| #8 波次導演 | **軟**——依站台配重抽樣；退化成均勻抽樣仍可運作 | `GetByMachineFamily()` | **否**（推得，非明文） |

### 雙向一致性檢查

四條未宣告：#4、#11、#13、#8。

**這不是索引寫錯。** 這四條依賴在「商品資料庫要提供什麼」定案之前無法預見——
#4 要搬什麼、#11 要畫什麼 icon、#13 要列什麼字，全都是本 GDD 才定下來的。
其中 **#11 HUD 這條最值得注意**：它之所以浮出來，是因為「家族級＋指名」的裁決把
icon 選擇邏輯綁進了商品表；在那之前 HUD 確實只需要認識客人系統。
**這是一個裁決長出一條新依賴的例子，不是原本就漏掉的。**

**系統索引的依賴圖已於 2026-09-19 更新完畢**（`systems-index.md` 第 23／27／30／32 行
的 Depends On 欄已列出商品資料庫）。

## Tuning Knobs

本系統幾乎沒有旋鈕。所有數值都在 #5／#7／#8／#15，本節**不複製別人的旋鈕**，只指向真相源。

### 本系統擁有的旋鈕

本表唯一可調的東西就是**它自己的內容**。內容即旋鈕：

| 旋鈕 | 型別 | 安全範圍 | 調太高會怎樣 | 調太低會怎樣 |
|---|---|---|---|---|
| SKU 總筆數 | int | 20-40（MVP） | 尖峰可讀性下降、美術資產線性增加；理論上限 255（`network_index` 型別） | 低於約 12 筆時四個家族撐不出變化，波次重複感明顯 |
| 每家族 `active` 筆數 | int | **≥1（硬性）** | 同家族內差異模糊，家族級需求失去意義 | **0 = 建置失敗**，該機台變空殼站台 |
| `nameable == true` 的筆數 | int | 待定案（見 Open Questions） | **每一筆都必須配一張專屬 icon**，直接換算成美術工時 | 為 0 時「指名客」這個客人類型不存在，退化成純家族級 |
| `display_label` 長度（喊聲） | int | **≤4 漢字**（`sku_holler_max_chars`） | 違反准入門檻 1「2-3 音節喊得完」 | — |
| `display_label` 長度（排版） | int | ≤6 漢字（`sku_display_label_max_chars`） | #13 結算畫面逐項列表排版溢出 | — |
| **同時在場相異需求符號數上限** | int | 待定案（見 OQ-P3） | 尖峰時玩家無法在 0.5 秒內辨識頭頂 icon，違反支柱 1 與支柱 2 | 為 0 不可能（至少要有家族符號） |

`nameable` 筆數的上限**不在本表定案**：它由美術（幾張 icon 畫得完）與 #7（指名客佔比
多少才有趣）共同決定，本表只負責**讓這個成本可見**。

⚠ **「同時在場相異需求符號數上限」為什麼必須放在這張表**：可讀性的崩潰是一個
**相乘項**——`同時在場的指名需求數` × `nameable 池的花色數`。即使指名比例很低，
只要池子夠大，尖峰同時在場的相異符號種類依然可能失控（比例控制的是**頻率**，
不是**花色數**）。而 **#7 只看得到並發、#11 只看得到池子，只有本表同時看得到兩個因子。**
這與 `nameable` 欄位是同一個模式：本表不決定值，本表讓成本可見。

**作業慣例（`nameable` 的預設值）**：新建 SKU 條目時 `nameable` 一律預設 `false`，
**只有在專屬 icon 資產進 repo 的同一個 commit 才翻成 `true`**。
這條慣例的作用是讓 AC4 的建置檢查不會在資產尚未畫完的早期誤報——
早期條目本來就該是 `false`。一旦有人宣稱可指名卻沒配 icon，紅燈立刻出現，
**那正是設計要的行為**。刻意**不**為此新增第三種「草稿中」狀態，
以免讓規則 2 的兩態模型長出未經定義的轉移分支。

⚠ **「SKU 總筆數 20-40」這個範圍是估的，不是推導出來的。** 真正能決定它的是
「一個家族內要有幾種東西，玩家才會覺得有變化但不會混亂」——那是 #7 與 #8 設計時
才量得出來的。此處寫成旋鈕而非定論，就是為了留這個口。

### 不屬於本系統、但受本表約束的旋鈕

| 旋鈕 | 真相源 | 本表的約束 |
|---|---|---|
| 指名需求出現比例 | #7 客人系統／#8 波次導演 | 只能從 `nameable == true` 的池子抽 |
| 各站台需求配重 | #8 波次導演 | 只能用 `machine_family` 的 4 值分類 |
| 加工時間、燒焦閾值、溢出閾值 | #5 機台互動組 | 本表不持有任何時間常數 |
| 星級門檻、耐心扣減 | #15 評分邏輯 | 本表只提供 `Matches()` 的布林輸出 |
| 每張訂單槽數 | #7 客人系統 | 本表只定義 `slots` 是陣列，不設上下限 |

## Visual/Audio Requirements

本系統不產生任何畫面或聲音。它產生的是**一份資產清單與一組命名約束**——每筆 SKU 上線時
必須有對應資產存在，命名由 `sku_id` 綁定（Edge Cases 的建置期檢查即靠此綁定運作）。

| 資產 | 顆粒度 | 規格來源 | 命名 |
|---|---|---|---|
| 手持模型 | 每筆 SKU | 美術聖經 §8.2（**級距未定，見 Open Questions**）、§8.4 Simple Lit、§5.1 互動層**禁貼圖** | `Mesh_[sku_id]` |
| 家族需求 icon | **每個 `machine_family` 一個，非每筆 SKU** | §3.3：單色剪影 64×64、白描邊、透明背景，進共享 `Atlas_Ui`，不用文字 ＋ **層級標記（見下）** | `Ui_Icon_[family]` |
| 指名需求 icon | **僅 `nameable == true` 者** | 同上，**且須通過 32×32 縮圖測試不與其他指名 icon 混淆**（准入門檻 6） | `Ui_Icon_[sku_id]` |
| 取得音效 | 依機台家族共用，非每筆 SKU | 歸 #14 音效系統 | — |

**本表施加的美術約束**：互動層**禁貼圖**（美術聖經原則 2；§5.1 射程限縮後仍適用於互動層）。
商品的辨識度必須由**形狀與色塊**承擔，不能靠包裝圖案——這與准入門檻第 2 條
「對方不看畫面就知道是什麼」互為表裡：**若一樣商品非得看到包裝印刷才認得出來，
它本來就不該進表。** 背景層排面不在本表射程（§5.1 共享圖集）。

#### 層級標記（准入門檻 5 的資產面）

家族級與指名級 icon **原本共用完全相同的視覺規格**（同尺寸、同單色剪影、同圖集、
同擺位），沒有任何邊框／底色／徽章／大小差異——**玩家無從在 0.5 秒內分辨
「這顆代表家族任意」與「這顆代表只有這個」**，而兩者的判定規則完全不同。
這是一條**隱藏規則**：說明書被換成了「你得先打過這局才學到教訓」，違反支柱 2。

對照：同一份美術聖經 §3.1 對「隊友 vs 客人」下了硬功夫（32×32 縮圖測試、剪影公式、
「穩 vs 晃」動態分流器）。**對客人身份的視覺分流下了規格，對需求層級的分流原本一片空白。**

**本表的要求**：兩級 icon 必須攜帶一個**與圖形內容無關、可套用於任意 icon 的層級標記**。
**具體是邊框、底板還是徽章，歸 #11 與美術決定；「必須存在」歸本表。**

⚠ **形狀語言預算目前是空的。** §4.3 的「2 種特權色相」鎖的是狀態色（互動黃／警示紅），
指名 icon 是單色剪影不靠色相分身份，所以**不違反色彩配額**——而這更糟：
**配額規則不管用了，卻沒有任何規則接手，而形狀比色相稀缺得多。** `nameable` 這個剎車
只擋美術工時，**不擋可讀性**：十張都畫出來、AC4 全過，然後玩家在尖峰看不懂——
**一個會通過所有自動化測試、卻在人手上失敗的系統。** 由准入門檻 6、AC12 的圖形查重、
以及 Tuning Knobs 的並發上限共同約束。

**已知缺口**：家族需求 icon **缺兩個**（`Microwave`、`Shelf`），且既有四個的分類基底
與 `machine_family` 不同源。見 OQ-P1。

📌 **Asset Spec** — Visual/Audio 需求已定義。美術聖經核准後，執行
`/asset-spec system:product-database` 產出逐資產的視覺描述、尺寸與生成提示。

## UI Requirements

**本系統沒有自己的 UI 畫面，但它對 UI 下約束。** r1 評審指出原本那句
「本系統沒有自己的 UI」把一個**資訊架構決策**（規則 3 在客人頭頂這個既有視覺頻道裡
開了第二條語意軸）偽裝成資料決策後推給下游。切分對**圖形資產**成立，對**顆粒度**不成立。

**本表欠的不是像素，是對像素的約束**——就像它已經對手持模型下了「互動層禁貼圖」、
對 `display_label` 下了字數上限。那些約束寫在准入門檻 5／6 與 Visual/Audio 節。

它另外對兩個 UI 系統各貢獻一個欄位：

| 消費者 | 本表提供 | UI 決策歸誰 |
|---|---|---|
| #11 HUD 與需求 icon | 家族級用 `machine_family`、指名級用 `network_index` 當 icon 查詢鍵 | #11＋美術：icon 圖形、頭頂擺位、**尖峰時多 icon 並存的排版與可讀性** |
| #13 結算畫面 | `display_label`（≤6 漢字） | #13：逐項列表的排版、排序、是否顯示 |

`display_label` **是玩家喊的名字，但不是客人 NPC 說的台詞**——後者屬於 #7／#14 的
口白內容，本表不定義它。

📌 **UX Flag — 商品資料庫**：本表的 icon 查詢鍵會長成 #11 HUD 的畫面元素。
Phase 4（Pre-Production）應為 #11 執行 `/ux-design`，故事應引用 `design/ux/[screen].md`，
而非直接引用本 GDD。

## Acceptance Criteria

層級標記沿用 netcode GDD 慣例：**MVP-必達**＝本 GDD 已明講「必須硬擋／0＝建置失敗」的
不變量；**MVP**＝核心必備但無「硬擋」措辭。證據型別依 `.claude/docs/coding-standards.md`。
測試落點：`Assets/Tests/EditMode/ProductDatabase/[Feature]Tests.cs`，
方法名 `Test_[Scenario]_[Expected]`。

⚠ **「BLOCKING」的實際效力**：標 BLOCKING 的條目，其驗證邏輯**必須同時**存在於
EditMode 測試與 `IPreprocessBuildWithReport.OnPreprocessBuild`（見 Edge Cases）。
只有測試而沒有 build hook 時，「BLOCKING」只約束測試套件是否綠燈，
**不約束任何人能不能按下 Build**。

| # | 準則 | 層級 | 證據 |
|---|---|---|---|
| AC1 | **身份永久性**。GIVEN `design/registry/sku-shipped-snapshot.txt` 裡的既有 `(sku_id, network_index, machine_family 名稱)` 快照，WHEN 現行 SKU 表載入，THEN 快照每一列原封不動存在（未改名、號碼未被他人重用、家族歸屬未變），且現行表內無兩列共用同一 `network_index`。**快照只准新增列** | **MVP-必達** | Logic／自動化 `Test_SkuRegistry_MatchesSnapshot`（BLOCKING） |
| AC2a | **喊聲長度**。GIVEN 每一筆 `active` SKU，WHEN 以 `StringInfo.LengthInTextElements` 計數，THEN `display_label` ≤ `sku_holler_max_chars`（4） | **MVP-必達** | Logic／自動化（BLOCKING） |
| AC2b | **標籤唯一**。GIVEN `active` SKU 集合，WHEN 正規化（大小寫、全半形）後比對，THEN 無兩筆 `display_label` 重複 | **MVP-必達** | Logic／自動化（BLOCKING） |
| AC3 | **無空殼站台**。GIVEN 現行 SKU 表，WHEN 依 `machine_family` 分組統計 `active`，THEN 4 個有效家族每一個 ≥1 筆；且**無任何 SKU 的 `machine_family` 為 `Invalid`** | **MVP-必達** | Logic／自動化（BLOCKING） |
| AC4 | **`nameable` 必有 icon**。GIVEN 每一筆 `nameable == true` 的 `active` SKU，WHEN 掃描 `Assets/Art/UI/Icons/`（比對規則：存在名為 `Ui_Icon_[sku_id]` 的 Sprite 資產且其 import 後尺寸為 64×64），THEN 資產存在 | **MVP-必達** | Logic／自動化（BLOCKING）——早期誤報由 `nameable` 預設 false 的作業慣例避免，**不放寬本測試** |
| AC5 | **`Matches()` 家族模式**。GIVEN fresh instance，WHEN `demand.kind == Family`，THEN 家族相符回 `Match`、不符回 `WrongFamily` | MVP | Logic／自動化（BLOCKING） |
| AC6 | **`Matches()` 指名模式**。GIVEN fresh instance，WHEN `demand.kind == Named`，THEN 完全相符回 `Match`；**同家族不同 SKU 回 `WrongSku`；不同家族回 `WrongFamily`** | MVP | Logic／自動化（BLOCKING） |
| AC7 | **`is_spoiled` 短路**。GIVEN `is_spoiled == true`，WHEN 對任一 `demand`（即使本應相符），THEN 一律回 `Spoiled` | MVP | Logic／自動化（BLOCKING） |
| AC8 | **`Get()` 查 deprecated**。GIVEN `deprecated` 條目的 `network_index`，WHEN 呼叫 `Get()`，THEN 完整回傳，不丟例外、不回 null | MVP | Logic／自動化（BLOCKING） |
| AC9 | **`Get()` 查無效值**。GIVEN 從未指派過的 `network_index`（含 `0 = Invalid`），WHEN 呼叫 `Get()`，THEN **拋出 C# 例外**（`ArgumentOutOfRangeException` 或等價型別）。⚠ **不得以 `Debug.Assert` 實作**——它掛 `[Conditional("UNITY_ASSERTIONS")]`，在 Release Web build 整段編譯掉，退化成靜默通過，正是本條要防的事 | MVP | Logic／自動化（BLOCKING）；測試矩陣須涵蓋 Release define 組合 |
| AC10 | **空家族查詢**。GIVEN 零筆 `active` 的家族，WHEN 呼叫 `GetByMachineFamily()`，THEN 回傳空陣列，不丟例外 | MVP | Logic／自動化（BLOCKING） |
| AC11a | **查詢對筆數無感（合成資料）**。GIVEN 一份只追加一筆條目、未修改任何生產 `.cs` 的合成資料集，WHEN 重跑四個查詢，THEN 新條目被正確辨識、行為與原筆數一致 | MVP | Logic／自動化（BLOCKING） |
| AC11b | **真實管線不需改碼**。GIVEN 在正式 SKU 資產追加一筆 `active` 條目的 PR，THEN diff 中不含任何非測試 `.cs` 變更。⚠ AC11a 用合成 fixture，**證明的是查詢演算法資料驅動，不是真實 ScriptableObject 管線**——若管線背後維護一份自動產生的 enum 或 switch-case，AC11a 完全抓不到 | MVP | 流程／CI PR 規則（非 EditMode 測試） |
| AC12 | **准入審查（六條門檻）**。GIVEN 一筆新提案 SKU，WHEN **至少 2 人獨立**依六條門檻逐項審查，THEN 產出審查紀錄存於 `production/qa/evidence/product-database/sku-admission/[sku_id].md`（範本 `_template.md`），**強制欄位包含**：①每條通過／不通過＋理由 ②**已搜尋此詞的商標登記狀態／已知品牌關聯** ③指名 SKU 須附 icon 草圖並記錄 32×32 縮圖測試結果。意見不一致時升級 game-designer 裁決。六條全通過才可標 `active` | MVP | **內容審查紀錄（Design Review），非程式碼可驗證**（ADVISORY，但為上線前硬性步驟） |
| AC13 | **槽位分配**。GIVEN 一份商品同時符合訂單的 Named 與 Family 槽，WHEN 呼叫 `AllocateSlot()`，THEN 回傳 Named 槽索引；覆蓋案例：兩個 Named 指向同一 SKU、三槽混合、跨家族混合、無可用槽回 `-1` | MVP | Logic／自動化（BLOCKING）。⚠ **只覆蓋規則本身，不解除 #15 的整合測試義務** |
| AC14 | **資料層純度**。GIVEN 一個不繼承 `UnityEngine.Object`、建構子直接注入 POCO 陣列的 `IProductCatalog` 實作，WHEN 在 EditMode 測試組件建構並呼叫 `Matches()`／`AllocateSlot()`／`Get()`，THEN 不需要 `[UnitySetUp]`、不載入場景、不呼叫 `Resources.Load`／`AssetDatabase`；且 `NightShift.ProductDatabase.asmdef` **不引用 `Unity.Netcode.Runtime`** | **MVP-必達**（下游三個硬依賴系統 testability 的前提） | Logic／自動化＋asmdef 靜態檢查（BLOCKING） |
| AC15 | **enum 未被重排**。GIVEN AC1 快照裡記錄的 `(sku_id → machine_family 名稱)` 對應，WHEN 讀取現行資產的 `machine_family` **整數值並解析回名稱**，THEN 與快照一致 | **MVP-必達** | Logic／自動化（BLOCKING）——這是唯一抓得到 enum 重排靜默錯位的測試 |
| AC16 | **查詢只回 active**。GIVEN 某家族底下同時有 `active` 與 `deprecated` 條目，WHEN 呼叫 `GetByMachineFamily()`／`GetOrderable()`，THEN 回傳集合**不含任何 `deprecated` 條目** | **MVP-必達** | Logic／自動化（BLOCKING） |
| AC17 | **建置閘門真的擋得住**。GIVEN 一份違反 AC1／AC2a／AC2b／AC3／AC4／AC15 任一條的資料集，WHEN 執行 `BuildPipeline.BuildPlayer`（含 Editor 手動 Build），THEN build **失敗**並回報違反的條目 | **MVP-必達** | Logic／自動化（BLOCKING）——`IPreprocessBuildWithReport` ＋ `BuildFailedException` |

### 測試夾具規格

- **AC4 資產掃描**：根目錄 `Assets/Art/UI/Icons/`；比對規則見 AC4 本文。
- **AC11a 合成資料集**：以 `FakeProductCatalog : IProductCatalog` 實作，建構子直接吃
  `ProductEntry[]`，**不碰 `AssetDatabase`、不建立 ScriptableObject**。
- **AC1／AC15 快照**：`design/registry/sku-shipped-snapshot.txt`。
  **它是資料治理 artefact，不是測試夾具**——放 `design/registry/` 而非 `Tests/`
  （後者重構時容易被清掉）；測試只讀取比對，不擁有它。
  **Bootstrap 規則**：第一次有 SKU 進 `active` 並合併進 main 的 PR，
  **必須同時建立本快照檔**，內容等於當下的 `active` ＋ `deprecated` 全集；
  該次 PR 視為建立基準線，不視為「新增列」審查對象。
  ⚠ **在快照建立之前，AC1／AC15 對空集合恆真通過**——這是已知且已承認的狀態，
  不是「已經稽核過」。

### 六條准入門檻的可自動化程度（誠實標示）

| 條 | 頻道 | 可自動化？ |
|---|---|---|
| 1. ≤4 漢字喊得完 | 口語 | **可**——AC2a（`StringInfo.LengthInTextElements`） |
| 2. 不看畫面就知道是什麼 | 口語 | **不可**——聽覺辨識＋常識判斷 |
| 3. 不與表內品項**聽**錯 | 口語 | **部分**——注音／拼音編輯距離掃出疑似衝突供人工複核。⚠ 腳本量測的是「安靜狀態讀字串像不像」，實際情境是**吵雜環境用語音喊**，兩者不是同一個問題；且新增 SKU 須對全表重跑 |
| 4. 秒懂但不屬於任何一家 | 口語 | **不可**——但 AC12 強制商標查核欄位，把直覺轉成流程 |
| 5. 層級可辨 | 視覺 | **可**（資產存在性）——AC4 的延伸 |
| 6. 花色不撞（32×32） | 視覺 | **不可**——人工，與門檻 3 對稱 |

⚠ **文字有查重（AC2b），圖形的查重是人工（AC12 第③欄）。** 文字是玩家「讀」的管道，
icon 是尖峰時「瞄」的管道——**高風險的那一半沒有自動化守門人**，只能靠審查紀錄。

### 延後（宿主系統尚未存在）

- **`deprecated` 的 `sku_id` 被其他資料表引用 → 擋建置**：掃描對象（波次配置、
  教學腳本）隨 #7／#8 落稿後才存在。不變量已寫在 Edge Cases，測試待宿主出現後補。

（原本列在此處的「槽位分配規則」已移除——r1 評審指出它是**全函式、不依賴任何下游資料**，
「宿主不存在所以測不了」對它為假。現為 **AC13**。⚠ 把一個假理由與一個真理由並列在
同一組 bullet 裡，是真缺口被鄰近的正當理由洗白的典型路徑，此處已拆開。）

### 刻意不設 AC

- **規則 4「單一真相源的射程」**：架構治理原則，不是可由 QA 獨立驗證的行為。
  可留痕的形式是靜態掃描（三個核心型別全 codebase 只能有一份定義），
  但目前無下游程式碼，現在寫也是恆真通過。待 #5 落地後補。
- **Overview 的「不用重出 build」澄清**：界定承諾邊界，不是承諾一個行為。
  為它寫 AC 等於「測一個不存在功能的缺席」。
- **初版 20-40 筆 SKU 內容的產出排程**：r1 評審提出，但 **GDD 不是排程**。
  這屬 systems-index／sprint plan，不屬本文件。⚠ 但 AC1-AC4、AC11a、AC15 全部
  預設「現行 SKU 表已有內容」——在內容進 repo 之前，它們停在「規格已定義、無資料可測」。

## Open Questions

| # | 問題 | 來源 | 擁有者 | 擋不擋進度 |
|---|---|---|---|---|
| OQ-P1 | **需求 icon 的分類基底要重新核對，不只是補兩個洞**。美術聖經 §3.3 的四個既有 icon（碗／杯／條碼／箱）**不是為 `machine_family` 畫的**——它們是為「服務類型」畫的，只有碗、杯字面重疊；條碼是每張單共通的結尾動作、箱是包裹代收。`Microwave`／`Shelf` 無對應符號。另需定義准入門檻 5 的層級標記具體形式（邊框／底板／徽章） | r1 評審（ux-designer＋game-designer） | art-director ＋ #11 | 不擋本文件；**擋 #11 HUD 與 #7 客人系統**——#7 在不知道 icon 詞彙容量之前無法校準指名比例 |
| OQ-P2 | **手持商品的 poly 級距未定**：§8.2 只有「機台類互動道具 ≤400 tris」與「貨架/環境模組 ≤150 tris」兩列，**沒有「手持商品」這一列**，兩者差 2.7 倍 | unity-specialist 體積估算 | art-director | 不擋；**擋美術資產開工** |
| OQ-P3 | **兩個相乘的上限未定**：`nameable` 筆數上限（美術工時）× 同時在場相異需求符號數上限（可讀性）。⚠ **只有本表同時看得到兩個因子**——#7 只看得到並發、#11 只看得到池子 | 本 GDD Tuning Knobs ＋ r1 評審 | art-director ＋ #7 ＋ #11 | 不擋 |
| OQ-P4 | **SKU 總筆數 20-40 是估的，不是推導的**：真正的判準是「一個家族內幾種東西才有變化又不混亂」 | 本 GDD | #7 ＋ #8 設計時回填 | 不擋 |
| OQ-P5 | **是否需要純演出用售價欄位**。⚠ 若答案是「要」，必須同時寫下「它為何不違反反支柱 `NOT 寫實經營模擬`」的論證，否則會被後人誤判為開了先例 | 本 GDD ＋ r1 評審 | game-designer | 不擋；若加是純附加欄位 |
| OQ-P6 | **是否支援「不重出 build 就能加新商品」**：需 Addressables 遠端目錄＋內容 host，而 itch.io 靜態 host 不是為此設計的 | unity-specialist | **technical-director** | 不擋；**獨立技術決策，不該由本 GDD 默認** |
| OQ-P7 | ~~`RequestHandoff(itemId)` 的語義~~ **已於 r1 評審後半封口**：依 `modules/multiplayer.md:78-93`，ownership transfer 唯一 API 是 `NetworkObject.ChangeOwnership(ulong)`，`itemId` 應為 **`NetworkObjectId (ulong)`**。剩餘待辦：#5 設計時與 netcode GDD 正式對齊措辭 | unity-specialist ＋ network-programmer | #5 | 不擋 |
| **OQ-P8** | **`[P-17]` 版本閘擋不擋得住「純內容變更」，目前無實據**。`netcode-session.md:163` 只寫 approval payload 承載 build／protocol version，**全文未定義 token 的產生規則**；唯一實測證據是 `:171` 的 `payload=w1-proto-v1`（字面量字串，命名為 proto）。若它只在 wire format 改變時手動遞增，**純內容補丁不會讓它改變，P-17 會放行**——而那正是 Overview 點名的場景。修法二選一：(a) 在 netcode GDD 把 token 定義成涵蓋內容的粒度（例如 build hash）；(b) 本表自建一層 SKU 表雜湊檢查 | r1 評審（network-programmer），主審已 grep 複核 | **technical-director ＋ netcode GDD** | 不擋本文件；**本表已停止把它當成既有保證** |
| **OQ-P9** | **`is_spoiled` 的信任邊界無處安放**。全文唯一一個「決定評分結果、由別系統寫入、要跨端傳」卻沒有線路規格的欄位：它附著在哪個 NetworkObject 上？是不是 `NetworkVariable`（若是，寫入權限該設 `Server`）？「只應由 host-authoritative 的 #5 建立」是勸告不是機制。⚠ 合作非對抗遊戲，作弊風險趨近於零；**真正的代價是規格空洞——#4 與 #5 會各自發明一個答案，然後兩個不一樣** | r1 評審（network-programmer） | #5 ＋ network-programmer | 不擋；**與 OQ-P7 並列為「會造成返工」** |
| **OQ-P10** | **`deprecated` 條目的美術資產引用如何斷開**。規則 2 的「永不刪除」是單調成長的承諾；若直接強引用 Mesh／Sprite／AudioClip，下架品項的資產會永遠留在打包依賴鏈裡。本表已規定「以可斷開的引用鍵繫結」，但**斷開由誰在什麼時機執行未定** | r1 評審（unity-specialist） | art-director ＋ technical-director | 不擋；**直接關係 44MB 硬標** |
| **OQ-P11** | **建置期資料治理閘門該拆成獨立 ADR ＋工具任務**。`IPreprocessBuildWithReport` 對 CI 紀律的選擇、asmdef 邊界落實、非 Editor 環境下 catalog 如何發現 SO 資產（`AssetDatabase.FindAssets` 是 Editor-only、`Resources.Load` 被團隊慣例禁止，故必然需要一步 build-time 收集，而這步放哪個 pipeline 階段未定）。⚠ **這是沒有任何系統擁有的跨切面基礎設施，而本表四條不變量全押在它身上**——不得吸收進「實作商品資料庫」的估算 | r1 評審（unity-specialist＋creative-director） | **technical-director ＋ devops-engineer** | 不擋本文件；**擋 AC17 的可實作性** |
| **OQ-P12** | **`ProductInstance` 過線是整包序列化還是拆欄位傳送，是否需要 `INetworkSerializable`**。`modules/multiplayer.md` 171 行完全沒有序列化章節；NGO 2.13.2 對兩欄位 unmanaged struct 的要求屬 Unity 6.3 的 HIGH risk 未驗證區 | r1 評審（network-programmer） | #5 ＋ unity-specialist | 不擋；宜比照 W1 做一次實測查證 |

⚠ **會造成返工的有兩條**：**OQ-P7**（已半封口，剩措辭對齊）與 **OQ-P9**（未封口）。
其餘十條都是「還沒決定」。
