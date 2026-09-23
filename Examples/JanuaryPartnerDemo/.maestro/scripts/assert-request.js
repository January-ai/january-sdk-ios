// Checks the most recent request the fixture server received on a route: that it
// was made for END_USER (the fixture tokens end with the end-user ID, and token
// requests send it in the January-End-User-ID header),
// that the query parameter QUERY_KEY equals QUERY_VALUE, that the compact JSON
// body contains every " && "-separated part of BODY_CONTAINS, and that the
// body's TIME_KEY timestamp is the seeded food log's time (TIME_EQUALS: seeded).
// Each check runs only when its variable is set.
//
//   - runScript:
//       file: ../scripts/assert-request.js
//       env:
//         ROUTE: /v1.2/water-logs
//         END_USER: qa-settings-user
// Maestro runs this on the host; override with -e FIXTURE_CONTROL=... when the
// fixture server listens elsewhere.
const control = typeof FIXTURE_CONTROL === 'string' && FIXTURE_CONTROL ? FIXTURE_CONTROL : 'http://127.0.0.1:18768';
const response = http.get(control + '/__requests');
if (!response.ok) {
  throw new Error('Reading the fixture requests failed: HTTP ' + response.status);
}
const matching = JSON.parse(response.body).filter((request) => request.path === ROUTE);
if (matching.length === 0) {
  throw new Error('The fixture server received no request on ' + ROUTE);
}
const last = matching[matching.length - 1];
if (typeof END_USER === 'string' && END_USER) {
  // API requests carry the user in the token; token requests carry the header.
  const suffix = '.' + END_USER;
  const authorization = last.authorization || '';
  if (authorization.slice(-suffix.length) !== suffix && last.end_user !== END_USER) {
    throw new Error('The last request on ' + ROUTE + ' was not made for ' + END_USER);
  }
}
if (typeof QUERY_KEY === 'string' && QUERY_KEY) {
  const actual = (last.query || {})[QUERY_KEY];
  if (actual !== QUERY_VALUE) {
    throw new Error('The last request on ' + ROUTE + ' had ' + QUERY_KEY + '=' + actual + ', expected ' + QUERY_VALUE);
  }
}
if (typeof BODY_CONTAINS === 'string' && BODY_CONTAINS) {
  const body = JSON.stringify(last.body || {});
  for (const part of BODY_CONTAINS.split(' && ')) {
    if (body.indexOf(part) === -1) {
      throw new Error('The last request on ' + ROUTE + ' did not contain ' + part);
    }
  }
}
if (typeof TIME_KEY === 'string' && TIME_KEY) {
  const value = (last.body || {})[TIME_KEY];
  const expected = JSON.parse(http.get(control + '/__seeded').body).eaten_at;
  if (Math.abs(Date.parse(value) - Date.parse(expected)) >= 1000) {
    throw new Error('The last request on ' + ROUTE + ' sent ' + TIME_KEY + ' ' + value + ', expected the seeded log\'s ' + expected);
  }
}
