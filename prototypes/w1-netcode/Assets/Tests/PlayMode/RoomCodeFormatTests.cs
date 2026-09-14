// W1 原型 — [P-1] 房間碼格式
//
// B01 的 log 意外帶出第一個真實樣本 Code=M69T96（6 碼）。
// #8 的輸碼規則（大小寫不敏感、易混淆字元 0/O、1/I/l 正規化）完全取決於實際字集，
// 因此收集多個樣本來定案：碼長是否固定、字集包含什麼、有無易混淆字元。
//
// 對應 GDD：design/gdd/netcode-session.md 的 [P-1]、Core Rule #8

using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using NUnit.Framework;
using Unity.Services.Authentication;
using Unity.Services.Core;
using Unity.Services.Multiplayer;
using UnityEngine;
using UnityEngine.TestTools;

namespace W1.Tests.PlayMode
{
    public class RoomCodeFormatTests
    {
        private const int SampleCount = 6; // 夠看出字集傾向，又不浪費免費額度

        [UnityTest]
        public IEnumerator P1_房間碼格式與字集()
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

                var codes = new List<string>();
                for (int i = 0; i < SampleCount; i++)
                {
                    IHostSession s = null;
                    try
                    {
                        s = await MultiplayerService.Instance.CreateSessionAsync(
                            new SessionOptions { MaxPlayers = 4 });
                        codes.Add(s.Code);
                    }
                    finally
                    {
                        if (s != null) { try { await s.AsHost().DeleteAsync(); } catch { } }
                    }
                }

                var charset = new SortedSet<char>(string.Concat(codes));
                var lengths = new SortedSet<int>(codes.Select(c => c.Length));
                var confusables = new string(charset.Where(c => "0O1Il".Contains(c)).ToArray());
                bool hasLower = charset.Any(char.IsLower);
                bool hasUpper = charset.Any(char.IsUpper);
                bool hasDigit = charset.Any(char.IsDigit);

                Debug.Log($"[W1][P-1] 樣本={string.Join(",", codes)}");
                Debug.Log($"[W1][P-1] 碼長={string.Join("/", lengths)} 字集={new string(charset.ToArray())}");
                Debug.Log($"[W1][P-1] 大寫={hasUpper} 小寫={hasLower} 數字={hasDigit} 易混淆字元={(confusables.Length == 0 ? "無" : confusables)}");

                Assert.IsTrue(codes.All(c => !string.IsNullOrWhiteSpace(c)), "每個 session 都應取得房間碼。");
                Assert.LessOrEqual(lengths.Max, 8,
                    "#8 要求房間碼『短、能唸出來』；超過 8 碼就要考慮 P-1 的自建短碼 fallback。");
            }
        }
    }
}
