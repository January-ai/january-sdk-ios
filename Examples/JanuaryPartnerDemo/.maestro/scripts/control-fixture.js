// Configures how the fixture server answers one route for the rest of the flow.
//
//   - runScript:
//       file: ../scripts/control-fixture.js
//       env:
//         ROUTE: /v1.2/foods        # request path to affect
//         STATUS: "500"             # HTTP status to return (default 200)
//         DELAY: "4"                # seconds to wait before answering (default 0)
//         EMPTY: "true"             # return an empty collection (default false)
//         HOLD: "true"              # answer only after release-fixture.js (default false)
// Maestro runs this on the host; override with -e FIXTURE_CONTROL=... when the
// fixture server listens elsewhere.
const control = typeof FIXTURE_CONTROL === 'string' && FIXTURE_CONTROL ? FIXTURE_CONTROL : 'http://127.0.0.1:18768';
const status = typeof STATUS === 'string' && STATUS ? STATUS : '200';
const delay = typeof DELAY === 'string' && DELAY ? DELAY : '0';
const empty = typeof EMPTY === 'string' && EMPTY === 'true' ? 'true' : 'false';
const hold = typeof HOLD === 'string' && HOLD === 'true' ? 'true' : 'false';
const url =
  control +
  '/__control?route=' + encodeURIComponent(ROUTE) +
  '&status=' + status + '&delay=' + delay + '&empty=' + empty + '&hold=' + hold;
const response = http.get(url);
if (!response.ok) {
  throw new Error('Fixture control failed for ' + ROUTE + ': HTTP ' + response.status);
}
