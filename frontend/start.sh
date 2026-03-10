elm make src/Main.elm --output=elm.js
kill $(lsof -ti:8081) 2>/dev/null
python3 -c "
import http.server, os

class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) or os.path.isdir(path) and not os.path.exists(os.path.join(path, 'index.html')):
            self.path = '/'
        return super().do_GET()

http.server.HTTPServer(('', 8081), SPAHandler).serve_forever()
"
