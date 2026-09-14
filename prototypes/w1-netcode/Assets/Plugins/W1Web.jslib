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

  W1_Now: function () { return performance.now(); }
});
