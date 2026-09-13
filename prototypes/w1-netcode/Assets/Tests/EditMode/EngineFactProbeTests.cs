// W1 原型 — 第 0 批引擎事實的「實機複驗」
//
// 第 0 批（2026-09-13）是純文件查詢，結論來自 NGO 2.13.2 原始碼與官方文件。
// 本檔把那些結論降落到**這台機器上實際安裝的套件**，因為套件解析出來的
// com.unity.transport 是 2.7.4，而查證時依 NGO 相依宣告寫的是 2.6.0。
//
// 測試刻意「斷言查到的值」：若某一條 fail，代表 GDD 裡回填的引擎事實與實機不符，
// 必須立刻回頭改 design/gdd/netcode-session.md，而不是改這裡的期望值。
//
// 對應 GDD：design/gdd/netcode-session.md 的 [P-3] / [P-9] / [P-20] 回填欄位
// 與 Core Rules #2 / #6 / #20 / #24、約束 ⑤⑧。

using NUnit.Framework;
using Unity.Netcode;
using Unity.Netcode.Components;
using Unity.Netcode.Transports.UTP;
using UnityEngine;

namespace W1.Tests.EditMode
{
    public class EngineFactProbeTests
    {
        // ── [P-9] UnityTransport 逾時 ────────────────────────────────
        // GDD 約束⑤ 依賴「內建逾時 ≫ app 心跳 8s」。
        // 文件查證值（UTP 2.6 文件）：Disconnect 30000ms / Heartbeat 500ms。
        // 實機是 UTP 2.7.4，故必須複驗。

        [Test]
        public void P9_UnityTransport_DisconnectTimeout_預設應為30000ms()
        {
            var go = new GameObject("probe_utp");
            try
            {
                var utp = go.AddComponent<UnityTransport>();
                Debug.Log($"[W1][P-9] DisconnectTimeoutMS = {utp.DisconnectTimeoutMS}");
                Assert.AreEqual(30000, utp.DisconnectTimeoutMS,
                    "GDD 約束⑤ 寫死 30s。若此值改變，約束⑤ 的餘裕論證與 AC27 都要重算。");
            }
            finally { Object.DestroyImmediate(go); }
        }

        [Test]
        public void P9_內建逾時必須大於app心跳逾時_約束5()
        {
            const int heartbeatTimeoutSec = 8; // GDD heartbeat_timeout_sec
            var go = new GameObject("probe_utp");
            try
            {
                var utp = go.AddComponent<UnityTransport>();
                var builtInSec = utp.DisconnectTimeoutMS / 1000f;
                Debug.Log($"[W1][P-9] 內建 {builtInSec}s vs app 心跳 {heartbeatTimeoutSec}s");
                Assert.Greater(builtInSec, heartbeatTimeoutSec,
                    "app 層心跳必須是更早的判定者，否則判定權落到引擎手上，" +
                    "GDD #24 的斷線處置序列不會被執行。");
            }
            finally { Object.DestroyImmediate(go); }
        }

        [Test]
        public void P9_HeartbeatTimeout_預設應為500ms_且身兼RelayPING間隔()
        {
            var go = new GameObject("probe_utp");
            try
            {
                var utp = go.AddComponent<UnityTransport>();
                Debug.Log($"[W1][P-9] HeartbeatTimeoutMS = {utp.HeartbeatTimeoutMS}");
                Assert.AreEqual(500, utp.HeartbeatTimeoutMS,
                    "此值同時是 Relay PING 間隔。Relay 對每個 client 連線的 TTL 是 10s，" +
                    "故本值不得調到 >10000ms，否則 keepalive 失效。GDD Tuning Knobs 已標記不得調動。");
                Assert.Less(utp.HeartbeatTimeoutMS, 10000,
                    "必須小於 Relay client TTL（10s），否則連線會被服務端回收。");
            }
            finally { Object.DestroyImmediate(go); }
        }

        // ── [P-3] tick rate 與送出頻率 ───────────────────────────────
        // 第 0 批結論：TickRate 預設 30；它決定 NetworkVariable 與 NetworkTransform 的
        // 送出節奏，但**不影響 RPC**（RPC 每幀於 PostLateUpdate 送出）。
        // 這條把 AC22 從「必然不可達」翻成「可達」，是本輪最關鍵的翻案，必須複驗預設值。

        [Test]
        public void P3_NetworkConfig_TickRate_預設應為30()
        {
            var cfg = new NetworkConfig();
            Debug.Log($"[W1][P-3] NetworkConfig.TickRate 預設 = {cfg.TickRate}");
            Assert.AreEqual(30u, cfg.TickRate,
                "GDD 記錄引擎預設為 30、本專案擬設 10。若引擎預設改變，" +
                "『設 10 會把 NetworkVariable 一起降頻』這條註記要重寫。");
        }

        // ── [P-20a] owner 斷線時的物件處置 ───────────────────────────
        // 這是本輪最硬的一條：預設 false ＝ 預設銷毀，且銷毀發生在
        // OnClientDisconnectCallback 之前。GDD #24 已據此補上 prefab 前置條件。

        [Test]
        public void P20a_NetworkObject_DontDestroyWithOwner_預設應為false()
        {
            var go = new GameObject("probe_netobj");
            try
            {
                var no = go.AddComponent<NetworkObject>();
                Debug.Log($"[W1][P-20a] DontDestroyWithOwner 預設 = {no.DontDestroyWithOwner}");
                Assert.IsFalse(no.DontDestroyWithOwner,
                    "預設 false ＝ owner 斷線時其 owned NetworkObject 會被 despawn+destroy。" +
                    "GDD #24 的前置條件（道具 prefab 必須顯式勾選）正是為此而存在。" +
                    "若此預設值改為 true，該前置條件可以放寬，但 AC56 仍應保留。");
            }
            finally { Object.DestroyImmediate(go); }
        }

        // ── Core Rule #2 的更正複驗 ──────────────────────────────────
        // r4 原文誤寫「Owner 權威是 NetworkTransform 預設，不改寫」。
        // 第 0 批查證：client-server 下 AuthorityMode 預設是 Server，必須顯式改寫。
        // 這條若 fail，代表 GDD #2 的更正本身是錯的。

        [Test]
        public void CoreRule2_NetworkTransform_AuthorityMode_預設應為Server()
        {
            var go = new GameObject("probe_nt");
            try
            {
                var nt = go.AddComponent<NetworkTransform>();
                Debug.Log($"[W1][#2] NetworkTransform.AuthorityMode 預設 = {nt.AuthorityMode}");
                Assert.AreEqual(NetworkTransform.AuthorityModes.Server, nt.AuthorityMode,
                    "GDD #2 已於 r4 更正為『必須顯式設 Owner，不是不改寫』。" +
                    "若此處實際為 Owner，代表那條更正下錯了，要回頭改 GDD。");
            }
            finally { Object.DestroyImmediate(go); }
        }

        [Test]
        public void CoreRule2_NetworkTransform_Interpolate_預設應為true()
        {
            var go = new GameObject("probe_nt");
            try
            {
                var nt = go.AddComponent<NetworkTransform>();
                Debug.Log($"[W1][#2] NetworkTransform.Interpolate 預設 = {nt.Interpolate}");
                Assert.IsTrue(nt.Interpolate,
                    "GDD 的插值緩衝論述（interpolation_buffer_ms）建立在預設開啟之上。");
            }
            finally { Object.DestroyImmediate(go); }
        }

        // ── 版本落差記錄 ─────────────────────────────────────────────
        // 不是斷言，是把實機版本印進 log，讓原型報告可以直接引用。

        [Test]
        public void 記錄實機套件版本落差()
        {
            Debug.Log("[W1][版本] 第 0 批查證依 NGO 相依宣告記為 com.unity.transport 2.6.0，" +
                      "但本機解析結果為 2.7.4。上列逾時斷言即為此落差而存在。");
            Assert.Pass("僅記錄，不斷言。");
        }
    }
}
