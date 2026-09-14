// W1 原型 — 第 1 批：Multiplayer Services 2.3.1 的 API 形狀驗證
//
// 這一檔**不連線**。它靠「能不能編譯」來證明 API 存在且簽章正確——
// 編譯期驗證比反射更硬：反射拿到的字串可能拼錯，編譯過就是真的有那個方法。
//
// 驗的是 GDD 裡三個把整條設計掛在上面的假設：
//   [P-10](b) Lobby 能否只建 session、延後到「開始上班」才配 Relay（Core Rule #23）
//   [P-10](c) 成員事件與 roster 查詢的載體（Core Rule #18 排歧表的序 1 與序 3）
//   [P-10](d) Host 能否主動移除成員（Core Rule #24a，全表唯一沒有退路的查證項）
//
// 對應 GDD：design/gdd/netcode-session.md

using System;
using System.Threading.Tasks;
using NUnit.Framework;
using Unity.Services.Multiplayer;

namespace W1.Tests.EditMode
{
    public class SessionApiShapeTests
    {
        // 這些方法永遠不會被呼叫。它們存在的唯一目的是「必須能編譯」。
        // 若 MPS 升級後簽章改變，這一檔會編譯失敗——那正是我們要的警報。
#pragma warning disable CS8321 // 區域函式未使用
        private static void CompileOnlyProbes()
        {
            // ── [P-10](b) 延後建立 Relay ───────────────────────────
            // GDD #23 的整條 Lobby 設計掛在「能不能拆」。
            // IHostSessionNetwork 同時有 StartRelayNetworkAsync 與 StopNetworkAsync，
            // 代表 network 是 session 之上可獨立啟停的一層。
            void DeferredRelay(IHostSession host)
            {
                IHostSessionNetwork net = host.Network;
                NetworkState state = net.State;          // Stopped / Starting / Started / Stopping / Migrating
                Task start = net.StartRelayNetworkAsync(new RelayNetworkOptions());
                Task stop = net.StopNetworkAsync();      // #23a 局間 teardown 回 MPS-only
                net.StateChanged += s => { };
                net.StartFailed += e => { };
                net.StopFailed += e => { };
                _ = (state, start, stop);
            }

            // 建 session 時 WithRelayNetwork 是**擴充方法**，不是必填參數，
            // 因此可以建出一個不帶 network 的 SessionOptions。
            void SessionWithoutNetwork()
            {
                var bare = new SessionOptions { MaxPlayers = 4 };       // 不呼叫 WithRelayNetwork
                var withRelay = new SessionOptions { MaxPlayers = 4 }.WithRelayNetwork();
                _ = (bare, withRelay);
            }

            // ── [P-10](c) 排歧表的兩條路徑 ─────────────────────────
            // 序 1：成員事件推播。序 3：roster 查詢。
            void DisambiguationSignals(ISession session)
            {
                // 序 1 — 推播
                session.PlayerJoined += id => { };
                session.PlayerLeaving += id => { };        // 註：PlayerLeft 已 deprecated
                session.PlayerHasLeft += id => { };
                session.RemovedFromSession += () => { };
                session.Deleted += () => { };
                session.SessionHostChanged += id => { };   // 比原設計預期的更直接
                session.SessionMigrated += () => { };
                session.StateChanged += s => { };

                // 序 3 — 查詢。GDD 原本假設要「輪詢 roster 再比對 Host」，
                // 實際上 Host 是一個可直接讀的屬性，連比對都不用。
                string hostId = session.Host;
                bool hostStillHere = session.HasPlayer(session.Host);
                var roster = session.Players;
                int count = session.PlayerCount;
                SessionState st = session.State;          // None / Connected / Disconnected / Deleted
                IClientSessionNetwork cnet = session.Network;
                NetworkState nstate = cnet.State;
                _ = (hostId, hostStillHere, roster, count, st, nstate);
            }

            // ── [P-10](d) Host 移除成員 ────────────────────────────
            // GDD #24a 的第 6 步。這是先前「全表唯一沒有退路」的查證項。
            void HostRemovesMember(ISession session, string playerId)
            {
                IHostSession asHost = session.AsHost();
                Task removed = asHost.RemovePlayerAsync(playerId);
                Task deleted = asHost.DeleteAsync();
                _ = (removed, deleted);
            }

            // ── [P-2](b) 重連身分 ──────────────────────────────────
            void Reconnect(ISession session)
            {
                Task r = session.ReconnectAsync();
                IPlayer me = session.CurrentPlayer;
                _ = (r, me);
            }

            // ── 額外發現：host migration 是一等公民 ────────────────
            // GDD 目前寫「MVP 無 host migration」。API 顯示那是**選擇**，不是限制。
            void HostMigrationExists(IHostSession host)
            {
                Task<SessionMigrationData> get = host.GetHostMigrationDataAsync(TimeSpan.FromSeconds(5));
                Task set = host.SetHostMigrationDataAsync(Array.Empty<byte>(), TimeSpan.FromSeconds(5));
                host.Host = "someone-else";               // host 可被指派
                _ = (get, set);
            }
        }
#pragma warning restore CS8321

        [Test]
        public void P10b_可以建立不帶Network的SessionOptions()
        {
            var bare = new SessionOptions { MaxPlayers = 4 };
            Assert.IsNotNull(bare, "WithRelayNetwork 是擴充方法而非必填，故 session 可先於 network 存在。");
            Assert.AreEqual(4, bare.MaxPlayers);
        }

        [Test]
        public void P10b_NetworkState有Stopped狀態_代表network可獨立啟停()
        {
            Assert.AreEqual(0, (int)NetworkState.Stopped);
            Assert.AreEqual(2, (int)NetworkState.Started);
            Assert.IsTrue(Enum.IsDefined(typeof(NetworkState), NetworkState.Migrating),
                "Migrating 狀態的存在代表 MPS 原生支援 host migration。");
        }

        [Test]
        public void P10c_SessionState列舉包含Disconnected與Deleted()
        {
            Assert.AreEqual(1, (int)SessionState.Connected);
            Assert.AreEqual(2, (int)SessionState.Disconnected);
            Assert.AreEqual(3, (int)SessionState.Deleted,
                "Deleted 與 Disconnected 是不同狀態——這正是 #18 排歧表要分辨的兩件事。");
        }

        [Test]
        public void 形狀驗證彙總()
        {
            // 本檔若能編譯，下列全部成立。這個測試只是把結論寫進 log。
            UnityEngine.Debug.Log(
                "[W1][第1批][編譯期驗證通過]\n" +
                "  P-10(b) IHostSessionNetwork.StartRelayNetworkAsync / StopNetworkAsync 存在 → #23 延後建連可行\n" +
                "  P-10(c) PlayerJoined/PlayerLeaving/PlayerHasLeft/RemovedFromSession/Deleted/\n" +
                "          SessionHostChanged/SessionMigrated 事件齊全 → 排歧表序 1 成立\n" +
                "  P-10(c) ISession.Host / HasPlayer / Players / PlayerCount → 排歧表序 3 成立，\n" +
                "          且 Host 可直接讀取，不需輪詢 roster 再比對\n" +
                "  P-10(d) IHostSession.RemovePlayerAsync 存在（經 ISession.AsHost()）→ #24a 成立\n" +
                "  P-2(b)  ISession.ReconnectAsync 存在\n" +
                "  額外     GetHostMigrationDataAsync/SetHostMigrationDataAsync + NetworkState.Migrating\n" +
                "          → host migration 是 MPS 一等公民，GDD 的『MVP 無 migration』是選擇而非限制");
            Assert.Pass();
        }
    }
}
