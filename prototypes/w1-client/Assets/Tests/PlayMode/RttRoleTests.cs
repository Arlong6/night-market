// W1 原型 — 第 4 批：互動往返延遲（AC22，MVP 必達）
//
// 要驗的是第 0 批從原始碼推出、但一直沒有實測的那個結論：
//   **RPC 不受 network tick 影響**（每幀於 PostLateUpdate 批次送出），
//   受 tick 影響的只有 NetworkVariable 與 NetworkTransform。
// 若結論為真，AC22（互動往返 P95 ≤300ms）在 10Hz tick 下可達成；
// 若為假，約束⑧ 會讓它數學上不可能。
//
// 測法用 `CustomMessagingManager` 的 named message 而非 `[Rpc]`：兩者走的是**同一條**
// 傳輸路徑（MessageManager → PostLateUpdate → transport），但 named message 不需要
// NetworkObject／prefab 註冊，在 batchmode 雙進程下設定成本低得多。
// 量到的是傳輸路徑本身的延遲，那正是 AC22 的分母。
//
// 由外部 shell 以 -testFilter 指定角色，兩個進程分別跑（Unity 不允許兩實例開同一專案）。
//
// 對應 GDD：design/gdd/netcode-session.md 的 AC22、約束⑧、[P-3]、OQ#1

using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using NUnit.Framework;
using Unity.Collections;
using Unity.Netcode;
using Unity.Netcode.Transports.UTP;
using Unity.Services.Multiplayer;
using UnityEngine.TestTools;
using Debug = UnityEngine.Debug;

namespace W1.Tests.PlayMode
{
    public static class W1Rtt
    {
        public const string Ping = "w1_ping";
        public const string Pong = "w1_pong";
        public const int Samples = 20;

        /// tick 與 region 由命令列帶入，讓對照組與實驗組跑**完全同一份程式碼**。
        /// -w1tick 1 與 -w1tick 10 的結果若相同，即證明 RPC 不受 tick 閘門控制。
        public static uint Tick => Arg("-w1tick", "10") is var s && uint.TryParse(s, out var v) ? v : 10u;
        public static string Region => Arg("-w1region", "");

        private static string Arg(string key, string fallback)
        {
            var args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length - 1; i++)
                if (args[i] == key) return args[i + 1];
            return fallback;
        }

        /// region 空字串代表用預設（Relay 自行挑，Web 上 QoS 不可用故無法自動選最近的）
        public static RelayNetworkOptions RelayOpts()
            => string.IsNullOrEmpty(Region) ? new RelayNetworkOptions()
                                            : new RelayNetworkOptions(Region);

        public static void SpawnNetworkManager(out UnityEngine.GameObject go, uint tickRate)
        {
            go = new UnityEngine.GameObject("W1_NM_Rtt");
            var nm = go.AddComponent<NetworkManager>();
            var utp = go.AddComponent<UnityTransport>();
            // 目標平台是 Web，故明確走 WebSocket；Relay 端也必須是 WSS，否則
            // 會拋 ArgumentException: Mismatched Relay configuration and network interface
            utp.UseWebSockets = true;
            nm.NetworkConfig = new NetworkConfig
            {
                NetworkTransport = utp,
                TickRate = tickRate,     // ← 這個值是否影響 RTT，正是本測試要回答的
                // PlayMode 的測試場景不在 build list，NGO 的場景同步會拋
                //   Scene Hash ... does not exist in the HashToBuildIndex table
                // 本測試只量傳輸往返，不需要場景同步。
                // ⚠ 這個值**兩端必須一致**，否則 NGO 在握手階段就拒絕連線。
                EnableSceneManagement = false,
            };
            Debug.Log($"[W1RTT] NetworkManager 建立，TickRate={tickRate}");
        }
    }

    /// shell 以 -testFilter "W1RttHost" 啟動
    public class W1RttHost
    {
        private UnityEngine.GameObject m_Go;

        [TearDown]
        public void TearDown()
        {
            if (NetworkManager.Singleton != null && NetworkManager.Singleton.IsListening)
                NetworkManager.Singleton.Shutdown();
            if (m_Go != null) UnityEngine.Object.DestroyImmediate(m_Go);
        }

        [UnityTest]
        public IEnumerator RunRttHost()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                await W1Io.SignInAsync();

                // 順手把可用 region 印出來：Web 上 QoS 不能用（PlatformNotSupportedException），
                // region 只能靠預設或顯式指定，所以「有哪些可選」本身就是設計要用的資料。
                try
                {
                    var regions = await Unity.Services.Relay.RelayService.Instance.ListRegionsAsync();
                    Debug.Log("[W1RTT][host] Relay regions: " +
                              string.Join(", ", regions.Select(r => r.Id)));
                }
                catch (Exception e) { Debug.Log($"[W1RTT][host] ListRegions 失敗: {e.Message}"); }

                W1Rtt.SpawnNetworkManager(out m_Go, tickRate: W1Rtt.Tick);   // 預設 = GDD 的 network_tick_rate

                // ⚠ Relay protocol **只能在建 session 時**經 WithNetworkOptions 指定——
                // RelayNetworkOptions(RelayProtocol) 已 Obsolete，而 StartRelayNetworkAsync
                // 沒有 protocol 參數。好消息是 WithNetworkOptions 只設定不啟動，
                // 因此「延後建連」與「指定 WSS」可以並存。
                var session = await MultiplayerService.Instance.CreateSessionAsync(
                    new SessionOptions { MaxPlayers = 4 }
                        .WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS }));
                Debug.Log($"[W1RTT][host] session 建立 NetworkState={session.Network.State}（應為 Stopped）");
                await session.Network.StartRelayNetworkAsync(W1Rtt.RelayOpts());

                var nm = NetworkManager.Singleton;
                Debug.Log($"[W1RTT][host] Code={session.Code} IsListening={nm.IsListening} " +
                          $"TickRate={nm.NetworkConfig.TickRate}");

                // 收到 ping 立刻原樣回 pong —— host 端不做任何額外處理，
                // 量到的才是純粹的傳輸往返
                nm.CustomMessagingManager.RegisterNamedMessageHandler(W1Rtt.Ping,
                    (senderId, reader) =>
                    {
                        reader.ReadValueSafe(out int seq);
                        reader.ReadValueSafe(out double sentAt);
                        var w = new FastBufferWriter(sizeof(int) + sizeof(double), Allocator.Temp);
                        using (w)
                        {
                            w.WriteValueSafe(seq);
                            w.WriteValueSafe(sentAt);
                            nm.CustomMessagingManager.SendNamedMessage(W1Rtt.Pong, senderId, w);
                        }
                    });

                W1Io.Write("code.txt", session.Code);
                W1Io.Write("host-ready.txt", DateTime.UtcNow.ToString("O"));

                var sw = Stopwatch.StartNew();
                while (sw.Elapsed.TotalSeconds < 300 && W1Io.Read("stop.txt") == null)
                    await Task.Delay(100);

                try { await session.AsHost().DeleteAsync(); } catch { }
            }
        }
    }

    /// shell 以 -testFilter "W1RttClient" 啟動
    public class W1RttClient
    {
        private UnityEngine.GameObject m_Go;

        [TearDown]
        public void TearDown()
        {
            if (NetworkManager.Singleton != null && NetworkManager.Singleton.IsListening)
                NetworkManager.Singleton.Shutdown();
            if (m_Go != null) UnityEngine.Object.DestroyImmediate(m_Go);
        }

        [UnityTest]
        public IEnumerator RunRttClient()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                await W1Io.SignInAsync();
                W1Rtt.SpawnNetworkManager(out m_Go, tickRate: W1Rtt.Tick);

                string code = null;
                for (int i = 0; i < 480 && code == null; i++)
                {
                    if (W1Io.Read("host-ready.txt") != null) code = W1Io.Read("code.txt");
                    await Task.Delay(250);
                }
                Assert.IsNotNull(code, "host 未在時限內就緒。");

                // ⚠ 協定**不會從 host 傳染過來**：第一版 client 只傳 code，結果照樣拋
                //   ArgumentException: Mismatched Relay configuration and network interface。
                //   join 端必須自己再宣告一次 WSS（JoinSessionOptions 同樣繼承 BaseSessionOptions，
                //   所以吃得下同一個擴充方法）。
                var session = await MultiplayerService.Instance.JoinSessionByCodeAsync(code,
                    new JoinSessionOptions()
                        .WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS }));
                var nm = NetworkManager.Singleton;

                // 等 NGO 真的連上（join session 會自動帶起 NGO client）
                for (int i = 0; i < 200 && !nm.IsConnectedClient; i++) await Task.Delay(100);
                Debug.Log($"[W1RTT][client] joined Code={code} IsConnectedClient={nm.IsConnectedClient} " +
                          $"TickRate={nm.NetworkConfig.TickRate}");
                Assert.IsTrue(nm.IsConnectedClient, "NGO client 未連上，無法量 RTT。");

                var rtts = new List<double>();
                var pending = new Dictionary<int, double>();
                var clock = Stopwatch.StartNew();

                nm.CustomMessagingManager.RegisterNamedMessageHandler(W1Rtt.Pong,
                    (senderId, reader) =>
                    {
                        reader.ReadValueSafe(out int seq);
                        reader.ReadValueSafe(out double sentAt);
                        if (pending.Remove(seq))
                            rtts.Add(clock.Elapsed.TotalMilliseconds - sentAt);
                    });

                for (int i = 0; i < W1Rtt.Samples; i++)
                {
                    var now = clock.Elapsed.TotalMilliseconds;
                    pending[i] = now;
                    var w = new FastBufferWriter(sizeof(int) + sizeof(double), Allocator.Temp);
                    using (w)
                    {
                        w.WriteValueSafe(i);
                        w.WriteValueSafe(now);
                        nm.CustomMessagingManager.SendNamedMessage(
                            W1Rtt.Ping, NetworkManager.ServerClientId, w);
                    }
                    await Task.Delay(250);   // 樣本之間留間隔，避免互相排隊
                }

                for (int i = 0; i < 40 && rtts.Count < W1Rtt.Samples; i++) await Task.Delay(100);

                if (rtts.Count == 0)
                {
                    W1Io.Write("rtt.txt", "samples=0;error=no pong received");
                    Assert.Fail("一個 pong 都沒收到。");
                }

                rtts.Sort();
                double P(double q) => rtts[Math.Min(rtts.Count - 1, (int)Math.Ceiling(q * rtts.Count) - 1)];
                var line = $"samples={rtts.Count};min={rtts.First():F1};median={P(0.5):F1};" +
                           $"p95={P(0.95):F1};max={rtts.Last():F1};tick={nm.NetworkConfig.TickRate};" +
                           $"region={(string.IsNullOrEmpty(W1Rtt.Region) ? "(default)" : W1Rtt.Region)}";
                Debug.Log($"[W1RTT][client] {line}");
                W1Io.Write("rtt.txt", line);

                try { await session.LeaveAsync(); } catch { }
            }
        }
    }
}
