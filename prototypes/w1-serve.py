#!/usr/bin/env python3
"""W1 原型 — 本地測試伺服器
Unity build 設了 decompressionFallback=false，所以 .br 檔必須由伺服器回
Content-Encoding: br，瀏覽器才解得開。Python 內建的 http.server 不會做這件事。
順便印出每個請求，方便對照 [P-6] 的 header 行為。"""
import http.server, socketserver, os, sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8123
ROOT = sys.argv[2] if len(sys.argv) > 2 else "w1-netcode/Build/Web"

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)
    def end_headers(self):
        p = self.path.split("?")[0]
        if p.endswith(".gz"):
            self.send_header("Content-Encoding", "gzip")
            if p.endswith(".js.gz"):     self.send_header("Content-Type", "application/javascript")
            elif p.endswith(".wasm.gz"): self.send_header("Content-Type", "application/wasm")
            else:                        self.send_header("Content-Type", "application/octet-stream")
        elif p.endswith(".br"):
            self.send_header("Content-Encoding", "br")
            if p.endswith(".js.br"):     self.send_header("Content-Type", "application/javascript")
            elif p.endswith(".wasm.br"): self.send_header("Content-Type", "application/wasm")
            else:                        self.send_header("Content-Type", "application/octet-stream")
        super().end_headers()
    def log_message(self, fmt, *args):
        sys.stderr.write("[serve] %s\n" % (fmt % args))

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", PORT), H) as httpd:
    print(f"[serve] http://127.0.0.1:{PORT}/  root={ROOT}", flush=True)
    httpd.serve_forever()
