# Review Log — netcode-session.md

## Review — 2026-09-05 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, network-programmer, qa-lead, unity-specialist + creative-director (senior)
Blocking items: 14 | Recommended: 6
Summary: 架構判斷紮實（host 權威、事件制 NPC、店語翻譯表精準服務支柱），但兩類系統性問題：
(1) 未驗證引擎行為與已定案規則混寫（slot 恢復、10Hz tick、?code= 轉發、節流偵測）需 [P] 分層
標記＋fallback 表；(2) 支柱 5 在斷線情境只保護斷線者、未保護留守者（2 人房無降載）。另有
Fantasy 秒數自我矛盾、MVP 範圍與 concept 矛盾（CD 裁決：基本保障=MVP、30s 恢復=Post-MVP）、
QA 判準缺數值等。CD-GDD-ALIGN: CONCERNS。
Prior verdict resolved: First review

## Review — 2026-09-05 (r2, 複審) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, network-programmer, unity-specialist, qa-lead, ux-designer + creative-director (senior)
Blocking items: 7 | Recommended: 7
Summary: 首審修訂為真修（留守者降載、[P] 表、AC 18→26、更衣室區間），架構主幹不需重寫；但同一病灶換位置
復發：規則依賴未定義變數（心跳逾時全文無值）、MVP 標籤未掃全（AC8 4 人標 MVP）、未驗證引擎前提當事實
（visibilitychange 需 .jslib、scene-placed 不同步遲加入者）。另公式③倍速算錯（應 1+drift/2）、Host 背景
「誰偵測誰通知」矛盾、公式⑤把冷啟動讀取條誤標已解。CD 要求掃描式修訂。CD-GDD-ALIGN: CONCERNS。
Disagreements: systems-designer 判 MAJOR（CD 裁 NEEDS：缺常數與表列，非取向錯）；ux-designer 認為更衣室
越界寫畫面（CD 裁：約束留 GDD、視覺交 /ux-design）；P-5 測法應改跨 channel（unity-specialist，CD 採納）。
Prior verdict resolved: Yes（14/14 已處理；本輪 7 項為新發現）
Revision applied same session (r2): 7/7 blocking fixed — Rule #20 心跳 2s/8s；#18 client 端偵測；公式③改正＋AC29；
NetworkVariable＋全動態 spawn＋AC32；公式⑤拆 (a)/(b)＋OQ#8；AC8 tier＋MVP slot 立即釋放＋AC33；Onboarding 斷線、
寬限不疊加（AC31）、Lobby 斷線 AC30、P-5 改寫、P-7～P-9 新增。Registry +heartbeat_interval_sec/heartbeat_timeout_sec。
Next: 第三輪 /design-review（新 session）。

## Review — 2026-09-06 (r3, 第三輪複審) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, network-programmer, unity-specialist, qa-lead, ux-designer + creative-director (senior)
Blocking items: 24（含 3 項結構前置） | Recommended: 21
Summary: r2 的 7 項全部確認已修、公式③數學全員複核通過；本輪 blocking 皆為新發現。支柱層級三個洞：
(1) #17/#18/#20 未限定 InShift，Host 在 Lobby 切分頁貼連結（最常見開局）會被自己的規則殺房；(2) client 無法區分
「Host 消失」與「自己斷線」，同一訊號被要求對應兩種矛盾輸出；(3) 留守者保護可被「退出→立刻重連」無限刷寬限期。
另：進度條鐵律與公式⑤(b) 三輪自我否定、班次時鐘是否為模擬真相從未裁決、Host 獨留無規則、UI 翻譯表描述 Post-MVP
行為、T_load 預算與 20Mbps 測試基準算不平、AC6 依賴未標 [P] 的 close frame 假設、settlement 逾時全文無值。
CD 診斷：三輪 blocking 只有四類（規則未限定範圍／依賴未定義常數／層級未掃全／未驗證前提當事實），清單式修訂
只修被點名的實例——要求改為掃描式修訂，先建三張結構表再動條文。CD-GDD-ALIGN: CONCERNS。
Disagreements: systems-designer + ux-designer 判 MAJOR（CD 裁 NEEDS：每項可一到三行定案，架構不需重寫）；進度條鐵律
ux 主張改文字 vs game-designer 主張只加限定（CD 裁改文字＋客製 loader 列 MVP）；Host 獨留 game-designer 續戰 vs
network-programmer 認為是設計選擇（CD 裁續戰＋提前收班）；M4 systems-designer 認為大半已解（CD 裁核心裁決未做）；
更衣室 3s 下限 ux 質疑理由 vs game-designer 動態下限（CD 裁理由改為情緒節拍、保留定長、否決動態）。
Prior verdict resolved: Yes（r2 7/7 已處理；本輪 24 項為新發現）
Revision applied same session (r3): 24/24 blocking fixed — 三張結構表（適用性矩陣 23×9、常數三欄、旋鈕約束 7 條）；
#17/#18/#20 限 InShift＋新 #23 Lobby 延後建連 [P-10]＋複製連結按鈕；#18 三訊號排歧表＋誠實預設分支；client 主動
teardown；心跳 Unreliable [P-11]；班次時鐘＝wall-clock 真相、模擬不快轉、catch-up 暫緩 resync；新 #21 Host 獨留續戰＋
提前收班（AC13a/b）；#15 寬限期 rejoin 即結束（AC36）；Onboarding×Host 消失；#6 交接完成＝Host 提交；ClaimGeneration
入 NetworkVariable struct；等待畫面分域鐵律＋客製 Web Template 列 MVP（AC41）；UI 翻譯表層級欄＋MVP 文案；#10 更衣室
runtime＋3s 理由；預算 25/10/10=45s＋AC7a；AC6a/6b [P-13/P-14]；P-7 Stripping [Preserve]；#8 輸碼字集；#12 beforeunload；
AC34-43 新增（AC 33→45 條）；P-10～P-14 新增；OQ#9-11。Registry +patience_mult/+background_disconnect_threshold_sec/
+settlement_timeout_sec，max_players MVP 註記，join budget 35→45。
User decisions (r3): 同意鐵律改寫＋loader 列 MVP；同意 Host 獨留續戰＋提前收班；同意 Lobby 延後建連為預設；settlement 20s。
Next: 新 session /clear 後 /design-review design/gdd/netcode-session.md（r4）；原型 W1 優先序 P-4 → P-10 → P-7 → P-13/14 → P-9/11。

## Review — 2026-09-13 (r4, 第四輪複審) — Verdict: NEEDS REVISION → 同 session 修訂完成
Scope signal: L
Specialists: game-designer, network-programmer, systems-designer, qa-lead, ux-designer + creative-director (senior)
＋ 4 位獨立對抗驗證者（逐項嘗試反駁每個 blocking，須引用條文才能 REFUTE）
＋ 2 張機械檢查（AC 時間算術可達性、常數↔AC 雙向對照）
＋ 主審自行補的 Unity 引擎交叉檢查（unity-specialist 三度因 API 用量上限中斷；依
  docs/engine-reference/unity/ 逐項核對，結果存 scratchpad/r4-unity-crosscheck.md）
Blocking items: 17 組（CD 綜合後） | Recommended: 未計數 | 機械檢查另抓 16 條不閉合 AC、12 項約束矛盾、19 項未登錄常數

Summary: r3 的掃描式修訂確實奏效——三張結構表都建了，架構四輪未被動搖。但 CD 診斷出第 2 類病灶
（依賴未定義常數）發生**變異**：從「常數不存在」變成「常數宣稱自己被驗證了，但沒有」——三欄表的
存在製造了覆蓋的假象（heartbeat_interval 標 AC27 驗收，但 AC27 只驗 8s 逾時；「時鐘 1s」標 AC23/AC25，
兩條都與時鐘無關）。
CD 的更根本診斷：把 17 組依「什麼工具才能回答」重分類，得到比「四類病灶」更有解釋力的切法——
(甲) 只有原型能回答的引擎事實，佔確認項四成；(乙) 文件用自己登錄的常數就能算出矛盾卻從沒人算的
算術，4 條；(丙) 真正的設計未裁決，只剩 5 項。
**全輪第一順位 B4**：#18 排歧表的訊號三被誤述為「雲端側對 Host member 的觀察」，而引擎文件對
`session.Network.State` 只有一句「連線狀態」。且該假設的 fallback（退化為兩訊號）會讓「Host 消失」
分支**永遠不可達**，直接殺掉 AC6b（文件自標「保底路徑，必達」）與 AC28——**全輪唯一一項
fallback 自己不成立**的假設。
CD-GDD-ALIGN: CONCERNS（性質已改變：r2/r3 是支柱層級的結構性空洞，r4 是已正確系統的邊界路徑漏洞）。
支柱 2、3 PASS；支柱 1、4、5 CONCERNS，違規全在邊界路徑，每條都有 1-3 行修法。

Disagreements（CD 逐項裁決，未靜默選邊）: 共 8 組。
[1] systems-designer 的「波次永久降載」加強版被驗證者引公式④原文駁回，CD 判「攻擊目標對、加強過頭」，
    game-designer 的原始弱化版存活並升為需 arlong 裁決。
[2] U8 驗證者主張「班次長度不 blocking」，CD 推翻驗證者站 SD7/B8——#21 與 States 表都寫「到 08:00」，
    要知道 08:00 何時到達必須有結束時戳；且純加法表達不了提前收班。
[5] ux-designer 曾用「重連要重載 25s」當作 G1 不嚴重的制衡理由，驗證者推翻該前提，
    CD 指出這同時拆掉了減罪理由，G1 因此比原判更嚴重。
[6] SD1 的心跳旋鈕反例被驗證者 REFUTE（把 interval=4 當預設，實際預設是 2），CD 採信，降為 nice-to-have。
[8] S10 的命名統一 vs N1 的保留兩個概念，CD 判給 N1——session_member_count 與 online_player_count
    在斷線期間本來就該不相等，硬統一會把 bug 焊死進命名。

**CD 的流程裁定（比 verdict 本身更重要）**：**r4 是最後一輪散文式評審。** 修訂完成後不再開 r5
六專家複審，改為 (1) 重跑機械檢查、(2) 直接開 W1 原型。原型回填走「回填 diff 複核」。
理由：四輪的 blocking 都長在上一輪修補的縫隙裡，且約四成確認項是對一個沒人跑過的系統的斷言
——散文評審沒有可以反駁它們的儀器。

User decisions (r4，arlong 三項裁決):
1. Settlement 期間加入者的支柱 5 出口 → **開放既有的單人練習沙盒**（復用必須存在的模式，不新增系統）
2. 留守者保護防濫用 → **同一玩家同一班次內第 2 次起的離線仍即時降載，但不再觸發寬限期**
   （保住保護本體，拿掉可重複刷的部分）
3. 修訂時機 → 現在就修（同 session 完成）

Prior verdict resolved: Yes（r3 的 24 項已於 r3 處理完畢；r4 的 17 組為新發現，其中 4 成是
先前被當成事實的未驗證引擎斷言）

Revision applied same session (r4): 698 行 → 1224 行；registry 常數 13 → 34。
- **新增 8 條 Core Rule**：#15a 重複離線抑制、#17a teardown 不變式、#23a 局間 teardown、
  #23b MPS 服務層 liveness、#24 Host 斷線處置原子序列（7 步，含 avatar despawn）、
  #24a MPS 成員唯一寫入者、#25 Lobby 的 Host 離開偵測、#26「開始上班」轉場、#27 冷啟動 stall
- **#18 排歧表改寫**：訊號三改為「MPS session 成員事件推播（序1）＋ roster 輪詢（序3）」
  **兩條獨立路徑**，使「Host 消失」分支在 fallback 下仍可達（救回 AC6b）；
  `navigator.onLine` 降為僅作快速否定
- **#20 刪除錯誤立論**：Unreliable pipeline 避開 HOL blocking 在 WebSocket 上不成立
  （HOL 在 TCP 層、在 pipeline 之下）；心跳範圍改為「NGO 連線存在期間」（含 Onboarding／Settlement）；
  payload 改 {seq, last_peer_seq_seen, host_shift_end_ts} 一包三用，刪除 60s resync 獨立通道
- **#9 截止閘門**移至 Host 的 ConnectionApprovalCallback（server-authoritative）＋build/protocol 版本閘
- **班次時鐘真相**改為 Host 權威 `shift_end_ts`（提前收班直接改寫它）＋offset 掛心跳；
  `shift_length_sec` 登錄（先前被 7 處依賴卻不存在）
- **#23 降級**為「高風險架構假設」＋補完整替代設計（引擎文件的 Sessions API 形狀與延後建連直接衝突）
- **States 表**新增 Booting／LoadFailed／Lobby*（前一班進行中）；刪孤兒名詞「Lobby 倒數」
- **適用性矩陣**擴為 30 列 × 11 欄
- **Tuning Knobs 全面修訂**：安全範圍改為**公式而非固定區間**（heartbeat_timeout = k × interval 且
  > threshold + interval；grace_window 下界隨 timeout 浮動），新增 15 個常數列
- **約束區塊 7 → 11 條**：新增 ⑧ tick×RTT ≤ interact_rtt、⑨ npc_catchup ≤ npc_interval、
  ⑩ grace ≥ heartbeat_timeout、⑪ threshold ≤ 5；④ 補上漏計的 T_detect
- **AC 46 → 57 條**：16 條不閉合全修、5 條拆分（6c／7b／13c／28a／34b/34c／37a/37b／42a／43a/b/c）、
  新增 AC44-54；新增 5 條 AC 撰寫規則防同類復發
- **[P] 14 → 20 條**，全部補「影響」欄（META-I1）；新增 P-15 Shutdown flush、P-16 send queue 溢位、
  P-17 approval callback、P-18 sendBeacon、P-19 clipboard、P-20 DontDestroyWithOwner
- **原型 W1 優先序重排**：P-10（升第一，一次回答四項 blocking）→ P-4/P-6/P-19（同一次 itch.io 部署）
  → P-7 → P-3 ＋ OQ#1（與 AC22 聯測）→ P-13/P-14/P-15 → P-9/P-16 → P-17/P-18/P-20。
  **P-11 移出 W1**（它問的是基於錯誤前提的問題）。P-4 讓位理由：它的 fallback 是全表最健康的一條。
- **OQ 新增 #12-#16**：頻寬預算與 relevancy、WebGL context loss、settlement 20s vs Fellowship、
  更衣室對重連者的時間稅、Host 獨留補位引導
- **registry 同步**：新增 15 個常數，6 個既有常數的 range 與約束一致化

約束驗算證據（修訂後預設值實跑）：11 條中 9 條 PASS、2 條待原型（[P-9]）、
1 條（⑧ tick）在 P-3 為「全域 tick」時 FAIL——**這正是設計意圖**，讓問題在回填當下自己跳出來。

Next: 重跑三張機械檢查（AC 時間算術、常數雙向、[P]→影響）驗證修訂未製造新的不閉合 →
**直接開 W1 原型**，不開 r5。

### r4 二次修訂（同日，機械檢查複驗後）

三張機械檢查對修訂後的 1224 行重跑，**抓到的比六位專家加起來還多，也抓到修訂本身的殘留與新洞**：

| 檢查 | 結果 |
|---|---|
| AC 時間算術 | 50 條含時限 AC：閉合 32／不閉合 10／無法驗算 8。其中 **6 條同源於一個單點缺陷** |
| 常數↔AC 雙向 | 三欄表 16 項「待補登」全為誤標（registry 實際已登錄）；1 項假 Y；4 處正文殘留 |
| [P]→影響（首次執行） | **20 條中 17 條的影響欄不完整**；7 條的 fallback 會殺掉 MVP AC，其中 5 條未標 |

**最重要的三個發現**：

1. **單點缺陷**：`t_disconnect` 在公式①是「Host 判定時刻」，在測試基建是「socket.close() 時刻」，
   相差 `relay_disconnect_propagation_sec`（2s）。**同一個符號兩種語義**，一次使 AC10／AC11／
   AC12／AC13a／AC31 全部算術不可達。修這一句即消五條。

2. **B4 未修好，只被推遲了一層**：#18 排歧表改成「事件推播＋roster 輪詢」兩條路徑，但兩者
   **共用 MPS session 層這個載體**，同層不可用時序 1/3/4/5 一起死，「Host 消失」分支再次不可達。
   修法：補上載體論證——**roster 查詢能力是 Lobby 設計的既有前提**（沒有它連隊友名牌都顯示不了），
   因此 `[P-10]` 查證項 (c) 要問的不是「查得到嗎」而是「多快反映」；若連 roster 都查不到，
   那是架構層級重做，不在排歧表的 fallback 範圍內。P-10 影響欄補上先前漏列的 AC6b（B4 的原始受害者）。

3. **判準的主詞未定義**：r4 判準是「任何 fallback 殺掉 **MVP-必達** AC 的假設即為 blocking」，
   但層級欄只有 MVP／Post／VS，**沒有「必達」這一級**——判準無法機械執行。
   已新增 **MVP-必達** 層級並指定四條：AC6b、AC53、AC54、AC7。

**二次修訂內容**：
- 正文殘留清理：NPC 補位 0.3→0.2（4 處）、局終 10s→12s（3 處）、刪 60s resync 孤兒列、
  公式④變數表的舊安全範圍同步
- AC 修正：AC7／AC10／AC11／AC12／AC13a／AC22／AC28／AC31／AC36／AC37a／AC45 共 11 條；
  新增 AC45a（顯示節奏）與 **AC55**（複製邀請連結——它是 MVP 交付物卻零 AC 覆蓋）
- **約束 11 → 14 條**：⑧改為**條件式**（原無條件式使現行預設依字面即為非法組態，
  恆觸發的警報無法在回填當下區分 before／after）；新增 ⑫（catch-up 分母也是旋鈕）、
  ⑬（worstcase 的組成）、⑭（傳播段與 UI 段須分開計時，**非數值約束**）
- **假設表**：P-2／P-20 各拆兩半（其 (b) 半承載 MVP AC 卻被整條排 W2 或判非 blocking）；
  P-6／P-7／P-9／P-17／P-18 標出 fallback 不可行的算式；P-11 刪除假陳述
- **原型優先序再排**：新增**第 0 批（零原型成本的純文件查詢）**；**P-17 從最後一批移到第 1 批**
  （其 fallback 殺 AC54，且與 P-10(b) 是同一次操作——先前排最後違反本文件自己的判準）；
  P-18 移到第 3 批（它自己的驗證方式欄就寫要併入 P-7）
- **修訂協定新增兩條執行規則**：(A) 影響欄必須從 `[P-n]` **全文反向掃描機械產生**，不得手填；
  (B) fallback 欄寫「可行」前**必須代入數字驗算**——本輪有兩條光靠一行乘除就被推翻
  （P-3 的 tick 算術、P-6 的 gzip 算術）
- registry 新增 6 個常數（更衣室區間、樂觀動畫上限、斷線通知停留、狀態收斂、
  Host 回前景清理、Lobby 背景安全係數），總數 34 → **40**

**最終驗算證據**（14 條約束以預設值實跑）：**PASS 10 ／ FAIL 0 ／ 待原型或非數值 4**。
檔案 1224 → **1291 行**。

Next: **直接開 W1 原型**，依新的分批優先序（第 0 批是零成本的文件查詢，先跑完可能直接消掉數條假設）。

---

## W1 原型 — 第 0 批（純文件查詢，零原型成本）— 2026-09-13

三條假設查證完畢，全部對照 **NGO 2.13.2 實際原始碼**與官方文件，附 URL 與原文。

| 假設 | 結果 |
|---|---|
| `[P-3]` NetworkTransform 頻率可否獨立於全域 tick | **假設為假，但後果與預期相反** |
| `[P-9]` 內建逾時是否 ≥8s、Relay idle timeout | **前半成立；後半的前提不存在** |
| `[P-20]` ownership 預設值與 transfer 限制 | **(a) 擔憂證實；(b) 設計成立** |

### 三個改變設計的發現

**1. AC22 的「不可達」判斷解除，因為約束⑧的前提是錯的。**
`RPC 完全不受 network tick 影響`——每**幀**於 `PostLateUpdate` 批次送出
（`MessageManager.ProcessSendQueues()` 非 tick-gated），受 tick 影響的是 NetworkVariable
與 NetworkTransform。新預算 ≈235-250ms ≤ 300ms，餘裕 50-65ms。
約束⑧已重寫，並追加硬規則：**互動結果一律走 RPC，不得以 NetworkVariable 承載**
（後者 10Hz 下單邊 +100ms 即超標）。

**2. GDD 的權威模型寫錯了。** Core Rule #2 原文「Owner 權威：玩家移動（NGO NetworkTransform
預設，不改寫）」——查證結果 client-server 拓撲下 `AuthorityMode` **預設是 `Server`**，
只有 distributed authority 才強制 owner authority。**不是「不改寫」而是「必須改寫」**。
照原文實作會讓玩家移動變成 server 權威，而本地 host 測試看不出來。
引擎參考 `modules/multiplayer.md` 的同一句錯誤也已更正。

**3. 斷線處置序列的第 2 步隱含了一個為假的假設。**
`DontDestroyWithOwner` 預設 `false`＝**預設銷毀**，且銷毀發生在 `OnClientDisconnectCallback`
**之前**、同一個同步 call stack 內。#24 把「掉落手持物」寫成第 2 步，那時物件已不存在。
已補前置條件：**prefab 必須先勾選該欄位**。⚠ 且 `RemoveOwnership()` **不做 unparent**，
「掉落在原地」必須 Host 自行實作，引擎不代勞。

### 一個讓 #23 升格的發現

Relay 對**每個 client 連線**的 TTL 是 **10 秒**（無「allocation idle timeout」這種東西），
靠 NGO 自動送的 PING 重置。**瀏覽器節流背景分頁 timer 會使 PING 停送 → 背景 10 秒即被踢。**
後果：若 Lobby 階段已建立 Relay 連線，AC34a（30s）與 AC34b（120s）**必然失敗**，
且失敗在 **Relay 層**，比 #23b 描述的 MPS 服務層更早觸發。
**因此 `[P-10]` 查證項 (b)（能否拆分 Relay）不是效能優化問題，是整條 Lobby 設計成立與否的問題。**
新增 Core Rule #23c 記錄此事。

### 其他寫進文件的引擎事實

- `DisconnectTimeoutMS` 預設 30s ≫ 8s → 約束⑤成立，app 心跳確實先判定；欄位名 1.x→2.x 無更名
- `HeartbeatTimeoutMS` **雙重用途**（UTP heartbeat ＋ Relay PING 間隔），**不得調動**
- `ClientConnectionBufferTimeout` = 10s，approval 握手上限，影響 #9 的閘門
- `ChangeOwnership` 回傳 void、**失敗靜默**（四條 early-return，含「目標不在 Observers」）
  → #6a 要求呼叫後回讀 `OwnerClientId`
- 兩次 ownership 變更需隔 **6 個 network tick** → 新常數 `ownership_change_cooldown_ticks`；
  **10Hz 下即 600ms**，對快節奏交接是可感知的延遲 → 新增 OQ#17
- `OwnershipStatus`／`RequestOwnership` 那套**只在 distributed authority 有效**，本專案不適用
- `DontDestroyWithOwner` 在 **2.4.0 之前是壞的**（2.13.2 已修）→ 網路上 2025 上半年討論不可信
- `docs-multiplayer.unity3d.com` 已全數 301 轉址，舊連結會落到 package 首頁

### 新增測試

- **AC56（MVP-必達）**：斷線後道具須 `IsSpawned` 且 `IsOwnedByServer`、已 unparent 於斷線座標。
  **這是唯一能在 CI 擋住「手持物斷線蒸發」的測試**，且本地 host 模式測不出來
- **AC57**：交接冷卻 <6 tick 時須拒絕或延後，且 log 不得出現 NGO 的 Rapid Ownership Change 警告

### 檔案變更

GDD 1303 → 1364 行；registry 40 → 42 常數；`modules/multiplayer.md` 76 → 171 行。
回填後約束重新驗算：④分情境成立、⑤ PASS（8s ≤ 30s）、⑧ PASS（250ms ≤ 300ms，餘裕 50ms）。

**Next**：第 1 批（同一次 Sessions API 建連 ＋ Host 消失實驗）——`P-10`(a)(b)(c)(d) ＋ `P-17`
＋ `P-14` ＋ `P-2(b)`。其中 P-10(b) 現已是整條 Lobby 設計的存亡問題。

### 第 0 批的實機複驗（同日，Unity 專案建立後）

第 0 批的結論原本只來自官方文件與 NGO 原始碼。專案建立後發現一個落差：
本機解析出的 `com.unity.transport` 是 **2.7.4**，而第 0 批依 NGO 2.13.2 的相依宣告記為 **2.6.0**——
逾時常數正是從 2.6 的文件查來的。

因此把結論降落到實際安裝的套件上，寫成 EditMode 測試（`prototypes/w1-netcode/Assets/Tests/EditMode/EngineFactProbeTests.cs`）：

```
total=8 passed=8 failed=0 result=Passed
```

| 複驗項 | 結果 |
|---|---|
| `UnityTransport.DisconnectTimeoutMS` ＝ 30000 | PASS |
| 內建逾時 > app 心跳 8s（**約束⑤**） | PASS |
| `UnityTransport.HeartbeatTimeoutMS` ＝ 500，且 < 10000（Relay TTL） | PASS |
| `NetworkConfig.TickRate` ＝ 30 | PASS |
| `NetworkObject.DontDestroyWithOwner` ＝ false | PASS |
| **`NetworkTransform.AuthorityMode` ＝ Server** | PASS |
| `NetworkTransform.Interpolate` ＝ true | PASS |

**最後一項的意義**：它確認了 r4 對 Core Rule #2 下的更正是對的——原文「Owner 權威是
NetworkTransform 預設，不改寫」確為錯誤，實機預設就是 `Server`。這條若當初沒查，
實作出來會是 server 權威的移動，而本地 host 測試永遠看不出來。

該測試**刻意寫成斷言查到的值**：任一條 fail 即代表 GDD 回填的引擎事實與實機不符，
屆時該改的是 GDD，不是測試的期望值。它同時是一組回歸測試——**套件或編輯器升級後應重跑**。

`[P-3]`／`[P-9]`／`[P-20a]` 的狀態因此從「已回填（文件）」升級為「已回填並實機複驗通過」；
`[P-20b]`（ownership transfer 的 pending 語義）仍為原始碼層級結論，需第 1 批實機連線驗證。

### 環境就緒狀態（2026-09-13）

| 項目 | 狀態 |
|---|---|
| Unity 編輯器 | 6000.3.24f1（＝GDD 釘選的 6.3 LTS），Web Build Support 4.9GB 已裝 |
| 授權 | Personal，已以 headless 啟動確認 `Successfully resolved entitlement details` |
| 原型專案 | `prototypes/w1-netcode/`（throwaway，與 `src/` 隔離；`.gitignore` 既有 Unity 規則已涵蓋） |
| 套件 | NGO **2.13.2**、Multiplayer Services **2.3.1**、UTP **2.7.4**、Authentication 3.7.4、Core 1.18.0 |
| 編譯 | 零錯誤 |
| **尚缺** | **UGS Project ID**——Relay 與 Sessions 沒有它無法連線，第 1 批因此卡住 |

---

## W1 原型 — 第 1 批（API 形狀，編譯期驗證）— 2026-09-13

拿到 UGS Project ID 後建立原型專案。第 1 批原定要「一次建連實驗」，但發現**有一半的
問題不需要連線就能回答**：套件裡有完整的 public API surface dump
（`Unity.Services.Multiplayer.api`），而「API 存不存在、簽章對不對」可以用**編譯期驗證**
確定——能編譯過就是真的有那個方法，比反射拿字串更硬。

測試：`prototypes/w1-netcode/Assets/Tests/EditMode/SessionApiShapeTests.cs`
結果：**12/12 通過，零編譯錯誤**（含第 0 批的 8 條）。

### 三項解決，其中一項是全輪最嚴重的

**`[P-10]`(b) 可拆分 → Core Rule #23 成立，風險解除。**
`WithRelayNetwork()` 是 `SessionOptions` 的**擴充方法而非必填參數**；
`IHostSession.Network`（`IHostSessionNetwork`）提供 **`StartRelayNetworkAsync()`** 與
**`StopNetworkAsync()`**；`NetworkState` 有獨立的 **`Stopped`**。
即 network 是 session 之上**可獨立啟停的一層**，正是 #23 需要的形狀。
r4 曾依引擎參考的「Session 會自動處理 lobby、Relay allocation、NGO 連線」判斷三者是
一次呼叫的封裝、與 #23 直接衝突——實際 API 顯示那句描述的是**便利路徑**，不是唯一路徑。
**`StopNetworkAsync()` 同時讓 #23a（局間 teardown）有了對應 API。**

**`[P-10]`(c) → B4 徹底解決，且排歧表比原設計更簡單。**
`ISession` 直接提供 `Host`（目前 host 的 playerId）與 `HasPlayer(playerId)`，
**不需要「輪詢 roster 再比對」**。事件面有
`Deleted`／`SessionHostChanged`／`PlayerLeaving`／`PlayerHasLeft`／`RemovedFromSession`／
`SessionMigrated`／`StateChanged`，其中 **`SessionHostChanged` 是先前完全沒預期到的**。
r4 二次修訂曾擔心「兩條路徑共用 MPS session 層載體，同層不可用時 B4 會復發」——
實際上 `Host`/`HasPlayer`/`Players` 與事件推播是**同一個物件上的兩種取用方式**，
不是兩個可能各自缺席的 API。`[P-10]`(c) 剩下的唯一問題因此從「查不查得到」
縮小為「多快反映」，那是時序量測，不是分支存亡。
另證實 r4 對訊號語義的判斷正確：`SessionState`（None/Connected/Disconnected/Deleted）
與 `NetworkState`（Stopped/Starting/Started/Stopping/Migrating）是**兩個獨立狀態機**，
`session.Network.State` 描述的確實是本機 network 層。

**`[P-10]`(d) `IHostSession.RemovePlayerAsync(playerId)` 存在**（經 `ISession.AsHost()`），
另有 `DeleteAsync()`。→ **#24a 成立。這是 r4 全表唯一「沒有退路」的查證項，現已解除。**

### 一個沒預期到的發現

**host migration 在 MPS 2.3.1 是一等公民**：`GetHostMigrationDataAsync`／
`SetHostMigrationDataAsync`、`IHostSession.Host` 可指派、`SessionMigrated` 事件、
`NetworkState.Migrating`、`MigrationFailed` 事件。

GDD 從 r1 起就把「房主關分頁＝本局結束」當成 MVP 的**既定限制**，#12 的 UI 也對玩家
明示。現在看來那是**選擇**，不是引擎限制。已列為 **OQ#18** 交 creative-director 裁決——
它影響 #12、#21、AC6b、AC13b、UI 翻譯表整條「店長把鐵門拉下來了」的敘事，
以及 Relay 情境 B（host 掉線後 10s 回收）這個目前無解的限制。

### 仍需實機連線驗證

| 項目 | 為什麼編譯期驗不了 |
|---|---|
| `[P-10]`(a) MPS session 服務層在背景分頁是否停擺 | 需 Web build ＋ 真實瀏覽器分頁背景化 |
| `[P-17]` `ConnectionApprovalCallback` 在 Sessions 封裝下可否用 | 需實際建連觀察 callback 是否被觸發 |
| `[P-14]` kill 行程後其他 client 的偵測時刻 | 需兩個實例 |
| `[P-2]`(b) 重連後 playerId 是否延續同值 | `ReconnectAsync`／`CurrentPlayer` 存在，但值的延續性要連線才知道 |
| 事件推播延遲、是否需 `RefreshAsync()` | 時序量測 |

### 環境

Project ID `a214763c-…` 已寫入 `ProjectSettings.asset`（`cloudProjectId`＋`cloudEnabled: 1`）。
註：Project ID 是公開識別碼不是密鑰，可入庫；**日後若出現 API key／secret，一律不得進 repo**。

### 第 1 批的 runtime 驗證（PlayMode，真實連上 UGS）

編譯期驗證只能證明 API 形狀。以下四條是**真的連上服務端**跑出來的，
`prototypes/w1-netcode/Assets/Tests/PlayMode/`，**PlayMode 4/4 ＋ P-1 1/1 通過**。

**過程中的一次失敗本身是事實**：首次執行三條全倒在
`SessionException: Cannot start when Singleton is not set`——`WithRelayNetwork()` 這條
路徑**依賴 `NetworkManager.Singleton`**，而 PlayMode 空場景沒有。拆成「不帶 network」
與「有 NetworkManager 才延後啟動」兩條後，問題反而更精確。

**`[P-10]`(b) runtime 證實，且優於設計預期**

```
無 NetworkManager 下建立成功：Code=M69T96 SessionState=Connected NetworkState=Stopped
延後 StartRelayNetworkAsync 後：NetworkState=Started  NGO.IsListening=True
StopNetworkAsync 後：NetworkState=Stopped（SessionState 仍 Connected）
```

三件事同時成立：Lobby 階段 **連 NGO 單例都不需要存在**；「開始上班」時才配 Relay 可行；
**#23a 的局間 teardown 經 runtime 證實**，且 `SessionState` 與 `NetworkState` 確實是
兩個獨立狀態機。Core Rule #23 的風險完全解除。

**`[P-1]` 實測回填 → 反而刪掉一條設計規則**

```
樣本=8RHW98,BJDDTW,WBQBKM,Q9WF6J,8RGHPL,QH8GCH
碼長=6  字集=689BCDFGHJKLMPQRTW
大寫=True 小寫=False 數字=True 易混淆字元=無
```

固定 6 碼、全大寫英數。字集是刻意設計的：數字只有 6/8/9，**字母不含任何母音**
（應是為了不讓隨機碼拼出真實字詞），且完全避開 0/O/1/I/L。
因此 **#8 的「易混淆字元正規化」規則已刪除**（服務端已處理，客戶端再做是多餘的），
**`[P-1]` 的 fallback（自建短碼對照表）不需要**，AC2 的「0/O 互換」子項亦移除。
大小寫不敏感仍保留（碼全大寫，但玩家會用小寫輸入）。
取樣說明：6 樣本共 36 個字元位置全未出現易混淆字元；若字集真含 4 個易混淆字元，
36 次抽樣全不中的機率約 0.9%——證據強，但非窮舉。

**`[P-2]`(b) 實測回填**

`session.CurrentPlayer.Id` **等同** `AuthenticationService.Instance.PlayerId`
（實測兩者皆 `lEYLoSNzPcbDMI7OnZij79CxFKGp`）。只要匿名帳號不變，身分即跨 session 延續，
**#15a 的離線次數計數與 AC50 有了可靠依據**。
⚠ 殘留限制：匿名帳號綁本機憑證，**清快取或換瀏覽器即換身分**（與 OQ#5 同源）。
已在 #15a 註明「換裝置即重新計數」屬已知接受——濫用成本仍高於收益。

**`[P-10]`(a) 仍未解**：MPS 服務層在背景分頁是否停擺，需 Web build ＋ 真實瀏覽器。

### 第 1 批後的假設狀態

| 假設 | 狀態 |
|---|---|
| P-1 房間碼格式 | ✅✅ 實測回填，**fallback 與一條設計規則一併刪除** |
| P-2(b) 重連身分 | ✅✅ 實測回填 |
| P-3 tick 與送出頻率 | ✅✅ 實機複驗（第 0 批） |
| P-9 逾時常數 | ✅✅ 實機複驗（第 0 批） |
| P-10(b)(c)(d) | ✅✅ (b) runtime 證實；(c)(d) 編譯期證實 |
| P-10(a) 服務層背景停擺 | ⬜ 待 Web build |
| P-14 kill 行程偵測時刻 | ⬜ 待雙實例 |
| P-17 approval callback | ⬜ 待實際連線觀察 |
| P-20(a) | ✅✅ 實機複驗（第 0 批） |
| P-20(b) ownership transfer | ✅ 原始碼層級，待實機 |

### 第 1 批續：approval callback 與服務層保活機制

**`[P-17]` 實測回填 → r4 的一項 blocking 解除**

```
ConnectionApprovalCallback 被呼叫！ ClientId=0 PayloadLen=11
approvalCalls=1  ConnectionApproval 設定值=True  payload=w1-proto-v1
```

三件事同時成立：Sessions 的 `StartRelayNetworkAsync` **沒有覆蓋** `ConnectionApproval` 設定；
callback **確實被呼叫**；`NetworkConfig.ConnectionData` 的 payload **完整傳遞**到 `req.Payload`。
最後一項就是 AC54（MVP-必達）版本閘所需的通道。

r4 曾標註 `[P-17]` 是「用一個未驗證機制去修另一個未驗證機制」，並判定其 fallback
（連線後才踢）在語義上做不到版本閘該做的事、因而是 blocking。**該 blocking 現已解除。**
⚠ 已驗的是 host 自身 local client（`ClientId=0`）那次 approval；
**拒絕原因如何呈現給遠端 client** 仍待雙進程情境確認。

**`[P-10]`(a) 從「未知」變成「機制已證實，只剩秒數」——而且不必做 Web build 就查到了**

在 SDK 原始碼中找到保活的完整鏈條：

- `LobbyHandler` 有週期性 heartbeat 排程，間隔常數 `LobbySettings.HeartbeatSeconds => 10`
- 排程器 `ActionScheduler`（`com.unity.services.core`）使用 **`PlayerLoopSystem`**
  並呼叫 **`JoinPlayerLoopSystem()`**
- `RunScheduledHeartbeat` 還有一道 `if (Application.isPlaying)` 檢查

即：**保活訊號掛在 Unity PlayerLoop 上**。WebGL 主迴圈由瀏覽器動畫影格驅動，
背景分頁會被節流甚至停止 → **保活必然停送**。這不再是猜測，是機制事實。

**剩餘未知縮小為單一數字**：Lobby 服務端「多久沒收到 heartbeat 就回收房間」。
需 Release Web build ＋ 真實瀏覽器背景化實測（第 3 批）。

⚠ 與 Relay 的 10 秒 client TTL 是**兩個獨立計時器**，都受背景分頁節流影響，
但 **Relay 那個更早觸發**——這再次強化 Core Rule #23 的必要性（見 #23c）。

**過程中的兩個工程教訓（已寫進 README 與 harness 註解）**

1. `AuthenticationService.Instance` 在 `UnityServices.InitializeAsync()` 之前存取會拋
   `ServicesInitializationException`，且 `?.` **擋不住**——拋例外的是 getter 本身。
2. 雙進程測試中，兩個專案副本若 `productName` 相同會**共用 PlayerPrefs**，
   於是拿到**同一個匿名帳號**，client 會變成 host 自己。已把副本改名為 `w1-client`。

---

## W1 原型 — 第 2 批（Release Web build，本地驗證部分）— 2026-09-13

建置設定刻意採 GDD 指定的正式組態：IL2CPP ＋ Managed Stripping High ＋ Strip Engine Code
＋ Brotli，因為 `[P-7]` 的整個風險就在「只有 Release build 才現形」。
建置成功、零錯誤、耗時約 3 分鐘。

**`[P-7]` 雙向通過 —— 這是本批最重要的結果**

`.jslib` 的 JS→C# 讀取（`location.search`／`visibilityState`／`navigator.onLine`／
`performance.now`）與 **C#←JS 的 `SendMessage` 回呼**在正式 build 下**全部正常**。
後者才是 `[Preserve]` 的真正考驗——它證明了 r4 為此加的保護是有效的。
實測 console：

```
[W1WEB] boot ownQuery='?code=TEST99' parentQuery='?code=TEST99' iframe=0 referrer=''
[W1WEB] clipboard result = OK
```

**`[P-19]` 本地通過**：Clipboard API 在 user gesture 下回傳 `OK`。
⚠ 但 **itch.io 的 iframe 是否以 permissions policy 擋掉 `clipboard-write` 仍待部署驗證**，
那才是 #23「複製邀請連結」這個必做配套的真正考驗。

**`[P-4]` 本地部分通過**：非 iframe 情境下 `?code=TEST99` 讀得到。
⚠ **真正的問題（itch.io 把遊戲放進 iframe 後 query 是否還在）必須部署才知道**。
探針已同時取自身 query、父視窗 query 與 `document.referrer` 三個來源，以便分辨
「完全讀不到」與「要改從父視窗取」。

### 兩個原本不知道的數字與限制

**Build size 的地板是 7.0 MB。** 一個幾乎空的專案（單一 OnGUI 探針 ＋ NGO ＋ MPS）
Brotli 後：`Web.wasm.br` 5607 KB、`Web.data.br` 1472 KB、`Web.framework.js.br` 77 KB、
`Web.loader.js` 26 KB。**執行環境與 netcode 套件就吃掉約 7 MB，留給遊戲內容約 43 MB。**
公式⑤ 的 `T_load` 餘裕本來就是 0，現在連地板都有依據了。

🔴 **Unity Web build 的預設字型不含 CJK——整張 UI 翻譯表在網頁上會是空白。**
實測探針畫面：**中文字元完全不渲染**，只有英數與符號出得來。
這是**支柱級問題**：UI Requirements 的核心主張正是「所有網路狀態一律翻譯成店語」，
而店語全是中文。已寫入 UI Requirements 與 `modules/web.md`：
必須打包 CJK 字型並設為預設，且**字型子集化應列為 MVP 建置步驟而非後期優化**
（體積直接壓在已經歸零的 `T_load` 餘裕上）。
註：Godot 也有同一個坑（`ThemeDB.fallback_font` 無 CJK）——**換引擎沒有換掉這個坑**。

### 尚待 itch.io 部署

`[P-4]`（iframe 是否轉發 `?code=`）、`[P-6]`（Brotli `Content-Encoding`）、
`[P-19]` 的 iframe 情境。三者同屬一次部署，需 butler 登入與一個 itch.io 專案頁。

## W1 原型 — 第 2 批（itch.io 真實部署）— 2026-09-14

部署到 `arlong666.itch.io/w1-netcode-probe-internal-test`（草稿，僅擁有者可見）。
三項假設全部有了決定性答案，**其中兩項為假，一項後果比預期嚴重**。

### `[P-4]` 帶碼連結：假設為假，但找到唯一可行路徑

| 來源 | 實測值 |
|---|---|
| `location.search` | **`?v=1789400690`**——itch.io 自己的版本參數，原始 `?code=` 完全不見 |
| `parent.location.search` | **`__CROSS_ORIGIN_BLOCKED__`**——iframe 來自 `html-classic.itch.zone`，與 `itch.io` 跨域 |
| **`document.referrer`** | **`https://arlong666.itch.io/…?code=…`——原始 URL 含 query，可讀** |

**帶碼連結仍可實作**，但必須改從 `document.referrer` 解析。
⚠ referrer 會被使用者隱私設定或 `Referrer-Policy` 削減，因此
**#8 的輸碼備援絕不可砍**（AC2 已保底）。探針同時取三個來源，正是為了分辨這件事。

### `[P-6]` Brotli：假設為假，且直接打穿支柱 4

itch.io **不支援 Brotli `Content-Encoding`，而且會把上傳的 `.br` 解壓後重新提供**。

| 檔案 | 我們的 Brotli | itch.io 實際傳輸 | 倍數 |
|---|---|---|---|
| `Web.wasm.br` | 5,741,298 | 8,108,255（`content-encoding: gzip`） | 1.41 |
| `Web.data.br` | 1,506,949 | 6,522,513（**無 content-encoding**） | **4.32** |
| `Web.framework.js.br` | 78,508 | 92,753 | 1.18 |
| `Web.loader.js` | 26,983 | 9,514 | 0.35 |
| **合計** | **7,353,738** | **14,733,035** | **2.00** |

機制已確認：`Web.data.br` 下載後前 4 位元組是 `UnityFS` **明文** → itch.io 解壓了 Brotli。
遊戲能跑，是因為 Unity 收到的本來就是可用資料——**壞消息藏在傳輸量裡，不在功能裡**。

🔴 **公式⑤ 的 `T_load ≤25s` 建立在「50MB Brotli ÷ 20Mbps」之上。
在 itch.io 上那是 ≈100MB → `T_load ≈50s` → 60 秒硬標破，支柱 4 不成立。**

正在驗證解法：`decompressionFallback = true`（Unity 內建 JS 解壓，不依賴伺服器 header）。
第一次建置刻意設 `false`，為的正是測出伺服器真實行為。

### `[P-19]` 剪貼簿：iframe 情境為假

itch.io 的 iframe `allow` 屬性實測**沒有 `clipboard-write`**：

```
autoplay; fullscreen *; geolocation; microphone; camera; midi; monetization;
xr-spatial-tracking; gamepad; gyroscope; accelerometer; xr; cross-origin-isolated; web-share
```

→ **#23 的「複製邀請連結」在 itch.io 上必須走 fallback**（可全選的文字框＋提示手動複製）。
本地非 iframe 情境仍為 `OK`，故此限制**專屬於 iframe 部署平台**。
⚠ 這一項在本地測試會通過、在正式平台失敗——正是 r4 擔心的那類「只在正式環境現形」的缺陷。

### 方法論註記

三項全部是「本地測不出來」的。`[P-4]` 與 `[P-19]` 在本地都通過，`[P-6]` 在本地根本不存在
（本地伺服器是我自己寫的，當然回正確的 header）。**必須真的部署**這件事本身，
是 r4 把這三項綁成同一批的理由，現在證明那個判斷是對的。

### `[P-6]` 的解法已驗證成立

把 `PlayerSettings.WebGL.decompressionFallback` 設為 **`true`**，副檔名隨之從 `.br`
變為 **`.unityweb`**。itch.io 不認得那是壓縮檔，因此**原樣提供**，改由 Unity 的 loader
自行解壓。

| 建置方式 | 本地 | itch.io 傳輸 | 倍數 |
|---|---|---|---|
| `.br`（fallback=false） | 7,353,738 | 14,733,035 | 2.00 |
| `.unityweb`（fallback=true） | 7,444,699 | **7,416,748** | **0.99** |

**傳輸量減半，公式⑤ 的 `T_load` 預算恢復，支柱 4 保住。** 部署後實測遊戲正常運作。
代價：`Web.loader.js` 由 26,983 → 117,894 bytes（+90KB），外加解壓的 CPU 時間
（未量測，列入第 4 批）。

🔴 **這是建置規範的強制項，不是可選優化。** 已同步寫入
`docs/engine-reference/unity/modules/web.md`——若誤用預設的 `.br`，50MB 的 build
在 itch.io 上等於約 100MB 傳輸。

### 第 2 批結論

| 假設 | 結果 |
|---|---|
| `[P-4]` 帶碼連結 | 假設為假；`document.referrer` 是唯一路徑；輸碼備援不可砍 |
| `[P-6]` Brotli | 假設為假；**但解法已驗證，傳輸量從 2.00 倍回到 0.99 倍** |
| `[P-7]` .jslib | ✅ 雙向皆通過（第 2 批本地 ＋ 部署後再次確認） |
| `[P-19]` 剪貼簿 | iframe 情境為假（`allow` 無 `clipboard-write`）；必須走 fallback |

三項為假中有兩項找到了可行路徑，一項（剪貼簿）確認必須降級。
**沒有任何一項需要改動架構。**

## W1 原型 — 第 3 批（背景分頁）— 2026-09-14

### 一個推論錯了，兩個擔憂因此解除

第 1 批在 SDK 原始碼中找到保活的完整鏈條：`LobbyHandler` 的 heartbeat 間隔
`HeartbeatSeconds => 10`，排程器 `ActionScheduler` 使用 `PlayerLoopSystem` 並
`JoinPlayerLoopSystem()`，還有一道 `if (Application.isPlaying)`。
當時據此推論「背景分頁 → 主迴圈停 → 保活停送 → session 被回收」，
並把 Core Rule #23 從「優化」升格為「必需」。

**前半正確（保活確實掛在 PlayerLoop 上），後半錯誤。**
背景分頁**不是停止主迴圈，而是節流**：

| 背景時長 | Update 次數 | 平均 | 最大 Update 間隔 |
|---|---|---|---|
| 4.4s | 9 | 2.1 fps | 1001 ms |
| 201.0s | 209 | 1.0 fps | 1601 ms（發生在第 6 秒，啟動初期） |
| 384.7s | 396 | 1.0 fps | **1601 ms（六分半鐘內未惡化）** |

Chrome 桌面版穩定節流到 **1 Hz**，六分半鐘內**未觸發 Page Freezing**。

- MPS heartbeat（10 秒）→ 照常送出 ✅
- Relay PING（500ms）→ 節流後約 1 秒一次，**仍遠低於 10 秒 TTL** ✅

**`[P-10]`(a) 假設為假：背景分頁不會讓 session 被回收。**
**#23b 與 #23c 的擔憂皆不成立；#23 回到「好設計」而非「必需」。**
**AC34a（背景 30s）與 AC34b（背景 120s）應可通過**；`lobby_bg_safety_factor` 失去用途。

### 方法論註記

原本的計畫是「建 session → 背景化 → 等回收 → 量秒數」。
改成**量主迴圈的最大停頓**之後，測試從「等一個可能很長的逾時」變成「看一個立刻可讀的數字」，
而且回答的是更上游的問題——**那個逾時到底會不會發生**。
結論是它不會發生，所以原本要量的秒數並不存在。

⚠ **量測邊界**：macOS 桌面 Chrome、分頁背景化（非視窗最小化、非系統休眠）、六分半鐘。
**行動瀏覽器不在此列**——OQ#10（iOS Safari 的背景回收）仍然有效且未解。
另註：1 Hz 意味著背景期間 `deltaTime` 約為 1 秒，**任何以每幀累加的模擬在背景都會行為異常**
——這與 GDD「模擬不快轉、不補跑」的裁定方向一致，但實作時要確認模擬確實凍結而非以 1 秒
步長繼續跑。

---

## W1 第 4 批 — 互動往返延遲（2026-09-15）

要驗的是第 0 批從 NGO 原始碼推出、但一直沒有實測的那個結論：**RPC 不受 network tick 閘門
控制**。它是 AC22（MVP-必達）成立與否的支點——若推論為假，約束⑧ 會讓該 AC 在數學上不可能。

### 測法

雙進程（Unity 不允許兩實例開同一專案，client 跑 `w1-client` 副本），經**真實 Relay WSS**，
以 `CustomMessagingManager` 的 named message 往返 20 次、每次間隔 250ms。
用 named message 而非 `[Rpc]`：兩者走**同一條**傳輸路徑
（`MessageManager` → `PostLateUpdate` → transport），但不需要 NetworkObject／prefab 註冊。
量到的是傳輸路徑本身的延遲，那正是 AC22 的分母。

`./w1-rtt-run.sh [tick] [region]`，tick 與 region 由命令列帶入，
**對照組與實驗組跑的是完全同一份程式碼**。

### 結果一：tick 的問題被釘死了

| tick | min | median | p95 | max |
|---|---|---|---|---|
| 10 Hz | 329.2 | 331.1 | 335.8 | 337.2 |
| **1 Hz** | 329.2 | 330.7 | 333.0 | 336.5 |

**tick 改十倍，往返一毫秒未動。** 選 1Hz 當對照組是刻意的：若 RPC 真按 tick 批次送出，
每筆最長要等 1 秒，p95 必然落在秒級。它沒有，而且兩組的離散度都只有 8ms——
連 10Hz 閘門該有的百毫秒級抖動都不存在。

**約束⑧ 的原前提正式作廢。AC22 不再受 tick 威脅。**

### 結果二：真正的威脅在別處

上表兩組都是**預設 region**。而 `interact_rtt_p95_ms` 的上限是 300ms——
**p95 335.8ms，遊戲邏輯一行都還沒跑就已經超標。**

只把 region 指定為 `asia-northeast1`，其餘完全不變：

```
samples=20;min=85.4;median=88.8;p95=94.5;max=104.4;tick=10;region=asia-northeast1
```

**3.7 倍。AC22 的成敗實際上由 region 決定，不是由 tick 決定。**

而這條**沒有自動解**：Relay 的 QoS（自動挑最近 region）在 Web 上拋
`PlatformNotSupportedException: QoS SDK does not support WebGL`，本作又是 Web-only。
沒有「不設就會自動最佳」這條路，遊戲必須自己決定並顯式傳入。

實機列舉的可用 region：`asia-southeast1`、`asia-northeast1`、`asia-south1`、
`us-central1`、`us-east1`、`us-west1`、`europe-north1`、`europe-west4`、
`europe-central2`、`australia-southeast1`、`southamerica-east1`。
**沒有台灣／香港節點**，東亞最近的是東京。

難處在於 **region 由 Host 在建立 allocation 時一次決定，整局不可改**，
而房間裡的人可能散在不同大洲。已升為約束⑮ ＋ registry 常數 `relay_region` ＋ **OQ#20**。

### 過程中撞到的兩個協定陷阱

兩個都不是查文件查到的，是測試連續失敗兩次逼出來的。

1. **Relay 協定只能在建 session 當下指定。**
   `RelayNetworkOptions(RelayProtocol)` 已 `[Obsolete]`（訊息明言改用
   `SessionOptions.WithNetworkOptions()`），而 Core Rule #23 延後建連用的
   `StartRelayNetworkAsync` 的非 obsolete 建構子只收 `region`／`preserveRegion`，
   **沒有 protocol 參數**。
   → **#23 不因此受損**：`WithNetworkOptions()` 只設定、不啟動，實測
   `CreateSessionAsync` 之後 `NetworkState` 仍為 `Stopped`，延後建連與指定 WSS 並存。
   但「協定」從執行期決定變成**建 session 時的一次性決定**。

2. **協定不會從 Host 傳染給加入者。**
   Host 已設 WSS 且 `IsListening=True`，加入端只傳房間碼
   （`JoinSessionByCodeAsync(code)`）照樣拋
   `ArgumentException: Mismatched Relay configuration and network interface`。
   `JoinSessionOptions` 同樣繼承 `BaseSessionOptions`，必須自己再宣告一次。
   → 實作上協定設定**必須集中成共用 helper**：漏掉任一條加入路徑會**只在該路徑失敗**，
   而 Host 端一切正常。**這種不對稱失敗在本地單機測試中看不出來**——
   與第 2 批 itch.io 那三項「本地全綠」是同一類陷阱。

附帶：`EnableSceneManagement` 兩端必須一致，否則 NGO 握手階段就拒絕連線。

### 方法論註記

這一批的價值有一半來自**對照組**。單看 tick=10 的那組數字，8ms 的離散度已經很像
「沒有閘門」，但那是解讀；跑 1Hz 之後，「若有閘門則 p95 必為秒級」讓結論變成不需要解讀的事實。

另一半價值完全是意外。原本只想驗 tick，結果 330ms 這個絕對值本身比 tick 更要命——
**如果只問「tick 會不會影響 RTT」而不看絕對值對不對得上 AC，這一批會得出「AC22 沒問題」
的錯誤結論並結案。** 量測時同時檢查「這個數字能不能過 AC」，而不只是檢查假設的真偽。

---

## OQ#20 裁決 — 「讓國外的人也可以參與」（arlong，2026-09-15）

第 4 批提出的三選一（寫死東亞／Host 端量測挑選／依時區推測）在裁決後**不再是三選一**：
既然不能犧牲海外玩家，就不能寫死任一大區。

### 追加量測：把模型驗到洲際距離

先前只有兩個資料點（東京 88.8ms、預設 331.1ms），不足以確定關係是線性的。補了第三點：

| region | median | p95 | 反推單程 `d(台灣, R)` |
|---|---|---|---|
| `asia-northeast1` | 88.8 | 94.5 | 22.2 ms |
| 預設（美國中部） | 331.1 | 335.8 | 82.8 ms |
| **`europe-west4`** | **434.3** | **437.8** | **108.6 ms** |

兩個進程都在台灣，故 `RTT = 4 × d(台灣, R)`。三點的反推單程值都落在該路線的合理範圍，
**模型成立，可以拿來推還沒量的組合。**

### 裁決後的解法不是折衷，是可證明的

Relay 的往返路徑是 `client → relay → host → relay → client`，故
`RTT_i = 2 × (d(i, R) + d(R, H))`。

先修正一個先前寫錯的前提：**Host 不付這筆延遲**——它是權威，自身互動本地就結算了。
所以要最小化的是**所有 client** 的延遲，Host 不計入。

由三角不等式 `d(i,R) + d(R,H) ≥ d(i,H)`，等號在 `R` 落於 `i` 與 `H` 之間時成立，
而 **`R = H` 對所有 `i` 同時成立**。把 relay 移向某個 client 會讓其他 client 變差；
移向 Host 則讓每個人同時拿到各自的理論下限 `2 × d(i, H)`。

**沒有人因此變差，所以沒有取捨要做。** → Core Rule #28：relay 貼著 Host 選。

原本擔心的「Host 端量測會吃掉 `T_load` 預算」也隨之消失——查時區是本地的、零延遲。
時區須用 `.jslib` 讀 `Intl.DateTimeFormat().resolvedOptions().timeZone`，
**不可用 .NET `TimeZoneInfo`**（Unity Web 的時區資料庫不完整）；
`.jslib` 在 Stripping High 下的存活已於第 2 批證實。

### 殘留代價，如實記錄

用模型推跨洲房間：歐洲玩家加入台灣 Host 的房、`R = asia-northeast1` 時，
`RTT = 2 × (d(歐,東京) + 22.2)`。`d(歐,東京)` 無法自本地量得，但由已測兩值夾擠得
`86.4 ≤ d(歐,東京) ≤ 130.8` → **`RTT ∈ [217, 306] ms`**。

**跨洲能玩，但正好壓在 `interact_rtt_p95_ms`(300ms) 的邊緣**，再加 server frame rate
與遊戲處理必定超過。

把跨區也硬綁 300ms 等於寫一條**注定失敗且無法靠實作補救**的 AC——那是光速問題，不是
實作問題。故 AC22 拆為兩條：

- **AC22（同區）**：p95 ≤300ms，MVP 必達。實測 `asia-northeast1` 裸往返 94.5ms，餘裕約 205ms。
- **AC22a（跨區）**：不設時間上限，改以**降級契約**承接——慢，但**正確、有回饋、不卡死**，
  且不得給出會被推翻的樂觀結果。
- **AC22b**：自動選區 ＋ 可覆寫；**留空即為缺陷**（會落到預設 region 的 335.8ms）。

⚠ 217–306ms 是**夾擠推得，非直接量測**（本地兩進程都在台灣，量不到歐洲↔東京）。
真實跨洲數字須待有海外測試者時補量。

### 一個順帶修正的過度斷言

先前寫「region 由 Host 一次決定，**整局**不可改」。查 API 形狀後這句太絕對：
region 是傳給 `StartRelayNetworkAsync` 的，而依 #23 那是「開始上班」才呼叫、
依 #23a 局間會 `StopNetworkAsync` 拆掉。所以固定範圍是**一個班次**，不是整局——
理論上每班次可重選，若日後啟用 host migration（OQ#18），region 得以跟著新 Host 走。
⚠ 此為由 API 形狀推得的推論，**未實測** stop→start 能否真的換區，列為結案後待驗項。

### 設計上的推論：誰當房主，決定了房裡所有人的延遲

一群人多數在歐洲卻由台灣的人開房，全體被綁在 `2 × d(自己, 台灣)`；
換一個歐洲的人開房即可消除。這是 Lobby UI 應該讓玩家知道的資訊，
也是 OQ#18（host migration）在 MVP 之後的一個實際用途。

---

## W1 第 4 批（續）— [P-20](b) ownership transfer 實機行為（2026-09-16）

這一項原本只是「把第 0 批查到的 API 行為做實機複驗」，結果推翻了 OQ#17 的兩個前提。

### 先在原始碼裡發現描述有問題

GDD 寫的是「引擎**要求**兩次 ownership 變更間隔 ≥6 個 network tick，10Hz → 600ms，
對 Overcooked-like 是**可感知的**交接延遲」。翻 `NetworkSpawnManager` 後發現那個 6
只存在於一則警告字串裡：

```
if (NetworkManager.LogLevel == LogLevel.Developer && !distributedAuthorityMode && ...)
    NetworkLog.LogWarningServer("[Rapid Ownership Change Detected][Potential Loss in State] ...");
```

**它不延遲、不阻擋任何交接**，而且還被 `LogLevel == Developer` 擋著。
註解裡寫的機制也不是 tick 而是延遲：「ownership changes faster than **the latency**
between the client-server」。

再往下翻 `NetworkVariableDeltaMessage`：

```csharp
var shouldWrite = networkVariable.IsDirty() && networkVariable.CanClientRead(TargetClientId)
    && (networkManager.IsServer || (networkVariable.CanWrite() && networkVariable.CanSend()));
```

`CanWrite()` 是在**下一個 tick 序列化時**才評估的。若那時所有權已被收回，
這筆 delta 根本不會被送出。→ 推得危險窗口 ≈ **一個** tick 週期，不是六個。

### 實機掃描

雙進程經 Relay WSS（`asia-northeast1`），一個 owner-write `NetworkVariable<int>`。
協定：host 把所有權交給 client → client 在 `OnGainedOwnership` 當下寫入 marker 並回報
→ host 等 `delay` 毫秒後收回所有權 → 900ms 後讀值，比對是否等於 marker。
每個 delay 跑 3 次。`prototypes/w1-own-run.sh [tick] [region]`。

| delay ms | 0 | 40 | 80 | 120 | 160 | 240 | 400 | 700 |
|---|---|---|---|---|---|---|---|---|
| **tick=10** | 0/3 | 1/3 | **3/3** | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| **tick=1** | 0/3 | 0/3 | 0/3 | 0/3 | 1/3 | 1/3 | 1/3 | 2/3 |

tick=1 是刻意的對照組：若窗口真的隨 tick 週期縮放，1Hz 下連 700ms 都該不安全。它正是如此。

存活率近乎 `delay ÷ tick 週期`（10Hz@40ms→40%→1/3；1Hz@700ms→70%→2/3），
正是「寫入落在 tick 週期內的**隨機相位**」該有的分布 —— 這比單一門檻值更能說明機制。

**handoff（交接傳播＋寫入＋回報，一個往返量級）**：tick=10 為 100-104ms、
tick=1 為 101-105ms。**不受 tick 影響**，與同 region 的 RTT（median 88.8、max 104.4ms）同量級。

### 結論

1. **OQ#17 消解，不需要 arlong 裁決** —— 是量測取代了裁決，不是有人做了取捨。
   「10Hz → 600ms 可感知交接延遲」不存在；交接約 100ms 且與 tick 無關。
   `network_tick_rate = 10` 不因交接而受威脅。
2. **`[P-20]`(b) 結案**：`ChangeOwnership` 同步原子、約 100ms → #6 的「單一真相時刻」
   與 AC14 皆成立，(b) 原本標註的「無 fallback」不再是問題。
3. 🔴 **但後果比原設計假設的嚴重**，這是本項唯一的壞消息。
   伺服器收到越權 delta 時記錄的是：

   > `Client wrote to NetworkVariable without permission.`
   > **`No more variables can be read. This is critical.`**

   它**中止解析該訊息的其餘部分** —— 所以掉的不只是那一筆，
   **同一物件上其他無關的 NetworkVariable 也會一起掉**。
   → **約束⑧ 的後半（互動結果一律走 RPC）從效能考量升格為正確性要求。**

### 方法論註記

第一版測試「失敗」了，而失敗訊息本身就是最重要的發現：Unity Test Framework 把
未預期的 Error 日誌當成測試失敗，於是那則 `No more variables can be read` 直接
中斷了整個掃描。**如果當初把它當成雜訊直接關掉，就會錯過這一行。**
先讀懂它、確認它是要量的現象，才放行 `LogAssert.ignoreFailingMessages`。

另一個坑值得記：runtime 造的 prefab 若 `SetActive(false)`，client 端會拋
`OverflowException: Reading past the end of the buffer`。根因是 NGO 反序列化時執行
`networkBehaviour?.Synchronize(...)` —— 那個 `?.` 在 behaviour 為 null 時**靜靜跳過，
但資料仍留在緩衝區**，於是讀爆。而 inactive 的實例不跑 `Awake`，
`ChildNetworkBehaviours` 是空的。host 端當時沒事，只因為我在 `Spawn()` 前手動啟用了。
**同一份程式碼、兩端行為不同**，又是一次只在跨進程才現形的不對稱失敗。

---

## W1 第 4 批（續）— JS 解壓的 CPU 成本（2026-09-17）

第 2 批留下的一筆帳：`decompressionFallback = true` 是繞過 itch.io 不支援 Brotli 的
強制設定，當時記錄為「傳輸量減半，公式⑤ 的 T_load 預算恢復」，但**解壓的 CPU 時間
留為未量測**。這次把它量出來，結論是——**預算並沒有恢復，只是從網路搬到了 CPU。**

### 量法

在 build 的 `index.html` 插計時點（`t_scriptStart` / `t_loaderLoaded` / `t_ready`
＋ Resource Timing），在 localhost 量，網路時間趨近於零，所以
`t_ready − t_loaderLoaded − fetch` 就是「資料在手之後的 CPU」。

關鍵是**對照組**：把三個 `.unityweb` 用原生 brotli 預先解壓、**檔名不變**再服務一次。
Unity 的 loader 遇到沒有壓縮標頭的檔案會原樣通過（實測成立，無錯誤），
所以兩版差的就是解壓那一段。同一個分頁先後載入，排除暖機差異。

### 結果

| 量測 | 值 |
|---|---|
| 壓縮 → 解壓後 | 6.98 MB → **34.13 MB**（4.89×） |
| 原生 C brotli 解壓同一份資料 | **86 ms**（397 MB/s） |
| 壓縮版「資料在手後 CPU」 | 2268 / 2465 / 2521 / 2529 / 2590 ms（暖）、3600 / 4323 ms（冷） |
| **預先解壓版「資料在手後 CPU」** | **331 / 412 ms** |
| **差值 ＝ JS 解壓成本** | **≈ 2.0-2.2 s（16.3 MB/s，比原生慢約 23 倍）** |
| wasm 編譯（27.5 MB 模組，`WebAssembly.compile` 單獨計時） | 346 ms |

### 過程中我推錯了一次，值得記

拿到「資料在手後 4.3 秒」時，我的第一個假設是**那是 27.5 MB wasm 的編譯成本**——
聽起來很合理。單獨量 `WebAssembly.compile` 之後：**346 ms**，不到十分之一。
假設錯了。接著才做預先解壓的對照組，才看到大頭是解壓。

**如果當時沒有去單獨量編譯，就會寫下一條「build 越小編譯越快」的錯誤結論，
而真正的槓桿（解壓吞吐）會被漏掉。** 這跟 region 那次同一個教訓：
數字的**絕對值**要對得上某個 AC，而不是只確認假設的真偽。

### 對公式⑤ 的衝擊

原式 `T_load ≈ build_size ÷ bandwidth ＋ 多資源 TTFB` **沒有任何 CPU 項**。
修正後多一項 `decompressed_size ÷ js_brotli_decompress_rate`。代入專案硬標：

```
S ＝ 50MB → 50÷2.5 ＋ 5 ＋ 0.30×50 ＋ 0.4 ＝ 20 ＋ 5 ＋ 15 ＋ 0.4 ＝ 40.4 s   ✗（上限 25s）
求解 T_load ≤ 25s → **S ≤ 約 28 MB**
```

**有效 build size 天花板從 50 MB 掉到約 28 MB**，跨出本 GDD 權責，升為 **OQ#21**。

### 這個結論的弱點，我不想它被當成定案

**(a) 這是相加模型，而我無法判定解壓能否與下載重疊。** localhost 的下載只有
19-153 ms，太快，看不出重疊。若 Unity 的 loader 是串流解壓，真實網路下 20 s 的下載
可以吸收掉大部分解壓時間，40.4 s 就是高估。
**這一筆複驗最便宜、也最可能翻案，應該在下修任何硬標之前先做**（需節流網路，非 localhost）。

**(b)** 8 核桌機是樂觀硬體。**(c)** 量的是 7 MB build，線性外推到 50 MB 未經驗證。

順帶一提，第 5 章新增的商品圖集採 ASTC（已壓縮格式），Brotli 對它幾乎壓不動，
所以它拉低 `build_decompressed_ratio`——**對 T_load 反而有利**。

### 複驗：解壓與下載會不會重疊（2026-09-17，同日）

上一節把「相加模型」列為最該先補、也最可能翻案的一筆。做了，**沒有翻案。**

不用 DevTools，自己寫限速伺服器（`prototypes/w1-serve-throttled.py`，以固定位元組
速率送出）。判別法很單純：**若解壓與下載重疊，網路變慢時「資料在手後的 CPU」會被
吸收而縮小；若相加，它會維持不變。**

| 網路 | 下載窗口（牆鐘） | **資料在手後 CPU** | 總計 |
|---|---|---|---|
| localhost（暖） | ~0.03 s | **2.27-2.59 s** | 2.5 s |
| 20 Mbps 限速 | 2.45 s | **3.23 s** | 5.82 s |
| 5 Mbps 限速 | **9.35 s** | **2.51 s** | 12.05 s |

**下載時間拉長 300 倍，CPU 項紋風不動。** 逐檔時序也對得上：5 Mbps 下
`Web.wasm.unityweb` 在 198→9380 ms 下載，而 `t_ready` 落在 12052 ms——
解壓在下載**結束之後**才開始。模型回測：5 Mbps 預測 11853 ms vs 實測 12052 ms（+199 ms）。

順帶修了一個量測本身的缺陷：原本用「各檔 duration 加總」當網路時間，但檔案是**並行
下載**的，加總會重複計算。改成牆鐘窗口（`max(responseEnd) − min(startTime)`）才對。
在 localhost 上這個差別無關緊要，一限速就會差很多。

**所以 40.4 s 不是高估，28 MB 的有效天花板站得住。** OQ#21 至此**沒有技術前置了**，
剩下的純粹是產品取捨：下修硬標（砍一半內容預算）／換掉 itch.io（對照組實測 CPU 僅
0.33-0.41 s，等於問題消失，但牽動發行通路）／接受更長的 T_load（等於支柱 4 打折）。

**方法論註記**：我原本把 (a) 標成「最可能翻案」並要求先做——結果它反而把結論釘死了。
這個標記本身沒有白費：**先做最可能推翻自己的那一項，通過了，後面的裁決才站得穩**。
若當初跳過它直接建議下修硬標，這個建議會一直帶著一個沒人驗過的假設。

### 前置二：不換主機能不能解決？能，而且已部署驗證（2026-09-18）

OQ#21 原本的三條路裡沒有這一條——它是查免費主機時，從 itch.io 自己的文件裡掉出來的。

itch.io 文件明寫「`.br` 結尾就會設 `content-encoding: br`」，但第 2 批實測是相反的。
矛盾的解答藏在同一段的括號裡：

> "Brotli encoding **can not be detected** like gzip, so we must depend on the `.br` extension"

**gzip 是看內容偵測，brotli 只能靠副檔名——而靠副檔名那條路壞了。**
順帶一提，把第 2 批那份 wasm 自己 gzip 一遍得到 **8,103,680** bytes，
而當時量到 itch.io 實際送出 **8,108,255** bytes，差不到 5KB：
**itch.io 就是把我們的 brotli 解掉再 gzip 一遍**，機制至此完全對上。

於是改建 gzip ＋ `decompressionFallback = false` 版本並實機部署。curl 結果：

| 檔案 | content-encoding | content-type | content-length |
|---|---|---|---|
| `Web-gzip-native.wasm.gz` | **gzip** | **application/wasm** | 7,805,140 |
| `Web-gzip-native.data.gz` | **gzip** | application/octet-stream | 1,913,539 |
| `Web-gzip-native.framework.js.gz` | **gzip** | text/javascript | 90,672 |
| `Web-gzip-native.loader.js` | gzip | text/javascript | 9,514 |

**每個 `content-length` 都與上傳的位元組數完全相同**——沒有被解壓、也沒有被重壓。
wasm 另外拿到 `application/wasm`，`WebAssembly.instantiateStreaming` 可用。遊戲正常運作。

附帶好處：`loader.js` 從 117,894 掉回 26,983 bytes——那 90KB 的 JS 解壓器一起消失。

### 三條路的完整實測

本機以正確 header 服務 gzip 版，量「資料在手後的 CPU」：

| 解壓方式 | CPU |
|---|---|
| Unity 的 JS brotli | 2268-2590 ms（暖）／3227-4323 ms（冷） |
| **瀏覽器原生 gzip** | **770 ms** |
| 完全不解壓（對照組） | 331-412 ms |

推得吞吐：**瀏覽器原生 gzip ≈ 85 MB/s，Unity 的 JS brotli ≈ 16.3 MB/s，差 5.2 倍。**
體積代價：gzip 為 brotli 的 **1.338** 倍（實測建置 9,836,334 vs 7,353,738）。

⚠ **下表以 brotli 等效大小為單位**，為的是讓三個方案可比；(b) 換算成實際出貨的 gzip 位元組是 **44.3 MB 上限／35 MB 內容**。

| 方案（brotli 等效單位） | S=50MB 的 T_load | 25s 下最大 build | **內容預算** |
|---|---|---|---|
| (a) 現況 brotli＋JS 解壓 @itch | 40.4 s | 28.0 MB | **21.0 MB** |
| **(b) gzip 原生 @itch（已驗證）** | 35.0 s | 33.1 MB | **26.1 MB** |
| (c) brotli 原生 @GitLab Pages | 27.1 s | 45.2 MB | **38.2 MB** |

### 免費主機的部分（curl 複驗過，非只讀文件）

- **GitLab Pages：可行**。`Accept-Encoding: br,gzip → content-encoding: br`。
  但機制是**同名檔協商**而非自訂 header，**Unity 預設會踩死**：
  顯式請求 `.br`（Unity 的 `index.html` 正是這樣寫）拿到的是裸 brotli 且**無 `content-encoding`**，
  瀏覽器解不開，而且沒有錯誤訊息。**必須後處理 `index.html` 把 URL 的 `.br` 拿掉、檔案留著。**
- **GitHub Pages：不行**。Fastly 只吐 gzip，給它 `Accept-Encoding: br` 也不回 br。
  抓到的真實 Unity 部署，其 `.br` 檔開頭是 `0061 736d`（`\0asm`）——**有人把檔案解壓了卻留著 `.br` 檔名**，
  那是「在這裡放棄 brotli」的指紋。
- **Surge.sh：幾乎確定不行**，無 header 設定介面，同樣問題的 issue 掛了十一年。
- **Netlify／Cloudflare Pages／Vercel／Firebase：未驗證**（負責該部分的 agent 中途卡死）。

### 方法論註記

這一輪的收穫不是「查到了哪些主機」，而是**查的過程推翻了問題本身**。
原問題是「哪個免費主機支援 brotli」，隱含前提是「必須換主機」。
而答案是：**不必**——把壓縮格式從 brotli 換成 gzip，就能用上 itch.io **本來就可靠**的那條路
（內容偵測），代價只是 1.338 倍體積，換掉 5.2 倍的解壓 CPU。

⚠ 一併記錄一個沒守住的地方：`design/gdd/netcode-session.md` 的 `[P-6]` 當初寫
「itch.io **不支援** Brotli」。更精確的說法是「itch.io 的 **`.br` 副檔名路徑**不可靠，
但 gzip 的內容偵測路徑可靠」。當時的結論在**當時的建置設定下**是對的，
但它把一個「設定問題」寫成了「主機能力問題」，因而讓後續三批都沒想到要試 gzip。

### 訂正：硬標的單位寫錯了（2026-09-18，定案當日自查發現）

寫入定案後做機械核對，抓到一個**我自己引入的錯誤**，而且是會讓人白白砍掉三成內容的那種。

模型裡的 `S` 一直是 **brotli 等效大小**（為了讓三個方案在同一把尺上比較），
解出來的 33.1 MB 也是 brotli 等效。但寫進 technical-preferences 時，
我把它標成了「**≤33 MB gzip 壓縮後**」——**單位錯置**。

正確值：以**實際出貨的 gzip 位元組**計是 **≤44 MB**（33.1 × 1.338 = 44.3）。
內容預算也跟著從「26 MB」變成「**約 35 MB**」（扣掉 gzip 版地板 9.4 MB）。
**我原本把上限訂得比實際需要嚴 34%。**

連帶的根因是另一個容易混的地方：`build_decompressed_ratio = 4.89` 是 **brotli** 的膨脹比，
而 **gzip 版實測是 3.641**（9,836,334 → 35,811,393）。算 T_load 的解壓項時
必須用與出貨格式相符的那一個。registry 兩個常數都已補上互斥警告。

以實際出貨位元組重算：
```
S÷2.5（20Mbps 下載）＋ 5s（TTFB）＋ S×3.641÷85（原生 gzip 解壓）＋ 0.37s ≤ 25s
→ S ≤ 44.3 MB
```

驗算（這一步反而證明模型是對的，錯的只有標籤）：
現有探針 build 9.38 MB → `3.75 ＋ 5 ＋ 0.40 ＋ 0.37 = 9.5 s`，
其中「解壓＋固定」預測 **0.77 s**，而本機實測 CPU **770 ms**——吻合到毫秒。

**方法論註記**：這個錯誤躲過了我寫入時的檢查，是在 arlong 要求「先確認不要一直寫錯」
之後的核對才抓到的。它躲過去的原因很具體——**三方比較表內部是自洽的**（全用 brotli 等效），
只有跨出那張表、寫進單一數字的硬標時才錯。
教訓：**跨文件搬運一個數字時，單位要跟著搬**，而比較表這種「內部自洽」的東西
最容易讓人忘記它有單位。已在 technical-preferences、registry、藝術聖經三處都明寫單位。

---

## W1 第 4 批（完）— `[P-18]` 離開通知能不能在 unload 時送達（2026-09-18）

W1 的最後一項。它之所以重要，是 GDD 自己標註的那句話：
**「fallback 在 Lobby 情境不成立」**——Lobby 依 #20／#23 不跑心跳，
beacon 送不出時唯一退路是 MPS 服務端 TTL（數十秒），
於是 #25 自述的「留在 Lobby 的人盯著一個說謊的 roster 數十秒」原封不動復活。
換句話說：**這一項沒有退路，只能是真的。**

### 量法

Release build（IL2CPP ＋ Stripping High ＋ Gzip）經 `.jslib` 在
`beforeunload`／`pagehide`／`visibilitychange` 三個事件各掛一次 `navigator.sendBeacon`
（失敗則退 `fetch(keepalive:true)`），送到**同源**的伺服器。

關鍵設計：**送達數由伺服器端數，不採信瀏覽器端「我以為送出了」**。
`sendBeacon` 回傳 `true` 只代表「已排入佇列」，不代表送達——這正是本項要驗的事。

### 結果：8/8 試驗、16/16 筆送達

| 情境 | beforeunload | pagehide |
|---|---|---|
| 頂層導航離開 | ✅ | ✅ |
| **直接關分頁** | ✅ | ✅ |
| iframe 被換掉（×5） | ✅ | ✅ |
| **關掉包著 iframe 的父分頁** | ✅ | ✅ |

最後一列是要害：**那正是 itch.io 的實際形狀**——遊戲跑在 iframe 裡，
玩家關掉的是 itch.io 的分頁。iframe 內的 handler 照樣觸發，beacon 照樣送達。

**`[P-18]` 為真，#12 的離開通知升格為關鍵機制之後，現在有實測支撐；
AC6c、#25 成立；「Lobby 沒有退路」的擔憂不再觸發。**

### 順手掉出來的一條實作要求

`beforeunload` 與 `pagehide` **兩者都會觸發**，間隔 **1-24 ms**。
也就是**每次離開會送出兩筆通知**。

→ **離開通知的處理必須冪等**，否則同一次離開會被當成兩次。
建議以 `pagehide` 為主（跨瀏覽器較可靠、涵蓋 bfcache），`beforeunload` 作為備援。
這條不寫下來，實作時很容易變成「玩家離開一次，roster 掉兩個人」。

### 沒測到的，如實記錄

1. **`visibilitychange` 路徑測不到。** 自動化分頁**一載入就是 `hidden`**
   （已確認 `document.visibilityState === 'hidden'`、本地送出記錄為空），
   不存在 visible→hidden 的轉換事件。
   🔴 **行動瀏覽器切 App 時只有這條路會觸發**，而它未經驗證——
   與 OQ#10（行動端背景回收）同屬行動端缺口，一併追蹤。
2. **確認框那半（AC42）刻意未測。** 瀏覽器 modal 會卡死自動化工具；
   而 #12 早已明寫該行為是 best-effort，其 fallback 本來就可行，
   所以這半的風險本來就低。**刻意不測，不是漏測。**
3. 僅 macOS 桌面 Chrome；未測封包遺失或極慢網路下的送達率。

### 盤點訂正：W1 沒做完（2026-09-18）

寫完 `[P-18]` 之後我在原型 README 寫下「W1 的假設表已全部回填」。
**那是錯的**，機械盤點當場抓到：20 項裡只有 10 項標為結案。

拆開來看：五項本來就屬 W2（`[P-2]`／`[P-5]`／`[P-11]`／`[P-12]`／`[P-16]`），不算數。
但 **W1 自己還有四項沒測**，而且它們有個共同點，這個共同點才是重點——

**四項全部屬於 NGO／WebSocket 傳輸層，而第 1 批測的是 MPS session 層。**

| 項 | 假設 |
|---|---|
| `[P-8]` | Relay 偵測 Host socket 斷開並傳播至其餘 client ≤ `relay_disconnect_propagation_sec`(2s) |
| `[P-13]` | Chrome 使用者主動關閉分頁時 WebSocket close frame **可靠**送達（AC6a 前提） |
| `[P-14]` | 行程被強制終止時退化為心跳路徑且 ≤ `session_end_worstcase_sec`(12s) 全員得知（AC6b） |
| `[P-15]` | `NetworkManager.Shutdown()` 在 WebGL **即時 flush** WebSocket close frame（#17a 前提） |

第 1 批量到的 **132.61s／1.14s** 是 **Lobby** 情境——依 #23 那時**根本還沒有 NGO 連線**，
量的是 MPS 的成員事件傳播。InShift 時有 NGO／Relay 的 WebSocket，斷線語義完全不同。
**兩者不能互相代答**，而我差點讓它們互相代答。

同理，今天的 `[P-18]` 測的是 `sendBeacon`（走 HTTP），
**和 `[P-13]` 的 WebSocket close frame 是兩套機制**——
前者為真不蘊含後者為真。這兩項看起來很像，實際上一點關係都沒有。

**為什麼會寫錯**：第 4 批連續結掉三項（P-6 的 CPU、P-20(b)、P-18），
加上 OQ#17／#20／#21 都收斂了，產生了「這批把剩下的都清完了」的錯覺。
而錯覺沒被文字擋住，是因為我憑印象寫結論，沒有先數。
**教訓與單位那次同源：宣稱「全部完成」之前先跑一次盤點，而不是先寫再查。**

好消息是器材齊了：今天的雙進程 harness（`w1-rtt-run.sh`／`w1-own-run.sh`）
已能在兩進程間建立 Relay WSS 的 NGO 連線，`[P-8]`／`[P-14]`／`[P-15]` 可共用；
`[P-13]` 需要瀏覽器端（關分頁時觀察 close frame 是否送達 Host）。
四項可併為**第 5 批：傳輸層斷線語義**。

---

## W1 第 5 批 — 傳輸層的斷線語義（2026-09-18）

補的是第 1 批漏掉的那一層。第 1 批量的 132.61s／1.14s 是 **MPS session 層**
（當時在 Lobby，依 #23 還沒有 NGO 連線）；本批量的是 **InShift 時 Relay 上的 WebSocket**。

一套 harness、兩種「Host 怎麼消失」：`./w1-disc-run.sh graceful|kill`。
兩個進程同機，故雙方各寫 `UtcNow`，相減即延遲。

### 結果

| 情境 | client 端第一個訊號 | 延遲 | 對照預算 |
|---|---|---|---|
| **Host 呼叫 `Shutdown()`** | `OnClientDisconnectCallback` | **0.08 s** | `relay_disconnect_propagation_sec` 2s ✅ |
| **Host 被 `kill -9`** | `OnClientDisconnectCallback` | **約 87 s** | `session_end_worstcase_sec` 12s 🔴 **超標 7.3 倍** |

`Shutdown()` 本身**回傳只要 2 ms**。

### `[P-15]` 為真 —— close frame 確實即時 flush

2ms 回傳、80ms 端到端。而 80ms 差不多就是到 `asia-northeast1` 的一個 RTT（median 88.8ms），
代表 close frame 是**以網路速度傳播**的，沒有額外的伺服器端延遲。
**#17a 的 teardown 前提成立**，#23a 的局間 teardown 可以放心依賴 `Shutdown()` 的同步語義。

### `[P-14]` 為假 —— 而且連我的悲觀預測都不夠悲觀

跑之前我先立了一個預測：第 0 批查到 `UnityTransport.DisconnectTimeoutMS = 30000`，
若傳輸層只靠它，偵測就是 30 秒 ≫ 12 秒。

**實測 87 秒 —— 是那個常數的近三倍。**

推測原因：**client↔Relay 的連線根本沒斷**。Relay 還在、還可達，
斷掉的是 host↔Relay。client 看不到自己的 socket 逾時，
所以 `DisconnectTimeoutMS` 這個常數在這個情境下**根本不會被觸發**，
只能等服務層判定 —— 那就回到第 1 批 132.61s 的同一個量級。

🔴 **設計後果：#20 的應用層心跳從「機制」升格為「唯一救命索」。**
它是唯一能把 87 秒壓進 12 秒的東西，AC6b 的達成完全依賴它。
已寫進 #20 本文，並註明適用範圍——#20 只在 InShift 跑，
Lobby 階段沒有心跳，那裡靠 #12 的 `beforeunload`（`[P-18]` 已證實送得出去）。

**兩層的分工至此才完整**：Lobby 靠主動通知，InShift 靠心跳，
而**傳輸層的逾時常數在兩邊都救不了**。

### 撞到 UGS 的速率限制，而它的錯誤訊息會騙人

`kill` 模式只取得 **n=1**。第二、三、四次嘗試都失敗，六次重試也全敗，
錯誤訊息一律是：

```
Unity.Services.Multiplayer.SessionException : lobby not found
```

我一度診斷成「前幾次 kill -9 留下的孤兒 session 污染了帳號」——**那是錯的**。
跑一次 graceful 當對照（它先前是通的）發現也壞了，翻日誌才看到真正的原因：**`429`**。

**我們今天跨批次建了太多 session，撞上 UGS Lobby 的速率限制。**
而限流時 `JoinSessionByCodeAsync` 拋的是 **`lobby not found`**，不是 429 —— 
**錯誤訊息指向一個不存在的原因**，害我往孤兒 session 的方向查。

這條值得記進設計：第 1 批已經記過「不能高頻輪詢 session（500ms → 429）」，
本次擴充為 **session 的建立與加入同樣受限，且限流時的錯誤訊息會誤導**。
玩家端的意義：**尖峰時大量開房／加入可能拿到「房間不存在」，而房間其實存在**，
#8 的輸碼失敗提示不該直接說「房號錯誤」。

### n=1 的誠實聲明

`kill` 只有一個樣本，我不打算假裝它是三個。但 **87s vs 12s 的差距遠大於任何合理變異**，
結論（#20 心跳為必需）不因 n=1 而動搖。
待 UGS 限流冷卻後應補 2-3 個樣本，把 87 秒這個數字本身釘準一點。

### `[P-13]` — 瀏覽器關分頁時 close frame 送不出去（2026-09-18，W1 最後一項）

第 5 批之後這一項的意義變了：既然 `kill -9` 要 87 秒、`Shutdown()` 只要 0.08 秒，
那「玩家關分頁」落在哪一側就決定了最常見情境的體驗。

**測法**：把 Web build 變成一個真的 NGO client。探針在帶 `?code=` 時
`AddComponent<W1WebClient>()`（不改場景，因為場景檔已存在、`CreateScene` 不會重跑），
加入 batchmode host 的 session、建立 Relay WSS 上的 NGO 連線，然後關閉分頁。
時間基準借用 `[P-18]` 的 beacon——它在 `beforeunload` 送出、同源伺服器記時；
host 記錄 `OnClientDisconnectCallback` 的時刻。兩者同機，相減即得。

**結果（兩個乾淨樣本）：15.23 秒、18.99 秒。**

**15-19 秒這個量級本身就是證據。** 若真有 close frame，偵測應該是一個 RTT——
同一批的 graceful `Shutdown()` 實測 **0.08 秒**。落在十幾秒代表**沒有 close frame，只有逾時**。

### 三種離開方式的完整光譜

| 離開方式 | 偵測延遲 | 對照 AC6b 的 12s |
|---|---|---|
| Host 呼叫 `Shutdown()` | **0.08 s** | ✅ |
| **瀏覽器關分頁** | **15-19 s** | 🔴 |
| 行程被 `kill -9` | **約 87 s** | 🔴 |

**傳輸層在「玩家關分頁」這個最常見的情境下也救不了。**

但出口是現成的，而且是這一批之前就鋪好的：`[P-18]` 已證實 `beforeunload` 的 `sendBeacon`
在**毫秒級**送達（8/8，含 iframe 父分頁關閉）。
→ **#12 的主動離開通知，對「偵測」而言不是 best-effort，是唯一的快路徑。**

⚠ 這裡要把語義切開，否則會誤讀 #12：
**離開通知＝關鍵機制**（有實測）；**攔阻確認框＝仍是 best-effort**
（瀏覽器政策決定，且 `[P-18]` 刻意未測）。兩者剛好寫在同一條規則裡，很容易混為一談。

### 一個沒解釋的觀察，不當結論但要留著

第二次嘗試時，client 在**連上 24.5 秒後自己斷了**——我還沒關分頁。
第一次撐了 30 秒沒事，第三次只存活 19 秒就被我關掉，所以**樣本不足以判斷**。

值得留意的是它與第 3 批有張力：第 3 批量的是**主迴圈**被節流到 1 Hz，
然後**推論**「10 秒的 MPS heartbeat 與 500ms 的 Relay PING 都送得出去」。
但第 3 批**沒有真的測過背景分頁裡的 NGO 連線**——而本次的自動化分頁一載入就是 `hidden`。

若那 24.5 秒是真的，代表**背景分頁會掉 NGO 連線**，第 3 批的推論就有洞。
⚠ **目前證據不足（1 次異常 vs 2 次正常），不寫進任何規則**，
但列為 W1 結案後的待驗項，且它與 OQ#10（行動端背景回收）屬同一類問題。

### W1 假設表至此全數回填

20 項中 **15 項結案**，其餘 5 項（`[P-2]`／`[P-5]`／`[P-11]`／`[P-12]`／`[P-16]`）
**本來就屬 W2**，不在 W1 範圍。
