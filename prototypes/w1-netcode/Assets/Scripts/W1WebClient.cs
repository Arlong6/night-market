// W1 原型 — [P-13]：瀏覽器關分頁時，WebSocket 的 close frame 會不會送出去？
//
// 為什麼這一項在第 5 批之後變得更重要：
//   第 5 批量到 Host 被 kill -9 時，client 要 **87 秒**才知道（AC6b 只給 12 秒）。
//   若瀏覽器關分頁**不送** close frame，那玩家關分頁就等同 kill -9 —— 87 秒。
//   若送，就是第 5 批 graceful 那側的 **0.08 秒**。兩者差一千倍。
//
// ⚠ [P-18] 證實的是 `sendBeacon`（走 HTTP），與 WebSocket close frame **是兩套機制**，
//   前者為真不蘊含後者為真。這正是本項存在的理由。
//
// 用法：以 ?code=XXXXXX 載入 Web build，本元件會加入該 session 並建立 NGO 連線。
//       之後由外部關閉分頁，由 batchmode 的 host 量測它多久發現。

using System;
using System.Threading.Tasks;
using Unity.Netcode;
using Unity.Netcode.Transports.UTP;
using Unity.Services.Authentication;
using Unity.Services.Core;
using Unity.Services.Multiplayer;
using UnityEngine;

public class W1WebClient : MonoBehaviour
{
    public string Status = "(未啟動)";
    public string Detail = "";

    private ISession m_Session;

    public async void Begin(string code)
    {
        try
        {
            Status = "初始化 UGS…";
            if (UnityServices.State != ServicesInitializationState.Initialized)
                await UnityServices.InitializeAsync();
            if (!AuthenticationService.Instance.IsSignedIn)
                await AuthenticationService.Instance.SignInAnonymouslyAsync();
            Detail = AuthenticationService.Instance.PlayerId;

            Status = "建立 NetworkManager…";
            var go = new GameObject("W1_NM_Web");
            DontDestroyOnLoad(go);
            var nm = go.AddComponent<NetworkManager>();
            var utp = go.AddComponent<UnityTransport>();
            utp.UseWebSockets = true;               // Web 只有 WebSocket
            nm.NetworkConfig = new NetworkConfig
            {
                NetworkTransport = utp,
                TickRate = 10,
                EnableSceneManagement = false,      // 場景不在 build list
            };

            Status = $"加入 {code}…";
            // 協定不會從 host 傳染，加入端必須自己再宣告一次（第 4 批的發現）
            m_Session = await MultiplayerService.Instance.JoinSessionByCodeAsync(code,
                new JoinSessionOptions()
                    .WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS }));

            for (int i = 0; i < 300 && !nm.IsConnectedClient; i++) await Task.Delay(100);
            Status = nm.IsConnectedClient ? "✅ NGO 已連線（可以關分頁了）" : "❌ NGO 未連上";
            Detail = $"IsConnectedClient={nm.IsConnectedClient} LocalClientId={nm.LocalClientId}";
            Debug.Log($"[W1WEBCLIENT] {Status} {Detail}");
        }
        catch (Exception e)
        {
            Status = "❌ 例外";
            Detail = e.GetType().Name + ": " + e.Message;
            Debug.LogError($"[W1WEBCLIENT] {Detail}");
        }
    }
}
