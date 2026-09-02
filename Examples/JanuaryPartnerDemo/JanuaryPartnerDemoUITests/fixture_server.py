import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

RULES = {}
NUTRIENTS = {"calories": {"value": 100, "unit": "kcal"}, "protein": {"value": 4, "unit": "g"}}
SERVINGS = [{"id": "11", "quantity": 1, "unit": "bowl", "scaling_factor": 1, "weight_grams": None, "is_primary": True}]
DIRECT_ITEMS = [
    {"id": "101", "name": "Fixture bowl", "nutrients": NUTRIENTS, "glycemic_index": None, "glycemic_load": None, "servings": SERVINGS},
    {"id": "102", "name": "Fixture soup", "nutrients": NUTRIENTS, "glycemic_index": None, "glycemic_load": None, "servings": SERVINGS},
]
SEARCH_ITEMS = [dict(item, type="menu_item", restaurant_name="Fixture Cafe", is_chain=False, distance_meters=100, image_url=None) for item in DIRECT_ITEMS]

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self):
        parsed = urlparse(self.path)
        query = {key: values[0] for key, values in parse_qs(parsed.query).items()}
        if parsed.path == "/__reset":
            RULES.clear(); return self.respond({})
        if parsed.path == "/__control":
            RULES[query["route"]] = {"status": int(query.get("status", 200)), "empty": query.get("empty") == "true"}
            return self.respond({})
        rule = RULES.get(parsed.path, {"status": 200, "empty": False})
        if rule["status"] != 200:
            message = f"No restaurant with id cafe. Use an id from a GET /v1.2/restaurants result." if rule["status"] == 404 else "The test request could not be completed."
            return self.respond({"code": "not_found" if rule["status"] == 404 else "fixture_error", "message": message, "request_id": "ios-ui-test"}, rule["status"])
        if parsed.path == "/v1.2/restaurants":
            items = [] if rule["empty"] else [{"type": "restaurant", "id": "cafe", "name": "Fixture Cafe", "is_chain": False, "distance_meters": 100, "city": "San Francisco", "address1": "123 Test Street", "address2": None}]
            return self.respond({"items": items})
        if parsed.path == "/v1.2/restaurants/cafe/menu-items":
            return self.respond({"items": [] if rule["empty"] else DIRECT_ITEMS})
        if parsed.path == "/v1.2/menu-items":
            return self.respond({"items": [] if rule["empty"] else SEARCH_ITEMS})
        return self.respond({"code": "not_found", "message": f"Unmapped fixture route {parsed.path}"}, 404)
    def respond(self, body, status=200):
        data = json.dumps(body).encode()
        self.send_response(status); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)

ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 18768), Handler).serve_forever()
