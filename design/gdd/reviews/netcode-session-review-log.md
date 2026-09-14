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
