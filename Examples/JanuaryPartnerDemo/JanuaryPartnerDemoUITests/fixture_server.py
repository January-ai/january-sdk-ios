"""Loopback-only OpenAPI fixtures for the January iOS demo UAT suite."""
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

NUTRIENTS = {key: {"value": value, "unit": unit} for key, value, unit in [
    ("calories", 100, "kcal"), ("protein", 4, "g"), ("carbohydrates", 20, "g"),
    ("total_fat", 2, "g"), ("fiber", 3, "g"), ("sodium", 10, "mg"),
]}
SERVINGS = [
    {"id": "11", "quantity": 1, "unit": "cup", "scaling_factor": 1, "weight_grams": 100, "is_primary": True},
    {"id": "12", "quantity": 1, "unit": "oz", "scaling_factor": 0.2835, "weight_grams": 28.35, "is_primary": False},
]

def food(identifier="101", name="Fixture oatmeal", full=True):
    return {
        "id": str(identifier), "type": "generic", "name": name, "brand_name": "January fixture",
        "nutrients": NUTRIENTS, "glycemic_index": 52, "glycemic_load": 12,
        "image_url": None, "barcode": None, "servings": SERVINGS if full else SERVINGS[:1],
    }

PREDICTION = {
    "points": [{"minutes": minute, "value": value} for minute, value in [(0, 90), (30, 125), (60, 140), (90, 115), (120, 95)]],
    "impact_score": "medium", "chart": {"min": 70, "max": 140},
}

def scan(name="Fixture breakfast"):
    return {"meal_name": name, "detections": [{"food": food(), "confidence": "high"}], "total_nutrients": NUTRIENTS}

def food_log(name="Fixture breakfast"):
    logged = food()
    logged.pop("servings"); logged.pop("type"); logged.pop("barcode")
    logged.update({"food_id": logged.pop("id"), "quantity": 1, "serving": {"id": "11", "quantity": 1, "unit": "cup", "weight_grams": 100}})
    return {"id": "opaque-log-1", "name": name, "eaten_at": "2026-09-01T16:00:00Z", "foods": [logged]}

STATE = {"rules": {}, "logs": [], "requests": []}

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self): self.handle_request()
    def do_POST(self): self.handle_request()
    def do_PATCH(self): self.handle_request()
    def do_DELETE(self): self.handle_request()

    def handle_request(self):
        parsed = urlparse(self.path); path = parsed.path
        query = {key: values[0] for key, values in parse_qs(parsed.query).items()}
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        body = json.loads(raw) if raw and "application/json" in self.headers.get("Content-Type", "") else {}
        if path == "/__reset": STATE.update(rules={}, logs=[], requests=[]); return self.respond({})
        if path == "/__control": STATE["rules"][query["route"]] = query; return self.respond({})
        if path == "/__seed": STATE["logs"] = [food_log()]; return self.respond({})
        if path == "/__requests": return self.respond(STATE["requests"])

        STATE["requests"].append({"method": self.command, "path": path, "query": query, "body": body})
        rule = STATE["rules"].get(path, {})
        if float(rule.get("delay", 0)): time.sleep(float(rule["delay"]))
        status = int(rule.get("status", 200)); empty = rule.get("empty") == "true"
        if status != 200:
            message = "No restaurant with id cafe. Use an id from a GET /v1.2/restaurants result." if status == 404 and "/restaurants/" in path else "The test request could not be completed."
            return self.respond({"code": "not_found" if status == 404 else "fixture_error", "message": message, "request_id": "ios-ui-test"}, status)

        if path.endswith("/autocomplete"): result = {"items": []}
        elif path.endswith("/alternatives"): result = {"alternatives": [] if empty else [food("102", "Fixture lentils")]}
        elif path.endswith("/foods/101"): result = food()
        elif path.endswith("/foods/102"): result = food("102", "Fixture lentils")
        elif path.endswith("/foods"): result = {"items": [] if empty else [food(full=False)]}
        elif "/foods/barcode/" in path: result = food(full=False)
        elif path.endswith("/restaurants/cafe/menu-items"):
            direct = [{"id": str(identifier), "name": name, "nutrients": NUTRIENTS, "glycemic_index": None, "glycemic_load": None, "servings": SERVINGS} for identifier, name in [(101, "Fixture bowl"), (102, "Fixture soup")]]
            result = {"items": [] if empty or int(query.get("offset", 0)) > 0 else direct}
        elif path.endswith("/menu-items") and "/restaurants/" not in path:
            result = {"items": [] if empty else [{"type": "menu_item", "id": str(identifier), "name": name, "restaurant_name": "Fixture Cafe", "is_chain": False, "distance_meters": 100, "image_url": None, "nutrients": NUTRIENTS, "glycemic_index": None, "glycemic_load": None, "servings": SERVINGS} for identifier, name in [(101, "Fixture bowl"), (102, "Fixture soup")]]}
        elif path.endswith("/restaurants"):
            result = {"items": [] if empty else [{"type": "restaurant", "id": "cafe", "name": "Fixture Cafe", "is_chain": False, "distance_meters": 100, "city": "San Francisco", "address1": "123 Test Street", "address2": None}]}
        elif path.endswith("/glucose/predictions"): result = PREDICTION
        elif path.endswith("/food-analysis/image"): result = scan()
        elif path.endswith("/food-analysis/corrections"): result = scan("Corrected breakfast")
        elif path.endswith("/food-analysis/text"): result = {"meal_name": None, "detections": [] if empty else [{"food": food(), "confidence": None}], "total_nutrients": NUTRIENTS}
        elif "/food-logs" in path:
            if self.command == "GET": result = {"items": STATE["logs"]}
            elif self.command == "DELETE": STATE["logs"] = []; return self.respond({}, 204)
            else: result = food_log(body.get("name") or "Fixture breakfast"); STATE["logs"] = [result]
        else: return self.respond({"code": "not_found", "message": f"Unmapped fixture route {path}"}, 404)
        return self.respond(result, 201 if self.command == "POST" and path.endswith("/food-logs") else 200)

    def respond(self, body, status=200):
        data = b"" if status == 204 else json.dumps(body).encode()
        self.send_response(status); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(data))); self.end_headers()
        try: self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError): pass

ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 18768), Handler).serve_forever()
