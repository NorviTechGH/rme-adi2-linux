"""Import EQ settings from the formats people already have.

Supported:
- Equalizer APO / Peace filter text (also REW's generic EQ export and
  Squiglink/AutoEq "ParametricEQ.txt"): `Filter 1: ON PK Fc 105 Hz
  Gain 6.5 dB Q 0.70`, with Preamp lines noted.
- CSV with a header naming frequency/gain (aliases recognised), or
  plain `freq,gain,q[,type]` rows.
- JSON: this app's profile format, and AutoEq-style objects with a
  `filters`/`eq` list of {type, frequency/fc, gain, q/bandwidth}.

Everything is funnelled into an ADI-2 EqProfile: five bands, shelves at
the ends. Reductions and clamps are reported in ImportResult.warnings —
nothing is silently dropped.
"""
from __future__ import annotations
import csv
import io
import json
import re
from dataclasses import dataclass, field

from .eq import Band, EqProfile
from .params import BAND_TYPES_1, BAND_TYPES_5

APO_TYPES = {
    "PK": "Peak", "PEQ": "Peak", "PEAKING": "Peak", "MODAL": "Peak", "PEAK": "Peak",
    "LS": "Shelf", "LSC": "Shelf", "LOW_SHELF": "Shelf", "LOWSHELF": "Shelf", "SHELF": "Shelf",
    "HS": "Shelf", "HSC": "Shelf", "HIGH_SHELF": "Shelf", "HIGHSHELF": "Shelf",
    "HP": "High Pass", "HPF": "High Pass", "HIGHPASS": "High Pass", "HPQ": "High Pass", "HIGH PASS": "High Pass",
    "LP": "High Cut", "LPF": "High Cut", "HIGHCUT": "High Cut", "LOWPASS": "High Cut", "LPQ": "High Cut", "HIGH CUT": "High Cut",
}
FREQ_MIN = (20, 20, 20, 200, 200)  # device table, per band
FREQ_MAX = 20000


@dataclass
class ImportResult:
    profile: EqProfile
    warnings: list = field(default_factory=list)
    preamp_db: float | None = None


def _reduce(bands: list[Band], warnings: list) -> list[Band]:
    """Fit an arbitrary filter list into the ADI-2's five bands."""
    shelves_lo = [b for b in bands if b.type == "Shelf" and b.freq_hz <= 500]
    shelves_hi = [b for b in bands if b.type == "Shelf" and b.freq_hz > 500]
    hp_list = [b for b in bands if b.type == "High Pass"]
    hc_list = [b for b in bands if b.type == "High Cut"]
    peaks = [b for b in bands if b.type == "Peak"]
    chosen: list[Band] = []
    if shelves_lo:
        chosen.append(shelves_lo[0])
        for extra in shelves_lo[1:]:
            warnings.append(f"converted extra low shelf at {extra.freq_hz:.0f} Hz to Peak")
            peaks.append(Band("Peak", extra.gain_db, extra.freq_hz, extra.q))
        for hp in hp_list:
            warnings.append(f"dropped High Pass at {hp.freq_hz:.0f} Hz (band 1 used by low shelf)")
    elif hp_list:
        chosen.append(hp_list[0])
        for hp in hp_list[1:]:
            warnings.append(f"dropped extra High Pass at {hp.freq_hz:.0f} Hz")
    top_band: Band | None = None
    if shelves_hi:
        top_band = shelves_hi[-1]
        for extra in shelves_hi[:-1]:
            warnings.append(f"converted extra high shelf at {extra.freq_hz:.0f} Hz to Peak")
            peaks.append(Band("Peak", extra.gain_db, extra.freq_hz, extra.q))
        for hc in hc_list:
            warnings.append(f"dropped High Cut at {hc.freq_hz:.0f} Hz (band 5 used by high shelf)")
    elif hc_list:
        top_band = hc_list[-1]
        for hc in hc_list[:-1]:
            warnings.append(f"dropped extra High Cut at {hc.freq_hz:.0f} Hz")
    peaks = sorted(peaks, key=lambda b: b.freq_hz)
    slots = 5 - len(chosen) - (1 if top_band is not None else 0)
    if len(peaks) > slots:
        keep_ids = {id(b) for b in sorted(peaks, key=lambda b: -abs(b.gain_db))[:slots]}
        keep = [b for b in peaks if id(b) in keep_ids]
        dropped = [b for b in peaks if id(b) not in keep_ids]
        warnings.append(f"dropped {len(dropped)} weakest peak(s): " +
                        ", ".join(f"{b.freq_hz:.0f} Hz" for b in dropped))
        peaks = sorted(keep, key=lambda b: b.freq_hz)
    chosen += peaks
    if top_band is not None:
        chosen.append(top_band)
    while len(chosen) < 5:
        pad = Band("Peak", 0.0, 1000.0, 1.0)
        if chosen and chosen[-1].type in ("Shelf", "High Cut"):
            chosen.insert(len(chosen) - 1, pad)  # keep the top shelf last
        else:
            chosen.append(pad)
    chosen = chosen[:5]
    # Shelves/passes only make sense at the ends on this hardware.
    if chosen[0].type == "Shelf" and chosen[0].freq_hz > 500:
        warnings.append(f"band 1: shelf at {chosen[0].freq_hz:.0f} Hz converted to Peak")
        chosen[0].type = "Peak"
    if chosen[4].type == "Shelf" and chosen[4].freq_hz <= 500:
        warnings.append(f"band 5: shelf at {chosen[4].freq_hz:.0f} Hz converted to Peak")
        chosen[4].type = "Peak"
    return chosen


def _finish(name: str, bands: list[Band], output: str,
            warnings: list, preamp_db=None) -> ImportResult:
    bands = _reduce(bands, warnings)
    for i, band in enumerate(bands):
        if band.gain_db > 12 or band.gain_db < -12:
            warnings.append(f"band {i + 1}: gain {band.gain_db} dB clamped to ±12")
            band.gain_db = max(-12.0, min(12.0, band.gain_db))
        if band.freq_hz < FREQ_MIN[i]:
            warnings.append(f"band {i + 1}: frequency raised to {FREQ_MIN[i]} Hz (device minimum)")
            band.freq_hz = float(FREQ_MIN[i])
        elif band.freq_hz > FREQ_MAX:
            warnings.append(f"band {i + 1}: frequency clamped to {FREQ_MAX} Hz (device maximum)")
            band.freq_hz = float(FREQ_MAX)
        qmax = 5.0 if i >= 3 else 9.9
        qval = band.q if band.q else 1.0
        if qval < 0.5 or qval > qmax:
            warnings.append(f"band {i + 1}: Q {band.q} clamped to 0.5..{qmax}")
        band.q = max(0.5, min(qmax, qval))
        allowed = BAND_TYPES_1 if i == 0 else BAND_TYPES_5 if i == 4 else ("Peak",)
        if band.type not in allowed:
            warnings.append(f"band {i + 1}: type {band.type} converted to Peak")
            band.type = "Peak"
    profile = EqProfile(name=name or "Imported EQ", output=output, bands=bands)
    profile.validate()
    if preamp_db:
        warnings.append(f"preamp {preamp_db:+.1f} dB has no ADI-2 equivalent "
                        "— lower the output volume by that amount instead")
    return ImportResult(profile, warnings, preamp_db)


_APO_FILTER = re.compile(
    r"Filter\s*\d*\s*:\s*ON\s+([A-Z_]+)\s+Fc\s+([\d.]+)\s*Hz\s+"
    r"Gain\s+(-?[\d.]+)\s*dB(?:\s+Q\s+([\d.]+))?", re.I)
_APO_PREAMP = re.compile(r"Preamp\s*:\s*(-?[\d.]+)\s*dB", re.I)
_REW_FILTER = re.compile(
    r"Filter\s*\d+\s*:\s*ON\s+([A-Z]+)\s+Fc\s+([\d.]+)\s*Hz\s+"
    r"Gain\s+(-?[\d.]+)\s*dB\s+Q\s+([\d.]+)", re.I)


def parse_apo_text(text: str, name: str, output: str) -> ImportResult:
    warnings, bands = [], []
    preamp = None
    if m := _APO_PREAMP.search(text):
        preamp = float(m.group(1))
    matches = list(_APO_FILTER.finditer(text)) or list(_REW_FILTER.finditer(text))
    for m in matches:
        kind = APO_TYPES.get(m.group(1).upper())
        if kind is None:
            warnings.append(f"skipped unsupported filter type {m.group(1)}")
            continue
        bands.append(Band(kind, float(m.group(3)), float(m.group(2)),
                          float(m.group(4) or 1.0)))
    if not bands:
        raise ValueError("no Equalizer APO / REW filters found")
    return _finish(name, bands, output, warnings, preamp)


_ALIASES = {"frequency": "freq", "fc": "freq", "hz": "freq", "freq_hz": "freq",
            "gain_db": "gain", "db": "gain", "bandwidth": "q", "type": "type",
            "filter_type": "type", "filter": "type"}


def parse_csv(text: str, name: str, output: str) -> ImportResult:
    rows = [r for r in csv.reader(io.StringIO(text))
            if r and any(c.strip() for c in r) and not r[0].strip().startswith("#")]
    if not rows:
        raise ValueError("empty CSV")
    header = [(_ALIASES.get(c.strip().lower(), c.strip().lower())) for c in rows[0]]
    has_header = "freq" in header and "gain" in header
    bands, warnings = [], []
    data_rows = rows[1:] if has_header else rows
    for idx, row in enumerate(data_rows, start=2 if has_header else 1):
        try:
            if has_header:
                d = dict(zip(header, row))
                freq, gain = float(d["freq"]), float(d["gain"])
                q = float(d.get("q") or 1.0)
                raw_type = str(d.get("type") or "PK").strip().upper()
            else:
                freq, gain = float(row[0]), float(row[1])
                q = float(row[2]) if len(row) > 2 and row[2].strip() else 1.0
                raw_type = row[3].strip().upper() if len(row) > 3 and row[3].strip() else "PK"
            kind = APO_TYPES.get(raw_type)
            if kind is None:
                warnings.append(f"row {idx}: unsupported filter type {raw_type!r}, using Peak")
                kind = "Peak"
        except (ValueError, KeyError, IndexError):
            warnings.append(f"skipped malformed CSV row {idx}")
            continue
        bands.append(Band(kind, gain, freq, q))
    if not bands:
        raise ValueError("no CSV EQ rows found (need frequency and gain columns)")
    return _finish(name, bands, output, warnings)


def parse_json(text: str, name: str, output: str) -> ImportResult:
    data = json.loads(text)
    if isinstance(data, dict) and "bands" in data:  # our own profile
        try:
            profile = EqProfile.from_dict(dict(data))
            profile.output = output
            return ImportResult(profile, [])
        except (ValueError, TypeError):
            pass  # fall through to generic filter reduction/clamping
    items = None
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        for key in ("filters", "eq", "bands", "filter"):
            if isinstance(data.get(key), list):
                items = data[key]
                break
    if items is None:
        raise ValueError("JSON has no filters/bands list")
    bands, warnings = [], []
    for idx, item in enumerate(items, 1):
        if not isinstance(item, dict):
            warnings.append(f"skipped non-object JSON filter entry #{idx}")
            continue
        raw_type = str(item.get("type", "PK")).strip().upper()
        kind = APO_TYPES.get(raw_type)
        if kind is None:
            if "SHELF" in raw_type:
                kind = "Shelf"
            else:
                warnings.append(f"filter #{idx}: unsupported type {raw_type!r}, using Peak")
                kind = "Peak"
        freq = item.get("frequency", item.get("fc", item.get("freq_hz")))
        gain = item.get("gain", item.get("gain_db", 0.0))
        q = item.get("q", item.get("bandwidth", 1.0))
        if freq is None:
            warnings.append(f"skipped JSON filter #{idx} with missing frequency")
            continue
        bands.append(Band(kind, float(gain), float(freq), float(q or 1.0)))
    if not bands:
        raise ValueError("no usable filters in JSON")
    if isinstance(data, dict) and data.get("name") and name in ("Imported EQ", ""):
        name = str(data["name"])
    return _finish(name, bands, output, warnings)


def import_eq_text(text: str, name: str = "Imported EQ",
                   output: str = "phones") -> ImportResult:
    """Detect the format and import. Raises ValueError with guidance."""
    stripped = text.strip()
    if not stripped:
        raise ValueError("empty EQ file — expected Equalizer APO/REW text, CSV, or JSON")
    if stripped.startswith("{") or stripped.startswith("["):
        try:
            return parse_json(stripped, name, output)
        except (json.JSONDecodeError, ValueError, TypeError) as exc:
            raise ValueError(f"invalid EQ JSON: {exc}") from exc
    if "filter" in stripped.lower() and "fc" in stripped.lower():
        try:
            return parse_apo_text(stripped, name, output)
        except ValueError:
            pass
    try:
        return parse_csv(stripped, name, output)
    except ValueError:
        pass
    return parse_apo_text(stripped, name, output)  # raises with its own message


def import_eq_file(path, output: str = "phones") -> ImportResult:
    from pathlib import Path
    p = Path(path)
    return import_eq_text(p.read_text(errors="replace"), p.stem, output)
