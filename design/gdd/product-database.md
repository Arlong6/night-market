# 商品資料庫 (Product Database)

> **Status**: In Design
> **System**: #6（Core / Foundation / MVP）
> **Author**: arlong + design-system skill
> **Last Updated**: 2026-09-20（r3 修訂）
> **Design Review**: 首審 NEEDS REVISION；r2 複審（新 session、9 位專家）NEEDS REVISION；
>   **r3 複審（新 session、11 位專家＋交叉引用＋終審）NEEDS REVISION** 2026-09-20
>   → 本次為 r3 修訂（評審紀錄：`design/gdd/reviews/product-database-review-log.md`）
> ⚠ **本欄只記錄「作者宣稱已處理」，不記錄「已解決」。** r1 的 log 由修訂者自己
>   簽發「全部 blocking 已處理」，而 r2 查出六個根因裡有兩個未修、三個只修表面
>   ——**修法越淺，自簽的 log 越綠**。「已解決」只能由獨立的再評審寫入。
> 🛑 **r3 終審裁定：本輪為本文件最後一輪散文式評審。**
>   理由：本輪嚴重度／成本比前 10 名裡有 **9 條落在 r2 那一輪自己寫下的文字上**，
>   而 30 條 AC 裡今天真能跑的只有 1 條。**這份文件的缺陷產生率，現在是修訂速率的
>   函數，不是「還沒修完」的函數。** 下一步是建那四個 C# 型別與其測試
>   （純 C#，不需要 Unity），用實作結果**回填**本檔——**刪除被推翻的斷言，不新增**。
> ✅ **原型已建並已跑**：`prototypes/product-database-core/`（Unity 6.3 內附 Mono，`./run.sh`）。
>   **實作測試 44 PASS / 0 FAIL；文件探針 5 TRIP。Design Test 撞到 3／5 → 終審裁決成立。**
>   三條被執行推翻的 r2 字面：AC6c 的「無法被表示」、AC11a 的家族量詞、`AllocateSlot` 缺資格述詞。
>   **原型沒有要求新增任何斷言**——它確認 r3 的修正是必要且充分的。
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
估 20-40 筆。貨架上那幾百個商品排面依美術聖經 §5.1（分層）與 §5.2（硬數字：單張
`Atlas_World_Facings`、2048×2048、256 格）是共用圖集的貼圖，
**不是資料**——它們負責「像超商」，不負責「被玩」。這一刀讓資料庫維持在系統索引
標定的 S 規模。
⚠ **但它不足以保證 44MB 硬標不被品項數吃掉**：規則 2 的「`deprecated` 永不刪除」
是一個**永久、單調成長**的承諾，若下架條目仍持有美術資產引用，那些資產會
**留在打包依賴鏈裡**。身份資料與資產引用因此必須**可分離**——但分離的手段是
「下架時把引用清成 null」，不是「一開始就不要引用」（r2 評審裁決，見規則 2 與 OQ-P10）。

⚠ **這個威脅的量級要講清楚，否則會為它付出過高的代價**：依美術聖經 §8.2
（互動道具 ≤400 tris）與 §8.6（icon 64×64 進共享圖集），一筆下架 SKU 的殘留
是數十 KB 量級；**100 筆 `deprecated` 約為個位數 MB，對照約 35MB 的內容預算**。
它是資產衛生問題，不是預算危機。本文件因此選擇**成本最低**的解法（規則 2 的
清 null），而不是為它引入 Addressables。

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
指名是少數。第二個場景情緒更高，但**它不是常態**。
⚠ **但本表約束不了那個比例，先前的措辭是錯的**（r2 評審，game-designer）：
`nameable` 管的是**哪些** SKU 可被指名，不是**多常**出現指名需求；並發上限管的是
**同時在場的花色數**，也不是頻率。十筆 `nameable` 之下，#7 完全可以合法地讓
100% 的需求都是指名，而不違反本表任何一條規則。
**指名需求出現比例是一條本表沒有擁有者的旋鈕**——它歸 #7／#8，而本表能做的
只有把它levy 出去：見 Tuning Knobs「不屬於本系統、但受本表約束的旋鈕」新增的一列。

⚠ **准入門檻 1-4 保護的是一條本作目前不提供的頻道。** 它們預設隊友之間有語音
（門檻 3 的自述是「吵雜環境用語音喊」），但 `design/` 全樹沒有任何遊戲內語音或
文字溝通系統，`systems-index.md` 也沒有這一項；概念文件第 220 行的「會開 Discord
開黑的程度」是**客群描述，不是出貨功能**。而支柱 4「貼連結就開玩」意味著大量場次
是沒有共用語音頻道的陌生人。
**因此門檻 1-4 是對內容作者的約束，不是對產品的保證；產品實際保證的是門檻 5-6。**
「遊戲內語音是否進 MVP，或改由 #11 提供一個非語音的『我要這個』ping」是
**creative-director 的裁決**，不在本表射程（見 OQ-P13）。

這張表不是給程式查的，是給**隔著兩排貨架的隊友喊的**。情緒是默契。

**准入門檻（本節唯一的硬產出，可證偽）**：門檻 1-4 稽核**口語頻道**（玩家喊出來的名字），
門檻 5-6 稽核**視覺頻道**（頭頂 icon），門檻 7 稽核**語意**（這一筆到底憑什麼進表）。
r1 評審指出原本只有前四條，等於**稽核了錯誤的頻道**：尖峰時真正的高風險管道是
玩家永遠不會聽到的 icon。

⚠ **r3 評審指出，補上視覺頻道之後這張表仍然漏掉了多數路徑**：門檻 **1、3、5、6**
的量詞域**全都是同一個集合**——`nameable`（上限 6、且依規則 3 是少數路徑），
連同 AC4、AC18、AC20 亦然。而規則 3 明訂家族級才是常態路徑，家族填充型 SKU 依
「門檻的適用分級」只需通過門檻 2、4，**兩條都不可自動化**。
**守門預算與風險呈單調反向**，而這正是 r1 指出的同一個缺陷升了一層。
門檻 7 是對此的修補，見下。

| # | 門檻 | 頻道 | 可自動化 |
|---|---|---|---|
| 1 | **`display_label` ≤ `sku_holler_max_chars`（4 字）** | 口語 | **可**（字數檢查） |
| 2 | 對方不看畫面就知道是什麼 | 口語 | 否 |
| 3 | 不與表內任何其他品項**聽**錯（「米血」vs「米糕」不得同場） | 口語 | 部分（注音距離輔助，最終判準是耳朵） |
| 4 | 台灣人秒懂，**但不屬於任何一家**（反支柱 `NOT 真實品牌`） | 口語 | 否——**且必須走商標查核流程**，見 AC12 |
| 5 | **層級可辨**：每一顆需求 icon 必須合成**恰好一張**層級標記覆蓋資產（`Ui_IconTier_Family` 或 `Ui_IconTier_Named`） | 視覺 | **可**（兩張覆蓋資產的存在性 ＋ 合成數 == 1，由 **AC18** 守護） |
| 6 | **花色不撞**：**任一需求 icon**（指名 icon **與四顆家族級 icon**）的剪影，在**回填尺寸**下不得與**頭頂符號總表**中任一項混淆 | 視覺 | 部分（機器前篩＋里程碑人測，見「門檻 6 的母體、尺寸與重跑義務」） |
| 7 | **同家族可互換**：本 SKU 是否可在家族級需求下**替代同家族的每一筆其他 SKU**？若否，它不得進本表，或該家族必須拆分 | 語意 | 否（人工；但它是**常態路徑上唯一一條守門人**，見下） |

#### 門檻 5 的形式（2026-09-20 arlong 裁決）

**採用獨立合成覆蓋資產**，不採剪影填充權重。理由：(a) 它讓「可自動化」這句話
**變成真的**——AC18 有一個可斷言的對象；(b) 它在 §4.3 的「紅蓋黃＋閃爍」狀態
覆寫下仍然存活，而填充權重在約 30px 閃爍的暗相可能整個消失。

⚠ **原本寫的「邊框／底板／徽章三擇一，歸 #11 與美術」是一個空集合**（r2 評審，
ux-designer；主審逐條覆核美術聖經）。三個選項全部已被分配：

| 選項 | 已被誰占用 | 出處 |
|---|---|---|
| 邊框／描邊 | 互動黃**一律**加白描邊（無障礙需求，非裝飾）；且細線框是 §3.3 明文排除的 UI 語系 | §4.5、§3.3 |
| 底板 | 隊友名牌背板（Unlit 細線框），**同樣在頭頂區域** | §8.8、§3.3 |
| 徽章 | 圓／星／三角／菱已分配給隊友四色的色＋形雙編碼 | §4.5 |

**本表因此改為授予「負空間清單」——不論最後圖形怎麼畫都成立的約束：**

> 層級標記**不得**使用 (a) 任何色相編碼（§4.3 的 2 色配額已滿，且色相已被
> 「紅蓋黃」狀態軸占用）；(b) 外框／描邊（與 §4.5 的強制白描邊不可區分）；
> (c) 背板（與 §8.8 隊友名牌、§3.3 UI 語系撞語系）；(d) 圓／星／三角／菱。
> 並且**必須通過狀態覆寫判準**（見 Edge Cases「狀態覆寫下的層級可辨」）。

**具體圖形歸 #11 與美術；「必須存在、不得用什麼、必須通過什麼判準」歸本表。**

#### 門檻 6 的母體、尺寸與重跑義務

**母體不是「任兩個 `nameable` icon」**——玩家真正會混淆的是**同一塊頭頂區域、
同一視距下的所有符號**：家族 icon、其他 `nameable` icon、隊友四形狀徽章（§4.5）、
超時驚嘆號（§4.5）、完成打勾印章（§4.5）。指名對指名反而是**最不可能**混淆的一組，
因為兩者穿同一套層級標記。
⚠ **母體一直是對的，錯的是量詞域**（r3 評審，accessibility-specialist ＋ ux-designer）：
本段把家族 icon 寫進母體，但門檻 6 原本只對「任一 `nameable` icon」生效，於是四顆
**常態路徑**上的家族 icon 只是被拿來比對的**對象**，自己從不受測。已於門檻表改為
「任一需求 icon」。

⚠ **「32×32」是暫代值，不是本專案已經擁有的儀器。** 美術聖經 §3.1 那把尺是在
**封閉的 5 元集合**上、且主體另有**第二條動態頻道**（「穩 vs 晃」）的前提下校準的；
靜態 icon 兩者皆無，而且沒有人量測過頭頂 icon 在第一人稱窄走道、90 百分位客人
距離下的實際螢幕像素尺寸。**回填觸發：#11 的第一版場景量測完成時。**

⚠ **`Atlas_Ui` 的 mipmap 設定與本門檻衝突**：§5.6 表把 `Atlas_Ui` 的 mipmap 設為
「關」，理由寫的是「螢幕空間」——但 §8.8 明寫頭頂 icon 是 **World Space Canvas
＋ Billboard**，有遠近。關 mipmap 會讓 64×64 縮到約 30px 時閃爍，於是門檻 6 測的是
**玩家永遠看不到的乾淨降取樣**。見 OQ-P14。
⚠ **而這一半是無障礙問題，不是畫質問題**（r3 評審，accessibility-specialist）：
無 mipmap 的降取樣**最先犧牲的是最細的高頻結構**，而那正是 §4.5 的**強制白描邊**——
§4.5 明標它是**藍黃軸色盲的補償**，不是裝飾。且開 mipmap 會改變圖集尺寸，
依 §5.6 那是 44MB 硬標下的**預算決策**，不是一個 import 勾選項。登記給 art-director。

**測試協定分兩層**（r3 評審裁決）。r2 只寫了人測那一層，而它在 solo 專案裡**不可執行**：
「未看過此 icon 集」的觀察者是**一次性消耗品**，10 次美術迭代需要 30 位素人——
而本文件自己在 AC12 砍掉第二審查者時用的正是「本專案是 solo，『至少 2 人』不可執行」
這條理由。**判準一致性。**

| 層 | 誰執行 | 何時 | 效力 |
|---|---|---|---|
| **① 機器前篩** | 降取樣至回填尺寸 → 二值化 → 兩兩比對（IoU 或 Hu moments），超過閾值的配對才送人工 | **每一次**新增或改稿 | advisory 預篩。與門檻 3 的注音距離腳本**同位階、同理由** |
| **② 人測** | 3 位未看過此 icon 集的觀察者，在回填尺寸下曝光 1 秒，強迫選擇說出品名，**全數正確**才算通過；其中**至少 1 位色覺異常**者 | **里程碑級批次**，不是逐筆 | 門檻 6 的實際 pass/fail。分歧升級 game-designer 裁決 |

這同時關掉兩個問題：人測成本從 O(迭代次數) 降到 O(里程碑數)，而偵測涵蓋率反而**上升**
（前篩每次都跑）。⚠ **色覺異常觀察者只加在第 ② 層**——加在逐筆協定上等於不會發生。

**重跑義務與門檻 3 對稱且更強**：新增 SKU 須對頭頂符號總表重跑；**既有 icon 改稿
亦須重跑**（美術迭代是新衝突最可能的來源），且重跑須針對**最終匯入資產**，不是草圖。
⚠ **而「改稿了沒有」需要一個機器看得見的觸發器**，否則重跑義務沒有載體：
審查紀錄（AC12）必須記錄**當時受測資產的內容雜湊與當時的 `display_label` 值**，
與現行不符即視為審查已失效。見 AC12 的新鮮度欄位。

#### 門檻 7：同家族可互換（r3 新增——常態路徑上唯一一條守門人）

> **本 SKU 是否可在家族級需求下替代同家族的每一筆其他 SKU？
> 若否，它不得進本表，或該家族必須拆分。**

**為什麼需要它**：`Matches()` 在 `kind == Family` 時回傳 `entry.machine_family ==
demand.family`——也就是它把 `machine_family` 當成「**客人可接受的等價類**」。
但 `machine_family` 的定義是「**這東西從哪台機器出來**」。**這兩件事沒有任何規則
保證相等**，而依規則 3 它們在多數路徑上被當成相等。

反例（今天就寫得出來）：微波家族同時放進「便當」與「肉包」。`Family: Microwave`
的需求對兩者都回 `Match`，但沒有任何客人會覺得「我要微波的東西」是一個需求。
Worked example 第 2 列（黑輪替代米血）之所以成立，靠的**不是**兩者同家族，
而是兩者在玩家心裡確實可互換——**那個前提從來沒有被寫成規則。**

⚠ **本表不採「把 `machine_family` 重新定義成客人可接受等價類」的修法**（r3 評審裁決）：
該欄位目前已扛五種用途（#5 菜單、#7／#8 配重、#11 icon 鍵、供給拓撲、等價類）
而規則 1 只宣告三種。**往一個已經超載的鍵上再加一種語意是錯的方向。**
本表只承載**商品家族**；站台身份與配重鍵歸 #5／#8（見規則 4）。

**適用範圍**：門檻 7 對**每一筆** SKU 生效，含家族填充型——它是那一類唯一多出來的
門檻，而那一類原本只需通過兩條都不可自動化的門檻。

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
| `display_label` | string | **上限依 `nameable` 分兩級**（r3 修正）：`nameable == true` → ≤4 漢字（`sku_holler_max_chars`，服務准入門檻 1）；`nameable == false` → ≤6 漢字（`sku_display_label_max_chars`，服務 #13 排版）。**兩級皆下界 1** | 指名型：**這就是玩家隔著貨架喊的那個名字**，門檻 1-4 對本欄位生效。家族填充型：**永遠不是玩家喊的需求**，只出現在 #13 結算逐項列表。**兩者皆不含客人 NPC 的口白台詞**（那是 #7／#14 的內容） | 內容作者、QA、#13、准入審查 |
| `machine_family` | enum，**必須明確指定整數值** `{Invalid=0, Shelf=1, Oden=2, Microwave=3, CoffeeMachine=4}` | 4 個有效值＋1 哨兵 | **三重用途**：#5 查自己的菜單／#7、#8 依站台配重抽樣／#11 查家族級 HUD icon | #5、#7、#8、#11 |
| `nameable` | bool | — | 這筆 SKU 是否可被「指名客」點名。**true 才需要專屬 icon 資產** | #7（抽指名需求）、#11（icon）、內容審查 |
| `status` | enum，**必須明確指定整數值** `{Invalid=0, Active=1, Deprecated=2}` | 2 個有效值＋1 哨兵 | 選拔池濾網。`GetByMachineFamily()`／`GetOrderable()` 只回 `Active`；`Get()` 兩者都回 | 本表兩個查詢、AC3／AC4／AC16 |
| `mesh_ref` | 直接資產引用（Mesh） | `Active` 時**必須非 null**；`Deprecated` 時**必須為 null** | 手持模型。**r2 裁決：允許強引用**（見規則 2） | #4／#5 |
| `icon_ref` | 直接資產引用（Sprite） | `nameable` 時必須非 null；否則必須為 null | 指名需求 icon | #11 |

⚠ **`status` 原本不在這張表裡**（r2 評審，systems-designer）——但規則 2、States 表 A、
兩個查詢、AC3／AC4／AC16 與三條 Edge Case 全部依賴它。一個標題寫著「一筆 SKU 的
欄位集合」的章節漏掉一個承重欄位，是單一真相源本身的缺陷。

**為什麼 `nameable` 不是 `icon_ref != null` 的重複**（先回答一個一定會被問的問題）：
`nameable` 是**意圖**，`icon_ref` 是**兌現**，兩者是不同的事實。你要的正是讓兩者之間
的落差變成一盞紅燈（AC4），而不是一個沒被表達的願望。這與規則 1 否決「取得路徑」
欄位的理由**不同類**——那個是對同一件事問兩次，這個是兩件事。
**不要依「獨立欄位是對同一件事問兩次」的原則把 `nameable` 刪掉。**

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
  手動指派的 `network_index`，完全保護不到這個走不同機制的攻擊面。**
  ⚠ **這一行本身就是主防線，AC15 只是後備偵測器**（r2 評審修正框架）：一旦整數值
  被顯式寫死，重排「宣告順序」在機制上**不可能**改變任何既有數值。AC15 防的是
  更罕見、更蓄意的行為——有人**編輯既有數值**或**刪除後重用號碼**。
  **絕不可以因為「AC15 已經覆蓋」而把顯式整數值順手簡化掉，那是完全反過來的。**
- **本規則適用於文件中每一個值型別欄位，不只上面兩個。** 完整清查：

| 欄位／型別 | 零值 | 哨兵？ | 守護 |
|---|---|---|---|
| `network_index` (byte) | 0 | ✓ `Invalid` | **AC1b**（資料側，r2 新增）＋ AC9（消費側） |
| `machine_family` (enum) | `Invalid=0` | ✓ | AC3、AC15a／b |
| `status` (enum) | `Invalid=0` | ✓（r2 新增） | AC1b |
| `CustomerDemand.kind` (enum) | `Invalid=0` | ✓（r2 新增：`{Invalid=0, Family=1, Named=2}`） | AC6c |
| `MatchResult` (enum) | `Unevaluated=0` | ✓（r2 新增——原本 `Match=0`，**零值即通過值**，直接違反本規則標題） | 型別定義本身 |
| `is_spoiled` (bool) | `false` = Fresh | ✗ bool 無哨兵位 | **不改型別**。⚠ **r3 修正：這一格原本寫著它被「server-write ＋ spawn 後不可變」守住了，而那是空的**——`server-write` 約束的是**誰**可以寫與**什麼時候**可以寫，**完全不約束「有沒有人寫過」**。實際守護 ＝ **`ProductInstance` 只能經由同時要求 `network_index` 與 `is_spoiled` 兩個參數的工廠建立**（見 Interactions），使「忘記蓋章」變成編譯錯誤而非執行期預設值 |
| `nameable` (bool) | `false` | ✗ | 失效方向安全（僅退化成不可指名）＋ 作業慣例 |

  ⚠ **兩個 bool 的失效方向相反，這一點必須講明**：`nameable` 預設 `false` 是
  **fail-safe**（頂多少一個指名品項）；`is_spoiled` 預設 `false` 是 **fail-unsafe**
  （沒蓋到章的燒焦便當以完美評分送達）。前者靠預設值就夠，後者不行——它的解法
  不是加第三個 enum 值（那會在網路路徑上多一個拋出點，方向錯誤），而是讓
  「未設定」在構造上不可達。

#### 規則 1c：序列化欄位名稱一經上線永不更名

Unity 依**欄位名稱**比對序列化資料。把 `nameable` 更名為 `isNameable`，會讓**每一筆
既有資產的該欄位靜默回到型別預設值**（`bool` → `false`、`byte` → `0`）——不編譯錯誤、
不拋例外、不出 import warning，然後出貨。

這與規則 1b 防的是**完全相同的拓撲，只是換一條管道**。落在 `nameable` 上的後果尤其
惡劣：全表歸零之後，「指名客」從出貨版靜默消失，而 **AC4 不但不會紅，還會更容易
通過**（零筆 `nameable` ＝ 零項 icon 要求）——**髒資料與測試套件再一次一起漂移。**

- **序列化欄位名稱永不更名。** 若非改不可，**必須**加
  `[UnityEngine.Serialization.FormerlySerializedAs("舊名")]` 並保留至少一個發行週期。
- **序列化欄位的型別亦不得變更**（含 `byte` → `ushort`），除非實測確認資料存活。
  ⚠ **本條與「刻意不處理」的 255 格條目直接互斥**（r3 評審，五方獨立發現）：那裡寫
  「一行改動、**不需資料遷移**」。**以本條為準**——那是一句未實測的斷言，且它漏算了
  wire format 改動必須連帶遞增 `[P-17]` 的版本 token（而該 token 的粒度目前未定義，
  見 OQ-P8）。該條目的**決策**（不為 255 格設 runtime 分支）不變，只是成本不是零。
- C# 欄位名一旦第一次 commit 即為永久 wire 契約的一部分：本表的 GDD 欄位名為
  snake_case，對應的 C# 序列化欄位名依 `.claude/docs/technical-preferences.md`
  為 `_camelCase`（`sku_id` → `_skuId`），**此對應表在第一筆資產存在前就必須定案**。

**刻意不存在的欄位**：成本、售價、利潤、庫存量、取得路徑分類、組合配方、加工時間閾值。
前四項由反支柱 `NOT 寫實經營模擬` 擋掉（含「剩幾個」——庫存是 #5 貨架站台的運作狀態，
不是商品身份）；取得路徑可由 `machine_family` 完全推導，獨立欄位是對同一件事問兩次，
兩個欄位遲早漂移；後兩項歸 #5。

#### 規則 2：兩層 ID，各司其職

- **`sku_id` 是權威身份**。一旦上線永不改名。品項下架時**不刪除，標成 `deprecated`**
  ——比照 `design/registry/entities.yaml` 現行慣例，理由相同：避免殘留引用變成幽靈字串。
- **`network_index` 是線路身份**。新增時取下一個未用過的整數（**從 1 起**）；
  **下架後號碼永久保留、不重新分配**。
- ⚠ **`deprecated` 保留的是「身份資料」，不是「美術資產引用」。**
  **2026-09-20 arlong 裁決（r2，反轉 r1 修訂的寫法）**：條目**可以**直接強引用
  Mesh／Sprite——那是 Unity 最可靠、有編譯期與建置期驗證的繫結方式。規則改為：
  > **`status` 轉為 `Deprecated` 時，必須把 `mesh_ref`／`icon_ref` 清成 `null`。**

  **為什麼反轉**：Unity player build 的資產納入條件只有四條——場景可達的序列化引用、
  `Resources/`、Addressables／AssetBundle、`StreamingAssets`。**字串命名查找不在其中。**
  所以 r1 寫的「命名約定」不是一個比較弱的選項，而是一個**不存在**的選項：只靠命名
  綁定的 mesh 根本不會進 build，而唯一能讓它在 runtime 被載入的補救是開一個
  `Resources/` 資料夾——那會**無條件**打包裡面每一個資產（含所有下架品項），
  比它想避免的強引用**嚴格更糟**。於是 r1 的規則實際上退化成 Addressables-only，
  而那會讓本文件三句話同時為假：Dependencies 的「零上游依賴」、
  States 的「載入期就固定的靜態表」（Addressables 是 async）、
  以及建置閘門的覆蓋（Addressables 內容建置不觸發 `IPreprocessBuildWithReport`）。
  清 null 的寫法保住全部三句，而且**可以在同一個 build hook 裡檢查**（AC19），
  資產也在清 null 的那一刻掉出依賴鏈。見 OQ-P10。

**為什麼線路上不必傳字串**：這張表不需要跨端同步。它隨 build 一起序列化出貨，
RPC 只需要傳「表格第幾格」。這也順帶回答了「商品資料庫要不要接網路同步層」
——**不要**，它是載入期就固定的靜態內容，不是執行期狀態。

⚠ **兩端內容一致由 `[P-17]` 版本閘保證，不由「同一個連結」保證。** r1 修訂寫的
「所有人從同一個連結進同一個 build，兩端內容保證一致」**是錯的**，而且被本專案自己的
netcode GDD 明文推翻：`netcode-session.md:163`「**Web 遊戲有瀏覽器快取，「舊 build
的分頁加入新 Host」是必然會發生的情境**」，AC54（MVP-必達）就是為這個情境寫的。
連結標定的是 URL，不是 bit-image。

**版本一致性的實際狀態（不要讀成保證）**：
> **若且唯若** `[P-17]` 的版本 token 粒度**涵蓋純內容變更**，本表才不需要另建防線。
> **該粒度目前未定義**——`netcode-session.md` 全文只寫「approval payload 同時承載
> build／protocol version」，從未定義 token 如何產生，唯一實據是 `:171` 的字面量
> `payload=w1-proto-v1`（命名為 proto）。**在它被定義之前，本表對兩端 SKU 表一致性
> 不作保證**，見 OQ-P8。

⚠ **這個洞的失敗模式不是靜默 desync，是 client 拋例外**（r2 評審，network-programmer）：
純內容補丁新增 `network_index` 41-45，token 沒動，舊 client 加入，收到 43，
呼叫 `Get(43)` → 依 Edge Cases 的 fail-fast 契約**拋例外**。**這比 OQ-P8 原本描述的
更糟，而且兩邊 GDD 都沒有任何 AC 覆蓋它。**

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
IProductCatalog                       // 只有查詢。r3 修正：純函式已移出
    Get(network_index)              -> ProductEntry     // 含 deprecated；未指派值拋例外
    GetByMachineFamily(family)      -> IReadOnlyList<ProductEntry>   // active only，快取
    GetOrderable()                  -> IReadOnlyList<ProductEntry>   // active only，快取
    GetNameable()                   -> IReadOnlyList<ProductEntry>   // active && nameable，快取

    // 需求工廠：吃 catalog，因為它們的契約需要查表才驗得動（r3）
    FamilyDemand(MachineFamily f)   -> CustomerDemand   // f == Invalid 時拋例外
    NamedDemand(byte networkIndex)  -> CustomerDemand   // 0、未指派、Deprecated、
                                                        // 或 nameable == false 時拋例外

static ProductMatching                // r3 新增：純函式不進 catalog 介面
    Matches(catalog, instance, demand)              -> MatchResult
    AllocateSlot(catalog, slots, filled, instance)  -> int   // 無候選槽回 -1

    // catalog 是「資料來源」參數，不是「邏輯來源」——假 catalog 只供給資料，
    // 判定邏輯永遠是這一份。這正是移出介面所買到的東西。

static ProductInstance.Create(byte networkIndex, bool isSpoiled) -> ProductInstance
                                      // r3：唯一建構路徑，兩個參數皆必填
```

**`Matches()` 與 `AllocateSlot()` 為什麼必須移出 `IProductCatalog`**（r3 評審裁決，
qa-lead 對 systems-designer 的正面衝突，qa-lead 勝）：
留在介面上時，測試夾具 `FakeProductCatalog : IProductCatalog` **必須自己重新實作它們**
——於是 AC11a 的迴歸向量、AC5／AC6／AC13 全部跑在**假貨的判定邏輯**上，真實作可以
完全錯誤而測試全綠。systems-designer 判它「是介面成員，OK」是**型別檢查層**的判定；
qa-lead 判它「做出來會假綠」是**測試有效性層**的判定，而後者更靠近後果。
**「假綠」是這份文件三輪來最一致的失敗類型，這裡有一次免費關掉它的機會。**

**`CustomerDemand` 的工廠為什麼要吃 catalog**（r3 評審，systems-designer F5）：
r2 的 `CustomerDemand.Named(byte)` 是**靜態的**，但它宣稱要拒絕「未指派／`Deprecated`／
`nameable == false`」——**這三件事只有查表才知道**。一個算不出自己契約的簽章，
與 r2 上一輪才剛修掉的 `AllocateSlot(order, instance)` 是**完全相同的形狀**。

**`GetNameable()` 為什麼必須在介面上**（r2 新增）：#7 每次抽指名需求都要這個池子，
而本節下面才剛寫「現場 LINQ 過濾會在熱路徑產生 GC alloc」——把指名池留給呼叫方
自己從 `GetOrderable()` 濾，正是本表禁止的那件事。空池回空陣列、不丟例外，
呼叫方有義務在抽樣前檢查非空（與 `GetByMachineFamily()` 同一契約）。

**`CustomerDemand` 改為非公開建構子＋兩個 catalog 工廠**（r2 新增，r3 修正射程）：
攤平的 tagged union 不能靠「下游**應**透過存取器讀取」這種勸告維持——本文件自己
在別處判定「是勸告，不是機制」。工廠強制設定未使用欄位為哨兵，並在建構當下拒絕
`family == Invalid`、`network_index == 0`、指向 `Deprecated` 條目、以及指向
`nameable == false` 的 SKU。由 **AC6c** 守護。

⚠ **但宣稱必須降一級：「讓非法狀態無法被表示」對 `struct` 為假**（r3 評審，
qa-lead ＋ systems-designer ＋ game-designer 三方獨立命中）。C# 的 `default(T)`、
`new T()`、`new T[3]` **永遠是公開建構路徑**，而規則 1b 的哨兵表自己就承認
`CustomerDemand.kind` 的零值是 `Invalid` ——**等於文件同時主張「default 不可達」
與「default 落在哨兵上」。** 裁決：**維持 struct**（本節下方的無 GC alloc 論證成立，
而 class 在同一條判準上更差——`new CustomerDemand[3]` 會給三個 null），
✅ **已由原型執行確認**（`prototypes/product-database-core/`，探針 `AC6c-R2CLAIM`／`-b`）：
`default(CustomerDemand).Kind == Invalid`，`new CustomerDemand[3]` 給出三個非法實例。
把宣稱改成「**無法被意外地表示**」，並依賴規則 1b 既有的哨兵設計讓 `default`
在 `Matches()` 的輸入域驗證處拋例外。

⚠ **連帶解除一條互斥**：r2 的 AC6b（把非法 demand 餵進 `Matches()`）與 AC6c
（那種 demand 建構不出來）**兩條都是 MVP-必達、而且互相排斥**，QA 只能回報
「無法驗證」。降級宣稱之後，AC6b 用 `default(CustomerDemand)` 與**經工廠產出後
才被下架的 SKU**兩條路徑即可構造，不需要任何 `InternalsVisibleTo` 後門。

**`ProductInstance` 亦只有一條建構路徑**（r3 新增，見 `is_spoiled` 的信任邊界）：
`ProductInstance.Create(networkIndex, isSpoiled)`，兩個參數皆必填。
由 **AC23** 守護。

**`AllocateSlot` 的簽章改了**（r2 修正）：原簽章 `AllocateSlot(order, instance)`
**算不出自己的規則**——規則寫「取索引較小、**且尚未填滿**的槽」，而 `CustomerOrder`
沒有佔用狀態，本文件又明訂「槽位佔用狀態歸 #15／#4」。於是三槽 worked example
從 API 不可達，AC13 不可測。改為由呼叫方傳入 `filled`，函式維持全函式與無狀態，
分層不變。連帶修正：下方「本規則是**全函式、不依賴任何下游資料**」應讀為
**不依賴下游的任何「資料表」；它依賴呼叫方傳入的佔用狀態**。

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
**`NetworkObjectId (ulong)`**。
⚠ **論據修正（r2）**：r1 寫的「ownership transfer 的唯一 API 是
`NetworkObject.ChangeOwnership(ulong)`，操作對象就是它」**指錯了參數**——那個 `ulong`
是**目標 clientId**，不是 NetworkObjectId，從所引的 `multiplayer.md:85` 自己就看得出來
（early-return 路徑之一是「目標不在 `Observers` 裡」，而 `Observers` 是 clientId 集合）。
在 `RequestHandoff(itemId, targetId)` 裡，變成那個 `ulong` 的是 **`targetId`**。
**結論仍然成立**（`itemId` 是 Host 用來查物件的鍵，ulong NetworkObjectId 是對的），
但理由要換成：Host 端唯一能定位一個已 spawn 物件的鍵就是它。
**附帶要求**：`NetworkObjectId` 在 despawn／respawn 之間不穩定，而結帳會在交接窗口
（實測約 100ms）內消耗掉 `ProductInstance`。**Host 必須驗證 `itemId` 仍在
`SpawnedObjects` 中，查無即回一個明確失敗，不得靜默 no-op。**

#### `is_spoiled` 的信任邊界（2026-09-20 裁決，**OQ-P9 條件性關閉**）

r1 把這一條留成 OQ 並評為「不擋」。**r2 推翻該評級**：決定它的規則已經在這個 repo 裡，
寫下來是零設計成本，而窗口隨 #5 開工關閉。

> **`is_spoiled` 與 `network_index` 皆為 server-write，**
> **且必須在該 `ProductInstance` 的 NetworkObject 呼叫 `Spawn()` 之前寫入，**
> **`Spawn()` 之後不可變。**

⚠ **中間那一行是 r3 新增的，而它是這整條裁決唯一讓它成立的條件**（r3 評審，
network-programmer；終審評為本輪最被低估的一條）。r2 只寫了「spawn 之後不可變」，
**完全沒有規定何時寫入**。照字面實作會寫成 `Spawn(); netVar.Value = ...`，那就變成
tick-gated delta：本專案 `network_tick_rate = 10Hz`（netcode 約束⑧）→ 單邊 +100ms，
而實測交接本身就是 100-104ms（netcode `[P-20]`(b)②）。接收端在那個窗口讀到
`network_index == 0` → 撞規則 1b 的 `Invalid` 哨兵 → `Get(0)` 依 AC9 **無條件拋例外**，
**而且是在 NGO 的訊息迴圈裡拋**。
**本地單機與 host-only 測試在這個 bug 上 100% 綠**——它是全套發現裡唯一一條
「你會跑的每一種測試都看不見、只在真實網路上致命」的。由 **AC22** 守護。

兩半都由本專案**已經做過的決定**蘊含：Core Rule #1 的 host authority；
netcode GDD 的**約束⑧**（互動請求／回應一律走 RPC，**不得以 NetworkVariable 承載結果**），
該約束已於 2026-09-16 由 W1 雙行程實測從效能顧慮**升級為正確性要求**
（越權寫入會讓伺服器**中止解析該訊息其餘部分**，同一物件上其他無關的 NetworkVariable
**一起掉**；tick=10、delay 40ms 下 3/3 全失）；以及 States §B 已隱含的單向、由機台
在交出成品時蓋章。

⚠ **引文修正（r3，network-programmer）**：r2 把約束⑧ 引成「不得以 NetworkVariable
承載 **owner-write**」——原文（`netcode-session.md:1233`）**沒有 owner-write 三個字**，
寫的是「不得以 NetworkVariable 承載**結果**」。而 netcode GDD 自己 `:1635` 又收窄成
「攜帶物的狀態不得放在 owner-write NetworkVariable」。**那是 netcode GDD 的內部不一致，
本表先前挑了對自己方便的那一邊且沒有揭露。**
**若廣義讀法（承載「結果」）勝出，`is_spoiled` 是互動結果，本整條裁決要重做**——
這是 OQ-P9 只能**條件性**關閉的理由，也是本表對 netcode GDD 的第 7 條前向義務。

**這一句話同時關掉三件事**：(a) 不需要權限模型——不可變的 server-set 值沒有寫入競爭；
(b) 不需要處理 ownership 變更與寫入的時序；(c) 讓規則 1b 那個「bool 沒有哨兵位」的
缺口在**構造上**不可達，因此**不需要**把 `is_spoiled` 改成三值 enum。
⚠ **拒絕三值 enum 的理由換掉了**（r3 修正）：r2 寫的「那會在網路路徑上多一個拋出點」
**不成立**——`NetworkVariable<SpoilState>` 與 `NetworkVariable<bool>` 在 NGO 是同一類
東西，而所謂的拋出點在 `Matches()` 裡，那是**純函式、住在 AC14 明文禁止引用 NGO 的
組件**，按定義不在網路路徑上。**正確的理由**：第三個 enum 值只是 `Invalid` 的第二份
拷貝，而它會多一個必須凍結的 enum（規則 1b／AC15a 的維護面），買到的是零。

⚠ **但 (c) 只成立一半，而缺的那一半 r2 沒看見**（r3 評審，game-designer F6）：
`server-write ＋ spawn 前寫入` 約束的是**誰**寫與**什麼時候**寫，
**完全不約束「有沒有人寫過」**。一個忘記蓋章的機台仍然產出 `is_spoiled == false`。
**修法**：`ProductInstance` **不得有公開的無參數建構路徑**，只能經由同時要求
`network_index` 與 `is_spoiled` 兩個參數的工廠建立——把「忘記蓋章」從執行期預設值
變成**編譯錯誤**。由 **AC23** 守護。

⚠ **承載方式**：兩個欄位以 **server-write `NetworkVariable`** 掛在 #5 擁有的
`NetworkBehaviour` 上，**不是**由 spawn 當下的一次性 RPC 設定。r1 寫的
「spawn 時設定好，接收端本地查一次即可」**對遲加入者為假**——本作允許到班次結束前
30 秒加入（netcode Core Rule #9；**驗收條目是 AC4／AC5，不是 AC51**——r3 引證修正：
AC51 層級為 MVP 且驗的是**相反情境**「剩 20s 已過截止 → 導向 Lobby」），而 netcode GDD 明寫
「**NGO 不會對遲加入者重播歷史 RPC**」。一個第 4 分鐘進場的玩家，對第 1 分鐘 spawn
的物品會**完全沒有值**，於是 `Get(0)` 撞上 `Invalid` 哨兵並拋例外。
NetworkVariable 的現值會在 spawn 同步時送給遲加入者，這正是需要的性質。

**序列化（原 OQ-P12，一併收斂）**：兩個欄位**分開以基元型別過線**，
**不把 `ProductInstance` 當成一個 struct 送**。理由不只是省事——若整包送，NGO 可能
要求在 struct 上宣告 `INetworkSerializable`／`INetworkSerializeByMemcpy`，而該宣告
必須寫在擁有該 struct 的組件裡，也就是 AC14 明文禁止引用 NGO 的那個組件。
**分開送同時保住規則 4 的單一真相源與 AC14 的純度。**
⚠ **但「不需要實測」這句刪除**（r3 評審，network-programmer）。兩個理由：
(a) NGO 2.x 有 `UserNetworkVariableSerialization<T>` 這組 static 委派，設計目的正是
「為你無法修改的型別註冊序列化」，而註冊可以寫在**別的組件**——若它存在（**中等信心，
需查證**），「必須宣告介面 → 必須引用 NGO → 違反 AC14」這條推理鏈在第二步就斷了；
(b) **對 #4 可能不夠**：#4 搬運的是 `ProductInstance`，而「米血！**兩串**！」的自然形狀是
`NetworkList<ProductInstance>`，它要求 `T: unmanaged + IEquatable<T> +` NGO 可序列化——
拆欄位的招在這裡失效，而**本專案已經踩過這個坑**（netcode `:844-845` 的 `ClaimGeneration`
struct 必須實作 `INetworkSerializable` ＋ `IEquatable<T>`）。
**因此 OQ-P12 改為條件性關閉**，並對 #4／#5 施加一條前向約束：
**不得以 `NetworkVariable`／`NetworkList` 承載 `ProductInstance` 的集合**，
若要如此必須先做 W1 式雙行程實測並重新裁決 AC14。

**需求結構（本表定義形狀，內容歸 #7）**：

```
CustomerDemand { kind: {Family|Named}, family: machine_family, network_index: byte }
CustomerOrder  { slots: CustomerDemand[] }
```

「兩串米血」是**兩個都指向米血的槽**，不是一個帶 `qty=2` 的槽。這與本專案
`game-session-state.md` 已進 registry 的 `slots_in_vignette` 模式一致，
並且避開「交了一份還差一份」的部分完成狀態。

**修飾語（「加酸黃瓜」）不做成資料結構**。若某個口味變體真的有玩法效果，
它應該是**一筆獨立的原子 SKU**，且必須自己通過 Player Fantasy 的**適用**准入門檻；
若只是台詞風味，它只能活在 #7 的口白層，不得進入判定。
另註：「大熱狗一支，加酸黃瓜」這個例子**本身就違反門檻第 1 條**（`≤4 漢字`）
——若真心想要修飾詞玩法，正確做法是回頭修改 Player Fantasy 的准入標準，
而不是繞過它加在資料結構裡。

## Formulas

本系統有兩條純函式，沒有數值參數、沒有可調權重——所有加權與聚合都在 #15。

`Matches` 判定「一份商品能不能滿足一個需求槽，不能的話是哪一種不能」：

```
Matches(catalog, instance, demand) -> MatchResult:
    // ── 兩側的輸入域都先驗，未指派值／哨兵在此拋例外 ──
    entry = Get(instance.network_index)
    if demand.kind == Invalid         : throw                  // r2 新增
    if demand.kind == Family:
        if demand.family == Invalid   : throw                  // r2 新增
    else:                                       // Named
        demand_entry = Get(demand.network_index)               // r2：上提出三元式
        if demand_entry.status != Active : throw               // r2 新增
        if not demand_entry.nameable     : throw               // r2 新增

    // ── 驗完才判定 ──
    if instance.is_spoiled            : return Spoiled
    if demand.kind == Family:
        return entry.machine_family == demand.family ? Match : WrongFamily
    else:
        if instance.network_index == demand.network_index : return Match
        return entry.machine_family == demand_entry.machine_family
               ? WrongSku : WrongFamily
```

⚠ **r1 只修了被點名的那條路徑，沒有推廣到那一類**（r2 評審，systems-designer
＋ qa-lead）。r1 上提的是 `Get(instance.network_index)`——**instance 側**；
而 ⚠ 的文字宣稱「兩個分支之前」，指的卻是 **demand 側**的那一次查詢，
那一次其實還留在失敗路徑的三元式裡。更嚴重的是，**demand 側還有三個同類缺口
從來沒被碰過，而且全部落在規則 3 明訂的多數路徑上**：

| demand 側輸入 | r1 之後的行為 | 為什麼危險 |
|---|---|---|
| `kind == Family` 且 `family == Invalid` | 回 `WrongFamily`，**對全遊戲每一件商品、永遠** | AC3 保證沒有 SKU 是 `Invalid` 家族，所以這張單**永遠不可能完成**，而且不報錯——正是本文件花三段譴責的那個傷害，發生在**常態路徑**上 |
| `kind == Named` 指向 `nameable == false` 的 SKU | 安靜回 `Match` | #11 拿到一個沒有 icon 資產的查詢鍵，尖峰時客人頭上一片空白 |
| `kind == Named` 指向 `deprecated` 條目 | 契約要求 `Get()` 完整回傳，所以不觸發 fail-fast | 該 instance 不可能被產出（兩個查詢都濾掉），槽永遠填不滿 |
| 預設建構的 `CustomerDemand` | `kind` 原本沒有哨兵，零值即 `Family` | 一個忘記賦值的 demand **看起來是合法的家族需求** |

⚠ **同時要理解這道防線的靈敏度是反的**（r2 交叉引用）：它對唯一一類**不是資料錯誤**
的輸入（舊 build 的 client 收到一個合法的新 `network_index`，見規則 2 的 OQ-P8 段）
大聲拋例外，卻對上表四類**真實預期的 bug** 安靜放行。
**因此正確的方向不是在讀取點加更多 throw，而是讓非法狀態無法被建構**
——`CustomerDemand.Family()`／`.Named()` 兩個工廠（見 Interactions）。
上表的 throw 是第二道網，不是主防線。

**為什麼回傳 enum 而不是 bool**：不是因為布林會銷毀資訊（不會——#15 手上握著兩個
輸入，加一次 `Get()` 就能自己導出）。理由是**判例一致性**：槽位分配規則因為
「避免 #15 重新發明一套不一致的規則」而留在本表，失敗分類的情況一模一樣，
沒有理由結論相反。

**變數**

| 變數 | 型別 | 範圍 | 說明 |
|---|---|---|---|
| `instance.network_index` | byte | 已登錄且 `active` 的 SKU 之一 | 實際交付的那一份商品的身份 |
| `instance.is_spoiled` | bool | {true, false} | 由產出它的機台（#5）蓋章。**資料庫定義這個欄位存在，但從不寫入它** |
| `demand.kind` | enum，明確整數值 `{Invalid=0, Family=1, Named=2}` | 2 有效＋1 哨兵 | 這個需求槽是家族級還是指名。**`Invalid` 不得出現，由工廠保證** |
| `demand.family` | enum | 4 個有效值（**不含 `Invalid`**） | `kind == Family` 時有效；`Invalid` 拋例外 |
| `demand.network_index` | byte | 已登錄、`Active`、且 `nameable == true` 的 SKU | `kind == Named` 時有效；三個條件任一不滿足即拋例外 |
| 回傳 | enum `MatchResult`，明確整數值 `{Unevaluated=0, Match=1, WrongFamily=2, WrongSku=3, Spoiled=4}` | 4 有效＋1 哨兵 | **只有 `Match` 算滿足**；其餘三值供 #13／#15 做差異化回饋。⚠ **`Unevaluated=0` 是 r2 新增的哨兵**——原本 `Match=0`，使**零值即通過值**，一個未填的陣列、未寫的 out 參數或 `default(MatchResult)` 都會讀成「每一槽都滿足」，直接違反規則 1b 的標題。`Matches()` 永不回傳它；讀到它代表 #15 有 bug |

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
| 1 | 米血, fresh | Family: `Oden` | **`Match`** | 家族相符 |
| 2 | 黑輪, fresh | Family: `Oden` | **`Match`** | 同家族，家族級需求不分哪一串 |
| 3 | 咖啡, fresh | Family: `Oden` | **`WrongFamily`** | 家族不符——要換一台機器 |
| 4 | 米血, fresh | Named: 米血 | **`Match`** | 指名命中 |
| 5 | 黑輪, fresh | Named: 米血 | **`WrongSku`** | 同家族仍不算——只要換同一鍋裡的另一串 |
| 6 | 米血, **spoiled** | Named: 米血 | **`Spoiled`** | 品項對，但壞了 |
| 7 | 米血, **spoiled** | Family: `Oden` | **`Spoiled`** | `is_spoiled` 短路在輸入域驗證之後、判定之前 |
| 8 | 米血, fresh | Named: 貢丸（`nameable == false`） | **拋例外** | r2 新增：輸入域驗證，不是判定結果 |
| 9 | 米血, fresh | Family: `Invalid` | **拋例外** | r2 新增：同上 |

⚠ **這張表就是實作者會直接抄進 `Test_Matches_*` fixture 的東西**，所以它必須是
`MatchResult` 值本身。r1 修訂只改了第 7 列、留下六列布林值，再用一句括號註腳翻譯
——那讓同一欄混用兩套型別系統。**已於 r2 整欄改寫，註腳刪除。**

第 2 列與第 5 列並列是這條公式的重點：**同一份米血，在家族級需求下可被黑輪替代，
在指名需求下不行。** 這正是「家族級為主、指名為輔」在程式上的全部差異。
而第 3 列與第 5 列的區別（`WrongFamily` vs `WrongSku`）正是玩家需要做**不同修正行為**
的兩種失敗：前者要換一台機器，後者只要換同一鍋裡的另一串。

### 槽位分配規則

`Matches()` 的定義域只到「單槽 vs 單商品」。當一份商品**同時被同一張訂單的多個槽接受**時
（訂單 `[Family:Oden, Named:米血]` 收到一份新鮮米血），公式本身不回答該消耗哪一槽。
補充規則：

```
前置條件  = filled.Length == slots.Length，否則拋 ArgumentException
資格述詞  = 一個槽 s 是候選，若且唯若 Matches(instance, s) == Match   ← r3 補
消耗優先序 = 候選槽中，Named 先於 Family
同優先序內 = 取 slots 陣列中索引較小、且尚未填滿的槽
一份商品只消耗一槽
無候選槽  = 回傳 -1
```

⚠ **「資格述詞」那一行是 r3 補的，而它不是贅述**（r3 評審，systems-designer）：
r2 的規則只寫了「優先序」與「索引較小」，**從未說候選槽必須先匹配**。字面讀之，
一份咖啡交到訂單 `[Family:Oden, Named:米血]` 會被分配到槽 0——而那正是 AC13 案例 ⑤
（「無可用槽 → `-1`」）所要求的相反行為。**規則與它自己的驗收條目互相矛盾。**
✅ **已由原型執行確認**（探針 `AC13-4-R2RULE`）：訂單 `[Family:Oden, Named:咖啡]` 交付一份黑輪，
r2 的字面規則把它分配到**槽 1**（指名咖啡的槽），而正確答案是槽 0。**資格述詞是載重的。**

⚠ **`filled` 的長度前置條件亦為 r3 補**：r2 為了讓 `AllocateSlot` 可測而加入 `filled`
參數，但沒有規定它與 `slots` 等長。長度不符時字面實作會索引越界或靜默截斷。

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

⚠ **這個交換論證的定義域是「單一訂單之內」，不是全場。**（r2 評審，systems-designer）
`AllocateSlot()` 一次只看一張訂單，而**誰選那張訂單本文件沒有定義**——4 名玩家、
多位客人同時在場時，那才是綁定性的決策。反例：客人 A 的訂單 `[Named:米血]`、
客人 B 的訂單 `[Family:Oden]`，這一波只會出一份米血與一份黑輪；米血先送達並被
判給 B 的 Family 槽，**A 從此不可能被滿足**。稀缺先鎖定的規則在這裡提供零保護，
因為稀缺槽與彈性槽分屬**不同訂單**。

**歸屬**：本規則的**整合**（交付判定點接線、槽位佔用狀態維護）歸 #15／#4；
規則本身是**全函式**——它不依賴任何下游的**資料表**，但它依賴呼叫方傳入的
`filled`（r2 修正簽章，見 Interactions）。故 `AllocateSlot()` 由本系統擁有並由
**AC13** 在本系統測掉——但它住在 `static ProductMatching`，**不在 `IProductCatalog`
介面上**（r3 修正，見 Interactions：留在介面上會讓測試夾具重新實作判定邏輯）。
**跨訂單分配明確不歸本表**：交付當下「東西給你遞給的那個客人」，歸 **#4**；
由此產生的跨訂單餓死風險是 #8 波次組成的問題。（同步記於「刻意不處理」。）
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
現況下打開 Editor、不跑測試、直接 Build Web，下列不變量**全部放行**。

**本文件指定的機制**：每一條下列不變量除了 EditMode 測試之外，
**必須同時實作在 `UnityEditor.Build.IPreprocessBuildWithReport.OnPreprocessBuild`
裡，驗證失敗即 `throw new BuildFailedException(...)`**。測試與 build hook 共用同一份
驗證邏輯，不得各寫一份。

⚠ **r1 寫的「那是 Unity 唯一能真正中止 `BuildPipeline` 的鉤子」不對，而那個「唯一」
正是讓文件停止推理覆蓋範圍的那個詞**（r2 評審，unity-specialist）。實際覆蓋：

| 路徑 | 觸發？ |
|---|---|
| Editor Build 按鈕、Build And Run、腳本呼叫 `BuildPipeline.BuildPlayer`、`-batchmode -executeMethod` | **是** |
| **Addressables `BuildPlayerContent()` ／ `BuildPipeline.BuildAssetBundles()`** | **否**——它們走 Scriptable Build Pipeline，不經過 player build 的 preprocessor |

⚠ **後者正是 Overview 與 OQ-P6 點名的「免出 build 的內容更新」路徑。** 若日後採用
Addressables 遠端目錄，**本閘門不會保護內容更新**，必須另建一個掛在 Addressables
build script 上的對應閘門。（本文件規則 2 已於 r2 改為不需要 Addressables，
但 OQ-P6 仍然開著。）

**三條會靜默繞過的路徑，必須明列**（r2）：
1. **驗證器所在 asmdef 的 `defineConstraints`／`includePlatforms` 設錯** → 類別根本
   沒被編譯，無錯誤、無警告、build 成功、閘門不存在。這是唯一**靜默**的一條，
   而且它住在 `.asmdef` 的 JSON 裡，`.cs` 的 code review 看不到。
   對策：驗證器 asmdef 釘死 `"includePlatforms": ["Editor"]` ＋ **`"defineConstraints": []`**，
   並由 **AC17b** 用 `TypeCache` 反射確認鉤子型別存在且唯一。
2. **`-quit -batchmode` 吞掉失敗**：`BuildPlayer` 會把失敗記進 `BuildReport.summary.result`，
   但 `-quit` 仍然 exit 0，除非 `executeMethod` 自己檢查並 `EditorApplication.Exit(1)`。
3. **出貨是 `butler push` 一個既有的 `Build/` 目錄**——閘門擋的是「建置的那一刻」，
   不是「發佈的那一刻」。
4. **鉤子與資料在同一個 repo**：能寫壞資料的人可以在同一個 commit 裡把鉤子註解掉。
   這是 lint 不是 gate——gate 的定義性質是 commit 時提交者無法控制它。
   今天唯一可得的外部執行者是 `CODEOWNERS`，而 `.github/CODEOWNERS` 目前把所有路徑
   指向 `@Donchitos`（上游模板 repo 的擁有者，不是本專案），需先重新指向才有意義。

⚠ **這塊建置期資料治理閘門是跨切面基礎設施，沒有任何系統擁有它**，而本文件的
建置期不變量全部押在它身上。它應拆成獨立的 ADR ＋工具任務，**不得吸收進「實作
商品資料庫」的估算**。見 OQ-P11 與 Acceptance Criteria 的「外部前置條件」節。

- **若某 SKU `nameable == true` 但找不到專屬 icon 資產**：**視為內容錯誤，擋建置。**
  icon 資產命名綁定 `sku_id`（`Ui_Icon_[sku_id]`），一條 EditMode 測試掃描所有
  `nameable == true` 條目確認對應資產存在。理由：`nameable` 的設計目的就是當內容配額的
  剎車，**剎車失靈（宣稱可指名卻沒配 icon）比放行更危險**，必須硬擋而非軟降級。
- **若兩筆 `active` SKU 的 `display_label` 相同**（大小寫、全形半形正規化後比對）：擋建置。
  雖然它不參與 `Matches()` 判定，但會出現在 #13 結算畫面的逐項列表上——讓玩家讀到兩個
  一樣的字樣卻對應不同商品，違反准入門檻第 3 條的精神。
- **若某 `machine_family` 底下一筆 `active` SKU 都沒有**：擋建置。那代表對應機台變成
  一個造不出任何東西的空殼站台。須有常駐 EditMode 測試檢查「4 個家族每個都 ≥1 筆 active」。
- **若某 `active` SKU 的 `mesh_ref` 為 null**：擋建置（**AC4b**，r2 新增）。手持模型是
  **每筆 SKU 都要付**的資產，也是隊友隔著兩排貨架真正看到的東西；r1 對少數派資產
  （指名 icon）硬擋，對多數派資產零檢查。
- **若某個非 `Invalid` 的 `MachineFamily` 成員沒有對應的 `Ui_Icon_[family]`**：擋建置
  （**AC4c**，r2 新增）。家族級需求是**常態路徑**——沒有 `Ui_Icon_Microwave`，
  微波家族的每一張需求單在玩家頭上都無法呈現。AC3 防的是空殼站台，
  **在此之前沒有人防空殼符號**。注意量詞寫「∀ 非 `Invalid` 成員」而非硬編「4 個」，
  否則 Alpha 期新增第五個家族時測試會靜默地不再涵蓋它。
- **若 `Ui_IconTier_Family` 或 `Ui_IconTier_Named` 任一不存在，或某顆 icon 合成的
  層級標記數不等於 1**：擋建置（**AC18**，r2 新增，服務准入門檻 5）。
- **若某 `deprecated` 條目的 `mesh_ref`／`icon_ref` 不為 null**：擋建置
  （**AC19**，r2 新增）。這是規則 2 的「清 null」從承諾變成機制的那一步。
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

### 狀態覆寫下的層級可辨（r2 新增）

客人頭頂這個視覺頻道在本 GDD 介入之前**已經承載兩條語意軸**：①要什麼（形狀，§3.3）
②急迫／可互動狀態（色相，§4.3 的「紅蓋黃＋閃爍」，優先序「超時 ＞ 可互動 ＞ 湯色」）。
規則 3 加的層級是**第三條**，而 r1 修訂只注意到形狀語言預算是空的，沒有問：
**當「紅蓋黃＋閃爍」對一顆帶層級標記的 icon 生效時，那個標記還看得見嗎？**

**本表不指定實作，但指定判準**：

> 在回填尺寸下、於閃爍的**暗相與亮相兩個瞬間**，家族級與指名級仍須可分辨。
> **任何無法通過此判準的標記形式不得採用。**（此條與門檻 5 的負空間清單共同淘汰
> 以色相實作、以描邊實作、以及在暗相可能整個消失的低對比實作。）

### 刻意不處理

- **`network_index` 255 格用完**：不設計 runtime 分支。MVP 20-40 筆、Full Vision
  內容量表（4 店型／10+ 服務／12+ 客人，且互動層 SKU 定義刻意窄縮）保守估計全內容
  生涯遠低於 100 筆，含 `deprecated` 永久燒掉的號碼亦然。真逼近上限的修法是型別換
  `ushort`——一行 wire-format 改動，既有數值原樣放進更大型別。
  ⚠ **但不是零成本**（r3 修正）：依規則 1c，序列化型別變更須先實測確認既有資產存活，
  且 wire format 改動須連帶遞增 `[P-17]` 的版本 token。**以規則 1c 為準。**
  **決策不變**——為機率趨近於零的情境設計執行期路徑，正是本文件一路在警戒的過度設計。
- **槽位是否已被填過**：`Matches()` 是無狀態純函式，對同樣輸入永遠給同樣答案。
  槽位佔用狀態歸 #15／#4 自己維護，明確不在 DB 射程。
- **場上現在有幾份某 SKU 存在**（供給稀缺性、多名玩家搶同一份指名商品）：本表完全不追蹤。
  `Matches()` 只判斷「已送到手上的這一份」合不合格，稀缺性與競爭仲裁歸 #4／#5／#7。
- **零槽訂單**：本表只定義容器形狀，不設下限約束；是否允許由 #7 自行決定。
  （`AllocateSlot()` 對零槽回 `-1`，與「不匹配任何槽」同一條出口。）
- **跨訂單分配**（r2 新增）：當同一份商品同時被**不同客人的**訂單接受時，該歸誰
  ——**歸 #4**，判準是「東西給你遞給的那個客人」。本表的 Named-先於-Family 只在
  單一訂單內成立，跨訂單的餓死風險（A 要指名米血、B 的家族槽先吃掉唯一那份）
  是 **#8 波次組成**的問題。**本表到此為止，但明列它，不讓它變成沒人看見的缺口。**
- **`Shelf` 家族的供給有界**（r2 新增，economy-designer）：`Oden`／`Microwave`／
  `CoffeeMachine` 是**產生器**——供給是時間的函數，站過去等夠久永遠拿得到；
  `Shelf` 是**存量**——會耗盡，補回來的唯一路徑是「貨架補貨」，那是另一位玩家
  要離開現場去做的另一件事（概念文件 MVP 五種互動之一）。
  **這是身份層的事實，不是庫存數字**，所以它落在規則 4 的射程內，而本表是唯一
  同時知道「這筆 SKU 從哪來」與「那條路徑是產生器還是存量」的地方。
  本表**不追蹤剩幾個**（那是 #5 的執行期狀態），但施加一條前向約束：
  > **#7 對 `Shelf` 家族的 SKU 下 `Named` 需求時，有義務先向 #5 查詢可得性；
  > #5 必須提供該查詢。在該查詢存在之前，`Named` 需求不得從 `Shelf` 家族抽樣。**

  後半句是今天就能寫下、且 MVP 期完全可接受的安全預設。見 OQ-P15。
- **交付的商品與訂單裡所有槽都不匹配**：`AllocateSlot()` 回傳 `-1`，
  **本表到此為止**。該商品是被退回、掉在地上、還是計入失誤，歸 #4／#15。
  （此條補齊 r1 評審指出的模式斷裂——本節其餘每一項刻意不處理的情境都有明列，
  唯獨這一項原本連「不處理」都沒說。）

## Dependencies

### 上游（本系統依賴誰）

**執行期上游：無。** 商品資料庫是 Foundation 層——這正是它能排在第二個設計的理由。
它**不接網路同步層**（規則 2：靜態表不跨端同步）、不接遊戲時鐘、不接任何執行期系統。
⚠ **這個「無」是規則 2 於 r2 選擇「強引用＋清 null」而非 Addressables 的直接結果。**
若日後改採 Addressables 繫結資產，本系統就**有**一個上游套件依賴，而且會變成 async，
「載入期就固定的靜態表」也同時失效——**那是一個要重新評估設計順序的決定，不是一個
實作細節**。

**非執行期耦合有兩處，其中一處是真上游而且必須雙向登記**：
1. 美術資產（mesh／icon／音效）——由 `mesh_ref`／`icon_ref` 直接引用，`sku_id` 只用於命名。
2. **netcode GDD 的 `[P-17]` 版本閘。** r1 寫「引用，不重建」。
   ⚠ **但這條引用是單向的，違反 `.claude/rules/design-docs.md` 的「Dependencies must be
   bidirectional」**：grep `netcode-session.md` 的 SKU／商品資料庫／product-database
   ——**零筆**。netcode GDD 沒有任何紀錄顯示有東西依賴它那個 token 的粒度，
   而 OQ-P8 的擁有者正是它。**這條 OQ 會變成孤兒。**
   **必須回填的一行**（在 netcode GDD 的 Interactions 表或 Core Rule #9 的版本閘項）：
   > 「版本 token 的粒度**必須涵蓋純內容變更**（SKU 表隨 build 出貨，
   > 見 `product-database.md` 規則 2 / OQ-P8）」，並補一條 AC54 的姊妹條涵蓋純內容偏移。

#### 本表創造的前向義務（r2 新增——必須有載體，不能只活在本檔）

⚠ **本文件至少創造六條對「尚不存在的文件」的義務，而唯一機制是「在對方不會打開的
檔案裡寫一句話」。** `systems-index.md` 一條都沒承載。**在這些義務被登記到索引之前，
它們等於不存在。**

> **權威清單在 `design/gdd/systems-index.md`「跨系統前向義務」節，不在這裡。**

⚠ **r3 刪除了這裡原本的那張副本表**（claim-verifier）：r2 同時在本檔與索引各寫一份，
而**兩份在誕生當天就已經長度不同**——索引有 10 列，本檔只有 6 列。
一張只會漂移、而且已經漂移了的副本，不是冗餘備份，是**未來的矛盾來源**。
依本文件自己對「單一真相源」的定義，前向義務的真相源是索引。
**本節只保留指標與這條理由。**

⚠ **而義務數量已由 6 增為 11**（r3 新增五條）：`is_spoiled`／`network_index` 的
wire 契約與 `Spawn()` 前寫入（#5）、`ProductInstance` 集合不得走 `NetworkList`（#4／#5）、
約束⑧ 讀法的裁決（netcode GDD）、`#5` 若提供列出 SKU 的機台選單則 `nameable` 的配額
剎車歸零（#5）、以及 icon 對比下限與 `Atlas_Ui` mipmap 的預算決策（art-director）。

### 下游（誰依賴本系統）

| 系統 | 強度 | 介面 | 系統索引已宣告 |
|---|---|---|---|
| #5 機台互動組 | **硬**——沒有它機台不知道自己能產出什麼 | `GetByMachineFamily()`、建立 `ProductInstance` | 是 |
| #7 客人系統 | **硬**——沒有它客人不知道能要什麼 | `GetOrderable()`、`nameable` | 是 |
| #15 評分邏輯 | **硬**——沒有它無法判定對錯 | `Matches()` | 是 |
| #4 攜帶與交付 | **硬**——它搬運的就是 `ProductInstance` | struct 形狀 | 是（2026-09-19 補登） |
| #11 HUD 與需求 icon | **硬**——icon 查詢鍵來自本表 | `machine_family`／`network_index` | 是（2026-09-19 補登） |
| #13 結算畫面 | **軟**——逐項列表用 `display_label`；缺它仍可顯示星等 | `display_label` | 是（2026-09-19 補登） |
| #8 波次導演 | **軟**——依站台配重抽樣；退化成均勻抽樣仍可運作 | `GetByMachineFamily()` | 是（2026-09-19 補登） |

### 雙向一致性檢查

**四條原本未宣告：#4、#11、#13、#8——現已全部補登。**
（r1 修訂已完成補登，但本節的表格與內文沒跟上，仍寫著「否／四條未宣告」，
與同節結尾的「已更新完畢」自相矛盾——r2 修正。這是一個**在「一致性檢查」小節裡
發生的一致性缺陷**，剛好示範了本文件的漏改模式：改了定義處，漏了引用處。）

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
| SKU 總筆數 | int | 20-40（MVP） | 尖峰可讀性下降、美術資產線性增加；理論上限 255（`network_index` 型別） | ⚠ **「低於 12 筆撐不出變化」這個下限是用錯變數推出來的**（r2，economy-designer）：家族級需求下同家族 SKU **完全可互換**（Worked example 第 2 列），所以家族內的第 n 筆（n ≥ 2）在常態路徑上買不到任何玩家決策。真正能為自己付帳的只有 **4 ＋ \|nameable\| ＋ \|在 #5 有相異加工剖面者\|**（三者可重疊）。多樣性的另一條幾乎免費的管道是 §5.1 的共享排面圖集 |
| 每家族 `active` 筆數 | int | **≥1（硬性）** | 同家族內差異模糊，家族級需求失去意義 | **0 = 建置失敗**，該機台變空殼站台 |
| `nameable == true` 的筆數 | int | **MVP：2 ≤ N ≤ 6**（下限 2026-09-20 arlong 裁決；上限 `sku_nameable_max`，由 art-director 自形狀預算推導） | **每一筆都必須配一張專屬 icon**，直接換算成美術工時**與形狀預算**（後者更稀缺） | **低於 2 即違反 MVP 下限**；為 0 時「指名客」這個客人類型不存在，退化成純家族級 |
| `display_label` 長度（喊聲，**僅 `nameable == true`**） | int | **≤4 漢字 ＝ ≤4 音節**（`sku_holler_max_chars`；⚠ 漢字數是**中文語系下的實作代理**，不是通用判準） | 違反准入門檻 1「隔著貨架一口氣喊得完」 | 下界 1；空字串不合法 |
| `display_label` 長度（排版，**僅 `nameable == false`**） | int | ≤6 漢字（`sku_display_label_max_chars`） | #13 結算畫面逐項列表排版溢出 | 下界 1 |
| `sku_nameable_max`（池子花色數上限） | int | **6**（2026-09-20 art-director 推導，由 8 下修；PROVISIONAL，回填觸發同門檻 6） | 尖峰時玩家無法在 0.5 秒內辨識頭頂 icon | 為 0 時「指名客」不存在，退化成純家族級 |
| **`nameable == true` 的 MVP 下限** | int | **2**（2026-09-20 arlong 裁決，各一個產生器家族） | — | **為 0 時規則 3 的兩級機制在 MVP 完全不被實測**，而它是全作唯一一個不來自真實超商經驗、因此需要被教的機制 |

（原本列在此的「同時在場相異需求符號數上限」已移到下一節「不屬於本系統」——
**本系統沒有執行期狀態，看不見並發，一個自己觀測不到的量不該掛在自己的旋鈕表上**。
但本表確實同時看得見兩個因子，所以它以 levy 的形式保留約束力。r2 修正。）

⚠ **這裡改成先釘住可靜態檢查的那一半**（r2）：r1 把**不可強制**的那一半（執行期並發）
當成本表的旋鈕，卻讓**可強制**的那一半（池子花色數）也停在 TBD。`sku_nameable_max`
是 build 期查得到的，所以它現在有一個暫定值與一條 AC；並發那一半 levy 給 #7。

`nameable` 筆數的**上限**不在本表定案：它由美術（幾張 icon 畫得完）與 #7（指名客佔比
多少才有趣）共同決定，本表只負責**讓這個成本可見**。

⚠ **但下限在本表定案，而且 r3 之前它根本不存在**（r3 評審：cross-reference C3）。
r2 只 levy 了上限，於是三條**個別正確、個別便宜**的修法（把 `Shelf` 的供給約束推廣到
所有家族／把它機制化進 `GetNameable()`／收緊指名池）**合起來會讓指名池在整個 MVP 期
回傳空陣列**——而 AC4 對空集合恆真、AC20 恆真、AC3 不受影響，**三十條 AC 沒有一條會紅**。
一個只有上限沒有下限的旋鈕，在夠多人各自把它往下轉一格之後會歸零，而沒有人會發現。

> **2026-09-20 arlong 裁決：MVP 的 `nameable` 下限 ＝ 2**（各一個產生器家族）。
> **代價已明示**：OQ-P1（缺兩顆家族 icon）與 OQ-P14（icon 圖形規格未定）因此
> 成為**真正的擋路項**，art-director 必須先交件。
> **換到的是**：規則 3 這個全作唯一不來自真實超商經驗的機制，在 MVP 就能被**實測**，
> 而不是再寫一輪文件去論證它。

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

**`nameable: true → false` 是合法且預期的操作**（r2 新增）。r1 只定義了 `false → true`，
於是這個旋鈕**只能往上轉**——而一個只能往上轉的東西不是旋鈕。實測後若發現
「8 個指名符號在尖峰讀不完」，r1 文件裡唯一的減量手段是把整筆 SKU 標 `deprecated`，
而那是**終態、不可復活、永久燒掉 `network_index`**，並且連帶把該 SKU 從**家族級供給池**
也一起拿掉（純屬誤傷——家族級根本用不到 icon）。**用不可逆的刪除去調一個可逆的旋鈕
是設計錯配。**

> 降級的代價：該 icon 從 `Atlas_Ui` 移除、`icon_ref` 清 null、#7 的指名池少一筆。
> **不影響** `sku_id`、`network_index`、`machine_family`、`status`、AC1 快照或 wire format
> ——`nameable` 不在快照 tuple 裡，所以降級不違反身分永久性。
> **指名池的縮減是旋鈕；SKU 的下架是刪除。兩者不得互相代替。**

⚠ **「SKU 總筆數 20-40」這個範圍是估的，不是推導出來的。** 真正能決定它的是
「一個家族內要有幾種東西，玩家才會覺得有變化但不會混亂」——那是 #7 與 #8 設計時
才量得出來的。此處寫成旋鈕而非定論，就是為了留這個口。

### 不屬於本系統、但受本表約束的旋鈕

| 旋鈕 | 真相源 | 本表的約束 |
|---|---|---|
| 指名需求出現**比例** | #7 客人系統／#8 波次導演 | 只能從 `GetNameable()` 的池子抽。⚠ **本表不約束這個比例**（r2 修正：`nameable` 管「哪些」、並發上限管「花色數」，兩者都不管頻率）。#7 的 GDD **必須**定下此值並反向引用本列 |
| 各站台需求配重 | #8 波次導演 | 只能用 `machine_family` 的 4 值分類；`Shelf` 是存量家族，見「刻意不處理」 |
| 加工時間、燒焦閾值、溢出閾值 | #5 機台互動組 | 本表不持有任何時間常數 |
| 星級門檻、耐心扣減 | #15 評分邏輯 | 本表只提供 `Matches()` 的**四值 `MatchResult`**；聚合成星等完全歸 #15 |
| 每張訂單槽數 | #7 客人系統 | 本表只定義 `slots` 是陣列。⚠ **不再是「不設上下限」**（r2 修正）：因為本表採 slots 而非 `qty` 欄位，N 個槽在頭頂就是 **N 個符號實例**，所以訂單槽數**同時是一條可讀性上限**，不只是難度旋鈕 |
| **同時在場相異需求符號數上限** | #7 並發 ＋ #11 呈現 | ⚠ **本表看得見兩個因子，但看不見執行期**（r2 修正）：本系統無執行期狀態、無執行期存在，`IProductCatalog` 沒有任何成員能觀測或限制並發。本表**levy** 這條約束：任一時刻在場的相異需求符號數不得超過 `sku_concurrent_distinct_max` ＝ **4（PROVISIONAL，r3 給值）**，**計數單位是槽不是客人**；#7 的 GDD 必須包含驗收此上限的測項並反向引用本列。⚠ **r3 補值的理由**：r2 把這條約束 levy 出去卻**沒給值**，於是 #7 被要求為一個無值的變數寫一條**不可能失敗**的測項，而 `.claude/rules/design-docs.md` 要求旋鈕必須有安全範圍。回填觸發同門檻 6。⚠ **它不是光敏性上限**，見 OQ-P16 |

## Visual/Audio Requirements

本系統不產生任何畫面或聲音。它產生的是**一份資產清單與一組命名約束**——每筆 SKU 上線時
必須有對應資產存在，命名由 `sku_id` 綁定（Edge Cases 的建置期檢查即靠此綁定運作）。

| 資產 | 顆粒度 | 規格來源 | 命名 |
|---|---|---|---|
| 手持模型 | 每筆 SKU | 美術聖經 §8.2（**級距未定，見 Open Questions**）、§8.4 Simple Lit、§5.1 **有體積的互動物件禁貼圖**（r3：該格已由「互動層一律禁」改為「物件禁／符號允許」，手持模型屬前者） | `Mesh_[sku_id]` |
| 家族需求 icon | **每個非 `Invalid` 的 `machine_family` 一個，非每筆 SKU**（AC4c 硬擋） | **§8.6**：單色剪影 64×64、白描邊、透明背景，進共享 `Atlas_Ui`；§3.3：不用文字 | `Ui_Icon_[family]` |
| 指名需求 icon | **僅 `nameable == true` 者**（`icon_ref` 非 null，AC4 硬擋） | 同上，**且須通過門檻 6 的頭頂符號總表查重** | `Ui_Icon_[sku_id]` |
| **層級標記覆蓋** | **恰好兩張，全專案共用** | 與圖形內容無關、可套用於任意 icon；須通過門檻 5 的負空間清單與狀態覆寫判準 | `Ui_IconTier_Family`／`Ui_IconTier_Named`（AC18 硬擋） |
| 取得音效 | 依機台家族共用，非每筆 SKU | 歸 #14 音效系統 | — |

⚠ **引用修正（r2，四位專家獨立發現）**：r1 把「單色剪影 64×64、白描邊、透明背景、
進共享 `Atlas_Ui`」記為 §3.3——**那五項裡 §3.3 一項都沒有**。該規格實際在 **§8.6**，
`Atlas_Ui` 的圖集設定在 **§5.6**。§3.3 對需求 icon 說的是
**「融入世界語系（實心幾何、高飽和）」**，只有「不用文字」真的來自 §3.3。

⚠ **本段原本帶行號（`:413`／`:340`），r3 已全部改為章節號。** 理由是實測出來的：
r3 修訂剛改寫 §8.6，**行號當場失效，`:413` 指向一段講 `T_load` 解壓 CPU 的無關文字**
——而這正是 r3 終審點名的 RC-ε（「改了定義處、漏了引用處」復發約 20 次）在**本次修訂
自己身上**的第一個實例。**跨檔引用一律用章節號，行號只用於一次性的評審佐證。**
（r3 的交叉引用專家另記錄：連評審自己都犯了同一個錯，最嚴重一處行號偏離 230 行。）

#### 需求 icon 的規格（2026-09-20 art-director 裁決，關閉 OQ-P14）

r2 指出 §3.3 與 §8.6 彼此矛盾並留成 OQ-P14。**art-director 已裁決，且覆核時另找到
第五處矛盾，那一處把問題從「取捨」變成「勘誤」**：

> **§8.8 早已核准頭頂使用 TextMeshPro，而 TMP 字型是 SDF atlas ＝ 貼圖。**
> 所以 §5.1 那格「互動層仍禁貼圖」在美術聖經**自己的頁面上**就已經是偽命題。
> 它不是一個待選分支，是一個**錯誤的格子**。

**裁決：§3.3 與 §8.6 描述的是同一顆 icon 的兩個圖層，本來就不衝突。**
§3.3 描述**填充層**（實心、高飽和、世界語系）；§8.6 描述**輪廓層**（單色、描邊、
透明背景）。先前唯一的真分歧只有「描邊要不要有顏色」。最終規格：

> 64×64 PNG／透明背景／**實心單色填充**（互動黃，狀態覆寫時警示紅）／
> **`Ink_Contour #23282A` 外描邊 4px**／無漸層無內部細節／
> Emission **只套填充，描邊與層級標記強制排除**／Unlit／World Space Billboard／`Atlas_Ui`

**附帶性質（art-director 指出，先前沒有人提過）**：身份（輪廓）與狀態（填充色相）
落在**物理分離的兩層**，因此「紅蓋黃」**永遠吃不掉身份**。

⚠ **而本文件與 r3 的 accessibility-specialist 共用的那個調和提案（互動黃 ＋ §4.5
白描邊）被實算否決**：`CR(黃, 白牆 #E9EEEC) = 1.2313:1`，而**白描邊在同一背景下
更糟——1.1728:1**。問題不是黃不夠深，是**那個方案裡沒有任何一個像素比背景暗**。
§4.5 的白描邊理由寫的是「深夜藍窗景旁的對比」——那條規則是為窗邊校準，卻被套用到
它唯一不適用的背景上（原則 1＋3 讓店內絕大多數就是 `#E9EEEC`／`#9BA3A6`）。
**改用 Ink 描邊後**：對白牆 12.71:1、對互動黃 10.33:1、對警示紅 3.40:1。
描邊與填充的失效區間**互補且不重疊**（暗描邊亡於暗背景、亮填充亡於亮背景，
而沒有背景能同時比兩者都亮又都暗），所以不需要雙描邊。

⚠ **一張訂單的 N 個槽在頭頂就是 N 個符號實例**（r2 新增，ux-designer）——這是本表
採 `slots` 陣列而非 `qty` 欄位的**直接呈現後果**，而 r1 只用機制理由論證該選擇、
沒有計過它的顯示代價。「米血！**兩串！**」在客人頭上是兩顆一樣的 icon（或某個
沒有人指定過的替代呈現——§8.8 只寫了「頭頂」，全專案沒有任何多 icon 擺位規格）。
因此 `sku_concurrent_distinct_max` 的**計數單位是槽不是客人**，而門檻 6 的最難案例
是「近乎重複的相鄰」。

**本表施加的美術約束**：**手持模型（`Mesh_[sku_id]`）禁貼圖**（美術聖經原則 2）。
⚠ **r3 刪除「互動層禁貼圖」這個較寬的說法**：依 art-director 裁決，原則 2 的射程是
**有體積的物件**，不是「互動層的一切」——2D 符號沒有可替代的輪廓，**其剪影即其全部**，
對它說「改用剪影」是同義反覆。需求 icon 因此**是**貼圖，而手持模型**不是**。
商品的辨識度必須由**形狀與色塊**承擔，不能靠包裝圖案——這與准入門檻第 2 條
「對方不看畫面就知道是什麼」互為表裡：**若一樣商品非得看到包裝印刷才認得出來，
它本來就不該進表。** 背景層排面不在本表射程（§5.1 共享圖集）。

#### 層級標記（准入門檻 5 的資產面）

**美術聖經對兩級 icon 的差異完全未著墨**：§8.6 的規格對「需求 icon」一體適用，
而「指名級」這個概念是本 GDD 才產生的。預設結果是兩級共用同一規格、無任何差異
——**不是因為有人如此裁決，而是因為沒有人被問過**。
（r1 寫的「原本共用完全相同的視覺規格（…同擺位）」把來源的**沉默**描述成來源的
**命令**；而且「同擺位」是無中生有——**全專案沒有任何頭頂 icon 的擺位規格**，
§8.8 只寫了「頭頂」，多 icon 版面在本文件的 UI Requirements 裡是交給 #11 的。r2 修正。）

後果不變且成立：**玩家無從在 0.5 秒內分辨「這顆代表家族任意」與「這顆代表只有這個」**，
而兩者的判定規則完全不同。這是一條**隱藏規則**——說明書被換成「你得先打過這局才
學到教訓」，違反支柱 2。
對照：同一份美術聖經 §3.1 對「隊友 vs 客人」下了硬功夫（縮圖測試、剪影公式、
「穩 vs 晃」動態分流器）。**對客人身份的視覺分流下了規格，對需求層級的分流一片空白。**

**本表的要求（2026-09-20 arlong 裁決）**：每一顆需求 icon 必須合成**恰好一張**
層級標記覆蓋資產（`Ui_IconTier_Family` 或 `Ui_IconTier_Named`），由 **AC18** 硬擋。
**「必須存在、恰好一張、不得用什麼（負空間清單）、必須通過狀態覆寫判準」歸本表。**
三個被 r1 交出去的形式選項為何全部不可用，見 Player Fantasy 的「門檻 5 的形式」。

**具體圖形已於 2026-09-20 由 art-director 裁定**（原本寫「歸 #11 與美術」，
但它是一個**沒有人被指派**的空位）：

> `Ui_IconTier_Family` ＝ 填充**內部**下緣內側、靠左對齊的 **16×16 Ink 實心方塊**；
> `Ui_IconTier_Named` ＝ 同高、**寬度加倍**的 **32×16 Ink 橫條**（來源 64×64）。
> **判別特徵 ＝ 左緣固定、右緣位移。**
> **從填充裡「挖空」，不是加在 icon 旁邊。**

挖空而非外加買到四件事：icon 的外接矩形不變（**因此不影響 #11 的多 icon 擺位——
本文件先前欠的那條空白現在不欠了**）、零額外面積、零額外 draw call、
「紅蓋黃」與閃爍**兩相皆原樣存活**（標記是 Ink 且被排除於 Emission 之外，
所以亮相時填充往白衝而標記不動，**對比在亮相變好不是變差**）。

⚠ **合成發生在 Sprite Atlas 打包期，不是執行期。** 兩張 PNG 以**來源資產**存在
（滿足 AC18 的存在性），**不進出貨的 atlas**：每顆 icon 的層級是**確定的**
（`Ui_Icon_[family]` 恆為家族級、`Ui_Icon_[sku_id]` 恆為指名級），所以沒有任何一顆
需要兩個變體，合成是 1:1，**格子數不增、下載不增、draw call 不增**。
若改成執行期疊加：10 NPC × 1-3 槽 ＝ 最多 30 個額外 World Space Canvas 元素，
而 §8.3 給 NPC 的**整個**配額是 20-30 calls——**直接打穿**，不予採用。

⚠ **art-director 自標未量測**：7.5 vs 15 顯示像素的右緣位移，在 1 秒強迫選擇下
是否可靠**沒有量過**。備案是 Family 縮到 1/8 寬（位移推到 11.3px），不改機制。

**選項 B（用 glyph 類別承載層級，零資產）經評估不可行**：(a) 它會推翻 arlong
兩天前的裁決，而那條裁決的理由（讓「可自動化」變成真的、AC18 有可斷言的對象）
至今無懈可擊；(b) 容器／食物的二分在本作 SKU 上直接破功——一罐飲料、一碗泡麵、
一杯咖啡，**它的食物本體就是容器**，而這些恰恰最可能被指名；(c) 與 §3.2／§3.4 的
世界形狀語彙相撞（關東煮鍋是全店唯一曲面主體）。
**但採納其洞見為次要冗餘線索**（非閘門、不免除合成義務）：家族 icon 優先取
容器／機台語彙，指名 icon 優先取食物本體語彙。

#### 形狀語言預算（2026-09-20 art-director 補齊，原本是空的）

**r2 的結論成立，但它的推論是錯的，而那是 r2 全套發現裡唯一一個實質錯誤。**

r2 寫：「若需求 icon 是單色剪影、不靠色相分身份，則它不違反 §4.3 色彩配額；
但若 §3.3 勝出，§4.3 的配額就對它生效，本專案其實已經擁有一條硬上限。」
**後半句是錯的。** §4.3 鎖的是**色相種類數 = 2**，而那 2 個名額**已經被狀態軸
（互動黃／警示紅）用完**。所以配額**不對身份施加任何上限**——它只是把身份頻道
從色相**驅逐回形狀**。**§3.3 勝出之後專案沒有獲得硬上限，而是失去了用色相分身份的
可能；處境比本文件先前以為的更緊，不是更鬆。**

**而 r2 的真結論「沒有任何規則接手，而形狀比色相稀缺得多」完全正確**，
art-director 已據此補上那條規則（依 §3.1 的「穩 vs 晃」分流器分兩個互斥判別池）：

> **池 A（客人頭頂）≤ 14 個相異剪影。**
> 現況已佔 **8**（超時驚嘆號 1 ＋ 完成打勾 1 ＋ 家族 icon 6，含尚不存在的
> `Microwave`／`Shelf`）→ **指名 icon 的形狀預算 ＝ 6**。

**這就是 `sku_nameable_max` 由 8 下修為 6 的推導。** ⚠ art-director 自標：
14 這個天花板是**規劃值不是量測值**，推導是類比（§3.1 的封閉 5 元集合 vs icon 的
語意先驗）不是實驗，**必須於 #11 回填後以門檻 6 的協定重校**。

⚠ **`nameable` 這個剎車只擋美術工時，不擋可讀性**——這條警告在有了形狀預算之後
**仍然成立**，只是現在有了一個數字：六張都畫出來、AC4 全過、AC20 全過，
仍然可能在尖峰看不懂。**約束力的完整清單**：准入門檻 5（負空間清單＋AC18）、
門檻 6（頭頂符號總表查重，含家族 icon）、`sku_nameable_max = 6`（AC20）、
形狀預算池 A ≤ 14、以及 levy 給 #7 的並發上限 4。

**已知缺口**：家族需求 icon **缺兩個**（`Microwave`、`Shelf`），且既有四個的分類基底
與 `machine_family` 不同源。見 OQ-P1。
⚠ **OQ-P1 的擋不擋等級於 r2 上修**：AC4c 一旦寫下，缺 icon 就是擋建置，
所以它從「不擋本文件」變成**擋本表任何 SKU 標成 `Active`**。

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

⚠ **「BLOCKING」在本節已改為兩個獨立的軸——先讀下方「『BLOCKING』的兩軸」節。**
簡言之：**軸 1（證據閘）今天就生效**，每一條標 Logic／自動化的 AC 都受它約束，
沒有通過的測試就不得標 Done；**軸 2（建置期強制）待 ADR-XXX**，只適用於資料不變量。
r1 把這件事寫成一段警語放在一條 MVP-必達 AC 旁邊；r2 改成一個明示的整批降級；
**r3 發現那個整批降級把 AC6c 也掃了進去——而 build hook 對一條型別建構測試無事可做**，
於是本節不再於單條 AC 上標 `(BLOCKING)`，改由兩軸表統一指定。

| # | 準則 | 層級 | 證據 |
|---|---|---|---|
| AC1a | **身份永久性（快照側，r3 改為事件日誌）**。GIVEN `design/registry/sku-shipped-snapshot.txt` 的 `sku:` 區塊——一份 **append-only 的事件日誌**，每列 `(日期, 事件, sku_id, network_index, machine_family 整數值)`，事件 ∈ `{ADDED, DEPRECATED}`——WHEN 現行 SKU 表載入，THEN ①同一 `sku_id` 的 `network_index` 與 `machine_family` 整數值在全部事件列中**恆等**且與現行表一致；②同一 `network_index` **從未指派給第二個 `sku_id`**；③**曾出現 `DEPRECATED` 的 `sku_id`，現行 `status` 不得為 `Active`**；④現行表中每一筆條目**至少有一列 `ADDED`** | **MVP-必達** | Logic／自動化。⚠ **r3 結構性改寫**：r2 的版本**三路封死、第一次下架就卡住**（systems-designer ＋ economy-designer 獨立發現）——欄位含 `status`，而維護規則要求「既有列永不編輯」×「與現行表雙射」。SKU 由 `Active` 轉 `Deprecated` 時：改列違反 append-only、加列違反雙射、不動則本條**永久紅燈**。三條路全封死，而唯一出口是**被明令禁止的「重新產生」**，**且重新產生正好會清空 AC15a**。改成事件日誌後，下架**就是**追加一列 `DEPRECATED`，三個矛盾同時消失。⚠ **雙射改為單向子句 ④**：`network_index` 永不重用**技術上只需對已出貨號碼成立**，而本檔名為 `shipped`；把約束從出貨邊界提前到 commit 邊界，代價是迭代期持續假紅燈——而一條會逼人造出破解法的規則比沒有規則更糟。⚠ 內容進表前對空集合恆真，見下方「真空與其對策」 |
| **AC1b** | **現行表自我一致（不依賴快照，r2 新增）**。GIVEN 現行 SKU 表，THEN `sku_id` 唯一且非空字串；`network_index` 唯一**且無任何一筆為 0**；`status` 無任何一筆為 `Invalid`；`machine_family` 無任何一筆為 `Invalid` | **MVP-必達** | Logic／自動化。⚠ **r3 修正 r2 的分類錯誤**：r2 把本條列入「量詞域是 enum 宣告或具名資產，不受真空影響」——**那是假的**。本條的 GIVEN 就是「現行 SKU 表」，**零列時全部子句恆真通過**。「不依賴快照」≠「不受真空影響」。本條在首批內容進表之前**買不到任何東西**，真空期的唯一活絆線是 AC15a ＋ AC17a |
| AC2a | **標籤長度（r3 依 `nameable` 分兩級）**。GIVEN 每一筆 `Active` SKU，WHEN 以 `StringInfo.LengthInTextElements` 計數，THEN **`nameable == true` → 1 ≤ `display_label` ≤ `sku_holler_max_chars`（4）**；**`nameable == false` → 1 ≤ `display_label` ≤ `sku_display_label_max_chars`（6）**；且 `sku_holler_max_chars ≤ sku_display_label_max_chars` | **MVP-必達** | Logic／自動化。⚠ r2 補下界——空字串原本通過。⚠ **r3 分兩級**：r2 新增「門檻的適用分級」給家族填充型 6 字，卻讓本條繼續對**每一筆** SKU 斷言 ≤4——**一筆分級明文允許的 5 字 SKU 會被一條 MVP-必達擋掉**，而解除它最順手的動作是調鬆唯一一條真正自動化的口語門檻 |
| AC2b | **標籤唯一**。GIVEN `Active` SKU 集合，WHEN 以 `s.Trim().Normalize(NormalizationForm.FormKC).ToLowerInvariant()` 正規化後比對，THEN 無兩筆 `display_label` 重複。繁簡變體不在射程，由 AC12 人工攔截 | **MVP-必達** | Logic／自動化（BLOCKING）。⚠ r2 釘死正規化式，否則測試不具決定性 |
| AC3 | **無空殼站台**。GIVEN 現行 SKU 表，WHEN 依 `machine_family` 分組統計 `Active`，THEN **`MachineFamily` 的每一個非 `Invalid` 成員**各 ≥1 筆；且無任何 SKU 的 `machine_family` 為 `Invalid` | **MVP-必達** | Logic／自動化（BLOCKING）。⚠ **本條預期在首批內容進表前為紅燈，那是正確行為。不得加空表豁免**（`if (catalog.Length == 0) Assert.Pass()`）；需要綠燈請標 `[Ignore("待首批 SKU 內容")]` 並開 issue 追蹤，**不得改寫斷言**。⚠ r2 把硬編的「4」改成 ∀ 成員，否則新增第五家族時本條會靜默不再涵蓋它 |
| AC4 | **`nameable` 必有 icon**。GIVEN 每一筆 `nameable == true` 的 `Active` SKU，THEN `icon_ref` **非 null**，且該 Sprite 的來源資產經 **`AssetDatabase.LoadAssetAtPath<Texture2D>(AssetDatabase.GetAssetPath(icon_ref))` 回報 `width == height == 64`**、其 `TextureImporter.textureType == Sprite`、`mipmapEnabled == true`、並被 `Atlas_Ui` 收錄 | **MVP-必達** | Logic／自動化——早期誤報由 `nameable` 預設 false 的作業慣例避免，**不放寬本測試**。⚠ r2 改為**引用檢查**而非檔案系統掃描（規則 2 已允許強引用），並釘死量測對象為**來源資產**：icon 打進圖集後，執行期 `sprite.texture` 回報的是圖集尺寸，不是 64×64。⚠ **r3 三項修正**：①量測 API 改掉——`TextureImporter` **沒有穩定公開的「回報來源寬高」成員**（`GetSourceTextureWidthAndHeight` 歷來是 internal），一條指向不存在 API 的 BLOCKING AC，它的自然解法就是被刪掉；②補 `mipmapEnabled`，art-director 已裁定 `Atlas_Ui` 開 mipmap；③**「被 `Atlas_Ui` 收錄」的查詢方式仍無規格，且 Sprite Atlas V2 的 `GetPackables` 行為需實測**——這一子句列為**待原型回填**，不得因難以實作而整條刪除 |
| **AC4b** | **`Active` 必有手持模型（r2 新增）**。GIVEN 每一筆 `Active` SKU，THEN `mesh_ref` 非 null | **MVP-必達** | Logic／自動化（BLOCKING） |
| **AC4c** | **每個家族必有需求 icon（r2 新增）**。GIVEN `MachineFamily` 的每一個非 `Invalid` 成員，THEN 存在對應 `Ui_Icon_[family]` 資產。⚠ 量詞域是 **enum 宣告**，不是 SKU 表——因此**不會被髒資料清空** | **MVP-必達** | Logic／自動化（BLOCKING） |
| AC5 | **`Matches()` 家族模式**。GIVEN fresh instance，WHEN `demand.kind == Family`，THEN 家族相符回 `Match`、不符回 `WrongFamily` | MVP | Logic／自動化（BLOCKING） |
| AC6 | **`Matches()` 指名模式**。GIVEN fresh instance，WHEN `demand.kind == Named`，THEN 完全相符回 `Match`；**同家族不同 SKU 回 `WrongSku`；不同家族回 `WrongFamily`** | MVP | Logic／自動化（BLOCKING） |
| **AC6b** | **Named 分支 fail-fast（r2 新增——r1 的頭條修法原本無人驗收）**。GIVEN 合法 fresh instance，WHEN `demand.kind == Named` 且 `demand.network_index` 為從未指派值／`deprecated`／`nameable == false`，THEN **拋 `ArgumentOutOfRangeException`**，不得回 `WrongSku`／`WrongFamily`／`Match` | **MVP-必達** | Logic／自動化（BLOCKING） |
| **AC6c** | **tagged union 無法被**意外地**建構成非法狀態**（r3 改寫）。GIVEN `catalog.FamilyDemand(Invalid)`／`.NamedDemand(0)`／`.NamedDemand(非 nameable)`／`.NamedDemand(Deprecated)`，THEN **建構當下**拋 `ArgumentOutOfRangeException`；且 `CustomerDemand` **無 `public` 建構子、無 `public` 欄位設值器**；且經工廠產出的實例恆滿足「`kind == Family` ⇒ `network_index == 0`」與「`kind == Named` ⇒ `family == Invalid`」 | **MVP-必達** | Logic／自動化＋反射。⚠ **r3 三項修正**：①r2 寫的「**無其他公開建構路徑**」＋「讓非法狀態**無法被表示**」對 `struct` 在 C# 語言層面**不可能為真**——`default(T)`、`new T()`、`new T[3]` 永遠存在且永遠給出 `kind == Invalid`。**維持 struct**（本文件自己的無 GC alloc 論證），但把宣稱降為「無法被**意外**地表示」，並讓 `default` 落在 `Invalid` 哨兵上由 `Matches()` 攔截（規則 1b 已如此設計）。②工廠改吃 catalog（見 Interactions），因為原簽章**算不出自己的契約**。③**證據型別移除 BLOCKING 標記**，改由下方兩軸表指定 |
| AC7 | **`is_spoiled` 短路**。GIVEN `is_spoiled == true` **且 `instance.network_index` 為已指派值、`demand` 由工廠建構**，WHEN 對任一合法 `demand`（即使本應相符），THEN 一律回 `Spoiled` | MVP | Logic／自動化（BLOCKING）。⚠ r2 收窄前提：輸入域驗證在短路**之前**，所以原本的「任一 demand／一律」比實作更強 |
| AC8 | **`Get()` 查 deprecated**。GIVEN `deprecated` 條目的 `network_index`，WHEN 呼叫 `Get()`，THEN 完整回傳，不丟例外、不回 null | MVP | Logic／自動化（BLOCKING） |
| AC9 | **`Get()` 查無效值**。GIVEN 從未指派過的 `network_index`（含 `0 = Invalid`），WHEN 呼叫 `Get()`，THEN **拋出 C# 例外**（`ArgumentOutOfRangeException` 或等價型別）。⚠ **不得以任何帶 `[Conditional]` 的 assert API 實作**——`UnityEngine.Debug.Assert`（`UNITY_ASSERTIONS`）、`UnityEngine.Assertions.Assert.*`（同上）、`System.Diagnostics.Debug.Assert`（`DEBUG`）在 Release Web build 全部整段編譯掉，退化成靜默通過，正是本條要防的事。必須是**無條件 throw** | MVP | Logic／自動化（BLOCKING）**＋靜態檢查**：`NightShift.ProductDatabase` 組件內不得出現上述三個符號。⚠ r2 刪除「測試矩陣須涵蓋 Release define 組合」——EditMode 在 Editor 裡跑，`UNITY_ASSERTIONS` 恆為真，**那條證據永遠產生不出來**；靜態檢查是唯一撐得住的替代 |
| AC10 | **空家族查詢**。GIVEN 零筆 `active` 的家族，WHEN 呼叫 `GetByMachineFamily()`，THEN 回傳空陣列，不丟例外 | MVP | Logic／自動化（BLOCKING） |
| AC11a | **查詢對筆數無感（合成資料）**。GIVEN 一份只追加一筆條目 `e` 的合成資料集，WHEN 重跑查詢，THEN `Get(e.network_index)` 回傳 `e`；**`GetByMachineFamily(e.machine_family)` 的結果集恰等於原結果集 ∪ {e}（順序不論），而其餘三個家族的結果集逐一不變**；`GetOrderable()`／`GetNameable()` 依 `e` 是否滿足各自的述詞（`Active`／`Active && nameable`），分別適用上述兩種情形之一；且對一組固定的 N 筆 `(instance, demand)` 迴歸向量，`Matches()` 的回傳值**逐一不變** | MVP | Logic／自動化。⚠ **r3 改寫**：r2 的版本按字面為假——`∪ {e}` 只對 `e` 自己的家族成立，對其餘三個家族會錯誤地要求包含 `e`；而緊接的「同理」在四個查詢裡**三個不成立**。✅ **已由原型執行確認**（探針 `AC11a-R2CLAIM`）：加入一筆 Oden SKU 後，CoffeeMachine 家族預期 2 筆、實得 1 筆。⚠ **另**：`Matches()` 的迴歸向量必須跑在**真實實作**上，不得跑在 `FakeProductCatalog` 上——這是純函式移出 `IProductCatalog` 的直接理由（見 Interactions） |
| AC11b | **無 per-SKU 硬編**。GIVEN `NightShift.ProductDatabase` 的原始碼，THEN 不存在以 `sku_id`／`network_index` 為分支的 `switch`／`if` 鏈，亦不存在自動產生的 per-SKU enum | MVP | Logic／靜態掃描（Roslyn 或 regex）。⚠ r2 改寫：原本的證據型別是「CI PR 規則」，但本 repo 無 `.github/workflows/`，且 230 個 commit 只有 1 個 merge、直推 main——**那條 GIVEN 掛在一個本專案不實行的工作流上**。「diff 不含 `.cs` 變更」也不是測試能觀測的性質（那是 diff 的性質），且會被「順手修個 typo」誤判 |
| AC12 | **准入審查（適用門檻全通過）**。GIVEN 一筆新提案 SKU，WHEN **作者 ＋ creative-director 兩方獨立**依**適用**門檻逐項審查，THEN 產出審查紀錄存於 `production/qa/evidence/product-database/sku-admission/[sku_id].md`（範本 `_template.md`），**強制欄位包含**：①每條適用門檻一行 `gateN_verdict:` ＋理由（不適用者填 `N/A`） ②**商標查核：TIPO 商標檢索的查詢字串、查詢日期、結果筆數** ③指名 SKU 須記錄門檻 6 對**最終匯入資產**（非草圖）的測試結果 ④**門檻 7 的同家族可互換性判斷，逐一列出當時同家族的其他 SKU**（r3 新增） ⑤**新鮮度：`label_at_review`（當時的 `display_label`）與 `icon_hash_at_review`（當時受測 icon 來源資產的內容雜湊）**（r3 新增）。意見不一致時升級 game-designer 裁決。適用門檻全通過才可標 `Active` | MVP | 內容審查紀錄（Design Review），**但其存在性與新鮮度由 AC12b 機器化**。⚠ r2 三項修正：指名第二審查者（本專案是 solo，「至少 2 人」不可執行；而實際抓出思樂冰／大亨堡的就是 CD）、指名商標來源（否則會被填成「Google 過了」）、以及**門檻分級**（見下）。⚠ **r3 新增欄位 ⑤ 的理由**（四份報告獨立提出，三份評為本輪最高嚴重度／成本比）：門檻 1／3 稽核的是**當時那個字串**的音韻性質，門檻 6 稽核的是**當時那張圖**的剪影——**改了標籤或改了 icon 稿，審查紀錄就靜默失效，而檔案還在、AC12b 還是綠的**。症狀是「尖峰偶爾拿錯東西」，**一個永遠會被歸因成『玩家太忙』的 bug，playtest 抓不到** |
| **AC12b** | **審查紀錄存在且已被填寫（r2 新增，r3 修正判準與層級）**。GIVEN 每一筆 `Active` SKU，THEN `production/qa/evidence/product-database/sku-admission/[sku_id].md` 存在且可解析；且**每一條適用門檻各有一行 `gateN_verdict: PASS｜FAIL｜N/A`**（`N/A` 僅對不適用門檻合法，依「門檻的適用分級」判定）；且**無任何適用門檻為 `FAIL` 或缺漏**；且**新鮮度欄位** `label_at_review` 等於現行 `display_label`、`icon_hash_at_review` 等於現行 `icon_ref` 來源資產的內容雜湊 | MVP | Logic／自動化。⚠ **r3 三項修正**：①**判準被範本打穿**——`_template.md` 的標題字面就是 `## gate1: PASS / FAIL / N/A ——`，於是 `cp _template.md [sku_id].md` **一個字不填就通過**。r2 造這條 AC 的全部用意是把「人有沒有判斷過」機器化，而判準在範本第一行就失效。已改為獨立的 `gateN_verdict:` 鍵，並要求範本標題行**不得含 `PASS` 字樣**。②`N/A` 原本不被接受，但分級表明確允許——按字面家族填充型必 FAIL。③**層級由 MVP-必達降為 MVP**：依本文件自己 `:721-722` 的 gate 定義（「gate 的定義性質是 commit 時提交者無法控制它」），solo 專案裡寫 SKU 的人 ＝ 寫審查檔的人，**AC12b 不滿足它自己的定義，它是 lint 不是 gate**。擋建置買到的增量只有「連檔案都沒建」。⚠ **但不刪除**——solo 的真實失敗模式是「忘記」，而 AC12b 對「忘記」有效；AC12 的 TIPO 商標查核欄位**維持強制** |
| AC13 | **槽位分配**。GIVEN `ProductMatching.AllocateSlot(catalog, slots, filled, instance)`，THEN 逐案例回傳預期索引：①同時符合 Named 與 Family → Named 槽索引 ②兩個 Named 指向同一 SKU，連續兩次交付 → 先填索引較小者、再填另一個 ③三槽混合，依 Edge Cases 的交付序 → 0／1／2 ④**跨家族混合**：訂單 `[0]=Family:Oden, [1]=Named:某咖啡`，交付一份新鮮咖啡 → **`1`**；交付一份新鮮黑輪 → **`0`** ⑤商品不匹配任何槽（訂單 `[Family:Oden, Named:米血]`，交付咖啡）→ `-1` ⑥零槽 → `-1` ⑦**`filled.Length != slots.Length` → 拋 `ArgumentException`** | MVP | Logic／自動化。⚠ **r3 三項修正**：①案例 ④ 原本**只有標題、沒有期望值**，QA 無從判定 pass/fail；②新增案例 ⑦，r2 為了讓本條可測而加入的 `filled` 參數原本**六個案例沒有一個真的行使它**；③案例 ⑤ 的措辭釘死，它現在是「資格述詞」那一行的驗收。⚠ **只覆蓋規則本身，不解除 #15 的整合測試義務**；且**不涵蓋跨訂單分配**（歸 #4） |
| AC14 | **資料層純度**。GIVEN 已編譯的 `NightShift.ProductDatabase` 組件，THEN ①**以 `CompilationPipeline.GetAssemblies(AssembliesType.Player)` 遞迴展開 `assemblyReferences` 求傳遞閉包**，該閉包不含 `Unity.Netcode.Runtime`、`UnityEditor`、與 `NightShift.ProductDatabase.Editor`；②`ProductEntry`／`ProductInstance`／`CustomerDemand` 皆 `IsSubclassOf(typeof(UnityEngine.Object)) == false`；③EditMode 測試可僅以建構子注入 POCO 陣列完成 catalog 建構並呼叫 `Get()`，且 `Matches()`／`AllocateSlot()` 可**完全不建構 catalog**即呼叫 | **MVP-必達**（下游三個硬依賴系統 testability 的前提） | Logic／自動化＋反射。⚠ **r3 修正 ①**：r2 把正確工具寫進了註腳，**斷言本體卻原封不動留著 `Assembly.GetReferencedAssemblies()`**——而該 API (a) **定義上不遞移**（只回傳直接 AssemblyRef），(b) 反映的是**編譯結果**而非 asmdef 宣告，Roslyn 會剔除未實際使用的 reference，於是 asmdef 明明引用了 NGO 也可能查不到。**一條 MVP-必達防線保護為零且恆綠。** 這是本文件通篇指控 r1 的「改了定義處、漏了引用處」在 r2 自己的修正裡復發。⚠ **r3 修正 ③**：改寫以反映純函式已移出 `IProductCatalog`。⚠ r2 原有兩項修正（否定式斷言改反射、不得文字 grep `.asmdef`）維持有效 |
| **AC15a** | **enum 宣告未被更動（r2 新增——今天就能亮紅燈，不需 SKU、不需資產、不需 build）**。GIVEN 快照檔中**以 `frozen_enum:` 為鍵**的區塊，WHEN 以 `Enum.GetNames`／`GetValues`／`GetUnderlyingType` 讀取**本組件中每一個標了 `[FrozenEnum]` 的 enum 型別**，THEN **①雙向**：快照的每一組 `(型別, 名稱, 整數值)` 在現行宣告中存在，**且現行宣告的每一組在快照中存在**（只允許以「新增列」的方式擴張，缺列即失敗）；**②**每個型別的 underlying type 與快照一致；**③**若快照檔缺席或 `frozen_enum:` 鍵不存在，**直接失敗**，不得視為通過 | **MVP-必達** | Logic／自動化＋反射。⚠ **r3 四項修正**：①**`frozen_enum:` 這個鍵在快照檔裡根本不存在**——該檔只有第 32 行的註解 `# frozen_enum — …`，一個找鍵的 parser 會找不到。**全文件唯一被宣稱「今天就會亮紅燈」的絆線，指向一個不存在的 referent。** ②**方向未指明**：r2 只寫「與快照一致」，若以快照為域，**刪掉整個區塊即恆真通過**——一次「順手清理」就能關掉它。已釘死為雙向。③**硬編四個型別名**改為 `[FrozenEnum]` 屬性掃描——硬編正是 AC3 在一列之前才剛修掉的缺陷（新增第五個 enum 時本條會靜默地不再涵蓋它）。④**補 underlying type**：規則 1c 明文禁止序列化型別變更，而全文零 AC 覆蓋 |
| AC15b | **資產整數值未錯位**。GIVEN AC1a 快照的 `(sku_id → machine_family 整數值)`，WHEN 讀取現行資產，THEN 一致 | **MVP-必達** | Logic／自動化（BLOCKING）。⚠ **比對整數值，名稱只作人類可讀註解**——r1 比對名稱，於是一次無害的更名（`Oden` → `OdenPot`，整數不動）會亮紅燈，而開發者解除它的方式是「重新產生快照」；**一條假陽性的解法恰好就是它真陽性的破解法的測試，期望值是負的** |
| AC16 | **查詢只回 Active**。GIVEN 某家族底下同時有 `Active` 與 `Deprecated` 條目，WHEN 呼叫 `GetByMachineFamily()`／`GetOrderable()`／`GetNameable()`，THEN 回傳集合**不含任何 `Deprecated` 條目**；且連續兩次呼叫同一查詢 `ReferenceEquals` 為 true（快取契約） | **MVP-必達** | Logic／自動化（BLOCKING）。⚠ r2 補快取斷言——原本「算一次並快取」是一條用來論證設計選擇的效能契約，零證據要求 |
| **AC18** | **層級標記（r2 新增，r3 改寫量詞域與判準）**。**①存在性**：`Ui_IconTier_Family` 與 `Ui_IconTier_Named` 兩張來源資產皆存在。**②合成數**：`Atlas_Ui` 的 packables 中，每一顆 `Ui_Icon_*` 恰好合成其中一張。**③層級正確**：`Ui_Icon_[family]` 合成的必須是 `_Family`，`Ui_Icon_[sku_id]` 合成的必須是 `_Named` | **MVP-必達** | Logic／自動化。⚠ **r3 三項修正**：①量詞域改掉——r2 寫「每一顆需求 icon 的 **prefab**」，但 `icon_ref` 的型別是 **Sprite**、家族 icon 靠 enum 名推導，**全文從未定義過「需求 icon prefab」這個資產類別**，資產表也沒有這一列，於是「每一顆」**沒有可列舉的集合**；改以 `Atlas_Ui` 的 packables 為域。②r2 那句「量詞域是兩個具名資產，不會被髒資料清空」**只覆蓋子句 ①**，子句 ② 仍可被清空——已如實標示。③**新增子句 ③**：層級是 icon 的**確定性函數**，所以**掛反是可偵測的**，而 r2 的版本只數數量不驗對錯——掛反可以 100% 通過 AC18、門檻 5 與 AC12b，然後教玩家一條與規則相反的隱藏規則 |
| **AC19** | **`Deprecated` 不得持有資產引用（r2 新增，服務規則 2 的清 null 裁決）**。GIVEN 每一筆 `Deprecated` 條目，THEN `mesh_ref` 與 `icon_ref` 皆為 null | **MVP-必達** | Logic／自動化（BLOCKING） |
| **AC20** | **指名池花色上下限（r2 新增上限，r3 補下限）**。GIVEN 現行 SKU 表，THEN `2 ≤ count(nameable == true) ≤ sku_nameable_max`（6） | MVP | Logic／自動化。⚠ **下限是 r3 補的，而它防的是一個 30 條 AC 全綠的失敗**：r2 只 levy 了上限，於是三條個別正確的修法合起來會讓指名池在整個 MVP 期為空，**而 AC4 對空集合恆真、AC20 恆真、AC3 不受影響**。⚠ 本條在首批內容進表前為紅燈，那是正確行為，處置同 AC3 |
| **AC22** | **`ProductInstance` 的兩個欄位在 `Spawn()` 之前寫入（r3 新增）**。GIVEN 兩個獨立行程（host ＋ 一個在物件 spawn **之後**才加入的 client），WHEN #5 產出一份商品並交接，THEN 接收端讀到的 `network_index` **從不為 0**、`is_spoiled` 與 host 端一致；且在 `network_tick_rate` 調到 **1Hz** 時結果不變 | **MVP-必達** | Integration／PlayMode **雙行程**。⚠ **本條不得以單機或 host-only 測試代替**——那正是這個缺陷唯一看不見的地方。1Hz 那一句是判別器：若實作誤把值寫在 `Spawn()` **之後**，它是 tick-gated delta，1Hz 下窗口被放大 10 倍必然暴露；10Hz 下窗口約 100ms，恰好與實測交接時間同量級，**測十次可能十次都綠**。⚠ 屬 W2 原型項，非本系統可獨立完成 |
| **AC23** | **`ProductInstance` 無法被建構成「忘記蓋章」的狀態（r3 新增）**。GIVEN `ProductInstance` 型別，THEN 無 `public` 無參數建構路徑、無 `public` 欄位設值器；且 `ProductInstance.Create(networkIndex, isSpoiled)` 是唯一公開建構點，兩個參數皆必填；且 `Create(0, _)` 拋例外 | MVP | Logic／自動化＋反射。⚠ 這一條補的是 `server-write` 守不住的那一半：**它約束誰寫與何時寫，完全不約束「有沒有人寫過」**。⚠ 與 AC6c 同理，`default(ProductInstance)` 在 C# 仍可達；宣稱為「無法**意外**建構」，`network_index == 0` 由 AC9 的哨兵攔截 |

### 「BLOCKING」的兩軸（r3 重寫——r2 的整批降級把兩件不同的事綁成一件）

⚠ **r2 寫的是一句整批降級**：「AC1a／AC1b／AC2a／AC2b／AC3／AC4／AC4b／AC4c／AC6c／
AC12b／AC15a／AC15b／AC18／AC19／AC20 的 BLOCKING 效力取決於 ADR-XXX，在它落地之前
這些條目的實際效力為 ADVISORY。」**那句話把 15 條掃進同一個桶，而其中至少一條根本
不屬於那個桶**：**AC6c 是一條型別建構測試，build hook 對它無事可做。**
一張整批掃入、而非逐條推導的清單，其後果是這 15 條在 sprint review 裡**沒有一條擋得住
標 Complete**，而且豁免現在有文件背書，比個案豁免更難撤銷。

**改為兩個獨立的軸。一條 AC 可以在一軸上生效而在另一軸上待命：**

| 軸 | 定義 | 今天生效嗎 | 適用 |
|---|---|---|---|
| **軸 1：證據閘** | 依 `.claude/docs/coding-standards.md`，Logic 型故事**沒有通過的自動化測試就不得標 Done**。它約束的是**驗收**，與能不能按 Build 無關 | **是。今天就生效，不降級** | **每一條標 Logic／自動化的 AC**，含全部 15 條 |
| **軸 2：建置期強制** | 驗證邏輯**同時**存在於 `IPreprocessBuildWithReport.OnPreprocessBuild`，使不跑測試的人也擋得住 | **否**，取決於 ADR-XXX（owner: technical-director ＋ devops-engineer） | 只有**資料不變量**適用：AC1a／AC1b／AC2a／AC2b／AC3／AC4／AC4b／AC4c／AC12b／AC15a／AC15b／AC18／AC19／AC20。**AC6c 不在此列**（它驗的是型別，不是資料） |

**為什麼必須拆**：r2 把 `coding-standards` 的 BLOCKING **重新定義**成「必須同時存在於
測試與 build hook」，然後因為 hook 不存在而整批降級。但 `coding-standards` 的 BLOCKING
是一道**證據閘**，而且**今天就能跑**——AC17a 自己就證明了驗證邏輯是純函式、
不需要 build、不需要內容、不需要資產。
**降級軸 2 是誠實的；把軸 1 一起降級是把一條今天做得到的紀律送掉。**

✅ **軸 1 今天就跑得動，已由原型證明**（`prototypes/product-database-core/`）：
`ProductCatalogValidator.Validate()` 在**零 Unity、零資產、零 build、零 SKU 內容**的
情況下，對 AC1b／AC2a（含門檻分級）／AC2b／AC3／AC20 全部產出可斷言的 `Violation`，
合成汙染資料集逐條亮紅、乾淨資料回空集合。**AC17a 的規格是準的。**

**為什麼 AC17 不能留在 AC 表裡**：本文件自己說那件工作「沒有任何系統擁有」
「不得吸收進『實作商品資料庫』的估算」，OQ-P11 的 owner 是別人，且 OQ-P11 明寫
它「擋 AC17 的可實作性」。**一條「本系統被禁止建造」的 AC 不是 acceptance criterion，
是別的工作項的 exit criterion 穿著 AC 的文法。** 留著只有兩種結局：#6 永遠 Done 不了，
或它在 sprint review 被豁免、把 RC-2 原狀還原——外加一張寫著「已處理」的紙。
**明示的降級關掉那條豁免路徑，因為降級現在是寫下來的，不是默默發生的。**

**兩條仍屬本系統、且今天就寫得出來的替代 AC**：

| # | 準則 | 層級 | 證據 |
|---|---|---|---|
| **AC17a** | **驗證器本身正確**。GIVEN `ProductCatalogValidator.Validate(entries, snapshot) -> IReadOnlyList<Violation>` 這個純函式，WHEN 餵入每一條不變量各一份**刻意汙染**的合成資料集，THEN 各回報恰好一條對應的 `Violation`；乾淨資料回空集合 | **MVP-必達** | Logic／自動化。**不需要 build、不需要內容、不需要資產** |
| **AC17b** | **鉤子確實接上了**。GIVEN 編譯後的 Editor 組件，WHEN `TypeCache.GetTypesDerivedFrom<IPreprocessBuildWithReport>()`，THEN 恰好含一個本專案的驗證鉤子型別；建構它並以汙染資料集呼叫 `OnPreprocessBuild`，THEN 拋 `BuildFailedException` | **MVP-必達** | Logic／自動化＋反射。**這一條抓的正是 RC-2 的實際失敗模式——「驗證器存在但沒接上」——而且不需要呼叫 `BuildPlayer`**（一次 Web build 數分鐘，且不支援在測試執行中重入） |

⚠ **AC17 原本標 BLOCKING，而 BLOCKING 的定義是「驗證邏輯必須同時在 build hook 裡」
——套用到它自己身上就是「build 閘門必須包含一條檢查 build 閘門是否存在的檢查」。
那不是悖論，是啟動失敗：閘門缺席的那一刻，正是它無法偵測自己缺席的那一刻。**
唯一非循環的執行者在 repo 之外（CI、pre-push hook、release checklist），
而那三者目前都不存在。AC17b 是**能做到的最接近**：它偵測「型別不存在」，
只是仍需要有人去跑它。

### 測試夾具規格

- **測試組件分成兩個**（r2 新增，否則 AC14 會被讀成禁止 AC1a/AC3/AC4/AC15b 所需的測試）：
  - `NightShift.ProductDatabase.Tests.EditMode` — **純**，不碰 `AssetDatabase`，
    涵蓋 AC5-AC11a／AC13／AC14／AC16／AC17a。
  - `NightShift.ProductDatabase.Tests.EditMode.Content` — 掃資產，涵蓋
    AC1a／AC1b／AC3／AC4／AC4b／AC4c／AC15b／AC18／AC19／AC20／AC17b。
  - 驗證邏輯本身住在第四個組件 `NightShift.ProductDatabase.Editor`
    （`includePlatforms: ["Editor"]`、**`defineConstraints: []`**），由測試與 build hook
    **共用**。⚠ 這個組件沒有出現在 Interactions 的 asmdef 表裡，但「共用同一份驗證
    邏輯」這條要求**必然**產生它——`AssetDatabase`／`TextureImporter` 是 Editor-only，
    不能住在 runtime 組件。AC14 須另外斷言 runtime 組件**不**引用它。
- **AC4 等資產檢查**：透過 `mesh_ref`／`icon_ref` 的**序列化引用**，不掃檔案系統。
  尺寸量測對象為**來源資產的 `TextureImporter`**，不是執行期 `Sprite`（圖集會騙人）。
- **AC11a 合成資料集**：以 `FakeProductCatalog : IProductCatalog` 實作，建構子直接吃
  `ProductEntry[]`，**不碰 `AssetDatabase`、不建立 ScriptableObject**。
- **AC1a／AC15a／AC15b 快照**：`design/registry/sku-shipped-snapshot.txt`。
  **它是資料治理 artefact，不是測試夾具**——放 `design/registry/` 而非 `Tests/`
  （後者重構時容易被清掉）；測試只讀取比對，不擁有它。
  ⚠ 它在 `Assets/` 之外，所以 `AssetDatabase` 讀不到，須以 `System.IO` 相對
  `Application.dataPath` 存取；這使 AC1a／AC15b 成為**檔案 I/O 測試**，
  與 `.claude/docs/coding-standards.md`「Unit tests do not call … file I/O」有張力。
  **明示承認：這兩條是資料治理檢查，不是單元測試**，放在 `.Content` 組件裡。

#### 真空與其對策（r2 重寫——r1 只做到承認）

r1 寫下「⚠ 在快照建立之前，AC1／AC15 對空集合恆真通過——這是已知且已承認的狀態，
不是『已經稽核過』」。那句話是誠實的，**但它不是解法**：一條不可能失敗的測試不是證據，
而警語住在 GDD 裡、gate 讀的是**測試結果**——**警語不會跟著 artifact 走**。
更糟的是**真空窗口正好是風險窗口**：enum 重排最可能發生在初次內容撰寫期，
也就是這道防線關著的那段時間。而 Bootstrap 規則掛在「PR」上，
但本 repo 230 個 commit 只有 1 個 merge、直推 main——**那不是本專案實行的工作流**。

**對策（今天就做得完，不需 Unity 專案、不需內容、不需 CI）**：

1. **立刻建立快照檔，空的，但帶 `frozen_enum:` 區塊。** ✅ 已建立。
   ⚠ **但 r2 建出來的那個檔並不符合它自己的規格**（r3 評審）：`frozen_enum` 只出現在
   一行**註解**裡（`# frozen_enum — …`），**不是可解析的鍵**，而 AC15a 的 GIVEN
   寫的正是「快照檔的 `frozen_enum:` 區塊」。**全文件唯一被宣稱「今天就會亮紅燈」的
   絆線，指向一個不存在的 referent。** 已於 r3 修正為真正的鍵，並補上 underlying type。
   ⚠ **而且那個檔在 git 裡是 untracked（`??`）**——**沒進版控的 tripwire 不是 tripwire。**
   已 `git add`。
2. **AC1a 改為 append-only 事件日誌**（r3 取代 r2 的「加雙射子句」）。
   r2 的雙射在**第一次下架時三路全封死**（見 AC1a 的 ⚠），而唯一出口是被明令禁止的
   「重新產生」——**且重新產生會順帶清空 AC15a**。事件日誌讓下架就是追加一列。
   雙射降為單向子句（現行表每筆至少有一列 `ADDED`）。
3. **AC1b 不依賴快照**（已拆出）：`sku_id`／`network_index` 唯一性、
   `network_index != 0`、`status != Invalid` 從第一列就有效。
   ⚠ r1 把「依賴快照的斷言」與「不依賴快照的斷言」綁在同一條 AC 裡——
   一個寫成「載入快照，對每一列……」的測試會在檔案缺席時提早返回，
   **把唯一性檢查一起帶走。真空是會傳染的。**
   ⚠ **但 r2 接著把 AC1b 列為「不受真空影響」，那是假的**——它的量詞域是現行 SKU 表，
   零列時恆真。**真空期真正活著的只有 AC15a 與 AC17a 兩條。**
4. **快照工具「不得有重新產生模式」降為作業慣例**（r3），不再要求為它建強制機制。
   理由是本文件自己的 gate 定義：一個與資料同 repo、由同一人維護的工具限制**是 lint
   不是 gate**。為它建機關，是一個 solo 開發者為防他自己造的機關。
   ⚠ **判準一致性**：這與 AC12b 由 MVP-必達降為 MVP 用的是同一條判準。
5. **build hook 追加一條**：SKU 表非空而快照檔缺席 → `BuildFailedException`。
   ⚠ **r3 修正觸發條件**：r2 寫的是「SKU 表**非空**而快照缺席」——而真空期的定義
   就是 SKU 表為空，**所以這條補救在它最需要的那段時間恰好不觸發**。
   改為：**快照檔缺席、或 `frozen_enum:` 區塊缺席，一律失敗，與 SKU 表是否為空無關**
   （已寫進 AC15a 子句 ③）。

### 七條准入門檻的可自動化程度（誠實標示）

| 條 | 頻道 | 可自動化？ |
|---|---|---|
| 1. ≤4 漢字喊得完 | 口語 | **可**——AC2a（`StringInfo.LengthInTextElements`）。⚠ **但它的拒絕率在構造上約為零**（r3 評審，game-designer）：代入本文件出現過的十個品項，**十個全部放行**，包括必須被拒絕的「思樂冰」與「大亨堡」。**它不得被當成自動化守門的證據**——它擋的是打錯字，不是擋不合格的內容 |
| 2. 不看畫面就知道是什麼 | 口語 | **不可**——聽覺辨識＋常識判斷 |
| 3. 不與表內品項**聽**錯 | 口語 | **部分**——注音／拼音編輯距離掃出疑似衝突供人工複核。⚠ 腳本量測的是「安靜狀態讀字串像不像」，實際情境是**吵雜環境用語音喊**，兩者不是同一個問題；且新增 SKU 須對全表重跑 |
| 4. 秒懂但不屬於任何一家 | 口語 | **不可**——但 AC12 強制商標查核欄位，把直覺轉成流程 |
| 5. 層級可辨 | 視覺 | **可**——**AC18** 三個子句（兩張 `Ui_IconTier_*` 存在 ＋ 合成數 == 1 ＋ **層級掛對**）。⚠ r1 標「AC4 的延伸」是**假的**：AC4 只查檔名與尺寸，讀不到一個像素。r2 改成獨立合成資產之後這句「可」才變成真的。⚠ **r3 再補子句 ③**：r2 的版本只數數量不驗對錯，**掛反可以 100% 通過** |
| 6. 花色不撞 | 視覺 | **部分**（r3 由「不可」上修）——**機器前篩**（降取樣＋二值化＋IoU／Hu moments）掃出疑似衝突供人工複核，與門檻 3 的注音距離腳本**同位階、同理由**；**里程碑級**三人素人測試才是 pass/fail。⚠ r2 只寫了人測那一層，而它在 solo 專案裡**不可執行**——「未看過此 icon 集」的觀察者是一次性消耗品，10 次迭代需 30 位素人，**而本文件在 AC12 砍掉第二審查者時用的正是同一條理由**。⚠ 重跑義務需要機器看得見的觸發器，見 AC12b 的新鮮度欄位 |
| 7. 同家族可互換 | 語意 | **不可**——人工判斷。但它是**專為常態路徑而設的唯一一條守門人**：門檻 1、3、5、6（連同 AC4／AC18／AC20）的量詞域全是 `nameable` ＝ 少數路徑；家族填充型原本只剩門檻 2、4，而兩條都不可自動化。規則 3 明訂家族級需求才是多數路徑 |

⚠ **文字有查重（AC2b），圖形的查重是人工（AC12 第③欄）。** 文字是玩家「讀」的管道，
icon 是尖峰時「瞄」的管道——**高風險的那一半沒有自動化守門人**。
r2 的對策不是假裝它可以自動化，而是**把「人有沒有判斷過」機器化**（AC12b）：
判斷留給人，判斷的**存在性**變成擋建置的。這正是 AC4 對 icon 用過的同一招，
r1 想到了對 icon 用，沒想到對審查本身用。

#### 門檻的適用分級（r2 新增）

r1 的 AC12 寫「六條全通過才可標 `active`」，但**其中四條對非指名 SKU 沒有指涉對象**：
門檻 5、6 管的是 icon，而非指名 SKU **沒有自己的 icon**（家族 icon 是每家族一個）；
門檻 1、3 服務的是「被喊出來」，而非指名 SKU 的 `display_label` 永遠不是玩家喊的需求
——它只出現在 #13 的逐項列表，適用的是較寬鬆的 6 字上限。
**於是對表中多數條目，兩條門檻空洞、兩條門檻過緊，而 AC 要求六條全過。**

| SKU 類型 | 適用門檻 | 標籤上限 |
|---|---|---|
| 家族填充型（`nameable == false`） | **2、4、7**（秒懂 ＋ 非品牌 ＋ **同家族可互換**） | `sku_display_label_max_chars`（6） |
| 指名型（`nameable == true`） | **1-7 全部** | `sku_holler_max_chars`（4） |

這同時把內容審查成本砍掉約一半，而砍掉的正是**回報最低**的那一半
（依規則 3，家族級需求下同家族 SKU 完全可互換，逐 SKU 的辨識在常態路徑上不產生決策）。

⚠ **AC2a 必須跟著這張表分兩級，而 r2 漏了**（r3 評審，四份報告獨立命中）：
r2 寫下這張分級表、給家族填充型 6 字上限，但 **AC2a 仍對「每一筆 `Active` SKU」
斷言 ≤4 且是自動化 BLOCKING**，規則 1 的欄位表也還寫著「實務上生效的是 4」。
**三處三種說法，而不一致的那一個正是 r2 自己新加的。** 首批內容進表當天，
第一筆 5 字的家族填充型 SKU 就會被擋下，而解除它最順手的動作是**調鬆
`sku_holler_max_chars`**——也就是調鬆唯一一條真正自動化的口語門檻。已於 r3 同步三處。

⚠ **門檻 1 的「一格落差」不再列為缺陷**（r3 裁決，accessibility-specialist ＋ ux-designer）。
r2 寫「散文說 2-3 音節、檢查放行 4 音節」——但散文裡的「2-3 音節」是**例示**，
不是規範；把例示當規範再去要求檢查與它對齊，是**過度解讀**。
**裁決：維持 `sku_holler_max_chars = 4`，明確不回填為 3**，散文措辭統一為「≤4 音節」。
若 #7 落稿後實測發現 4 字仍太鬆再收。

### 延後（宿主系統尚未存在）

- **`deprecated` 的 `sku_id` 被其他資料表引用 → 擋建置**：掃描對象（波次配置、
  教學腳本）隨 #7／#8 落稿後才存在。不變量已寫在 Edge Cases，測試待宿主出現後補。

（原本列在此處的「槽位分配規則」已移除——r1 評審指出它是**全函式、不依賴任何下游資料**，
「宿主不存在所以測不了」對它為假。現為 **AC13**。⚠ 把一個假理由與一個真理由並列在
同一組 bullet 裡，是真缺口被鄰近的正當理由洗白的典型路徑，此處已拆開。）

#### 為什麼 r2 沒有把評審提出的三十條新 AC 全部收進來

r2 評審共提出約 30 條新 AC。本文件**只採納其中量詞域「不會被它所偵測的錯誤清空」
的那些**（AC1b、AC4c、AC15a、AC17a、AC17b、AC18、AC3 的 ∀ 改寫，以及幾條把既有
AC 改成可證偽的重寫）。

理由：**往一個還不存在的閘門上加 AC，買到的不是安全，是「將來要被豁免的東西」**，
而且會讓 **AC 數量變成覆蓋率的反指標**。閘門的 ADR 落地後再重開 AC 集合。
這條判準本身來自 r2 的交叉引用綜合——六條被閘的不變量裡有五條，
量詞域是由它們所稽核的資料**推導**出來的，所以**資料越髒、覆蓋越小**。

### 刻意不設 AC

- **規則 4「單一真相源的射程」**：架構治理原則，不是可由 QA 獨立驗證的行為。
  可留痕的形式是靜態掃描（三個核心型別全 codebase 只能有一份定義），
  但目前無下游程式碼，現在寫也是恆真通過。待 #5 落地後補。
- **Overview 的「不用重出 build」澄清**：界定承諾邊界，不是承諾一個行為。
  為它寫 AC 等於「測一個不存在功能的缺席」。
- **初版 20-40 筆 SKU 內容的產出排程**：r1 評審提出，但 **GDD 不是排程**。
  這屬 systems-index／sprint plan，不屬本文件。⚠ 但 AC1a、AC3、AC4、AC11a、AC15b
  全部預設「現行 SKU 表已有內容」——在內容進 repo 之前，它們停在
  「規格已定義、無資料可測」。

  ⚠ **r2 在此處寫了一句自我評分，而它是假的**（r3 評審，五份報告各打一條；
  終審評為本輪第二被低估）。原文是：「**AC1b、AC15a、AC4c、AC17a、AC17b、AC18
  不受此限，因為它們的量詞域是 enum 宣告或具名資產，不是 SKU 表。**」
  **六條裡有四條不及格：**

  | 條 | 宣稱 | 事實 |
  |---|---|---|
  | **AC1b** | 不受真空影響 | **假**。它的 GIVEN 就是「現行 SKU 表」，零列時**全部子句恆真通過**。「不依賴快照」≠「不受真空影響」，r2 把兩者混為一談 |
  | **AC15a** | 量詞域是 enum 宣告 | **半真**。方向未指明：若以快照為域，**刪掉 `frozen_enum:` 區塊即恆真通過**——一次「順手清理」就能關掉全文件唯一活著的絆線。已於 r3 釘死為**雙向**比對（見該條） |
  | **AC18** | 具名資產，不會被清空 | **只對子句 ① 成立**。子句 ②／③ 的量詞域是 `Atlas_Ui` 的 packables，清空 atlas 即恆真 |
  | AC4c／AC17a／AC17b | — | **成立**。量詞域分別是 enum 宣告、合成汙染資料集、編譯後型別 |

  **為什麼這一句話比它底下的四條 AC 更值得修**：一句假的自我評分**比沒有自我評分更糟**，
  因為它會關掉下一位讀者的推理。而它是本文件真空對策的唯一支柱——
  **若它為假，這份文件今天真正活著的絆線是 1 條（AC17a，而且還沒有人寫），不是 5 條。**
  ⚠ 而這正是 r2 自己立下的「量詞域不會被它所偵測的錯誤清空」那條判準——
  **它用那條判準砍掉了約 30 條候選 AC，卻從來沒有回頭掃過自己的產出。**

## Open Questions

| # | 問題 | 來源 | 擁有者 | 擋不擋進度 |
|---|---|---|---|---|
| OQ-P1 | **需求 icon 的分類基底要重新核對，不只是補兩個洞**。美術聖經 §3.3 的四個既有 icon（碗／杯／條碼／箱）**不是為 `machine_family` 畫的**——它們是為「服務類型」畫的，只有碗、杯字面重疊；條碼是每張單共通的結尾動作、箱是包裹代收。`Microwave`／`Shelf` 無對應符號。⚠ **r3 更新**：層級標記的具體形式**已由 art-director 裁定**（Ink 挖空方塊／橫條，見 Visual/Audio），本 OQ 只剩**家族 icon 的分類基底**這一半。而 art-director 的形狀預算把家族 icon 算成 **6 顆**（四個 `machine_family` ＋ 結帳條碼 ＋ 包裹箱），其中 `Microwave`／`Shelf` 兩顆**不存在** | r1 評審（ux-designer＋game-designer）；r2 上修等級；r3 縮小 | art-director ＋ #11 | ⚠ **r3 再上修：它現在擋的是內容進表本身。** AC4c 使缺家族 icon 即擋建置，而 `nameable` 下限已裁為 2，所以指名 icon 也必須存在。**首批 SKU 進 `Active` 的前置條件 ＝ 6 顆家族 icon ＋ 2 顆指名 icon ＋ 2 張層級標記。** 另**擋 #11 HUD 與 #7 客人系統** |
| OQ-P2 | **手持商品的 poly 級距未定**：§8.2 只有「機台類互動道具 ≤400 tris」與「貨架/環境模組 ≤150 tris」兩列，**沒有「手持商品」這一列**，兩者差 2.7 倍 | unity-specialist 體積估算 | art-director | 不擋；**擋美術資產開工** |
| OQ-P3 | **兩個相乘的上限未定**：`nameable` 筆數上限（美術工時）× 同時在場相異需求符號數上限（可讀性）。⚠ **只有本表同時看得到兩個因子**——#7 只看得到並發、#11 只看得到池子 | 本 GDD Tuning Knobs ＋ r1 評審 | art-director ＋ #7 ＋ #11 | 不擋 |
| OQ-P4 | **SKU 總筆數 20-40 是估的，不是推導的**。⚠ **r2 改寫問法**：「一個家族內幾種東西才有變化」問錯了——家族級需求下同家族完全可互換，所以該問的是 **\|nameable\| 與 \|相異加工剖面\| 各是多少**（那是 #7／#5 答得出來的問題）。可辯護筆數 ≈ 4 ＋ 兩者聯集，實際落點可能在 **12-20** 而非 20-40。⚠ 上界是會被填滿的，所以 registry 的 `sku_count_target` 已標為待重新推導。**並附一條可稽核的准入判準**：一筆不 `nameable`、且在 #5 沒有相異加工剖面的新 SKU，應改為 §5.1 的背景排面，不進本表 | 本 GDD；r2 改寫 | #7 ＋ #5 ＋ #8 設計時回填 | 不擋 |
| OQ-P5 | **是否需要純演出用售價欄位**。⚠ 若答案是「要」，必須同時寫下「它為何不違反反支柱 `NOT 寫實經營模擬`」的論證，否則會被後人誤判為開了先例 | 本 GDD ＋ r1 評審 | game-designer | 不擋；若加是純附加欄位 |
| OQ-P6 | **是否支援「不重出 build 就能加新商品」**：需 Addressables 遠端目錄＋內容 host，而 itch.io 靜態 host 不是為此設計的 | unity-specialist | **technical-director** | 不擋；**獨立技術決策，不該由本 GDD 默認** |
| OQ-P7 | ~~`RequestHandoff(itemId)` 的語義~~ **已於 r1 評審後半封口**：依 `modules/multiplayer.md:78-93`，ownership transfer 唯一 API 是 `NetworkObject.ChangeOwnership(ulong)`，`itemId` 應為 **`NetworkObjectId (ulong)`**。⚠ **r3 修正：r1 的推論被本文件自己推翻過，但這一格沒跟著改**——那個 `ulong` 是**目標 clientId**，不是 NetworkObjectId（見 Interactions 的論據修正）。結論仍成立，但理由要換成「Host 端唯一能定位一個已 spawn 物件的鍵就是它」。⚠ **且本格漏帶了 Interactions 新增的那條硬要求**：`NetworkObjectId` 在 despawn／respawn 之間不穩定，**Host 必須驗證 `itemId` 仍在 `SpawnedObjects` 中，查無即回明確失敗**——否則結帳在交接窗口內消耗掉 `ProductInstance` 之後，Host 會拋 `KeyNotFoundException`（權威端，全房受影響）。實作者讀 OQ 表當 checklist，所以這一格必須自足。剩餘待辦：#5 設計時與 netcode GDD 正式對齊措辭 | unity-specialist ＋ network-programmer；r3 修正 | #5 | 不擋 |
| **OQ-P8** | **`[P-17]` 版本閘擋不擋得住「純內容變更」，目前無實據**。`netcode-session.md:163` 只寫 approval payload 承載 build／protocol version，**全文未定義 token 的產生規則**；唯一實測證據是 `:171` 的 `payload=w1-proto-v1`（字面量字串，命名為 proto）。若它只在 wire format 改變時手動遞增，**純內容補丁不會讓它改變，P-17 會放行**——而那正是 Overview 點名的場景。修法二選一：(a) 在 netcode GDD 把 token 定義成涵蓋內容的粒度（例如 build hash）；(b) 本表自建一層 SKU 表雜湊檢查 | r1 評審（network-programmer），r2 兩位專家獨立重新發現 | **technical-director ＋ netcode GDD** | ⚠ **r2 上修：擋規則 2 的完整性**。r1 把它填成 OQ 卻讓規則 2 的斷言原封不動——實作者讀 Detailed Design，不讀 OQ 表。規則 2 已於 r2 改寫成條件句，**在本 OQ 關閉前，本表對兩端 SKU 表一致性不作保證**。另：此依賴是單向的，netcode GDD 對它零筆紀錄，**必須回填一行否則本 OQ 會變孤兒** |
| **OQ-P9** | **`is_spoiled` 的信任邊界** — **r3 由「已封口」改回「條件性關閉」**。r2 的裁決是：`is_spoiled` 與 `network_index` 皆為 **server-write，且 NetworkObject spawn 之後不可變**，以 server-write `NetworkVariable` 承載（遲加入者於 spawn 同步取得現值）。兩半都由本專案既有決定蘊含（Core Rule #1 host authority ＋ 約束⑧ 於 2026-09-16 由 W1 雙行程實測升級為正確性要求 ＋ States §B 的單向蓋章）。詳見 Interactions。⚠ **r3 加上兩件 r2 沒寫的事**：①**必須在 `Spawn()` **之前**寫入**——r2 只寫了「之後不可變」，完全沒規定何時寫，而照字面實作會是 tick-gated delta，在 10Hz 下製造一個約 100ms、與實測交接時間同量級的窗口，接收端讀到 `network_index == 0` 並在 NGO 訊息迴圈裡拋例外，**而本地測試 100% 綠**（AC22）；②**約束⑧ 的引文被改窄了**——原文是「不得以 NetworkVariable 承載**結果**」，r2 引成「不得承載 **owner-write**」，而 netcode GDD 自己另一處又收窄成 owner-write。**若廣義讀法勝出，`is_spoiled` 是互動結果，本整條裁決要重做。** 這就是它只能條件性關閉的理由 | r1 評審（network-programmer）；r2 裁決；r3 補時序與引文 | **netcode GDD**（裁決約束⑧ 的讀法） | 不擋本文件；**擋 #5 開工** |
| **OQ-P10** | **`deprecated` 條目的資產引用由誰在什麼時機清 null**。⚠ **機制已於 r2 定案**（規則 2：允許強引用，`Deprecated` 時必須清 null，由 AC19 守護）——r1 把這條 OQ 寫成「斷開由誰執行未定」，**預設了機制已決而只差擁有者，但機制其實是壞的**（命名約定無法讓資產進 build）。剩餘待辦只有流程：誰在下架流程裡執行清 null、清完由誰複核 | r1 評審（unity-specialist）；r2 縮小 | art-director ＋ 本表擁有者 | 不擋；AC19 已把它從承諾變成機制 |
| **OQ-P11** | **建置期資料治理閘門該拆成獨立 ADR ＋工具任務**。⚠ **r2 縮小範圍**：r1 把三件事綁在一起，其中一件是假問題。**「非 Editor 環境下 catalog 如何發現 SO 資產」不需要 build-time 收集步驟**——標準解是一個容器 ScriptableObject（`ProductCatalogAsset` 持有 `ProductDefinition[]`，由 boot scene 的 `[SerializeField]` 引用），走一般序列化依賴鏈進 build，執行期零發現、零 async、零 `Resources`、零 `AssetDatabase`。**本文件採用此解**，它同時保住「零上游依賴」「載入期靜態表」與 AC14 的純度。剩下兩件是真的：①`IPreprocessBuildWithReport` 對 CI 紀律的選擇與三條靜默繞過路徑 ②asmdef 邊界的落實與 `CompilationPipeline` 檢查 | r1 評審；r2 縮小 | **technical-director ＋ devops-engineer** | 不擋本文件；**決定「外部前置條件」節何時解除降級** |
| **OQ-P12** | **`ProductInstance` 過線是否需要 `INetworkSerializable`** — **r3 由「已收斂」改回「條件性關閉」**。r2 的收斂是：**兩個欄位分開以基元型別過線，不把 struct 當一包送**。這不只是省事——整包送可能要求在 struct 上宣告 NGO 介面，而該宣告必須寫在擁有 struct 的組件裡，也就是 AC14 明文禁止引用 NGO 的那一個。**分開送同時保住規則 4 的單一真相源與 AC14 的純度。** ⚠ **r3 刪除「且不需要實測」並改回條件性**，兩個理由：①NGO 2.x 有 `UserNetworkVariableSerialization<T>` 這組 static 委派，設計目的正是「為你無法修改的型別註冊序列化」，**而註冊可以寫在別的組件**——若它存在（中等信心，**需查證**），「必須宣告介面→必須引用 NGO→違反 AC14」這條推理鏈在第二步就斷了；②**對 #4 可能不夠**：多槽攜帶的自然形狀是 `NetworkList<ProductInstance>`，它要求 `T: unmanaged + IEquatable<T> +` NGO 可序列化，拆欄位的招在此失效，而本專案已踩過這坑（netcode 的 `ClaimGeneration`）。**前向約束**：#4／#5 不得以 `NetworkVariable`／`NetworkList` 承載 `ProductInstance` 的集合，若要如此須先做 W1 式實測並重新裁決 AC14 | r1 評審（network-programmer）；r2 裁決；r3 重開 | **#4 ＋ #5** | 不擋本文件；**擋 #4 開工** |
| ~~OQ-P13~~ | ~~遊戲內語音是否進 MVP~~ **已於 2026-09-22 由 arlong 裁決關閉**：**MVP 不做遊戲內語音**；**#11 欠一個非語音的「我要這個」ping**（服務支柱 5，且是唯一對聽障玩家、吵雜環境、陌生人房都成立的版本）。⚠ **對本表的後果**：准入門檻 1-4 稽核的口語頻道**確定不會出貨**，所以它們**確定**是「對內容作者的約束，不是對產品的保證」——先前那句話是條件句，現在是事實。產品實際保證的仍是門檻 5-6。⚠ **而 icon 承載的溝通載荷因此變成 100%，不是「大量場次」**：`sku_nameable_max = 6`、形狀預算池 A ≤ 14、並發上限 4 這三條的重要性隨之上修。裁決緣由見 `first-person-controller.md` 的 Player Fantasy——身體是本作唯一在沒有 Discord 的場次裡仍成立的協調頻道 | r2 評審（game-designer＋ux-designer）；r3 升級；2026-09-22 裁決 | **已關閉** | — |
| ~~OQ-P14~~ | ~~美術聖經 §3.3 與 §8.6 對需求 icon 自相矛盾~~ **已於 2026-09-20 由 art-director 裁決關閉。** 覆核時另找到**第五處矛盾**，而它把問題從「取捨」變成「勘誤」：**§8.8 早已核准頭頂使用 TextMeshPro，而 TMP 字型是 SDF atlas ＝ 貼圖**，所以 §5.1「互動層仍禁貼圖」在美術聖經自己的頁面上就已經是偽命題。**裁決**：§3.3 是填充層、§8.6 是輪廓層，兩者合併；需求 icon **是**貼圖；原則 2 的射程限縮為**有體積的物件**。**對比**：文件原本提的「互動黃 ＋ §4.5 白描邊」實算 1.23:1，而白描邊對白牆更糟（1.17:1）——**問題不是黃不夠深，是那個方案裡沒有任何一個像素比背景暗**；改用 `Ink_Contour #23282A` 描邊後對白牆 12.71:1。**`Atlas_Ui` mipmap 改為開**（+39KB ＝ 預算 0.11%）。**形狀預算**：池 A（客人頭頂）≤ 14 相異剪影，現況已佔 8，故 `sku_nameable_max` 由 8 **下修為 6**。詳見 Visual/Audio | r2 評審（四位獨立發現）；r3 派 art-director 裁決 | **已關閉** | — |
| **OQ-P15** | **`Shelf` 家族的可得性查詢**。`Shelf` 是本表唯一供給有界的家族（補貨是玩家要離場去做的另一件事），而 #7 目前無從分辨它與三個產生器家族。本表已寫下安全預設（在查詢存在前不得從 `Shelf` 抽 `Named`），但「波次可完成性由誰保證」仍無擁有者——⚠ 文件自己在槽位分配那節**用了**「整個波次只會出一份米血」這個供給前提來論證優先序，卻沒有把它寫成任何人擁有的不變量 | r2 評審（economy-designer） | #5 ＋ #7 | 不擋；**#7 開工前必須有答案** |
| **OQ-P16** | **光敏性安全上限無人擁有**。§4.2「加壓靠閃爍頻率」＋§4.3「紅蓋黃＋閃爍」＋「十顆黃 icon 同亮」＋§4.5 以閃爍作為超時的色盲雙編碼 ＝ 尖峰時的設計意圖是**多顆同時閃爍的紅色 icon**，而全專案沒有任何閃爍率上限或關閉選項。⚠ **r3 刪除一句假陳述**：r2 寫「本表提議的並發上限**同時是一條光敏性上限**」——**那是錯的**。光敏性危害取決於閃爍的**總面積與頻率**，與**花色種類數**無關，而 §4.3 明許「十顆黃 icon 同亮」；並發上限限制的是**相異符號種類**，十顆**同一種** icon 同時閃爍完全不受它約束。⚠ 而這正是 r2 自己在 Tuning Knobs 才剛修過的同型錯誤（「並發上限管的是花色數，不是頻率」）——**改了定義處、漏了引用處**。本表對光敏性**不提供任何保護**，只負責指名擁有者。另：§8.3 的共享材質全域脈動意味著所有閃爍**同相**，面積會相加。⚠ 確切法規門檻**請對照 WCAG 2.3.1 原文查證**；我的理解是通則約為「任一秒內不超過三次閃爍」，而瀏覽器發行沒有 launcher 層級的警告畫面 | r2 評審（ux-designer）；r3 修正（accessibility-specialist） | **#18 設定與無障礙** | 不擋 |
| **OQ-P17** | **受眾範圍正在被三個欄位寬度默默決定**。支柱 2「**台灣人**秒懂」＋ §3.3 icon 不用文字（所以看不懂符號的人沒有文字退路）＋ `display_label` 的漢字上限（一條**擋 build** 的 AC），三處各自把受眾限定在台灣。⚠ 而 `display_label` 一個欄位同時承擔「喊的名字」（音韻性質，永不算繪）與「#13 逐項列表的字」（會被算繪、未來要變成 localization key）兩個工作，兩者的約束不同。**這應該是一次明示裁決，不是三個欄位寬度的副作用。** 本表目前明確假設**繁體中文單一語系**；若新增語系，`display_label` 需拆兩欄，而該拆分**不得**改動 `sku_id` | r2 評審（ux-designer） | **creative-director** | 不擋 |

⚠ **r3 的收支**：關閉 **OQ-P14**（art-director 裁決）；把 **OQ-P9 與 OQ-P12 由「已關閉」
改回「條件性關閉」**——前者取決於 netcode GDD 對約束⑧ 的內部不一致如何裁決，
後者取決於 `UserNetworkVariableSerialization<T>` 是否存在、以及 #4 是否需要
`NetworkList<ProductInstance>`。**r2 把兩者標成已封口是過早的。**
⚠ **並刪除 r2 的「仍會造成返工的：無」這句自評**——r3 至少找出三條會造成返工的：
`Spawn()` 前寫入（若 #5 已照舊寫法實作）、純函式移出 `IProductCatalog`（若測試夾具已寫）、
以及 `sku_nameable_max` 由 8 下修為 6（若已畫了 7-8 張 icon）。

**擋下游開工的三條**：**OQ-P1**（缺 `Microwave`／`Shelf` 家族 icon，且 `nameable` 下限
已裁為 2，所以它現在擋的是**內容進表本身**）、**OQ-P15**（擋 #7）、
**OQ-P11**（決定「軸 2：建置期強制」何時生效）。
