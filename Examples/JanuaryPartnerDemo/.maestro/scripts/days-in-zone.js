// Sets the end user's calendar days in TIMEZONE, which the app must use whatever
// the device's timezone is: output.today and output.yesterday (yyyy-MM-dd), and
// output.yesterdayNoon, the instant of noon yesterday on that clock (ISO 8601).
//
//   - runScript:
//       file: ../scripts/days-in-zone.js
//       env:
//         TIMEZONE: Pacific/Kiritimati
const parts = (date) => {
  const values = {};
  new Intl.DateTimeFormat('en-US', {
    timeZone: TIMEZONE, hourCycle: 'h23',
    year: 'numeric', month: 'numeric', day: 'numeric', hour: 'numeric', minute: 'numeric', second: 'numeric',
  }).formatToParts(date).forEach((part) => { values[part.type] = Number(part.value); });
  return values;
};
const pad = (value) => (value < 10 ? '0' : '') + value;
const day = (utc) => utc.getUTCFullYear() + '-' + pad(utc.getUTCMonth() + 1) + '-' + pad(utc.getUTCDate());

const now = parts(new Date());
output.today = day(new Date(Date.UTC(now.year, now.month - 1, now.day)));
output.yesterday = day(new Date(Date.UTC(now.year, now.month - 1, now.day - 1)));
// Noon on that clock: start from noon UTC and remove the zone's offset at that moment.
const guess = Date.UTC(now.year, now.month - 1, now.day - 1, 12);
const wall = parts(new Date(guess));
const offset = Date.UTC(wall.year, wall.month - 1, wall.day, wall.hour, wall.minute, wall.second) - guess;
output.yesterdayNoon = new Date(guess - offset).toISOString();
