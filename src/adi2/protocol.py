"""RME ADI-2 MIDI SysEx protocol (RME MIDITable v1.2, 2026-10-30).

Wire format: F0 00 20 0D <device-id> <command> <payload...> F7
Parameters travel in 3-byte containers. Channel addresses 0..11 and
13/14 pack a 5-bit parameter index and a signed 12-bit raw value;
frequencies use 11 bits plus a factor-10 flag. Address 12 (device
settings) packs a 6-bit index and an unsigned 11-bit value instead.
All bytes after F0 are 7-bit. Encoding here is verified byte-for-byte
against the worked examples in RME's table (see tests/test_protocol.py).
"""
from __future__ import annotations

VENDOR = (0x00, 0x20, 0x0D)
DEVICE_IDS = {"dac": 0x71, "pro": 0x72, "pro24": 0x73}
CMD_TO_REMOTE, CMD_TO_DEVICE, CMD_REQUEST, CMD_REQUEST_PRESET = 0x01, 0x02, 0x03, 0x04
CMD_NAME_TO_REMOTE, CMD_NAME_TO_DEVICE, CMD_STATUS = 0x05, 0x06, 0x07

# Channel addresses: each output owns a channel block plus EQ left/right.
OUTPUTS = {
    "line":    {"channel": 3, "eq_left": 4,  "eq_right": 5,  "label": "Line Out"},
    "phones":  {"channel": 6, "eq_left": 7,  "eq_right": 8,  "label": "Phones 1/2"},
    "phones34": {"channel": 9, "eq_left": 10, "eq_right": 11, "label": "Phones 3/4"},
}
ADDR_INPUT, ADDR_INPUT_EQ_L, ADDR_INPUT_EQ_R = 0, 1, 2
ADDR_DEVICE, ADDR_PRESET_L, ADDR_PRESET_R = 12, 13, 14


def _check_raw(raw: int) -> int:
    if not -2048 <= raw <= 2047:
        raise ValueError(f"raw value {raw} outside signed 12-bit range")
    return raw & 0xFFF


def encode_param(address: int, index: int, raw: int) -> bytes:
    """Encode one 3-byte parameter container (channel-style packing)."""
    if not 0 <= address <= 15:
        raise ValueError("address outside 0..15")
    if not 0 <= index <= 31:
        raise ValueError("parameter index outside 0..31")
    v = _check_raw(raw)
    return bytes(((address << 3) | (index >> 2),
                  ((index & 0x03) << 5) | ((v >> 7) & 0x1F),
                  v & 0x7F))


def encode_freq(address: int, index: int, hz: float) -> bytes:
    """Frequencies: direct 11-bit up to 2047 Hz, else Hz/10 + factor flag."""
    if hz <= 2047:
        raw, factor = int(round(hz)), 0
    else:
        raw, factor = int(round(hz / 10.0)), 1
    if not 0 <= raw <= 2047:
        raise ValueError(f"frequency {hz} Hz not representable")
    return bytes(((address << 3) | (index >> 2),
                  ((index & 0x03) << 5) | (factor << 4) | ((raw >> 7) & 0x0F),
                  raw & 0x7F))


def encode_device_param(index: int, raw: int) -> bytes:
    """Address-12 packing: 6-bit index, unsigned 11-bit value."""
    if not 0 <= index <= 63:
        raise ValueError("device parameter index outside 0..63")
    if not 0 <= raw <= 2047:
        raise ValueError("device value outside 0..2047")
    return bytes(((ADDR_DEVICE << 3) | (index >> 3),
                  ((index & 0x07) << 4) | ((raw >> 7) & 0x0F),
                  raw & 0x7F))


def decode_param(b: bytes) -> tuple[int, int, int]:
    """Decode a channel-style container -> (address, index, raw signed)."""
    if len(b) != 3:
        raise ValueError("container must be 3 bytes")
    address = (b[0] >> 3) & 0x0F
    index = ((b[0] & 0x07) << 2) | ((b[1] >> 5) & 0x03)
    raw = ((b[1] & 0x1F) << 7) | (b[2] & 0x7F)
    return address, index, raw - 4096 if raw > 2047 else raw


def decode_freq(b: bytes) -> tuple[int, int, int]:
    address, index, _ = decode_param(b)
    raw11 = ((b[1] & 0x0F) << 7) | (b[2] & 0x7F)
    return address, index, raw11 * 10 if (b[1] >> 4) & 1 else raw11


def decode_device_param(b: bytes) -> tuple[int, int]:
    index = ((b[0] & 0x07) << 3) | ((b[1] >> 4) & 0x07)
    raw = ((b[1] & 0x0F) << 7) | (b[2] & 0x7F)
    return index, raw


def build_message(device_id: int, command: int, payload: bytes = b"") -> bytes:
    return bytes((0xF0, *VENDOR, device_id, command)) + payload + b"\xf7"


def params_message(device_id: int, containers: list[bytes]) -> bytes:
    """Command 0x02: send parameters to the device."""
    return build_message(device_id, CMD_TO_DEVICE, b"".join(containers))


def request_all_message(device_id: int) -> bytes:
    return build_message(device_id, CMD_REQUEST, b"\x09")


def request_eq_preset_message(device_id: int, slot_zero_based: int) -> bytes:
    return build_message(device_id, CMD_REQUEST, bytes((0x0A + slot_zero_based,)))


def preset_command_message(device_id: int, sub: int) -> bytes:
    """Command 0x04: 0x01..0x09 load setup 1..9, 0x0A..0x12 save, 0x13 factory."""
    return build_message(device_id, CMD_REQUEST_PRESET, bytes((sub,)))


def name_message(device_id: int, first_byte: int, name: str) -> bytes:
    """Command 0x06 name transfer: 14-char right-aligned field + 00 00."""
    field = name.encode("ascii", "replace")[:14].rjust(14, b" ")
    return build_message(device_id, CMD_NAME_TO_DEVICE,
                         bytes((first_byte,)) + field + b"\x00\x00")


def split_messages(data: bytes) -> list[bytes]:
    out, cur = [], None
    for byte in data:
        if byte == 0xF0:
            cur = bytearray((byte,))
        elif cur is not None:
            cur.append(byte)
            if byte == 0xF7:
                out.append(bytes(cur))
                cur = None
    return out


def parse_message(msg: bytes) -> tuple[int, int, bytes] | None:
    """-> (device_id, command, payload) or None if not an ADI-2 message."""
    if len(msg) < 7 or msg[0] != 0xF0 or tuple(msg[1:4]) != VENDOR or msg[-1] != 0xF7:
        return None
    return msg[4], msg[5], msg[6:-1]


def parse_params(payload: bytes, freq_indices: dict[int, set[int]] | None = None):
    """Yield (address, index, value). freq_indices maps address -> freq
    parameter indices, decoded with the factor-10 rule instead of signed."""
    freq_indices = freq_indices or {}
    for i in range(0, len(payload) - 2, 3):
        chunk = payload[i:i + 3]
        address = (chunk[0] >> 3) & 0x0F
        if address == ADDR_DEVICE:
            index, raw = decode_device_param(chunk)
            yield address, index, raw
        elif address in freq_indices:
            _, index, _ = decode_param(chunk)
            if index in freq_indices[address]:
                yield decode_freq(chunk)
            else:
                yield decode_param(chunk)
        else:
            yield decode_param(chunk)
