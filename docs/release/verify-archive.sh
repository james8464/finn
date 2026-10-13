#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /path/to/Plumb.xcarchive" >&2
    exit 2
fi

binary="$1/Products/Applications/Plumb.app/Plumb"
if [ ! -f "$binary" ]; then
    echo "Missing Plumb binary in archive: $1" >&2
    exit 2
fi

if ! command -v rg >/dev/null 2>&1; then
    echo "ripgrep is required to inspect the archive" >&2
    exit 2
fi

manifest="$1/Products/Applications/Plumb.app/PrivacyInfo.xcprivacy"
if [ ! -f "$manifest" ]; then
    echo "Missing PrivacyInfo.xcprivacy in the app: App Store Connect rejects the upload (ITMS-91053)" >&2
    exit 1
fi

contents=$(strings -a "$binary")
if matches=$(printf '%s\n' "$contents" | rg 'DemoPoseSource|DemoRecapGenerator|DemoExerciseClassifier|SyntheticExerciseMotion|DEMO INPUT|-plumb-ui-demo|-plumb-validation|validation\.stopToResult|VideoFilePoseSource|VIDEO FILE INPUT|-plumb-video-file|-plumb-video-poses|-plumb-ui-hands-free'); then
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

echo "Release archive has its privacy manifest and excludes test-only demo and validation code."
