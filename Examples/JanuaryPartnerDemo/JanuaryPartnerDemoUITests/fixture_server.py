"""Loopback-only OpenAPI fixtures for the January iOS demo UAT suite."""
import json
import math
import sys
import time
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
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
        "image_url": None, "barcode": "012345678905", "servings": SERVINGS if full else SERVINGS[:1],
    }

PREDICTION = {
    "points": [{"minutes": minute, "value": value} for minute, value in [(0, 90), (30, 125), (60, 140), (90, 115), (120, 95)]],
    "impact_score": "medium", "chart": {"min": 70, "max": 140},
}

def detected(identifier="101", name="Fixture oatmeal"):
    return {
        "id": str(identifier), "name": name, "brand_name": "January fixture", "nutrients": NUTRIENTS,
        "quantity": 1, "serving": {"id": "11", "quantity": 1, "unit": "cup"},
    }

def suggestions(query):
    """Autocomplete suggests the fixture foods only for queries that start with "fix", so flows
    that type other queries never see a suggestion list."""
    if not query.lower().startswith("fix"): return []
    return [{"id": "101", "type": "generic", "name": "Fixture oatmeal", "brand_name": "January fixture", "image_url": None, "nutrients": NUTRIENTS},
            {"id": "102", "type": "generic", "name": "Fixture lentils", "brand_name": "January fixture", "image_url": None, "nutrients": NUTRIENTS}]

def scan(name="Fixture breakfast"):
    return {"meal_name": name, "detections": [{"food": detected(), "confidence": "high"}], "total_nutrients": NUTRIENTS}

def seeded_eaten_at():
    """A minute after midnight today in this machine's timezone (the simulator's), so the seeded
    log is always today's and its time differs from the time a flow runs."""
    first_minute = datetime.now().astimezone().replace(hour=0, minute=1, second=0, microsecond=0)
    return first_minute.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def logged_on(log, query):
    """Whether a log was eaten within the request's start_date..end_date in its timezone."""
    start, end = query.get("start_date"), query.get("end_date")
    if not start or not end: return True
    try: zone = ZoneInfo(query.get("timezone", "UTC"))
    except Exception: zone = timezone.utc
    eaten = datetime.fromisoformat(log["eaten_at"].replace("Z", "+00:00")).astimezone(zone).date().isoformat()
    return start <= eaten <= end

def food_log(name="Fixture breakfast", foods=None, eaten_at=None):
    """One saved log with the foods a create or update sent (food 102 is the lentils), or the oatmeal."""
    logged_foods = []
    for selection in foods or [{"food_id": "101", "serving_id": "11", "quantity": 1}]:
        identifier = str(selection.get("food_id", "101"))
        logged = food(identifier, "Fixture lentils" if identifier == "102" else "Fixture oatmeal")
        logged.pop("servings"); logged.pop("type"); logged.pop("barcode")
        logged.update({"food_id": logged.pop("id"), "quantity": selection.get("quantity", 1),
                       "serving": {"id": str(selection.get("serving_id", "11")), "quantity": 1, "unit": "cup", "weight_grams": 100}})
        logged_foods.append(logged)
    return {"id": "opaque-log-1", "name": name, "eaten_at": eaten_at or seeded_eaten_at(), "foods": logged_foods}

STATE = {"rules": {}, "logs": [], "water": [], "weights": [], "history": False, "requests": [], "seeded_eaten_at": None}
ML_PER_FL_OZ = 29.5735
ML_PER_UNIT = {"fl_oz": ML_PER_FL_OZ, "cup": ML_PER_FL_OZ * 8, "ml": 1}
LB_PER_KG = 1 / 0.45359237
HISTORY_DAYS = 400
LIST_LIMIT = 100

def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

def local_today(query):
    try: zone = ZoneInfo(query.get("timezone", "UTC"))
    except Exception: zone = timezone.utc
    return datetime.now(zone).date().isoformat()

def scaled_nutrients(count):
    return {key: {"value": amount["value"] * count, "unit": amount["unit"]} for key, amount in NUTRIENTS.items()}

def visible(entries, user):
    """The logs a user sees: their own and the seeded ones, which belong to no user."""
    return [entry for entry in entries if entry.get("user") in (None, user)]

def food_log_summary(query, user=None):
    count = len([log for log in visible(STATE["logs"], user) if logged_on(log, query)]); days = 1 if count else 0
    start = query.get("start_date", local_today(query)); end = query.get("end_date", start)
    bucket = {"start_date": start, "end_date": end, "logs_count": count, "days_with_logs": days, "nutrients": scaled_nutrients(count) if count else {}}
    return {"group_by": query.get("group_by", "day"), "week_start": None, "timezone": query.get("timezone", "UTC"), "start_date": start, "end_date": end,
            "buckets": [bucket], "totals": {"logs_count": count, "days_with_logs": days, "nutrients": bucket["nutrients"]},
            "average_per_logged_day": {"nutrients": bucket["nutrients"]}}

def history_water(days_ago):
    """Milliliters drunk `days_ago` days before today in the seeded history; every sixth day is blank."""
    if days_ago % 6 == 5: return None
    return 1500 + (days_ago * 137) % 900

def history_weight(days_ago):
    """The seeded history's weight: a slow downward trend with a two-week wobble. Every seventh day
    is blank, and every tenth is logged in pounds, as a user switching scales would."""
    if days_ago % 7 == 3: return None
    kilograms = round(70 + days_ago * 0.012 + 0.4 * math.sin(days_ago / 2.5), 1)
    return {"value": round(kilograms * LB_PER_KG, 1), "unit": "lb"} if days_ago % 10 == 0 else {"value": kilograms, "unit": "kg"}

def daily_items(query, today_item, history_item):
    """One item per local day inside start_date..end_date, oldest first, capped at the most recent
    LIST_LIMIT days like the API. Today comes from logs created in this run; earlier days come from
    the seeded history (when seeded)."""
    today = datetime.fromisoformat(local_today(query)).date()
    start = query.get("start_date", today.isoformat()); end = query.get("end_date", today.isoformat())
    items = []
    if STATE["history"]:
        for days_ago in range(HISTORY_DAYS, 0, -1):
            date = (today - timedelta(days=days_ago)).isoformat()
            if start <= date <= end and (item := history_item(date, days_ago)): items.append(item)
    if start <= today.isoformat() <= end and (item := today_item(today.isoformat())): items.append(item)
    return items[-LIST_LIMIT:]

def volume(amount, unit):
    """Converts a logged {value, unit} to the unit a listing asks for."""
    value = float(amount.get("value", 0))
    if amount.get("unit") == unit: return value
    return value * ML_PER_UNIT[amount.get("unit", "ml")] / ML_PER_UNIT[unit]

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
        if path == "/__reset": STATE.update(rules={}, logs=[], water=[], weights=[], history=False, requests=[], seeded_eaten_at=None); return self.respond({})
        if path == "/__history": STATE["history"] = True; return self.respond({})
        if path == "/__control": STATE["rules"][query["route"]] = query; return self.respond({})
        if path == "/__seed": STATE["logs"] = [food_log()]; STATE["seeded_eaten_at"] = STATE["logs"][0]["eaten_at"]; return self.respond({})
        if path == "/__seeded": return self.respond({"eaten_at": STATE["seeded_eaten_at"]})
        if path == "/__requests": return self.respond(STATE["requests"])
        # Lets a flow wait out a delayed response: /__sleep?seconds=3
        if path == "/__sleep": time.sleep(float(query.get("seconds", 1))); return self.respond({})

        STATE["requests"].append({"method": self.command, "path": path, "query": query, "body": body, "at": time.time(),
                                  "authorization": self.headers.get("Authorization"), "end_user": self.headers.get("January-End-User-ID")})
        rule = STATE["rules"].get(path, {})
        if float(rule.get("delay", 0)): time.sleep(float(rule["delay"]))
        status = int(rule.get("status", 200)); empty = rule.get("empty") == "true"
        if status != 200:
            message = "No restaurant with id cafe. Use an id from a GET /v1.2/restaurants result." if status == 404 and "/restaurants/" in path else "The test request could not be completed."
            return self.respond({"code": "not_found" if status == 404 else "fixture_error", "message": message, "request_id": "ios-ui-test"}, status)

        # A stand-in for the token relay, so a Debug build can rehearse the client-token flow here.
        if path == "/api/january/client-token":
            return self.respond({"token": f"fixture-relay-token.{self.headers.get('January-End-User-ID', '')}", "expiresIn": 1800})
        # The fixture tokens end with the end-user ID, so logs are kept per user.
        user = (self.headers.get("Authorization") or "").partition("-token.")[2] or None
        if path.endswith("/autocomplete"): result = {"items": [] if empty else suggestions(query.get("query", ""))}
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
        elif path.endswith("/food-analysis/text"): result = {"meal_name": None, "detections": [] if empty else [{"food": detected(), "confidence": None}], "total_nutrients": NUTRIENTS}
        elif path.endswith("/food-logs/summary"): result = food_log_summary(query, user)
        elif "/food-logs" in path:
            if self.command == "GET":
                result = {"items": [{key: value for key, value in log.items() if key != "user"}
                                    for log in visible(STATE["logs"], user) if logged_on(log, query)]}
            elif self.command == "DELETE": STATE["logs"] = [log for log in STATE["logs"] if log not in visible(STATE["logs"], user)]; return self.respond({}, 204)
            else:
                result = food_log(body.get("name") or "Fixture breakfast", body.get("foods"), body.get("eaten_at"))
                STATE["logs"] = [log for log in STATE["logs"] if log not in visible(STATE["logs"], user)] + [dict(result, user=user)]
        elif "/water-logs" in path:
            # Every log lands on today's local date; one daily total per day in the requested unit.
            if self.command == "GET":
                unit = query.get("unit", "fl_oz")
                def today_water(date):
                    mine = visible(STATE["water"], user)
                    if not mine: return None
                    return {"date": date, "total": {"value": round(sum(volume(entry["amount"], unit) for entry in mine), 1), "unit": unit}}
                def past_water(date, days_ago):
                    milliliters = history_water(days_ago)
                    return None if milliliters is None else {"date": date, "total": {"value": round(volume({"value": milliliters, "unit": "ml"}, unit), 1), "unit": unit}}
                result = {"items": [] if empty else daily_items(query, today_water, past_water)}
            elif self.command == "DELETE":
                log_id = path.rsplit("/", 1)[1]; STATE["water"] = [entry for entry in STATE["water"] if entry["id"] != log_id or entry.get("user") != user]
                return self.respond({}, 204)
            else:
                result = {"id": f"water-log-{len(STATE['water']) + 1}", "amount": body.get("amount"), "consumed_at": now_iso()}
                STATE["water"].append(dict(result, user=user))
        elif "/weight-logs" in path:
            # The latest measurement stands for today's local date, in the unit it was logged in.
            if self.command == "GET":
                def today_weight(date):
                    mine = visible(STATE["weights"], user)
                    return {"date": date, "weight": mine[-1]["weight"]} if mine else None
                def past_weight(date, days_ago): return {"date": date, "weight": weight} if (weight := history_weight(days_ago)) else None
                result = {"items": [] if empty else daily_items(query, today_weight, past_weight)}
            else:
                result = {"weight": body.get("weight"), "measured_at": now_iso()}
                STATE["weights"].append(dict(result, user=user))
        else: return self.respond({"code": "not_found", "message": f"Unmapped fixture route {path}"}, 404)
        created = self.command == "POST" and (path.endswith("/food-logs") or path.endswith("/water-logs") or path.endswith("/weight-logs"))
        return self.respond(result, 201 if created else 200)

    def respond(self, body, status=200):
        data = b"" if status == 204 else json.dumps(body).encode()
        self.send_response(status); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(data))); self.end_headers()
        try: self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError): pass

ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 18768), Handler).serve_forever()
