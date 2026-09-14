// W1 原型 — 雙進程測試入口
//
// 用途：`[P-14]`（Host 行程被強制終止後，其他 client 多久發現）與
//       `[P-10]`(c) 剩下的「事件多快反映」——兩者都需要**兩個真實進程**，
//       單一 PlayMode 測試做不到（kill 不了自己）。
//
// 用法（batchmode）：
//   Unity -batchmode -nographics -projectPath . -executeMethod W1Harness.RunHost   -w1out <dir>
//   Unity -batchmode -nographics -projectPath . -executeMethod W1Harness.RunClient -w1out <dir>
//
// 協定（透過 <dir> 下的檔案，避免進程間通訊的複雜度）：
//   host   建好 session 後寫 code.txt，接著寫 host-ready.txt，然後保持存活
//   client 讀 code.txt 加入，寫 client-joined.txt，訂閱事件後開始計時
//          偵測到 host 消失時寫 result.txt（內含偵測秒數與命中的訊號）
//
// 對應 GDD：design/gdd/netcode-session.md 的 [P-14]、[P-10](c)、AC6b、AC6c、#18、#25

using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using Unity.Services.Authentication;
using Unity.Services.Core;
using Unity.Services.Multiplayer;
using UnityEditor;
using Debug = UnityEngine.Debug;

public static class W1Harness
{
    private static string OutDir
    {
        get
        {
            var args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length - 1; i++)
                if (args[i] == "-w1out") return args[i + 1];
            return Path.Combine(Path.GetTempPath(), "w1harness");
        }
    }

    private static void Write(string name, string content)
    {
        Directory.CreateDirectory(OutDir);
        File.WriteAllText(Path.Combine(OutDir, name), content);
        Debug.Log($"[W1H] wrote {name}: {content}");
    }

    private static string Read(string name)
    {
        var p = Path.Combine(OutDir, name);
        return File.Exists(p) ? File.ReadAllText(p).Trim() : null;
    }

    private static async Task SignInAsync()
    {
        if (UnityServices.State != ServicesInitializationState.Initialized)
            await UnityServices.InitializeAsync();
        if (!AuthenticationService.Instance.IsSignedIn)
            await AuthenticationService.Instance.SignInAnonymouslyAsync();
        Debug.Log($"[W1H] signed in as {AuthenticationService.Instance.PlayerId}");
    }

    // ── Host ────────────────────────────────────────────────────────
    public static void RunHost()
    {
        try { RunHostAsync().GetAwaiter().GetResult(); }
        catch (Exception e) { Debug.LogError($"[W1H][host] {e}"); Write("host-error.txt", e.ToString()); }
    }

    private static async Task RunHostAsync()
    {
        // 註：host 與 client 是不同專案（不同 productName），PlayerPrefs 分開，
        // 因此各自持有獨立的匿名帳號，不需要也不能在 Initialize 前呼叫 SignOut
        // （AuthenticationService.Instance 在初始化前會拋 ServicesInitializationException，
        //   `?.` 擋不住，因為拋例外的是 getter 本身）。
        await SignInAsync();

        var session = await MultiplayerService.Instance.CreateSessionAsync(
            new SessionOptions { MaxPlayers = 4 });
        Write("code.txt", session.Code);
        Write("host-player.txt", session.CurrentPlayer.Id);
        Debug.Log($"[W1H][host] session up. Code={session.Code} Host={session.Host}");
        Write("host-ready.txt", DateTime.UtcNow.ToString("O"));

        // 保持存活直到被 kill（外部 shell 負責）。上限 180s 以免變成孤兒進程。
        var sw = Stopwatch.StartNew();
        while (sw.Elapsed.TotalSeconds < 180)
        {
            await Task.Delay(250);
            if (Read("stop.txt") != null) break;
        }
        try { await session.AsHost().DeleteAsync(); } catch { }
    }

    // ── Client ──────────────────────────────────────────────────────
    public static void RunClient()
    {
        try { RunClientAsync().GetAwaiter().GetResult(); }
        catch (Exception e) { Debug.LogError($"[W1H][client] {e}"); Write("client-error.txt", e.ToString()); }
    }

    private static async Task RunClientAsync()
    {
        await SignInAsync();

        // 等 host 就緒
        string code = null;
        for (int i = 0; i < 240 && code == null; i++)
        {
            if (Read("host-ready.txt") != null) code = Read("code.txt");
            await Task.Delay(250);
        }
        if (code == null) { Write("client-error.txt", "host never became ready"); return; }

        var session = await MultiplayerService.Instance.JoinSessionByCodeAsync(code);
        var hostId = session.Host;
        Debug.Log($"[W1H][client] joined Code={code} Host={hostId} PlayerCount={session.PlayerCount}");
        Write("client-joined.txt", $"host={hostId};count={session.PlayerCount}");

        // 訂閱 #18 排歧表序 1 用到的全部事件，記錄哪一個先到
        var sw = new Stopwatch();
        string hit = null;
        void Mark(string which)
        {
            if (hit != null) return;
            hit = which;
            var secs = sw.Elapsed.TotalSeconds;
            Debug.Log($"[W1H][client] DETECTED via {which} after {secs:F2}s");
            Write("result.txt", $"signal={which};seconds={secs:F2}");
        }
        session.PlayerLeaving += id => { if (id == hostId) Mark("PlayerLeaving"); };
        session.PlayerHasLeft += id => { if (id == hostId) Mark("PlayerHasLeft"); };
        session.SessionHostChanged += id => Mark($"SessionHostChanged->{id}");
        session.Deleted += () => Mark("Deleted");
        session.RemovedFromSession += () => Mark("RemovedFromSession");
        session.StateChanged += st => Debug.Log($"[W1H][client] SessionState -> {st}");

        // 通知外部「可以動手 kill 了」
        Write("client-armed.txt", DateTime.UtcNow.ToString("O"));
        sw.Start();

        // 同時輪詢 HasPlayer(Host)，那是排歧表序 3
        while (sw.Elapsed.TotalSeconds < 90 && hit == null)
        {
            await Task.Delay(500);
            try
            {
                await session.RefreshAsync();
                if (!session.HasPlayer(hostId)) Mark("HasPlayer(Host)==false");
            }
            catch (Exception e) { Debug.Log($"[W1H][client] refresh threw: {e.GetType().Name}"); }
        }

        if (hit == null) Write("result.txt", "signal=NONE;seconds=timeout(90)");
        try { await session.LeaveAsync(); } catch { }
    }
}
