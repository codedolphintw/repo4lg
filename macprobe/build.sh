#!/bin/bash
# Build one binary per scene file (Core.swift + scenes/<file>.swift + a generated
# entry point), so a scene file that does not compile loses only its own scenes.
# Run from the repo root; env: OUT (results dir), B (build dir).
set -u
: "${OUT:?}" "${B:?}"
mkdir -p "$B/bin" "$B/gen" "$OUT/build"
: > "$B/scenes.map"
: > "$OUT/build/summary.txt"
for f in macprobe/scenes/*.swift; do
  base=$(basename "$f" .swift)
  names=$(sed -n 's#^// SCENES: ##p' "$f" | head -1)
  [ -n "$names" ] || continue
  gen="$B/gen/Main_$base.swift"
  {
    echo "import AppKit"
    echo "@main struct Main {"
    echo "  @MainActor static func main() {"
    echo "    sceneRegistry = ["
    for n in $names; do echo "      \"$n\": scene_$n,"; done
    echo "    ]"
    echo "    runApp()"
    echo "  }"
    echo "}"
  } > "$gen"
  if swiftc -swift-version 5 -parse-as-library macprobe/Core.swift "$f" "$gen" -o "$B/bin/MacProbe_$base" > "$OUT/build/$base.txt" 2>&1; then
    for n in $names; do echo "$n $B/bin/MacProbe_$base" >> "$B/scenes.map"; done
    echo "ok     $base ($names)" | tee -a "$OUT/build/summary.txt"
  else
    echo "FAILED $base ($names)" | tee -a "$OUT/build/summary.txt"
    grep -E 'error:' "$OUT/build/$base.txt" | head -30
  fi
  # keep the published log small
  head -c 60000 "$OUT/build/$base.txt" > "$OUT/build/$base.txt.tmp" && mv "$OUT/build/$base.txt.tmp" "$OUT/build/$base.txt"
done
cat "$B/scenes.map" | sed 's#/[^ ]*/##' > "$OUT/build/scenes.map.txt"
exit 0
