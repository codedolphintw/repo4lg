#!/bin/bash
# Run the scenes listed in a plan file: one line "<scene> <light|dark> <variant>".
# Variants: normal | compat (UIDesignRequiresCompatibility in Info.plist) |
# reduceTransparency | increaseContrast | fka (full keyboard access) |
# accent-<red|orange|yellow|green|purple|pink|graphite>.
# Run from the repo root; env: OUT (results dir), B (build dir).
set -u
: "${OUT:?}" "${B:?}"
PLAN="${1:-macprobe/plan.txt}"
mkdir -p "$OUT" "$B/apps"
: > "$OUT/run.log"
: > "$OUT/variants.txt"

make_app() {   # <binary> <variant> -> path of the executable inside a bundle
  local bin="$1" variant="$2" compat=""
  [ "$variant" = compat ] && compat='<key>UIDesignRequiresCompatibility</key><true/>'
  local app="$B/apps/$(basename "$bin")-$variant.app"
  if [ ! -d "$app" ]; then
    mkdir -p "$app/Contents/MacOS"
    cp "$bin" "$app/Contents/MacOS/MacProbe"
    cat > "$app/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MacProbe</string>
<key>CFBundleIdentifier</key><string>dev.probe.macprobe</string>
<key>CFBundleName</key><string>MacProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
$compat
</dict></plist>
PL
    codesign -s - --force "$app" > /dev/null 2>&1 || echo "codesign failed for $app" >> "$OUT/variants.txt"
  fi
  echo "$app/Contents/MacOS/MacProbe"
}

accent_value() {
  case "$1" in
    red) echo 0 ;; orange) echo 1 ;; yellow) echo 2 ;; green) echo 3 ;;
    purple) echo 5 ;; pink) echo 6 ;; graphite) echo -1 ;;
  esac
}

dw() {  # defaults write, logged with its exit code
  defaults write "$@" > /dev/null 2>&1
  echo "defaults write $* rc=$?" >> "$OUT/variants.txt"
}

apply_variant() {
  case "$1" in
    reduceTransparency) dw com.apple.universalaccess reduceTransparency -bool true ;;
    increaseContrast) dw com.apple.universalaccess increaseContrast -bool true ;;
    fka) dw -g AppleKeyboardUIMode -int 3 ;;
    accent-*)
      local v; v=$(accent_value "${1#accent-}")
      dw -g AppleAccentColor -int "$v"
      [ "$v" = "-1" ] && dw -g AppleAquaColorVariant -int 6
      ;;
  esac
}

restore_variant() {
  case "$1" in
    reduceTransparency) dw com.apple.universalaccess reduceTransparency -bool false ;;
    increaseContrast) dw com.apple.universalaccess increaseContrast -bool false ;;
    fka) defaults delete -g AppleKeyboardUIMode > /dev/null 2>&1 ;;
    accent-*)
      defaults delete -g AppleAccentColor > /dev/null 2>&1
      defaults delete -g AppleAquaColorVariant > /dev/null 2>&1
      ;;
  esac
}

# The hosted runner starts with Reduce Transparency (and Reduce Motion) ON, which turns
# every glass shape into its opaque fallback. The normal captures need it OFF; the
# variant "reduceTransparency" switches it on for one scene and restores it OFF.
echo "initial reduceTransparency: $(defaults read com.apple.universalaccess reduceTransparency 2>&1)" >> "$OUT/variants.txt"
echo "initial reduceMotion: $(defaults read com.apple.universalaccess reduceMotion 2>&1)" >> "$OUT/variants.txt"
dw com.apple.universalaccess reduceTransparency -bool false
echo "now reduceTransparency: $(defaults read com.apple.universalaccess reduceTransparency 2>&1)" >> "$OUT/variants.txt"
sleep 2

while read -r scene appearance variant rest; do
  case "$scene" in ''|\#*) continue ;; esac
  tag="$scene-$appearance-$variant"
  bin=$(awk -v s="$scene" '$1==s {print $2}' "$B/scenes.map" | head -1)
  if [ -z "$bin" ]; then echo "$tag: no binary (scene file did not build)" | tee -a "$OUT/run.log"; continue; fi
  exe=$(make_app "$bin" "$variant")
  apply_variant "$variant"
  "$exe" --scene "$scene" --appearance "$appearance" --variant "$variant" --out "$OUT" > "$OUT/log-$tag.txt" 2>&1 &
  pid=$!
  i=0
  while [ "$i" -lt 130 ]; do
    [ -f "$OUT/$tag.done" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
    i=$((i + 1))
  done
  kill -9 "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  restore_variant "$variant"
  st="done"
  [ -f "$OUT/$tag.done" ] || st="NO-DONE"
  echo "$tag: $st (${i}s)" | tee -a "$OUT/run.log"
  head -c 20000 "$OUT/log-$tag.txt" > "$OUT/log-$tag.tmp" && mv "$OUT/log-$tag.tmp" "$OUT/log-$tag.txt"
  sleep 1
done < "$PLAN"
exit 0
