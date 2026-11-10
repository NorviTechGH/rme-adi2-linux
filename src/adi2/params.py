"""Parameter registry from RME's MIDITable (ADI-2 DAC values unless noted).

Real units are converted to wire raw values by ``raw = real / incr``,
except volume, which RME transmits in 0.1 dB steps, and EQ frequencies,
which use the factor-10 encoding in protocol.encode_freq.
"""
from __future__ import annotations
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Param:
    index: int
    name: str
    kind: str = "number"          # number | enum | bool | freq
    minimum: float = 0.0
    maximum: float = 1.0
    default: float = 0.0
    incr: float = 1.0             # real units per raw step
    unit: str = ""
    labels: tuple = ()            # enum labels, position = raw value
    devices: tuple = ("dac", "pro", "pro24")

    def to_raw(self, real: float) -> int:
        return int(round(real / self.incr))

    def to_real(self, raw: int) -> float:
        return raw * self.incr


def enum(index, name, labels, default=0, devices=("dac", "pro", "pro24")):
    return Param(index, name, "enum", 0, len(labels) - 1, default, 1, "", tuple(labels), devices)


def boolean(index, name, default=0, devices=("dac", "pro", "pro24")):
    return Param(index, name, "bool", 0, 1, default, 1, "", ("off", "on"), devices)


def num(index, name, lo, hi, default, incr, unit="", devices=("dac", "pro", "pro24")):
    return Param(index, name, "number", lo, hi, default, incr, unit, (), devices)


DAC, PRO = ("dac",), ("pro", "pro24")

OUTPUT_CHANNEL = [
    enum(1, "Source", ("Auto", "SPDIF coax", "Optical", "USB", "USB (Rec coax)", "USB (Rec opt.)"), devices=DAC),
    enum(1, "Source", ("Auto", "AES", "SPDIF", "Analog", "USB 1/2", "USB 3/4"), devices=PRO),
    boolean(3, "Auto Ref Level", 1),
    enum(4, "Mono", ("OFF", "ON", "to Left")),
    num(5, "Width", -1.0, 1.0, 1.0, 0.01),
    boolean(6, "M/S Processing"),
    enum(7, "Polarity", ("OFF", "Both", "Left", "Right")),
    enum(8, "Crossfeed", ("Off", "1", "2", "3", "4", "5")),
    enum(9, "DA Filter", ("SD Sharp", "SD Slow", "Sharp", "Slow", "NOS", "SD LD / Brickwall"), devices=DAC),
    enum(9, "DA Filter", ("SD Sharp", "SD Slow", "Sharp", "Slow", "NOS", "SD LD"), devices=PRO),
    enum(10, "De-Emphasis", ("Auto", "ON", "OFF")),
    boolean(11, "Dual EQ"),
    Param(12, "Volume", "number", -114.5, 6.0, -10.0, 0.1, "dB"),
    boolean(13, "Lock Volume"),
    num(14, "Balance", -1.0, 1.0, 0.0, 0.01),
    boolean(15, "Mute"),
    boolean(16, "Dim"),
    enum(17, "Loopback to USB", ("OFF", "pre FX", "post FX", "post -6 dB"), devices=DAC),
    enum(18, "Digital DC Protection", ("OFF", "ON", "Filter")),
    boolean(20, "Loudness Enable"),
    num(21, "Loudness Bass Gain", 1.0, 10.0, 7.0, 0.5, "dB"),
    num(22, "Loudness Treble Gain", 1.0, 10.0, 7.0, 0.5, "dB"),
    num(23, "Loudness Low Vol Ref", -90.0, -20.0, -30.0, 0.5, "dB"),
]
REF_LEVEL_LINE = enum(2, "Ref Level (Line)", ("-5 dBu", "+1 dBu", "+7 dBu", "+13 dBu"), 2, DAC)
REF_LEVEL_LINE_PRO = enum(2, "Ref Level (Line)", ("+4 dBu", "+13 dBu", "+19 dBu", "+24 dBu"), 2, PRO)
REF_LEVEL_PHONES = enum(2, "Ref Level (Phones)", ("Lo-Power", "Hi-Power"), 0)

INPUT_CHANNEL = [
    enum(1, "Ref Level", ("+4 dBu", "+13 dBu", "+19 dBu", "+24 dBu"), 2, PRO),
    boolean(2, "Auto Ref Level"),
    num(3, "Trim Gain Left", 0.0, 6.0, 0.0, 0.5, "dB"),
    num(4, "Trim Gain Right", 0.0, 6.0, 0.0, 0.5, "dB"),
    enum(5, "Phase Invert", ("OFF", "Both", "Left", "Right")),
    boolean(6, "M/S Processing"),
    enum(7, "AD Filter", ("SD Sharp", "SD Slow", "Sharp", "Slow")),
    boolean(8, "Dual EQ"),
    enum(9, "AD Conversion", ("PCM", "DSD")),
]

BAND_TYPES_1 = ("Peak", "Shelf", "High Pass", "High Cut")
BAND_TYPES_5 = ("Peak", "Shelf", "High Cut")
EQ_BANDS = [  # (band, type_idx, gain_idx, freq_idx, q_idx)
    (1, 3, 4, 5, 6), (2, None, 7, 8, 9), (3, None, 10, 11, 12),
    (4, None, 13, 14, 15), (5, 16, 17, 18, 19),
]
EQ_FREQ_INDEX = {5, 8, 11, 14, 18, 22, 25}
EQ_EXTRA = [
    boolean(2, "EQ Enable"),
    boolean(20, "Bass/Treble Enable", 1),
    num(21, "Bass Gain", -12.0, 12.0, 0.0, 0.5, "dB"),
    Param(22, "Bass Frequency", "freq", 20, 150, 85, 1, "Hz"),
    num(23, "Bass Q", 0.5, 1.5, 0.9, 0.1),
    num(24, "Treble Gain", -12.0, 12.0, 0.0, 0.5, "dB"),
    Param(25, "Treble Frequency", "freq", 3000, 10000, 6500, 1, "Hz"),
    num(26, "Treble Q", 0.5, 1.5, 0.7, 0.1),
    boolean(27, "Load B/T with Preset"),
    enum(28, "EQ Preset Select",
         ("Manual", "Temp") + tuple(f"Preset {i}" for i in range(1, 21)) + ("Clear",)),
]

REMAP_DAC = ("Default", "Setup 1", "Setup 2", "Setup 3", "Setup 4", "Setup 5",
             "Setup 6", "Setup 7", "Setup 8", "Setup 9", "Mono", "Mono to L",
             "Mute", "Loudness", "EQ enable", "B/T enable", "EQ+B/T+Ld",
             "Toggle Ph/Line", "Polarity", "AutoDark", "Dim", "Toggle View",
             "Crossfeed 1", "Crossfeed 2", "Crossfeed 3", "Crossfeed 4",
             "Crossfeed 5", "DA SD Sharp", "DA SD Slow", "DA Sharp", "DA Slow",
             "DA NOS", "DA SD LD (Brickwall)", "EQ Preset 1", "EQ Preset 2",
             "EQ Preset 3", "EQ Preset 4", "EQ Preset 5", "EQ Preset 6",
             "EQ Preset 7", "EQ Preset 8", "EQ Preset 9")

DEVICE_PARAMS = [
    enum(1, "Mute Line vs.", ("OFF", "vs. Phones", "Toggle Ph/Line", "Toggle plugged"), 1, DAC),
    enum(2, "Auto Standby", ("OFF", "30 min", "1 h", "2 h", "4 h")),
    boolean(3, "DSD Detection", 1),
    enum(4, "DSD Filter", ("50 kHz", "150 kHz")),
    boolean(5, "DSD Direct (Line)", devices=("dac", "pro")),
    enum(6, "Basic Mode", ("Auto", "AD/DA", "USB", "Preamp", "Dig Thru", "DAC"), devices=PRO),
    boolean(8, "Dual Phones", devices=PRO),
    enum(15, "Clock Source", ("Auto", "INT", "SPDIF coax", "Optical"), devices=DAC),
    enum(15, "Clock Source", ("Auto", "INT", "AES", "SPDIF"), devices=PRO),
    enum(25, "Remap Keys", ("OFF", "ON", "IR Remote"), 2),
    Param(16, "Sample Rate (display)", "enum", 0, 9, 1, 1, "",
          ("44.1 k", "48 k", "88.2 k", "96 k", "176.4 k", "192 k", "352.8 k", "384 k", "705.6 k", "768 k")),
    enum(32, "Display Mode", ("Default", "Dark")),
    enum(33, "Meter Color", ("Green", "Cyan", "Amber", "Monochrome", "Red", "Orange")),
    enum(34, "Horizontal Meter", ("Post-FX", "Pre-FX", "Dual", "Post-FX dBu")),
    boolean(35, "AutoDark Mode"),
    boolean(36, "Show Volume Screen", 1),
    enum(37, "Lock UI", ("OFF", "Remote", "Keys", "Keys + Remote")),
    boolean(62, "Load Volume"),
]
REMAP_KEY_PARAMS = [enum(i, name, REMAP_DAC, devices=DAC)
                    for i, name in ((26, "Key VOL (1)"), (27, "Key I/O (2)"),
                                    (28, "Key EQ (3)"), (29, "Key SETUP (4)"))]


def for_device(params, device: str):
    return [p for p in params if device in p.devices]


def freq_index_map():
    """address -> EQ frequency indices, for protocol.parse_params."""
    addrs = (1, 2, 4, 5, 7, 8, 10, 11, 13, 14)
    return {a: set(EQ_FREQ_INDEX) for a in addrs}
