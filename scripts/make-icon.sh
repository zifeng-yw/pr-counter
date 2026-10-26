#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ICON_BUNDLE=Resources/AppIcon.icon
rm -rf "$ICON_BUNDLE"
mkdir -p "$ICON_BUNDLE/Assets"
swift scripts/make-icon.swift "$ICON_BUNDLE/Assets/foreground.png"
cat > "$ICON_BUNDLE/icon.json" <<'JSON'
{
  "fill" : {
    "automatic-gradient" : "srgb:0.12157,0.14902,0.18824,1.00000"
  },
  "groups" : [
    {
      "layers" : [
        {
          "image-name" : "foreground.png",
          "name" : "foreground"
        }
      ],
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.5
      },
      "translucency" : {
        "enabled" : true,
        "value" : 0.3
      }
    }
  ],
  "supported-platforms" : {
    "circles" : [
      "watchOS"
    ],
    "squares" : "shared"
  }
}
JSON
echo "Wrote $ICON_BUNDLE"
