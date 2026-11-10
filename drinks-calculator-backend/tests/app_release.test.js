// tests/app_release.test.js
// The release notice behind GET /api/app/release — the only thing that can tell a shop
// a newer APK exists, because this distribution has no store to do it.
//
// The rule these tests pin: NOTHING IS GUESSED. With nothing configured the answer is
// "we do not know", because a version number that sends a shop chasing an update that
// does not exist is worse than silence.
const {
  readRelease,
  normaliseVersion,
  normaliseBuild,
  normaliseUrl,
} = require('../utils/appRelease');

describe('what counts as a version', () => {
  test('digits and dots, with an optional leading v', () => {
    expect(normaliseVersion('1.2.0')).toBe('1.2.0');
    expect(normaliseVersion(' 2 ')).toBe('2');
    expect(normaliseVersion('v1.2.3')).toBe('1.2.3');
  });

  test('anything else is refused rather than coerced', () => {
    expect(normaliseVersion('latest')).toBeNull();
    expect(normaliseVersion('1.2.0-beta')).toBeNull();
    expect(normaliseVersion('')).toBeNull();
    expect(normaliseVersion(null)).toBeNull();
    expect(normaliseVersion(undefined)).toBeNull();
  });
});

describe('the download link', () => {
  test('an http(s) link is kept', () => {
    expect(normaliseUrl('https://example.com/a.apk')).toBe(
      'https://example.com/a.apk'
    );
    expect(normaliseUrl('http://example.com/a.apk')).toBe(
      'http://example.com/a.apk'
    );
  });

  test('anything that is not a link is refused', () => {
    // The app hands this straight to the phone's browser, so it must be http(s).
    expect(normaliseUrl('javascript:alert(1)')).toBeNull();
    expect(normaliseUrl('/downloads/app.apk')).toBeNull();
    expect(normaliseUrl('ftp://example.com/a.apk')).toBeNull();
    expect(normaliseUrl('')).toBeNull();
  });
});

describe('reading the release from the environment', () => {
  test('nothing configured means we do not know, so nothing is announced', () => {
    const release = readRelease({});
    expect(release.known).toBe(false);
    expect(release.latestVersion).toBeNull();
    expect(release.downloadUrl).toBeNull();
    expect(release.mandatory).toBe(false);
  });

  test('a configured release is reported whole', () => {
    const release = readRelease({
      APP_LATEST_VERSION: '1.2.0',
      APP_LATEST_BUILD: '2',
      APP_APK_URL: 'https://example.com/app-release.apk',
      APP_RELEASE_NOTES: 'Fixed the till total on a tab',
      APP_UPDATE_MANDATORY: 'true',
    });
    expect(release).toEqual({
      known: true,
      latestVersion: '1.2.0',
      latestBuild: 2,
      downloadUrl: 'https://example.com/app-release.apk',
      notes: 'Fixed the till total on a tab',
      mandatory: true,
    });
  });

  test('a version with no link is still announced, just without a link', () => {
    const release = readRelease({ APP_LATEST_VERSION: '1.2.0' });
    expect(release.known).toBe(true);
    expect(release.downloadUrl).toBeNull();
  });

  test('an unusable version makes the whole notice unknown', () => {
    expect(readRelease({ APP_LATEST_VERSION: 'latest' }).known).toBe(false);
  });

  test('mandatory is only true when it is literally true', () => {
    expect(readRelease({ APP_LATEST_VERSION: '1.0.0' }).mandatory).toBe(false);
    expect(
      readRelease({ APP_LATEST_VERSION: '1.0.0', APP_UPDATE_MANDATORY: 'yes' })
        .mandatory
    ).toBe(false);
    expect(
      readRelease({ APP_LATEST_VERSION: '1.0.0', APP_UPDATE_MANDATORY: 'TRUE' })
        .mandatory
    ).toBe(true);
  });

  test('a build number must be a positive whole number', () => {
    expect(normaliseBuild('2')).toBe(2);
    expect(normaliseBuild('0')).toBeNull();
    expect(normaliseBuild('2.5')).toBeNull();
    expect(normaliseBuild('two')).toBeNull();
  });

  test('notes are trimmed and capped', () => {
    expect(
      readRelease({ APP_LATEST_VERSION: '1.0.0', APP_RELEASE_NOTES: '  hi  ' })
        .notes
    ).toBe('hi');
    expect(
      readRelease({ APP_LATEST_VERSION: '1.0.0', APP_RELEASE_NOTES: '   ' }).notes
    ).toBeNull();
    const long = readRelease({
      APP_LATEST_VERSION: '1.0.0',
      APP_RELEASE_NOTES: 'x'.repeat(900),
    });
    expect(long.notes.length).toBe(500);
  });
});
