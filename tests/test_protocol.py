"""Oracles are RME's own worked examples (MIDITable Examples sheet)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / "src"))
from adi2 import protocol as p  # noqa: E402

PRO = 0x73  # all RME examples use the ADI-2/4 Pro SE device ID


def hx(s):
    return bytes.fromhex(s)


def test_volume_example():
    # "Set Volume of Phones 34 to -10dB (address 9, index 12, value -100)"
    msg = p.params_message(PRO, [p.encode_param(9, 12, -100)])
    assert msg == hx("F0 00 20 0D 73 02 4B 1F 1C F7")


def test_input_range_example():
    # "Set Input-Range to 13dBu (address 0, parameter index 1, value 2)"
    msg = p.params_message(PRO, [p.encode_param(0, 1, 2)])
    assert msg == hx("F0 00 20 0D 73 02 00 20 02 F7")


def test_status_request_example():
    assert p.request_all_message(PRO) == hx("F0 00 20 0D 73 03 09 F7")


def test_eq_preset_request_example():
    # "Request EQ-Preset 2 (counting from zero: 1)"
    assert p.request_eq_preset_message(PRO, 1) == hx("F0 00 20 0D 73 03 0B F7")


def test_band5_freq_factor10():
    # From the device's preset answer: address 14, index 18, 10000 Hz.
    assert p.encode_freq(14, 18, 10000) == hx("74 57 68")
    assert p.decode_freq(hx("74 57 68")) == (14, 18, 10000)


def test_decode_real_device_containers():
    # Fragments of the recorded "Send all Settings" answer.
    assert p.decode_param(hx("09 20 64")) == (1, 5, 100)    # Band 1 Freq
    assert p.decode_freq(hx("0A 03 74")) == (1, 8, 500)     # Band 2 Freq
    assert p.decode_param(hx("4B 1F 1C")) == (9, 12, -100)  # Phones 34 volume


def test_signed_roundtrip():
    for raw in (-2048, -100, -3, 0, 13, 2047):
        assert p.decode_param(p.encode_param(7, 4, raw)) == (7, 4, raw)


def test_device_param_roundtrip():
    for idx, raw in ((1, 3), (25, 2), (63, 2047)):
        assert p.decode_device_param(p.encode_device_param(idx, raw)) == (idx, raw)


def test_name_message_shape():
    msg = p.name_message(PRO, 0x21, "Setup 1")
    assert msg[6] == 0x21 and msg[21:23] == b"\x00\x00" and len(msg) == 24
    assert msg[7:21] == b"       Setup 1"


if __name__ == "__main__":
    for name, fn in sorted(dict(globals()).items()):
        if name.startswith("test_"):
            fn()
            print(f"ok {name}")
