// Clears the fixture server's rules, seeded logs and recorded requests so a
// flow never inherits another flow's error or delay configuration.
// Maestro runs this on the host; override with -e FIXTURE_CONTROL=... when the
// fixture server listens elsewhere.
const control = typeof FIXTURE_CONTROL === 'string' && FIXTURE_CONTROL ? FIXTURE_CONTROL : 'http://127.0.0.1:18768';
const response = http.get(control + '/__reset');
if (!response.ok) {
  throw new Error('Fixture server reset failed: HTTP ' + response.status);
}
