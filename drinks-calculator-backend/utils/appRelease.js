// utils/appRelease.js
// What the LATEST published build of the app is, so a device can tell its user that an
// update exists.
//
// WHY THIS EXISTS. The app is handed out as a direct APK download — there is no Play
// Store to notify anyone. A store would tell each phone "a new version is out"; with a
// direct download nothing does, so the shop silently stays on an old build for ever.
// The backend answers "what is the latest?" and the app compares that with the version
// it is actually running.
//
// NOTHING IS GUESSED. Every value comes from the environment
// (APP_LATEST_VERSION, APP_LATEST_BUILD, APP_APK_URL, APP_RELEASE_NOTES,
// APP_UPDATE_MANDATORY). Unset means "we do not know", which the caller reports as null
// and the app renders as nothing at all. A wrong version number here would send a shop
// chasing an update that does not exist — worse than saying nothing.
//
// Pure, so the rule is testable without a server (tests/app_release.test.js).

/// Digits and dots only: "1.2.0", "2". Anything else is not a version we will compare.
const VERSION_PATTERN = /^\d+(\.\d+){0,3}$/;

function normaliseVersion(value) {
  if (value === null || value === undefined) return null;
  const text = String(value).trim().replace(/^v/i, '');
  return VERSION_PATTERN.test(text) ? text : null;
}

function normaliseBuild(value) {
  if (value === null || value === undefined || String(value).trim() === '') {
    return null;
  }
  const parsed = Number(String(value).trim());
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

/// An http(s) link, or null. Anything else (a bare path, a `javascript:` URL) is
/// refused: the app hands this straight to the phone's browser.
function normaliseUrl(value) {
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  return /^https?:\/\/\S+$/i.test(text) ? text : null;
}

function normaliseNotes(value) {
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  return text === '' ? null : text.slice(0, 500);
}

/**
 * The release a shop should be told about, read from the environment.
 *
 * `known: false` means nothing is configured: the caller must not invent a version.
 * A version without a download link is still reported — useful ("a newer build
 * exists, ask your supplier") — and the app simply offers no Download button.
 */
function readRelease(env = {}) {
  const latestVersion = normaliseVersion(env.APP_LATEST_VERSION);
  const known = latestVersion !== null;
  return {
    known,
    latestVersion: known ? latestVersion : null,
    latestBuild: known ? normaliseBuild(env.APP_LATEST_BUILD) : null,
    downloadUrl: known ? normaliseUrl(env.APP_APK_URL) : null,
    notes: known ? normaliseNotes(env.APP_RELEASE_NOTES) : null,
    mandatory:
      known &&
      String(env.APP_UPDATE_MANDATORY || '').trim().toLowerCase() === 'true',
  };
}

module.exports = {
  readRelease,
  normaliseVersion,
  normaliseBuild,
  normaliseUrl,
};
