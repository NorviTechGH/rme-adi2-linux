#!/bin/sh
# Install ADI-2 Control for the current user (no root needed).
set -eu
cd "$(dirname "$0")"
pip install --user .
mkdir -p ~/.local/share/applications ~/.local/share/icons/hicolor/512x512/apps
cp data/tech.norvi.Adi2Control.png \
    ~/.local/share/icons/hicolor/512x512/apps/tech.norvi.Adi2Control.png
sed "s|^Exec=.*|Exec=$HOME/.local/bin/adi2-control|" \
    data/tech.norvi.Adi2Control.desktop \
    > ~/.local/share/applications/tech.norvi.Adi2Control.desktop
echo "Installed. Run: adi2-control   (or launch 'ADI-2 Control')"
echo "Optional bit-perfect PipeWire setup: see README, 'Bit-perfect PipeWire'."
