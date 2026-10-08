#!/bin/bash
# Boot a fresh simulator and capture every probe page in light/dark under three
# accessibility variants. Output: <page>-<mode>-<variant>.{png,json}.
set -euo pipefail
: "${OUT:?}" "${APP:?}"
BID=dev.probe.liquidglass
PAGES="${PAGES:-showcase swatch-regular swatch-clear edges buttons inputs list tabs sheet alert glass}"

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

# Reduce Transparency has no simctl switch. Both candidate keys are written;
# the app records UIAccessibility.isReduceTransparencyEnabled, which is the
# only evidence that counts.
set_rt() {
  for key in EnhancedBackgroundContrastEnabled ReduceTransparencyEnabled; do
    xcrun simctl spawn "$UDID" defaults write com.apple.Accessibility "$key" -bool "$1" || true
  done
  xcrun simctl spawn "$UDID" notifyutil -p com.apple.accessibility.cache.enhance.background.contrast || true
}

for variant in normal reduceTransparency increaseContrast; do
  case $variant in
    normal) set_rt false; xcrun simctl ui "$UDID" increase_contrast disabled ;;
    reduceTransparency) set_rt true; xcrun simctl ui "$UDID" increase_contrast disabled ;;
    increaseContrast) set_rt false; xcrun simctl ui "$UDID" increase_contrast enabled ;;
  esac
  for mode in light dark; do
    xcrun simctl ui "$UDID" appearance "$mode"
    for page in $PAGES; do
      name="$page-$mode-$variant"
      xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
      DATA=$(xcrun simctl get_app_container "$UDID" "$BID" data)
      rm -f "$DATA/Documents/frames.json"
      xcrun simctl launch "$UDID" "$BID" -page "$page" > /dev/null
      # 3 s for the app to write frames.json, plus margin; one launch in 42
      # missed 5 s in run 37705008773, so wait for the file instead.
      for _ in $(seq 1 20); do [ -f "$DATA/Documents/frames.json" ] && break; sleep 0.5; done
      sleep 1
      xcrun simctl io "$UDID" screenshot "$OUT/$name.png" 2> /dev/null
      cp "$DATA/Documents/frames.json" "$OUT/$name.json" || echo "frames.json missing: $name"
    done
  done
done
