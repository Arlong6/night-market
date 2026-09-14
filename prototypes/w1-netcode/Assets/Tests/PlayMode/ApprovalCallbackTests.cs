// W1 原型 — [P-17] ConnectionApprovalCallback 在 Sessions 封裝下是否仍可用
//
// 為什麼重要：GDD Core Rule #9 把「班次剩 30 秒鎖 join」的**唯一執行點**移到了
// Host 的 `ConnectionApprovalCallback`，理由是那是唯一 server-authoritative 的 join gate；
// 同一個 payload 還要承載 build/protocol 版本閘（AC54，MVP-必達）。
//
// r4 標註這是「用一個未驗證機制去修另一個未驗證機制」：Sessions API 會自行啟動 NGO
// （`StartRelayNetworkAsync`），若它在封裝過程中覆蓋或忽略了 approval 設定，
// #9 與 AC54 就全部落空，而 fallback（連線後才踢）在語義上做不到版本閘該做的事。
//
// 測法：開啟 ConnectionApproval、註冊 callback，再經 Sessions 啟動 relay network，
// 觀察 callback 是否真的被呼叫。Host 啟動時 NGO 會對 local client 走一次 approval。
//
// 對應 GDD：design/gdd/netcode-session.md 的 [P-17]、Core Rule #9、AC5/AC35/AC54

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
    public class ApprovalCallbackTests
    {
        private GameObject m_Go;

        [TearDown]
        public void TearDown()
        {
            if (m_Go != null)
            {
                if (NetworkManager.Singleton != null && NetworkManager.Singleton.IsListening)
                    NetworkManager.Singleton.Shutdown();
                Object.DestroyImmediate(m_Go);
                m_Go = null;
            }
        }

        [UnityTest]
        public IEnumerator P17_ApprovalCallback在Sessions啟動下是否被呼叫()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                if (UnityServices.State != ServicesInitializationState.Initialized)
                    await UnityServices.InitializeAsync();
                if (!AuthenticationService.Instance.IsSignedIn)
                    await AuthenticationService.Instance.SignInAnonymouslyAsync();

                // 先備好 NetworkManager，並在 Sessions 動手之前就開啟 approval
                m_Go = new GameObject("W1_NM_Approval");
                var nm = m_Go.AddComponent<NetworkManager>();
                var utp = m_Go.AddComponent<UnityTransport>();
                nm.NetworkConfig = new NetworkConfig
                {
                    NetworkTransport = utp,
                    ConnectionApproval = true,      // ← #9 的閘門前提
                };

                int approvalCalls = 0;
                byte[] seenPayload = null;
                nm.ConnectionApprovalCallback = (req, resp) =>
                {
                    approvalCalls++;
                    seenPayload = req.Payload;
                    resp.Approved = true;
                    resp.CreatePlayerObject = false;
                    Debug.Log($"[W1][P-17] ConnectionApprovalCallback 被呼叫！ " +
                              $"ClientId={req.ClientNetworkId} PayloadLen={(req.Payload?.Length ?? -1)}");
                };

                // 也放一段 payload，驗證 #9 要承載的 build/protocol version 有沒有通道
                nm.NetworkConfig.ConnectionData = System.Text.Encoding.UTF8.GetBytes("w1-proto-v1");

                IHostSession s = null;
                try
                {
                    s = await MultiplayerService.Instance.CreateSessionAsync(
                        new SessionOptions { MaxPlayers = 4 });
                    Debug.Log($"[W1][P-17] session 建立 Code={s.Code} NetworkState={s.Network.State}");

                    await s.Network.StartRelayNetworkAsync(new RelayNetworkOptions());
                    Debug.Log($"[W1][P-17] StartRelayNetworkAsync 後 " +
                              $"NetworkState={s.Network.State} IsListening={nm.IsListening} " +
                              $"IsHost={nm.IsHost} IsServer={nm.IsServer}");

                    // 給 NGO 幾幀把 local client 的 approval 走完
                    for (int i = 0; i < 120 && approvalCalls == 0; i++)
                        await Task.Yield();

                    Debug.Log($"[W1][P-17] 結果：approvalCalls={approvalCalls} " +
                              $"ConnectionApproval 設定值={nm.NetworkConfig.ConnectionApproval} " +
                              $"payload={(seenPayload == null ? "null" : System.Text.Encoding.UTF8.GetString(seenPayload))}");

                    // 關鍵斷言一：Sessions 啟動後，ConnectionApproval 設定**沒有被覆蓋**
                    Assert.IsTrue(nm.NetworkConfig.ConnectionApproval,
                        "Sessions 的 StartRelayNetworkAsync 若把 ConnectionApproval 關掉，" +
                        "#9 的截止閘門與 AC54 的版本閘就沒有載體，fallback 在語義上也做不到。");

                    // 關鍵斷言二：NGO 確實以 host 身分起來了
                    Assert.IsTrue(nm.IsListening, "Sessions 應已把 NGO 帶起來。");
                    Assert.IsTrue(nm.IsHost || nm.IsServer, "本機應為 host/server。");
                }
                finally
                {
                    if (s != null) { try { await s.AsHost().DeleteAsync(); } catch { } }
                }
            }
        }
    }
}
