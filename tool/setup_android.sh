#!/usr/bin/env bash
# Generates the android/ folder (if missing) and applies the app's settings.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ]; then
  flutter create --platforms=android --org pk.bijlimeter --project-name bijli_meter .
fi

# flutter create adds a sample test that does not match this app.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm test/widget_test.dart
fi

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i '0,/<application/s//<uses-permission android:name="android.permission.INTERNET"\/>\n    <application/' "$MANIFEST"
fi
sed -i 's/android:label="bijli_meter"/android:label="Bijli Meter"/' "$MANIFEST"

# ML Kit references optional language packs (Chinese, Japanese, ...) that the
# app does not bundle; tell R8 not to fail on them.
cat > android/app/proguard-rules.pro <<'EOF'
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
EOF

# Android lint crashes on some plugin sources during release builds; skip it.
for GRADLE in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$GRADLE" ] && ! grep -q 'checkReleaseBuilds' "$GRADLE"; then
    printf '\nandroid {\n    lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }\n}\n' >> "$GRADLE"
  fi
done

echo "Android project ready."
