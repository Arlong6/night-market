#!/usr/bin/env python3
"""W1 [P-18] — 同時服務 build 與收 beacon 的伺服器

同源，省掉 CORS（sendBeacon 跨源是 no-cors，送得出去但看不到回應，
而我們要的是「伺服器端實收數」，同源最乾淨）。

GET  /*        → 服務 build（.gz 帶 content-encoding）
POST /beacon   → 記錄一筆，寫進 beacons.log
GET  /_log     → 回傳目前收到的全部，給測試腳本讀
"""
import http.server, socketserver, sys, os, json, time, threading

PORT = int(sys.argv[1]); ROOT = sys.argv[2]
LOG = os.path.join(os.path.dirname(os.path.abspath(ROOT)), "beacons.log")
lock = threading.Lock()
received = []

class H(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def __init__(self, *a, **kw): super().__init__(*a, directory=ROOT, **kw)

    def do_POST(self):
        if self.path.split("?")[0] == "/beacon":
            n = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(n).decode("utf-8", "replace") if n else ""
            with lock:
                received.append({"t": round(time.time(), 3), "body": body})
                open(LOG, "a").write(body + "\n")
            sys.stderr.write(f"[beacon] {body}\n")
            self.send_response(204); self.send_header("Content-Length","0"); self.end_headers()
        else:
            self.send_response(404); self.send_header("Content-Length","0"); self.end_headers()

    def do_GET(self):
        if self.path.split("?")[0] == "/_log":
            with lock: data = json.dumps(received).encode()
            self.send_response(200)
            self.send_header("Content-Type","application/json")
            self.send_header("Content-Length",str(len(data)))
            self.send_header("Access-Control-Allow-Origin","*")
            self.end_headers(); self.wfile.write(data); return
        super().do_GET()

    def end_headers(self):
        p = self.path.split("?")[0]
        if p.endswith(".gz"):
            self.send_header("Content-Encoding","gzip")
            if p.endswith(".js.gz"):     self.send_header("Content-Type","application/javascript")
            elif p.endswith(".wasm.gz"): self.send_header("Content-Type","application/wasm")
            else:                        self.send_header("Content-Type","application/octet-stream")
        self.send_header("Cache-Control","no-store")
        super().end_headers()

    def log_message(self, *a): pass

socketserver.ThreadingTCPServer.allow_reuse_address = True
with socketserver.ThreadingTCPServer(("127.0.0.1", PORT), H) as httpd:
    print(f"[beacon-server] http://127.0.0.1:{PORT}/  root={ROOT}  log={LOG}", flush=True)
    httpd.serve_forever()
