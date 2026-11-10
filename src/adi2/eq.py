"""EQ profile model and SysEx builder.

A profile is five parametric bands plus the per-output switches that
must not fight it (Bass/Treble and Loudness off). Bands are written to
both EQ channels of the chosen output with identical values, so the
result is correct with Dual EQ on or off.
"""
from __future__ import annotations
import json
from dataclasses import dataclass, field, asdict
from pathlib import Path

from . import protocol as proto
from .params import BAND_TYPES_1, BAND_TYPES_5

BAND_LAYOUT = [(3, 4, 5, 6), (None, 7, 8, 9), (None, 10, 11, 12),
               (None, 13, 14, 15), (16, 17, 18, 19)]


@dataclass
class Band:
    type: str = "Peak"
    gain_db: float = 0.0
    freq_hz: float = 1000.0
    q: float = 1.0

    def validate(self, band_no: int) -> None:
        types = BAND_TYPES_1 if band_no == 1 else BAND_TYPES_5 if band_no == 5 \
            else ("Peak",)
        if self.type not in types:
            raise ValueError(f"band {band_no}: type {self.type!r} not in {types}")
        if not -12.0 <= self.gain_db <= 12.0:
            raise ValueError(f"band {band_no}: gain outside -12..+12 dB")
        if not 20 <= self.freq_hz <= 20000:
            raise ValueError(f"band {band_no}: frequency outside 20..20000 Hz")
        qmax = 5.0 if band_no >= 4 else 9.9
        if not 0.5 <= self.q <= qmax:
            raise ValueError(f"band {band_no}: Q outside 0.5..{qmax}")


@dataclass
class EqProfile:
    name: str = "Untitled"
    output: str = "phones"           # line | phones | phones34
    bands: list = field(default_factory=lambda: [Band() for _ in range(5)])
    eq_enable: bool = True
    bass_treble_enable: bool = False
    loudness_enable: bool = False

    def validate(self) -> None:
        if self.output not in proto.OUTPUTS:
            raise ValueError(f"unknown output {self.output!r}")
        if len(self.bands) != 5:
            raise ValueError("an ADI-2 EQ profile has exactly 5 bands")
        for i, band in enumerate(self.bands, 1):
            band.validate(i)

    def containers(self) -> list:
        self.validate()
        out = proto.OUTPUTS[self.output]
        left, right, channel = out["eq_left"], out["eq_right"], out["channel"]
        boxes = [proto.encode_param(left, 2, 1 if self.eq_enable else 0),
                 proto.encode_param(left, 20, 1 if self.bass_treble_enable else 0),
                 proto.encode_param(channel, 20, 1 if self.loudness_enable else 0)]
        for addr in (left, right):
            for band, (t_idx, g_idx, f_idx, q_idx) in zip(self.bands, BAND_LAYOUT):
                if t_idx is not None:
                    types = BAND_TYPES_1 if t_idx == 3 else BAND_TYPES_5
                    boxes.append(proto.encode_param(addr, t_idx, types.index(band.type)))
                boxes.append(proto.encode_param(addr, g_idx, int(round(band.gain_db / 0.5))))
                boxes.append(proto.encode_freq(addr, f_idx, band.freq_hz))
                boxes.append(proto.encode_param(addr, q_idx, int(round(band.q / 0.1))))
        return boxes

    def message(self, device_id: int = 0x71) -> bytes:
        return proto.params_message(device_id, self.containers())

    def to_json(self) -> str:
        return json.dumps(asdict(self), indent=2) + "\n"

    @classmethod
    def from_dict(cls, data: dict) -> "EqProfile":
        copy = dict(data)
        bands = [Band(**b) for b in copy.pop("bands")]
        profile = cls(bands=bands, **copy)
        profile.validate()
        return profile

    @classmethod
    def load(cls, path) -> "EqProfile":
        return cls.from_dict(json.loads(Path(path).read_text()))

    def save(self, path) -> None:
        Path(path).write_text(self.to_json())


def dt1990_profile() -> EqProfile:
    """Beyerdynamic DT 1990 Pro (analytic pads), reduced from the
    oratory1990 10-band AutoEq preset to the ADI-2's five bands.
    Deployed and verified on the Phones output 2026-05-22."""
    return EqProfile(
        name="DT 1990 Pro (analytic) — studio reference",
        output="phones",
        bands=[Band("Shelf", 6.5, 105, 0.70), Band("Peak", -2.0, 150, 0.50),
               Band("Peak", 4.5, 4200, 3.5), Band("Peak", -3.0, 7400, 3.4),
               Band("Shelf", -7.5, 10000, 0.70)])
