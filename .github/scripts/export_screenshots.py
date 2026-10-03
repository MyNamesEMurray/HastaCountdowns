#!/usr/bin/env python3
"""Export the screenshots attached by ScreenshotTests from an .xcresult
bundle into a folder, named after their attachment names."""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile


def main():
    result, output = sys.argv[1], sys.argv[2]
    os.makedirs(output, exist_ok=True)
    with tempfile.TemporaryDirectory() as staging:
        subprocess.run(
            ["xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", staging],
            check=True,
        )
        with open(os.path.join(staging, "manifest.json")) as f:
            manifest = json.load(f)
        count = 0
        for test in manifest:
            for attachment in test.get("attachments", []):
                human = attachment.get("suggestedHumanReadableName", "")
                match = re.match(r"((?:light|dark)-\d\d-[a-z]+)", human)
                if not match:
                    continue
                source = os.path.join(staging, attachment["exportedFileName"])
                extension = os.path.splitext(source)[1] or ".png"
                shutil.copy(source, os.path.join(output, match.group(1) + extension))
                count += 1
    print(f"exported {count} screenshots to {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
