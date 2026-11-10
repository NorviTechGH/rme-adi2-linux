"""ALSA MIDI transport via alsa-utils `amidi` (no extra dependencies).

The ADI-2 must have MIDI Control enabled (Setup > Device Mode / DSD on
the DAC) and appears as an ALSA raw-MIDI port named "ADI-2 DAC".
"""
from __future__ import annotations
import re
import subprocess
from dataclasses import dataclass

from . import protocol as proto


@dataclass
class Port:
    card_device: str          # e.g. "hw:3,0,0"
    name: str


def find_ports() -> list[Port]:
    try:
        out = subprocess.run(["amidi", "-l"], capture_output=True, text=True,
                             timeout=5).stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    ports = []
    for line in out.splitlines():
        m = re.match(r"\s*IO\s+(hw:\S+)\s+(.*ADI-2.*)", line)
        if m and "MIDI 2" not in m.group(2):  # control lives on Port 1
            ports.append(Port(m.group(1), m.group(2).strip()))
    return ports


class Transport:
    def __init__(self, port: str, device_id: int = 0x71):
        self.port, self.device_id = port, device_id

    def send(self, message: bytes) -> None:
        subprocess.run(["amidi", "-p", self.port, "-S", message.hex(" ")],
                       check=True, capture_output=True, timeout=10)

    def send_params(self, containers: list[bytes]) -> None:
        # RME caps one SysEx block at 256 bytes: chunk to 80 containers.
        for i in range(0, len(containers), 80):
            self.send(proto.params_message(self.device_id, containers[i:i + 80]))

    def _capture(self, message: bytes, seconds: float) -> bytes:
        """Send a request and collect replies for `seconds`.

        The ADI-2 streams level/status frames forever once woken, so
        amidi never goes idle: capture is cut off by the timeout and
        whatever arrived is parsed."""
        try:
            proc = subprocess.run(
                ["amidi", "-p", self.port, "-S", message.hex(" "), "-d"],
                capture_output=True, timeout=seconds)
            raw = proc.stdout
        except subprocess.TimeoutExpired as exc:
            raw = exc.stdout or b""
        hex_text = "".join(c for c in raw.decode("ascii", "ignore")
                           if c in "0123456789abcdefABCDEF")
        return bytes.fromhex(hex_text[: len(hex_text) - len(hex_text) % 2])

    def request_all(self, timeout: float = 3.0) -> dict:
        """Send 03 09 and collect the device's parameter dump.

        Returns {(address, index): raw} with frequencies already decoded
        to Hz for EQ addresses."""
        from .params import freq_index_map
        data = self._capture(proto.request_all_message(self.device_id), timeout)
        state = {}
        for msg in proto.split_messages(data):
            parsed = proto.parse_message(msg)
            if not parsed or parsed[1] != proto.CMD_TO_REMOTE:
                continue
            for address, index, value in proto.parse_params(parsed[2], freq_index_map()):
                state[(address, index)] = value
        return state

    def request_names(self, timeout: float = 2.0) -> dict:
        data = self._capture(proto.request_all_message(self.device_id), timeout)
        names = {}
        for msg in proto.split_messages(data):
            parsed = proto.parse_message(msg)
            if not parsed or parsed[0] != self.device_id or parsed[1] != proto.CMD_NAME_TO_REMOTE:
                continue
            payload = parsed[2]
            if payload:
                names[payload[0]] = payload[1:15].decode("ascii", "replace").strip(" \x00")
        return names
