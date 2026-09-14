// W1 原型 — 第 1 批（連線部分）：UGS 連線冒煙測試
//
// 第一次執行的結果改寫了這一檔的分工。當時把「帶 Relay 建 session」當基準放在最前面，
// 結果三條測試全倒在同一個錯誤：`SessionException: Cannot start when Singleton is not set`
// ——那指的是 `NetworkManager.Singleton`。PlayMode 測試跑在空場景，沒有 NetworkManager，
// 而 `WithRelayNetwork()` 這條路徑會去啟動 NGO。
//
// 那個失敗本身是有用的事實：**Sessions 的 relay 路徑依賴 NetworkManager.Singleton**。
// 於是拆成兩條分別驗，問題也更精確了：
//   B01 不帶 network 的 session，是否**連 NetworkManager 都不需要**？
//        → 若是，Core Rule #23 的 Lobby 階段可以完全不碰 NGO，價值比原設計更大。
//   B02 有 NetworkManager 時，能否**延後**呼叫 StartRelayNetworkAsync？
//        → 這是 #23「按開始上班才建連」的 runtime 證明。
//
// 對應 GDD：design/gdd/netcode-session.md 的 [P-10](b)、[P-2](b)、Core Rule #18/#23

using System.Collections;
using System.Threading.Tasks;
using NUnit.Framework;
using Unity.Netcode;
using Unity.Netcode.Transports.UTP;
using Unity.Services.Authentication;
using Unity.Services.Core;
using Unity.Services.Multiplayer;
using UnityEngine;
using UnityEngine.TestTools;

namespace W1.Tests.PlayMode
{
    public class UgsSmokeTests
    {
        private static bool s_Initialized;
        private GameObject m_NetworkManagerGo;

        private static async Task EnsureSignedInAsync()
        {
            if (!s_Initialized)
            {
                await UnityServices.InitializeAsync();
                s_Initialized = true;
                Debug.Log($"[W1][UGS] InitializeAsync 完成，State={UnityServices.State}");
            }
            if (!AuthenticationService.Instance.IsSignedIn)
            {
                await AuthenticationService.Instance.SignInAnonymouslyAsync();
            }
            Debug.Log($"[W1][UGS] IsSignedIn={AuthenticationService.Instance.IsSignedIn} " +
                      $"PlayerId={AuthenticationService.Instance.PlayerId}");
        }

        /// 程式化建立 NetworkManager＋UnityTransport（PlayMode 空場景裡沒有）。
        private void SpawnNetworkManager()
        {
            if (NetworkManager.Singleton != null) return;
            m_NetworkManagerGo = new GameObject("W1_NetworkManager");
            var nm = m_NetworkManagerGo.AddComponent<NetworkManager>();
            var utp = m_NetworkManagerGo.AddComponent<UnityTransport>();
            nm.NetworkConfig = new NetworkConfig { NetworkTransport = utp };
            Debug.Log($"[W1][NGO] NetworkManager 已建立，Singleton={(NetworkManager.Singleton != null)}");
        }

        [TearDown]
        public void TearDown()
        {
            if (m_NetworkManagerGo != null)
            {
                if (NetworkManager.Singleton != null && NetworkManager.Singleton.IsListening)
                {
                    NetworkManager.Singleton.Shutdown();
                }
                Object.DestroyImmediate(m_NetworkManagerGo);
                m_NetworkManagerGo = null;
            }
        }

        [UnityTest]
        public IEnumerator A01_可以在batchmode完成初始化與匿名登入()
        {
            var t = EnsureSignedInAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            Assert.IsTrue(AuthenticationService.Instance.IsSignedIn,
                "batchmode 匿名登入失敗 → 後續所有自動化連線測試都無法無人值守執行。");
            Assert.IsNotEmpty(AuthenticationService.Instance.PlayerId);
        }

        // ── [P-10](b) runtime 驗證之一 ─────────────────────────────
        // 刻意**不建立 NetworkManager**。若這條通過，代表 Lobby 階段
        // 連 NGO 的單例都不需要存在。
        [UnityTest]
        public IEnumerator B01_不帶Network的Session_不需要NetworkManager_P10b()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                await EnsureSignedInAsync();
                Assert.IsNull(NetworkManager.Singleton,
                    "本測試的前提是場景中沒有 NetworkManager。");

                IHostSession bare = null;
                try
                {
                    var options = new SessionOptions { MaxPlayers = 4 }; // 不呼叫 WithRelayNetwork
                    bare = await MultiplayerService.Instance.CreateSessionAsync(options);

                    Debug.Log($"[W1][P-10b] 無 NetworkManager 下建立成功：Code={bare.Code} " +
                              $"SessionState={bare.State} NetworkState={bare.Network.State} " +
                              $"Host={bare.Host} PlayerCount={bare.PlayerCount}");

                    Assert.IsNotEmpty(bare.Code, "房間碼應可取得（#8 的入口）。");
                    Assert.AreEqual(NetworkState.Stopped, bare.Network.State,
                        "NetworkState 應為 Stopped —— 這正是 #23『Lobby 不存在會逾時的即時連線』所需。");
                    Assert.IsTrue(bare.HasPlayer(bare.Host),
                        "#18 排歧表序 3 直接用 HasPlayer(Host) 判斷 Host 是否還在。");
                }
                finally
                {
                    if (bare != null) { try { await bare.AsHost().DeleteAsync(); } catch { } }
                }
            }
        }

        // ── [P-10](b) runtime 驗證之二 ─────────────────────────────
        // 有 NetworkManager 時，延後啟動 Relay（模擬 Host 按「開始上班」）。
        [UnityTest]
        public IEnumerator B02_可延後啟動Relay_模擬開始上班_P10b()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                await EnsureSignedInAsync();
                SpawnNetworkManager();

                IHostSession s = null;
                try
                {
                    s = await MultiplayerService.Instance.CreateSessionAsync(
                        new SessionOptions { MaxPlayers = 4 });
                    Debug.Log($"[W1][P-10b] 建立時 NetworkState={s.Network.State}");
                    Assert.AreEqual(NetworkState.Stopped, s.Network.State);

                    // ← 這一刻相當於 Host 按下「開始上班」
                    await s.Network.StartRelayNetworkAsync(new RelayNetworkOptions());
                    Debug.Log($"[W1][P-10b] 延後 StartRelayNetworkAsync 後 " +
                              $"NetworkState={s.Network.State} NGO.IsListening={NetworkManager.Singleton?.IsListening}");

                    Assert.AreEqual(NetworkState.Started, s.Network.State,
                        "延後啟動後應為 Started —— 這是 #23『按開始上班才建連』的 runtime 證明。");

                    // #23a：局間 teardown 回 MPS-only
                    await s.Network.StopNetworkAsync();
                    Debug.Log($"[W1][#23a] StopNetworkAsync 後 NetworkState={s.Network.State}");
                    Assert.AreEqual(NetworkState.Stopped, s.Network.State,
                        "#23a 局間 teardown 應能把 network 停掉而 session 仍在。");
                    Assert.AreEqual(SessionState.Connected, s.State,
                        "network 停掉後 session 本身應仍存活（兩個狀態機獨立）。");
                }
                finally
                {
                    if (s != null) { try { await s.AsHost().DeleteAsync(); } catch { } }
                }
            }
        }

        // ── [P-2](b) playerId 是否等同 Auth 身分 ───────────────────
        [UnityTest]
        public IEnumerator B03_sessionPlayerId等同AuthPlayerId_P2b()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                await EnsureSignedInAsync();
                var authId = AuthenticationService.Instance.PlayerId;

                IHostSession s = null;
                try
                {
                    s = await MultiplayerService.Instance.CreateSessionAsync(
                        new SessionOptions { MaxPlayers = 4 });
                    var inSession = s.CurrentPlayer.Id;
                    Debug.Log($"[W1][P-2b] AuthPlayerId={authId} CurrentPlayer.Id={inSession}");

                    Assert.AreEqual(authId, inSession,
                        "若相等，代表只要匿名帳號不變、身分就跨 session 延續 —— " +
                        "#15a 的『同一玩家第 2 次離線』與 AC50 因此有可靠的識別依據。");
                }
                finally
                {
                    if (s != null) { try { await s.AsHost().DeleteAsync(); } catch { } }
                }
            }
        }
    }
}
