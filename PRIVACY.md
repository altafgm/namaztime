# Salah Time — Privacy Policy

_Last updated: 20 September 2026_

Salah Time ("the app") is an offline prayer-times app for Android. It has no user
accounts, no advertising and no analytics, and it never sends your data to us or to
any service we operate or control.

## What the app uses

- **Approximate / precise location (optional).** Used on the device to calculate prayer
  times and the direction of the Qibla for your area. The coordinates are stored only in
  the app's private storage. The app has no server component, so it never uploads your
  location. If the app cannot obtain a fresh fix it keeps using the last location it
  resolved, or the built-in default city.
- **Reverse geocoding (device feature).** To show a city name for the coordinates, the
  app calls the geocoding service built into your device
  (`android.location.Geocoder`). Depending on your device, that **system** service may
  send the coordinates to the platform vendor's geocoding provider. It is a feature of
  the operating system, not a request made by the app, and the app itself transmits
  nothing.
- **Notifications.** If you enable them, the app creates local notifications at the
  prayer times. They are generated and shown on the device.
- **Local storage.** Your settings, the calculated schedule and the home-screen widget
  data are stored in the app's private storage (SharedPreferences / Hive). Nothing is
  kept outside the app, and uninstalling the app removes it.

## What the app does not do

- No account, sign-in or personal identifiers.
- No analytics, advertising, tracking or crash-reporting SDKs.
- No transmission of your location, prayer times, settings or usage — prayer times are
  computed on the device by an offline calculation engine.
- No selling or sharing of data with third parties.

## Permissions and why they are needed

| Permission | Why it is requested |
|---|---|
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | calculate prayer times for your position (optional: the app falls back to the last known, or the default, city) |
| `POST_NOTIFICATIONS` | show the prayer-time notifications you enable |
| `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` | start each prayer notification at its exact minute; if denied the app still works with a 1 minute window |
| `RECEIVE_BOOT_COMPLETED` | re-arm those notifications after a restart |
| `INTERNET`, `ACCESS_NETWORK_STATE` | available to the platform location and geocoding services only; the app itself sends nothing |

## Children

The app collects no personal data and is suitable for all audiences.

## Changes

If this policy changes, the updated version will be published at this same URL.

## Contact

Email: [madotest007@gmail.com](mailto:madotest007@gmail.com)
