#!/usr/bin/env python3
"""W1 原型 — 限速伺服器（公式⑤ 的 CPU 項複驗）

要回答的問題：Unity 的 loader 是「下載完才解壓」還是「邊下載邊解壓」？
localhost 的下載只有 19-153ms，太快，看不出重疊。把頻寬壓到真實水準就看得出來：

  相加（不重疊）→ 網路再慢，「資料在手後的 CPU」仍維持約 2.5s
  重疊（串流）  → 網路變慢時，該值會塌下來（解壓被下載時間吸收）

用法：w1-serve-throttled.py PORT ROOT MBPS
"""
import http.server, socketserver, sys, time, os

PORT = int(sys.argv[1]); ROOT = sys.argv[2]; MBPS = float(sys.argv[3])
BYTES_PER_SEC = MBPS * 1_000_000 / 8
CHUNK = 32 * 1024

class H(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def copyfile(self, source, outputfile):
        # 以固定位元組速率送出，模擬真實頻寬
        t0 = time.perf_counter(); sent = 0
        while True:
            buf = source.read(CHUNK)
            if not buf: break
            outputfile.write(buf); sent += len(buf)
            target = sent / BYTES_PER_SEC
            drift = target - (time.perf_counter() - t0)
            if drift > 0: time.sleep(drift)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("[throttle] %s\n" % (fmt % args))

socketserver.ThreadingTCPServer.allow_reuse_address = True
with socketserver.ThreadingTCPServer(("127.0.0.1", PORT), H) as httpd:
    print(f"[throttle] http://127.0.0.1:{PORT}/ root={ROOT} rate={MBPS}Mbps "
          f"({BYTES_PER_SEC/1048576:.2f} MB/s)", flush=True)
    httpd.serve_forever()
