// Live flows only: reads the January API directly, as the flow's end user, to
// check what the demo just showed or saved. It gets a client token from the same
// token endpoint the app uses and never prints it.
//
//   - runScript:
//       file: ../scripts/live-api.js
//       env:
//         CHECK: water          # what to read or check, see below
//         DAY: ${maestro.copiedText}
//         UNIT: fl_oz
//         EXPECT: "8"
//
// Checks (each also leaves what it read in output.live for later steps):
//   preflight                         checks the settings; no requests
//   search       QUERY [TYPE]         output.live.firstFood: the first result's name, and
//                                     output.live.firstFoodPattern to find it on screen
//   barcode      QUERY                output.live.barcode from a branded result, and
//                                     output.live.barcodeFoodPattern for what the API returns for it
//   water        DAY UNIT [EXPECT]    the day's total in UNIT ("none" when nothing is logged);
//                                     output.live.water, output.live.waterText ("8 fl oz")
//   water-week   DAY UNIT             output.live.waterWeek: the Week chart's summary
//   cup-support  DAY                  output.live.cupRejected: whether totals in cups are refused
//   weight       DAY [EXPECT]         the day's weight ("72.5 kg" or "none"); output.live.weightText
//   weight-week  DAY UNIT             output.live.weightWeek: the Week chart's summary in UNIT
//   food-log     DAY NAME EXPECT_COUNT [EXPECT_FOODS]
//                                     how many of the day's logs are named NAME, and their food count
//   summary      DAY [EXPECT_LOGS]    output.live.logsCount: the day's logs_count, and
//                                     output.live.dayTotalsText as the Tracking tab shows it
//   cleanup      DAY NAME_PREFIX      deletes the day's food logs whose name starts with NAME_PREFIX
//   find-food    QUERY                output.live.foodIndex: where the portion food is in the demo's
//                                     search for QUERY (the same request its food picker makes)
//   portion-log  DAY NAME SHEET_CALORIES [EXPECT_SERVINGS]
//                                     checks the newest log named NAME: one food, the portion food's
//                                     serving, EXPECT_SERVINGS servings (default 1), and calories
//                                     within 2% of SHEET_CALORIES, what the serving sheet showed.
//                                     output.live.portionCaloriesText is those calories as the app
//                                     shows them; output.live.portionLogIDs, the day's logs named NAME
//   delete-food-logs                  deletes output.live.portionLogIDs
//
// The portion food is PORTION_FOOD_ID and its serving PORTION_SERVING_ID, by default the API's
// greek yogurt 70376084 and its 6 oz serving 34157706 (100 kcal a serving).
//
// DAY may be the Tracking day label ("Today, 2026-09-22"); its date is used.
// Without DAY, checks use today in TIMEZONE.
// Environment: END_USER_ID (required), TOKEN_URL (default: the local token relay;
// it must need no session token, as the flows pass no credentials), API_URL
// (default: the January API), TIMEZONE (default: this machine's).
//
// A 429 from the API stops the check with an error that starts with
// "RATE_LIMITED", which run-live.mjs recognizes: it stops the run there and
// prints how to resume, rather than letting every later step fail. Requests
// from this script are spaced at least a second apart.
const tokenURL = typeof TOKEN_URL === 'string' && TOKEN_URL ? TOKEN_URL : 'http://127.0.0.1:8787/api/january/client-token';
const apiURL = (typeof API_URL === 'string' && API_URL ? API_URL : 'https://partners.january.ai').replace(/\/$/, '');
if (typeof END_USER_ID !== 'string' || !END_USER_ID) {
  throw new Error('Set END_USER_ID (-e END_USER_ID=...) to the test user the live flows may write to.');
}
const timezone = (function () {
  if (typeof TIMEZONE === 'string' && TIMEZONE) return TIMEZONE;
  try { return Intl.DateTimeFormat().resolvedOptions().timeZone; } catch (error) { return 'UTC'; }
})();
const day = (function () {
  const match = typeof DAY === 'string' ? DAY.match(/\d{4}-\d{2}-\d{2}/) : null;
  if (match) return match[0];
  // Today in TIMEZONE, as YYYY-MM-DD.
  try { return new Intl.DateTimeFormat('en-CA', { timeZone: timezone }).format(new Date()); } catch (error) { return null; }
})();

const portionFoodID = typeof PORTION_FOOD_ID === 'string' && PORTION_FOOD_ID ? PORTION_FOOD_ID : '70376084';
const portionServingID = typeof PORTION_SERVING_ID === 'string' && PORTION_SERVING_ID ? PORTION_SERVING_ID : '34157706';

if (!output.live) output.live = {};

function accessToken() {
  const cached = output.liveAuthorization;
  if (cached && cached.user === END_USER_ID && cached.expiresAt > Date.now() + 60000) return cached.token;
  pace();
  const response = http.post(tokenURL, { headers: { 'January-End-User-ID': END_USER_ID }, body: '' });
  stopIfRateLimited(response, 'the token request');
  if (response.status === 401 || response.status === 403) {
    throw new Error('The token endpoint requires a session token (HTTP ' + response.status + '); use one that needs none, such as the local relay.');
  }
  if (!response.ok) throw new Error('The token endpoint answered HTTP ' + response.status);
  const body = JSON.parse(response.body);
  const seconds = Number(body.expiresIn || body.expires_in || 300);
  output.liveAuthorization = { user: END_USER_ID, token: body.token, expiresAt: Date.now() + seconds * 1000 };
  return body.token;
}

function pace() {
  const earliest = (output.liveLastRequestAt || 0) + 1000;
  while (Date.now() < earliest) { /* keep under the per-user request rate */ }
  output.liveLastRequestAt = Date.now();
}

function stopIfRateLimited(response, what) {
  if (response.status !== 429) return;
  let detail = '';
  try { detail = JSON.parse(response.body).message || ''; } catch (error) { detail = String(response.body); }
  console.log('live-api ' + what + ' -> HTTP 429 ' + detail);
  throw new Error('RATE_LIMITED: the January API refused ' + what + ' with HTTP 429. ' + detail);
}

function request(method, path) {
  pace();
  const response = http.request(apiURL + path, {
    method: method,
    headers: { Authorization: 'Bearer ' + accessToken(), 'Content-Type': 'application/json' },
  });
  console.log('live-api ' + method + ' ' + path + ' -> HTTP ' + response.status);
  stopIfRateLimited(response, method + ' ' + path);
  return response;
}

function getJSON(path) {
  const response = request('GET', path);
  if (!response.ok) throw new Error('GET ' + path + ' answered HTTP ' + response.status + ': ' + response.body);
  return JSON.parse(response.body);
}

function requireDay() {
  if (!day) throw new Error('Set DAY to a date such as 2026-09-22 or the Tracking day label.');
  return day;
}

function query(params) {
  return Object.keys(params)
    .filter(function (key) { return params[key] !== undefined && params[key] !== null && params[key] !== ''; })
    .map(function (key) { return encodeURIComponent(key) + '=' + encodeURIComponent(params[key]); })
    .join('&');
}

/// Formats like the app: up to one decimal, with thousands separators (en_US).
function number(value) {
  const rounded = Math.round(value * 10) / 10;
  const parts = String(Math.abs(rounded)).split('.');
  parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return (rounded < 0 ? '-' : '') + parts.join('.');
}

const unitTitles = { fl_oz: 'fl oz', ml: 'ml', cup: 'cup' };

function escapePattern(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function shiftDay(value, days) {
  const parts = value.split('-').map(Number);
  const date = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2] + days));
  return date.toISOString().slice(0, 10);
}

function expectNumber(label, actual, expected) {
  if (expected === undefined || expected === null || expected === '') return;
  if (expected === 'none') {
    if (actual !== null) throw new Error(label + ': expected nothing logged, the API has ' + actual);
    return;
  }
  if (actual === null || Math.abs(actual - Number(expected)) > 0.051) {
    throw new Error(label + ': expected ' + expected + ', the API has ' + actual);
  }
}

const check = typeof CHECK === 'string' ? CHECK : '';
switch (check) {
  case 'search': {
    const body = getJSON('/v1.2/foods?' + query({ query: QUERY, type: typeof TYPE === 'string' ? TYPE : '', limit: 10, offset: 0 }));
    if (body.items.length === 0) throw new Error('The API found no foods for ' + QUERY);
    output.live.firstFood = body.items[0].name;
    // A pattern that finds the name inside a result row's text.
    output.live.firstFoodPattern = '.*' + escapePattern(body.items[0].name) + '.*';
    console.log('live-api search "' + QUERY + '": ' + body.items.length + ' results, first "' + output.live.firstFood + '"');
    break;
  }
  case 'barcode': {
    // A barcode from a branded search, then what the API returns for it.
    const found = getJSON('/v1.2/foods?' + query({ query: QUERY, type: 'branded', limit: 20, offset: 0 }))
      .items.filter(function (item) { return typeof item.barcode === 'string' && /^\d{6,14}$/.test(item.barcode); });
    if (found.length === 0) throw new Error('No branded result for ' + QUERY + ' has a barcode');
    const food = getJSON('/v1.2/foods/barcode/' + found[0].barcode);
    const item = food.items ? food.items[0] : food;
    output.live.barcode = found[0].barcode;
    output.live.barcodeFoodPattern = '.*' + escapePattern(item.name) + '.*';
    console.log('live-api barcode ' + output.live.barcode + ': "' + item.name + '"');
    break;
  }
  case 'water': {
    const body = getJSON('/v1.2/water-logs?' + query({ start_date: requireDay(), end_date: day, timezone: timezone, unit: UNIT }));
    const total = body.items.length > 0 ? body.items[0].total.value : null;
    output.live.water = total === null ? 0 : total;
    output.live.waterText = total === null ? 'No water logged' : number(total) + ' ' + unitTitles[UNIT];
    console.log('live-api water ' + day + ' in ' + UNIT + ': ' + (total === null ? 'none' : total));
    expectNumber('Water on ' + day, total, typeof EXPECT === 'string' ? EXPECT : '');
    break;
  }
  case 'water-week': {
    const start = shiftDay(requireDay(), -6);
    const body = getJSON('/v1.2/water-logs?' + query({ start_date: start, end_date: day, timezone: timezone, unit: UNIT }));
    const logged = body.items.filter(function (item) { return item.total.value > 0; });
    const total = logged.reduce(function (sum, item) { return sum + item.total.value; }, 0);
    output.live.waterWeek = logged.length === 0
      ? 'Water, last 7 days: nothing logged'
      : 'Water, last 7 days: ' + logged.length + (logged.length === 1 ? ' day' : ' days') + ' logged, ' + number(total) + ' ' + unitTitles[UNIT] + ' in total';
    console.log('live-api ' + output.live.waterWeek);
    break;
  }
  case 'cup-support': {
    // Accepted (200) or refused as an invalid request (400); anything else is a failure, not
    // an answer about cups.
    const response = request('GET', '/v1.2/water-logs?' + query({ start_date: requireDay(), end_date: day, timezone: timezone, unit: 'cup' }));
    if (!response.ok && response.status !== 400) {
      throw new Error('Asking for water totals in cups answered HTTP ' + response.status + ': ' + response.body);
    }
    output.live.cupRejected = response.status === 400;
    console.log('live-api water totals in cups: ' + (response.ok ? 'accepted' : 'refused with HTTP 400 ' + response.body));
    break;
  }
  case 'weight': {
    const body = getJSON('/v1.2/weight-logs?' + query({ start_date: requireDay(), end_date: day, timezone: timezone }));
    const weight = body.items.length > 0 ? body.items[0].weight : null;
    output.live.weightText = weight === null ? 'No weight logged' : number(weight.value) + ' ' + weight.unit;
    console.log('live-api weight ' + day + ': ' + output.live.weightText);
    const expected = typeof EXPECT === 'string' ? EXPECT : '';
    if (expected === 'none' && weight !== null) throw new Error('Weight on ' + day + ': expected none, the API has ' + output.live.weightText);
    if (expected && expected !== 'none' && output.live.weightText !== expected) {
      throw new Error('Weight on ' + day + ': expected ' + expected + ', the API has ' + output.live.weightText);
    }
    break;
  }
  case 'weight-week': {
    const start = shiftDay(requireDay(), -6);
    const body = getJSON('/v1.2/weight-logs?' + query({ start_date: start, end_date: day, timezone: timezone }));
    const toUnit = function (weight) {
      if (weight.unit === UNIT) return weight.value;
      return UNIT === 'kg' ? weight.value * 0.45359237 : weight.value / 0.45359237;
    };
    const values = body.items
      .slice()
      .sort(function (a, b) { return a.date < b.date ? -1 : a.date > b.date ? 1 : 0; })
      .map(function (item) { return toUnit(item.weight); });
    const count = values.length === 1 ? '1 entry' : values.length + ' entries';
    output.live.weightWeek = values.length === 0
      ? 'Weight, last 7 days: no entries'
      : values.length === 1
        ? 'Weight, last 7 days: 1 entry, ' + number(values[0]) + ' ' + UNIT
        : 'Weight, last 7 days: ' + count + ', from ' + number(values[0]) + ' ' + UNIT + ' to ' + number(values[values.length - 1]) + ' ' + UNIT;
    console.log('live-api ' + output.live.weightWeek);
    break;
  }
  case 'food-log': {
    const body = getJSON('/v1.2/food-logs?' + query({ start_date: requireDay(), end_date: day, timezone: timezone }));
    const named = body.items.filter(function (log) { return log.name === NAME; });
    console.log('live-api food logs on ' + day + ' named "' + NAME + '": ' + named.length + (named.length ? ' with ' + named[0].foods.length + ' foods' : ''));
    if (named.length !== Number(EXPECT_COUNT)) {
      throw new Error('Expected ' + EXPECT_COUNT + ' food logs named ' + NAME + ' on ' + day + ', the API has ' + named.length);
    }
    if (typeof EXPECT_FOODS === 'string' && EXPECT_FOODS && named[0].foods.length !== Number(EXPECT_FOODS)) {
      throw new Error('Expected ' + EXPECT_FOODS + ' foods in ' + NAME + ', the API has ' + named[0].foods.length);
    }
    break;
  }
  case 'summary': {
    const body = getJSON('/v1.2/food-logs/summary?' + query({ start_date: requireDay(), end_date: day, timezone: timezone }));
    output.live.logsCount = body.totals.logs_count;
    output.live.dayTotalsText = 'Day totals · ' + body.totals.logs_count + (body.totals.logs_count === 1 ? ' log' : ' logs');
    console.log('live-api food log summary ' + day + ': ' + output.live.logsCount + ' logs');
    if (typeof EXPECT_LOGS === 'string' && EXPECT_LOGS && output.live.logsCount !== Number(EXPECT_LOGS)) {
      throw new Error('Expected ' + EXPECT_LOGS + ' logs on ' + day + ', the API summary has ' + output.live.logsCount);
    }
    break;
  }
  case 'cleanup': {
    const body = getJSON('/v1.2/food-logs?' + query({ start_date: requireDay(), end_date: day, timezone: timezone }));
    body.items
      .filter(function (log) { return typeof log.name === 'string' && log.name.indexOf(NAME_PREFIX) === 0; })
      .forEach(function (log) {
        const response = request('DELETE', '/v1.2/food-logs/' + encodeURIComponent(log.id));
        if (!response.ok) throw new Error('Deleting food log ' + log.id + ' answered HTTP ' + response.status);
      });
    break;
  }
  case 'find-food': {
    const body = getJSON('/v1.2/foods?' + query({ query: QUERY, limit: 10, offset: 0 }));
    let index = -1;
    for (let position = 0; position < body.items.length; position += 1) {
      if (String(body.items[position].id) === portionFoodID) { index = position; break; }
    }
    console.log('live-api search "' + QUERY + '": food ' + portionFoodID + (index < 0 ? ' is not in the ' + body.items.length + ' results' : ' is result ' + index));
    if (index < 0) {
      throw new Error('Food ' + portionFoodID + ' is not in the demo\'s results for ' + QUERY + ': '
        + body.items.map(function (item) { return item.id + ' ' + item.name; }).join(', '));
    }
    output.live.foodIndex = index;
    break;
  }
  case 'portion-log': {
    const body = getJSON('/v1.2/food-logs?' + query({ start_date: requireDay(), end_date: day, timezone: timezone }));
    const named = body.items
      .filter(function (log) { return log.name === NAME; })
      .sort(function (a, b) { return a.created_at < b.created_at ? 1 : a.created_at > b.created_at ? -1 : 0; });
    output.live.portionLogIDs = named.map(function (log) { return log.id; });
    if (named.length === 0) throw new Error('No food log named ' + NAME + ' on ' + day);
    if (named[0].foods.length !== 1) throw new Error('Expected 1 food in ' + NAME + ', the API has ' + named[0].foods.length);
    const food = named[0].foods[0];
    const calories = food.nutrients && food.nutrients.calories ? food.nutrients.calories.value : null;
    console.log('live-api ' + NAME + ': food ' + food.food_id + ', serving ' + food.serving.id + ' ('
      + food.serving.quantity + ' ' + food.serving.unit + '), ' + food.quantity + ' servings, ' + calories + ' kcal');
    if (String(food.food_id) !== portionFoodID || String(food.serving.id) !== portionServingID) {
      throw new Error('Expected food ' + portionFoodID + ' serving ' + portionServingID + ', the API logged food ' + food.food_id + ' serving ' + food.serving.id);
    }
    const servings = Number(typeof EXPECT_SERVINGS === 'string' && EXPECT_SERVINGS ? EXPECT_SERVINGS : 1);
    if (Math.abs(food.quantity - servings) > 0.001) {
      throw new Error('Expected ' + servings + ' serving(s) of ' + food.serving.quantity + ' ' + food.serving.unit + ', the API logged ' + food.quantity);
    }
    const sheet = Number(String(typeof SHEET_CALORIES === 'string' ? SHEET_CALORIES : '').replace(/,/g, ''));
    if (!(sheet > 0)) throw new Error('Set SHEET_CALORIES to the calories the serving sheet showed, not "' + SHEET_CALORIES + '"');
    if (calories === null || Math.abs(calories - sheet) > Math.max(1, sheet * 0.02)) {
      throw new Error('The serving sheet showed ' + sheet + ' kcal; the API logged ' + calories + ' kcal');
    }
    output.live.portionCaloriesText = number(calories);
    break;
  }
  case 'delete-food-logs': {
    (output.live.portionLogIDs || []).forEach(function (id) {
      const response = request('DELETE', '/v1.2/food-logs/' + encodeURIComponent(id));
      if (!response.ok) throw new Error('Deleting food log ' + id + ' answered HTTP ' + response.status);
    });
    output.live.portionLogIDs = [];
    break;
  }
  case 'preflight':
    console.log('live-api preflight: end user ' + END_USER_ID + ', timezone ' + timezone + ', API ' + apiURL);
    break;
  default:
    throw new Error('Unknown CHECK "' + check + '"');
}
