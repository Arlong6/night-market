// W1 原型 — [P-20](b) ownership transfer 實機行為（OQ#17 的前提查核）
//
// GDD 目前寫：「兩次 ownership 變更需間隔 6 個 network tick，否則 owner-write 的
// NetworkVariable 更新可能遺失。10Hz 下即 600ms，對『互相拋接道具』是可感知的延遲。」
//
// 讀 NGO 2.13.2 原始碼後，這句話有兩處可疑：
//   1. NetworkSpawnManager 的 k_MaximumTickOwnershipChangeMultiplier=6 **只是一則警告**，
//      而且被 `LogLevel == Developer` 擋著。它不延遲、不阻擋任何交接 —— 所以
//      「600ms 的可感知交接延遲」這個說法本身可能就不存在。
//   2. 真正的遺失機制在 NetworkVariableDeltaMessage：送出端在**下一個 tick 序列化時**
//      才評估 `CanWrite()`。若那時所有權已被收回，delta 根本不會被送出。
//      故危險窗口 ≈「本地寫入 → 下一個 tick」，10Hz 下 ≤100ms，而非 600ms。
//
// 本測試量兩件事：
//   (A) 一次 ownership 交接實際要多久（client 端本地計時，可與 RTT 基準線對照）
//   (B) 「client 拿到所有權並寫入」到「所有權被收回」之間要隔多久，寫入才不會遺失
//       —— 掃一串延遲值把真實門檻找出來，而不是相信那個 600ms。
//
// 由外部 shell 以 -testFilter 指定角色，兩個進程分別跑。
//
// 對應 GDD：design/gdd/netcode-session.md 的 [P-20](b)、OQ#17、約束⑧、network_tick_rate

using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using NUnit.Framework;
using Unity.Collections;
using Unity.Netcode;
using Unity.Netcode.Transports.UTP;
using Unity.Services.Multiplayer;
using UnityEngine;
using UnityEngine.TestTools;
using Debug = UnityEngine.Debug;

namespace W1.Tests.PlayMode
{
    public static class W1Own
    {
        public const string Wrote = "w1_own_wrote";
        public const uint PrefabHash = 0x5715C0DE;   // 兩端寫死同一個值，見下方說明

        /// 掃描用的延遲序列（毫秒）：client 寫入後，所有權被收回前所等待的時間。
        /// 涵蓋 0 到遠超過「6 tick = 600ms」的範圍，好讓門檻自己浮出來。
        public static readonly int[] Delays = { 0, 40, 80, 120, 160, 240, 400, 700 };
        public const int Repeats = 3;

        /// 兩個專案副本各自在 runtime 建 prefab，GlobalObjectIdHash 會不一致（它平常源自
        /// 資產 GUID）。這裡用反射寫死同一個常數，讓兩端的 prefab 對得上。
        /// 這是 throwaway 原型才做得的事 —— 正式程式碼請用真正的 prefab 資產。
        public static GameObject MakePrefab()
        {
            // ⚠ **prefab 必須保持 active**。第一版設成 SetActive(false)，結果 client 端
            // 拋 OverflowException: Reading past the end of the buffer。
            // 根因：NGO 在 NonAuthorityLocalSpawn 反序列化時執行
            //   networkBehaviour?.Synchronize(...)
            // 那個 `?.` 在 behaviour 為 null 時**靜靜跳過，但資料仍留在緩衝區**，於是讀爆。
            // 而 inactive 的實例不會跑 Awake → ChildNetworkBehaviours 是空的 → 取到 null。
            // （host 端當時沒事，只因為我在 Spawn() 前手動 SetActive(true)。）
            var go = new GameObject("W1Carryable");
            var no = go.AddComponent<NetworkObject>();
            go.AddComponent<W1Carryable>();

            var f = typeof(NetworkObject).GetField("GlobalObjectIdHash",
                BindingFlags.NonPublic | BindingFlags.Instance);
            Assert.IsNotNull(f, "GlobalObjectIdHash 欄位找不到 —— NGO 版本可能變了。");
            f.SetValue(no, PrefabHash);
            return go;
        }

        public static void Spawn(out GameObject nmGo, out GameObject prefab, uint tickRate)
        {
            nmGo = new GameObject("W1_NM_Own");
            var nm = nmGo.AddComponent<NetworkManager>();
            var utp = nmGo.AddComponent<UnityTransport>();
            utp.UseWebSockets = true;                       // 目標平台 Web，Relay 端須為 WSS
            prefab = MakePrefab();
            nm.NetworkConfig = new NetworkConfig
            {
                NetworkTransport = utp,
                TickRate = tickRate,
                EnableSceneManagement = false,              // 測試場景不在 build list
            };
            nm.NetworkConfig.Prefabs.Add(new Unity.Netcode.NetworkPrefab { Prefab = prefab });
            // Developer 等級才看得到那則 Rapid Ownership Change 警告 —— 我們正是要看它有沒有出現
            nm.LogLevel = LogLevel.Developer;
            Debug.Log($"[W1OWN] NetworkManager 建立 TickRate={tickRate} prefabHash={W1Own.PrefabHash:X}");
        }

        public static SessionOptions HostOpts() =>
            new SessionOptions { MaxPlayers = 4 }
                .WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS });
    }

    /// shell 以 -testFilter "W1OwnHost" 啟動
    public class W1OwnHost
    {
        private GameObject m_Nm, m_Prefab;

        [TearDown]
        public void TearDown()
        {
            if (NetworkManager.Singleton != null && NetworkManager.Singleton.IsListening)
                NetworkManager.Singleton.Shutdown();
            if (m_Nm != null) UnityEngine.Object.DestroyImmediate(m_Nm);
            if (m_Prefab != null) UnityEngine.Object.DestroyImmediate(m_Prefab);
        }

        [UnityTest]
        public IEnumerator RunOwnHost()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                // 快速交接**必然**讓伺服器印出
                //   [Netcode] Client wrote to NetworkVariable`1 without permission.
                //   No more variables can be read. This is critical.
                // 那正是本測試要量的現象，但 UTF 預設把未預期的 Error 日誌當成測試失敗，
                // 第一回合就會中斷整個掃描。這裡明確放行。
                LogAssert.ignoreFailingMessages = true;

                await W1Io.SignInAsync();
                W1Own.Spawn(out m_Nm, out m_Prefab, tickRate: W1Rtt.Tick);

                var session = await MultiplayerService.Instance.CreateSessionAsync(W1Own.HostOpts());
                await session.Network.StartRelayNetworkAsync(W1Rtt.RelayOpts());
                var nm = NetworkManager.Singleton;

                var inst = UnityEngine.Object.Instantiate(m_Prefab);
                inst.SetActive(true);
                var no = inst.GetComponent<NetworkObject>();
                no.Spawn();                                  // host 先持有
                var carry = inst.GetComponent<W1Carryable>();
                Debug.Log($"[W1OWN][host] spawned id={no.NetworkObjectId} owner={no.OwnerClientId} " +
                          $"Code={session.Code} tick={nm.NetworkConfig.TickRate}");

                // client 寫入完成的回報：夾帶它寫進去的 marker
                int lastMarker = 0; bool gotWrote = false;
                nm.CustomMessagingManager.RegisterNamedMessageHandler(W1Own.Wrote,
                    (sender, reader) => { reader.ReadValueSafe(out lastMarker); gotWrote = true; });

                W1Io.Write("code.txt", session.Code);
                W1Io.Write("host-ready.txt", DateTime.UtcNow.ToString("O"));

                // 等 client 連上
                ulong clientId = 0;
                for (int i = 0; i < 300 && clientId == 0; i++)
                {
                    clientId = nm.ConnectedClientsIds.FirstOrDefault(c => c != NetworkManager.ServerClientId);
                    await Task.Delay(100);
                }
                Assert.AreNotEqual(0UL, clientId, "client 未連上。");
                Debug.Log($"[W1OWN][host] client={clientId} 已連上，開始掃描");
                await Task.Delay(1000);

                var lines = new List<string>();
                foreach (var d in W1Own.Delays)
                {
                    for (int r = 0; r < W1Own.Repeats; r++)
                    {
                        // 1. host 持有並清成哨兵值
                        if (no.OwnerClientId != NetworkManager.ServerClientId)
                            no.ChangeOwnership(NetworkManager.ServerClientId);
                        await Task.Delay(500);
                        carry.Value.Value = -1;
                        await Task.Delay(500);

                        // 2. 交給 client，計時到收到它的回報為止（＝交接傳播＋寫入＋回報，一個 RTT 量級）
                        gotWrote = false; lastMarker = 0;
                        var sw = Stopwatch.StartNew();
                        no.ChangeOwnership(clientId);
                        for (int i = 0; i < 100 && !gotWrote; i++) await Task.Delay(20);
                        var handoffMs = sw.Elapsed.TotalMilliseconds;
                        if (!gotWrote) { lines.Add($"delay={d};rep={r};ERROR=client 未回報"); continue; }

                        // 3. 等 d 毫秒後把所有權收回
                        await Task.Delay(d);
                        no.ChangeOwnership(NetworkManager.ServerClientId);

                        // 4. 給足時間讓任何還在路上的 delta 抵達，再判定
                        await Task.Delay(900);
                        var got = carry.Value.Value;
                        var survived = got == lastMarker;
                        lines.Add($"delay={d};rep={r};marker={lastMarker};value={got};" +
                                  $"survived={survived};handoff_ms={handoffMs:F0}");
                        Debug.Log($"[W1OWN][host] {lines[lines.Count - 1]}");
                    }
                }

                W1Io.Write("ownership.txt", string.Join("\n", lines));
                Debug.Log("[W1OWN][host] 掃描完成");
                try { await session.AsHost().DeleteAsync(); } catch { }
            }
        }
    }

    /// shell 以 -testFilter "W1OwnClient" 啟動
    public class W1OwnClient
    {
        private GameObject m_Nm, m_Prefab;

        [TearDown]
        public void TearDown()
        {
            W1OwnershipSignals.Gained = null;
            if (NetworkManager.Singleton != null && NetworkManager.Singleton.IsListening)
                NetworkManager.Singleton.Shutdown();
            if (m_Nm != null) UnityEngine.Object.DestroyImmediate(m_Nm);
            if (m_Prefab != null) UnityEngine.Object.DestroyImmediate(m_Prefab);
        }

        [UnityTest]
        public IEnumerator RunOwnClient()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                // 快速交接**必然**讓伺服器印出
                //   [Netcode] Client wrote to NetworkVariable`1 without permission.
                //   No more variables can be read. This is critical.
                // 那正是本測試要量的現象，但 UTF 預設把未預期的 Error 日誌當成測試失敗，
                // 第一回合就會中斷整個掃描。這裡明確放行。
                LogAssert.ignoreFailingMessages = true;

                await W1Io.SignInAsync();
                W1Own.Spawn(out m_Nm, out m_Prefab, tickRate: W1Rtt.Tick);

                string code = null;
                for (int i = 0; i < 480 && code == null; i++)
                {
                    if (W1Io.Read("host-ready.txt") != null) code = W1Io.Read("code.txt");
                    await Task.Delay(250);
                }
                Assert.IsNotNull(code, "host 未在時限內就緒。");

                var session = await MultiplayerService.Instance.JoinSessionByCodeAsync(code,
                    new JoinSessionOptions()
                        .WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS }));
                var nm = NetworkManager.Singleton;
                for (int i = 0; i < 200 && !nm.IsConnectedClient; i++) await Task.Delay(100);
                Assert.IsTrue(nm.IsConnectedClient, "NGO client 未連上。");
                Debug.Log($"[W1OWN][client] joined Code={code} tick={nm.NetworkConfig.TickRate}");

                // 拿到所有權的當下就寫入，然後立刻回報 —— 之後所有權多快被收回由 host 決定
                int marker = 0;
                W1OwnershipSignals.Gained = c =>
                {
                    marker++;
                    c.Value.Value = marker;
                    var w = new FastBufferWriter(sizeof(int), Allocator.Temp);
                    using (w)
                    {
                        w.WriteValueSafe(marker);
                        nm.CustomMessagingManager.SendNamedMessage(
                            W1Own.Wrote, NetworkManager.ServerClientId, w);
                    }
                    Debug.Log($"[W1OWN][client] 取得所有權，寫入 {marker}");
                };

                var sw = Stopwatch.StartNew();
                while (sw.Elapsed.TotalSeconds < 600 && W1Io.Read("ownership.txt") == null)
                    await Task.Delay(500);

                try { await session.LeaveAsync(); } catch { }
            }
        }
    }
}
