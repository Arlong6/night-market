// W1 原型 — Web 平台橋接
// 驗 [P-4]（itch.io iframe 是否轉發 ?code=）、[P-19]（clipboard）、[P-7]（.jslib + Stripping）
mergeInto(LibraryManager.library, {

  W1_GetOwnQuery: function () {
    var s = window.location.search || "";
    var b = lengthBytesUTF8(s) + 1, p = _malloc(b);
    stringToUTF8(s, p, b); return p;
  },

  // itch.io 把遊戲放在 iframe 裡。帶碼連結的 query 會留在**父視窗**，
  // 子 iframe 的 location.search 可能是空的 —— 這正是 [P-4] 要測的。
  W1_GetParentQuery: function () {
    var s = "";
    try { s = window.parent.location.search || ""; }      // 同源才讀得到
    catch (e) { s = "__CROSS_ORIGIN_BLOCKED__"; }
    var b = lengthBytesUTF8(s) + 1, p = _malloc(b);
    stringToUTF8(s, p, b); return p;
  },

  W1_GetReferrer: function () {
    var s = "";
    try { s = document.referrer || ""; } catch (e) { s = "__BLOCKED__"; }
    var b = lengthBytesUTF8(s) + 1, p = _malloc(b);
    stringToUTF8(s, p, b); return p;
  },

  W1_IsInIframe: function () {
    try { return (window.self !== window.top) ? 1 : 0; } catch (e) { return 1; }
  },

  // [P-19] clipboard 需要 user gesture，且 iframe 可能被 permissions policy 擋掉
  W1_TryCopy: function (textPtr, objPtr, methodPtr) {
    var text = UTF8ToString(textPtr);
    var obj = UTF8ToString(objPtr), method = UTF8ToString(methodPtr);
    function report(r) { try { SendMessage(obj, method, r); } catch (e) {} }
    if (!navigator.clipboard || !navigator.clipboard.writeText) {
      report("NO_API"); return;
    }
    navigator.clipboard.writeText(text)
      .then(function () { report("OK"); })
      .catch(function (e) { report("DENIED:" + (e && e.name ? e.name : "unknown")); });
  },

  // [P-7] 背景分頁偵測所需的訊號來源
  W1_GetVisibility: function () {
    var s = document.visibilityState || "unknown";
    var b = lengthBytesUTF8(s) + 1, p = _malloc(b);
    stringToUTF8(s, p, b); return p;
  },

  W1_GetOnline: function () { return navigator.onLine ? 1 : 0; },


  // ── [P-18] 離開通知能不能在 unload 時送達 ──────────────────────────
  // 為什麼這半比「確認框」那半重要得多：GDD 自述 fallback 在 Lobby 情境**不成立**——
  // Lobby 依 #20／#23 不跑心跳，beacon 送不出時唯一退路是 MPS 服務端 TTL（數十秒），
  // 於是 #25 的「留在 Lobby 的人盯著一個說謊的 roster」原封不動復活。
  //
  // 三個事件全部掛上，因為它們的可靠度不同且各有陷阱：
  //   beforeunload      —— 行動瀏覽器常常不觸發；有互動才准跳確認框
  //   pagehide          —— 較可靠，且涵蓋 bfcache
  //   visibilitychange  —— 切分頁／切 App 時就會觸發，是行動端唯一穩的
  // 每次送出都標明是哪個事件觸發的，才看得出該押哪一個。
  W1_InstallUnloadBeacon: function (urlPtr, tagPtr) {
    var url = UTF8ToString(urlPtr), tag = UTF8ToString(tagPtr);
    if (window.__w1beacon) { return; }
    window.__w1beacon = { sent: [] };

    function send(ev) {
      var payload = tag + "|" + ev + "|" + Math.round(performance.now());
      var ok = false;
      try {
        // sendBeacon 的整個存在理由就是「unload 時仍會送出」
        if (navigator.sendBeacon) { ok = navigator.sendBeacon(url, payload); }
      } catch (e) { ok = false; }
      if (!ok) {
        // 退路：keepalive 的 fetch。語義相同，但瀏覽器支援度與配額不同，
        // 值得知道它在 beacon 失敗時能不能接住。
        try {
          fetch(url, { method: "POST", body: payload + "|viaKeepalive", keepalive: true });
          ok = true;
        } catch (e2) {}
      }
      window.__w1beacon.sent.push(ev + ":" + (ok ? "ok" : "fail"));
    }

    window.addEventListener("beforeunload", function () { send("beforeunload"); });
    window.addEventListener("pagehide", function () { send("pagehide"); });
    document.addEventListener("visibilitychange", function () {
      if (document.visibilityState === "hidden") { send("visibilityhidden"); }
    });
  },

  // 回報本地端「自己以為送出了幾筆」，與伺服器端實收數對照才知道到達率
  W1_GetBeaconLog: function () {
    var s = (window.__w1beacon && window.__w1beacon.sent.join(",")) || "";
    var b = lengthBytesUTF8(s) + 1, p = _malloc(b);
    stringToUTF8(s, p, b); return p;
  },

  W1_Now: function () { return performance.now(); }
});
