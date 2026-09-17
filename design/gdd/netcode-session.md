# 網路同步層＋Session (Netcode & Session)

> **Status**: Revised 2026-09-13 r4（第四輪複審 NEEDS REVISION，17 組 blocking＋機械檢查結果已處理）
> **Design Review**: 2026-09-05 首審 NEEDS REVISION（14）→ 修訂 → 複審 NEEDS REVISION（7）→ 修訂 →
> 2026-09-06 第三輪 NEEDS REVISION（24，含 3 項結構前置）→ 修訂 →
> 2026-09-13 第四輪 NEEDS REVISION（17 組＋2 張機械檢查；CD-GDD-ALIGN: CONCERNS）→ 已修訂
> **r4 流程裁定（creative-director）**：**r4 是最後一輪散文式評審。** 本次修訂完成後不再開 r5
> 六專家複審，改為 (1) 重跑三張機械檢查、(2) 直接開 W1 原型。原型回填造成的變更走「回填 diff
> 複核」。理由：四輪的 blocking 都長在上一輪修補的縫隙裡，且約四成確認項是對一個沒人跑過的
> 系統的斷言——散文評審沒有可以反駁它們的儀器。
> 審查日誌：`design/gdd/reviews/netcode-session-review-log.md`
> **Author**: arlong + agents (network-programmer, systems-designer, creative-director)
> **Last Updated**: 2026-09-13
> **Implements Pillar**: 開連結就開玩（進房 ≤60 秒）、沒有人在等（重連策略＋留守者保護）
> **Engine Facts**: docs/engine-reference/unity/modules/multiplayer.md（NGO 2.13.2 / MPS 2.3.1 / Relay WSS）
> **修訂協定（r4 起，取代 r3 版）**：每輪修訂先跑**五個掃描**——(1) 適用性矩陣空格、
> (2) 常數三欄對照（**雙向**：不只「常數出現在三處」，而是「被引用的那條 AC 真的斷言了這個數字」）、
> (3) 所有描述玩家可見行為的表格皆有層級欄、(4) [P] 反向掃描、
> (5) **AC 時間算術可達性**（每條有時間上界的 AC 列出依賴的具名常數／假設，驗算是否閉合）
> ——再處理個別條文。
> **r4 新判準**：**任何 fallback 會殺掉 MVP-必達 AC 的 [P]，其 fallback 本身即為 blocking**
> （見 Provisional Assumptions 的「影響」欄；MVP-必達的定義見 Acceptance Criteria 層級欄）。
> 反之，一條 [P] 只要 fallback 可行，它就不是 blocking，屬原型查證範圍——文件不為未開機的
> 引擎停止交付。
> **r4 二次修訂補的兩條執行規則**（機械檢查證明光有「影響」欄擋不住同一類缺陷——20 條裡
> 有 17 條的影響欄不完整，因為它是**手填的散文**）：
> - **(A) 影響欄必須從 `[P-n]` 的全文反向掃描產生**，不得手寫：掃出每一處標記位置 → 列出
>   該位置涉及的 AC／常數／規則 → 與影響欄比對，缺一即 fail。同時檢查反向：**凡依賴某
>   假設的 AC 必須標上該假設編號**（AC 撰寫規則 5）。
> - **(B) fallback 欄寫「可行」之前必須代入具體數字驗算**。本輪有兩條光靠一行乘除就被
>   推翻：`P-3`（10Hz→400ms、20Hz→300ms 恰等上限、30Hz 只剩 33ms）與 `P-6`
>   （gzip ×1.2 → 29s > 25s）。**未經驗算的「可行」是斷言，不是結論。**

## Overview

網路同步層＋Session 是大夜班的連線地基，負責兩件事：**（1）房間生命週期**——開房、
產生人類可讀的房間碼、輸碼或貼連結加入、離開與斷線處理；**（2）同步慣例**——遊戲
狀態（客人、時鐘、分數）與玩家動作（移動、互動、攜帶）如何在 2-4 位玩家之間保持
一致：誰擁有真相、事件怎麼傳、慢半拍怎麼補。技術路徑為 Unity NGO 2.13＋Multiplayer
Services Sessions（client-as-host＋Relay WSS），細節見引擎參考文件。玩家幾乎不直接
接觸這個系統——他們唯一摸到的是大廳的房間碼；其餘時候它的存在只透過一件事被感知：
「我撈起的關東煮，在隊友的螢幕上也被撈起了。」本作的核心體驗（同樂）完全建立在
多人同場之上，沒有這層，遊戲不存在。它同時是全專案最高技術風險（新引擎＋Web
transport 無官方端到端範例），因此是第一個做技術原型的系統。

## Player Fantasy

本系統是間接型基礎設施——玩家感受到的是它成就的事，不是系統本身。

**主軸：「貼連結，人就到了」（自動門即傳送門）**
錨點時刻：群組貼上連結，你還在補貨架，就聽見「叮咚——歡迎光臨」，朋友的店員身影
已經走進門、站在你旁邊的貨架前——中間沒有任何一個他要「操作」的畫面。
情緒：期待被立刻兌現的輕快驚喜。（時間預算見 Formulas ②；本節不寫秒數——
體感承諾是「不用等」，不是某個具體數字。）
連線不是「建立中」，是「他來上班了」——所有網路狀態一律翻譯成店裡的事件語言：
**進房＝進門、離開＝下班、重連＝去後場拿貨回來**。技術詞彙一個都不准出現在玩家眼前。

**第二層：「班照樣要上」（沒有人被留在門外，也沒有人被留下獨撐）**
中途加入的人穿好制服就走進店裡，隊友頭也不回喊「幫我顧一下關東煮」；有人掉線時，
**留下來的人不會被雙倍客潮處死**——客人變少、耐心變長，老闆會擋一下（見 Core Rules
#15）。回來的人看到店還在轉。守護支柱「沒有人在等」——這條**同時保護斷線者與留守者**，
後者才是每次 Wi-Fi 一抖就會發生的常態。**就算只剩店長一個人，店也不關**（Core Rules
#21）——他可以撐到天亮，也可以拉下鐵門提前收班結算。

> 註：MVP 沒有 host migration——房主關掉分頁本局就結束。這句 Fantasy 承諾的是
> 「隊友掉線時店還轉得下去」，不是「session 永生」。

**語氣資產（併入）**：房間碼像交接班的口令——短、能唸出來、不分大小寫（Core Rules
#8）；UI 用班表詞彙（值班、交接、代班）；連線失敗不說「錯誤」，說「這班沒這個人喔，
再確認一次工號」。

**等待畫面的分域鐵律（r3 改寫）**：
- **遊戲內（中途加入、重連、局間、任何 build 已載入後的時刻）絕不出現任何等待畫面**
  ——沒有進度條、沒有「連線中」、沒有「主機遷移中」、沒有「等待玩家準備」。
  任何讓人低頭看讀取條的畫面，都是「開連結就開玩」的直接違規。
- **冷啟動（build 下載，每位新玩家第一次必經）必須以世界語言呈現等待**——例如鐵門
  緩緩升起、日光燈逐盞亮起——**不得出現百分比、技術術語、Unity 預設 loader**。
  完全靜默不是選項：15-25 秒的空白會讓玩家分不清「還在載入」與「當掉」。客製
  HTML/CSS Web Template 為 **MVP 必要交付物**（公式⑤(b)，視覺歸 `/ux-design`）。
- **冷啟動失敗／卡住必須有出口（r4 新增，Core Rules #27）**——上一條的動機是「不讓玩家
  分不清還在載入與當掉」，但若**真的當掉**，現行設計沒有任何狀態、逾時或重試路徑，
  玩家會盯著同一個動畫直到自己關頁。這在**每位新玩家的必經路徑**上，是支柱 4 的直接違規。
  規則：以「下載位元組數連續 `load_stall_timeout_sec` 無增長」判定 stall（**不是總時長逾時**
  ——節流網路下 T_load ≈80s 是文件自承的預期常態，總時長逾時會誤判），顯示世界語言的
  「鐵門卡住了，重新整理看看」＋重試鈕。

**絕不能被感受到的**：裝驅動、更新檔、建立帳號、技術進度條、「主機遷移中」、
「等待玩家準備」。

## Detailed Design

### Core Rules

**權威模型**
1. **Host 權威**：客人 NPC 狀態機、波次導演、計分、班次時鐘、共用道具歸屬、結算結果
2. **Owner 權威**：玩家移動與朝向。
   ⚠ **W1 第 0 批查證更正（2026-09-13）**：原文寫「NGO NetworkTransform 預設，不改寫」是**錯的**。
   client-server 拓撲下 `NetworkTransform` 的 `AuthorityMode` **預設是 `Server`**
   （`AuthorityModes.Server = 0`，欄位無初始值；Tooltip 原文「If server (**the default**)…」）；
   只有 distributed authority 拓撲才強制 owner authority。
   **本設計要的 owner 權威必須顯式設定 `AuthorityMode = AuthorityModes.Owner`**，
   不是「不改寫」而是「必須改寫」。這條若照原文實作，玩家移動會變成 server 權威，
   手感與設計意圖不符且無人會發現（本地 host 測試看不出來）。
3. **RPC 事件驅動**：機台互動一律 request → Host validate → broadcast，
   禁止 client 直接改共用物件的視覺狀態；client 只做 0-`optimistic_anim_max_ms`（100ms）的樂觀動畫

**互動搶奪仲裁**
4. Host 是唯一仲裁者：站台/道具有 `IsClaimed`＋`ClaimedBy`＋**`ClaimGeneration`**（三者
   合為**同一個 replicated NetworkVariable struct**，Host 寫、全員讀，遲加入者與重連者
   連線時自動取得現值），第一個合法請求得標。新加入者的首次 claim 請求**帶所讀到的
   現行世代**；世代不符即拒絕（見 Edge Cases claim lock 逾時）
5. 輸家體驗：樂觀動畫被拒後播輕量「撲空」回彈＋音效——**不做位置回滾**
   （無物理精度需求，回滾突兀，撲空更自然也更好笑）

**道具攜帶/交接**
6. 道具歸屬走 ownership transfer；交接需 Host 驗證雙方距離/朝向。**「交接完成」的判定
   時刻＝Host 提交 ownership transfer 的那一刻**（Host 權威、單一真相），不等待新持有者
   ack、不設 ack 逾時。完成後新持有者若斷線，依 #11 掉落於**新持有者**的最後座標。

   ✅ **W1 第 0 批查證確認（2026-09-13）**：此定義**成立，不需重寫**。client-server 拓撲下
   `ChangeOwnership(ulong)` 在 server 端是**同步、原子**的——函式返回時 `OwnerClientId`
   已是新值，三個 ownership callback 皆已觸發，**不存在 pending／待確認的中間態**。
   （`OwnershipStatus`／`RequestOwnership`／`IsRequestInProgress` 那整套權限機制**只在
   distributed authority 有效**，與本專案無關。）

   **但查證同時帶出三條必須遵守的但書**：
   - **6a. `ChangeOwnership` 回傳 `void`，失敗是靜默的**——四條 early-return 路徑
     （未 spawned、目標已是 owner、非 server 呼叫、**目標不在 `Observers` 裡**）各只寫一行 log。
     **Host 必須在呼叫後回讀 `OwnerClientId` 確認，才能宣告交接完成並廣播**。
     否則「單一真相時刻」可能根本沒發生而無人知道。
   - **6b. 兩次 ownership 變更之間至少間隔 `ownership_change_cooldown_ticks`（6 個 network tick）**
     ——NGO 原始碼 `k_MaximumTickOwnershipChangeMultiplier = 6`，超過頻率會警告
     「[Rapid Ownership Change Detected][Potential Loss in State]」且 owner-write 的
     NetworkVariable 更新**可能遺失**。道具快速互相拋接的玩法**必須設交接冷卻**。
   - **6c. 只有 server 能發起 transfer**（非 server 呼叫直接被拒），這與 #1 Host 權威一致。
7. **不同步拋物線**——用附著點（attach socket）＋交接動畫遮蔽轉移瞬間，
   WebSocket 尖峰的位置跳動不給玩家看見

**加入與離開**
8. 帶碼連結是主要入口（房間碼為 Sessions API 原生 `session.Code`，格式平台決定
   `[P-1]`）；手動輸碼為**必備備援**——若部署平台不轉發 URL query（`[P-4]`，
   itch.io iframe 未驗證），輸碼路徑就是唯一入口，不得砍。**輸碼規則** ✅ **（`[P-1]` 已於 W1 第 1 批實測回填，2026-09-13）**：
   實測 6 個 session 的 `session.Code` 為 **固定 6 碼、全大寫英數**，
   觀察字集 `689BCDFGHJKLMPQRTW`——**數字只有 6/8/9，字母不含任何母音，
   且完全不含 0、O、1、I、L**。服務端顯然已刻意避開易混淆字元（避開母音應是為了
   不讓隨機碼拼出真實字詞）。因此：
   - **「易混淆字元正規化」規則已刪除**——服務端字集已處理，客戶端再做是多餘的
   - **`[P-1]` 的 fallback（自建短碼對照表）不需要**
   - **仍須保留：比對大小寫不敏感**（碼本身全大寫，但玩家會用小寫輸入）
   - 輸入框**必須支援整串貼上**
   > 取樣說明：6 個樣本共 36 個字元位置，未出現任何易混淆字元。若真實字集含
   > 4 個易混淆字元，36 次抽樣全不中的機率約 0.9%——證據強，但非窮舉證明。
9. 中途加入：允許，但**班次剩 30 秒起鎖 join**（含 Settlement 全程），此後加入者
   一律導向 **Lobby（前一班進行中）**（見 States 表；不是另開新房）。
   邊界：剩餘 `t ≤ 30.0s` 即鎖（含端點）。
   **截止閘門的唯一執行點＝Host 的 `NetworkManager.ConnectionApprovalCallback`**（r4 改：
   原寫「玩家點擊加入的瞬間判一次」不可實作——點擊當下 client 尚未加入 session、更無 NGO
   連線，**無從得知班次剩餘時間**，且由 client 自判違反 server-authoritative 原則）。
   判準＝`shift_end_ts − host_now ≤ late_join_cutoff_sec`，時間源為 Host 權威的
   `shift_end_ts`（見「班次時鐘語義」）。拒絕時以 approval response 的 reason 回店語訊息。
   - **UI 預檢（非權威）**：client 可讀 MPS session custom data 裡 Host 發布的 `shift_end_ts`
     先行提示，避免白跑一趟；**預檢結果不具權威，一律以 approval 為準**
   - **approval payload 同時承載 build／protocol version**（r4 新增）：Web 遊戲有瀏覽器快取，
     「舊 build 的分頁加入新 Host」是必然會發生的情境，無版本閘＝靜默 desync。
     版本不符一律拒絕，訊息「這是舊的班表，重新整理一下」
   - 截止檢查通過後，更衣室 3-5s 內的截止線滑動屬已知接受（見 Edge Cases）
   - ✅ **`[P-17]` 已實測回填（W1 第 1 批，2026-09-13）**：`ConnectionApprovalCallback`
     **在 Sessions 啟動網路的情況下確實被呼叫**，且 `NetworkConfig.ConnectionApproval`
     **未被 Sessions 覆蓋**（啟動後仍為 `true`）。
     實測 log：`ConnectionApprovalCallback 被呼叫！ ClientId=0 PayloadLen=11`、
     `approvalCalls=1 ConnectionApproval=True payload=w1-proto-v1`。
     **`NetworkConfig.ConnectionData` 的 payload 完整傳遞到 `req.Payload`
     ——這就是 AC54 版本閘所需的通道，本條的可行性成立。**
     ⚠ 已驗的是 host 自身 local client（`ClientId=0`）走的那次 approval；
     遠端 client 加入走同一條 NGO approval 路徑，但**拒絕原因如何呈現給遠端 client**
     仍待雙進程情境確認
10. 中途加入過場（3.0-5.0 秒，**定長情緒節拍**）＝**更衣室**。本 GDD 只定**約束**：
    時長區間、**全程無讀取條、無技術文字、無店內狀態同步依賴**、必須傳達「目前比分
    ＋剩餘時間」。3.0s 下限的理由是**推門進店的動作節奏**（情緒節拍下限），不是資訊
    識讀；5.0s 上限是「開始像在等」。視覺呈現（參考示意：穿制服、牆上班表、推門進店）
    歸 `/ux-design` 定案。**Runtime 規則：同步未於過場結束前完成者仍準時進場**，缺項
    以 NetworkVariable 現值顯示、同步完成瞬間更新，**不得延長轉場**——更衣室是定長
    情緒節拍，不是同步等待室。
    註：更衣室是 Unity 場景，**只在 build 已載入後存在**——它解決的是 mid-join 的
    讀取條問題，不解決冷啟動 T_load 的（見公式⑤ (b)）
11. 斷線：攜帶物品 ≤`disconnect_cleanup_sec`（2s）掉落於**斷線當下座標**（可被隊友撿走）；
    進行中互動歸零、站台解鎖；roster 更新為離線（以上皆 **MVP 必要**）。**MVP 的 slot 處理：
    離線者名額立即釋放（不佔 `max_players`），重連者走中途加入流程（受 #9 截止限制、
    走更衣室、不恢復原位）**。slot 保留 30 秒重連窗口與原位恢復為 **Post-MVP**
    （見 Acceptance Criteria 的 MVP 欄）。「斷線」的判定時刻見 #20（心跳）。
    **完整的執行序列見新增的 #24**——本條只定義「結果」，#24 定義「誰做、依什麼順序做」。
    **兩個人數是不同的量，不得混用**（r4 釐清）：`session_member_count`＝MPS session 成員數，
    是 `max_players` 的判定依據；`online_player_count`＝在線遊玩人數，是波次導演的依據。
    斷線期間兩者**本來就不相等**，B1 揭露的洞正是「它們錯誤地相等了」
12. **Host 關閉分頁＝本局結束**（MVP 無 host migration）——大廳 UI 明示
    「房主離開視為本局結束」。**Best-effort 攔阻**：Host 於 Lobby／InShift 主動關閉分頁
    或導頁時觸發瀏覽器 `beforeunload` 確認（明寫 best-effort——行動瀏覽器與手勢關閉
    可能攔不住）。
    - 🔴 **本條已於 W1 第 1 批升格為「關鍵機制」，不再是 best-effort 的錦上添花**：
      實測顯示 Host **優雅離開**（主動呼叫 `DeleteAsync()`）時，其他 client 於 **1.14 秒**
      收到 `session.Deleted`；而 Host **被強制終止**時要 **132.61 秒**才收到 `PlayerLeaving`。
      **差 116 倍。** 換言之，本條就是「把 132 秒變成 1.14 秒」的那個開關——
      關分頁、導頁、按離開這些最常見動作能否走到主動通知，直接決定 Lobby 的體驗
      是否違反支柱 5。
    - **離開通知必須用 `sendBeacon`／`keepalive` 語義**（r4 新增）：一般 async HTTP 請求
      在 unload 時會被瀏覽器取消，SDK 的 `LeaveSessionAsync` 幾乎必然來不及送出 `[P-18]`。
      ⚠ **`[P-18]` 的重要性因此同步升格**——它先前的 fallback 是「退回心跳路徑」，
      而實測證明那條路徑在 Lobby 要 132 秒。**若 `sendBeacon` 不可行，必須另尋
      在 unload 期間可靠送出刪除請求的手段，不能只是接受降級。**
    - `beforeunload` 需自寫 `.jslib` 橋接（Web 平台無 C# 直達路徑），與 P-7 同屬
      SendMessage／stripping 風險面，查證併入 P-7
    - **站內離開按鈕統一為一顆 `end_shift_early`**（r4 改，原本「結束本班」與 #21 的
      「提前收班」是兩個名字、適用範圍互斥）：店語「提前收班／拉鐵門」，Host 任何時刻可見。
      **`online_player_count` > 1 時必須站內二次確認**（「還有人在店裡，要拉鐵門嗎？」）；
      **Host 獨留時免確認**直接進 Settlement。理由：原設計讓站內按鈕比關分頁更危險
      （關分頁好歹有瀏覽器確認框），誤觸即毀全隊的局
    - 文案與視覺歸 `/ux-design`
13. 進房流程預算 ≤45 秒（帶碼連結 0s＋Web 載入 ≤25s＋auth 預熱並行 0s＋
    暱稱自動產生不阻擋＋大廳 ≤10s＋spawn ≤10s）——對支柱硬標 60s 留 15s（25%）餘裕
    （見公式②；標準網路 20Mbps 下 T_load 實測預期 20s 以上，25s 已計入多資源 TTFB）

**留守者保護（支柱「沒有人在等」的另一半）**
14. 玩家離線（斷線或退出）時，`player_count` **立即重新取樣**（不等波次邊界），
    當前波次剩餘客人生成量按新人數即時降載
15. 同時給 **15 秒寬限期**：不生成新客人、場上客人耐心倍率 ×1.5，店語呈現為
    「老闆出來擋一下」。寬限期結束後回到正常波次節奏，**並以店語明示結束**
    （「老闆回辦公室了」或等義文案，歸 `/ux-design`）——靜靜結束會讓留守者
    不知道保護何時消失（r4 補）。**寬限期內任一玩家加入完成
    （更衣室結束）→ 寬限期立即結束、`online_player_count` 立即重新取樣**——朋友補位時
    本來就不該繼續降載，同時堵住「退出→立刻重連→再刷 15 秒寬限」的漏洞
15a. **單人重複離線的抑制（r4 新增，arlong 裁決）**：同一玩家於**同一班次內第 2 次起**
    的離線，`online_player_count` **仍立即重新取樣、當前波次仍即時降載**（誠實反映在線
    人數，這是留守者保護的本體，不可拿掉），但**不再觸發 #15 的寬限期**
    （不生新客人／耐心 ×1.5 皆不適用）。
    理由：現行設計下主動背景 5.01 秒即觸發 teardown，換到全隊降載＋耐心 ×1.5，個人成本
    僅約 9 秒且可逐波重複——「用 alt-tab 調低難度」違反支柱 1「兩段式節奏不可破壞」。
    本條保住保護的本體，只拿掉可重複刷的那一部分。
    計數以 **session-level player 身分**為準（非 NGO ClientId——重連會配發新 ClientId，
    見 `[P-2]`）。✅ W1 第 1 批實測：該身分＝`AuthenticationService.PlayerId`，
    只要匿名帳號不變就跨 session 延續。⚠ **匿名帳號綁本機憑證，清快取或換瀏覽器即換身分**
    ——「換裝置即重新計數」屬已知接受（濫用成本仍高於收益）。
    計數於**班次結束時歸零**，不跨班累積。
    註：真的網路不穩的人仍拿得到降載（最常態的保護），只是第二次起沒有額外的寬限緩衝。
16. 例外：`player_count` 僅計算**在線**玩家；重連保留中的 slot（Post-MVP）不計入
    （避免留守者扛不存在的人力份額）。**多人相繼離線**：寬限期以**最新**離線時刻
    重算 15 秒（不疊加、不延長超過最新離線＋15s），耐心倍率固定 ×1.5 不疊乘

**Web 特有防禦（#17-#18 僅適用於 InShift，見適用性矩陣）**
17. **分頁背景是最大已知風險**（背景分頁 Update 完全不執行，非僅降頻——故不能
    只靠 frame delta 偵測）：以瀏覽器 `visibilitychange` 事件在背景**當下**標記時刻。
    分頁恢復時依背景時長分流：
    - **≤5 秒**：顯示層 catch-up（2 秒線性追平，NPC 不瞬移；語義見公式③）
    - **>5 秒**：**視同斷線**——走下方的 teardown 不變式，再走既有斷線流程。
      不硬把數十秒壓進 2 秒——那會製造本設計自己禁止的瞬移
    - catch-up 進行中若再次進入背景：取消當次 catch-up、以新的背景時刻重新分流
    - **時間源必須是單調時鐘**（r4 新增）：`t_hidden`／`t_visible` 一律於 `.jslib` 側以
      `performance.now()` 取得。不得用 `Date.now()`（wall-clock 可被 NTP 校時或使用者
      手動調整回撥，會讓 `T_bg` 為負，見公式③的 clamp 規則）；也不得在 C# 側取
      （分頁背景時 C# 根本不執行）
    - **本條僅適用於 InShift**。CreatingRoom／JoiningRoom／Lobby／Onboarding／Settlement
      期間任何角色的分頁背景化**不觸發**任何斷線判定，只有 socket close 或玩家主動離開
      才算離開 session（見 #23）

**17a. teardown 不變式（r4 新增，狀態機層級）**
    **任何從 InShift 離開至 Idle 的路徑**——#17 的 >5 秒分支、#18 排歧表的
    「Host 消失」與「無法排歧」兩個分支、玩家主動離開——**一律先執行 client teardown，
    再切 UI**：呼叫 `NetworkManager.Shutdown()`＋best-effort `LeaveSessionAsync()`。
    不得只切本地 UI 而讓底層連線活著（會出現 client 已回主選單、Host 尚未判定的
    「陰陽人」狀態）。
    r3 只把 teardown 寫在 #17 的 >5 秒分支，而 #18 的兩個 →Idle 分支沒有——**AC43 的
    client 全程前景，物理上進不了 #17 那條分支**，於是它在 Host 眼中永遠在線。
    `[P-15]` `NetworkManager.Shutdown()` 在 WebGL 上是否即時 flush WebSocket close frame
    未經驗證；若否，Host 端只能靠心跳逾時發現（≤8s），而非即時。
    **⚠ 本條不足以單獨解決單向失效**——鏈路已壞時斷線者通知不了任何人。Host 側的
    獨立判據見 #20 的雙向存活確認。
18. Host 背景化的額外處理（InShift）：Host 背景時其 JS **完全停止，無法主動通知任何人**
    ——因此局終由 **client 端心跳逾時（#20，8s）偵測**，但 client 收不到心跳有兩種可能
    原因（Host 消失 vs 自己斷線），必須先經下表排歧：

    **排歧的核心事實（r4 改寫）**：MPS **session 層**與 **Relay 資料層**是**兩條各自獨立
    的連線**（session 層走 HTTPS／WebSocket 到 Lobby 服務，Relay 走 WSS 中繼）。因此
    「session 層還通不通」就是「我的網路好不好」的獨立證據——這是排歧的支點。

    **判定依序執行，第一個命中者即定案**（不是投票，是優先序）：

    ✅ **`[P-10]`(c) 已於 W1 第 1 批回填（2026-09-13，編譯期驗證通過）——本表已改用實際 API，
    且比 r4 的設計更簡單**：`ISession` 直接提供 `Host`（string，目前 host 的 playerId）
    與 `HasPlayer(playerId)`，**不需要「輪詢 roster 再比對」**，連比對都省了。

    | 序 | 訊號（實際 API） | 命中條件 | 判定 |
    |---|---|---|---|
    | 1 | **session 事件推播**：`session.Deleted`／`session.SessionHostChanged`／`session.PlayerLeaving(id)`／`session.PlayerHasLeft(id)`（皆為 `ISession` 上的 `event Action`） | 收到 Host 對應 id 的離開事件，或 session 被刪除 | **Host 消失**（正面證據，最強） |
    | 2 | `navigator.onLine`（`.jslib`，`[P-7]`） | `false` | **自己斷線**（快速否定；`true` 不構成任何證據，見下） |
    | 3 | **`session.HasPlayer(session.Host)`** | session 層可達 **且回傳 false** | **Host 消失**（第二條獨立路徑） |
    | 4 | 同上 | session 層可達 **且回傳 true** | **無法排歧**——我的 session 層是通的、Host 也還在 session 裡，壞的是 Relay 資料路徑那一段。**不預設因果** |
    | 5 | `session.State`＝`SessionState.Disconnected`，或查詢拋錯 | session 層不可達 | **自己斷線** |
    | 6 | 以上皆不可得或互相矛盾 | — | **無法排歧** |

    輔助：`SessionState` 是 `None`/`Connected`/`Disconnected`/`Deleted` 四態，
    與 `IClientSessionNetwork.State`（`NetworkState`：`Stopped`/`Starting`/`Started`/`Stopping`/`Migrating`）
    **是兩個獨立的狀態機**——這正證實了 r4 對「訊號三語義被誤述」的判斷：
    `session.Network.State` 描述的是**本機 network 層**，而 session 成員資訊在 `ISession` 上。

    **為什麼是兩條路徑到「Host 消失」**：序 1 是推播、序 3 是輪詢，二者只需**任一可用**
    即可到達該分支。這正是修好 B4 的關鍵——r3 的單一訊號一旦退化，該分支就整條死掉，
    連帶殺死一條自標「必達」的 AC。**任何 [P] 的 fallback 都必須保住每一個分支的可達性**，
    這是 r4 新增的判準（見標頭）。

    ✅ **B4 已徹底解決（W1 第 1 批）**：r4 二次修訂時擔心「序 1 與序 3 共用 MPS session 層
    這個載體，同層不可用時一起死，B4 會以同一形式復發」。實際 API 顯示這個擔憂
    **在 API 可用性層面不成立**——`Host`、`HasPlayer`、`Players`、`PlayerCount` 都是
    `ISession` 的一等成員，與事件推播是**同一個物件上的兩種取用方式**，不是兩個可能
    各自缺席的 API。`[P-10]`(c) 剩下的唯一問題因此**從「查不查得到」縮小為「多快反映」**
    （事件推播延遲 vs 需不需要 `RefreshAsync()`），那是時序量測，不是分支存亡。
    網路層面「session 層不可達」由**序 5** 正確處理（判自己斷線），是有意義的判定，
    不是分支死亡。

    輔助訊號（不單獨定案，用於加強或推翻上述）：自身 `visibilitychange` 在心跳空窗期
    是否全程前景——若曾背景化，一律優先走 #17 的背景分流，不進本表。

    | 判定 | 玩家看到 | 後續 |
    |---|---|---|
    | Host 消失 | 「店長把鐵門拉下來了」 | 依 **17a** teardown →Idle |
    | 自己斷線 | 「這班你先下班了——點連結再回來上工」 | 依 **17a** teardown →Idle |
    | 無法排歧 | **預設不表態**：「跟店裡斷線了，點連結重新上工」 | 依 **17a** teardown →Idle |

    **r4 修正的具體錯誤**：原表的訊號三寫 `session.Network.State`＝「**雲端側對 Host
    member 的觀察**」。引擎參考文件對該屬性的完整原文只有一句「連線狀態：
    `session.Network.State` / `StateChanged`」，最自然的讀法是**本機這個 session 物件的
    連線狀態**——從本機 socket 的視角，「Host 走了」與「我自己網路壞了」產生同一個狀態
    轉移，本質上無法區分。且原表的「Host 消失」與「無法排歧」兩欄前兩訊號完全相同，
    唯一分辨者就是訊號三；而 `[P-10]` 的 fallback 寫「退化為兩訊號」，退化後兩欄無法
    區分，依「矛盾即走無法排歧」的鐵則，**「Host 消失」分支將永遠不可達**，直接殺掉
    AC6b（文件自標「保底路徑，必達」）與 AC28。這是全輪唯一一項 **fallback 自己不成立**
    的假設，也是 r4 的第一順位。新表以**兩條獨立路徑**（序 1 的正面事件、序 3 的可達性
    推論）指向「Host 消失」，任一可用即該分支可達。

    `navigator.onLine` **不是可達性測試**（r4 降級）：它只反映「有沒有一張網卡是 up 的」。
    captive portal、上游斷線、AC43 的單向丟包情境下它全都回 `true`。因此它只作為
    **快速否定**（`false` 即確診自己斷線），`true` 不構成任何正面證據。

    Host 恢復前景後依自身 `visibilitychange` 判 >5s → 主動關閉 session 釋放 Relay
    （不重新接管）。
    **全員得知局終的時間上限（r4 修正）**：Host 背景化情境中各 client **獨立**以自身心跳
    空窗判定，**不需要任何傳播**，上限＝`heartbeat_timeout_sec`。只有 Host **主動 close**
    的路徑才需加 `relay_disconnect_propagation_sec`。原文把兩條路徑混寫成
    「8s＋傳播延遲」，方向保守但不精確。
19. 狀態事件附**單物件** sequence 號（per-object，與 #4 的 `ClaimGeneration` 合流；
    **不設全域序號**——跨物件比較序號無意義）`[P-5]`。
    單一 reliable channel 底層為 TCP 本就有序；真正風險是 NGO **跨 channel** 到達
    順序，原型須以本專案實際 channel 組合驗證；若證實有序，通用 sequence 層應移除，
    **但 `ClaimGeneration` 仍保留**——它防的是「請求遲到超過 lock timeout」，與有序性無關

**連線偵測（心跳，僅 InShift）**
20. **app-level 心跳**：每 **2 秒**一拍（Host↔每個 client 雙向），連續 **8 秒**未收到
    判定「心跳逾時」＝斷線。
    **逾時 8s 必須 > 背景閾值 5s**（見 Tuning Knobs 約束區塊），否則切分頁 ≤5s 回來的人
    會被誤判斷線、公式③的 catch-up 分支永遠走不到。NGO/Relay 內建連線逾時須 ≥ 8s，
    否則以內建值為準並回填 `[P-9]`。`t_disconnect`（公式①）＝判定時刻＝真實斷線＋
    偵測延遲（拔線 ≤`heartbeat_timeout_sec`；優雅關閉／關分頁走 socket close，
    ＝`relay_disconnect_propagation_sec` `[P-8]`，**不是 0**——Relay 架構下 client 與 Host
    之間沒有直接 socket，Host 得知的時刻是 Relay 偵測並傳播的時刻）。

    **運行範圍（r4 修正）**：**心跳自 NGO 連線建立起運行**，涵蓋 **Onboarding、InShift、
    Settlement**。r3 寫「僅於 InShift 運行」與適用性矩陣（#18/#20 的 Onb 欄標 Y）、
    States 表的 Onboarding 轉移條件、AC37 三處直接矛盾；且若心跳到 InShift 才起算，
    Host 端的逾時計時器起算點未定義，Settlement 期間的 Host 消失也將無偵測。
    Lobby 與更早的狀態依 #23 尚未建立 NGO 連線，自然不跑心跳——Lobby 的 Host 離開
    偵測改由 MPS session 事件負責，見 **#25**。

    **心跳 payload（r4 定案）**：`{ seq, last_peer_seq_seen, host_shift_end_ts }`，約 8-16 bytes。
    一個封包同時供給三件事，因此**刪除「時鐘每 60s resync」這條獨立通道**：
    - **雙向存活確認**（B3 的修法）：Host 收到某 client 的心跳時，若其回報的
      `last_peer_seq_seen` 已落後超過 `heartbeat_timeout_sec`，即判定該連線**單向失效**，
      走與逾時完全相同的斷線程序（#24）。這讓單向丟包在**還通的那個方向上**就能被偵測，
      不必依賴斷線者自己來通知——鏈路已壞時它本來就通知不了
    - **時鐘 offset 估計**：client 以 `offset = host_value − (local_value + RTT/2)` 平滑估計，
      RTT 由心跳往返得出（見「班次時鐘語義」）
    - **HUD 的 ping 顯示**：由同一次往返得出

    **pipeline 選擇為實作細節，不是設計論點（r4 刪除錯誤立論）**：r3 寫「心跳走獨立的
    Unreliable pipeline——走 reliable 遇 head-of-line blocking 只會延遲不會遺失」。
    這個推論在本專案不成立：UTP 的 pipeline 位於 network interface **之上**，而
    `WebSocketNetworkInterface` 底下是**單一 TCP 連線**，HOL blocking 發生在 TCP 層、
    在任何 pipeline **之下**。選 Unreliable 只是讓 UTP 不再附加自己的重傳／排序標頭，
    **完全無法讓心跳超車 TCP 送出佇列**。且 TCP 不丟包，「漏 4 拍」在此沒有丟包語義——
    收不到 4 拍只代表「對端停止產生心跳（分頁凍結／行程死亡）」或「TCP 連線已停擺」。
    因此 8s 的依據**不是丟包容忍度，而是分頁凍結容忍度**（已由 5s 閾值決定）。
    結論：reliable 或 unreliable 皆可，二者在 WSS 下對到達時刻無實質差異。
    真正該防的是 **UTP send queue 溢位**（NGO 會真的丟訊息並報錯）——見 `[P-16]` 與
    Open Questions #12。

**Session 生命週期補充（r3 新增）**
21. **Host 獨留不結束本局**：其餘玩家全部離線、僅剩 Host 在線時，session 不結束，
    Host 單人續戰至 08:00，套用 N=1 降載與 #15 寬限期（「店還在轉」的正面兌現）。
    **留守單人可主動「提前收班」→ 直接進入 Settlement** 結算現有成績（本 GDD 負責
    支柱 5 的出口；N=1 的波次密度曲線歸波次導演 GDD，見 Open Questions #9）。
    只有 **Host 亦離線**（關頁／背景 >5s／心跳逾時）才是「全員離線」→ session 結束
22. **Settlement 逾時**：全員確認或 `settlement_timeout_sec`（20s）到期 → 自動視為
    全員確認 → Lobby
23. **Lobby 階段連線策略** ✅ **（W1 第 1 批確認可行，2026-09-13；風險解除）**：Lobby 只用 MPS Session
    的輕量 API 交換房間碼與 roster，**延後到 Host 按「開始上班」才配置 Relay allocation／
    建立 NGO 連線**——使 Lobby 階段根本不存在會逾時的即時傳輸連線，Host 切分頁貼連結
    30-120 秒不會殺掉自己的房。

    ✅ **可拆分，已驗證（W1 第 1 批，編譯期驗證通過）**：
    - `WithRelayNetwork()` 是 `SessionOptions` 的**擴充方法，不是必填參數**——
      `new SessionOptions { MaxPlayers = 4 }` 本身完全合法，可建出不帶 network 的 session。
    - `IHostSession.Network`（型別 `IHostSessionNetwork`）提供
      **`StartRelayNetworkAsync(RelayNetworkOptions)`** 與 **`StopNetworkAsync()`**，
      且 `NetworkState` 有獨立的 **`Stopped`** 狀態。
      即：**network 是 session 之上可獨立啟停的一層**，正是本條需要的形狀。
    - **`StopNetworkAsync()` 同時讓 #23a（局間 teardown 回 MPS-only）有了對應 API。**

    ✅ **runtime 實測證據（W1 第 1 批，PlayMode 4/4 通過）**：
    - 建立時：`Code=M69T96`、`SessionState=Connected`、**`NetworkState=Stopped`**
    - **場景中沒有 `NetworkManager` 也能建立成功**——比原設計預期的更好：
      Lobby 階段連 NGO 的單例都不需要存在
    - 延後呼叫 `StartRelayNetworkAsync()` 後：`NetworkState=Started`、`NGO.IsListening=True`
      （這一刻即 Host 按下「開始上班」）
    - 再呼叫 `StopNetworkAsync()`：回到 `NetworkState=Stopped`，而 `SessionState` 仍為
      `Connected`——**#23a 的局間 teardown 經 runtime 證實**，且兩個狀態機確實獨立

    r4 曾依引擎參考的敘述（「Session 會自動處理 lobby、Relay allocation、NGO 連線」）
    判斷三者是一次呼叫的封裝、與本條直接衝突，因而把它降級為高風險假設。
    實際 API 與 runtime 都顯示那句話描述的是**便利路徑**（一次帶齊選項時的行為），
    不是**唯一路徑**。本條的風險解除；`[P-10]` 剩餘的查證項只剩 (a) 服務層在背景分頁
    是否停擺——那需要 Web build ＋ 真實瀏覽器。

    ⚠ **一併記錄的引擎事實**：`WithRelayNetwork()` 這條路徑**依賴 `NetworkManager.Singleton`**
    （首次測試在無 NetworkManager 的空場景下拋
    `SessionException: Cannot start when Singleton is not set`）。
    不帶 network 的 session 則無此依賴。這正好強化本條：Lobby 階段可以完全不碰 NGO。

    🔴 **延後建連對「協定選擇」的硬性約束（W1 第 4 批新發現，本條的實作規範）**：
    Web 目標平台必須走 **WSS**（WebGL 沒有 UDP）。但 Relay 協定**無法在延後那一刻指定**——
    `StartRelayNetworkAsync(RelayNetworkOptions)` 的非 obsolete 建構子只收
    `region` 與 `preserveRegion`，沒有 protocol 參數；帶 `RelayProtocol` 的建構子已標記
    `[Obsolete]`，訊息明言「應改由 `SessionOptions.WithNetworkOptions()` 設定」。
    協定因此只能在**建立 session 當下**就決定：

    ```csharp
    // ✅ 正確：建 session 時就定協定，但**不啟動**網路（NetworkState 仍為 Stopped）
    var session = await MultiplayerService.Instance.CreateSessionAsync(
        new SessionOptions { MaxPlayers = 4 }
            .WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS }));
    // …Lobby 階段…（此時完全沒有 Relay allocation）
    await session.Network.StartRelayNetworkAsync(new RelayNetworkOptions());  // 「開始上班」
    ```

    **本條不因此受損**：`WithNetworkOptions()` 只設定、不啟動，與 `WithRelayNetwork()`
    是兩回事——延後建連與指定 WSS 可以並存。但它把「協定」從執行期決定變成
    **建 session 時的一次性決定**，Lobby 建立後無法再改。
    同時 `UnityTransport.UseWebSockets` 必須為 `true`，兩端不一致會拋
    `ArgumentException: Mismatched Relay configuration and network interface`
    （首次 RTT 測試即因此失敗）。

    🔴 **協定不會從 Host 傳染給加入者**：第二次 RTT 測試中 Host 已設 WSS 且
    `IsListening=True`，加入端只傳房間碼（`JoinSessionByCodeAsync(code)`）便再次拋出
    同一個 `Mismatched` 例外。**每個角色都必須各自宣告一次**——
    `JoinSessionOptions` 同樣繼承 `BaseSessionOptions`，吃得下同一個擴充方法：

    ```csharp
    await MultiplayerService.Instance.JoinSessionByCodeAsync(code,
        new JoinSessionOptions()
            .WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS }));
    ```

    對 #8（輸碼／帶碼連結加入）與 #26（開始上班轉場）的實作意義：
    **協定設定必須集中成一個共用的 helper**，任何一條加入路徑漏掉就會在該路徑上
    單獨失敗，而 Host 端完全正常——這種不對稱失敗在本地單機測試中看不出來。

    ⚠ 附帶事實：**QoS SDK 不支援 WebGL**（`PlatformNotSupportedException`，非致命，
    僅表示無法用 QoS 自動選 region）。Web 上的 region 選擇只能靠預設或顯式指定。

    **若不可拆的替代設計（r4 補完，不再只是一句 timeout 調整）**：
    - (a) **接受 Lobby 期間存在 Relay／NGO 連線**，並把 Lobby 的 Host 離開偵測改回心跳
      （#20 的運行範圍相應擴及 Lobby），同時拉高 Lobby 階段 transport disconnect timeout
      至實測可行上限；
    - (b) **明訂「Host 可離開分頁的最長秒數」＝實測服務端／transport 逾時 × `lobby_bg_safety_factor`（0.5）**，
      並在 Lobby UI 對 Host 誠實呈現這個限制（不承諾做不到的事）；
    - (c) **以「複製邀請連結」按鈕消除切分頁的必要性**——這是唯一不依賴任何未驗證引擎
      行為的解，因此列為**必做配套**（見下）。
    - ⚠ r3 原本的 fallback（「拉高 Lobby 階段 transport disconnect timeout」）**不足以涵蓋
      #23b 描述的服務層失效模式**——那一層根本沒有 transport timeout 可以調。

23a. **第二個以上的 Lobby（Settlement → Lobby，r4 新增裁決）**：
    **Settlement 結束進入 Lobby 時，teardown NGO／Relay，回到 MPS-only 狀態**——維持
    #23 的不變式，使局間 Lobby 與首個 Lobby 行為完全一致（Host 此時去群組貼連結叫更多
    人，是比首次開房**更高頻**的情境）。r3 完全未裁決此點。
    代價已記帳：「再開一班」時每個人要重跑一次 Relay 配置＋WSS handshake，該成本納入
    #26 的轉場預算並以世界語言遮蔽。

23c. **Relay 連線 TTL** ✅ **（W1 第 3 批實測後降級：#23 仍是好設計，但不再是「必需」）**：

    🟢 第 0 批查到 Relay 對每個 client 連線的 TTL 是 10 秒、靠 NGO 每 500ms 的 PING 維持，
    當時據此推論「背景分頁會讓 PING 停送 → 10 秒內被踢」，並把 #23 從優化**升格為必需**。
    **第 3 批的實測推翻了那個推論**：背景分頁只是節流到 1 Hz，500ms 的 PING 變成約 1 秒一次，
    **仍遠低於 10 秒 TTL**，連線不會斷。
    **#23（Lobby 延後建連）因此回到「好設計」而非「必需」**——它仍值得做（少一層資源、
    狀態更單純、局間 teardown 有明確語意），但**不再是支柱 4／5 的存亡問題**。
    下列原始論述保留作為背景：
    Relay 對**每個 client 連線**的存活時限是 **10 秒**（host 在 BIND 後尚無 peer 時為 60 秒），
    靠 NGO 自動送出的 PING（間隔＝`HeartbeatTimeoutMS`＝500ms）持續重置。
    **但瀏覽器會節流背景分頁的 timer**——Host 切到背景貼連結時 PING 很可能停送，
    **10 秒內即被 Relay 踢掉**。
    後果分兩種情況：
    - **若 Lobby 階段已建立 Relay 連線**（即 #23 的拆分不成立）：Host 切分頁 10 秒就掉線，
      **AC34a（30s）與 AC34b（120s）必然失敗**，且失敗發生在 **Relay 層**，比 #23b 描述的
      MPS 服務層更早觸發。
    - **若 #23 的延後建連成立**：Lobby 階段根本沒有 Relay 連線，不存在會逾時的東西，設計成立。
    **因此 `[P-10]` 查證項 (b)（能否拆分）不是效能優化問題，而是整條 Lobby 設計成立與否的問題**
    ——若不可拆，走 #23 的替代設計 (b)：Host 可離開分頁的最長秒數改以 **10 秒**（而非 MPS TTL）
    × `lobby_bg_safety_factor` 計算，並在 Lobby UI 對 Host 誠實呈現。
    ⚠ 另：`HeartbeatTimeoutMS` 是**雙重用途**（UTP 連線 heartbeat ＋ Relay PING 間隔），
    調大到 >10s 會直接破壞 Relay keepalive——**此值不得調動**，已在 Tuning Knobs 標記。

23b. **MPS session 自身的服務端存活要求** ✅ **（W1 第 3 批實測：擔憂不成立，2026-09-14）**：

    🟢 **實測結論：背景分頁不會讓 session 被回收。**
    先前的推論是「保活掛在 PlayerLoop 上 → 背景分頁 Update 不執行 → heartbeat 停送」。
    **前半正確，後半錯誤**——關鍵在於背景分頁**不是停止主迴圈，而是節流**。

    | 背景時長 | Update 次數 | 平均 | 最大 Update 間隔 |
    |---|---|---|---|
    | 4.4s | 9 | 2.1 fps | 1001 ms |
    | 201.0s | 209 | 1.0 fps | 1601 ms（發生在第 6 秒，啟動初期） |
    | 384.7s | 396 | 1.0 fps | 1601 ms（**六分半鐘內未惡化**） |

    Chrome 桌面版把背景分頁的主迴圈節流到**穩定 1 Hz**，且六分半鐘內**未觸發 Page Freezing**。
    - MPS heartbeat 間隔 **10 秒** → 1 Hz 下照常送出 ✅
    - Relay PING 間隔 **500ms** → 節流後約 1 秒一次，仍**遠低於 10 秒 TTL** ✅
    - **兩個計時器都活著，#23b 與 #23c 的擔憂皆不成立。**

    ⚠ **實測範圍的誠實邊界**：macOS 桌面 Chrome、分頁背景化（非視窗最小化、非系統休眠）、
    六分半鐘。**行動瀏覽器不在此列**——iOS Safari 的背景回收遠比桌面激進，OQ#10 仍然有效。
    下列原始擔憂保留作為背景說明：
    - **保活機制確認存在**：`LobbyHandler` 有週期性 heartbeat 排程，間隔常數
      `LobbySettings.HeartbeatSeconds => 10`（**10 秒**）。
    - **它確實掛在 Unity 主迴圈上**：排程器 `ActionScheduler` 使用
      `PlayerLoopSystem` 並呼叫 `JoinPlayerLoopSystem()`；`RunScheduledHeartbeat`
      還有一道 `if (Application.isPlaying)` 檢查。
    - **後果**：WebGL 的主迴圈由瀏覽器動畫影格驅動，背景分頁會被節流甚至完全停止 →
      **保活訊號停送**。這正是本條原本擔心的事，現已**不是猜測而是機制事實**。
    - **剩餘未知**：Lobby 服務端「多久沒收到 heartbeat 就回收房間」的實際秒數。
      這需要 Release Web build ＋ 真實瀏覽器背景化實測（第 3 批）。
    - ⚠ **與 Relay 的 10 秒 TTL 是兩個獨立的計時器**，兩者都受背景分頁節流影響，
      但**Relay 那個更早觸發**（見 #23c）。原本以下的描述保留作為背景：
    #23 的立論是「Lobby 不存在會逾時的**即時傳輸**連線」。但 session／lobby 本身可能有
    service-side liveness 需求（Lobby 服務靠週期性 heartbeat 維持房間存活）。而 SDK 的
    計時器跑在 **Unity 主迴圈（rAF 驅動）** 上——正是 #17 自己主張「背景分頁 Update
    完全不執行」的那個迴圈。兩件事放在一起：**Host 切到背景，session heartbeat 大機率
    一起停**。若服務端逾時是 30 秒量級，AC34 會在**服務層**失敗，而 #23 消滅的 transport
    層逾時根本沒碰到這個機制。
    **原型必須分辨失敗發生在哪一層**，否則量了等於沒量。
    若確為服務層停擺 → fallback 為以 `.jslib`／Web Worker 維持最小 keepalive
    （背景分頁仍可執行的 timer），或接受 Lobby 背景上限並走 (b)。

    **必做配套（不等原型）**：Lobby 內「複製邀請連結」按鈕（降低切分頁的必要性；
    WebGL 的 clipboard API 需 user gesture＋`.jslib` 橋接，見 `[P-19]`）；
    「店長顧著店別亂跑」改為積極引導文案（實際文案歸 `/ux-design`）

**斷線處置與離開偵測（r4 新增 #24-#27）**
24. **Host 的斷線處置原子序列**——r3 只定義了「結果」（#11），從未定義誰做、依什麼順序做。

    ⚠⚠ **前置條件（W1 第 0 批查證，2026-09-13，優先於下列所有步驟）**：
    **所有可攜帶道具的 prefab 必須在 `NetworkObject` 上勾選 `DontDestroyWithOwner`。**
    查證結果：該欄位**預設 `false`**，而 NGO 在 owner 斷線時的清理
    （`NetworkConnectionManager.OnClientDisconnectFromServer`）會 despawn 並 **destroy** 其
    所有 owned NetworkObject，**且這件事發生在 `OnClientDisconnectCallback` 之前、同一個
    同步 call stack 內**。
    **後果**：若未設定，下列步驟 2（掉落）執行時物件**已經不存在**，救不回來——
    r4 把「掉落」寫成序列的第 2 步，隱含假設了「物件還在」，那個假設在預設設定下為假。
    設為 `true` 後走 `RemoveOwnership()` 分支：ownership 交還 Host，`NetworkObjectId` 不變
    （不消失也不複製，符合 AC10／AC14）。
    ⚠ **但 `RemoveOwnership()` 不做 unparent**——官方對「保留時物件的 transform／parent
    會怎樣」完全無記載。道具若 parented 到玩家身上，玩家 GameObject 被銷毀時道具會跟著走。
    **「掉落於斷線當下座標」必須由 Host 自行實作**（unparent → 設落地座標），不得假設引擎代勞。

    Host 判定某 client 斷線後（#20 逾時、單向失效、或 NGO `OnClientDisconnectCallback`），
    依**固定順序**執行，全序列於 `disconnect_cleanup_sec`（2s）內完成：
    1. **凍結該 client 的輸入採納**——因 #2 是 owner 權威移動，不凍結的話該 client 恢復
       前景時 flush 出的 NetworkTransform 更新會讓一個**已被判定離線的角色動起來**
    2. **手持物品掉落**於斷線當下座標（#11）——**Host 主動 unparent ＋ 設落地座標**，
       再依前置條件由 `RemoveOwnership()` 把 ownership 收回 Host（引擎不會代勞定位）
    3. **站台解鎖**、`ClaimGeneration` +1
    4. **roster 更新**為離線
    5. **despawn 該玩家的 avatar NetworkObject**——不留殭屍。窄店面裡站著一具不會動的
       人形會把「借過」機制變成「撞牆」，直接傷害支柱 3「隊友是活的動線」
    6. **釋放 MPS session 名額**：Host 呼叫 host-side 的成員移除 API（見 #24a）
    7. **`online_player_count` 重新取樣**、寬限期起算（#14／#15／#15a）

24a. **MPS session 成員的唯一寫入者是 Host（r4 新增）**：
    `max_players` 由 **MPS／Lobby 服務端**在 `JoinSessionByCodeAsync` 就擋下——那是 NGO
    connection approval **之前**的一道獨立閘門。拔線者的 C# 不會執行，`LeaveSessionAsync`
    永遠不會被呼叫；WebGL 關分頁時 `OnApplicationQuit` 同樣不可靠。因此若無人代為移除，
    2 人 MVP 房的斷線者點連結回來會撞「這班人滿了」（AC33／AC36 與 AC8 互相打架）。
    - **`max_players` 的唯一執行點＝MPS join**；NGO 側只做二次驗證
    - **Host 判定斷線後呼叫 `session.AsHost().RemovePlayerAsync(playerId)`** ✅ **（W1 第 1 批確認存在，2026-09-13）**——`ISession.AsHost()` 取得 `IHostSession`，其上有 `RemovePlayerAsync(string playerId)` 與 `DeleteAsync()`。**這是 r4 全表唯一「沒有退路」的查證項，現已解除。**
    - **等待中的加入者（Lobby 前一班進行中）佔 `session_member_count`，但不計入
      `online_player_count`**——兩個計數本來就不相等（#11）
    - **Host 自己消失時無人可執行本條**：這是 MVP 無 host migration 的設計限制，
      不是 bug。服務端資源釋放改依服務端閒置回收，時限由 `[P-9]` 回填（見 AC13b 的拆分）

25. **Lobby 階段的 Host 離開偵測（r4 新增）**：Lobby 依 #23 無 NGO 連線、依 #20 不跑心跳，
    r3 卻在適用性矩陣把 #12 的 Lobby 欄標 Y，且 Lobby 畫面已對玩家明示「房主離開視為
    本局結束」——**承諾了一個沒有機制的行為**，留在 Lobby 的人會盯著一個說謊的 roster
    數十秒，直到服務端回收房間。這穩定觸發支柱 5 的「純看戲 >30s」。
    **偵測來源＝訂閱 `ISession` 的成員事件** ✅（與 #18 排歧表序 1 同一機制，一次做兩件事）：
    client 於進入 Lobby 時即訂閱 `session.Deleted`／`session.SessionHostChanged`／
    `session.PlayerLeaving`，收到 Host 對應事件即顯示「店長把鐵門拉下來了」→Idle。

    ✅🔴 **實測結果：兩條路徑差 116 倍（W1 第 1 批雙進程，2026-09-13）**

    | Host 離開方式 | client 得知時間 | 命中訊號 |
    |---|---|---|
    | **優雅離開**（主動呼叫 `DeleteAsync()`） | **1.14 秒** | `session.Deleted`（隨後 `SessionState → Disconnected`） |
    | **被強制終止**（`kill -9`） | **132.61 秒** | `session.PlayerLeaving` |

    **這改變了問題的形狀。** 原本看起來是「Lobby 偵測根本不可行」，
    實際上是「**只要走到優雅路徑就幾乎即時**」——而關分頁、按離開、導頁這些
    **最常見的動作全都有機會走優雅路徑**。真正沒救的只有當機／斷電／行程被強制結束。

    **直接後果：#12 的 `beforeunload` ＋ 主動通知從「best-effort 錦上添花」升格為
    「關鍵機制」。** 它不再只是攔阻誤觸，而是**把 132 秒變成 1.14 秒的那個開關**。
    - 測法：Host 與 client 各為獨立 Unity 進程與獨立匿名帳號；client 加入後 `kill -9` Host
      （模擬行程被強制終止），client 同時訂閱五個事件並以 5 秒間隔輪詢 `HasPlayer(Host)`，
      記錄哪個訊號先到。
    - 結果：**`PlayerLeaving` 於 132.61 秒後到達**；輪詢路徑未更早命中——服務端在那之前
      根本還沒把 Host 移出名冊，**兩條路徑同步，慢的是服務端判定本身**。
    - 判讀：132 秒幾乎確定是服務端等 lobby heartbeat 逾時的時間
      （Host 每 `HeartbeatSeconds`＝10 秒送一次，被 kill 後停送）；
      而 1.14 秒是服務端收到主動刪除請求後的事件廣播延遲——**兩者量的是不同東西**。
    - **衝擊（已縮小）**：支柱 5 的 design test 是「純看戲 >30 秒就重做」。
      優雅路徑 1.14 秒**遠低於紅線**；只有強制終止路徑的 132 秒超標，
      而那是**罕見情境**（當機／斷電／強制結束行程）。
      r4 曾指出「矩陣承諾了一個沒有機制的行為」——現在機制有了，
      且**在最常見的路徑上夠快**。
    - ⚠ **本數字僅適用於 Lobby（純 session 層）**。InShift 有 NGO 心跳
      （`heartbeat_timeout_sec`＝8 秒判定），該路徑不受影響。**問題精確地只在 Lobby。**
    - ✅ **arlong 已裁決（2026-09-13）：慢路徑採「本地逾時提示」。**
      Lobby **自己計時**，自最後一次收到任何 session 事件起超過
      `lobby_host_silence_timeout_sec`（30s）仍無動靜，即顯示
      「跟店長聯絡不上……」等店語提示 ＋ **可離開按鈕**。
      **不等服務端**——服務端那 132 秒不在我們控制範圍內。
      理由：這是唯一同時做到「不承諾做不到的事」與「卡在支柱 5 的 30 秒紅線內」的解。
      實際文案與視覺歸 `/ux-design`。

26. **「開始上班」轉場（Lobby → InShift，r4 新增）**：依 #23，Relay allocation 與 NGO 連線
    在此刻才建立；依 #23a，第二班起還要重跑一次。這是**最常見的開局路徑**（所有人都已在
    Lobby，Host 按下開始），比中途加入更高頻，而 r3 對它沒有任何時間預算、AC 或畫面定義。
    - **預算**：歸入既有的 `T_spawn ≤10s`（不新增預算項，但 AC7b 須單獨量測本段）
    - **呈現**：必須以**世界語言**遮蔽（打卡鐘、鐵門升起、日光燈逐盞亮起）——班次開始
      本來就是一個天然的敘事節拍，這是機會不是麻煩。視覺歸 `/ux-design`
    - **鐵律適用**：本轉場發生在 build 已載入之後，因此「遊戲內絕不出現等待畫面」
      **完全適用**——不得出現進度條或「連線中」

27. **冷啟動 stall 偵測（r4 新增）**：以「下載位元組數連續 `load_stall_timeout_sec` 無增長」
    判定 stall（**不是總時長逾時**——節流網路下 `T_load ≈80s` 是公式⑤自承的預期常態，
    總時長逾時會誤判正常的慢速下載）。判定後顯示世界語言的「鐵門卡住了，重新整理看看」
    ＋重試鈕。States 表相應在 Idle 之前補 **Booting／LoadFailed** 分支——原本 Idle 的進入
    條件「App 啟動」預設成功，而唯一的錯誤態 ServiceError 被限縮在 build 已載入之後，
    涵蓋不到 404／斷網／瀏覽器不相容。視覺歸 `/ux-design`

28. **Relay region 貼著 Host 選（W1 第 4 批實測後新增；arlong 2026-09-15 裁決「讓國外的人
    也可以參與」）**：Host 在建立 allocation 前，依 `relay_region_by_timezone` 查自己的
    時區得出 region 並顯式傳入 `RelayNetworkOptions(region)`；查不到時退到
    `relay_region_offset_fallback`；玩家可在建房介面覆寫（AC22b）。

    **為什麼是「貼著 Host」而不是「貼著多數玩家」或「取中點」**——這不是取捨，是可證明的：
    Relay 的往返路徑是 `client → relay → host → relay → client`，故
    `RTT_i = 2 × (d(i, R) + d(R, H))`。由三角不等式 `d(i,R) + d(R,H) ≥ d(i,H)`，
    **等號在 R 落於 i 與 H 之間時成立，而 R = H 對所有 i 同時成立**。
    把 relay 移向某個 client 只會讓其他 client 變差；移向 Host 則讓每個人同時拿到
    各自的理論下限 `2 × d(i, H)`。**沒有人因此變差，故無需權衡。**
    ⚠ Host 自己不付這筆延遲（它是權威，自身互動本地結算），所以最佳化的目標是
    **所有 client 的延遲**，Host 不計入。

    **推論：誰當房主，決定了房裡所有人的延遲。** 若一群人多數在歐洲卻由台灣的人開房，
    全體都被綁在 `2 × d(自己, 台灣)` 上，而換一個歐洲的人開房即可消除。
    這是 Lobby UI 應該讓玩家知道的資訊（AC22a），也是 OQ#18（host migration）
    在 MVP 之後的一個實際用途。

    ⚠ **時區必須用 `.jslib` 讀 `Intl.DateTimeFormat().resolvedOptions().timeZone`，
    不可用 .NET `TimeZoneInfo`**——Unity Web 的時區資料庫不完整。
    `.jslib` 橋接在 IL2CPP ＋ Managed Stripping High 下的存活已於 W1 第 2 批證實。
    ⚠ VPN 與旅居者會被判到錯的區。這是**接受的誤差**：後果是延遲較高，不是連不上，
    且有覆寫出口。

### 狀態 × Core Rule 適用性矩陣（r3 結構前置 #1；r4 擴充）

Y＝適用、N＝明確不適用、–＝該狀態下無此概念（N.A.）。空格即未裁決，不得留白。
狀態縮寫：**Boot**（Booting／LoadFailed，r4 新增）／Idle／SvcErr（ServiceError）／
Creating／Joining／Lobby／**Lobby\***（Lobby 前一班進行中，r4 新增）／Onb（Onboarding）／
InShift／Disc（Disconnected）／Settle（Settlement）。

| Rule | Boot | Idle | SvcErr | Creating | Joining | Lobby | Lobby\* | Onb | InShift | Disc | Settle |
|---|---|---|---|---|---|---|---|---|---|---|---|
| #1 Host 權威 | – | – | – | – | – | Y | Y | Y | Y | – | Y |
| #2 Owner 權威（移動） | – | – | – | – | – | N | N | N | Y | – | N |
| #3 RPC request→validate | – | – | – | – | – | N | N | N | Y | – | N |
| #4 claim NetworkVariable | – | – | – | – | – | – | – | Y（讀現值） | Y | – | – |
| #5 撲空不回滾 | – | – | – | – | – | – | – | – | Y | – | – |
| #6 交接完成＝Host 提交 | – | – | – | – | – | – | – | – | Y | – | – |
| #7 附著點遮蔽 | – | – | – | – | – | – | – | – | Y | – | – |
| #8 帶碼／輸碼規則 | – | Y | – | – | Y | – | – | – | – | – | – |
| #9 鎖 join（approval 閘門） | – | – | – | – | Y | – | – | – | Y | – | Y（全程鎖） |
| #10 更衣室約束 | – | – | – | – | – | – | – | Y | – | – | – |
| #11 斷線掉落／解鎖／slot | – | – | – | – | – | N（直接離開） | N（直接離開） | N（視同未加入） | Y | Y | N（slot 隨結算釋放） |
| #12 Host 關頁＋beforeunload＋end_shift_early | – | – | – | N | – | Y | Y | Y | Y | – | Y |
| #13 進房預算 | Y | Y | – | Y | Y | Y | – | Y | – | – | – |
| #14 離線立即重取樣 | – | – | – | – | – | N | N | N | Y | – | N |
| #15 寬限期（含 rejoin 提前結束） | – | – | – | – | – | N | N | N | Y | – | N |
| **#15a 重複離線抑制（第 2 次起不給寬限）** | – | – | – | – | – | N | N | N | **Y** | – | N |
| #16 僅計在線；多重離線 | – | – | – | – | – | N | N | N | Y | – | N |
| #17 背景 ≤5s/>5s 分流 | N | N | N | N | N | **N** | **N** | **N** | **Y** | – | **N** |
| **#17a teardown 不變式（任何 →Idle 路徑）** | – | – | – | – | – | Y | Y | **Y** | **Y** | **Y** | Y |
| #18 Host 消失排歧表 | N | N | N | N | N | **N**（改由 #25） | **N**（改由 #25） | Y | **Y** | – | **Y** |
| #19 單物件 sequence | – | – | – | – | – | – | – | Y | Y | – | – |
| #20 心跳 2s/8s（NGO 連線存在期間） | N | N | N | N | N | **N**（無 NGO 連線） | **N** | **Y** | **Y** | – | **Y** |
| #21 Host 獨留續戰／提前收班 | – | – | – | – | – | N | N | – | Y | – | – |
| #22 Settlement 逾時 | – | – | – | – | – | – | – | – | – | – | Y |
| #23 Lobby 延後建連＋複製連結 | – | – | – | Y | Y | Y | Y | – | – | – | – |
| **#23a 局間 teardown（回 MPS-only）** | – | – | – | – | – | Y（進入時已完成） | – | – | – | – | **Y**（離開時執行） |
| **#24 Host 斷線處置原子序列** | – | – | – | – | – | N | N | N（視同未加入） | **Y** | **Y** | **Y** |
| **#24a MPS 成員唯一寫入者＝Host** | – | – | – | Y | Y | **Y** | **Y** | **Y** | **Y** | Y | **Y** |
| **#25 Lobby 的 Host 離開偵測（MPS 事件）** | – | – | – | – | – | **Y** | **Y** | – | – | – | – |
| **#26 「開始上班」轉場** | – | – | – | – | – | **Y** | – | – | – | – | – |
| **#27 冷啟動 stall 偵測** | **Y** | – | – | – | – | – | – | – | – | – | – |
| **#28 Relay region 貼著 Host 選** | – | – | – | **Y**（協定於建 session 時定） | – | **Y**（region 於 #26 建 allocation 時定） | **Y** | – | – | – | – |

### States and Transitions

| 狀態 | 進入條件 | 離開/轉移 | 玩家看到 | 層級 |
|---|---|---|---|---|
| **Booting**（r4 新增） | 開啟頁面，build 下載中 | 下載完成→Idle；**stall（位元組數連續 `load_stall_timeout_sec` 無增長，#27）→LoadFailed** | 客製 Web Template 的世界語言等待畫面（鐵門緩緩升起；禁百分比與技術術語） | MVP |
| **LoadFailed**（r4 新增） | #27 判定 stall，或資源 404／不相容 | 重試→Booting | 「鐵門卡住了，重新整理看看」＋重試鈕 | MVP |
| Idle | **Booting 完成**（r4 改：原寫「App 啟動」預設成功，涵蓋不到載入失敗） | 選建房/加入；**UGS 初始化或匿名登入失敗→ServiceError** | 主選單 | MVP |
| ServiceError | `UnityServices.InitializeAsync()` 或 `SignInAnonymouslyAsync()` 失敗（UGS 中斷、防火牆擋網域） | 重試成功→Idle；放棄→Idle（單人練習仍可玩） | 「總公司系統維修中」＋重試鈕；**不得只顯示技術錯誤碼** | MVP |
| CreatingRoom | 點「建立房間」 | 成功→Lobby；失敗→Idle＋「排班表印壞了，再試一次」。**背景化不觸發任何判定** | 「排班表準備中」 | MVP |
| JoiningRoom | 輸碼或帶碼連結 | 成功→Lobby；碼失效→「這班沒這個人喔」；**滿員→「這班人滿了」**；**已過加入截止（班次剩 ≤30s 或 Settlement 中）→「這班快下班了，你排下一班」→下一局 Lobby**；皆回 Idle 或 Lobby。**背景化不觸發任何判定** | 輸入工號畫面 | MVP |
| Onboarding | 中途加入且通過截止檢查 | 3.0-5.0s 後→InShift（同步未完亦準時進場，#10）；**自身斷線→視同從未加入（不建 roster、不進 Disconnected）→Idle**；**偵測到 Host 消失（#18 排歧表，Onboarding 期間即已監聽心跳）→ 依得知路徑分流（r4 二次修訂，與 AC37a／37b 同步）：(a) 即時訊號（socket close／MPS 事件）→ 得知後 ≤`ui_feedback_sec` 中止過場→「店長把鐵門拉下來了」→Idle；(b) 心跳逾時路徑（8s > 更衣室上限 5s，過場內不可能觸發）→ **準時進場**，進場後依 AC6b 收局終** | **更衣室**（約束：比分＋剩餘時間；視覺歸 /ux-design） | MVP |
| Lobby | 進入 session（首次），或 **Settlement 結束（#23a，已 teardown 回 MPS-only）** | **房主按「開始上班」→#26 轉場→InShift**；全員離開→Idle；**此狀態 socket close 或主動離開→直接離開 session（不進 Disconnected，無 slot 保留）**；**任何角色（含 Host）分頁背景化不觸發斷線判定、不跑心跳（#17/#20/#23）**；**Host 離開由 MPS session 事件偵測（#25）→「店長把鐵門拉下來了」→Idle** | 房號、隊友名牌、Ready、**複製邀請連結**、「房主離開視為本局結束」 | MVP |
| **Lobby\*（前一班進行中）**（r4 新增） | **#9 的 approval 閘門拒絕但 MPS 成員已成立**（班次剩 ≤30s 或 Settlement 中） | 前一班進 Settlement→Lobby 時**與既有玩家合流**（不另開新房，是同一 session 的下一個狀態）；主動離開→Idle；**Host 離開→#25** | **明確告知「這班還在忙，08:00 交接」＋剩餘時間＋在場隊友人數（不得看起來像空房）**；**等待期間開放單人練習沙盒**（arlong 裁決，見下） | MVP |
| InShift | **#26 轉場完成**（r4 改：原寫「Lobby 倒數結束」，該名詞全文僅此一次出現、無旋鈕、無常數、無 AC，屬孤兒名詞，已刪除）／Onboarding 結束 | 時鐘到 `shift_end_ts`→Settlement；**心跳逾時（#20）經 #18 排歧或背景 >5s→依 #17a teardown→Disconnected**；**Host 獨留→續戰（#21）；Host 按 `end_shift_early`→Settlement** | 遊戲主畫面 | MVP |
| Disconnected | **僅由 InShift 進入**（心跳逾時／背景逾 5 秒） | **MVP：瞬時狀態**——顯示店語 `disconnect_notice_dwell_sec`（2s）後→Idle（slot 已釋放，重新點連結＝新玩家加入）。**Post-MVP**：窗口內重連→InShift；逾時或班次結束→踢出至 Idle | **MVP**：「這班你先下班了——點連結再回來上工」（無倒數）→主選單。**Post**：「去後場拿貨…」＋倒數 | MVP／Post |
| Settlement | 時鐘到 `shift_end_ts`／`end_shift_early` | 全員確認或 **`settlement_timeout_sec`（20s）逾時→#23a teardown→Lobby**（#22）。**背景化不觸發任何判定**；**心跳仍運行**（#20 涵蓋 Settlement） | 星級結算、再開一班 | MVP |

註：`Disconnected` 僅存在於 InShift；Booting／LoadFailed／Lobby／Lobby\*／CreatingRoom／
JoiningRoom／Onboarding／Settlement 期間的分頁背景化**一律不算斷線**，連線中斷
（socket close）一律視為離開，不觸發重連窗口（公式①的 `t_disconnect` 亦僅定義於班次內）。

**Lobby\* 的支柱 5 出口（arlong 於 r4 裁決）**：等待者在 MPS 層**已經是 session member**，
他的處境不是「還沒進來」，而是「已在房裡但沒有 avatar」。最長等待可達
`late_join_cutoff_sec`（30s）＋`settlement_timeout_sec`（20s）＝ **50s**，遠超支柱 5 的
「純看戲 >30s 就重做」，而且若他是第一個到的，那還是一間**沒有隊友的空房**——對一個
Fellowship 排第一的遊戲，無陪伴的等待比純看戲更糟。
**裁決：等待期間開放既有的單人練習沙盒**（系統 #19「單人練習模式」），讓他在自己的
店裡暖身。理由：復用一個本來就必須存在的模式，直接兌現「任何狀態都有事可做」，
不新增系統。沙盒內容與縮放歸單人練習模式 GDD；本 GDD 只定**約束**：
(a) 沙盒不得與正在進行的班次共享任何狀態；(b) 前一班進 Lobby 的瞬間必須**可中斷**地
把他拉回合流（不得因沙盒正在進行而延遲合流）；(c) 畫面必須同時可見「前一班還剩多久」。

### Interactions with Other Systems

**本層消費的輸入訊號（r4 新增）**——下游契約寫得很清楚，但 session 層自己吃哪些引擎／
服務事件從未列出，而這些正是 #18／#24／#24a／#25 的實作載體：

| 來源 | 訊號 | 本層用途 |
|---|---|---|
| NGO | `OnClientConnectedCallback` | roster 建立、#26 轉場完成判定 |
| NGO | `OnClientDisconnectCallback`＋`DisconnectReason` | #24 斷線處置序列的觸發源之一（另一源是 #20 心跳逾時） |
| NGO | `ConnectionApprovalCallback` | **#9 截止閘門的唯一執行點**＋build/protocol 版本閘 `[P-17]` |
| NGO | `OnTransportFailure` | 走 #17a teardown →「無法排歧」分支 |
| MPS Session | 成員事件（`PlayerLeft`／`RemovedFromSession`／`SessionDeleted` 或 2.3.1 等價名稱 `[P-10]`） | **#18 排歧表序 1**（Host 消失的正面證據）＋**#25**（Lobby 的唯一偵測來源） |
| MPS Session | session 層可達性（事件到達／輪詢成功） | **#18 排歧表序 3**（「我的網路好不好」的獨立證據） |
| MPS Session | host-side 成員移除 API `[P-10]` | **#24a**（釋放 `max_players` 名額） |
| 瀏覽器（`.jslib`） | `visibilitychange`＋`performance.now()` `[P-7]` | #17 背景分流（時間源必須單調） |
| 瀏覽器（`.jslib`） | `navigator.onLine` | #18 排歧表序 2，**僅作快速否定** |
| 瀏覽器（`.jslib`） | `beforeunload`＋`sendBeacon` `[P-18]` | #12 攔阻與離開通知 |

介面契約（下游系統據此開發；「延遲容忍」指 300ms 尖峰下是否無感）：

| 下游系統 | 送入 | 收到 | 真相擁有者 | 延遲容忍 |
|---|---|---|---|---|
| 第一人稱控制器 | local_ready（spawn 完成） | player_joined(id, slot) / player_left(id) | session 層（roster）；移動歸玩家 | 高（roster 事件罕見） |
| 機台互動組 | RequestInteract(stationId, generation) | InteractResult(stationId, clientId, ok, payload) | Host | 互動判定 RTT 需 <300ms |
| 機台互動組 | — | player_disconnected(id, held[]) → 強制釋放 | session 層 | ≤2s（否則機台卡死） |
| 客人系統 | — | NpcStateChanged(npcId, state, waypointId, ts)（里程碑事件，非逐幀；**當前 state/waypoint 亦存 NetworkVariable** 供遲加入者） | Host | 高（client 本地插值移動） |
| 波次導演 | — | **`online_player_count`**（r4 統一命名，原寫 `player_count`；**加入走波次邊界取樣、離線立即取樣**，見公式④）＋grace_window(15s) 旗標（**rejoin 完成即撤旗**；**#15a 抑制生效時不發此旗**）＋**host_solo 旗標**（#21，N=1 曲線由波次導演 GDD 定義） | session 層 | 高 |
| 遊戲時鐘 | — | **`shift_end_ts`**（NetworkVariable，Host 權威；`end_shift_early` 直接改寫它）＋**時鐘 offset 由 2s 心跳持續估計**（r4 改：刪除「每 60s resync」這條獨立通道，見 #20 的心跳 payload）（**顯示層 catch-up 平滑進行中不套用新 offset**，公式③） | Host | 可容忍，drift 校正非逐幀 |
| 評分邏輯 | — | ScoreChanged(new, delta, reason)；final_roster | Host | 高（結算讀一次） |
| 攜帶與交付 | RequestHandoff(itemId, targetId) | ownership transfer 完成事件（＝Host 提交時刻，#6） | Host | 交接動畫遮蔽 |
| HUD | — | connection_state / room_code / ping | session 層 | 低（500ms-1s 刷新） |
| 大廳 UI | create_room / join_by_code(code) / ready_toggle / **copy_invite_link** / **end_shift_early（提前收班，僅 Host 獨留時可用）** | room_code、roster_updated、session_started | session 層 | <1s 回饋 |
| 結算畫面 | — | final_roster、disconnect_log、session_duration、**settlement_timeout_sec** | session 層 | 高 |

**同步頻率總表**（r4 修正）：玩家 NetworkTransform 10Hz＋插值 `[P-3]`；NPC 事件制
（每 NPC 最快 0.2s 一次）；分數事件制；**心跳 2s（NGO 連線存在期間，涵蓋 Onboarding／
InShift／Settlement；pipeline 選擇為實作細節，見 #20）**。
**時鐘不再有獨立的網路通道**——`shift_end_ts` 是 NetworkVariable（變更時才同步），
offset 掛在心跳上。Tuning Knobs 的「時鐘同步間隔 1s」已更名為**「時鐘顯示更新間隔」**
（純本地渲染節奏，不產生網路流量）——r3 的三處數字衝突（總表 1s／旋鈕 1s／Interactions
表 60s resync）是**命名碰撞**：前兩者指本地顯示，後者指網路校時，現已分離並刪除後者。

**NGO 基礎設施約定**（下游實作前提，架構階段需開 ADR）：
- **單一場景**——不啟用 `NetworkSceneManager` 場景同步。中途加入的更衣室過場是本地
  UI 疊層，不觸發 scene event（否則會打到既有玩家的幀率，違反 AC4）
- **狀態真相走 NetworkVariable，RPC 只驅動表現層**：`IsClaimed`/`ClaimedBy`/**`ClaimGeneration`**
  （同一 struct）、NPC 當前 milestone、時鐘 `session_start_ts` 等「遲加入者必須立刻
  知道」的狀態一律為 NetworkVariable（Host 寫、全員讀，NGO 連線時自動同步現值）；
  RPC 事件（撲空、動畫、音效）不作為狀態來源——NGO 不會對遲加入者重播歷史 RPC
- **所有需跨玩家同步狀態的物件（機台、道具、NPC）一律由 Host 動態 spawn**，登錄
  `NetworkPrefabsList`；**禁止 scene-placed NetworkObject**（關閉 NetworkSceneManager
  後不會同步給遲加入者）；場景只留靜態幾何。spawn/despawn 生命週期由 Host 擁有
- **所有可攜帶道具的 NetworkObject 必須顯式設定為「不隨 owner 銷毀」**
  （`NetworkObject.DontDestroyWithOwner` 或等義欄位），**或**由 Host 在掉落前先收回
  ownership。理由：#6 把交接定義為 ownership transfer，於是手持物成為該 client 的
  **owned NetworkObject**；NGO 在 owner 斷線時對其 owned 物件的處置若為銷毀，AC10
  （≤2s 掉落）與 AC14（「不消失也不複製」）會直接失敗，而且是那種**本地測不出、
  只在真實斷線時出現**的 bug。
  ⚠ **引擎預設值未經確證**（引擎參考文件無記載）——`[P-20]`。無論預設為何，
  **顯式設定都是安全的**，因此本條不等原型即可執行；但文件不得斷言「NGO 預設會銷毀」
- **RPC 一律使用 NGO 2.x 的通用 `[Rpc]` attribute**（r4 新增，可指定目標含 client-to-client）。
  **禁用 NGO 1.x 的 `[ServerRpc]`／`[ClientRpc]`**——引擎參考的棄用表已明列，而本 GDD
  全文只寫「RPC」未指定風格，下游實作者（或訓練資料停在 1.x 的協作 AI）極可能寫成舊式
- **`NetworkTransform.Update` 不可 override**（Unity 6.3 breaking change）——需要自訂更新
  時機時用 `NetworkTransform.OnUpdate` 或 `INetworkUpdateSystem`。本設計 #2 不改寫
  NetworkTransform，但下游實作者容易踩此雷
- **`IsClaimed`/`ClaimedBy`/`ClaimGeneration` 的 struct 需同時實作 `INetworkSerializable`
  與 `IEquatable<T>`**——缺後者會讓 NGO 的變更偵測每幀誤判為 dirty
- **Relay allocation／NGO 連線延後至「開始上班」建立**（#23，`[P-10]`，⚠ **高風險假設**，
  與引擎文件描述的 Sessions API 形狀直接衝突）；Lobby 階段只有 MPS Session 層。
  **局間（Settlement→Lobby）teardown 回 MPS-only**（#23a）
- 重連的「原位恢復」需**自建** session-level player GUID ↔ slot 對照表——
  NGO 重連會配發新 ClientId，此非引擎內建能力 `[P-2]`。**#15a 的離線次數計數也以此
  身分為準**

**班次時鐘語義（r3 裁定，r4 補完真相來源與 offset 協定）**：

**真相＝Host 權威的 `shift_end_ts`**（NetworkVariable）。r3 寫「班次時鐘＝`now − session_start_ts`」
有三個洞：(a) **`now` 是誰的時鐘**從未定義——WebGL 下 C# 的 wall-clock 即 JS `Date.now()`，
直接繼承使用者的系統時鐘，偏差可達數分鐘，而**玩家系統時鐘不準是常態不是邊緣情況**，
這使 AC35（分辨 30.5s 與 29.5s）在 client 側完全不可信；(b) **「班次長度」這個常數在 GDD
與 registry 中都不存在**，而 #9／#21／公式①／AC5／AC13a／AC19／AC35 全部依賴它；
(c) `session_start_ts + 長度` 這種純加法**表達不了 `end_shift_early`**（提前收班會縮短班次）。

- `shift_length_sec` 登錄為常數，是 `shift_end_ts` 的**初值**（`shift_end_ts = 建立時刻 + shift_length_sec`）
- **`end_shift_early` 直接改寫 `shift_end_ts`**——這是它能被表達的唯一方式
- **client↔Host 的時鐘 offset 由既有的 2s 心跳持續估計**（#20 的 payload 帶
  `host_shift_end_ts`）：`offset = host_value − (local_value + RTT/2)`，RTT 由心跳往返得出。
  收斂精度目標 ≤`clock_offset_tolerance_ms`（100ms）
- **所有「班次剩餘」的權威判定一律在 Host 側**（#9 的 approval 閘門即依此）；client 側的
  倒數顯示是套用 offset 後的估計值，不具權威

**模擬（波次導演、NPC、客人耐心）不快轉、不補跑**：Host 背景化期間模擬凍結，恢復後從
凍結點續跑，落差（≤5s，>5s 已走局終路徑）以「少了那幾秒的客人」吸收。快轉模擬會製造
本設計禁止的瞬移與不可控的難度尖峰。班次長度本身不因任何人的分頁行為延長。

**背景恢復時三種物件各走各的追平規則**（皆為**顯示層**，不改模擬）：時鐘→公式③
（2 秒線性平滑，避免數字硬跳）；玩家角色→NetworkTransform 插值（單幀 ≤ 移動速度上限）；
NPC→下述 `npc_milestone_catchup_sec`（0.2 秒）milestone 補位。三者互不套用對方的時間常數。

**Host 凍結期間的 client 行為**（背景化 ≤5 秒的情況）：client 端 NPC **凍結在原地
不外插**（milestone 事件缺席時不得自行推進）；恢復後若一次收到多個堆積 milestone，
只套用**最新一筆**並以 `npc_milestone_catchup_sec`（0.2 秒）內插補位移，中間狀態捨棄——避免連續瞬移 `[P-12]`。
NPC 本地插值僅在兩個 milestone 之間執行；若玩家肉身阻擋導致本地路徑與 Host 分岔，
下一筆 milestone 到達時以同樣的 `npc_milestone_catchup_sec` 補位規則收斂，不瞬跳。

## Formulas

**① 重連窗口**：`T_deadline = t_disconnect + W`

| 變數 | 符號 | 型別 | 範圍 | 說明 |
|---|---|---|---|---|
| 斷線時刻 | t_disconnect | float | ≥0（班次內秒數，上界＝`shift_length_sec`） | 心跳逾時**判定**的時間點＝`t_actual + T_detect` |
| 偵測延遲 | T_detect | float | `relay_disconnect_propagation_sec`（2s，優雅 close）～`heartbeat_timeout_sec`（8s，拔線） | 真實斷線到 **Host 判定**的延遲。**r4 修正：優雅 close 路徑不是 0**——Relay 架構下 client 與 Host 之間沒有直接 socket，Host 得知的時刻是 Relay 偵測並傳播的時刻 `[P-8]`。AC 的「≤2s 後處理」自**判定時刻**起算 |
| 保留窗口 | W | int | 30（tuning 10-90） | slot 保留秒數（Post-MVP）；約束為 **`W + heartbeat_timeout_sec ≤ Relay allocation idle timeout`** `[P-9]`（r4 修正：原約束 `W ≤ idle timeout` 漏計 T_detect——拔線情境下服務端會比 W 早 8s 釋放） |

輸出：T_deadline 或班次結束（先到者）→ slot 釋放。後段斷線（t_disconnect＋W > 班次結束）
時窗口實質為 0，屬設計接受。
範例：班次 3:00 斷線 → 3:30 前重連保留原位、手持物品已於斷線 ≤2s 掉落。

**② 進房時間預算**：`T_join = T_load + T_lobby + T_spawn ≤ 60s（硬標）`

| 變數 | 預算 | 說明 |
|---|---|---|
| T_load | ≤25s | Web build 載入（loader.js／framework.js／wasm／data 3-4 個獨立資源各有 TTFB；anonymous auth 並行預熱，額外 0s） |
| T_lobby | ≤10s | 帶碼連結免輸入；暱稱自動產生、可後改不阻擋 |
| T_spawn | ≤10s | 含中途加入 3-5s 過場 |
| 合計 | ≤45s | 對支柱硬標 60s 留 15s（25%）緩衝 |

每一分段皆須**單獨**量測（AC7a），不得以總和抵銷。

**③ 分頁背景分流**：`T_bg = t_visible − t_hidden`（由 `visibilitychange` 標記，
**不使用 frame delta**——背景分頁 Update 完全不執行，量不到）

| 條件 | 處理 | 理由 |
|---|---|---|
| `T_bg ≤ 5s`（含端點） | **顯示層** catch-up：`drift = T_bg`，2 秒線性追平，**顯示倍速 `rate = 1 + drift/2`**（drift=0→1.0×；drift=3→2.5×；drift=5→**3.5×**，2 秒內推進 2+5=7 秒）。**模擬不變**（見班次時鐘語義） | 短切分頁可無痛追回顯示，避免數字硬跳 |
| `T_bg > 5s` | **視同斷線**，client 主動 teardown 後走斷線流程（#17） | drift 上限——數十秒壓進 2 秒＝本設計自己禁止的瞬移 |
| catch-up 中再次背景 | 取消當次 catch-up，以新的 `t_hidden` 重新分流 | 避免 drift 疊加未定義 |
| catch-up 中收到心跳的新時鐘 offset | **暫緩套用**，catch-up 完成後再套 | 避免二次跳動。r4：原寫「遇 60s resync」，該獨立通道已刪除（offset 現掛在 2s 心跳上，見 #20） |

| `T_bg < 0` | **視為 0，不觸發 catch-up**，直接以現值顯示 | r4 新增的退化輸入防呆。若 `t_hidden`/`t_visible` 取自 wall-clock（NTP 校時、使用者手動改時間），`T_bg` 可為負，代入 `rate = 1 + drift/2` 得 `rate < 1`（追平比即時還慢，語義未定義）。時間源已於 #17 訂為 `.jslib` 的 `performance.now()`（單調），本條是第二道防線 |

5.00s vs 5.01s 為**硬懸崖**，不加 hysteresis（>5s 已走斷線，不存在有意義的來回震盪），
屬已知接受風險。實作以 `T_bg <= threshold` 判定，避免浮點比較誤差。

**`background_disconnect_threshold_sec` 的安全範圍上界為 5，不是 10**（r4 修正）：
代入 `rate = 1 + drift/2`，threshold=10 → `rate = 6.0×`，2 秒內推進 12 秒——這正是本公式
自己禁止的瞬移。品質線反推得出的上界就是 5。原表列的 2-10 與本公式的「不瞬移」鐵律互斥。

**④ 波次人數取樣（非對稱）**：
- 加入：`N_wave(w) = online_player_count @ wave_start(w)`——波次邊界取樣，
  中途加入者只影響下一波（避免中途變難）
- **離線：立即重新取樣**，當前波次剩餘生成量即時降載（保護留守者）
- `online_player_count` **僅計在線玩家**；重連保留中的 slot 不計入
- 寬限期：離線事件後 15 秒內不生成新客人、場上客人耐心 ×1.5
- **多重離線**：第二人於寬限期內離線 → 以**最新**離線時刻重算 15 秒（不疊加）；
  倍率固定 ×1.5 不疊乘。例：A 於 t=0、B 於 t=10 離線 → 寬限至 t=25
- **寬限期內加入完成（含退出者重連）→ 寬限立即結束、立即重新取樣**（#15）。
  例：A 於 t=0 離線、t=6 重連完成 → 寬限於 t=6 結束（非 t=15）
- **同一玩家第 2 次起的離線：仍立即重新取樣與降載，但不觸發寬限期**（#15a，r4 新增）。
  例：A 於 t=0 首次離線 → 降載＋寬限至 t=15；A 於 t=40 第二次離線 → **只降載，無寬限**。
  計數以 session-level player 身分為準，班次結束歸零
- **Host 獨留**（N=1）：仍套用以上規則；密度曲線由波次導演 GDD 定義（`host_solo` 旗標）

| 變數 | 型別 | 範圍 | 說明 |
|---|---|---|---|
| online_player_count | int | 1-4 | 僅在線者；`max_players` 見 registry（MVP 建置暫設 2） |
| grace_window | int | 15（tuning **`heartbeat_timeout_sec`–30**；下界隨 timeout 浮動，見約束⑥⑩） | 離線後的緩衝秒數 |
| patience_mult | float | 1.5（tuning **1.01-2.0**；1.0 是關閉旗標，不在安全範圍內，見約束⑥） | 寬限期內客人耐心倍率 |

**⑤ 載入頻寬假設**（T_load ≤25s 的成立條件）：

🔴 **公式本身於 2026-09-17（W1 第 4 批）被實測推翻——它少了一整項。**
原式 `T_load ≈ build_size ÷ bandwidth ＋ 多資源 TTFB` **沒有任何 CPU 項**，
而實測顯示存在一筆**與頻寬完全無關**的解壓成本。修正後：

```
T_load ≈ build_size ÷ bandwidth          （下載）
       ＋ 多資源 TTFB                      （連線開銷）
       ＋ decompressed_size ÷ js_brotli_decompress_rate   ← 新增，先前不存在
       ＋ wasm 編譯與引擎初始化             （實測 ~0.4s，小項）
```

**為什麼會少這一項**：第 2 批為了繞過 itch.io 不支援 Brotli，把
`decompressionFallback` 設為 `true`，改由 **Unity 的 JS 解壓器**處理 Brotli。
當時記錄為「傳輸量減半、公式⑤ 的預算恢復」，但把**解壓的 CPU 時間**留為未量測。
它不是小數目：

| 量測（8 核桌機、localhost、網路時間趨近 0） | 值 |
|---|---|
| 壓縮 / 解壓後體積 | 6.98 MB → **34.13 MB**（4.89×） |
| 原生 C brotli 解壓同一份資料 | **86 ms**（397 MB/s） |
| **Unity JS 解壓器（相減得出）** | **≈ 2.0-2.2 s（16.3 MB/s，比原生慢約 23 倍）** |
| wasm 編譯（27.5 MB 模組，單獨計時） | 346 ms |
| 預先解壓後的總 CPU（編譯＋引擎初始化） | **331-412 ms** |

配對方式：同一分頁先後載入「壓縮版」與「預先解壓版（檔名不變，loader 原樣通過）」，
兩者差值即解壓成本。壓縮版 CPU 2268-2590 ms（暖）／3600-4323 ms（冷），
預先解壓版 331-412 ms，**差距穩定落在 2 秒量級**。

🔴 **外推到 50MB 的專案硬標，這一項就吃掉整個預算**（⚠ **外推非實測**）：
50 MB × 4.89 ＝ 約 **244 MB** 解壓輸出 ÷ 16.3 MB/s ≈ **15 s**。
代入修正後的公式（20Mbps ＝ 2.5 MB/s、TTFB 5s）：

```
S ＝ 50MB → 50÷2.5 ＋ 5 ＋ 0.30×50 ＋ 0.4 ＝ 20 ＋ 5 ＋ 15 ＋ 0.4 ＝ 40.4 s  ✗（上限 25s）
求解 T_load ≤ 25s → 0.70·S ≤ 19.6 → **S ≤ 約 28 MB**
```

**即：把解壓 CPU 算進去之後，build size 的有效天花板從 50 MB 掉到約 28 MB。**
這跨出本 GDD 權責（`build_size ≤50MB` 是 technical-preferences 的專案級硬標），
**列為必須上呈的裁決事項**，見 OQ#21。

✅ **相加模型已於同日以限速伺服器複驗，並未被推翻**（自寫限速服務，非 DevTools）。
判別法：若解壓與下載重疊，網路變慢時「資料在手後的 CPU」會被吸收而**縮小**；
若相加，它會**維持不變**。

| 網路 | 下載窗口（牆鐘） | **資料在手後 CPU** | 總計 |
|---|---|---|---|
| localhost（暖） | ~0.03 s | **2.27-2.59 s** | 2.5 s |
| 20 Mbps 限速 | 2.45 s | **3.23 s** | 5.82 s |
| 5 Mbps 限速 | **9.35 s** | **2.51 s** | 12.05 s |

**下載時間拉長 300 倍，CPU 項紋風不動** → **解壓不與下載重疊，相加模型成立。**
逐檔時序也一致：5 Mbps 下 `Web.wasm.unityweb` 於 198→9380 ms 下載，
`t_ready` 落在 12052 ms——解壓在下載**結束之後**才開始。
模型回測：5 Mbps 預測 11853 ms vs 實測 12052 ms（差 +199 ms）。

⚠ **仍然存在的弱點（已縮小為兩條）**：
(a) 8 核桌機是**樂觀**硬體；低階筆電與行動裝置只會更慢。
(b) 量的是 7 MB build；線性外推到 50 MB 未經驗證。
⚠ 次要觀察：5 Mbps 下 `Web.data` 早在 3239 ms 就下載完而 wasm 仍在傳，
故**不同檔案之間**可能有少量解壓重疊（模型預測 2.1 s，實測 2.51 s，差距與此相符）；
但主宰時間的 wasm 解壓確定是串行的。

原式的其餘部分仍然成立：50MB ÷ 25s ≈ **16Mbps 持續下載**——
標準網路（20Mbps）下留約 5s 給 3-4 個資源的連線建立開銷。因應：
- 縮 build size 是主要槓桿（專案硬標 ≤50MB，越小越好）。
  **T_load 的餘裕實際為 0**（50MB ÷ 20Mbps ＝ 20s，加多資源 TTFB 5s 恰好用滿 25s）。
  ✅ **W1 第 2 批實測的「地板值」**：一個**幾乎空的專案**（單一 OnGUI 探針 ＋ NGO 2.13.2
  ＋ MPS 2.3.1）Brotli 壓縮後為 **7.0 MB**——`Web.wasm.br` 5607 KB、`Web.data.br` 1472 KB、
  `Web.framework.js.br` 77 KB、`Web.loader.js` 26 KB（未壓縮）。
  即：**netcode 層與 IL2CPP 執行環境就吃掉約 7 MB，留給遊戲內容約 43 MB。**
  這個地板先前完全沒有依據，現在有了。
  因此**不得少列任何一個已知槓桿**（r4 補齊，依 `modules/web.md`）：
  **WebAssembly 2023 開關**（原生 Wasm 例外、SIMD、優化 memcpy、BigInt 互通——效能升、
  體積降，目標客群的瀏覽器支援無虞，**建議開**）、Unity 6.3 的 IL2CPP metadata 變長度索引、
  Strip Engine Code、Managed Stripping High（與 `[P-7]` 的 `[Preserve]` 保護並用）
- 等待畫面分域鐵律（Player Fantasy）在載入期分兩段，**兩段皆已定案**：
  - **(a) mid-join 的 T_spawn 過場**（3-5s）＝更衣室（Core Rules #10）——Unity 場景，
    build 已載入後才存在
  - **(b) 冷啟動的 T_load**（≤25s，每位新玩家第一次都會遇到）：build 尚未下載，更衣室
    **不存在**。**已定案：客製 HTML/CSS Web Template**（Unity 穩定功能，非引擎風險）
    取代預設 loader，以世界語言呈現等待（禁百分比、技術術語）。**MVP 必要交付物**，
    視覺歸 `/ux-design`（Open Questions #8）
- **60s 硬標的成立條件**：僅於「標準網路」（20Mbps）成立。文件自訂的「節流網路」
  （5Mbps）下 `T_load ≈ 50MB×8/5Mbps = 80s`，**超標**——列為已知風險，非本 GDD 可解；
  主要槓桿仍是 build size（AC7 只在標準網路驗收）
- ✅ **itch.io 的 Brotli 支援已實測（W1 第 2 批）：不支援，且會解壓上傳的 `.br` 再重送，
  使傳輸量變成 2.00 倍。強制解法：`decompressionFallback = true`（產出 `.unityweb`，
  由 Unity 自行解壓），實測傳輸量回到 0.99 倍。**
  代價是 loader 增加約 90KB 與解壓的 CPU 時間。
  ⚠ **這條是建置規範的強制項，不是可選優化**——若誤用預設的 `.br`，
  50MB 的 build 在 itch.io 上會變成約 100MB 傳輸，`T_load` 直接翻倍而破 60 秒硬標。

（房間碼格式由 Sessions API 決定，不設自訂公式；碼長於原型回填 `[P-1]`。）

## Edge Cases

- **If 兩人同時 claim 同一機台/道具**：Host 先到先得＋lock；輸家收到明確拒絕事件並播
  撲空回彈動畫——絕不靜默失敗。
- **If 任一玩家分頁背景 ≤5 秒（InShift）**：恢復時走顯示層 catch-up（公式③）；client 端
  NPC 期間凍結不外插，恢復後只套用最新 milestone 並 `npc_milestone_catchup_sec`（0.2s）補位。
- **If 任一玩家分頁背景 >5 秒（InShift）**：client 主動 teardown，視同斷線走斷線流程。
  **Host 若如此則本局結束**（依 Core Rules #12）。此為本系統最大已知風險。
- **If 任何角色於 Lobby／CreatingRoom／JoiningRoom／Onboarding／Settlement 背景化**（含
  Host 切分頁貼連結 30-120 秒）：**不觸發任何斷線判定**，房間存活（#17/#20/#23）。
- **If client 收不到 Host 心跳但無法排歧**（自己全程前景、`navigator.onLine` 為 true、
  且 MPS session 層亦不可得）：走 #18 排歧表的序 5「無法排歧」分支，顯示不預設因果的
  「跟店裡斷線了，點連結重新上工」→依 #17a teardown →Idle。屬已知接受的殘餘 case。
- **If 連線單向失效**（例：只有入站封包被丟棄——client 的出站仍通，Host 持續收得到它的
  心跳）：**兩側都必須動作，缺一即永久軟鎖死**。
  - **client 側**：收不到 Host 心跳 → 走 #18 排歧 → 依 **#17a teardown** 後回 Idle
  - **Host 側**：#20 的心跳 payload 帶 `last_peer_seq_seen`，Host 見該值落後超過
    `heartbeat_timeout_sec` 即判定**單向失效**，走 **#24 完整處置序列**（掉落、解鎖、
    despawn、釋放 MPS 名額、重取樣）
  - **若只修 client 側**（r3 的狀態）：Host 永不逾時 → 名額不釋放、留守者不降載，而該
    玩家已在主選單；他依指示「點連結重新上工」會在 2 人房撞「這班人滿了」——**想回來
    卻回不去的永久軟鎖死**，且同時讓留守者拿不到任何保護。這不是 2 秒的過渡狀態。
  - **若只修 Host 側**：client 端會殘留一個已被 Host 清掉的幽靈連線。
- **If 冷啟動下載卡住**（位元組數連續 `load_stall_timeout_sec` 無增長）：依 #27 進 LoadFailed，
  顯示「鐵門卡住了，重新整理看看」＋重試鈕。**不以總時長逾時判定**——節流網路下
  `T_load ≈80s` 是公式⑤自承的預期常態。
- **If Host 於 Lobby／Lobby\* 離開**（關頁、導頁或斷線）：依 **#25** 由 MPS session 成員事件
  偵測（Lobby 無 NGO 連線也無心跳），顯示「店長把鐵門拉下來了」→Idle。
  時限依 `[P-10]` 實測回填，**不套用 InShift 心跳路徑的 `session_end_worstcase_sec`（12s）**。
- **If 同一玩家於同一班次內第 2 次離線**：依 **#15a**，`online_player_count` 仍立即重取樣、
  波次仍即時降載，但**不進入寬限期**（不生新客人／耐心 ×1.5 皆不適用）。
- **If 玩家在 Settlement 期間斷線**：心跳於 Settlement 仍運行（#20），依 #24 處置；
  其結算成績已由 Host 定案，不因斷線而改變（`final_roster` 保留其名）。
- **If 班次結束進入 Lobby**（#23a）：teardown NGO／Relay 回到 MPS-only。重建成本由
  **#26** 的轉場吸收並以世界語言遮蔽，不得出現讀取條。
- **If 玩家於重連窗口內重連**（Post-MVP）：恢復原 slot 的位置與朝向；手持物品不
  恢復（已於斷線時掉落）。本作**無 HP 概念**——恢復項目僅位置、朝向、slot 與名牌。
- **If 玩家離線（斷線或退出）**：`online_player_count` 立即重新取樣、當前波次即時
  降載、進入 15 秒寬限期（不生成新客人、耐心 ×1.5）——留守者不被雙倍客潮處死。
- **If 寬限期內第二人離線**：以最新離線時刻重算 15 秒，倍率維持 ×1.5（不疊加、不疊乘）。
- **If 寬限期內有人加入完成（含剛退出者用連結重連）**：寬限期**立即結束**、立即重新
  取樣——「退出→重連→再刷寬限」不成立。
- **If 玩家於更衣室過場（Onboarding）中斷線**：視同從未加入——不建 roster、不觸發
  留守者降載、不進 Disconnected，回 Idle。
- **If 更衣室過場結束時同步尚未完成**（慢網路）：仍準時進場，缺項以 NetworkVariable
  現值顯示、同步完成瞬間更新；不延長轉場（#10）。
- **If 更衣室過場中 Host 消失**：Onboarding 期間已監聽 Host 心跳，經 #18 排歧判定 Host
  消失 → **依得知路徑分流**：即時訊號（socket close／MPS 事件）→ 得知後 ≤`ui_feedback_sec`
  中止過場 →「店長把鐵門拉下來了」→Idle；心跳逾時路徑（`heartbeat_timeout_sec` 8s 大於
  更衣室上限 5s，**過場內不可能觸發**）→ 準時進場，進場後依 AC6b 收局終。
- **If Host 分頁背景 >5 秒**：Host 無法自報；client 端於心跳逾時（8s）經排歧表判定 Host
  消失 → 本地結束本局並顯示「店長把鐵門拉下來了」；Host 回前景後自行關閉 session。
- **If 房間已滿（`max_players`）**：加入被拒，訊息「這班人滿了」（與碼失效訊息不同）。
- **If 班次剩餘 ≤30.0 秒或已在 Settlement**：加入被拒並導向下一局 Lobby，訊息
  「這班快下班了，你排下一班」。
- **If 玩家點擊加入時剩 31s、更衣室結束時剩 27s**：截止檢查只在點擊瞬間判一次，
  此玩家照常進場；3-5s 的截止線滑動屬已知接受。
- **If UGS 初始化／匿名登入失敗**：進入 ServiceError 狀態，顯示「總公司系統維修中」
  ＋重試鈕；單人練習模式仍可進入（不依賴 UGS）。
- **If claim lock 5 秒逾時**：站台強制解鎖、`ClaimGeneration` +1；**逾時後才抵達的原請求
  一律作廢**（即使 sequence 合法）——世代不符者拒絕，避免「鎖已釋出、舊請求仍被判
  合法」。邊界：`t ≤ 5.000s` 視為逾時前（含端點，對齊重連窗口 `t ≤ W` 的先例）。
- **If 新加入者首次 claim 帶的世代與 Host 不符**（讀到現值前就送出）：拒絕並播撲空，
  client 以 NetworkVariable 現值重試。
- **If 玩家逾 30s 未重連**（Post-MVP）：slot 釋放，可被新玩家經連結取用。
- **If 房間碼失效或滿員**：明確店語錯誤訊息（「這班沒這個人喔，再確認一次工號——
  或跟朋友要一個新連結」），不得卡在 loading。
- **If 玩家於 Settlement 期間加入**：導向下一局 Lobby，不插入當前結算。
- **If Host 主動關閉分頁**：先觸發 `beforeunload` 確認（best-effort）；確認後 session 於
  優雅 close 路徑 ≤`session_end_graceful_sec`（5s）`[P-13]`、任何路徑 ≤`session_end_worstcase_sec`（12s）內結束，全員收到「店長把鐵門拉下來了」
  通知回主選單（MVP 明示限制）。
- **If WebSocket 尖峰造成 RPC 亂序**：sequence 號比對，舊封包丟棄不覆蓋新狀態。
- **If 其餘玩家全部離線、僅剩 Host**：session **不結束**（#21），Host 單人續戰，套用 N=1
  降載＋寬限期；Host 可按「提前收班」進 Settlement。
- **If Host 亦離線（＝全員離線）**：session 結束、釋放 Relay 配置。
- **If 班次結束時仍有玩家在重連窗口內**（Post-MVP）：slot 隨結算釋放，不延長班次。
- **If 交接瞬間一方斷線**：以 Host 是否已提交 ownership transfer 為準（#6）——未提交則
  物品仍在原持有人處、依其最後位置掉落；已提交則在新持有人處、依**新持有人**最後位置
  掉落。不消失也不複製。
- **If Settlement 有人不按確認**：`settlement_timeout_sec`（20s）到期自動視為全員確認。

## Dependencies

**上游（外部服務，硬依賴）**：
- Unity Gaming Services：Authentication（匿名登入）、Multiplayer Services 2.3.1
  （Sessions/Lobby/Relay）。UGS 不可用＝無法連線遊玩；單人練習模式不經此層（軟化條款）。
- 引擎事實鎖定：`docs/engine-reference/unity/modules/multiplayer.md`（NGO 2.13.2、
  Relay WSS、免費額度 50 CCU）。

**架構風險與退路（r4 新增，風險管理條目）**：
本作選的 **client-as-host ＋ Relay(WSS) ＋ MPS Sessions** 路線**沒有官方端到端的
「Relay-over-WSS Web」成品範例**（引擎參考文件原文：「第一個原型就是在補這個證明」）。
而同一份文件記載，被本作否決的備選 **Distributed Authority 反而正式支援 WebGL**
（NGO 2.1.1+／UTP 2.3.0+／MPS 1.0.2+，有官方 Web quickstart 與 Asteroids Bitesize 樣本）。
這個不對稱先前未被記錄。
- **不改變現行架構決策**：2-4 人、容忍延遲的本作確實用不到 DA 的好處，且 DA 的 authority
  心智模型不同、綁 Unity 雲
- **但 plan B 要事先寫下來**：若 W1 原型證實 client-as-host over Relay WSS 有根本障礙，
  **DA 是有官方 Web 支援的退路**，應優先於自架方案評估
- **自架退路已變窄**：Multiplay Hosting 已於 Unity 6.3 自編輯器／runtime 移除
  （服務 2026-03-31 終止），第三條路只剩「自租機器跑 headless ＋ nginx/caddy 反代 wss」

**上游（內部）**：無——本系統是全專案地基。

**下游（11 系統）**：介面契約以 Detailed Design 的「Interactions with Other Systems」
表為唯一真相源。
- **硬依賴**（無本層不能運作）：機台互動組、客人系統、波次導演、遊戲時鐘、評分邏輯、
  攜帶與交付、第一人稱控制器（多人 spawn/roster）、大廳 UI
- **軟依賴**（缺了仍能玩）：HUD 的 ping/connection 顯示、結算畫面的 disconnect_log

對應的下游 GDD 撰寫時必須回列「depends on: 網路同步層＋Session」，保持雙向一致。
**交棒事項**：N=1（Host 獨留）波次密度曲線→波次導演 GDD；更衣室內「該去哪」提示→
game-designer／`/ux-design`；客製 Web Template 視覺→`/ux-design`；Web 平台 ADR
（單執行緒、Addressables 與 `NetworkPrefabsList` 共存）→`/create-architecture`。
**r4 新增交棒**：`shift_length_sec` 的**最終值**（本 GDD 只登錄它的存在與暫定值，
節奏歸屬）→遊戲時鐘＋波次導演 GDD；**Lobby\* 等待期間的單人練習沙盒內容與縮放**
→單人練習模式 GDD（本 GDD 只定三條約束，見 States 表下方）；`end_shift_early` 的
二次確認框文案、冷啟動失敗文案、寬限期結束文案→`/ux-design`；
**session 層 ADR**（MPS 成員寫入者、approval 閘門、心跳 payload 格式）→`/create-architecture`。

## Tuning Knobs

> **r4 全面修訂**：機械檢查（常數↔AC 雙向對照）發現**約束區塊 7 條全部與本表的「安全範圍」
> 欄存在矛盾**，另有 12 項新矛盾與 19 項應登錄未登錄的數值。本表的「安全範圍」欄先前
> 實際上是**註解而非契約**（8 個旋鈕的範圍在 AC 層面不可行使——AC 把預設值寫死了）。
> 以下已修正：範圍欄現為**可實際行使的值域**，與約束區塊、AC 三方一致。

| 旋鈕 | 預設 | 安全範圍 | 調過頭的後果 |
|---|---|---|---|
| 心跳間隔 heartbeat_interval_sec | 2s | 1-5（**不可獨立調**——動它會連帶改變 timeout 的合法集合，見約束①③） | 太低＝白耗頻寬；太高＝逾時判定粗糙 |
| 心跳逾時 heartbeat_timeout_sec | 8s | **`k × heartbeat_interval_sec`，k 為整數 ≥3，且 `> background_disconnect_threshold_sec + heartbeat_interval_sec`，且 ≤30** | 太低＝切分頁回來被誤判斷線；太高＝留守者裸撐更久 |
| 背景視同斷線閾值 background_disconnect_threshold_sec | 5s | **2-5**（r4 修正：原寫 2-10，但 threshold=10 代入公式③得 `rate = 6.0×`，違反本設計自訂的「不瞬移」鐵律，見約束⑪） | 太低＝切個分頁就掉線；太高＝追趕幅度過大造成瞬移 |
| 網路 tick network_tick_rate | 10Hz（**引擎預設是 30**） | 10-30 | ✅ `[P-3]` 已回填：本值＝`NetworkConfig.TickRate`，**同時決定 NetworkTransform 與 NetworkVariable 的送出節奏，但不影響 RPC**。⚠ 設為 10 等於把所有 NetworkVariable 也降到 10Hz（引擎預設 30），需確認對客人狀態同步無害。太低＝橡皮筋感；太高＝WebSocket 佇列堆積 |
| 交接冷卻 ownership_change_cooldown_ticks | 6 ticks | ≥6（引擎下限） | ✅ `[P-20]` 回填新增：NGO 原始碼 `k_MaximumTickOwnershipChangeMultiplier = 6`，低於此值會警告「[Rapid Ownership Change Detected][Potential Loss in State]」且 owner-write 的 NetworkVariable 更新可能遺失。道具快速拋接必須受此限 |
| ⚠ **引擎值：`UnityTransport.HeartbeatTimeoutMS`** | 500ms | **不得調動** | ✅ `[P-9]` 回填新增：NGO 把它**同時**當作 Relay PING 間隔傳下去。調大到 >10s 會破壞 Relay keepalive 而被踢（Relay TTL 10s）。列在此處是為了讓人**不要動它** |
| 插值緩衝 interpolation_buffer_ms | 150ms | 100-300（建議 ≥1.5 × tick 間隔） | 太低＝抖動；太高＝他人位置明顯落後 |
| NPC 事件最小間隔 npc_event_min_interval_sec | 0.2s/隻 | 0.1-0.5 | 太低＝事件洪水；太高＝客人反應遲鈍 |
| NPC 里程碑補位時長 npc_milestone_catchup_sec | **0.2s**（r4 修正：原 0.3s） | ≤ npc_event_min_interval_sec（**約束⑨**） | 原值 0.3 > 間隔 0.2，補位永遠被下一筆事件打斷 |
| 顯示層 catch-up 時長 catchup_duration_sec | 2s | 1-3 | 公式③的分母；太高＝追平拖沓，太低＝倍速過大 |
| 互動 claim lock 逾時 claim_lock_timeout_sec | 5s | 2-10 | 太低＝慢網路誤解鎖；太高＝機台卡死觀感差 |
| 互動往返上限 interact_rtt_p95_ms | 300ms | 200-400（**約束⑧**） | r4 新增本列——它先前只存在於 Interactions 表與 registry，不在本表，卻被三欄表宣稱「Y」 |
| 重連窗口 W reconnect_window_sec（Post-MVP） | 30s | 10-90 | 太低＝Wi-Fi 一閃就丟位；太高＝空 slot 拖累全隊（約束④） |
| 中途加入截止 late_join_cutoff_sec | 30s | **20-60**（r4 修正：原 0-60，但約束⑦要求 ≥ 更衣室上限＋最小有效遊玩＝5＋15） | 太低＝進來就結算沒體驗；太高＝後段無法補人 |
| 最小有效遊玩時間 min_meaningful_play_sec | 15s | 10-30 | r4 新增：「進場後至少還能玩多久才值得進場」，約束⑦的組成 |
| 更衣室過場時長 | 3.0-5.0s（定長情緒節拍） | **區間固定，不可調**（下限 3.0／上限 5.0 同時被約束⑦引用） | 低於 3s 推門節奏斷掉；高於 5s 開始像在等 |
| 離線寬限期 grace_window_sec | 15s | **`heartbeat_timeout_sec` – 30**（r4 修正：原 0-30；下界**隨 timeout 浮動**，不是固定的 8，見約束⑥與⑩） | 太低＝留守者裸撐；太高＝空窗太久失去張力 |
| 寬限期耐心倍率 patience_mult | 1.5× | **1.01-2.0**（r4 修正：原 1.0-2.0，而約束⑥要求嚴格 >1.0） | 太低＝寬限無感；太高＝掉線反而變輕鬆 |
| 結算逾時 settlement_timeout_sec | 20s | 10-60 | 太低＝逐項檢討看不完；太高＝「再開一班」節奏被拖 |
| 班次長度 shift_length_sec | **480s（8 分鐘，暫定）** | 依遊戲時鐘／波次導演 GDD 定案 | r4 新增：`shift_end_ts` 的初值。**最終值不歸本 GDD**（見交棒事項），但它的**存在**必須在此登錄——#9／#21／公式①／AC5／AC13a／AC19／AC35 全部依賴它 |
| 時鐘顯示更新間隔 clock_display_interval_sec | 1s | 0.5-5 | r4 更名（原「時鐘同步間隔」）：**純本地渲染節奏，不產生網路流量**。命名碰撞已解，見同步頻率總表 |
| 時鐘 offset 收斂容差 clock_offset_tolerance_ms | 100ms | 50-500 | r4 新增：心跳估計的 offset 精度目標 |
| Relay 斷線傳播延遲 relay_disconnect_propagation_sec | 2s `[P-8]` | 原型回填 | r4 新增：先前同一機制在全文以 1s／2s／5s／10s **四種數字**現形（AC16／公式①＋P-8／AC6a／AC6b＋AC28），從未具名 |
| 斷線後果處理上限 disconnect_cleanup_sec | 2s | 1-3 | r4 新增：#11／#24 的清理 SLA，自**判定時刻**起算。被 AC10／AC11／AC13a／AC27 引用 |
| UI 回饋上限 ui_feedback_sec | 1s | **`relay_disconnect_propagation_sec`–2**（約束⑮） | r4 新增：被 AC2／AC13a／AC37a 引用 |
| 局終廣播（優雅路徑） session_end_graceful_sec | 5s `[P-13]` | 原型回填 | r4 新增：AC6a |
| 局終廣播（保底路徑） session_end_worstcase_sec | **12s**（r4 修正：原 10s） | 原型回填 | `heartbeat_timeout(8) + heartbeat_interval(2) + 傳播(2) = 12`。原寫 10 的餘裕為 0，加上 AC27 自己的 ±1s 容差即破（9+2=11>10） |
| Lobby 房主靜默逾時 lobby_host_silence_timeout_sec | 30s | 15-45（**上限受支柱 5 的 30 秒紅線約束，不宜超過**） | r4 後新增（arlong 裁決）：Lobby 自最後一次收到任何 session 事件起計時，逾時即顯示店語提示＋可離開按鈕。存在的理由是實測發現 Host 被**強制終止**時服務端要 132.61 秒才廣播——本地逾時是不等服務端的自救 |
| 冷啟動 stall 逾時 load_stall_timeout_sec | 10s | 5-20 | r4 新增（#27）：**位元組數無增長**的容忍秒數，**不是總時長逾時** |
| 進房總預算 join_time_budget_sec | 60s | 鎖定（支柱 4 硬標） | r4 二次修訂：先前三欄表宣稱「已補列」但本表實際沒有這一列（假 Y）。超標即違反支柱 4 的 design test |
| 更衣室過場區間 onboarding_duration_sec | [3.0, 5.0]s | 區間固定，不可調 | r4 二次修訂登錄：**約束⑦直接引用它的上限**，先前該值只存在於「預設」欄。AC4 |
| 樂觀動畫上限 optimistic_anim_max_ms | 100ms | 50-150 | r4 二次修訂登錄：Core Rule #3「client 只做 0-`optimistic_anim_max_ms`（100ms）的樂觀動畫」決定互動手感，先前無常數、無 AC、不在正當留 AC 清單。與 AC4 的「單幀 >100ms」同數字但**不同概念**，易混 |
| 斷線通知停留 disconnect_notice_dwell_sec | 2s | 1-4 | r4 二次修訂登錄：States 表與 UI 表的「≈2s 後回主選單」。與 `disconnect_cleanup_sec` 同值但**不同義**（一個是 UI 停留，一個是 Host 清理 SLA） |
| 狀態收斂上限 state_convergence_sec | 1s | 0.5-2 | r4 二次修訂登錄：AC24（全 client 顯示相同 NPC 狀態）與 AC32（遲加入者的 NetworkVariable 一致）共用，先前只存在於 AC |
| Host 回前景清理 host_return_cleanup_sec | 5s | 3-10 | r4 二次修訂登錄：AC28a（Host 回前景後關閉 session 與釋放 Relay）。與 `session_end_graceful_sec` 同值但**不同起算點** |
| Lobby 背景安全係數 lobby_bg_safety_factor | 0.5 | 0.3-0.8 | r4 二次修訂登錄：#23b 與 AC34b 的「設計上限＝實測服務端逾時 × 本值」。是設計旋鈕，不是導出值 |
| 分段預算 T_load / T_lobby / T_spawn | 25s / 10s / 10s | 各自獨立硬閘門 | r4 新增為獨立常數——AC7a 明令「不得以總和抵銷」，它們不是 60s 的註解 |
| 最大人數 max_players | 4（**MVP 建置＝2**） | **MVP=2、VS 起=4，其餘鎖定**（r4 修正：原標「鎖定」但實際在里程碑間取兩個值，語義矛盾） | 改動需重新平衡波次密度與店內空間（支柱 3） |

**約束區塊（r3 結構前置 #3；r4 擴充至 11 條）**——各旋鈕的安全範圍不可獨立解讀，
須**同時**滿足下列全部；任一不滿足即為非法組態：

| # | 約束 | 說明 |
|---|---|---|
| ① | `heartbeat_timeout_sec = k × heartbeat_interval_sec`，k 為整數且 k ≥ 3 | 逾時必為間隔整數倍；k<3 抖動即誤判。預設 8 = 4×2 ✓ |
| ② | `heartbeat_timeout_sec > background_disconnect_threshold_sec` | 否則背景 ≤閾值回來的人被誤判斷線，公式③ catch-up 分支走不到。預設 8 > 5 ✓ |
| ③ | `background_disconnect_threshold_sec < heartbeat_timeout_sec − heartbeat_interval_sec` | 留至少一拍餘裕給恢復後的首拍。預設 5 < 6 ✓ |
| ④ | **依斷線者身分分兩種情境**（`[P-9]` 已回填，2026-09-13） | ⚠ **原約束的前提不存在**：Relay **沒有**以 allocation 為單位的 idle timeout，而是**每個 client 連線 10s TTL**（host 在 BIND 後尚無 peer 時為 60s），且**任何經過該 client 的訊息都會重置**。<br>**情境 A（斷線的是 client，Host 仍在線）**：Host 的 UTP 每 500ms 自動送 Relay PING，TTL 持續重置 → allocation 存活遠超 `reconnect_window_sec + heartbeat_timeout_sec`（38s），**約束滿足**。<br>**情境 B（斷線的是 Host）**：PING 停送後 **10s** 內回收 → 30s 重連窗口在 Host 掉線時**靠 Relay 撐不住**（MVP 本就無 host migration，屬設計限制，已由 #12 明示） |
| ⑤ | `heartbeat_timeout_sec ≤ UnityTransport.DisconnectTimeoutMS` | ✅ **`[P-9]` 已回填（2026-09-13）：`DisconnectTimeoutMS` 預設 30000ms＝30s ≫ 8s，約束成立**，app 層心跳確實是更早的判定者。欄位名 1.x→2.x **無更名**。⚠ 另有兩個獨立逾時須注意：`ClientConnectionBufferTimeout`＝10s（approval 握手上限，影響 #9 的閘門）、`MaxConnectAttempts × ConnectTimeoutMS`＝60s（建立連線階段總逾時，重連流程應調小） |
| ⑥ | `grace_window_sec > 0 ∧ patience_mult > 1.0`（**嚴格不等式**） | 任一為下限值即等同關閉留守者保護。range 下界已相應上移 |
| ⑦ | **`late_join_cutoff_sec ≥ 更衣室上限 + min_meaningful_play_sec`** | r4 修正：原約束 `≥ 更衣室上限 5s` 是**必要非充分**——取 cutoff=5 時，剩 5.1s 點擊→通過閘門→更衣室 3-5s→進場只剩 0.1~2.1s，仍是「進場即結算」。預設 30 ≥ 5+15=20 ✓ |
| ⑧ | **`RTT + 2 幀 + 處理時間 ≤ interact_rtt_p95_ms`**，且**互動請求／回應一律走 RPC，不得以 NetworkVariable 承載結果**（🔴 **2026-09-16 起本條後半為正確性要求，不再只是效能考量** —— 見下方 `[P-20]`(b)：越權的 owner-write delta 會讓伺服器 `No more variables can be read`，**中止解析整則訊息的其餘部分**，連同物件上其他無關的 NetworkVariable 一起掉） | ✅ **`[P-3]` 已回填（2026-09-13），原約束的前提是錯的**：**RPC 完全不受 network tick 影響**——每**幀**於 `PostLateUpdate` 批次送出（`MessageManager.ProcessSendQueues()` 非 tick-gated），接收端每幀 `EarlyUpdate` 處理。受 tick 影響的是 **NetworkVariable**（每 tick 收集一次）與 **NetworkTransform**。<br>**新預算（60fps、節流 RTT 200ms）**：16.6ms ＋ 100ms ＋ ≤1 幀 ＋ 100ms<br>🟢 **已由實測直接證實（W1 第 4 批，2026-09-15）**：雙進程經 Relay WSS 量 20 樣本往返，**tick 改十倍、RTT 一毫秒未動**——10Hz：median 331.1／p95 335.8ms；1Hz：median 330.7／p95 333.0ms。若 RPC 受 tick 閘門控制，1Hz 下每筆須等最長 1 秒，p95 必落在秒級。**推論與量測一致，本約束的原前提正式作廢。**<br>🔴 **但量測同時暴露一個原設計沒算進去的項**：上表的 RTT 並非「網路成本」的全部，`interact_rtt_p95_ms` 的分母**受 Relay region 選擇支配**，見約束⑮ ＋ 16.6ms ≈ **235-250ms ≤ 300ms，餘裕 50-65ms**。**AC22 在 10Hz 下可達成，先前「必然不可達」的判斷解除。**<br>⚠ **但這條的後半是硬規則**：若改用 NetworkVariable 承載互動結果，10Hz 下單邊即 +100ms → 逼近 350ms 超標。<br>⚠ 最大未知數已轉移到 **server 端 frame rate**（若 server 跑 30fps，單幀成本 +33ms）與 **WebSocket 丟包下的 P95 尾端**，兩者須實機量測 |
| ⑫ | **`1 + background_disconnect_threshold_sec / catchup_duration_sec ≤ 3.5`** | r4 二次修訂新增：公式③的 `rate` 分母 `catchup_duration_sec` **本身也是旋鈕**（範圍 1-3），而約束⑪只鎖了分子。取 threshold=5（合法）∧ catchup=1（合法）→ `rate = 6.0×`，正是 ⑪ 用來否決 threshold=10 的那個數字。預設 `1 + 5/2 = 3.5` ✓（等號） |
| ⑬ | **`session_end_worstcase_sec ≥ heartbeat_timeout_sec + heartbeat_interval_sec + relay_disconnect_propagation_sec`** | r4 二次修訂新增：該關係先前只寫在 AC6b 的括號裡。調動 `heartbeat_timeout_sec`（合法範圍可至 30）會讓 AC6b／AC13b／AC28 寫死的 12 靜默失效。預設 12 ≥ 8+2+2 ✓（等號） |
| ⑭ | **凡「經網路傳播才得知」的事件，其 AC 須拆成兩段計時：`得知時刻`（＝傳播延遲，依 `[P-8]`／`[P-10]`）＋`得知後的 UI 回饋`（≤`ui_feedback_sec`）。兩者不得混為單一上界。** | r4 二次修訂新增（**非數值不等式**）：`ui_feedback_sec`（本地操作到畫面）與 `relay_disconnect_propagation_sec`（網路傳播）量的是**不同區段**，用不等式綁它們是錯的。真正的缺陷是**把端到端上限寫成只含其中一段**——AC37a 原寫「過場 ≤1s 中止」而傳播下界就是 2s，即為此類。已修正的有 AC37a；撰寫新 AC 時一律套用本條 |
| ⑨ | **`npc_milestone_catchup_sec ≤ npc_event_min_interval_sec`** | r4 新增：原值 0.3 > 0.2，補位永遠被下一筆 milestone 打斷，兩常數互斥 |
| ⑮ | **`RTT_i = 2 × (d(i, R) + d(R, H))`；Relay region `R` 必須顯式指定且貼著 Host（見 #28）。同區房間須滿足 `RTT_i ≤ interact_rtt_p95_ms`；跨區房間改由 AC22a 的降級契約承接** | 🔴 **W1 第 4 批實測後新增，全表唯一「不寫程式就會違反」的約束**。量測（20 樣本／組、Relay WSS、雙進程同置於台灣，故 `RTT = 4 × d(台灣, R)`）：<br>｜region｜median｜p95｜反推單程｜<br>｜`asia-northeast1`｜88.8｜**94.5**｜22.2ms｜<br>｜預設（美國中部）｜331.1｜**335.8**｜82.8ms｜<br>｜`europe-west4`｜434.3｜**437.8**｜108.6ms｜<br>三點皆吻合線性模型 → **模型可用來推未量測的組合**。<br>**預設值下 p95 335.8ms > `interact_rtt_p95_ms`(300ms)，即遊戲邏輯一行都還沒跑，AC22 就已經失敗。** 之所以不能留空靠引擎自選：Relay 的 QoS（自動挑最近 region）在 Web 上拋 `PlatformNotSupportedException: QoS SDK does not support WebGL`，而本作 Web-only。<br>**跨洲房間的推算（arlong 裁決「讓國外的人也可以參與」後的核心數字）**：歐洲玩家加入台灣 Host 的房、`R = asia-northeast1` 時，`RTT = 2 × (d(歐,東京) + 22.2)`。`d(歐,東京)` 無法自本地量得，但由已測兩值夾擠：`108.6 − 22.2 ≤ d(歐,東京) ≤ 108.6 + 22.2`（下界取差的絕對值） → **`RTT ∈ [217, 306] ms`**。→ **跨洲可玩，但正好壓在 300ms 邊緣，不是有餘裕地達標**。故 AC22 拆為同區（必達）與跨區（降級契約）兩條，見 AC22／AC22a。<br>⚠ 上述皆為**裸傳輸往返**，未含 server frame rate、節流與遊戲處理時間。<br>⚠ **region 的固定範圍是「一個班次」而非「整局」**：它傳給 `StartRelayNetworkAsync`，而依 #23 那是「開始上班」才呼叫、依 #23a 局間會 `StopNetworkAsync` 拆掉。故**理論上每個班次可重選 region**——若日後啟用 host migration（OQ#18），region 得以跟著新 Host 走。⚠ **此為由 API 形狀推得的推論，尚未實測**（未驗證 stop→start 是否真能換到不同 region），列為 W1 結案後的待驗項。<br>可用 region（實機列舉）：`asia-southeast1`、`asia-northeast1`、`asia-south1`、`us-central1`、`us-east1`、`us-west1`、`europe-north1`、`europe-west4`、`europe-central2`、`australia-southeast1`、`southamerica-east1`。**無台灣／香港節點**，東亞最近為東京。 |
| ⑩ | **`grace_window_sec ≥ heartbeat_timeout_sec`** | r4 新增：拔線後 Host 要 6-8s 才判定，留守者在判定前**完全沒有保護**。若 grace < timeout，裸撐窗口會佔滿甚至超過整個寬限期，支柱 5 對留守者失效。預設 15 ≥ 8 ✓（裸撐仍佔 53%，屬已知接受，以 `[P-13]` 的優雅路徑縮短） |
| ⑪ | **`background_disconnect_threshold_sec ≤ 5`**（由公式③反推） | `rate = 1 + T_bg / catchup_duration_sec`，threshold=10 → 6.0×，違反「不瞬移」鐵律 |

交互作用：`network_tick_rate` × `npc_event_min_interval_sec` 共同決定頻寬峰值——調高任一時
先跑原型量測 Open Questions #2（尖峰佇列是否收斂）與 #12（send queue 溢位）再定案。

**常數三欄對照表（r3 結構前置 #2；r4 改為雙向核對）**

> **r4 判準升級**：不只檢查「常數出現在三處」，而是檢查**「被引用的那條 AC 真的斷言了
> 這個數字」**。r3 版有 4 個假引用與 2 個欄位造假，因為表格的存在製造了覆蓋的假象。

| 常數 | Tuning Knobs | registry | AC（須真正斷言該數值） |
|---|---|---|---|
| heartbeat_interval_sec = 2 | Y | Y | **AC44（r4 新增）**——原標 AC27 為**假引用**：AC27 只斷言 8s 逾時與 2s 後處理，46 條 AC 無一驗證心跳頻率 |
| heartbeat_timeout_sec = 8 | Y | Y | AC27, AC6b |
| background_disconnect_threshold_sec = 5 | Y | Y | AC15, AC16, AC29 |
| network_tick_rate = 10Hz | Y | Y（registry 已登錄） `[P-3]` | **AC46（r4 新增）**——原標 AC23 為假引用：AC23 測插值平滑度，與 tick rate 無關 |
| interpolation_buffer_ms = 150 | Y | Y | AC23（**條件引用**：150ms 在 GIVEN，判準是移動速度上限；AC23 `blocked-by` 第一人稱控制器 GDD） |
| npc_event_min_interval_sec = 0.2 | Y | Y（registry 已登錄） | AC25 |
| npc_milestone_catchup_sec = 0.2 | Y | Y（registry 已登錄） | AC15, AC24 |
| catchup_duration_sec = 2 | Y | Y（registry 已登錄） | AC15, AC29 |
| claim_lock_timeout_sec = 5 | Y | Y | AC21, AC38 |
| interact_rtt_p95_ms = 300 | **Y（r4 補列）** | Y | AC22 |
| reconnect_window_sec = 30 | Y | Y | AC17, AC18 |
| late_join_cutoff_sec = 30 | Y | Y | AC5, AC35 |
| min_meaningful_play_sec = 15 | Y | Y（registry 已登錄） | AC35 |
| grace_window_sec = 15 | Y | Y | AC12, AC31, AC36 |
| patience_mult = 1.5 | Y | Y | AC12, AC31 |
| settlement_timeout_sec = 20 | Y | Y | AC39 |
| max_players = 4（MVP 2） | Y | Y | AC8 |
| shift_length_sec = 480（暫定） | Y | Y（registry 已登錄） | **AC47（r4 新增）** |
| clock_display_interval_sec = 1 | Y | Y | **AC45a（r4 二次修訂）**——AC45 驗的是 offset 精度，不驗顯示節奏；已另立 AC45a 專驗本常數 |
| clock_offset_tolerance_ms = 100 | Y | Y（registry 已登錄） | **AC45（r4 新增）** |
| relay_disconnect_propagation_sec = 2 `[P-8]` | **Y（r4 新列）** | Y（registry 已登錄） | AC6a, AC16, AC28 |
| disconnect_cleanup_sec = 2 | **Y（r4 新列）** | Y（registry 已登錄） | AC10, AC11, AC13a, AC27 |
| ui_feedback_sec = 1 | **Y（r4 新列）** | Y | AC2, AC13a, **AC37a**（r4 二次修訂：AC37 無任何時間上界，真正引用者是 AC37a） |
| session_end_graceful_sec = 5 | **Y（r4 新列）** | Y（registry 已登錄） | AC6a |
| session_end_worstcase_sec = 12 | **Y（r4 新列）** | Y（registry 已登錄） | AC6b, AC13b, AC28 |
| load_stall_timeout_sec = 10 | **Y（r4 新列）** | Y（registry 已登錄） | **AC48（r4 新增）** |
| T_load / T_lobby / T_spawn = 25/10/10 | **Y（r4 新列）** | Y（registry 已登錄） | AC7a |
| join_time_budget_sec = 60 | **Y（r4 補列，原填「#13」即自承缺一處）** | Y | AC7 |
| 更衣室 3.0-5.0s | Y | 無（區間非單值） | AC4 |
| onboarding_duration_sec = [3.0, 5.0] | Y | Y（區間） | AC4 |
| optimistic_anim_max_ms = 100 | Y | Y | ⚠ **零 AC 覆蓋**（r4 二次修訂標記，待補一條驗互動手感的 AC） |
| disconnect_notice_dwell_sec = 2 | Y | Y | ⚠ **零 AC 覆蓋**（r4 二次修訂標記，屬 UI 停留時長，可由 /ux-review 涵蓋） |
| state_convergence_sec = 1 | Y | Y | AC24, AC32 |
| host_return_cleanup_sec = 5 | Y | Y | AC28a |
| lobby_bg_safety_factor = 0.5 | Y | Y | AC34b |
| player_count_sampling（規則非數值） | 無（規則） | Y | AC12, AC31（**註：「加入走波次邊界取樣」這一半零 AC 覆蓋**，r4 二次修訂標記） |
| build_size ≤50MB、標準網路 20Mbps | 跨文件（technical-preferences.md） | **應以 `referenced_by` 指回本 GDD** | AC7, AC7a 的成立條件 |

**AC 中正當留在 AC 的數字**（測試方法學／導出值／邊界取樣，不需登錄為常數）：
±1s／±0.5s 容差、5.0s vs 5.1s 與 30.5s vs 29.5s 與 5.000s vs 5.001s 等邊界取樣、
2.5×／3.5× 等由公式導出的倍速、5 次取樣 P95、20 次取樣、120s 背景取樣點、
節流網路的 5Mbps／200ms／1%、AC4 的單幀 >100ms 與 AC15 的單幀 ≤1m（判準非旋鈕）。

## Visual/Audio Requirements

（基礎設施系統——僅一條）連線事件的音訊呈現走世界語言：隊友加入＝門鈴「叮咚」＋
「歡迎光臨」（與客人進門同源但音高區別）；無任何「連線成功」系統音。

## UI Requirements

本系統不擁有畫面（大廳 UI、HUD 是獨立系統），但**擁有連線狀態的語言**——下游 UI
必須使用此翻譯表，禁止出現技術詞彙。**層級欄**：MVP 列為 MVP 建置實際呈現；Post 列
待 Post-MVP 功能存在時才啟用，MVP 期不得實作。

| 技術狀態 | 玩家看到的店語 | 層級 |
|---|---|---|
| Connecting / Creating session | 「排班表準備中…」 | MVP |
| Creating session 失敗 | 「排班表印壞了，再試一次」＋重試鈕 | MVP |
| Joining | 「打卡中…」 | MVP |
| 加入成功 | 門鈴叮咚＋隊友身影進門（無文字） | MVP |
| 已過加入截止（剩 ≤30s／Settlement 中） | 「這班快下班了，你排下一班」→下一局 Lobby | MVP |
| 自己斷線（MVP 無 slot 保留） | 「這班你先下班了——點連結再回來上工」（無倒數，`disconnect_notice_dwell_sec`＝2s 後回主選單） | MVP |
| 自己斷線（Post-MVP 重連窗口） | 「去後場拿貨…」＋倒數 | Post |
| 收不到 Host 心跳且無法排歧（#18） | 「跟店裡斷線了，點連結重新上工」（不預設因果） | MVP |
| 隊友斷線（MVP） | 名牌變灰＋「（名字）下班了」＋**後場門音效**（不在視野內也聽得到） | MVP |
| 隊友斷線（Post-MVP 保留中） | 名牌變灰＋「（名字）去後場了」 | Post |
| 寬限期（老闆擋一下） | 「老闆出來擋一下」＋客人排隊變短的可見變化 | MVP |
| 隊友重連（MVP＝以新人身分中途加入） | **無專屬文案**——走正常「叮咚＋歡迎光臨」新人進門 | MVP |
| 隊友重連（Post-MVP 原位恢復） | 「你回來了，剛剛老闆幫你頂著」（**與實際機制一致**——是系統降載，不是隊友代勞） | Post |
| Host 獨留續戰 | 無專屬文案（店照常轉）；大廳 UI 提供「提前收班」按鈕 | MVP |
| UGS 服務失敗 | 「總公司系統維修中」＋重試鈕（禁顯技術錯誤碼） | MVP |
| 房間滿員 | 「這班人滿了」（與碼失效訊息區分） | MVP |
| 房間碼錯誤/失效 | 「這班沒這個人喔，再確認一次工號——或跟朋友要一個新連結」 | MVP |
| Host 離開＝局結束（排歧判定 Host 消失） | 「店長把鐵門拉下來了」 | MVP |
| Host 主動關頁前的攔阻（`beforeunload`，best-effort） | 瀏覽器原生確認框；文案歸 /ux-design | MVP |
| Lobby 給房主的提示 | 積極引導文案（取代「店長顧著店別亂跑」；實際文案歸 /ux-design）＋「複製邀請連結」按鈕 | MVP |
| 冷啟動載入（客製 Web Template） | 世界語言等待畫面（例：鐵門緩緩升起），禁百分比與技術術語；視覺歸 /ux-design | MVP |
| **冷啟動 stall／載入失敗**（#27，LoadFailed） | 「鐵門卡住了，重新整理看看」＋重試鈕；**禁技術錯誤碼** | MVP |
| **寬限期結束**（#15 補） | 店語明示保護結束（例：「老闆回辦公室了」）——靜靜結束會讓留守者不知道保護何時消失 | MVP |
| **第 2 次起離線（#15a 抑制生效）** | **無專屬文案**——名牌變灰與降載照常，只是不再出現「老闆出來擋一下」。不對玩家解釋抑制規則 | MVP |
| **等待下一班（Lobby\*）** | 「這班還在忙，08:00 交接」＋剩餘時間＋在場隊友人數＋**可進單人練習沙盒暖身**；**不得看起來像空房** | MVP |
| **`end_shift_early` 二次確認（`online_player_count` > 1）** | 站內確認框：「還有人在店裡，要拉鐵門嗎？」；Host 獨留時**不出現**，直接進 Settlement | MVP |
| **「開始上班」轉場**（#26） | 世界語言遮蔽（打卡鐘／鐵門升起／日光燈逐盞亮起）；**禁進度條與「連線中」**；視覺歸 /ux-design | MVP |
| **Lobby 期間 Host 離開**（#25，MPS 事件偵測） | 「店長把鐵門拉下來了」（與 InShift 同文案，玩家不需要知道偵測機制不同） | MVP |
| **build 版本不符**（#9 的版本閘） | 「這是舊的班表，重新整理一下」 | MVP |

🔴 **W1 第 2 批發現：Unity Web build 的預設字型不含 CJK——整張翻譯表在網頁上會是空白**

實測 Release Web build 的探針畫面：**所有中文字元完全沒有渲染**，只有英數與符號顯示得出來
（Unity 內建 GUI skin 的預設字型無 CJK glyph）。

這對本系統是**支柱級的問題**，因為上表的核心主張正是「所有網路狀態一律翻譯成店語，
技術詞彙一個都不准出現在玩家眼前」——**而店語全是中文**。字型缺失等於整條原則在
目標平台上失效。

- **必做**：**打包一套含 CJK 的字型**（思源黑體／Noto Sans TC 等）並設為專案預設，
  不得依賴系統或引擎內建字型。
- **成本要進預算**：CJK 字型即使子集化也有明顯體積，而公式⑤ 的 `T_load` 餘裕**已經是 0**，
  地板又實測為 7.0 MB。**字型子集化（只打包實際用到的字）應列為 MVP 的建置步驟**，
  不是 polish 階段的優化。
- **交棒**：字型選型、子集化流程與授權 → `/ux-design` ＋ web-platform ADR。
- 註：這與先前 Godot 專案遇到的是同一類問題（該引擎是 `ThemeDB.fallback_font` 無 CJK），
  **換引擎並沒有換掉這個坑**。

📌 **UX Flag — 網路同步層＋Session**：本系統有 UI 語言需求。Pre-Production Phase 4
時，大廳與連線狀態畫面（含冷啟動 Web Template、beforeunload 文案、Lobby 房主引導）
須先跑 `/ux-design`，stories 引用 `design/ux/[screen].md`。

## Acceptance Criteria

每條可由 QA 不讀 GDD 獨立執行。**層級**欄（r4 二次修訂，新增必達／可降級之分）：
- **MVP-必達**＝核心假設驗證必備，**且不接受任何 fallback 把它降級或撤銷**。
  依 r4 判準，**任何會殺掉本級 AC 的 fallback，其 fallback 本身即為 blocking**。
  目前列為 MVP-必達者：**AC6b**（Host 以任何路徑離開的保底局終）、**AC53**（MPS 名額釋放，
  否則 2 人房永久軟鎖死）、**AC54**（版本閘，否則靜默 desync）、**AC7**（支柱 4 的硬標）。
- **MVP**＝核心假設驗證必備，但原型證實不可行時**允許依 fallback 降級並記錄**。
- **Post**＝Post-MVP；**VS**＝Vertical Slice（需 3 人以上）。
- `[P]`＝provisional，待原型回填引擎事實後才進 QA 計畫。
> **為什麼要分這一級**：r4 的判準主詞是「MVP-必達 AC」，但先前層級欄只有 MVP／Post／VS
> 三種值，**判準的主詞本身沒有定義**，於是「P-13 把 AC6a 降為 Nice-to-have」「P-10 替代
> 設計放棄 AC34b 的 120s」算不算殺掉必達 AC，只能靠判斷。沒有這一級，判準無法機械執行。

**測試基準環境**（所有 AC 適用）：Chrome 穩定版；標準網路＝下行 20Mbps／RTT 40ms／
丟包 0%；「節流網路」＝下行 5Mbps／RTT 200ms／丟包 1%（DevTools 或 tc netem）。
**節流一律只套用於受測 client 單側，Host 走標準網路**（r4 明訂）——雙側節流下
Relay 中繼的純網路成本 ≥400ms，AC22 的 300ms 在數學上不可能達標。

**r4 新增的 AC 撰寫規則**（避免第五輪再撞同一類問題）：
1. **凡涉及班次剩餘時間的 GIVEN，必須寫明「Host 端計算之」**——client 的 wall-clock
   偏差可達數分鐘，0.5s 級鑑別在 client 側不可信
2. **凡涉及分頁背景化的 GIVEN，必須寫明「是誰的分頁」**（受測 client 自身／Host／第三人）
3. **凡有時間上界的 AC，該上界必須引用具名常數**，不得寫死數字——數字寫死會讓
   Tuning Knobs 的安全範圍變成不可行使的死字（r3 有 8 個旋鈕是這樣死的）
4. **判定區間 ≠ 容差區間**：心跳類判定必落在 `[timeout − interval, timeout]`，
   寫「±容差」會讓約一半的取樣無故 fail（AC27 的教訓）
5. **凡依賴 [P] 的 AC 必須標該 [P] 編號**，且該 [P] 的「影響」欄要反向列出本 AC

**Session 生命週期**

| # | 準則 | 層級 |
|---|---|---|
| 1 | GIVEN 大廳按建立房間，WHEN 建立成功，THEN 收到 room_code，且產生的分享連結貼到另一瀏覽器分頁開啟後免輸碼直接顯示大廳 | MVP |
| 2 | GIVEN 有效 room_code，WHEN 於標準網路手動輸入送出（**含全小寫**；r4 後移除「0/O 互換」子項——`[P-1]` 實測字集不含易混淆字元，該測試無意義），THEN ≤1s 加入 roster（**此路徑不得依賴 URL 轉發**） | MVP |
| 3 | GIVEN 部署於 itch.io 的正式頁面（iframe 環境），WHEN 開啟帶碼連結，THEN 免輸碼進大廳；若平台不轉發 query，THEN 自動 fallback 至輸碼畫面且顯示「請輸入工號」 | MVP `[P-4]` |
| 4 | GIVEN 遊戲進行中且班次剩餘 >30s，WHEN 新玩家加入，THEN 更衣室過場時長 ∈[3.0s, 5.0s]（含端點，逾時視為 fail）；期間既有玩家**本機** frame time 無單幀 >100ms、既有玩家螢幕上**其他角色**位置無單幀 >1m 跳變、輸入未被鎖 | MVP |
| 5 | GIVEN **Host 端計算之**班次剩餘 ≤`late_join_cutoff_sec`（30s）或已在 Settlement，WHEN 新玩家點連結，THEN **approval 閘門拒絕**並導向 **Lobby\***，顯示「這班快下班了，你排下一班」，不進入當前班次 | MVP |
| 6a | GIVEN Host 分頁**優雅關閉**（`socket.close()` 或確認 close frame 已送出），WHEN 偵測斷線，THEN session ≤`session_end_graceful_sec`（5s）內結束，全員收到「店長把鐵門拉下來了」回主選單（best-effort 快速路徑）。**狀態限定：InShift** | MVP `[P-13]` |
| 6b | GIVEN Host 於 **InShift** 以**任何路徑**離開（含真實點 X 關分頁、bfcache、行程強制終止），WHEN client 心跳逾時，THEN 全員 ≤`session_end_worstcase_sec`（**12s**＝逾時 8＋間隔 2＋傳播 2）內收到「店長把鐵門拉下來了」回主選單（保底路徑，必達）。**r4 修正**：原寫 ≤10s，餘裕為 0，加上 AC27 自己的 ±1s 容差即破（9+2=11>10） | **MVP-必達** `[P-10]` `[P-14]` |
| 6c | GIVEN Host 於 **Lobby 或 Lobby\*** 離開（關頁／導頁／斷線），WHEN client 訂閱的 session 成員事件到達，THEN 顯示「店長把鐵門拉下來了」回主選單。✅ **實測：優雅離開路徑 ≤2s**（實測 1.14s，訊號 `session.Deleted`）。🔴 **強制終止路徑實測 132.61s**——該路徑的呈現方式待 OQ#19 裁決，本 AC 只驗優雅路徑。不得套用 AC6b 的 12s（那是 InShift 心跳路徑） | MVP |
| 7 | GIVEN 全新玩家於**標準網路**點分享連結（冷啟動、清空快取），WHEN 開始計時，THEN 至「角色能響應移動輸入」≤`join_time_budget_sec`（60s），**5 次取樣 P95**。**量測邊界**：與 AC7a 同——**不含 Host 按「開始上班」前的人為等待**（那不是系統延遲；否則 Host 泡杯咖啡即 fail，pass/fail 不由系統決定） | **MVP-必達** |
| 7a | GIVEN 同 AC7 條件，WHEN 分段計時，THEN T_load ≤25s、T_lobby ≤10s、T_spawn ≤10s **各自單獨成立**（5 次取樣 P95），不得以總和抵銷。**T_lobby 的計時邊界定義**：自大廳畫面可互動起，至玩家按下 Ready 為止，**不含 Host 按「開始上班」前的人為等待**（那不是系統延遲） | MVP |
| 7b | GIVEN N 位玩家皆已在 Lobby 且 Ready，WHEN Host 按「開始上班」，THEN 至**全員可操作** ≤`T_spawn`（10s，5 次取樣 P95），且期間畫面為 #26 的世界語言轉場、**無進度條、無「連線中」字樣**。**第二班起（Settlement→Lobby→開始上班，含 #23a 的 Relay／NGO 重建）同樣成立** | MVP `[P-10]` |
| 8 | GIVEN 房間已達 `max_players`（**MVP 建置＝2 人，VS 起＝4 人**），WHEN 再一人嘗試加入，THEN 顯示「這班人滿了」（與碼失效訊息不同）且不進入房間 | MVP（2 人）／VS（4 人） |
| 9 | GIVEN UGS 初始化或匿名登入失敗（阻擋 UGS 網域模擬），WHEN 玩家開啟遊戲，THEN 顯示「總公司系統維修中」＋可用的重試鈕，且畫面無任何技術錯誤碼 | MVP |

**斷線與留守者保護**

| # | 準則 | 層級 |
|---|---|---|
| 10 | GIVEN 玩家攜帶物品，WHEN 斷線，THEN 物品於 **Host 判定時刻起** ≤`disconnect_cleanup_sec`（2s）掉落於**物理斷線當下座標**（非判定時座標、非重連時座標），且可被隊友撿起 | MVP |
| 11 | GIVEN 玩家在機台互動中，WHEN 斷線，THEN 該站台於 **Host 判定時刻起** ≤`disconnect_cleanup_sec`（2s）內解鎖、進度歸零、`ClaimGeneration` +1，其他玩家可立即使用 | MVP |
| 12 | GIVEN 2 人房波次進行中且該玩家為本班次**首次**離線（否則適用 #15a），WHEN 一人斷線，THEN 自 **Host 判定時刻**起 `online_player_count` 立即變為 1、當前波次剩餘客人生成量降載，且 `grace_window_sec`（15s）內不生成新客人、場上客人耐心 ×`patience_mult`（1.5）。**判定前的 ≤`relay_disconnect_propagation_sec` 窗口內照常生成，屬已知接受**（Host 尚未知道有人離線） | MVP |
| 13a | GIVEN 2 人房 InShift，WHEN 非 Host 玩家離線、僅剩 Host 在線，THEN session **不結束**，自 **Host 判定時刻**起 ≤`disconnect_cleanup_sec`（2s）內完成 N=1 降載並進入寬限期，班次照常至 08:00；大廳 UI 出現「提前收班」按鈕，按下後 ≤1s 進入 Settlement | MVP |
| 13b | GIVEN 房內僅剩 Host 在線，WHEN Host 亦離線（關頁／背景 >5s／心跳逾時），THEN **玩家可見的局終** ≤`session_end_worstcase_sec`（12s）內完成：所有仍在線的 client 回主選單並顯示「店長把鐵門拉下來了」 | MVP |
| 13c | GIVEN 同 13b，WHEN Host 已消失，THEN **服務端的 Relay 連線於 ≤10s 內回收**（✅ `[P-9]` 已回填 2026-09-13：Relay 對每個 client 連線的 TTL 為 10s，Host 停止送 PING 後即計時）。**r4 修正**：原 13b 要求「≤10s 釋放 Relay」，但 `[P-9]` 自己假設 Relay idle timeout ≥30s，且 Host 已消失時**沒有任何 actor 能執行釋放**——兩個數字方向相反且無可執行路徑。這是 MVP 無 host migration 的**設計限制，不是 bug**，AC 須誠實反映 | MVP `[P-9]` |
| 14 | GIVEN 兩玩家正在交接物品，WHEN 交接完成前（Host 尚未提交 transfer）一方斷線，THEN 物品歸屬留在原持有人並依 #10 掉落；WHEN 交接完成後新持有人斷線，THEN 依新持有人最後位置掉落。兩情境皆不消失也不複製 | MVP |
| 15 | GIVEN **受測 client 自身**分頁背景 3s（<5s 閾值），WHEN 回到前景，THEN 走顯示層 catch-up：**時鐘顯示**於 `catchup_duration_sec`（2s）內追平（倍速 2.5×）且模擬（NPC 數量、波次進度）與背景前連續、無補跑；**其他玩家角色**單幀位移 ≤ 移動速度上限×dt；**NPC** 依 `npc_milestone_catchup_sec`（**0.2s**，r4 修正）補位規則單幀位移 ≤1m | MVP |
| 16 | GIVEN **受測 client 自身**分頁背景 8s（>5s 閾值），WHEN 回到前景，THEN 該 client 依 **#17a** 主動 teardown（Host 於 ≤`relay_disconnect_propagation_sec`（2s）內收到 disconnect），並顯示「這班你先下班了——點連結再回來上工」（非 catch-up）。**r4 修正**：原寫「Host ≤1s」比 `[P-8]` 自承的傳播 ≤2s 還嚴，且未標 [P]——Relay 架構下 client 與 Host 之間沒有直接 socket | MVP `[P-8]` `[P-15]` |
| 17 | GIVEN 斷線 29s（窗口內），WHEN 重連，THEN 恢復原 slot：位置、朝向、名牌一致（手持物品除外——已掉落） | Post `[P-2]` |
| 18 | GIVEN 斷線 31s（逾窗口），WHEN 嘗試重連，THEN slot 已釋放，以新玩家流程加入。邊界歸屬：`t ≤ W` 視為窗口內 | Post `[P-2]` |
| 19 | GIVEN 班次結束時有玩家在重連窗口內，WHEN 結算觸發，THEN slot 隨結算釋放，班次不延長 | Post `[P-2]` |

**同步正確性**

| # | 準則 | 層級 |
|---|---|---|
| 20 | GIVEN 兩玩家同幀對同一機台 claim（腳本驅動），WHEN 同時到達，THEN 僅一方成功，另一方收到明確拒絕事件並播撲空動畫（非靜默失敗） | MVP |
| 21 | GIVEN 玩家 claim 後 Host 未回應，WHEN 達 claim lock 逾時 5s，THEN 站台強制解鎖；逾時後才抵達的原請求被拒（`ClaimGeneration` 不符），不得覆蓋新持有者 | MVP |
| 22 | GIVEN **節流只套用於受測 client 單側**（Host 走標準網路；雙側節流下純網路成本 ≥400ms，數學上不可能達標），**且房內所有人與 Host 同大區**（依 #28，relay 貼著 Host），WHEN 玩家對機台送出 claim，THEN 按下→收到成功/撲空結果的往返 P95 ≤`interact_rtt_p95_ms`（300ms，20 次取樣）；超過即顯示等待狀態，不卡死無回饋。✅ **`[P-3]` 已回填（2026-09-13）：本條可達成，先前的「不可達」判斷解除。** RPC 不受 network tick 影響（每幀 `PostLateUpdate` 送出），預算約 235-250ms，餘裕 50-65ms。**但 GIVEN 須追加硬前提：互動請求與結果一律走 RPC，不得以 NetworkVariable 承載**——後者受 tick 批次，10Hz 下單邊 +100ms 即超標。🟢 **W1 第 4 批已實測（2026-09-15）**：雙進程經 Relay WSS、20 樣本，tick 10Hz 與 1Hz 的往返**完全一致**（p95 335.8 vs 333.0ms）→ 不受 tick 閘門控制的推論成立。<br>🔴 **但 GIVEN 必須再追加一條，否則本條在預設設定下必定失敗**：**Relay region 須顯式指定為玩家所在大區**。同一組量測中，預設 region 的 p95 = **335.8ms（已超標）**，指定 `asia-northeast1` 後為 **94.5ms**，餘裕從負值變成約 205ms。區別純粹來自 region，與 tick、與遊戲邏輯無關（見約束⑮、OQ#20）。<br>⚠ 上述為**裸傳輸往返**，尚未含 server 端 frame rate、節流、與遊戲處理時間；餘裕的最大未知數仍是 WebSocket 丟包下的 P95 尾端 🟢 **同區已實測達標**：`asia-northeast1` 下裸傳輸往返 p95 = 94.5ms，餘裕約 205ms 供 server frame rate、節流與遊戲處理使用。 | MVP |
| 22a | GIVEN 房內存在**與 Host 不同大區**的玩家（arlong 2026-09-15 裁決「讓國外的人也可以參與」後新增），WHEN 該玩家送出 claim，THEN (1) 互動**仍必須得出正確且最終一致的結果**，不得因逾時而卡死或落入錯誤狀態；(2) 按下後 ≤`ui_feedback_sec` 內必須出現**本地的「處理中」回饋**，不得靜默等待網路；(3) **不得給出會被推翻的樂觀結果**——`claim` 的成功／撲空只能由 Host 宣告（此為 #2 權威模型的直接後果，跨區只是讓它更容易被看見）。<br>**本條不設 300ms 上限，因為那是光速問題不是實作問題**：依約束⑮ 的模型，歐洲玩家在台灣 Host 房中的裸往返落在 **217–306ms**，再加 server frame rate 與遊戲處理必定超過 `interact_rtt_p95_ms`。把跨區也綁 300ms 等於寫一條**注定失敗且無法靠實作補救**的 AC。<br>改以**降級契約**承接：慢，但正確、有回饋、不卡死。<br>⚠ 量測邊界：217–306ms 是由兩組實測值夾擠推得，**非直接量測**（本地兩個進程都在台灣，量不到歐洲↔東京）。真實跨洲數字須待有海外測試者時補量，列入 W1 結案後的待辦。 | MVP |
| 22b | GIVEN Host 建立房間，WHEN 建立 Relay allocation 前，THEN 依 `relay_region_by_timezone` 查得 region 並顯式傳入（查不到則用 `relay_region_offset_fallback`），**且建房介面提供覆寫**；WHEN 玩家覆寫，THEN 以覆寫值建立。<br>驗證方式：以偽造時區（`.jslib` 可注入）逐一覆蓋表中每個 region 值，斷言傳入 `RelayNetworkOptions` 的 region 與查表結果一致；另斷言未知時區會落到 offset fallback 而非拋例外或留空。<br>**留空即為缺陷**：留空會落到預設 region，實測 p95 335.8ms，直接違反 AC22。 | MVP |
| 23 | GIVEN **節流只套用於受測 client 單側**，WHEN 觀察其他 client 的角色 60s，THEN 插值（緩衝 `interpolation_buffer_ms`＝150ms）後單幀位移超過**第一人稱控制器 GDD 所定義之移動速度上限**的次數＝0。**⚠ 該常數目前不存在**（第一人稱控制器 GDD 未撰寫）——本條在該 GDD 定案前**無法執行**，列為 `blocked-by: 第一人稱控制器 GDD` | MVP |
| 24 | GIVEN NPC 以里程碑事件同步，WHEN 任一里程碑觸發，THEN 全 client（含中途加入者）於 `state_convergence_sec`（1s）內顯示相同 NPC 狀態；Host 凍結後恢復時只套用最新一筆並於 `npc_milestone_catchup_sec`（**0.2s**，r4 修正）內補位，不瞬跳。**r4 修正理由**：原值 0.3s > `npc_event_min_interval_sec`（0.2s），補位永遠被下一筆 milestone 打斷，兩常數互斥（約束⑨） | MVP `[P-12]` |
| 25 | GIVEN 同一 NPC 連續狀態變化，WHEN 事件送出，THEN 同一 NPC 兩事件間隔 ≥0.2s（log 驗證） | MVP |
| 26 | GIVEN 以腳本刻意延後送出先發 RPC 製造亂序，WHEN client 收到**同一物件** sequence 落後的封包，THEN 封包被丟棄不覆蓋狀態（丟棄計數 log >0）；不同物件的序號互不比較 | MVP `[P-5]` |

**複審新增（2026-09-05 r2）**

| # | 準則 | 層級 |
|---|---|---|
| 27 | GIVEN InShift 中玩家**拔線**（socket 層中斷、無 close frame），WHEN 停止心跳，THEN Host 的判定時刻落在 **[6.0s, 8.0s] 區間內**（含端點），隨後 #24 的 `disconnect_cleanup_sec`（2s）自**判定時刻**起算。**r4 修正理由**：原寫「8s（±1s）」＝[7,9]，但心跳每 2s 一拍，實際判定必落在 [6,8]——約一半的取樣會落在 [6,7) 而被判 fail。判定區間是量化區間，不是容差區間 | MVP |
| 28 | GIVEN Host 分頁背景化 >5s（CDP 模擬，不關分頁），WHEN client 心跳逾時且 **#18 排歧表判定 Host 消失**（client 自身全程前景、`navigator.onLine` true、**MPS session 層可達**），THEN 全員 ≤`session_end_worstcase_sec`（12s）內收到「店長把鐵門拉下來了」回主選單。**r4 修正**：各 client **獨立**以自身心跳空窗判定，**偵測本身不需要傳播**（上限 `heartbeat_timeout_sec`＝8s）；但判定後還要走 #18 排歧（序 1 事件或序 3 roster 輪詢，皆為 `[P-10]` 待回填量）與 UI 呈現（`ui_feedback_sec`）——**r4 二次修訂**：上一版把上限壓到 8s，等於把排歧與 UI 的餘裕一起刪掉，使本條恆不可達 | MVP `[P-10]` |
| 28a | GIVEN 同 AC28，WHEN **Host 回到前景**，THEN 自回前景時刻起 ≤`host_return_cleanup_sec`（5s）內完成 session 關閉與 Relay 配置釋放。**r4 拆出理由**：原 AC28 把此子項寫成「Host 回前景後已釋放」，其時刻＝Host 回前景時刻，**無時間上界**（可能數小時），QA 無法判 pass/fail。起算點必須是回前景，不是背景化 | MVP |
| 29 | GIVEN 分頁背景 **5.0s**（閾值邊界，含端點），WHEN 回到前景，THEN 走 catch-up 而非斷線：時鐘**顯示**於 2s 內推進 7 秒（3.5×），且 #15 的三項位移判準成立；GIVEN 背景 **5.1s**，THEN 走斷線流程 | MVP |
| 30 | GIVEN 玩家於 Lobby 斷線（socket close），WHEN 重新連線，THEN 以全新加入流程進房，roster 無其舊 slot、無 Disconnected 狀態、留守者降載未觸發 | MVP |
| 31 | GIVEN 3 人房，**以優雅 WS close 模擬**（`t_disconnect = 0` 基準，見測試基建），A 於 t=0 離線、B 於 t=10 離線，且**兩人皆為該班次首次離線**（否則適用 #15a），WHEN 觀察波次導演，THEN 寬限期於 **t = 10 + `relay_disconnect_propagation_sec` + `grace_window_sec` = 27±0.5s** 結束（非 t=15、非 t=25、非 t=30——r4 二次修訂：B 的物理斷線在 t=10，Host 判定在 t=12，寬限自判定起算），期間耐心倍率恆為 ×1.5。**r4 補**：原條未列入斷線模擬基準清單，若以拔線路徑執行會得 t=33（各加判定延遲 8s），±0.5s 容差必 fail | VS（需 3 人） |
| 32 | GIVEN 進行中班次有 2 個站台已被 claim、NPC 處於非初始狀態，WHEN 新玩家中途加入 spawn 完成，THEN ≤`state_convergence_sec`（1s）內其 client 的 `IsClaimed`/`ClaimedBy`/`ClaimGeneration` 與 NPC 當前 state 與 Host 一致（無需等待下一次 milestone） | MVP |
| 33 | GIVEN MVP 建置（無 slot 保留），WHEN 玩家斷線後於 join 截止前重新點連結，THEN 以新玩家流程進房（更衣室），不恢復原位、原名額已可被他人取用 | MVP |

**第三輪新增（2026-09-06 r3）**

| # | 準則 | 層級 |
|---|---|---|
| 34a | GIVEN Host 於**第一個** Lobby，WHEN Host 分頁背景化 **30s** 後回前景，THEN 房間仍存活、roster 不變、無任何斷線訊息；期間另一玩家用連結加入成功 | MVP `[P-10]` |
| 34b | GIVEN 同 34a，WHEN 背景化 **120s**，THEN 同樣成立。**若 fail，必須記錄失敗發生在哪一層**（transport 逾時 vs **MPS 服務端 TTL／host keepalive**，見 #23b）——兩者的 fallback 完全不同，量不出層級等於沒量。實測 TTL 回填後，設計上限訂為「實測值 × `lobby_bg_safety_factor`（0.5）」 | MVP `[P-10]` |
| 34c | GIVEN **Settlement 之後的第二個 Lobby**（已依 #23a teardown 回 MPS-only），WHEN 重複 34a 的操作，THEN 同樣成立。**r4 新增理由**：「再開一班時去群組貼連結叫更多人」比首次開房更高頻，而原 AC34 只測第一個 Lobby，造成覆蓋假象 | MVP `[P-10]` |
| 35 | GIVEN **Host 端計算之**班次剩餘 **30.5s**（以 `shift_end_ts − host_now` 取得，取樣點＝Host 收到 approval request 的時刻），WHEN 新玩家點連結，THEN 進入更衣室；GIVEN 剩餘 **29.5s**，THEN 顯示「這班快下班了，你排下一班」導向 Lobby\*（邊界 `t ≤ 30.0` 鎖）。**r4 修正**：原條未定義由誰在哪一端量測，而 client 端的 wall-clock 偏差可達數分鐘，0.5s 級鑑別在 client 側不可信 | MVP |
| 36 | GIVEN 2 人房 A 於 t=0 **首次**離線觸發寬限期（優雅 close 基準），WHEN A 於腳本可控的 `t_click` 點連結重連並完成更衣室，THEN 寬限期於 **[`t_click` + 3.0s, `t_click` + 1.0s + 5.0s]** 區間內結束（＝加入 ≤`ui_feedback_sec` ＋ 更衣室 3.0-5.0s）、`online_player_count` 回到 2、耐心倍率回 ×1.0。**r4 二次修訂**：上一版寫死 [5.0, 8.0] 與自述構成不符（自點擊起算應為 (3.0, 6.0]），量測起點未定義是根因；現改為相對 `t_click` 的區間。**原條的「再退出再重連 3 次，每次寬限皆結束」已刪除**——依 #15a，第 2 次起不再觸發寬限期，見 AC50 | MVP |
| 37 | GIVEN 玩家於更衣室過場中（Onboarding），WHEN 其 socket 中斷，THEN roster 從未出現其名字、留守者降載未觸發、其 client 回 Idle | MVP |
| 37a | GIVEN 玩家於更衣室過場中，WHEN Host **優雅離開**（socket close／MPS 成員事件推播，即 #18 排歧表序 1 命中），THEN 過場於 **client 得知的時刻起** ≤`ui_feedback_sec`（1s）內中止並顯示「店長把鐵門拉下來了」，不卡在更衣室至過場結束。**得知時刻**：socket close 子路徑＝`relay_disconnect_propagation_sec`（2s，故端到端 ≤3s）；MPS 事件子路徑**依 `[P-10]` 回填，不得硬寫時限**（比照 AC6c）。**r4 二次修訂**：上一版把端到端上限寫成 1s，小於同一路徑的傳播下界 2s，恆不可達 | MVP `[P-8]` `[P-10]` |
| 37b | GIVEN 同上，WHEN Host 以**心跳逾時路徑**消失（背景化／拔線），THEN 該玩家**準時進場**（更衣室是定長情緒節拍，不延長也不提前），進場後依 **AC6b** 於 `session_end_worstcase_sec` 內收到局終。**r4 修正理由**：心跳逾時需 8s，而更衣室窗口只有 3.0-5.0s——原 AC37 的「≤1s 中止」在此路徑**數學上不可達**（缺口 3-5s），無論 timeout 取安全範圍的哪個值都不可達 | MVP |
| 38 | GIVEN **EditMode 單元測試**直接呼叫仲裁函式，claim 請求的到達時戳為 lock 建立後 **t=5.000s**，THEN 視為逾時前、正常仲裁；GIVEN **t=5.001s**，THEN 以世代不符拒絕。**r4 修正**：本條必須在**邏輯層**驗證——Web build 是單執行緒 60fps，幀量化 16.6ms 遠大於 1ms 判別解析度，兩個測項在實機上 99.99% 會落在同一幀，實機測試無法分辨。仲裁函式已要求為 engine-agnostic plain C#（見測試基建） | MVP |
| 39 | GIVEN Settlement 畫面，WHEN 任一玩家 20s（±1s）未按確認，THEN 自動視為全員確認進入 Lobby | MVP |
| 40 | GIVEN 更衣室過場中同步刻意延遲至 6s（腳本），WHEN 過場於 5.0s 結束，THEN 玩家準時進場、可移動，缺項以 NetworkVariable 現值顯示，同步完成後 ≤1 幀更新，轉場未延長 | MVP |
| 41 | GIVEN 全新玩家冷啟動，WHEN build 下載中，THEN 畫面為客製 Web Template（無 Unity 預設 loader、無百分比、無「Loading」等技術字樣），且畫面有可辨識的世界語言動態 | MVP |
| 42 | GIVEN Host 於 InShift，WHEN 按 Cmd+W／點 X 關閉分頁，THEN 出現 `beforeunload` 確認框（桌面 Chrome）| MVP `[P-18]` |
| 42a | GIVEN Host 於 InShift 且 `online_player_count` > 1，WHEN 按站內 `end_shift_early`，THEN **出現站內二次確認框**（「還有人在店裡，要拉鐵門嗎？」），確認後才結束；GIVEN Host 獨留（N=1），WHEN 按同一顆按鈕，THEN **不出現確認框**，≤`ui_feedback_sec`（1s）直接進 Settlement。**r4 修正理由**：原 AC42 後半「站內按鈕不出現確認框直接結束」，等於一顆**隊友在場時無確認即終結全隊 session** 的按鈕——比關分頁還危險（後者好歹有瀏覽器確認框），誤觸即毀局 | MVP |
| 43a | GIVEN InShift client 自身全程前景、`navigator.onLine` 為 true，WHEN 以 tc netem 對該 client **單向丟棄所有入站封包**（含 MPS session 層）達 `heartbeat_timeout_sec`，THEN 依 #18 序 5 判「自己斷線」，顯示「這班你先下班了——點連結再回來上工」，並依 **#17a** 完成 teardown | MVP |
| 43b | GIVEN 同上，WHEN **只丟棄 Relay 路徑的入站封包、MPS session 層仍可達且 Host 仍在 roster**，THEN 依 #18 序 4 判「無法排歧」，顯示不預設因果的「跟店裡斷線了，點連結重新上工」 | MVP `[P-10]` |
| 43c | GIVEN 43a／43b 任一情境（client 出站仍通，**Host 持續收得到它的心跳**），WHEN 逾時，THEN **Host 端亦須完成 #24 的完整處置序列**：手持物掉落、站台解鎖、avatar despawn、roster 更新、**MPS 名額釋放**、`online_player_count` 重取樣、寬限期觸發——**缺任一項即 fail**。驗證方式：逾時後讓另一玩家以同一連結加入 2 人房，**必須成功**（不得出現「這班人滿了」）。**r4 新增理由**：原 AC43 只驗 client 端文案，完全不驗 Host 端後果，而後者才是永久軟鎖死的所在 | MVP |

**第四輪新增（2026-09-13 r4）**

| # | 準則 | 層級 |
|---|---|---|
| 44 | GIVEN InShift 連線正常，WHEN 觀察任一方向的心跳封包 10s，THEN 收到 5±1 拍（驗證 `heartbeat_interval_sec` ＝ 2s）。**r4 新增理由**：常數三欄表原宣稱此常數由 AC27 驗收，但 AC27 只斷言 8s 逾時——**46 條 AC 無一驗證心跳頻率本身** | MVP |
| 45 | GIVEN client 的系統時鐘被人為調快 60s，WHEN 進入 InShift 並觀察 60s，THEN **由 log 讀取內部 offset 估計值**，`|offset_estimate − true_offset| ≤ `clock_offset_tolerance_ms`（100ms）。**r4 二次修訂**：上一版判準是「畫面倒數誤差 ≤1s」，而 `clock_display_interval_sec` 本身就是 1s——判準等於觀測量化，pass/fail 不可分辨（與 AC38 的 16.6ms 幀量化同型錯誤，當時已認定實機不可測）。改讀內部估計值即繞開量化 | MVP |
| 45a | GIVEN 同上，WHEN 觀察畫面，THEN 班次倒數的**顯示更新節奏**為 `clock_display_interval_sec`（1s）±0.2s（驗證顯示層常數本身） | MVP |
| 46 | GIVEN 已建立 NGO 連線且 `NetworkConfig.TickRate` 設為 10，WHEN 量測 NetworkTransform 的實際發送頻率，THEN 為 10Hz ±1Hz。✅ **`[P-3]` 已回填（2026-09-13）：NetworkTransform 的送出頻率＝全域 `NetworkConfig.TickRate`，無 per-instance 設定**（全檔 grep `SendRate`／`UpdateRate` 零命中；可調的只有 `PositionThreshold` 等「要不要送」的門檻）。⚠ **連帶後果**：把 TickRate 設為 10 會**同時**把所有 NetworkVariable 降到 10Hz（預設是 30），需確認對客人狀態同步無害 | MVP |
| 47 | GIVEN 班次進行中，WHEN Host 按 `end_shift_early`，THEN `shift_end_ts` 被改寫為當下時刻，全 client 的倒數顯示於 ≤1s 內反映；GIVEN 未提前收班，THEN `shift_end_ts` ＝ 建立時刻 ＋ `shift_length_sec` | MVP |
| 48 | GIVEN 冷啟動下載進行中，WHEN 以 DevTools 將頻寬降為 0 達 `load_stall_timeout_sec`（10s），THEN 進入 LoadFailed 顯示「鐵門卡住了，重新整理看看」＋可用的重試鈕；GIVEN 以 5Mbps 節流（`T_load ≈80s` 的正常慢速），THEN **不得**誤判為 stall | MVP |
| 49 | GIVEN 進行中班次，WHEN 任一玩家斷線且 Host 完成 #24，THEN 其 avatar NetworkObject **已 despawn**（留守者畫面上不存在該角色，不留不會動的人形阻擋動線）；且該 client 恢復前景後 flush 的任何 NetworkTransform 更新**不得**讓已離線的角色動起來 | MVP |
| 50 | GIVEN 2 人房 A 於同一班次內**第 2 次**離線，THEN `online_player_count` 立即變 1、當前波次剩餘生成量降載（保護仍在），但**不進入寬限期**：不套用耐心 ×1.5、照常生成新客人、不顯示「老闆出來擋一下」。GIVEN A 第 3、4 次離線，THEN 行為同第 2 次 | MVP |
| 51 | GIVEN 班次剩餘 20s（已過截止），WHEN 新玩家點連結，THEN 進入 **Lobby\***：畫面同時顯示「這班還在忙」＋前一班剩餘時間＋在場隊友人數，**且可進入單人練習沙盒**；WHEN 前一班進入 Settlement 並轉入 Lobby，THEN 該玩家**自動與既有玩家合流於同一 session**（不另開新房），沙盒被中斷且不延遲合流 | MVP |
| 52 | GIVEN Settlement 結束轉入 Lobby，WHEN 觀察連線狀態，THEN NGO／Relay 已 teardown、僅存 MPS session 層（驗證 #23a 的不變式，使 AC34c 得以成立） | MVP `[P-10]` |
| 53 | GIVEN 2 人房其中一人斷線且 Host 已完成 #24a 的名額釋放，WHEN 第三位玩家以同一連結加入，THEN **加入成功**（`session_member_count` 已回到 1，未達 `max_players`）；GIVEN 名額未釋放，THEN 本條 fail——這是 B1 的直接驗收 | **MVP-必達** `[P-10]` |
| 56 | GIVEN PlayMode 多實例，Host spawn 一個道具並 `ChangeOwnership` 給某 client，WHEN 強制 `DisconnectClient` 該 client，THEN 該道具 `IsSpawned == true` 且 `IsOwnedByServer == true`（未被銷毀），且其座標為斷線當下座標、已 unparent。**W1 第 0 批查證後新增**：`DontDestroyWithOwner` 預設 `false`＝預設銷毀，且銷毀發生在 `OnClientDisconnectCallback` **之前**——**這是唯一能在 CI 擋住「手持物斷線蒸發」的測試**，且本地 host 模式測不出來（host 自己不走 remote disconnect 清理路徑） | **MVP-必達** |
| 57 | GIVEN 兩玩家連續互相交接同一道具，WHEN 兩次 `ChangeOwnership` 間隔 < `ownership_change_cooldown_ticks`（6 個 network tick），THEN 系統拒絕或延後第二次交接，且 log 中不出現 NGO 的「[Rapid Ownership Change Detected]」警告 | MVP |
| 55 | GIVEN Host 於 Lobby，WHEN 按「複製邀請連結」，THEN 剪貼簿內容為可直接開啟的帶碼連結（貼到另一瀏覽器分頁可免輸碼進房）；GIVEN clipboard API 不可用（`[P-19]` fallback），THEN 改顯示可全選的連結文字框並提示手動複製，**不得靜默失敗**。**r4 二次修訂新增理由**：本按鈕同時是 UI Requirements 的 MVP 列、Interactions 契約的 `copy_invite_link`、#23 的「必做配套」、以及 #23 替代設計 (c) 的核心，卻在先前 54 條 AC 中**無一驗收** | MVP `[P-19]` |
| 54 | GIVEN 舊版 build 的分頁（模擬瀏覽器快取）嘗試加入新版 Host 的房間，WHEN approval 檢查 build／protocol version，THEN 拒絕並顯示「這是舊的班表，重新整理一下」，**不得靜默進入造成 desync** | **MVP-必達** `[P-17]` |

**測試基建需求**（/qa-plan 引用）：
- **測試分層順序**（由便宜到貴）：(1) EditMode 純邏輯——心跳判定、公式③④、
  `ClaimGeneration` 比對、排歧表判定函式，皆應為 engine-agnostic plain C#；
  (2) 本地 NGO PlayMode（Editor 多實例）——斷線/交接/波次/遲加入類；(3) Playwright＋
  Chrome 對本地伺服的實機 Web build——背景化、節流、冷啟動、關分頁；(4) 一次性 itch.io
  部署——AC3、P-4、P-6。完整策略歸 `/qa-plan`
> **編號前綴**：本節一律以 `AC` 前綴指涉驗收準則，與 Core Rules 的 `#` 區分（r3 版混用
> 同一種 `#` 符號，讀者無法分辨「#20」指的是心跳規則還是第 20 條 AC）。

- **AC20、AC21、AC26 需雙瀏覽器腳本驅動**（Playwright/CDP）＋可控 RPC 送出時序，人工點擊
  無法保證同時；測試鉤子須以 build flag 隔離、release build 剔除
- **AC38 改為 EditMode 單元測試**（r4 修正）——1ms 判別解析度遠小於 Web build 的 16.6ms
  幀量化，實機無法分辨 5.000s 與 5.001s。仲裁函式須為 engine-agnostic plain C#
- AC22、AC23 需網路節流（**只套受測 client 單側**）；AC15、AC16、AC29、AC34a/b/c 需可程式化分頁背景化
- AC17、AC18、AC36 需自動化 socket 切斷/恢復以精準控制秒數
- **斷線模擬基準**：AC10、AC11、AC12、AC13a、AC13b、AC14、AC30、**AC31**、**AC36**、
  **AC49**、**AC50**、**AC53** 一律以**優雅 WS close**（`socket.close()`）模擬，作為
  物理斷線基準。
  ⚠ **基準時刻的定義（r4 二次修訂，機械檢查找到的單點缺陷）**：`t_disconnect` 在公式①
  是「**Host 判定**時刻」，而 `socket.close()` 只是「**物理斷線**時刻」，兩者相差
  `relay_disconnect_propagation_sec`（2s）。**凡 AC 寫「≤N 秒完成某項清理」者，一律自
  Host 判定時刻起算**（AC27 已有此字樣，AC10／AC11／AC12／AC13a／AC31 已照此修正）。
  先前把 `socket.close()` 時刻當成 `t_disconnect = 0`，使那五條同時多出 2s 而全部算術
  不可達——**同一個符號兩種語義**是它們的共同根因，修這一句即一次消除五條。
  （r4 補列 AC13a／AC31／AC36／AC49／AC50／AC53——先前未列，
  以拔線路徑執行會各自多出 6-8s 判定延遲，使其 ±0.5s 容差必 fail）；
  **拔線**（無 close frame，對應「Wi-Fi 一抖」）路徑由 AC27 單獨驗證判定區間 [6,8]s。
  **AC6a 明確標註為 `socket.close()` 代理；AC6b 必須以真實瀏覽器「點 X 關閉分頁」與
  「kill 瀏覽器行程」兩種動作驅動**，不得以 `socket.close()` 替代
- AC28、AC34a/b/c 需 CDP 對 Host 分頁做背景化（非關閉）。**背景化的主要手法**：`page.evaluate`
  覆寫 `document.hidden`／`visibilityState` 並 `dispatchEvent(new Event('visibilitychange'))`
  直接命中 production 監聽路徑；`Page.setWebLifecycleState` 與 Playwright 雙分頁
  `bringToFront()` 留作真實情境交叉驗證
- **只能在已建置並伺服的實機 Release（Stripping High）Web build 驗證**——`.jslib` 在 Editor
  不執行（`[P-7]`），Editor Play Mode 通過不算數：
  **AC15、AC16、AC28、AC28a、AC29、AC34a/b/c、AC41、AC42、AC43a/b/c、AC48**
  （r4 補列 AC42 與 AC43a/b/c 與 AC48——三者分別依賴 `beforeunload`、`visibilitychange`／
  `navigator.onLine`、以及下載進度回報，全部走 `.jslib`，原清單漏列）
- AC3 需實際部署到 itch.io（不能用本地 server 替代——iframe query 轉發是平台行為）；
  **與 `[P-6]`（Brotli）、`[P-19]`（clipboard 權限）綁同一次部署**
- AC7、AC7a、AC7b 需固定頻寬基準（標準網路定義如上）＋清空快取，5 次取樣取 P95
- AC43a/b 需 tc netem 單向丟包（只丟入站）以維持 `navigator.onLine === true`；
  **AC43b 需能分別針對 Relay 端點與 MPS 端點設定規則**（分辨兩條獨立連線）
- **AC53 是 B1（MPS 名額釋放）的唯一直接驗收**，且 **AC36、AC33 的可執行性依賴它**
  ——標記 `blocked-by: AC53`，AC53 未通過前這兩條不進 /qa-plan 執行清單
- **AC23 標記 `blocked-by: 第一人稱控制器 GDD`**（其判準「角色移動速度上限」尚不存在）

## Provisional Assumptions（未驗證的引擎/平台行為）

以下標記 `[P-n]` 的項目是**假設而非已驗證規格**。技術原型的職責就是證實或推翻它們；
下游實作不得在回填前把它們當定案。

> **r4 結構前置 #4：新增「影響」欄（META-I1）**
> r3 的 [P] 表只寫「假設／驗證方式／fallback」，**沒有寫「若為假，哪些 AC、常數、規則
> 會死」**。B4 就是這個缺口的代價：`[P-10]` 的 fallback 會讓「Host 消失」分支永遠不可達，
> 直接殺掉 AC6b（文件自標「保底路徑，必達」），四輪無人發現——因為沒有任何一張表逼你
> 去看下游。
> **判準（r4 新增）：任何 fallback 會殺掉 MVP-必達 AC 的 [P]，其 fallback 本身即為 blocking。**
> 反之，fallback 可行的 [P] 不是 blocking，屬原型查證範圍。

> **原型 W1 優先序（r4 二次修訂，依「同一次操作可否併測」× 「fallback 可行性」重排）：**
>
> | 批次 | 內容 | 為什麼綁在一起 |
> |---|---|---|
> | **第 0 批**（零原型成本） | `P-9` 前半（`UnityTransport` 逾時欄位名與預設值）、`P-20(a)`（`DontDestroyWithOwner` 名稱與預設值）、`P-20(b)`（ownership transfer API 與限制）、`P-3` 前半（tick API 語義） | **全是查 API 文件**，不需要跑任何東西。先做完可能直接消掉數條假設 |
> | **第 1 批**（同一次 Sessions API 建連 ＋ Host 消失實驗） | `P-10`(a)(b)(c)(d)、**`P-17`**、`P-14`、`P-2(b)` | 同一次建連即可觀察：能否拆分 Relay、approval callback 可否註冊、成員事件與 roster 行為、host-side 移除 API、kill 行程後的偵測時刻、重連身分是否延續 |
> | **第 2 批**（同一次 itch.io 部署，約 10 分鐘） | `P-4` ＋ `P-6` ＋ `P-19` | 三者都只有實際部署才能答 |
> | **第 3 批**（同一次 Release／Stripping High build） | `P-7` ＋ **`P-18`** | `P-18` 自己的驗證方式欄就寫「查證併入 P-7 的同一次 Release build」 |
> | **第 4 批** | `P-3` 後半 ＋ OQ#1 ＋ **AC22 聯測**（拉高 tick 後須同時觀察 `P-16` 的 send queue 深度） | 約束⑧的連動必須在同一次量測裡有答案 |
> | **第 5 批** | `P-13` ＋ `P-15` | 兩者都是 close frame 的送達可靠性 |
> | **W2** | `P-2(a)`、`P-5`、`P-11`、`P-12`、`P-16` | fallback 皆可行，且無 MVP-必達 AC 依賴 |
>
> **相對上一版的三處改動與理由**：
> 1. **`P-17` 從最後一批移到第 1 批**——它的 fallback 殺掉 AC54（MVP-必達），而查證成本
>    近乎為零（與 P-10(b) 是同一次操作）。上一版把它排最後，**違反本文件自己寫下的
>    「fallback 可行的讓位給 fallback 不可行的」**。
> 2. **`P-18` 從最後一批移到第 3 批**——它自己的驗證方式欄就說要併入 P-7，優先序卻把它
>    排到 P-7 之後四批，表內自相矛盾。
> 3. **新增第 0 批**——`P-9` 前半、`P-20` 全部、`P-3` 前半都是純文件查詢，混在原型批次裡
>    等於讓零成本的事排隊等高成本的事。
>
> **`P-11` 維持移出 W1** ✓（B9 證明它問的是基於錯誤前提的問題）。
> **`P-2` 拆半後 (b) 移入 W1**（它承載 AC50 與 #15a，皆 MVP，先前整條排 W2 是層級誤判）。
> 改動理由：
> 1. **P-10 升為第一**（原第二）——它一次回答四項 blocking（B4 訊號語義、B1 成員移除 API、
>    B6 服務層 heartbeat、#23 能否拆分），其中 B4 是全輪唯一「fallback 自己不成立」的項目。
> 2. **P-4 讓位**不是因為不重要，而是**它的 fallback 是全表最健康的一條**（不轉發 query →
>    輸碼成為唯一入口，而 #8 已把輸碼釘成必備備援、AC2 已保底）。依 r4 的判準，
>    fallback 可行的讓位給 fallback 不可行的。
> 3. **P-4／P-6／P-19 綁同一次部署**——三者都只有實際部署才能答，10 分鐘的事，不跑三趟。
> 4. **P-3 上移並與 AC22、OQ#1 聯測**——若 P-3 證實是全域 tick，AC22 依約束⑧數學上不可達，
>    而 AC22 是 MVP AC、`interact_rtt_p95_ms` 是已登錄常數。兩件事必須同一次量測有答案，
>    否則 P-3 回來時沒人會聯想去重查 AC22。
> 5. **P-11 移出 W1**——B9 指出它問的是一個**基於錯誤前提**的問題（HOL blocking 在 TCP 層，
>    在 pipeline 之下）。取而代之新增 **P-16（send queue 溢位）**，那才是 WSS 單一 TCP
>    底下真正該防的東西。
>
> **實機複驗（2026-09-13，`prototypes/w1-netcode/`）**：第 0 批的結論原本只來自文件與原始碼。
> 由於本機解析出的 `com.unity.transport` 是 **2.7.4**（第 0 批依 NGO 相依宣告記為 2.6.0），
> 已另寫 EditMode 測試把結論降落到實際安裝的套件上：
> `Assets/Tests/EditMode/EngineFactProbeTests.cs`，**8/8 通過**
> （結果：`prototypes/w1-editmode-results.xml`）。
> 複驗項目：`DisconnectTimeoutMS`＝30000、`HeartbeatTimeoutMS`＝500 且 <10000、
> 內建逾時 > app 心跳 8s（約束⑤）、`NetworkConfig.TickRate`＝30、
> `DontDestroyWithOwner`＝false、**`NetworkTransform.AuthorityMode`＝Server**（確認 #2 的更正正確）、
> `Interpolate`＝true。
> 該測試刻意寫成**斷言查到的值**：任一條 fail 即代表 GDD 回填的引擎事實與實機不符，
> 屆時該改的是本文件，不是測試的期望值。**套件升級後應重跑。**
>
> **W1 的成功判準**：原型報告必須同時回填下表的「影響」欄——每條被推翻的假設要明講
> 它殺掉了哪幾條 AC。**沒有這一欄的原型報告不算完成。**

| # | 假設 | 驗證方式 | 若為假的 fallback | **影響（若為假，什麼會死）** | 目標 |
|---|---|---|---|---|---|
| ~~P-1~~ ✅✅ **已實測回填 2026-09-13（W1 第 1 批）** | **固定 6 碼、全大寫英數，字集 `689BCDFGHJKLMPQRTW`（6 樣本）——無母音、無 0/O/1/I/L。** 假設成立且優於預期：**fallback 不需要，#8 的正規化規則已刪除**。~~原假設~~ `session.Code` 為短、可口述的碼，且字集不含或可正規化 0/O、1/I/l | 原型直接取值列印 | 碼太長/不可讀/字集不受控 → 自建短碼對照表映射到 session id | AC1、AC2 的可用性。**fallback 可行**（自建短碼表），非 blocking。註：此 fallback 同時是 P-10 服務層 fallback 的前置——只有短碼與 session id 解耦，才可能在 session 被服務端回收後用**同一個房間碼**重建 | 原型 W1 |
| P-2 | 30s slot-hold 可與 Relay/MPS 服務端逾時共存，且能靠自建 GUID 表恢復原位 | 原型斷線 29s/31s 實測 | 服務端更早釋放 → 縮短 W 至服務端上限；或砍掉原位恢復（本就是 Post-MVP） | **拆兩半（r4 二次修訂）**：**(a) 30s slot-hold 與原位恢復**＝AC17／AC18／AC19，全為 Post 層級，fallback 可行，非 blocking。**(b) 跨重連的 session-level player 身分** ✅✅ **已實測回填（W1 第 1 批）**：`session.CurrentPlayer.Id` **等同** `AuthenticationService.Instance.PlayerId`（實測皆為 `lEYLoSNzPcbDMI7OnZij79CxFKGp`）。因此**只要匿名帳號不變，身分就跨 session 延續**，#15a 的離線次數計數與 AC50 有可靠依據。`ISession.ReconnectAsync()` 亦存在。⚠ 殘留：匿名帳號本身綁在本機憑證上，**清快取／換瀏覽器會換身分**（與 OQ#5 的 PlayerPrefs 儲存分割同源）——這是設計可接受的限制，但應在 #15a 註明「換裝置即重新計數」。＝**AC50（MVP）** 與 **#15a 的全部目的**——若身分不可得，離線次數只能用 NGO ClientId 計數，而重連會配發新 ClientId，**每次都算「第一次」，「用 alt-tab 調低難度」的漏洞原封復活**。**(b) 目前無 fallback，且應移入 W1**（先前整條排 W2 是層級誤判） | 原型 W2 |
| ~~P-3~~ ✅✅✅ **已回填、實機複驗、並於 2026-09-15 完成雙進程實測（W1 第 0＋4 批）——本項結案** | ~~玩家同步 10Hz 可獨立於全域 tick 調整~~ → **假設為假，但後果與預期相反（是好消息）**。NetworkTransform 送出頻率**＝全域 `NetworkConfig.TickRate`，無 per-instance 設定**（預設 30）。**但 RPC 完全不受 tick 影響**（每幀 `PostLateUpdate` 送出），受影響的只有 NetworkVariable 與 NetworkTransform。→ **AC22 可達成**（≈235-250ms），約束⑧ 已重寫。🟢 **第 4 批雙進程實測直接驗證（20 樣本、Relay WSS、經真實網路）**：**tick=10Hz → p95 335.8ms；tick=1Hz → p95 333.0ms**。tick 改十倍、往返一毫秒未動，「RPC 非 tick-gated」由原始碼推論升格為**實測事實**。<br>🔴 **同一次量測意外掀出一個原設計完全沒有的變數：Relay region**。上面兩組都是預設 region；改指定 `asia-northeast1` 後 **p95 = 94.5ms**。**AC22 的成敗實際上由 region 決定，不是由 tick 決定**——這是本項最重要的產出，已升為約束⑮ 與 OQ#20。<br>殘留實機項：server frame rate、WebSocket 丟包 P95 尾端、`InterpolationBufferTickOffset` 實際預設值 | 查 NGO 2.13 API＋原型實測，**必須與 AC22／OQ#1 同一次量測** | 實為全域 tick → **必須先驗證 tick rate 對 AC22 的影響**，必要時把 tick 拉高至 20-30Hz 並改用 interpolation／send-threshold 降低單物件發送頻率（tick rate 與「每個物件多久送一次」本來就是兩件事） | **AC22（MVP）**、AC23、AC46、約束⑧、registry 的 `interact_rtt_p95_ms`。⚠ **裸 fallback 不可行**——「改為統一 tick 值」若沿用 10Hz，往返多 200ms，AC22 數學上必敗。fallback 必須附帶「拉高 tick」才成立 | 原型 W1 |
| ~~P-4~~ ✅ **已實測回填 2026-09-13（W1 第 2 批，真實部署）** | **假設為假，但找到唯一可行路徑**。實測 itch.io 部署（草稿頁）：<br>• `location.search` ＝ **`?v=1789400690`**（itch.io 自己的版本參數，**原始 `?code=` 完全不見**）<br>• `parent.location.search` ＝ **`__CROSS_ORIGIN_BLOCKED__`**（iframe 來自 `html-classic.itch.zone`，與 `itch.io` 跨域）<br>• **`document.referrer` ＝ `https://arlong666.itch.io/w1-netcode-probe-internal-test?code=…`（原始 URL 含 query，可讀）** ← **唯一可行路徑**<br>**結論**：帶碼連結**仍可實作**，但必須改從 `document.referrer` 解析，不能讀 `location.search`。⚠ referrer 可能被使用者的瀏覽器隱私設定或 `Referrer-Policy` 削減，故 **#8 的輸碼備援絕不可砍**（AC2 已保底） | **實際部署一次測**（10 分鐘），與 P-6／P-19 同一次 | 不轉發 → 輸碼路徑成為唯一入口（AC2 已保底），並改用「短碼優先」的分享文案 | AC3 的前半。**fallback 是全表最健康的一條**——#8 已把輸碼釘成必備備援，AC2 已保底，非 blocking | 原型 W1 |
| P-5 | NGO **跨 channel**（本專案實際使用的 reliable/unreliable 組合）可能亂序，需單物件 sequence 保護 | 原型以實際 channel 組合壓測（**不是**單 reliable channel——TCP 本就有序，會得偽陰性） | 證實有序 → **移除**通用 sequence 層，**但保留 `ClaimGeneration`**（防遲到請求，與有序性無關） | AC26。**fallback 可行**（移除是簡化，非損失），非 blocking | 原型 W2 |
| ~~P-6~~ 🔴 **已實測回填 2026-09-13：假設為假，且後果比預期嚴重** | **itch.io 不支援 Brotli `Content-Encoding`，且會把上傳的 `.br` 解壓後重新提供**，實際傳輸量 **正好 2.00 倍**：<br><br>｜檔案｜我們的 Brotli｜itch.io 實際傳輸｜倍數｜<br>｜`Web.wasm.br`｜5,741,298｜8,108,255（`content-encoding: gzip`）｜1.41｜<br>｜`Web.data.br`｜1,506,949｜6,522,513（**無 content-encoding**）｜**4.32**｜<br>｜`Web.framework.js.br`｜78,508｜92,753｜1.18｜<br>｜`Web.loader.js`｜26,983｜9,514｜0.35｜<br>｜**合計**｜**7,353,738**｜**14,733,035**｜**2.00**｜<br><br>機制已確認：`Web.data.br` 下載後前 4 位元組為 `UnityFS` 明文 → **itch.io 解壓了 Brotli**，存原始內容後以 gzip（wasm/js）或不壓縮（data）提供。遊戲能跑是因為 Unity 收到的本來就是可用資料。<br>🔴 **對公式⑤ 的衝擊**：`T_load ≤25s` 建立在「50MB Brotli ÷ 20Mbps」之上；在 itch.io 上那會變成 **≈100MB 傳輸 → T_load ≈50s**，**60 秒硬標直接破，支柱 4 不成立**。<br>✅ **解法已實測成立**：把 `PlayerSettings.WebGL.decompressionFallback` 設為 **`true`**。<br>副檔名隨之從 `.br` 變為 **`.unityweb`**——itch.io 不認得它是壓縮檔，因此**原樣提供**（`content-encoding: none`），改由 Unity 的 loader 自行解壓。<br><br>｜建置方式｜本地｜itch.io 傳輸｜倍數｜<br>｜`.br`（fallback=false）｜7,353,738｜**14,733,035**｜2.00｜<br>｜`.unityweb`（fallback=true）｜7,444,699｜**7,416,748**｜**0.99**｜<br><br>**傳輸量減半，回到 Brotli 水準，公式⑤ 的 `T_load` 預算恢復。** 部署後實測遊戲正常運作。<br>**代價**：`Web.loader.js` 由 26,983 → 117,894 bytes（+90KB，內含 JS Brotli 解壓器），
<br>🔴🔴 **解壓的 CPU 時間已於 2026-09-17（第 4 批）量出，而它推翻了本項當時的結論**：當時寫「傳輸量減半，公式⑤ 的 T_load 預算恢復」——**預算並沒有恢復，只是從網路搬到了 CPU**。實測（8 核桌機、localhost、配對法：同一分頁先後載入壓縮版與預先解壓版）：壓縮後 6.98 MB → 解壓後 **34.13 MB**（4.89×）；原生 C brotli 解壓僅 **86 ms**，而 **Unity 的 JS 解壓器約 2.0-2.2 s（16.3 MB/s，慢約 23 倍）**。對照組（預先解壓、檔名不變、loader 原樣通過）的總 CPU 僅 331-412 ms，其中 wasm 編譯單獨計時 346 ms —— **解壓是大頭，編譯與引擎初始化都是小項**。<br>線性外推到 50MB 硬標約 **15 s**，使 `T_load ≈ 40.4 s`，**AC7a 破**。有效 build size 天花板因此降到約 **28 MB**，已升為 **OQ#21**（跨 technical-preferences 權責）。<br>✅ **該複驗已於同日完成，未翻案**：限速 20Mbps 與 5Mbps 下，下載窗口拉長 300 倍而「資料在手後的 CPU」維持 2.5-3.2s 不動 → **解壓不與下載重疊，40.4s 不是高估**。OQ#21 因此已無技術前置，純屬產品取捨。<br>🔴 **此為 Web 建置的強制設定，不是可選優化**——`decompressionFallback = true` 必須寫進建置規範（itch.io 的限制未變；改變的是它的代價現在有數字了）。 | 原型部署後看 network trace，與 P-4／P-19 同一次 | 不支援 → 改 gzip 或無壓縮，重估 T_load 與 build size 上限 | AC7、AC7a 的 `T_load ≤25s`——**該預算的餘裕已經是 0**（50MB ÷ 20Mbps ＝ 20s ＋ TTFB 5s）。⚠ **裸 fallback 不可行——與 P-3 同構**（r4 二次修訂）。代入算式：50MB(Brotli) → gzip 約 ×1.2 ＝ 60MB ÷ 20Mbps ＝ 24s ＋ TTFB 5s ＝ **29s > 25s**，缺口 4s。故 fallback **必須附帶「下修 build size 上限」**才成立，而該動作跨出本 GDD 權責（屬 technical-preferences 的專案級硬標）。另影響 `join_time_budget_sec`、`join_phase_budgets_sec`、跨文件常數 `build_size ≤50MB` | 原型 W1 |
| ~~P-7~~ ✅✅ **已實測回填 2026-09-13（W1 第 2 批，Release Web build）** | **雙向皆通過**：JS→C# 的讀取（`location.search`／`visibilityState`／`navigator.onLine`／`performance.now`）與 **C#←JS 的 `SendMessage` 回呼**（clipboard 結果回傳 `OK`）在 **IL2CPP ＋ Managed Stripping High ＋ Brotli 的正式 build** 下**全部正常**，`[Preserve]` 確實擋住了裁切。實測 console：`[W1WEB] boot ownQuery='?code=TEST99' iframe=0`、`[W1WEB] clipboard result = OK`。~~原假設~~ `visibilitychange`／`navigator.onLine`／`online`/`offline` 可經自建 `.jslib`（JS→C# `SendMessage`）橋接進 Unity WebGL；**接收方法在 IL2CPP＋Managed Stripping High 下需 `[Preserve]` 或 `link.xml` 保護**（否則被當死碼裁掉，僅正式 build 現形）；Editor 不執行 .jslib，分流邏輯**只能在實機 Release Web build 驗證** | 原型 W1 寫 .jslib＋`[Preserve]`，於 Release build 實測。**同一次併測 P-18**（`beforeunload`／`sendBeacon`）與 `performance.now()` 的單調時間源 | 事件不可靠 → 改以 `requestAnimationFrame` 停擺時長估算（精度較差，5s 閾值需放寬）；Stripping 裁掉 → link.xml 全保留該類別 | AC15、AC16、AC28、AC28a、AC29、AC34a/b/c、AC41、AC42、**AC43a/b/c**、AC48——**幾乎所有 Web 行為 AC**；另影響 Core Rule #17 的單調時鐘要求、#12 的 `beforeunload`、公式③全條、#18 排歧表序 2、常數 `background_disconnect_threshold_sec`。⚠ **fallback 與約束⑪直接衝突（r4 二次修訂）**：fallback 寫「5s 閾值需放寬」，但 `background_disconnect_threshold_sec` 的安全範圍上界＝5、約束⑪鎖死 `≤5`（>5 即違反「不瞬移」鐵律）——**閾值不能放寬**，而 rAF 停擺估算無法分辨 5.0s 與 5.1s → **AC29 在 fallback 下不可測**。二階影響：link.xml 全保留會增大 build size，打回已歸零的 T_load 餘裕（與 P-6 的 fallback 反向拉扯）。**r4 縮小查證範圍**：引擎參考文件記載「NGO 2.6+ 用 codegen 取代反射初始化（stripping 相容性較好）」，本專案為 2.13.2，故 **NGO 自身的序列化不在風險面**；風險僅限 `.jslib` 經 `SendMessage` 呼叫的 C# 接收方法（那確實是反射呼叫） | 原型 W1 |
| P-8 | Relay 偵測 Host socket 斷開並傳播至其餘 client 的延遲 ≤`relay_disconnect_propagation_sec`（2s） | 原型 Host 關分頁，量 client `OnClientDisconnect` 時刻 | 更慢 → AC6a／AC16／AC28 上限依實測放寬並回填該具名常數 | AC6a、AC16、AC28、公式①的 `T_detect`。**fallback 可行**（放寬上限），非 blocking。r4 已把此延遲提升為具名常數，四處引用同一個值 | 原型 W1 |
| ~~P-9~~ ✅✅ **已回填並實機複驗通過 2026-09-13（W1 第 0 批）** | **`DisconnectTimeoutMS` 預設 30000ms＝30s ≫ 8s，約束⑤成立**；欄位名 1.x→2.x 無更名。**Relay 沒有 allocation idle timeout**，而是每 client 連線 **10s TTL**（host 獨自時 60s）→ 約束④ 已改為情境式，AC13c 填入 10s。⚠ 新發現：`HeartbeatTimeoutMS` 雙重用途（UTP heartbeat ＋ Relay PING 間隔）**不得調動**；`ClientConnectionBufferTimeout`＝10s 影響 #9 approval 閘門；`DisconnectTimeoutMS` 影響 send queue 容量。~~原假設~~ NGO/UTP 與 Relay 的內建連線逾時 ≥ `heartbeat_timeout_sec`（app-level 心跳才是先判定者）；**Relay allocation idle timeout ≥ `reconnect_window_sec + heartbeat_timeout_sec` ＝ 38s**（r4 修正：原寫 ≥30s，漏計 `T_detect`）。**順帶記錄 `UnityTransport` 逾時欄位的確切名稱**（NGO 1.x→2.x 有更名）**與 Relay allocation idle timeout 的實測值**（AC13c 需要它） | 查 NGO 2.13 `NetworkConfig`／`UnityTransport`／Relay 文件＋原型實測 | 內建更短 → 以內建值為心跳逾時上限，Tuning Knobs 約束區塊回填 | 約束④、約束⑤、⑬、AC13c、**#24a 末段**（Host 自己消失時的服務端回收）、常數 `heartbeat_timeout_sec` 與 `reconnect_window_sec`。⚠ **條件式不可行（r4 二次修訂）**：若內建逾時 <8s，代入約束①（k×interval）②③ → timeout=6 時需 `threshold < 4`，逼使 `background_disconnect_threshold_sec` 下修至 2 → **AC15（3s 背景走 catch-up）、AC16（8s 背景）、AC29（5.0/5.1 邊界）三條 MVP AC 的 GIVEN 全部作廢**。**前半（查 `UnityTransport` 逾時欄位名與預設值）是純文件查詢、零原型成本，應排最前** | 原型 W1 |
| P-10 ✅**(b)(c)(d) 已回填；(a) 機制已證實、秒數待實測** | **四個查證項，三個已解決（W1 第 1 批，2026-09-13，編譯期驗證）**：**(b) 可拆分** ✅ `WithRelayNetwork` 為擴充方法、`IHostSessionNetwork.StartRelayNetworkAsync`/`StopNetworkAsync` 存在、`NetworkState.Stopped` 獨立存在 → **#23 成立**。**(c) 事件與查詢齊全** ✅ `ISession` 的 `Deleted`/`SessionHostChanged`/`PlayerLeaving`/`PlayerHasLeft`/`PlayerJoined`/`RemovedFromSession`/`SessionMigrated`/`StateChanged`，以及 `Host`/`HasPlayer`/`Players`/`PlayerCount` → **排歧表兩條路徑成立且較原設計更簡單**。**(d) `IHostSession.RemovePlayerAsync` 存在** ✅ → **#24a 成立，全表唯一無退路的查證項解除**。**(a) ✅ 已完整回填（W1 第 3 批實測，2026-09-14）：假設為假，背景分頁不會回收 session。**
第 1 批在原始碼層面確認保活掛在 PlayerLoop 上（`HeartbeatSeconds => 10`、
`ActionScheduler.JoinPlayerLoopSystem()`），並據此推論背景分頁會使其停送——**推論錯了**。
實測：Chrome 桌面版把背景分頁節流到**穩定 1 Hz**（384.7 秒內 396 次 Update，
最大間隔 1601ms 且發生在啟動初期），六分半鐘內未凍結。
10 秒的 heartbeat 與 500ms 的 Relay PING **都照常送出**。
→ **AC34a（背景 30s）與 AC34b（背景 120s）應可通過**；`lobby_bg_safety_factor` 失去用途
（保留常數但標記為未使用）。
⚠ 邊界：macOS 桌面 Chrome、分頁背景化、六分半鐘。**行動瀏覽器不在此列**（OQ#10 仍有效）。 以下為原始查證項描述：：(a) **MPS session heartbeat 由誰驅動、背景分頁凍結後 session 實際存活秒數**（#23b——**排最前面，它比「能否拆分 Relay」更能否定 #23**）；(b) MPS 2.3.1 是否支援「先建 session member、按開始上班才配 Relay／建 NGO」的拆分（#23）；(c) **session 成員事件的名稱與 roster 輪詢 API**（#18 排歧表序 1 與序 3 的載體）；(d) **host-side 成員移除 API 是否存在**（#24a） | 原型：CDP 對 Lobby 中 Host 背景化 30s／120s，另一 client 加入，**並記錄失敗發生在哪一層**（transport vs 服務層）；讀 MPS API 是否可拆；列印 session 事件與 roster 查詢結果 | (a) 服務層停擺 → 以 `.jslib`／Web Worker 維持最小 keepalive，或接受 Lobby 背景上限＝實測 TTL×0.5 並走 #23 的替代設計 (b)；(b) 不可拆 → #23 的替代設計 (a)(b)(c)；(c) 事件不可得 → **改用 roster 輪詢**（序 3）；**兩者皆不可得才退化** | ⚠ **最大的一條**。影響 **AC6b（MVP-必達）**、AC6c、AC7b、AC8、AC28、AC33、AC34a/b/c、AC36、AC43b、AC52、AC53、**AC55**、#18 **序 1／序 3／序 4／序 5**（四者皆以 MPS session 層為載體）、#23、#23a、#23b、#24a、#25、#26、常數 `max_players`。**r3 的 fallback 不可行**——它會讓「Host 消失」分支永遠不可達，殺掉 AC6b。r4 已改為雙路徑（事件＋輪詢）並補上「roster 查詢是 Lobby 前提」的載體論證（見 #18）。⚠ **查證項 (d)（host-side 成員移除 API）目前無 fallback**——若不存在，AC53 死，並連帶 AC33／AC36（測試基建已標 `blocked-by: AC53`）與 AC8 互相打架，且「單向失效的永久軟鎖死」無解。**(d) 是本表唯一沒有退路的查證項，因此 P-10 排 W1 第一順位**。替代設計 (a) 成立時 **AC52 語義上必 fail**（無 teardown 可驗）；替代設計 (b) 成立時 **AC34b 的 120s 承諾被明文放棄**——兩者都是有意識的取捨，不是遺漏 | 原型 W1（**最優先**） |
| P-11 | ~~UTP 於 WebSocket 下提供可用的 Unreliable pipeline~~ **（r4 降級）** 改為量測題：節流網路下尖峰流量對心跳到達時刻的延遲分布為何，8s 判定是否仍有足夠餘裕 | 原型於節流網路量心跳到達 pattern | 延遲過大 → 逾時判定改為「連續 N 拍延遲 >X」（⚠ **r4 二次修訂更正**：先前寫「已升格為主判定」是**假陳述**——#20 的主判定全文是「連續 8 秒未收到」，GDD 內不存在任何「連續 N 拍延遲 >X」的規則。若真要改為該形式，約束①的語義、AC27 的判定區間、AC44 全部要重寫） | 無 MVP AC 直接依賴。**r4 移出 W1**——B9 證明原問題基於錯誤前提（HOL blocking 在 TCP 層、在 pipeline 之下），pipeline 選擇對到達時刻無實質差異 | 原型 W2 |
| P-12 | NGO 2.13 的 NetworkVariable／NetworkTransform 在 client 經歷 5s 無 Update 後恢復時，不會把積壓變更於單幀 burst 套用造成瞬跳；「只套用最新 milestone」可靠 | 原型：背景 5s 後恢復，逐幀 log NetworkTransform 軌跡與 `IsClaimed` 變更序列 | 會瞬跳 → NetworkVariable 層自建 coalescing（只套用最新值） | AC24、AC15 的位移判準。**fallback 可行**（自建 coalescing），非 blocking | 原型 W2 |
| P-13 | Chrome 使用者主動關閉分頁時 WebSocket close frame **可靠**送達（AC6a 的前提） | 原型：真實點 X 關分頁 20 次，量 client 偵測時刻分布 | 不可靠 → AC6a 降為 Nice-to-have，**AC6b（`session_end_worstcase_sec`）為唯一硬指標** | AC6a、`session_end_graceful_sec`、約束⑩的裸撐窗口縮短手段。**fallback 可行**（AC6b 保底），非 blocking | 原型 W1 |
| P-14 | 瀏覽器行程被強制終止（kill、OS 回收）時退化為心跳路徑且 ≤`session_end_worstcase_sec` 全員得知（AC6b） | 原型：kill Chrome 行程，量 client 偵測時刻 | 更慢 → AC6b 上限依實測放寬並回填該具名常數 | AC6b（**MVP 必達**）。fallback 是放寬數值而非取消保證，**可行**，非 blocking | 原型 W1 |
| **P-15** | `NetworkManager.Shutdown()` 在 WebGL 上**即時 flush WebSocket close frame**（#17a 的 teardown 前提） | 原型：client 呼叫 Shutdown，量 Host 收到 disconnect 的時刻分布 | 不即時 → Host 端只能靠心跳逾時發現（≤`heartbeat_timeout_sec`），AC16 上限放寬至該值 | AC16、#17a 的「即時」承諾、公式①的 `T_detect` 下界。**fallback 可行**（退回心跳路徑），非 blocking | 原型 W1 |
| **P-16** | **UTP send queue 溢位時 NGO 的實際行為**（是否真的丟訊息並報錯；佇列深度上限與可監控性） | 原型：4 人＋10 NPC 尖峰壓測，監控 send queue 深度與錯誤 log | 會靜默丟訊息 → 必須為 Host 出站每 tick 的 payload 設上限並監控佇列深度 | 無單一 AC，但影響整個同步正確性的**底層前提**（r4 新增，取代 P-11 的 W1 位置）。**這才是 WSS 單一 TCP 底下真正該防的東西**——r3 全文與 OQ 都沒有 | 原型 W2 |
| ~~P-17~~ ✅✅ **已實測回填 2026-09-13（W1 第 1 批）** | **callback 確實被呼叫、`ConnectionApproval` 未被 Sessions 覆蓋、`ConnectionData` payload 完整傳遞**（實測 `payload=w1-proto-v1`）→ **#9 的截止閘門與 AC54 的版本閘都有可用載體，先前「fallback 殺掉 AC54」的 blocking 解除**。⚠ 殘留：拒絕原因如何呈現給**遠端** client 待雙進程確認。~~原假設~~ Host 的 `ConnectionApprovalCallback` 在 Sessions API 封裝下仍可用 | 原型：以 Sessions API 建連，嘗試註冊 approval callback 並拒絕一個 client，觀察 client 端收到什麼 | 不可用 → 截止判定改由 Host 於 NGO 連線建立**後**立即踢出並附原因（體驗較差，玩家會閃一下才被退），版本閘同理 | AC5、AC35、AC54、#9 的「唯一執行點」。另影響 **AC51**、Lobby\* 的進入條件、#9 的版本閘、UI 翻譯表兩列、常數 `late_join_cutoff_sec`。⚠ **fallback 不可行，本項為 blocking（r4 二次修訂）**：fallback 是「連線建立**後**立即踢出」，但 **AC54（MVP-必達）** 的 THEN 明寫「不得靜默進入造成 desync」——fallback 下 client **一定先建立 NGO 連線**才被踢，在那個窗口內舊 build 已開始收發 NetworkVariable／RPC，**正是版本閘要防的事**；若序列化格式不相容，連線建立本身就可能讓 Host 收到畸形封包。**版本閘的全部意義是「在任何資料交換之前」擋下**，fallback 在語義上做不到。另 AC5／AC35 的 THEN 與取樣點須連帶改寫（AC35 的 0.5s 級鑑別會被連線建立的抖動侵蝕）。**查證成本近乎為零——與 P-10(b) 是同一次原型操作**，不應排在最後一批 | **原型 W1（與 P-10 同批）** |
| **P-18** | `beforeunload` 可從 WebGL build 經 `.jslib` 觸發確認框；`sendBeacon`／`keepalive` 語義的離開通知可在 unload 時送達 | 原型：Release build 實測關分頁攔阻與離開通知到達率 | 攔不住 → #12 已明寫 best-effort，維持現狀；beacon 送不出 → 離開通知退回心跳路徑 | AC42、**AC6c**、**#25**（Lobby 的唯一偵測來源）、#12 的攔阻與離開通知。⚠ **fallback 在 Lobby 情境不成立（r4 二次修訂）**：fallback 寫「beacon 送不出 → 離開通知退回心跳路徑」，但 **Lobby 依 #20／#23 根本不跑心跳**——實際退路只剩 MPS 服務端 TTL（#23b 推測數十秒量級），於是 #25 自述的「留在 Lobby 的人會盯著一個說謊的 roster 數十秒，穩定觸發支柱 5」原封不動復活。**AC42 的桌面攔阻部分 fallback 仍可行**（best-effort 已明示），但 **AC6c 的離開通知部分不可行**。查證併入 P-7 的同一次 Release build（**因此應與 P-7 同批，而非排最後**） | **原型 W1（與 P-7 同批）** |
| ~~P-19~~ 🔴 **已實測回填 2026-09-13：iframe 情境為假** | **本地（非 iframe）實測 `clipboard result = OK`**——Clipboard API 在 Release Web build ＋ user gesture 下可用。🔴 **itch.io 的 iframe `allow` 屬性實測沒有 `clipboard-write`**：<br>`autoplay; fullscreen *; geolocation; microphone; camera; midi; monetization; xr-spatial-tracking; gamepad; gyroscope; accelerometer; xr; cross-origin-isolated; web-share`<br>→ **Clipboard API 在 itch.io 上會被 permissions policy 擋掉，#23 的「複製邀請連結」必須走 fallback**（顯示可全選的連結文字框＋提示手動複製）。本地非 iframe 情境仍為 `OK`，故此限制**專屬於 iframe 部署平台** | 與 P-4／P-6 同一次 itch.io 部署實測 | 不可用 → 「複製邀請連結」退化為「顯示可全選的連結文字框」＋提示手動複製 | #23 的**必做配套**（複製邀請連結按鈕）——而該按鈕是 #23 替代設計 (c) 的核心，也是降低 Host 切分頁必要性的唯一不依賴引擎行為的手段。**fallback 可行但削弱 #23 的保護** | 原型 W1 |
| ~~P-20~~ ✅✅✅ **(a)(b) 皆已回填並實機驗證完畢 —— 本項結案**（(a) 2026-09-13 第 0 批；(b) 2026-09-16 第 4 批雙進程實測） | **(a)** `NetworkObject.DontDestroyWithOwner` 是 **public bool field，預設 `false`＝預設銷毀**，Inspector 可勾選；**銷毀發生在 `OnClientDisconnectCallback` 之前、同一 call stack** → #24 的前置條件已補（原序列第 2 步隱含「物件還在」的假設為假）。⚠ `RemoveOwnership()` **不做 unparent**，「掉落在原地」須自行實作。⚠ 版本陷阱：2.4.0 前該欄位是壞的，2.13.2 已修，網路上 2025 上半年討論不可信。**(b)** `ChangeOwnership(ulong)` 在 client-server **同步原子、無 pending 窗口** → **#6 的「單一真相時刻」定義成立**；但回傳 void 失敗靜默（須回讀 `OwnerClientId`）、只有 server 能發起；`OwnershipStatus` 那套**只在 DA 有效**。<br>🟢 **(b) 已於 2026-09-16 完成雙進程實機掃描，並推翻「需隔 6 tick」的描述**：<br>① **引擎並不「要求」間隔**。`k_MaximumTickOwnershipChangeMultiplier = 6` 只出現在 `NetworkSpawnManager` 的**一則警告**裡，且被 `LogLevel == Developer` 擋著，**不延遲也不阻擋任何交接**。<br>② **交接本身約 100ms，且不受 tick 影響**：實測 handoff（交接傳播＋寫入＋回報，一個往返量級）tick=10 為 100-104ms、tick=1 為 101-105ms —— 與同 region 實測 RTT（median 88.8、max 104.4ms）同量級。**「10Hz → 600ms 可感知交接延遲」的推論為假。**<br>③ **真正存在的是 NetworkVariable 的遺失窗口，且它 ≈ 一個 tick 週期**（非 6 個）。掃描「client 寫入後、所有權被收回前」的等待時間，各 3 次：<br>｜delay ms｜0｜40｜80｜120｜160｜240｜400｜700｜<br>｜**tick=10**｜0/3｜1/3｜**3/3**｜3/3｜3/3｜3/3｜3/3｜3/3｜<br>｜**tick=1**｜0/3｜0/3｜0/3｜0/3｜1/3｜1/3｜1/3｜2/3｜<br>存活率近乎 `delay ÷ tick 週期`（10Hz@40ms→40%→1/3；1Hz@700ms→70%→2/3），正是「寫入落在 tick 週期內的隨機相位」該有的分布。機制：送出端在**下一個 tick 序列化時**才評估 `CanWrite()`（`NetworkVariableDeltaMessage`），屆時若已非 owner 則該筆 delta 不再送出。<br>④ 🔴 **後果比原設計假設的嚴重**：伺服器端收到越權 delta 時記錄 `Client wrote to NetworkVariable without permission. **No more variables can be read. This is critical.**` —— 它**中止解析該訊息的其餘部分**，故**同一物件上其他無關的 NetworkVariable 也會一起掉**，不是只掉那一筆。這使約束⑧「互動結果一律走 RPC，不得以 NetworkVariable 承載」從**效能考量升格為正確性要求**。<br>→ **OQ#17 因此消解**，見該條 | 查 NGO 2.13 API＋原型：owner 斷線後觀察其 owned NetworkObject 是否被銷毀 | 預設為銷毀 → **顯式設定為不隨 owner 銷毀**（NGO 約定段已要求，本來就要做） | **拆兩半（r4 二次修訂）**：**(a) `DontDestroyWithOwner` 名稱與預設值**＝AC10、#24 步驟 2。修法（顯式設定）無論預設為何都安全 → **非 blocking**；且這是**查 API 文件**而非原型項，應排第 0 批。⚠ 註：NGO 約定段給的兩條路中，「Host 在掉落前先收回 ownership」**在時序上脆弱**（斷線不可預測，若銷毀發生在 `OnClientDisconnectCallback` 之前或同幀則來不及），真正安全的只有顯式設定那一條。**(b) ownership transfer 在 NGO 2.x 的 API 與限制**＝**#6 的「單一真相時刻」與 AC14（MVP）**——若 transfer 是非同步、存在 pending 窗口，則「Host 提交的那一刻」不存在，AC14 的二分無法成立。~~**(b) 目前無 fallback**~~ → **(b) 已結案：`ChangeOwnership` 同步原子且約 100ms，#6 的「單一真相時刻」與 AC14 皆成立，不需要 fallback。**唯一的實作要求是 **攜帶物的狀態不得放在 owner-write NetworkVariable**（約束⑧已涵蓋）。 | 原型 W1 ✅ 已完成 |

## Open Questions

（引擎/平台假設見上方 Provisional Assumptions 表；此處只列尚未有答案的設計問題。）

| # | 問題 | 解決方式 | 目標時點 |
|---|---|---|---|
| 1 | Relay WSS 真實 RTT 與尖峰行為（雙瀏覽器實測）？ | 原型量測（AC22/23 的前置） | 原型 W1 |
| 2 | 4 人＋10 NPC 尖峰下 RPC 佇列是否收斂？ | 原型壓力腳本 | 原型 W2 |
| 3 | WebGL 下 NGO 序列化緩衝的記憶體足跡（512MB heap 內佔比）？單執行緒下 NGO 訊息處理佔 16.6ms 幀預算比例？ | 原型量測 | 原型 W2 |
| 4 | 單人練習模式是否完全離線（不初始化 UGS）？ | 波次導演 GDD＋ADR | /create-architecture |
| 5 | 暱稱持久化：iframe 下 PlayerPrefs 可能被儲存分割清空（Safari ITP），是否接受每次重置？ | UX 決策 | /ux-design |
| 6 | Web build 是否永久維持單執行緒（itch.io 無 COOP/COEP 表頭）？ | ADR 寫死 | /create-architecture |
| 7 | 撲空是否會系統性懲罰高延遲玩家（每次搶站都輸）？ | playtest 觀察，必要時調 claim 規則 | 原型後 playtest |
| 8 | **冷啟動客製 Web Template 的視覺**：可行性已定案（Unity 穩定功能，MVP 交付物），待出「鐵門緩緩升起／日光燈逐盞亮起」等世界語言等待畫面的視覺稿 | /ux-design | Pre-Production Phase 4 |
| 9 | **Host 獨留（N=1）超過寬限期後的波次密度與耐心曲線**：單人身兼所有站台的長時段體驗未經 playtest，本 GDD 只提供 `host_solo` 旗標與「提前收班」出口 | 波次導演 GDD＋playtest | /design-system 波次導演 |
| 10 | 行動瀏覽器 InShift 期間切訊息 App 的背景回收比桌機激進，5s 閾值幾乎必中——是否為行動端另設閾值或接受「行動端為次要目標」？ | 原型於 iOS Safari／Android Chrome 實測後決定 | 原型 W2 |
| 11 | `NetworkPrefabsList` 與專案 Addressables 規範如何共存（runtime `AddNetworkPrefab` 順序）？ | web-platform ADR | /create-architecture |
| 12 | **頻寬預算與 relevancy／priority 規則**：全文無任何頻寬上限或 relevancy 規則。粗估 4 人 × 10Hz NetworkTransform ＋ 10 NPC × 5 events/s，經 client-as-host 星狀轉發，Host 上行約 15-25 KB/s、每場 1 小時約 60-90MB 經過 Relay——對 3GiB/CCU 的免費額度**綽綽有餘**（結論是不必擔心成本，但這個結論應該被寫下來而不是靠沒人問）。真正該定的是 Host 上行的**上限**與 send queue 深度監控門檻 | 原型量測（與 `[P-16]` 同一次）＋ web-platform ADR | 原型 W2 |
| 13 | **行動瀏覽器的 WebGL context loss**：iOS Safari 切 App 回來可能是 `webglcontextlost`——畫布死亡，**這不是「背景 >5s」可以涵蓋的分支**（沒有可恢復的 client 可以 teardown）。是否加規則「偵測到 context loss → 視同離開 session → 引導重新整理頁面」？ | 原型於 iOS Safari 實測（與 OQ#10 併問） | 原型 W2 |
| 14 | **`settlement_timeout_sec` = 20s 是否打斷 Fellowship**：concept 把「結算檢討直接變成『剛剛那波我們應該…』的重開動力」列為 Short-Term Loop 的核心，而 Fellowship 是第一優先 aesthetic。20s 對認真檢討的朋友團可能太短，尤其首次遇到細項清單。tuning 範圍 10-60 已留夠彈性，但**預設值的依據看不出對齊過 concept** | playtest 時特別驗證「是否打斷檢討」，不只驗「有沒有自動推進」 | 原型後 playtest |
| ~~20~~ ✅ **已裁決 2026-09-15（arlong：「讓國外的人也可以參與」）** | **Relay region 要怎麼選？**（W1 第 4 批實測後提出）。原本的三選一（寫死東亞／Host 端量測／依時區推測）在裁決後**變成不是三選一**：既然不能犧牲海外玩家，就不能寫死任一大區。<br>**裁決後的解法（Core Rule #28）**：relay **貼著 Host** 選，由時區查表決定、可覆寫。這條之所以成立而非折衷，是因為它可證明——`RTT_i = 2 × (d(i,R) + d(R,H))`，由三角不等式，`R = H` 讓**每個 client 同時**拿到各自的理論下限，移向任一 client 只會讓其他人變差。**沒有人因此變差，所以沒有取捨要做。**<br>原本擔心的「Host 端量測會吃掉 `T_load` 預算」也隨之消失：查時區是本地的、零延遲。<br>殘留代價已如實記錄於 AC22a：跨洲裸往返 217–306ms，**能玩但壓在 300ms 邊緣**，故跨區改以降級契約（慢但正確、有回饋、不卡死）承接，而非硬綁一條注定失敗的 300ms。 | technical-director ＋ arlong | ✅ 已結案，產出 #28／⑮／AC22a／AC22b ＋ 兩張 registry 對照表 |
| 21 | **`build_size ≤50MB` 的專案硬標要不要下修到約 28MB？**（W1 第 4 批實測後新增；**原本掛的前置複驗已於 2026-09-17 完成，結論未被推翻**）。公式⑤ 先前缺一整項：`decompressionFallback = true`（第 2 批為繞過 itch.io 不支援 Brotli 而定的**強制**設定）帶來一筆與頻寬無關的 CPU 成本。實測 7MB build 的 JS 解壓約 **2.0-2.2 s**（16.3 MB/s，比原生 C 慢約 23 倍）；線性外推到 50MB 約 **15 s**，代入修正後的公式得 `T_load ≈ 40.4 s`，**AC7a 的 ≤25s 破，支柱 4「開連結就開玩」不成立**。求解得有效天花板約 **28 MB**。<br>✅ **原列為「最可能翻案、必須先做」的 (a) 已完成**：以自寫限速伺服器測 20 Mbps 與 5 Mbps。下載窗口從 0.03 s 拉到 9.35 s（**300 倍**），而「資料在手後的 CPU」維持在 2.5-3.2 s **不動** —— **解壓不與下載重疊，相加模型成立，40.4 s 不是高估。**<br>**因此本項已無技術前置，純粹是產品取捨，請 arlong 在三條路裡選**：<br>(b) **下修 build 硬標至約 28 MB**——最直接，但把內容預算從 43 MB 砍到約 21 MB（扣掉 7 MB 地板），砍掉一半。<br>(c) **改回 `decompressionFallback = false` 並換一個支援 Brotli 的主機**（itch.io 之外）——T_load 的 CPU 項幾乎歸零（實測對照組僅 0.33-0.41 s），但放棄 itch.io 會牽動發行通路，屬產品決策。<br>(d) **接受較長的 T_load**，改寫 AC7a 與 `load_stall_timeout_sec` 的預期值——但那等於承認支柱 4 的「開連結就開玩」要打折。<br>⚠ 剩餘量測邊界：8 核桌機（樂觀硬體）、7MB build 線性外推未驗證。低階裝置只會更慢。 | technical-director ＋ arlong（跨 technical-preferences 權責） | **技術前置已完成，等裁決** |
| 15 | **更衣室 3-5s 對重連者是否為無回報的時間稅**：`#10` 的「推門進店的動作節奏」理由只對**第一次**進店成立。對一個 6 秒前才掉線、系統把他當全新員工對待的玩家，這 3-5s 是純等待。是否在**演出上**區隔（維持定長，但改為「回到崗位」而非「新人報到」）？ | game-designer ＋ `/ux-design` | Pre-Production Phase 4 |
| 19 | **Lobby 階段「Host 被強制終止」的 132 秒偵測延遲，要怎麼對玩家呈現？**（W1 第 1 批實測後新增）。實測已把問題縮小：**優雅離開只要 1.14 秒**（`Deleted` 事件），**只有強制終止／當機才是 132.61 秒**。因此方向已明確——**#12 的 `beforeunload` ＋ 主動 `DeleteAsync()` 升格為關鍵機制**，覆蓋最常見的關分頁情境。**剩下的裁決只有一個：那條罕見的 132 秒路徑要怎麼呈現？** 選項：✅ **arlong 已裁決（2026-09-13）：採本地逾時提示**——Lobby 自最後一次 session 事件起計時，超過 `lobby_host_silence_timeout_sec`（30s）即顯示店語提示＋可離開按鈕，**不等服務端**。新增常數 `lobby_host_silence_timeout_sec`。文案歸 `/ux-design`。註：host migration（OQ#18）**解決不了這個延遲**——瓶頸是服務端判定 host 消失的時間，migration 只改變判定之後做什麼 | 已裁決 | 已納入 #25 |
| 18 | **MVP 是否仍要維持「無 host migration」？**（W1 第 1 批發現後新增）。GDD 從 r1 起就把「房主關分頁＝本局結束」當成 MVP 的既定限制，#12 的 UI 也對玩家明示。但 MPS 2.3.1 的 API 顯示 **host migration 是一等公民**：`IHostSession.GetHostMigrationDataAsync`／`SetHostMigrationDataAsync`、`IHostSession.Host` 可指派、`ISession.SessionMigrated` 事件、`NetworkState.Migrating` 狀態、`IClientSessionNetwork.MigrationFailed` 事件。也就是說「無 migration」是**選擇**而非引擎限制。是否至少列入 Post-MVP？（影響 #12、#21、AC6b、AC13b、UI 翻譯表的「店長把鐵門拉下來了」整條敘事，以及 Relay 情境 B 的 10s 回收問題） | creative-director 裁決 ＋ 實機評估遷移成本 | 原型 W1 後 |
| ~~17~~ ✅ **已消解 2026-09-16（W1 第 4 批雙進程實測，非裁決）** | **`network_tick_rate` 的第三個考量：交接冷卻**（W1 第 0 批查證後提出）。原文為「引擎要求兩次 ownership 變更間隔 ≥6 個 network tick，10Hz → **600ms**，對 Overcooked-like 的快節奏合作是**可感知的**交接延遲」。**兩個前提都不成立**：<br>① **引擎沒有「要求」**。那個 `6` 只存在於 `NetworkSpawnManager` 的一則警告字串裡，且被 `LogLevel == Developer` 擋著，**不延遲也不阻擋任何交接**。<br>② **交接本身約 100ms 且不受 tick 影響**（tick=10 量得 100-104ms、tick=1 量得 101-105ms，與同 region RTT 同量級）。**沒有 600ms 這回事**，`network_tick_rate = 10` 不因交接而受威脅。<br>真正存在的是**另一件事**：owner-write NetworkVariable 的遺失窗口 ≈ **一個** tick 週期（10Hz 下 ~100ms，實測門檻落在 40-80ms 之間；1Hz 下連 700ms 都仍在掉）。而它**只影響 owner-write NetworkVariable**，約束⑧ 早已規定互動結果一律走 RPC —— 只要攜帶物的狀態不放在 owner-write NetworkVariable，本項風險完全不存在。<br>⚠ 但該實測也讓約束⑧ 的地位改變：越權 delta 會讓伺服器**中止解析整則訊息的其餘部分**（`No more variables can be read. This is critical.`），故約束⑧ 從效能考量**升格為正確性要求**。詳見 `[P-20]`(b)。 | 實測取代裁決，無需 arlong 介入 | ✅ 已結案，產出見 [P-20](b) 與約束⑧ |
| 16 | **Host 獨留長時間續戰時是否主動引導補位**：#21 給了「提前收班」出口，但沒有「開放補位」的引導（例如提示 Host 再貼一次連結）。若班次才過 1/4 隊友就全掛，Host 要撐 6 分鐘以上 | 波次導演 GDD ＋ playtest（與 OQ#9 併問） | 原型後 playtest |

**已解決（首次修訂）**：更衣室過場約束定案（Core Rules #10，**僅 mid-join**；視覺歸
/ux-design）；MVP 分層裁決（AC 層級欄）；背景節流分流（公式③）；留守者降載
（Core Rules #14-16）。
**已解決（複審修訂 r2）**：心跳定義（#20、公式①、Tuning Knobs）；Host 背景局終機制
（#18）；公式③倍速改正（1+drift/2）；狀態真相 NetworkVariable＋全動態 spawn；公式⑤
冷啟動誠實化；MVP slot 立即釋放（#11、States）；Onboarding 斷線；寬限期不疊加；
P-5 測法改跨 channel；P-7～P-9 新增。
**已解決（第四輪修訂 r4，2026-09-13）**：
**第四張結構表「[P] → 影響對照」**（META-I1，B4/B6/B12 的共同根因）＋兩張機械檢查
（AC 時間算術可達性、常數↔AC **雙向**對照）納入修訂協定；
**#18 排歧表改寫**（訊號三的語義錯誤；改為 MPS session 成員事件推播＋roster 輪詢
**兩條獨立路徑**，使「Host 消失」分支在 fallback 下仍可達，救回 AC6b）；
**#24／#24a 斷線處置原子序列**（含 avatar despawn、MPS 名額釋放、`DontDestroyWithOwner`
顯式設定）；**#17a teardown 不變式**＋**心跳雙向存活確認**（單向失效的永久軟鎖死）；
**#9 截止閘門移至 `ConnectionApprovalCallback`** ＋ build/protocol 版本閘；
**#20 刪除 Unreliable／HOL 的錯誤立論**、心跳範圍改為「NGO 連線存在期間」、
payload 合併三用途並刪除 60s resync 通道；
**`shift_end_ts` 為班次時鐘真相**＋`shift_length_sec` 登錄＋offset 協定；
**#23 降級為高風險架構假設**＋完整替代設計，**#23a 局間 teardown**、**#23b 服務層 liveness**；
**#25 Lobby 的 Host 離開偵測**、**#26 「開始上班」轉場**、**#27 冷啟動 stall**；
**#15a 重複離線抑制**（arlong 裁決）、**Lobby\* 狀態＋單人練習沙盒出口**（arlong 裁決）；
**`end_shift_early` 統一為一顆按鈕**＋N>1 時二次確認；
Tuning Knobs 全面修訂（range 與約束一致化、新增 15 個常數列）、**約束區塊 7→11 條**；
AC 修訂 16 條不閉合＋拆分 5 條＋新增 AC44-54；`[P]` 14→20 條並全部補「影響」欄；
OQ 新增 #12-#16。
**已解決（第三輪修訂 r3）**：三張結構表（適用性矩陣、常數三欄、旋鈕約束）；#17/#18/#20
限定 InShift＋Lobby 延後建連（#23、P-10）；Host 消失 vs 自己斷線排歧表（#18）；client
主動 teardown；心跳 Unreliable pipeline（P-11）；班次時鐘＝wall-clock 真相、模擬不快轉、
catch-up 暫緩 resync；Host 獨留續戰＋提前收班（#21、AC13a/b）；寬限期 rejoin 即結束
（#15、AC36）；Onboarding × Host 消失轉移；交接完成＝Host 提交（#6）；`ClaimGeneration`
入 NetworkVariable struct；等待畫面分域鐵律＋客製 Web Template 列 MVP；UI 翻譯表層級欄
＋MVP 文案真值；更衣室 runtime 規則＋3s 理由；預算 45s＋AC7a 分段；AC6a/6b＋P-13/P-14；
P-7 Stripping；輸碼字集規則；beforeunload；AC34-43 新增。
