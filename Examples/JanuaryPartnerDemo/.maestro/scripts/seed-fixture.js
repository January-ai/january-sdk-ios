// Seeds the fixture server with one saved food log ("Fixture breakfast").
// Maestro runs this on the host; override with -e FIXTURE_CONTROL=... when the
// fixture server listens elsewhere.
const control = typeof FIXTURE_CONTROL === 'string' && FIXTURE_CONTROL ? FIXTURE_CONTROL : 'http://127.0.0.1:18768';
const response = http.get(control + '/__seed');
if (!response.ok) {
  throw new Error('Fixture seed failed: HTTP ' + response.status);
}
