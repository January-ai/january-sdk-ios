"""Loopback-only OpenAPI fixtures for the January iOS demo UAT suite."""
import json
import math
import sys
import threading
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

def seeded_created_at():
    """A minute after midnight today in this machine's timezone (the simulator's), so the seeded
    log is always today's and its time differs from the time a flow runs."""
    first_minute = datetime.now().astimezone().replace(hour=0, minute=1, second=0, microsecond=0)
    return first_minute.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def logged_on(log, query):
    """Whether a log was eaten within the request's start_date..end_date in its timezone."""
    start, end = query.get("start_date"), query.get("end_date")
    if not start or not end: return True
    return start <= local_day(log["created_at"], query) <= end

def food_log(name="Fixture breakfast", foods=None, created_at=None, log_id="opaque-log-1"):
    """One saved log with the foods a create or update sent (food 102 is the lentils), or the oatmeal."""
    logged_foods = []
    for selection in foods or [{"food_id": "101", "serving_id": "11", "quantity": 1}]:
        identifier = str(selection.get("food_id", "101"))
        logged = food(identifier, "Fixture lentils" if identifier == "102" else "Fixture oatmeal")
        logged.pop("servings"); logged.pop("type"); logged.pop("barcode")
        logged.update({"food_id": logged.pop("id"), "quantity": selection.get("quantity", 1),
                       "serving": {"id": str(selection.get("serving_id", "11")), "quantity": 1, "unit": "cup", "weight_grams": 100}})
        logged_foods.append(logged)
    return {"id": log_id, "name": name, "created_at": created_at or seeded_created_at(), "foods": logged_foods}

STATE = {"rules": {}, "logs": [], "water": [], "weights": [], "history": False, "requests": [], "seeded_created_at": None, "next_log": 1}
# Routes whose responses wait until a flow releases them (/__control?...&hold=true, then
# /__release?route=...), so a flow can assert a loading state however slow the device is.
HOLDS = {}

def release_holds(route=None):
    for held in [route] if route else list(HOLDS):
        event = HOLDS.pop(held, None)
        if event: event.set()
ML_PER_FL_OZ = 29.5735
ML_PER_UNIT = {"fl_oz": ML_PER_FL_OZ, "cup": ML_PER_FL_OZ * 8, "ml": 1}
LB_PER_KG = 1 / 0.45359237
HISTORY_DAYS = 400
LIST_LIMIT = 100

def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

def request_zone(query):
    try: return ZoneInfo(query.get("timezone", "UTC"))
    except Exception: return timezone.utc

def local_today(query):
    return datetime.now(request_zone(query)).date().isoformat()

def local_day(timestamp, query):
    """The request timezone's calendar date of an ISO-8601 timestamp."""
    return datetime.fromisoformat(timestamp.replace("Z", "+00:00")).astimezone(request_zone(query)).date().isoformat()

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

def daily_items(query, day_item):
    """One item per local day inside start_date..end_date that has something logged, oldest first,
    capped at the most recent LIST_LIMIT days like the API. day_item(date, days_ago) combines the
    logs created in this run for that local date with the seeded history (days before today, when
    seeded)."""
    today = datetime.fromisoformat(local_today(query)).date()
    start = datetime.fromisoformat(query.get("start_date", today.isoformat())).date()
    end = datetime.fromisoformat(query.get("end_date", today.isoformat())).date()
    items, day = [], start
    while day <= end:
        if item := day_item(day.isoformat(), (today - day).days): items.append(item)
        day += timedelta(days=1)
    return items[-LIST_LIMIT:]

def seeded(days_ago):
    """Whether the seeded history covers a day that many days before today."""
    return STATE["history"] and 0 < days_ago <= HISTORY_DAYS

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
        if path == "/__reset":
            release_holds(); STATE.update(rules={}, logs=[], water=[], weights=[], history=False, requests=[], seeded_created_at=None, next_log=1)
            return self.respond({})
        if path == "/__history": STATE["history"] = True; return self.respond({})
        if path == "/__control":
            release_holds(query["route"]); STATE["rules"][query["route"]] = query
            if query.get("hold") == "true": HOLDS[query["route"]] = threading.Event()
            return self.respond({})
        if path == "/__release": release_holds(query["route"]); STATE["rules"].get(query["route"], {})["hold"] = "false"; return self.respond({})
        if path == "/__seed":
            STATE["logs"] = [food_log()]; STATE["seeded_created_at"] = STATE["logs"][0]["created_at"]; STATE["next_log"] = 2
            return self.respond({})
        if path == "/__seeded": return self.respond({"created_at": STATE["seeded_created_at"]})
        if path == "/__requests": return self.respond(STATE["requests"])
        # Lets a flow wait out a delayed response: /__sleep?seconds=3
        if path == "/__sleep": time.sleep(float(query.get("seconds", 1))); return self.respond({})

        STATE["requests"].append({"method": self.command, "path": path, "query": query, "body": body, "at": time.time(),
                                  "authorization": self.headers.get("Authorization"), "end_user": self.headers.get("January-End-User-ID")})
        rule = STATE["rules"].get(path, {})
        if rule.get("hold") == "true" and (held := HOLDS.get(path)): held.wait(timeout=120)
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
            elif self.command == "DELETE":
                log_id = path.rsplit("/", 1)[1]
                STATE["logs"] = [log for log in STATE["logs"] if not (log["id"] == log_id and log in visible(STATE["logs"], user))]
                return self.respond({}, 204)
            elif self.command == "PATCH":
                # Replaces the addressed log, keeping its ID and whatever the update leaves out.
                log_id = path.rsplit("/", 1)[1]
                existing = next((log for log in visible(STATE["logs"], user) if log["id"] == log_id), None)
                if existing is None: return self.respond({"code": "not_found", "message": f"No food log {log_id}"}, 404)
                foods = body.get("foods") or [{"food_id": food["food_id"], "serving_id": food["serving"]["id"], "quantity": food["quantity"]} for food in existing["foods"]]
                result = food_log(body.get("name") or existing["name"], foods, body.get("created_at") or existing["created_at"], log_id)
                STATE["logs"] = [dict(result, user=user) if log is existing else log for log in STATE["logs"]]
            else:
                # A new log alongside the others.
                result = food_log(body.get("name") or "Fixture breakfast", body.get("foods"), body.get("created_at"), f"opaque-log-{STATE['next_log']}")
                STATE["next_log"] += 1
                STATE["logs"].append(dict(result, user=user))
        elif "/water-logs" in path:
            # One daily total per local date (in the request's timezone), in the requested unit:
            # the logs consumed that day plus the seeded history.
            if self.command == "GET":
                unit = query.get("unit", "fl_oz")
                def day_water(date, days_ago):
                    amounts = [volume(entry["amount"], unit) for entry in visible(STATE["water"], user) if local_day(entry["created_at"], query) == date]
                    history = history_water(days_ago) if seeded(days_ago) else None
                    if history is not None: amounts.append(volume({"value": history, "unit": "ml"}, unit))
                    return {"date": date, "total": {"value": round(sum(amounts), 1), "unit": unit}} if amounts else None
                result = {"items": [] if empty else daily_items(query, day_water)}
            elif self.command == "DELETE":
                log_id = path.rsplit("/", 1)[1]; STATE["water"] = [entry for entry in STATE["water"] if entry["id"] != log_id or entry.get("user") != user]
                return self.respond({}, 204)
            else:
                result = {"id": f"water-log-{len(STATE['water']) + 1}", "amount": body.get("amount"), "created_at": body.get("created_at") or now_iso()}
                STATE["water"].append(dict(result, user=user))
        elif "/weight-logs" in path:
            # Each local date's latest measurement, in the unit it was logged in, or else the
            # seeded history's.
            if self.command == "GET":
                def day_weight(date, days_ago):
                    measured = sorted((entry["created_at"], index, entry["weight"]) for index, entry in enumerate(visible(STATE["weights"], user))
                                      if local_day(entry["created_at"], query) == date)
                    weight = measured[-1][2] if measured else (history_weight(days_ago) if seeded(days_ago) else None)
                    return {"date": date, "weight": weight} if weight else None
                result = {"items": [] if empty else daily_items(query, day_weight)}
            else:
                result = {"weight": body.get("weight"), "created_at": body.get("created_at") or now_iso()}
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
