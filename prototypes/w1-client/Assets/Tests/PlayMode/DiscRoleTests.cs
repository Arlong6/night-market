// W1 原型 — 第 5 批：傳輸層的斷線語義（[P-8]／[P-14]／[P-15]）
//
// 為什麼需要新的一批：第 1 批量到的 132.61s／1.14s 是 **MPS session 層**的成員事件，
// 當時在 Lobby，依 #23 **根本還沒有 NGO 連線**。InShift 時有 Relay 上的 WebSocket，
// 斷線語義完全不同，兩層不能互相代答。本批補的就是傳輸層那半。
//
// 三個假設共用同一套 harness，只差「Host 怎麼消失」：
//   [P-15] Host 呼叫 NetworkManager.Shutdown() → close frame 是否**即時** flush（#17a 前提）
//   [P-8]  Relay 偵測 socket 斷開並傳播至其餘 client ≤ relay_disconnect_propagation_sec(2s)
//   [P-14] Host 行程被 kill -9 → 多久全員得知？AC6b 要求 ≤ session_end_worstcase_sec(12s)
//
// 對 [P-14] 有個可先立的預測：第 0 批查到 UnityTransport.DisconnectTimeoutMS = 30000。
// 若傳輸層只靠它，偵測就是 30s ≫ 12s —— 那就**證明 #20 的應用層心跳不是優化而是必需**。
//
// 兩個進程的時鐘同機，故雙方各寫 UtcNow，相減即延遲。
//
// 對應 GDD：[P-8]／[P-13]／[P-14]／[P-15]、AC6a／AC6b、#17a、#20、約束⑬

using System;
using System.Collections;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using NUnit.Framework;
using Unity.Netcode;
using Unity.Netcode.Transports.UTP;
using Unity.Services.Multiplayer;
using UnityEngine;
using UnityEngine.TestTools;
using Debug = UnityEngine.Debug;

namespace W1.Tests.PlayMode
{
    public static class W1Disc
    {
        /// -w1mode graceful ＝ 測 [P-15]／[P-8]；kill ＝ 測 [P-14]（由 shell 執行 kill -9）
        public static string Mode
        {
            get
            {
                var a = Environment.GetCommandLineArgs();
                for (int i = 0; i < a.Length - 1; i++) if (a[i] == "-w1mode") return a[i + 1];
                return "graceful";
            }
        }

        public static void Spawn(out GameObject go, uint tick)
        {
            go = new GameObject("W1_NM_Disc");
            var nm = go.AddComponent<NetworkManager>();
            var utp = go.AddComponent<UnityTransport>();
            utp.UseWebSockets = true;
            nm.NetworkConfig = new NetworkConfig
            {
                NetworkTransport = utp,
                TickRate = tick,
                EnableSceneManagement = false,
            };
            nm.LogLevel = LogLevel.Developer;
            Debug.Log($"[W1DISC] NM 建立 tick={tick} " +
                      $"DisconnectTimeoutMS={utp.DisconnectTimeoutMS} " +
                      $"HeartbeatTimeoutMS={utp.HeartbeatTimeoutMS} " +
                      $"ConnectTimeoutMS={utp.ConnectTimeoutMS}");
        }
    }

    public class W1DiscHost
    {
        private GameObject m_Go;

        [TearDown] public void TearDown()
        {
            if (NetworkManager.Singleton != null && NetworkManager.Singleton.IsListening)
                NetworkManager.Singleton.Shutdown();
            if (m_Go != null) UnityEngine.Object.DestroyImmediate(m_Go);
        }

        [UnityTest]
        public IEnumerator RunDiscHost()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                LogAssert.ignoreFailingMessages = true;
                await W1Io.SignInAsync();
                W1Disc.Spawn(out m_Go, W1Rtt.Tick);

                var session = await MultiplayerService.Instance.CreateSessionAsync(W1Own.HostOpts());
                await session.Network.StartRelayNetworkAsync(W1Rtt.RelayOpts());
                var nm = NetworkManager.Singleton;
                Debug.Log($"[W1DISC][host] up Code={session.Code} mode={W1Disc.Mode}");

                W1Io.Write("code.txt", session.Code);
                W1Io.Write("host-ready.txt", DateTime.UtcNow.ToString("O"));

                // 等 client 的 NGO 真的連上（不是只加入 session）
                ulong cid = 0;
                for (int i = 0; i < 300 && cid == 0; i++)
                {
                    cid = nm.ConnectedClientsIds.FirstOrDefault(c => c != NetworkManager.ServerClientId);
                    await Task.Delay(100);
                }
                Assert.AreNotEqual(0UL, cid, "client 的 NGO 未連上。");
                Debug.Log($"[W1DISC][host] client={cid} 已連上");

                // 等 client 表示「我已經開始計時」
                for (int i = 0; i < 300 && W1Io.Read("client-armed.txt") == null; i++) await Task.Delay(100);
                await Task.Delay(1500);

                if (W1Disc.Mode == "graceful")
                {
                    // [P-15]：Shutdown() 是否即時 flush close frame
                    W1Io.Write("host-action-at.txt", DateTime.UtcNow.ToString("O"));
                    var sw = Stopwatch.StartNew();
                    nm.Shutdown();
                    Debug.Log($"[W1DISC][host] Shutdown() 回傳耗時 {sw.Elapsed.TotalMilliseconds:F0} ms, " +
                              $"IsListening={nm.IsListening}");
                    W1Io.Write("host-shutdown-returned-ms.txt", sw.Elapsed.TotalMilliseconds.ToString("F0"));
                }
                else
                {
                    // [P-14]：保持存活，等 shell 送 kill -9。寫下「我還活著」的最後時刻。
                    W1Io.Write("host-action-at.txt", DateTime.UtcNow.ToString("O"));
                    Debug.Log("[W1DISC][host] 等待外部 kill -9…");
                }

                var wait = Stopwatch.StartNew();
                while (wait.Elapsed.TotalSeconds < 300 && W1Io.Read("result.txt") == null)
                    await Task.Delay(200);
                try { await session.AsHost().DeleteAsync(); } catch { }
            }
        }
    }

    public class W1DiscClient
    {
        private GameObject m_Go;

        [TearDown] public void TearDown()
        {
            if (NetworkManager.Singleton != null && NetworkManager.Singleton.IsListening)
                NetworkManager.Singleton.Shutdown();
            if (m_Go != null) UnityEngine.Object.DestroyImmediate(m_Go);
        }

        [UnityTest]
        public IEnumerator RunDiscClient()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                LogAssert.ignoreFailingMessages = true;
                await W1Io.SignInAsync();
                W1Disc.Spawn(out m_Go, W1Rtt.Tick);

                string code = null;
                for (int i = 0; i < 480 && code == null; i++)
                {
                    if (W1Io.Read("host-ready.txt") != null) code = W1Io.Read("code.txt");
                    await Task.Delay(250);
                }
                Assert.IsNotNull(code, "host 未就緒。");

                // ⚠ 實測到 JoinSessionByCodeAsync 會間歇拋 SessionException: lobby not found
                //   （同一份程式碼兩次成功、兩次失敗）。看起來是建立後到可被 code 查到之間
                //   有傳播延遲，或今天建了太多 session 而被限流。重試而非放棄。
                ISession session = null;
                for (int attempt = 1; attempt <= 6 && session == null; attempt++)
                {
                    try
                    {
                        session = await MultiplayerService.Instance.JoinSessionByCodeAsync(code,
                            new JoinSessionOptions()
                                .WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS }));
                    }
                    catch (Exception e)
                    {
                        Debug.Log($"[W1DISC][client] join 第 {attempt} 次失敗：{e.Message}");
                        if (attempt == 6) throw;
                        await Task.Delay(3000);
                    }
                }
                var nm = NetworkManager.Singleton;
                for (int i = 0; i < 300 && !nm.IsConnectedClient; i++) await Task.Delay(100);
                Assert.IsTrue(nm.IsConnectedClient, "NGO client 未連上。");
                Debug.Log($"[W1DISC][client] NGO 已連上 Code={code}");

                // 兩條偵測路徑都記，看哪條先到
                string firstSignal = null; DateTime firstAt = default;
                void Mark(string which)
                {
                    if (firstSignal != null) return;
                    firstSignal = which; firstAt = DateTime.UtcNow;
                    Debug.Log($"[W1DISC][client] 偵測到：{which} @ {firstAt:O}");
                }
                nm.OnClientDisconnectCallback += id => Mark($"OnClientDisconnectCallback(id={id})");
                session.PlayerHasLeft += id => Mark($"MPS.PlayerHasLeft({id})");
                session.Deleted += () => Mark("MPS.Deleted");

                W1Io.Write("client-armed.txt", DateTime.UtcNow.ToString("O"));

                // 輪詢 transport 層的連線狀態當第三條路
                var sw = Stopwatch.StartNew();
                // ⚠ 第一次跑設 90s：callback 在 90.9s 才進來、剛好被切掉，
                //    result.txt 誤記為 NONE 而日誌裡其實有。改 240s。
                while (sw.Elapsed.TotalSeconds < 240 && firstSignal == null)
                {
                    if (!nm.IsConnectedClient) Mark("IsConnectedClient==false（輪詢）");
                    await Task.Delay(50);
                }

                var actionRaw = W1Io.Read("host-action-at.txt");
                var line = firstSignal == null
                    ? "signal=NONE;seconds=timeout(240)"
                    : $"signal={firstSignal};" +
                      (actionRaw != null
                        ? $"seconds={(firstAt - DateTime.Parse(actionRaw, null, System.Globalization.DateTimeStyles.RoundtripKind)).TotalSeconds:F2};"
                        : "seconds=?;") +
                      $"mode={W1Disc.Mode}";
                Debug.Log($"[W1DISC][client] {line}");
                W1Io.Write("result.txt", line);
                try { await session.LeaveAsync(); } catch { }
            }
        }
    }
}
