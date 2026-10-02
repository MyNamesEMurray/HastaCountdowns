#!/usr/bin/env python3
"""Print the UDID of an iPhone simulator on the newest installed iOS runtime.

Writes `udid=<UDID>` to GITHUB_OUTPUT so the build step can target it
without hard-coding a device name that changes between runner images.
"""

import json
import os
import subprocess
import sys


def runtime_version(identifier):
    suffix = identifier.rsplit("iOS-", 1)[-1]
    try:
        return tuple(int(part) for part in suffix.split("-"))
    except ValueError:
        return ()


def main():
    raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
    devices = json.loads(raw)["devices"]
    best = None
    for runtime, entries in devices.items():
        if ".iOS-" not in runtime:
            continue
        version = runtime_version(runtime)
        for device in entries:
            if not device.get("name", "").startswith("iPhone"):
                continue
            candidate = (version, device["name"], device["udid"])
            if best is None or candidate[:2] > best[:2]:
                best = candidate
    if best is None:
        print("::error::No available iPhone simulator found.")
        subprocess.run(["xcrun", "simctl", "list", "devices"])
        return 1
    version, name, udid = best
    print(f"Using {name} (iOS {'.'.join(map(str, version))}) {udid}")
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a") as f:
            f.write(f"udid={udid}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
