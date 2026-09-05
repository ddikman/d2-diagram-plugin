#!/usr/bin/env bash
# fetch-fonts.sh — maintainer script: (re)download the bundled OFL fonts into assets/fonts/.
#
# Usage: scripts/fetch-fonts.sh
#
# The plugin ships unmodified static TTFs (no subsetting, so no reserved-font-name concerns) for
# three families, each with its SIL Open Font License text:
#   inter          Inter by Rasmus Andersson        https://github.com/rsms/inter
#   ibm-plex-mono  IBM Plex Mono by IBM             https://github.com/IBM/plex (via google/fonts)
#   lora           Lora by Cyreal                   https://github.com/cyrealtype/Lora-Cyrillic
# Sources are pinned; override INTER_VERSION, GOOGLE_FONTS_REF or LORA_REF to update.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTER_VERSION="${INTER_VERSION:-4.1}"
GOOGLE_FONTS_REF="${GOOGLE_FONTS_REF:-5e35378e6bda803962ee6fd257e444a7d459660d}"  # google/fonts main, 2026-09
LORA_REF="${LORA_REF:-2d53b449b60e185b39f671b44fded83e0910ad30}"  # cyrealtype/Lora-Cyrillic main, 2026-09
INTER_ZIP="${INTER_ZIP:-}"   # optional: path to an already downloaded Inter-<version>.zip

dl() { echo "  $2"; curl -fsSL --retry 3 --max-time 300 -o "$2" "$1"; }

echo "IBM Plex Mono"
d="$ROOT/assets/fonts/ibm-plex-mono"; mkdir -p "$d"
for s in Regular Bold Italic SemiBold; do
  dl "https://raw.githubusercontent.com/google/fonts/$GOOGLE_FONTS_REF/ofl/ibmplexmono/IBMPlexMono-$s.ttf" "$d/IBMPlexMono-$s.ttf"
done
dl "https://raw.githubusercontent.com/google/fonts/$GOOGLE_FONTS_REF/ofl/ibmplexmono/OFL.txt" "$d/OFL.txt"

echo "Lora"
d="$ROOT/assets/fonts/lora"; mkdir -p "$d"
for s in Regular Bold Italic SemiBold; do
  dl "https://raw.githubusercontent.com/cyrealtype/Lora-Cyrillic/$LORA_REF/fonts/ttf/Lora-$s.ttf" "$d/Lora-$s.ttf"
done
dl "https://raw.githubusercontent.com/cyrealtype/Lora-Cyrillic/$LORA_REF/OFL.txt" "$d/OFL.txt"

echo "Inter"
d="$ROOT/assets/fonts/inter"; mkdir -p "$d"
tmp="$(mktemp -d)"
zip="$INTER_ZIP"
if [ -z "$zip" ] || [ ! -f "$zip" ]; then
  zip="$tmp/Inter-$INTER_VERSION.zip"
  dl "https://github.com/rsms/inter/releases/download/v$INTER_VERSION/Inter-$INTER_VERSION.zip" "$zip"
fi
unzip -q -o "$zip" 'extras/ttf/Inter-Regular.ttf' 'extras/ttf/Inter-Bold.ttf' 'extras/ttf/Inter-Italic.ttf' \
  'extras/ttf/Inter-SemiBold.ttf' 'LICENSE.txt' -d "$tmp"
cp "$tmp"/extras/ttf/Inter-*.ttf "$d/"
cp "$tmp/LICENSE.txt" "$d/OFL.txt"
rm -rf "$tmp"

echo
for f in "$ROOT"/assets/fonts/*/*.ttf; do
  case "$(head -c 4 "$f" | xxd -p)" in 00010000|74727565) ;; *) echo "error: $f is not a TrueType font" >&2; exit 1 ;; esac
done
du -sh "$ROOT"/assets/fonts/* | sed 's|.*/assets/|assets/|'
du -sh "$ROOT/assets/fonts" | sed 's|.*/assets/|total assets/|'
