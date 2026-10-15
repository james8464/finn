#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /path/to/Finn.xcarchive" >&2
    exit 2
fi

binary="$1/Products/Applications/Finn.app/Finn"
if [ ! -f "$binary" ]; then
    echo "Missing Finn binary in archive: $1" >&2
    exit 2
fi

if ! command -v rg >/dev/null 2>&1; then
    echo "ripgrep is required to inspect the archive" >&2
    exit 2
fi

manifest="$1/Products/Applications/Finn.app/PrivacyInfo.xcprivacy"
if [ ! -f "$manifest" ]; then
    echo "Missing PrivacyInfo.xcprivacy in the app: App Store Connect rejects the upload (ITMS-91053)" >&2
    exit 1
fi

app="$1/Products/Applications/Finn.app"
# save workouts to Apple Fitness: HealthKit crashes the app on a permission request without the
# purpose string, and refuses every call without the entitlement
if ! rg -q -a 'NSHealthUpdateUsageDescription' "$app/Info.plist"; then
    echo "Info.plist lacks NSHealthUpdateUsageDescription: asking Health for permission would crash" >&2
    exit 1
fi
if codesign -d "$app" >/dev/null 2>&1; then
    entitlements=$(codesign -d --entitlements - --xml "$app" 2>/dev/null || codesign -d --entitlements :- "$app" 2>/dev/null || true)
    if ! printf '%s\n' "$entitlements" | rg -q 'com\.apple\.developer\.healthkit'; then
        echo "The signed app lacks the HealthKit entitlement (com.apple.developer.healthkit)" >&2
        exit 1
    fi
    if printf '%s\n' "$entitlements" | rg -q 'health-records'; then
        echo "The signed app asks for Clinical Health Records, which Finn does not use" >&2
        exit 1
    fi
    healthkit="has the HealthKit entitlement"
else
    healthkit="is not code signed (HealthKit entitlement not checked)"
fi

contents=$(strings -a "$binary")
if matches=$(printf '%s\n' "$contents" | rg 'DemoPoseSource|DemoRecapGenerator|DemoExerciseClassifier|SyntheticExerciseMotion|DEMO INPUT|-finn-ui-demo|-finn-validation|validation\.stopToResult|VideoFilePoseSource|VIDEO FILE INPUT|-finn-video-file|-finn-video-poses|-finn-ui-hands-free'); then
    echo "Release archive contains test-only demo or validation code:" >&2
    echo "$matches" >&2
    exit 1
else
    status=$?
    if [ "$status" -ne 1 ]; then
        echo "Could not inspect the archive" >&2
        exit 2
    fi
fi

echo "Release archive: privacy manifest and Health purpose string present; the app $healthkit; test-only demo and validation code excluded."
