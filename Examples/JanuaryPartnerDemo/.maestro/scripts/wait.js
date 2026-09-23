// Waits on the host for SECONDS (default 1), for example until a response the
// fixture server delays has reached the app, before asserting what it changed.
//
//   - runScript:
//       file: ../scripts/wait.js
//       env:
//         SECONDS: "3"
// Maestro runs this on the host; override with -e FIXTURE_CONTROL=... when the
// fixture server listens elsewhere.
const control = typeof FIXTURE_CONTROL === 'string' && FIXTURE_CONTROL ? FIXTURE_CONTROL : 'http://127.0.0.1:18768';
const seconds = typeof SECONDS === 'string' && SECONDS ? SECONDS : '1';
const response = http.get(control + '/__sleep?seconds=' + encodeURIComponent(seconds));
if (!response.ok) {
  throw new Error('Fixture wait failed: HTTP ' + response.status);
}
