# Bijli Meter ⚡

Android app (Flutter) to track electricity units for Pakistani WAPDA companies
(LESCO, MEPCO, IESCO, GEPCO, FESCO, PESCO, HESCO, SEPCO, QESCO, TESCO).

## Features

- Multiple meters per home, each with its own 14-digit reference number and history
- Last reading, reading date and 12-month history loaded automatically from the
  PITC bill portal (`bill.pitc.com.pk/<company>bill/general?refno=...`)
- Company detected from the reference number (falls back to trying every company)
- Take a photo of the meter → digits read on-device with Google ML Kit
- Units used so far, daily average, forecast until the next reading date,
  and a warning before the 200-unit slab
- All data stays on the phone

## Download

Every push to `main` builds an APK and publishes it under **Releases**.
Open the latest release, download `app-release.apk`, and install it on Android
(allow "Install unknown apps" when asked).

## Develop locally

```bash
bash tool/setup_android.sh   # creates android/ the first time
flutter pub get
flutter run
```

## Project layout

```
lib/
  main.dart                 app entry
  theme.dart                colors and fonts
  models/meter.dart         meter, readings, forecast math
  services/bill_service.dart  PITC bill fetch + HTML parsing
  services/ocr_service.dart   ML Kit digit reading
  services/meter_store.dart   local storage
  screens/                  home, add meter, meter detail, scan
  widgets/common.dart       cards, chips, slab bar, history chart
```
