// Seeds the fixture server with 400 days of water and weight history before
// today, so the Tracking charts have data for every range. Weights are mostly
// in kilograms with every tenth day in pounds; some days are left blank. List
// requests still honour start_date/end_date and the 100-day limit.
// Maestro runs this on the host; override with -e FIXTURE_CONTROL=... when the
// fixture server listens elsewhere.
const control = typeof FIXTURE_CONTROL === 'string' && FIXTURE_CONTROL ? FIXTURE_CONTROL : 'http://127.0.0.1:18768';
const response = http.get(control + '/__history');
if (!response.ok) {
  throw new Error('Fixture history seed failed: HTTP ' + response.status);
}
