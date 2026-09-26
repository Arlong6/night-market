# w1-pointerlock-probe

**假說**：itch.io 的 iframe 允許 `requestPointerLock()`。

若為否，第一人稱控制器（`design/gdd/first-person-controller.md`）在既定發行通路上不成立
——依該 GDD 的 OQ-F1，「失敗則不是調參數，是重畫」。這是該檔**風險最高、驗證成本最低**的一項。

順帶驗證 **OQ-F2**（`look_deg_per_unit` 待校正）：鎖定期間取樣 `movementX/Y`，
本專案對「Web 上滑鼠位移的單位」零筆記載，這是第一筆。

## 怎麼跑

```bash
cd prototypes/w1-pointerlock-probe
python3 -m http.server 8787 --bind 127.0.0.1
```

- **本機鑑別力驗證**：<http://127.0.0.1:8787/local-harness.html>
  左右兩格載入同一個 `index.html`，只差一個 sandbox token（A 有 `allow-pointer-lock`，B 沒有）。
  **各點一下兩格**。A 應成功、B 應失敗。若兩格都成功，探針沒有鑑別力，不可採信。
- **itch.io 實測**：把 `index.html` 推上去後在遊戲頁點擊。
  ```bash
  GODEBUG=http2client=0 ~/.local/bin/butler push . <user>/<slug>:html5
  ```
  `GODEBUG=http2client=0` 是必要的——此網路會殺掉 Go 的 HTTP/2 長上傳。

## 狀態

🟢 **已結案（2026-09-26）。OQ-F1 通過：itch.io 的 iframe 內指標鎖定可用。**

部署：`arlong666/w1-pointerlock-probe:html5`（Draft），build `#2018235`。

## 發現

### 已確立（2026-09-26，本機）

0. 🟢 **探針有鑑別力**（arlong 手動點擊 `local-harness.html` 確認）：
   A 格（sandbox 含 `allow-pointer-lock`）變綠、鎖定成功；
   B 格（不含）變紅、鎖定失敗。**同一份 `index.html`，只差一個 sandbox token。**
   → 一個「永遠回報成功」的探針已被排除，itch.io 的結果可以採信。
   ⚠ 該次點擊發生在未插儀器的視窗，故**未留下 `movementX/Y` 數值**；OQ-F2 的取樣留到 itch.io 那一輪。

1. **`document.featurePolicy.allowedFeatures()` 不能用來預測 pointer lock 是否可用。**
   即使 iframe 的 sandbox **含有** `allow-pointer-lock`，該清單裡**依然沒有** `pointer-lock`。
   → 這回答了 OQ-F1 懸著的一半：GDD 原文說「受 sandbox token 與 Permissions Policy
   **兩個不同機制**管，哪一個生效未確認」——Permissions Policy 根本不列這個 feature，
   **唯一可靠的訊號是實際呼叫 `requestPointerLock()` 並觀察結果**。探針據此設計。

2. **opaque-origin（sandbox 無 `allow-same-origin`）的 iframe 內容，父層讀不到
   `contentDocument`，且在截圖裡不保證被合成**（OOPIF 站台隔離）。
   → 探針改以 `postMessage` 回報，父層才取得到值。**itch.io 是跨域 iframe，
   同一限制成立**——這也是為什麼探針把結果印在自己畫面上（大字、可直接看），
   而不是只寫 console：W1 已實測 itch.io 的 iframe `allow` 不含 `clipboard-write`，
   複製不出來。

3. **自動化送不進 OOPIF 的可信點擊**，所以 A/B 兩格的最終判定需要人手點一次。

### 🟢 itch.io 實測結果（2026-09-26，Chrome / macOS，dPR=2）

**OQ-F1 通過。**

```
🔴 結果                       : ✅ 指標鎖定成功取得（在 iframe 內）
嘗試次數                      : 1（第一次就成功）
requestPointerLock 回傳       : Promise → resolved
錯誤細節                      : —
Esc 後能否重鎖                : ✅ 解除後再次點擊可重新取得鎖定（嘗試次數 2）
allowedFeatures 含 pointer-lock : 否   ← 而它照樣成功了
```

**4. itch.io 的遊戲 iframe 沒有 `sandbox` 屬性。** 實測其屬性：

```
sandbox : （不存在）
allow   : autoplay; fullscreen *; geolocation; microphone; camera; midi;
          monetization; xr-spatial-tracking; gamepad; gyroscope;
          accelerometer; xr; cross-origin-isolated; web-share
```

pointer lock 在 iframe 中由 sandbox 的 `allow-pointer-lock` token 管——**沒有 sandbox
屬性就沒有那條限制**。這是 OQ-F1 為真的結構性原因。

🔴 **GDD 對 OQ-F1 的擔憂建立在一個錯誤類比上，應予更正。** 原文以
「`clipboard-write` 缺席確實導致 Clipboard API 被擋，『缺席＝被擋』在這個平台有前例」
支持對 pointer lock 的憂慮。但 `clipboard-write` **是** Permissions Policy feature，
`pointer-lock` **不是**（見發現 1）。**拿 `allow` 字串推論 pointer lock 可用性，
從一開始就是問錯問題。**

**5. C15 的實測邊界要講清楚。** 已證實：**一次玩家點擊可重新取得鎖定，未觀察到 UA 抑制。**
未測：「不帶新手勢的自動重鎖會失敗」——探針只在點擊時請求。該半在操作上無影響，
因為 AC27 本就禁止發出任何自動重鎖呼叫。C15 的設計結論成立，且那條路已知是通的。

**6. OQ-F2 第一筆數據（不足以定值，但有一條結構性結論）**

```
取樣數 62 ｜ |movement| 最大 5.00 ｜ 平均（非零）1.650
累計 |ΔX| / |ΔY| = 71.0 / 30.0 ｜ devicePixelRatio = 2
movement 對 screenX：screenX 完全凍結 → movement 是唯一訊號
```

✅ **可直接寫進 GDD**：鎖定期間 `screenX` 不動，**`movementX/Y` 是唯一的視角訊號來源**。
⬜ **仍待確立**：`look_deg_per_unit` 的換算係數。上述為隨手甩動的樣本，
要定值需一次「移動已知物理距離」的受控量測，且需涵蓋 dPR≠2 的機器。

## 檔案

- `index.html` — 探針本體。**這是要推上 itch.io 的東西。**
- `local-harness.html` — 本機 A/B 鑑別力驗證。**不要部署**（推上去也無害，itch.io 只會播 `index.html`）。
