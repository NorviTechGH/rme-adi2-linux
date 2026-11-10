#!/usr/bin/env python3
"""Recreated EQ builder (the 2026-05 original lived in /tmp and is lost).

Builds the SysEx block for an EQ profile and either writes it as hex,
or sends it to a connected ADI-2 with amidi.

    python3 tools/build_eq.py                      # DT 1990, print hex
    python3 tools/build_eq.py profile.json -o eq.syx --binary
    python3 tools/build_eq.py --send               # via first ADI-2 port
    python3 tools/build_eq.py --send --port hw:3,0,0 --device pro
"""
import argparse
import sys
from pathlib import Path

from . import protocol as proto
from .eq import EqProfile, dt1990_profile


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("profile", nargs="?", help="profile JSON (default: DT 1990)")
    ap.add_argument("-o", "--output", help="write SysEx here (.syx with --binary)")
    ap.add_argument("--binary", action="store_true", help="write raw .syx bytes")
    ap.add_argument("--send", action="store_true", help="send with amidi")
    ap.add_argument("--port", help="ALSA port, e.g. hw:3,0,0 (default: auto-detect)")
    ap.add_argument("--device", default="dac", choices=sorted(proto.DEVICE_IDS))
    args = ap.parse_args()

    profile = EqProfile.load(args.profile) if args.profile else dt1990_profile()
    device_id = proto.DEVICE_IDS[args.device]
    message = profile.message(device_id)
    print(f"{profile.name} -> {profile.output}: {len(message)} bytes, "
          f"{len(profile.containers())} parameters", file=sys.stderr)

    if args.output:
        if args.binary:
            Path(args.output).write_bytes(message)
        else:
            Path(args.output).write_text(message.hex(" ").upper() + "\n")
        print(f"wrote {args.output}", file=sys.stderr)
    if args.send:
        from .transport import Transport, find_ports
        port = args.port
        if not port:
            ports = find_ports()
            if not ports:
                print("no ADI-2 MIDI port found (check USB + MIDI Control = On)",
                      file=sys.stderr)
                return 2
            port = ports[0].card_device
        Transport(port, device_id).send(message)
        print(f"sent to {port}", file=sys.stderr)
    if not args.output and not args.send:
        print(message.hex(" ").upper())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
