// W1 原型 — [P-14] 雙進程：Host 行程被強制終止後，其他 client 多久發現
//
// 為什麼是 PlayMode 測試而不是 -executeMethod：
//   第一版寫成 Editor 的 `-executeMethod` 入口，結果拋
//   `ServicesInitializationException: You are attempting to initialize Unity Services
//    in Edit Mode. Unity Services can only be initialized in Play Mode`。
//   UGS 只能在 Play Mode 初始化，所以雙進程的兩個角色都必須是 PlayMode 測試，
//   由外部 shell 以 `-testFilter` 指定各自扮演哪一邊。
//
// 為什麼需要兩個進程：kill 不了自己。且 Unity 不允許兩個實例開同一專案，
//   故 client 跑在 `prototypes/w1-client`（同專案副本，productName 已改以分離 PlayerPrefs）。
//
// 協定（透過 -w1out 指定的目錄交換檔案）：
//   Host   建 session → 寫 code.txt / host-ready.txt → 保持存活直到被 kill
//   Client 讀 code.txt → 加入 → 訂閱全部事件並輪詢 → 寫 client-armed.txt
//          → 偵測到 Host 消失時寫 result.txt（記錄**哪個訊號先到**與秒數）
//
// 對應 GDD：design/gdd/netcode-session.md 的 [P-14]、[P-10](c)、AC6b、AC6c、#18、#25

using System;
using System.Collections;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using NUnit.Framework;
using Unity.Services.Authentication;
using Unity.Services.Core;
using Unity.Services.Multiplayer;
using UnityEngine.TestTools;
using Debug = UnityEngine.Debug;

namespace W1.Tests.PlayMode
{
    public static class W1Io
    {
        public static string OutDir
        {
            get
            {
                var args = Environment.GetCommandLineArgs();
                for (int i = 0; i < args.Length - 1; i++)
                    if (args[i] == "-w1out") return args[i + 1];
                return Path.Combine(Path.GetTempPath(), "w1harness");
            }
        }

        public static void Write(string name, string content)
        {
            Directory.CreateDirectory(OutDir);
            File.WriteAllText(Path.Combine(OutDir, name), content);
            Debug.Log($"[W1H] wrote {name}: {content}");
        }

        public static string Read(string name)
        {
            var p = Path.Combine(OutDir, name);
            return File.Exists(p) ? File.ReadAllText(p).Trim() : null;
        }

        public static async Task SignInAsync()
        {
            if (UnityServices.State != ServicesInitializationState.Initialized)
                await UnityServices.InitializeAsync();
            if (!AuthenticationService.Instance.IsSignedIn)
                await AuthenticationService.Instance.SignInAnonymouslyAsync();
            Debug.Log($"[W1H] signed in as {AuthenticationService.Instance.PlayerId}");
        }
    }

    /// 由 shell 以 -testFilter "W1HostRole" 啟動
    public class W1HostRole
    {
        [UnityTest]
        public IEnumerator RunHost()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                await W1Io.SignInAsync();
                var session = await MultiplayerService.Instance.CreateSessionAsync(
                    new SessionOptions { MaxPlayers = 4 });

                W1Io.Write("code.txt", session.Code);
                W1Io.Write("host-player.txt", session.CurrentPlayer.Id);
                Debug.Log($"[W1H][host] up. Code={session.Code} Host={session.Host}");
                W1Io.Write("host-ready.txt", DateTime.UtcNow.ToString("O"));

                // 保持存活等著被 kill -9。上限 180s 避免孤兒進程。
                var sw = Stopwatch.StartNew();
                while (sw.Elapsed.TotalSeconds < 420 && W1Io.Read("stop.txt") == null)
                    await Task.Delay(250);

                try { await session.AsHost().DeleteAsync(); } catch { }
            }
        }
    }

    /// 由 shell 以 -testFilter "W1ClientRole" 啟動
    public class W1ClientRole
    {
        [UnityTest]
        public IEnumerator RunClient()
        {
            var t = RunAsync();
            while (!t.IsCompleted) yield return null;
            if (t.IsFaulted) throw t.Exception!.GetBaseException();

            async Task RunAsync()
            {
                await W1Io.SignInAsync();

                string code = null;
                for (int i = 0; i < 480 && code == null; i++)
                {
                    if (W1Io.Read("host-ready.txt") != null) code = W1Io.Read("code.txt");
                    await Task.Delay(250);
                }
                Assert.IsNotNull(code, "host 未在時限內就緒。");

                var session = await MultiplayerService.Instance.JoinSessionByCodeAsync(code);
                var hostId = session.Host;
                Debug.Log($"[W1H][client] joined Code={code} Host={hostId} " +
                          $"PlayerCount={session.PlayerCount} Me={session.CurrentPlayer.Id}");
                W1Io.Write("client-joined.txt", $"host={hostId};count={session.PlayerCount}");

                var sw = new Stopwatch();
                string hit = null;
                void Mark(string which)
                {
                    if (hit != null) return;
                    hit = which;
                    var secs = sw.Elapsed.TotalSeconds;
                    Debug.Log($"[W1H][client] DETECTED via {which} after {secs:F2}s");
                    W1Io.Write("result.txt", $"signal={which};seconds={secs:F2}");
                }

                // #18 排歧表序 1：事件推播。全部訂閱，看哪個先到。
                session.PlayerLeaving += id => { if (id == hostId) Mark("PlayerLeaving"); };
                session.PlayerHasLeft += id => { if (id == hostId) Mark("PlayerHasLeft"); };
                session.SessionHostChanged += id => Mark($"SessionHostChanged->{id}");
                session.Deleted += () => Mark("Deleted");
                session.RemovedFromSession += () => Mark("RemovedFromSession");
                session.StateChanged += st => Debug.Log($"[W1H][client] SessionState -> {st}");

                W1Io.Write("client-armed.txt", DateTime.UtcNow.ToString("O"));
                sw.Start();

                // #18 排歧表序 3：輪詢 HasPlayer(Host)
                // ⚠ 首次執行用 500ms 間隔，結果每次 RefreshAsync 都吃 HTTP 429
                //   (Too Many Requests)，輪詢完全失效。服務端對 session 查詢有速率限制，
                //   這本身是 #18 序 3 的實作約束：**不能高頻輪詢**。改為 5 秒。
                while (sw.Elapsed.TotalSeconds < 300 && hit == null)
                {
                    await Task.Delay(5000);
                    try
                    {
                        await session.RefreshAsync();
                        if (!session.HasPlayer(hostId)) Mark("HasPlayer(Host)==false");
                    }
                    catch (Exception e)
                    {
                        Debug.Log($"[W1H][client] refresh threw {e.GetType().Name}: {e.Message}");
                    }
                }

                if (hit == null) W1Io.Write("result.txt", "signal=NONE;seconds=timeout(300)");
                try { await session.LeaveAsync(); } catch { }
            }
        }
    }
}
