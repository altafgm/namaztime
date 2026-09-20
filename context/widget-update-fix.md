# Widget Update + Notifications Fix — Context Notes

> **When/why this matters:** The Android home-screen widget was not updating to the
> correct current/next prayer after a device reboot or after the app was removed
> from background (swiped away), even though notifications kept firing. This doc
> records the architecture, root causes, fixes, and the exact on-device validation
> procedure so future fixes can reuse it.

## App / environment facts

- Package: `com.salahtime.maniyars` (project root `/home/altaf/Documents/App/namaztime`).
- Stack: Flutter 3.47.2, Kotlin 2.2.20, AGP 8.11.1, Gradle 8.14.0, Java 17,
  `minSdk = flutter.minSdkVersion`, `isCoreLibraryDesugaringEnabled = true`
  (`desugar_jdk_libs:2.0.4`) => `java.time` works in app code; deps for it were added to build.gradle.
- Notifications are posted natively by `PrayerUpdateWorker` (not from Flutter).
  Flutter-side `schedulePrayerNotifications` exists but is never called.
- Widget is a RemoteViews (`PrayerWidgetProvider`) that renders straight from
  SharedPreferences `FlutterSharedPreferences.xml` (no Flutter engine needed).

## SharedPreferences keys (read by widget / written by worker & receivers)

File: `shared_prefs/FlutterSharedPreferences.xml` (in app data dir).

- `flutter.bg_lat` / `flutter.bg_lng` — persisted location for native fetches.
- `flutter.widget_schedule` — JSON:
  `{"today":"dd-MM-yyyy","todayTimes":{Fajr,Dhuhr,Asr,Maghrib,Isha},"tomorrow":"dd-MM-yyyy","tomorrowTimes":{...}}`
  where prayer values are `HH:mm` (24h).
- `flutter.widget_last_prayer_name` / `flutter.widget_last_prayer_time` — "last" prayer
  (displayed time formatted like `4:39 PM`; recompute uses `DateTimeFormat.mediumTime`-style locale).
- `flutter.widget_next_prayer_name` / `flutter.widget_next_prayer_time` — next prayer.
- `flutter.widget_last_notified_prayer` — dedup key: `"PrayerName|dd-MM-yyyy"`; prevents
  re-notifying the same prayer the same day.

**Gotcha:** the Flutter `shared_preferences` plugin stores Dart `double` values with a
double-prefix, so native keys for those look like `flutter.flutter.bg_lat` /
`flutter.flutter.widget_*`. The `flutter.flutter.*` entries seen in the prefs file are
legacy/harmless. Native code must read `flutter.bg_*` (single prefix).

## Intent / alarm chain

- Exact RTC alarm action `com.salahtime.maniyars.PRAYER_UPDATE_ALARM` -> `PrayerUpdateReceiver`
  (exported=false) -> enqueues unique WorkManager worker `prayer_update_worker`
  (`PrayerUpdateWorker`), which on success schedules the NEXT alarm.
- Android broadcasts handled by `BootReceiver` (see intent filters below).

## Root causes (as fixed)

1. Widget only refreshed on `onUpdate` (add/resize) or when the worker already ran —
   no recompute at boot / app-update / time-change -> stale widget after reboot.
2. `bg_lat`/`bg_lng` were only persisted when GPS succeeded; the common fallback
   (default Istanbul coords used for the fetch) was never saved, so the native worker
   had no persistent location.
3. Fragile alarm chain: bare `Result.retry()` on failures could let WorkManager abandon
   the work after repeated failures and never schedule the next prayer alarm; also
   `MY_PACKAGE_REPLACED` (app update) / `TIME_SET` / `TIMEZONE_CHANGED` were not handled.

## What was changed

- `android/app/src/main/kotlin/com/salahtime/maniyars/PrayerScheduleData.kt` (NEW):
  - `computeOffline(scheduleDate, todayTimes, tomorrowDate, tomorrowTimes, nowDate, nowTime)`
    — pure function returning `OfflineResult(last, next, lastTime, nextTime)`:
    before Fajr -> none/Fajr; during a prayer window -> that/next; after Isha ->
    (Isha, tomorrow Fajr); falls back to stored "tomorrow" when it matches today's date.
  - `save(context, ...)` persists today+tomorrow JSON; `recomputeFromStoredSchedule(context, prefs)`
    recomputes last/next from device clock + stored schedule and writes the prefs.
- `PrayerScheduleData.kt` unit tests: `android/app/src/test/kotlin/com/salahtime/maniyars/PrayerScheduleDataTest.kt`
  (8 cases: before Fajr, mid-day, exact prayer time, after Isha -> tomorrow Fajr,
  reboot-into-new-day, stale schedule, no tomorrow, missing prayer). All pass.
- `PrayerWidgetProvider.kt`: `onUpdate` calls `recomputeFromStoredSchedule`; added
  `refreshAll(context)` = recompute + redraw every widget id (used by receivers).
- `PrayerUpdateWorker.kt` (rewritten):
  - Always refreshes widget from stored schedule FIRST (offline) so the widget is
    correct even if network fails.
  - Always fetches tomorrow's times and persists `widget_schedule`.
  - On failure: keeps a 1-hour fallback alarm self-healing loop and returns
    `Result.success()` (does NOT burn retries / abandon the chain).
  - Notification + `last_notified_prayer` dedup; runs next alarm scheduling including
    "after Isha -> tomorrow Fajr".
- `BootReceiver.kt`:
  - Refreshes the widget immediately on ANY incoming event.
  - Enqueues the worker for `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED` / `TIME_SET` /
    `TIMEZONE_CHANGED`; for `LOCKED_BOOT_COMPLETED` only refreshes the widget.
  - WorkManager enqueue wrapped in try/catch.
- `WidgetUpdateReceiver.kt`: now calls `PrayerWidgetProvider.refreshAll(context)`.
- `android/app/src/main/AndroidManifest.xml`: added `MY_PACKAGE_REPLACED`, `TIME_SET`,
  `TIMEZONE_CHANGED` to the BootReceiver intent filter.
- `lib/screens/home_screen.dart`: `_persistBgLocation(lat, lng, [syncedAt])` persists the
  fallback Istanbul location (41.0082, 28.9784) on permission-denied, GPS-fail, and
  timeout paths, not just on GPS success.
- `android/app/build.gradle.kts`: `testImplementation("junit:junit:4.13.2")`.
- `test/widget_test.dart`: fixed (was failing pre-existing
  `ProviderNotFoundException`); now wraps `MyApp` in `SettingsProvider` + `PrayerProvider`
  over `SharedPreferences.setMockInitialValues({})`.

## Build/test commands

```
cd android && ./gradlew :app:testDebugUnitTest   # Kotlin unit tests (8/8)
flutter test                                      # 4/4 pass
flutter analyze                                   # 2 pre-existing infos + 2 unawaited warnings
flutter build apk --debug; adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## On-device E2E method (API 36 emulator, package pre-installed, `adb root` available)

Setup once:
```
adb root                                    # REQUIRED for settings put / manual date / editing prefs
adb shell settings put global auto_time 0
adb shell settings put global auto_time_zone 0
adb shell date 090819312026.00              # format MMDDhhmm[[CC]YY][.ss]  -> Sep 8 19:31 2026
```

Simulate "removed from background": `adb shell am kill com.salahtime.maniyars`
(verify with `adb shell pidof com.salahtime.maniyars` -> empty).
**Do NOT use `am force-stop`** — force-stop cancels alarms/pending broadcasts by Android
design, so no app can update its widget in that state until reopened (OS behavior, not fixable).

Read the widget: `uiautomator dump` is unreliable on API 36 -> use
`adb shell uiautomator dump /sdcard/w.xml && adb shell cat /sdcard/w.xml | grep -oE 'text="[^"]+"'`
and find the "Salah Time" card. (Screenshots can't be read in this environment — text only.)
`cmd appwidget` shell command is NOT available on API 36.

Read prefs/notifications:
```
adb shell run-as com.salahtime.maniyars cat shared_prefs/FlutterSharedPreferences.xml | grep ...
adb shell dumpsys notification --noredact | grep "pkg=com.salahtime.maniyars" | grep -oE "id=[0-9]+"
adb logcat -d | grep -E "posted event.*salahtime"      # NotificationListener posts
```

### Validation matrix that passed (app process killed before every step, never opened)

| Device time (app dead) | Widget shown | Notification (`last_notified_prayer`) |
|---|---|---|
| Sep 8 19:00 (after reboot) | Asr 4:39 PM \| Maghrib 7:25 PM | — |
| Sep 8 19:31 (past Maghrib) | Maghrib 7:25 PM \| Isha 8:55 PM | `Maghrib\|08-09-2026` |
| Sep 8 21:00 (past Isha) | Isha 8:55 PM \| Fajr 5:03 AM (cross-midnight) | `Isha\|08-09-2026` |
| Sep 9 06:00 (next day, past Fajr) | Fajr 5:03 AM \| Dhuhr 1:01 PM (day rollover + refetch) | `Fajr\|09-09-2026` |
| Sep 9 17:00 (past Asr) | Asr 4:38 PM \| Maghrib 7:24 PM | `Asr\|09-09-2026` |

Reboot path was ALSO proven independently: corrupt the four widget prefs to junk as root
(only while app process is dead), `adb reboot`, wait, then confirm without opening the app
the widget recovers correct last/next from device clock + stored schedule.

Notification ids in dumpsys are the `notificationIdFor(prayer)` values (e.g. Fajr=101,
Maghrib=104, Isha=105); when a new prayer's notification posts the previous one is removed.

## 7-day idle scenario (phone idle, app killed)

**Answer: yes, the widget and notifications keep updating indefinitely without relaunch.**

The native chain (`PrayerUpdateWorker`) uses `setExactAndAllowWhileIdle` + `RTC_WAKEUP`
alarms which survive Doze and survive app process kill (`am kill`). Each run:

1. Recomputes widget offline from stored schedule + device clock.
2. Fetches tomorrow's times and persists `widget_schedule` (today+tomorrow).
3. Posts notification if the prayer hasn't been notified yet.
4. Schedules the next alarm at the exact next prayer wall-clock time.

After Isha (last prayer today), the worker schedules tomorrow's Fajr alarm — the
schedule rolls forward day after day indefinitely. On reboot, `BootReceiver` re-enqueues
the worker. The only thing that breaks the chain is `am force-stop` (by Android design)
which cancels all pending intents and alarms; the app must be opened once to restart.
This is unfixable OS behaviour, not a bug in the app.

The legacy Dart-side 7-day `BackgroundService.executeTask` is now skipped entirely on
Android (`main.dart` gates on `Platform.isAndroid`), since the native worker already
owns widget updates + notifications and the Dart version was redundant duplicate work
running on the UI isolate.

## Performance optimizations

### What was slow and why

- **GPS blocking on startup** — `_resolveLocation()` with 8s GPS fix + 5s geocode
  blocked the first prayer load. Home page was blank for up to 13–15s on cold start.
- **Sequential fetch + 750ms sleep** — `getPrayerTimesForDates` fetched N dates one at
  a time with an artificial 750ms sleep between each. For the 2-date home load:
  +750ms wasted; for the 7-day background window: 4.5s pure sleeping.
- **NotificationService.init()** blocked first frame — called synchronously before
  `loadPrayerSchedule`, which only requests POST_NOTIFICATIONS permission (not needed
  for painting).
- **BackgroundService.refreshIfStale** ran 8 sequential HTTP calls (7-day window) on
  the main UI isolate on every app open/resume if >1h stale — duplicate of native worker.

### What was changed (second round)

- **`lib/services/aladhan_api_service.dart`**:
  - Removed `_requestDelayMs` (750ms sleep). Multi-date fetch now uses `Future.wait`
    in batches of `_maxConcurrentRequests` (3). Two dates (home) = one batch, no delay.
- **`lib/providers/prayer_provider.dart`**:
  - `loadPrayerSchedule` now fetches today first (awaited, renders cards), then
    tomorrow in the background (not awaited before painting). `notifyListeners()`
    fires as soon as today is ready, showing the cards; `_isLoading` stays true so
    a thin `LinearProgressIndicator` shows while tomorrow loads. `_notificationService
    .init()` is now `unawaited` (only requests permission).
- **`lib/screens/home_screen.dart`**:
  - `_startup` split into two phases: `_startupWithPinnedLocation` (reads persisted
    `bg_lat`/`bg_lng` from prefs or uses Istanbul default; loads cached schedule
    instantly, no GPS, no network) then `_startupWithLiveLocation` (GPS + geocode in
    background; only reloads if location materially differs >0.01°). First paint is
    near-instant (<100ms cache read or one network call). Cold start: **~1.5s** total
    (`am start -W` WaitTime).
- **`lib/main.dart`**:
  - `NotificationService.init()` + `BackgroundService.register()` no longer block
    `runApp()` (moved to post-frame `unawaited`).
  - `BackgroundService.refreshIfStale()` calls are skipped when `Platform.isAndroid`
    (native worker owns widget + notifications; Dart version is legacy duplicate).
- **`lib/services/background_service.dart`**:
  - Removed the redundant separate `_fetchMaghribTime` pre-call (one HTTP request
    saved). Window start derived inline.
  - `_fetchWindowDates` / `_fetchMaghribTime` removed (dead code).
  - Day fetches parallelized in batches of `_maxConcurrentRequests` (3); removed
    `_requestDelayMs` sleeps.

### Validation (post-optimization)

Cold start (force-stop → am start -W): **WaitTime 1519ms** (down from >15s GPS-blocked).

E2E on API-36 emulator (GPS-resolved to Ukiah, US — real location, app killed between steps):

| Device time (app dead) | Widget shown | Notification (`last_notified_prayer`) |
|---|---|---|
| Sep 8 21:00 (past Isha) | Isha 8:58 PM \| Fajr 5:17 AM (cross-midnight) | `Isha\|08-09-2026` |
| Sep 9 06:00 (next day, past Fajr) | Fajr 5:17 AM \| Dhuhr 1:10 PM (day rollover + refetch) | `Fajr\|09-09-2026` |

Schedule blob confirmed rolling: `today=09-09-2026, tomorrow=10-09-2026`. Widget times
matched schedule exactly (Fajr 05:17 → 5:17 AM, Dhuhr 13:10 → 1:10 PM).

1. **After `adb reboot`, `adb root` is lost** — re-run `adb root` or you'll get
   `date: cannot set date: Operation not permitted` and `settings put` will fail.
2. The **emulator resets the clock to host time on reboot** (manual `date` does not
   persist across reboot) — always re-read `adb shell date` after boot and re-set.
3. `auto_time`/`auto_time_zone` must be 0 before `adb shell date`; restore to 1 when done.
4. Editing the prefs XML as root is safe only when the app process is dead
   (`pidof` empty); a live process overwrites your edits from its in-memory cache.
5. The Aladhan API returns slightly different times per call for the same day — compare
   widget times against the CURRENT `widget_schedule` blob, not an earlier read.
6. Device is IST(+5:30) with Istanbul(+3) fallback coords — that timezone mismatch is
   pre-existing app behavior; the widget uses the app's own schedule, not raw API times.
7. Steps map to: BootReceiver (boot/now) -> refreshAll offline; Worker (alarm) ->
   offline refresh + fetch tomorrow + notify + schedule next alarm. If widget is stale,

## Follow-up (2026-09-20) — AM/PM drawn at the full time size after an app-triggered refresh

**Symptom (user report):** tapping the GPS/localise icon re-fetches the schedule and
refreshes the widget; after that refresh the widget's AM/PM looked much bigger than the
small suffix drawn after a native refresh, while the *sizing math* was identical.

**Root cause — a separator mismatch, not sizing.** `WidgetSizing` produced
`scale=1.0, timeSp=20, periodSp=8` on every path (logcat), so the layout was right and the
stored *text* was wrong. Two writers store `flutter.widget_last_prayer_time`:

- Flutter `WidgetService._formatTime` → `DateFormat.jm()`, which on current CLDR/ICU uses a
  **U+202F narrow no-break space** (`7:22\u202FPM`; hexdump of the prefs file:
  `37 3a 32 32 e2 80 af 50 4d`).
- Kotlin `PrayerScheduleData.recomputeFromStoredSchedule` → `DateFormat.getTimeFormat`
  → a plain `U+0020` space.

`PrayerWidgetProvider.updateWidget` split the marker with `raw.endsWith(" PM")`, so the
U+202F value never matched: the suffix stayed `""` and the whole string was set on the
**20sp** time view while the AM/PM view stayed empty. Measured on the emulator (density
2.625): digits+AM/PM band **194px** (bug) vs **135px** (correct).

**Fix**
- `WidgetTimeText.kt` (new, pure Kotlin so it stays JVM-testable): `split(localeTime)`
  splits on any Unicode space (`isWhitespace` + `Character.isSpaceChar` → U+0020/U+00A0/
  U+2007/U+202F) and accepts any trailing non-digit token of ≤5 chars as the marker, so
  `PM`, `pm`, `p.m.`, `μ.μ.`, `下午` all work and 24h times/placeholders are left untouched.
- `PrayerWidgetProvider.updateWidget` uses `WidgetTimeText.split(raw)` (the per-locale
  `endsWith` list is gone); its temporary `Log.d` was removed.
- `lib/services/widget_service.dart` normalises U+202F/U+00A0 to a plain space so both
  writers store the same value.
- Tests: `WidgetTimeTextTest.kt` (10 cases) — `./gradlew :app:testDebugUnitTest`.

**Verified** (two 4x1 widgets + one pinned 2x1): after re-launching the app *and* after
tapping the GPS icon, all six columns render the time band at exactly 135px, i.e. digits
20sp + AM/PM 8sp, the same as the native-recomputed baseline. Stored value is now
`7:22 PM` with an ASCII space.

## Follow-up (2026-09-20) — a failed GPS fix silently moved the user to the default city

**Symptom:** tapping the GPS icon when no *fresh* fix is available (indoors, emulator,
stale last location) recalculated the whole schedule for Istanbul and persisted those
coordinates, so app, widget and notifications all switched city (and time).

**Root cause:** every failure branch of `HomeScreen._resolveLocation()` returned
`_defaultLocation` (41.0082, 28.9784 / Istanbul) *and* persisted it via
`_persistBgLocation`, overwriting the previously resolved coordinates that the fast
startup path and the Dart/native background workers read (`bg_lat`/`bg_lng`).

**Fix (`lib/screens/home_screen.dart`)**
- `_storedLocation()` returns the last resolved location plus its city/country (or null).
- `_fallbackLocation(reason)` keeps the stored location and only seeds the default on a
  fresh install; the status text distinguishes "Using last known location." from
  "Using default location.".
- Timeout, permission-denied and GPS-unavailable branches (plus the
  `_startupWithLiveLocation` catch) use it; `_startupWithPinnedLocation` uses the stored
  city instead of a hard-coded "Istanbul, Turkey".
- `_persistBgLocation` takes a `LocationData` and stores `bg_city`/`bg_country` next to
  `bg_lat`/`bg_lng`/`last_synced_at`, and only on a successful fix.

**Verified:** with `bg_lat=20.5936833 / bg_city=Wadgaon` stored and location services off
(`settings put secure location_mode 0`), the app shows "GPS unavailable. Using last known
location." with unchanged Wadgaon times and the stored coordinates untouched (before the
fix they became 41.0082 / Istanbul).

   check `logcat` for `WM-WorkerWrapper` (worker) and `AppWidgetServiceImpl` (push).