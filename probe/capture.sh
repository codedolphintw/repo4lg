#!/bin/bash
# Boot a fresh simulator, run Probe.app in light and dark, save screenshot + frames.
set -euo pipefail
: "${OUT:?}" "${APP:?}"
BID=dev.probe.liquidglass

RT=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]]
rs.sort(key=lambda r: [int(p) for p in r["version"].split(".")])
print(rs[-1]["identifier"])')
DT=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
ids = [d["identifier"] for d in json.load(sys.stdin)["devicetypes"]]
for want in ("iPhone-17-Pro", "iPhone-16-Pro"):
    hit = [i for i in ids if i.endswith("." + want)]
    if hit:
        print(hit[0]); break
else:
    sys.exit("no iPhone Pro device type")')
echo "runtime=$RT devicetype=$DT" | tee "$OUT/device.txt"

UDID=$(xcrun simctl create lgprobe "$DT" "$RT")
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged \
  --batteryLevel 100 --wifiBars 3 --cellularBars 4
xcrun simctl install "$UDID" "$APP"

for mode in light dark; do
  xcrun simctl ui "$UDID" appearance "$mode"
  xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BID"
  sleep 8
  xcrun simctl io "$UDID" screenshot "$OUT/glass-$mode.png"
  DATA=$(xcrun simctl get_app_container "$UDID" "$BID" data)
  cp "$DATA/Documents/frames.json" "$OUT/glass-$mode.json" || echo "frames.json missing ($mode)"
done
