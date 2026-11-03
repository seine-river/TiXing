#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/TiXing/Vendor/Umeng"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$VENDOR"
curl --retry 5 --retry-all-errors --connect-timeout 15 --max-time 300 --compressed -fsSL \
  'https://devs.umeng.com/sdk' -o "$WORK/sdk.html"

URL="$(python3 - "$WORK/sdk.html" "$WORK/payload.json" <<'PY'
import copy
import json
import sys
import urllib.request

html_path, _payload_path = sys.argv[1:]
html = open(html_path, encoding="utf-8", errors="ignore").read()
marker = "window.__INITIAL_DATA__ ="
start = html.index(marker) + len(marker)
end = html.index("</script>", start)
initial = json.loads(html[start:end])
platform = copy.deepcopy(next(item for item in initial["platforms"] if item["code"] == "ios"))
platform["required"] = 1
platform["component"] = []
for code in ("ios_app", "ios_apm"):
    component = copy.deepcopy(next(item for item in platform["component"] if item["code"] == code))
    component["required"] = 1
    component["visible"] = True
    platform["component"].append(component)
payload = {"data": platform, "version": initial["allList"][0]["version"]}
request = urllib.request.Request(
    "https://devs.umeng.com/download",
    data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
    headers={"content-type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=120) as response:
    result = json.load(response)
print(result["oss"])
PY
)"

curl --retry 8 --retry-all-errors --connect-timeout 15 --max-time 900 -fL "$URL" -o "$WORK/umeng.zip"
unzip -q "$WORK/umeng.zip" -d "$WORK/extracted"
while IFS= read -r framework; do
  name="$(basename "$framework")"
  rm -rf "$VENDOR/$name"
  cp -R "$framework" "$VENDOR/$name"
done < <(find "$WORK/extracted" -name 'UMCommon.xcframework' -o -name 'UMDevice.xcframework' -o -name 'UMAPM.xcframework')

python3 "$ROOT/generate_project.py"
echo "Umeng XCFrameworks installed in $VENDOR"
