#!/usr/bin/env python3
"""Pick the next TestFlight build number by asking App Store Connect.

Writes `build_number=<N>` to GITHUB_OUTPUT, where N is one more than the
highest build number ever uploaded for the app. Falls back to epoch
seconds if App Store Connect can't be reached, which is still strictly
increasing.

Environment:
  ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8   App Store Connect API key
  BUNDLE_ID                                 app bundle id
"""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

ASC_BASE = "https://api.appstoreconnect.apple.com"


def asc_token():
    now = int(time.time())
    return jwt.encode(
        {
            "iss": os.environ["ASC_ISSUER_ID"],
            "iat": now - 30,
            "exp": now + 600,
            "aud": "appstoreconnect-v1",
        },
        os.environ["ASC_KEY_P8"],
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def get(url, token):
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(request) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"{}")


def highest_build_number(token, app_id):
    url = f"{ASC_BASE}/v1/builds?" + urllib.parse.urlencode(
        {"filter[app]": app_id, "fields[builds]": "version", "limit": 200}
    )
    highest = 0
    while url:
        status, data = get(url, token)
        if status != 200:
            raise RuntimeError(f"builds query returned HTTP {status}")
        for build in data.get("data", []):
            version = build.get("attributes", {}).get("version", "")
            if version.isdigit():
                highest = max(highest, int(version))
        url = (data.get("links") or {}).get("next")
    return highest


def emit(build_number, source):
    print(f"build number {build_number} ({source})")
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a") as f:
            f.write(f"build_number={build_number}\n")


def main():
    bundle_id = os.environ["BUNDLE_ID"]
    try:
        token = asc_token()
        status, apps = get(
            f"{ASC_BASE}/v1/apps?" + urllib.parse.urlencode({"filter[bundleId]": bundle_id, "fields[apps]": "bundleId"}),
            token,
        )
        if status != 200 or not apps.get("data"):
            raise RuntimeError(f"no app for {bundle_id} (HTTP {status})")
        highest = highest_build_number(token, apps["data"][0]["id"])
        emit(highest + 1, f"highest existing build is {highest}")
    except Exception as error:  # noqa: BLE001
        print(f"::warning::Could not read build numbers from App Store Connect ({error}); using a timestamp.")
        emit(int(time.time()), "timestamp fallback")
    return 0


if __name__ == "__main__":
    sys.exit(main())
