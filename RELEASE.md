# Releasing the app: a signed APK, and telling the shops about it

`DEPLOY.md` ships the **backend**. This file ships the **app** — which is handed out as a
direct APK download, with no store to sign it, publish it or announce it.

The app asks `GET /api/app/release` what the newest build is (see `utils/appRelease.js` and
`lib/widgets/update_notice_host.dart`); this file is how that answer gets set, and how the
file it points at gets built and signed.

---

## The one rule that cannot be undone

**Android accepts an update only when it is signed by the SAME key as the installed app.**
Lose the key and no shop can ever upgrade again — every one of them has to uninstall, losing
whatever lived only on that phone, and reinstall. So: create the key once, back it up in a
password manager *and* offline, and never let it near git.

Every build shipped **before 10 November 2026** was signed with the **debug** key
(`build.gradle.kts` fell back to it). Two consequences:

- The first properly signed release **cannot install over** those. Those shops must remove the
  app first. That is why `download.html` leads with that note, and why it is worth shipping
  that first signed build with `APP_UPDATE_MANDATORY=true` and release notes that say so.
- What they lose is only what is on the phone: the saved session (they sign in again) and any
  sale not yet synchronised. The shop's account and data stay on the server.

---

## One-time: create the release key

```powershell
cd android
keytool -genkey -v -keystore drinkquick-release.jks -keyalg RSA -keysize 2048 `
        -validity 10000 -alias drinkquick
```

Then move `drinkquick-release.jks` **out of the repo** (e.g. `C:\keys\`) and copy
`android\key.properties.example` to `android\key.properties`, filling in the passwords and the
`storeFile` path (forward slashes; a properties file treats `\` as an escape).

Both files are excluded by `android/.gitignore` **and** the root `.gitignore`. Prove it:

```powershell
git check-ignore -v android/key.properties     # must print a matching rule
git ls-files "*.jks" "*.keystore"              # must print nothing
```

---

## Every release

1. **Bump the version** — `pubspec.yaml` `version: 1.2.0+2` **and** the matching
   `AppConstants.appVersion` / `appBuild` (`lib/utils/constants.dart`). `test/app_info_test.dart`
   fails if the two drift, and rejects a second copy of the version anywhere else in `lib/`.
2. **Run the gates**: `flutter test`, `flutter analyze lib` (0 errors), i18n parity (`EN` must
   equal `FR`).
3. **Build it**:
   ```powershell
   flutter build apk --release
   # → build\app\outputs\flutter-apk\app-release.apk   (~82 MB, ~8 min cold, ~2 min warm)
   ```
   Without `android/key.properties` this build **fails** rather than quietly signing with the
   debug key: such an APK could never be upgraded by a properly signed one, and `flutter build
   apk` does not print Gradle warnings — it prints a failure. For a throwaway test build use
   `flutter build apk --debug`, or ask for the debug key explicitly with
   `cd android; .\gradlew assembleRelease -PallowDebugSigning=true`. Never publish either.
4. **Check the signature you just made**:
   ```powershell
   & "$env:LOCALAPPDATA\Android\sdk\build-tools\<version>\apksigner.bat" verify --print-certs `
     build\app\outputs\flutter-apk\app-release.apk
   # → Signer #1 certificate DN: CN=<your key>, ...   (NOT CN=Android Debug)
   ```
5. **Hash it** — this is the number a shop can check:
   ```powershell
   Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
   ```
6. **Publish the file** where `APP_APK_URL` can point (a GitHub Release asset is the simplest
   and serves the bytes directly), then set the environment on Render and deploy:

   | Variable | Value |
   |---|---|
   | `APP_LATEST_VERSION` | `1.2.0` — **without** it nothing is announced at all |
   | `APP_LATEST_BUILD` | `2` (must match `appBuild`; a rebuild with the same version is still news) |
   | `APP_APK_URL` | the published `https://…/app-release.apk` |
   | `APP_APK_SHA256` | the 64-character digest from step 5 |
   | `APP_RELEASE_NOTES` | one plain sentence for the shop (max 500 characters) |
   | `APP_UPDATE_MANDATORY` | `true` only when they truly must update — "Later" still works |

The shop sees the notice a few seconds after the next app launch (or when the app is brought
back to the foreground). The page `https://<host>/download.html` shows the same version, notes
and hash, and a human-readable install guide in English and French.

---

## Traps worth knowing

- **A push does not deploy.** The backend change reaches Render only through a **manual**
  deploy, so the new env values take effect then — `GET /health`'s `RELEASE` marker is the
  proof, and a short poll proves nothing (one deploy here took 21m46s).
- **The app never downloads the APK itself.** It shows a dialog; the phone's browser does the
  rest. A shop with no browser-side connection simply updates later.
- **`APP_UPDATE_MANDATORY` is not a lock.** It only makes the dialog reappear after "Later" —
  deliberately, because a till must keep selling on an old build.
- **`APP_APK_URL` is one link for every shop.** Check it before deploying: a typo sends all of
  them to the wrong file. Publishing the SHA-256 is what makes that detectable.
