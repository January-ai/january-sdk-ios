// Lets the fixture server answer the requests it is holding on ROUTE (see
// control-fixture.js HOLD), after a flow has checked the loading state.
//
//   - runScript:
//       file: ../scripts/release-fixture.js
//       env:
//         ROUTE: /v1.2/foods
// Maestro runs this on the host; override with -e FIXTURE_CONTROL=... when the
// fixture server listens elsewhere.
const control = typeof FIXTURE_CONTROL === 'string' && FIXTURE_CONTROL ? FIXTURE_CONTROL : 'http://127.0.0.1:18768';
const response = http.get(control + '/__release?route=' + encodeURIComponent(ROUTE));
if (!response.ok) {
  throw new Error('Fixture release failed for ' + ROUTE + ': HTTP ' + response.status);
}
