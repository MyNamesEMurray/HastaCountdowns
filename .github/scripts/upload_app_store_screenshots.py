#!/usr/bin/env python3
"""Upload composed screenshots to the editable App Store version.

Expects a folder with one subfolder per App Store locale (en-US, es-MX,
ja, ...), each holding that locale's PNGs in upload order. For every
locale on the version that has a folder, the screenshots in the chosen
display type's set are replaced, then each upload is checked until App
Store Connect finishes processing it.

Usage: upload_app_store_screenshots.py <folder>

Environment:
  ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8   App Store Connect API key
  BUNDLE_ID                                 app bundle id
  DISPLAY_TYPE                              default APP_IPHONE_67 (6.9")
"""

import glob
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

ASC_BASE = "https://api.appstoreconnect.apple.com"
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now - 30, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        os.environ["ASC_KEY_P8"],
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


TOKEN = None


def api(method, path, body=None):
    url = path if path.startswith("http") else ASC_BASE + path
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        raise RuntimeError(f"{method} {url} returned HTTP {error.code}: {detail}") from None


def editable_version(app_id):
    versions = api("GET", f"/v1/apps/{app_id}/appStoreVersions?" + urllib.parse.urlencode(
        {"filter[platform]": "IOS", "limit": 20}))["data"]
    for version in versions:
        if version["attributes"].get("appStoreState") in EDITABLE_STATES:
            return version
    raise RuntimeError("No editable App Store version found.")


def screenshot_set(localization_id, display_type):
    sets = api("GET", f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets?limit=50")["data"]
    for item in sets:
        if item["attributes"]["screenshotDisplayType"] == display_type:
            return item["id"]
    created = api("POST", "/v1/appScreenshotSets", {"data": {
        "type": "appScreenshotSets",
        "attributes": {"screenshotDisplayType": display_type},
        "relationships": {"appStoreVersionLocalization": {
            "data": {"type": "appStoreVersionLocalizations", "id": localization_id}}},
    }})
    return created["data"]["id"]


def upload(set_id, path):
    with open(path, "rb") as f:
        content = f.read()
    reservation = api("POST", "/v1/appScreenshots", {"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(content)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
    }})["data"]
    for operation in reservation["attributes"]["uploadOperations"]:
        chunk = content[operation["offset"]:operation["offset"] + operation["length"]]
        headers = {header["name"]: header["value"] for header in operation.get("requestHeaders", [])}
        request = urllib.request.Request(operation["url"], data=chunk, method=operation["method"], headers=headers)
        with urllib.request.urlopen(request):
            pass
    api("PATCH", f"/v1/appScreenshots/{reservation['id']}", {"data": {
        "type": "appScreenshots",
        "id": reservation["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(content).hexdigest()},
    }})
    return reservation["id"]


def wait_for_processing(ids):
    pending = set(ids)
    failures = []
    deadline = time.time() + 300
    while pending and time.time() < deadline:
        time.sleep(5)
        for screenshot_id in list(pending):
            data = api("GET", f"/v1/appScreenshots/{screenshot_id}?fields[appScreenshots]=fileName,assetDeliveryState")["data"]
            state = data["attributes"].get("assetDeliveryState") or {}
            if state.get("state") == "COMPLETE":
                pending.discard(screenshot_id)
            elif state.get("state") == "FAILED":
                pending.discard(screenshot_id)
                failures.append(f"{data['attributes'].get('fileName')}: {state.get('errors')}")
    failures += [f"{screenshot_id}: still processing" for screenshot_id in pending]
    return failures


def main():
    global TOKEN
    root = sys.argv[1]
    display_type = os.environ.get("DISPLAY_TYPE") or "APP_IPHONE_67"

    TOKEN = token()
    apps = api("GET", "/v1/apps?" + urllib.parse.urlencode({"filter[bundleId]": os.environ["BUNDLE_ID"]}))["data"]
    if not apps:
        raise RuntimeError("App not found in App Store Connect.")
    version = editable_version(apps[0]["id"])
    print(f"Version {version['attributes']['versionString']} ({version['attributes']['appStoreState']})")
    localizations = api("GET", f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=50")["data"]

    problems = []
    for localization in localizations:
        locale = localization["attributes"]["locale"]
        files = sorted(glob.glob(os.path.join(root, locale, "*.png")))
        if not files:
            print(f"{locale}: no screenshots, skipped")
            continue
        set_id = screenshot_set(localization["id"], display_type)
        existing = api("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=50")["data"]
        for screenshot in existing:
            api("DELETE", f"/v1/appScreenshots/{screenshot['id']}")
        ids = [upload(set_id, path) for path in files]
        api("PATCH", f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots", {
            "data": [{"type": "appScreenshots", "id": screenshot_id} for screenshot_id in ids]})
        failures = wait_for_processing(ids)
        problems += [f"{locale}: {failure}" for failure in failures]
        status = "ok" if not failures else f"{len(failures)} problem(s)"
        print(f"{locale}: replaced {len(existing)} with {len(ids)} screenshots in {display_type} (set {set_id}), {status}")
    for problem in problems:
        print(f"::error::{problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
