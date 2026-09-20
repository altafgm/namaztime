# Play Store readiness — permissions, cleartext, exact alarms, data safety

> **Why this file exists:** the pre-publish review flagged four items (unnecessary
> `REQUEST_INSTALL_PACKAGES`, cleartext networking enabled, exact-alarm policy
> justification, location-privacy evidence). This records what changed, why the change is
> behaviour preserving, and the text/answers to use in Play Console.

## 1. Removed permissions (behaviour preserving)

`android/app/src/main/AndroidManifest.xml`:

| Permission | Action | Evidence it was safe |
|---|---|---|
| `REQUEST_INSTALL_PACKAGES` | **removed** | No `PackageInstaller`, `installPackage`, `open_file*`, `apk`/update-download code in `lib/` or `android/app/src/main/kotlin/`, and no plugin needs it; the manifest-merger blame report shows it came only from our own manifest (`AndroidManifest.xml:11`) |
| `FOREGROUND_SERVICE` | **removed from our manifest** (extra) | our own line was redundant, not wrong: WorkManager (`androidx.work`) and geolocator (`com.baseflow.geolocator.GeolocatorLocationService`) declare it for their services, so the merged APK is unchanged and runtime behaviour is identical |
| `INTERNET`, `ACCESS_NETWORK_STATE` | kept | the platform fused location provider and reverse geocoder can use the network; removing them risks changing location behaviour |

Verify on a built APK (the permission list must not contain `REQUEST_INSTALL_PACKAGES`, and
there must be no cleartext attribute — `FOREGROUND_SERVICE` is expected, it comes from the
plugin libraries):

```bash
M=build/app/intermediates/packaged_manifests/debug/processDebugManifestForPackage/AndroidManifest.xml
grep -q 'REQUEST_INSTALL_PACKAGES' "$M" && echo "STILL DECLARED" || echo "REQUEST_INSTALL_PACKAGES: gone"
grep -o 'android:usesCleartextTraffic="[^"]*"' "$M" || echo "cleartext attribute: none"
adb shell dumpsys package com.salahtime.maniyars | sed -n '/requested permissions:/,/^$/p'
```

## 2. Cleartext networking off

`android:usesCleartextTraffic="true"` was removed from `<application>` and no
network-security-config was added, so the platform default (HTTPS only) applies.

Why nothing breaks: **the app performs no HTTP at all.**
`lib/services/aladhan_api_service.dart` is a compatibility facade over
`OfflinePrayerEngine` ("Prayer times are calculated locally; no network request is made"),
and there is no `package:http`, `dio`, `HttpClient`, `Image.network`/`NetworkImage`,
WebView or `url_launcher` usage in `lib/`:

```bash
grep -rn 'package:http\|dio\|HttpClient\|Image.network\|NetworkImage\|http://' lib/
echo "(no output above = no HTTP client in the app)"
```

## 3. Exact alarms — policy justification

Both `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` are kept: the adhan reminder has to
fire at the exact minute of the prayer, and the app degrades gracefully when the
permission is not granted.

Justification to paste into Play Console when it asks about exact alarms:

> Salah Time reminds the user of the five daily prayers at their exact times. Those times
> can be only minutes apart during parts of the year and depend on the sun's position, so
> the reminder is only useful when it fires at the scheduled minute — an inexact or
> batched alarm can arrive after the prayer window has started. The user chooses which
> prayers notify them. The app declares `USE_EXACT_ALARM` (Android 13+) and the
> user-grantable `SCHEDULE_EXACT_ALARM` for older versions. If exact alarms are not
> granted, the app does not fail: it falls back to a one-minute inexact window, so the
> reminder still arrives.

Graceful degradation lives in `PrayerUpdateWorker.scheduleNextRun()`:

```kotlin
if (Build.VERSION.SDK_INT >= 31 && !alarmManager.canScheduleExactAlarms()) {
    alarmManager.setWindow(AlarmManager.RTC_WAKEUP, nextRun.time, 60_000L, createAlarmPendingIntent())
    return
}
alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextRun.time, createAlarmPendingIntent())
```

Demonstrate it in a review build: turn exact alarms off for the app
(Settings → Apps → Special access → Alarms & reminders, or
`adb shell cmd appops set com.salahtime.maniyars SCHEDULE_EXACT_ALARM deny`), then confirm
the app keeps working and scheduling (logcat: `PrayerUpdateWorker`) and that no UI blocks.

## 4. Location privacy evidence

What the code does: coordinates come from the device (`geolocator`) and are used on-device
by `OfflinePrayerEngine`; they are persisted only in the app's private preferences
(`bg_lat`/`bg_lng`/`bg_city`/`bg_country`) for the background worker and the widget.
**No coordinates or prayer data leave the device from the app** — there is no backend and
no third-party SDK. The only off-device step is the *platform* reverse geocoder
(`geocoding` → `android.location.Geocoder`), which is a system service.

Publishable policy: `PRIVACY.md` in the repository root (host it anywhere). Simplest route
to the public URL Play requires — GitHub Pages:

```bash
git add PRIVACY.md && git commit -m "Add privacy policy"
# GitHub → Settings → Pages → Deploy from branch → main /(root)
# URL: https://<user>.github.io/<repo>/PRIVACY.md
```

Then set **Play Console → App content → Privacy policy** to that URL.

### Data safety form answers

| Question | Answer | Reason |
|---|---|---|
| Does your app collect or share any required user data type? | **No** | nothing is transmitted off the device by the app; location, schedule and settings stay in app-private storage (Play counts on-device-only processing as *not collected*) |
| Approximate / precise location | *not collected, not shared* | processed on device only; the policy notes that the OS geocoder resolves the city name |
| Personal, financial, messages, photos, files, contacts, health, calendar | *not collected, not shared* | not requested or used |
| App activity, app info & performance, device or other IDs | *not collected, not shared* | no analytics/ad SDKs in `pubspec.yaml` (geolocator, geocoding, provider, intl, timezone, hijri, hive, flutter_local_notifications, flutter_timezone, shared_preferences) |
| Is all user data encrypted in transit? | *n/a — nothing is transmitted* | |
| Data deletion request path? | *n/a — no account; all data is on device and uninstalling removes it* | |

Also fill **Play Console → App content → Location**: state that location is used for the
app's core functionality (prayer-time calculation), is optional (the app falls back to the
last known or default city), and is not shared.

## Re-verification steps

```bash
flutter build apk --debug
grep -o 'uses-permission android:name="[^"]*"' \
  build/app/intermediates/packaged_manifests/debug/processDebugManifestForPackage/AndroidManifest.xml | sort -u
grep -c usesCleartextTraffic \
  build/app/intermediates/packaged_manifests/debug/processDebugManifestForPackage/AndroidManifest.xml   # expect 0
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb logcat -d -s PrayerUpdateWorker:* PrayerWidgetProvider:*   # smoke test after first run
```
