#!/usr/bin/env bash
# Export a throwaway WEB build whose main scene is tests/web_blast_check.tscn, so the
# blast-death path can be proven in a real browser on the gl_compatibility renderer.
# The shipping build/web/ is never touched: this exports to the scratch dir passed in.
# project.godot and export_presets.cfg are restored on exit, always.
set -euo pipefail

OUT="${1:?usage: web_blast_check.sh <output-dir>}"
GODOT="${GODOT:-$HOME/Downloads/godot-4.6.2/Godot.app/Contents/MacOS/Godot}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"

cp project.godot project.godot.bak
cp export_presets.cfg export_presets.cfg.bak
restore() { mv -f project.godot.bak project.godot; mv -f export_presets.cfg.bak export_presets.cfg; }
trap restore EXIT

mkdir -p "$OUT"

# Clone the Web preset into a second preset that keeps tests/ in the pack.
python3 - "$OUT" <<'PY'
import re, sys
out = sys.argv[1]
cfg = open('export_presets.cfg').read()
blk = cfg.split('[preset.1]')[0].rstrip() + '\n'
clone = blk.replace('[preset.0]', '[preset.1]').replace('[preset.0.options]', '[preset.1.options]')
clone = clone.replace('name="Web"', 'name="WebBlastCheck"')
clone = clone.replace('exclude_filter="addons/gut/*, tests/*, *.gd.uid"',
                      'exclude_filter="addons/gut/*, *.gd.uid"')
clone = re.sub(r'export_path="[^"]*"', 'export_path="%s/index.html"' % out, clone)
open('export_presets.cfg', 'w').write(cfg.rstrip() + '\n\n' + clone)
PY

# Point the build at the check scene instead of the game.
sed -i '' 's|^run/main_scene=.*|run/main_scene="res://tests/web_blast_check.tscn"|' project.godot

"$GODOT" --headless --path . --export-release "WebBlastCheck" "$OUT/index.html"
echo "exported to $OUT"
