#!/bin/bash
# Boot a fresh simulator and capture every probe page in light/dark under three
# accessibility variants. Output: <page>-<mode>-<variant>.{png,json}.
set -euo pipefail
: "${OUT:?}" "${APP:?}"
BID=dev.probe.liquidglass
# probe/run.env (optional) picks what this run captures: PAGES, VARIANTS, MOTION.
[ -f probe/run.env ] && . probe/run.env
PAGES="${PAGES:-showcase swatch-regular swatch-clear edges buttons inputs list tabs sheet alert glass}"
VARIANTS="${VARIANTS:-normal reduceTransparency increaseContrast}"

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

for variant in $VARIANTS; do
  case $variant in
    normal) set_rt false; xcrun simctl ui "$UDID" increase_contrast disabled ;;
    reduceTransparency) set_rt true; xcrun simctl ui "$UDID" increase_contrast disabled ;;
    increaseContrast) set_rt false; xcrun simctl ui "$UDID" increase_contrast enabled ;;
  esac
  for mode in light dark; do
    xcrun simctl ui "$UDID" appearance "$mode"
    for page in $PAGES; do
      name="$page-$mode-$variant"
      echo "$(date +%T) $name" >> "$OUT/progress.txt"
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

# Motion: screen recordings of the animated pages (light mode), cut into
# frames at 30 fps, 1 px per pt. "press" is pressed with idb when available.
# perl alarm: macOS has no `timeout`. tmo SECONDS cmd...
tmo() { perl -e 'alarm shift; exec @ARGV' "$@"; }
log() { echo "$(date +%T) $*" | tee -a "$OUT/progress.txt"; }
if [ -n "${MOTION:-}" ]; then
  log "motion start: $MOTION"
  set_rt false; xcrun simctl ui "$UDID" increase_contrast disabled; xcrun simctl ui "$UDID" appearance light
  tmo 300 xcrun swiftc -O probe/frames.swift -o "$RUNNER_TEMP/frames" 2> "$OUT/frames-build.txt" || log "frames.swift build failed"
  log "frames tool built"
  for page in $MOTION; do
    xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
    DATA=$(xcrun simctl get_app_container "$UDID" "$BID" data)
    rm -f "$DATA/Documents/frames.json"
    xcrun simctl launch "$UDID" "$BID" -page "$page" > /dev/null
    for _ in $(seq 20); do [ -f "$DATA/Documents/frames.json" ] && break; sleep 0.5; done
    cp "$DATA/Documents/frames.json" "$OUT/motion-$page.json" || true
    log "$page: recording"
    xcrun simctl io "$UDID" recordVideo --codec h264 --force "$OUT/motion-$page.mp4" 2> "$OUT/rec-$page.txt" &
    REC=$!
    sleep 1
    if [ "$page" = press ] && command -v idb > /dev/null; then
      # centers from frames.json, in points
      read -r IX IY BX BY < <(python3 -c '
import json, sys
b = json.load(open(sys.argv[1]))["bounds"]
c = lambda k: (b[k]["x"] + b[k]["w"] / 2, b[k]["y"] + b[k]["h"] / 2)
print(*c("press.interactive"), *c("press.button"))' "$OUT/motion-$page.json")
      sleep 1
      log "press: idb tap $IX $IY"
      tmo 20 idb ui tap --udid "$UDID" --duration 1.5 "$IX" "$IY" > "$OUT/idb-press.txt" 2>&1 || echo "idb tap failed rc=$?" >> "$OUT/idb-press.txt"
      sleep 1
      tmo 20 idb ui tap --udid "$UDID" --duration 1.5 "$BX" "$BY" >> "$OUT/idb-press.txt" 2>&1 || echo "idb tap failed rc=$?" >> "$OUT/idb-press.txt"
      sleep 1
    else
      sleep 7
    fi
    kill -INT $REC 2>/dev/null || true
    for _ in $(seq 20); do kill -0 $REC 2>/dev/null || break; sleep 0.5; done
    kill -9 $REC 2>/dev/null || true
    log "$page: recorded $(stat -f %z "$OUT/motion-$page.mp4" 2>/dev/null || echo missing) bytes"
    tmo 240 "$RUNNER_TEMP/frames" "$OUT/motion-$page.mp4" "$OUT/motion-$page" 30 0.3333333 > "$OUT/motion-$page.txt" 2>&1 || log "$page: frames failed"
    log "$page: $(cat "$OUT/motion-$page.txt" | tail -1)"
  done
fi
