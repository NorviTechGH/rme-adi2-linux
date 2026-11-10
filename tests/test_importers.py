import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / "src"))
from adi2.importers import import_eq_text  # noqa: E402

APO = """Preamp: -6.5 dB
Filter 1: ON LSC Fc 105 Hz Gain 6.5 dB Q 0.70
Filter 2: ON PK Fc 150 Hz Gain -2.0 dB Q 0.50
Filter 3: ON PK Fc 4200 Hz Gain 4.5 dB Q 3.50
Filter 4: ON PK Fc 7400 Hz Gain -3.0 dB Q 3.40
Filter 5: ON HSC Fc 10000 Hz Gain -7.5 dB Q 0.70
"""

AUTOEQ_10 = """Preamp: -3.0 dB
""" + "\n".join(
    f"Filter {i}: ON PK Fc {f} Hz Gain {g} dB Q {q}"
    for i, (f, g, q) in enumerate(
        [(60, 2, 1), (120, 1, 1), (300, -1, 2), (800, 0.5, 2), (1500, -4, 3),
         (2500, 2, 2), (4000, 5, 4), (6000, -2, 5), (9000, 1, 2), (12000, -1, 1)], 1))

CSV = """frequency,gain_db,q,type
105,6.5,0.7,LS
4200,4.5,3.5,PK
10000,-7.5,0.7,HS
"""

JSON_AUTOEQ = """{"name": "Test", "filters": [
  {"type": "LOW_SHELF", "frequency": 105, "gain": 6.5, "q": 0.7},
  {"type": "PEAKING", "frequency": 4200, "gain": 4.5, "q": 3.5},
  {"type": "HIGH_SHELF", "frequency": 10000, "gain": -7.5, "q": 0.7}]}"""


def test_apo_dt1990_matches_known_profile():
    result = import_eq_text(APO, output="phones")
    got = [(b.type, b.gain_db, b.freq_hz, b.q) for b in result.profile.bands]
    assert got == [("Shelf", 6.5, 105.0, 0.7), ("Peak", -2.0, 150.0, 0.5),
                   ("Peak", 4.5, 4200.0, 3.5), ("Peak", -3.0, 7400.0, 3.4),
                   ("Shelf", -7.5, 10000.0, 0.7)]
    assert result.preamp_db == -6.5 and any("preamp" in w for w in result.warnings)


def test_ten_band_reduction_keeps_strongest_and_warns():
    result = import_eq_text(AUTOEQ_10)
    assert len(result.profile.bands) == 5
    gains = [b.gain_db for b in result.profile.bands]
    assert 5.0 in gains and -4.0 in gains  # strongest survive
    assert any("dropped" in w for w in result.warnings)


def test_csv_import():
    result = import_eq_text(CSV)
    assert result.profile.bands[0].type == "Shelf"
    assert result.profile.bands[4].freq_hz == 10000.0


def test_json_autoeq_import():
    result = import_eq_text(JSON_AUTOEQ)
    assert result.profile.name == "Test"
    assert result.profile.bands[1].gain_db == 4.5


def test_own_profile_json_roundtrip():
    from adi2.eq import dt1990_profile
    result = import_eq_text(dt1990_profile().to_json(), output="line")
    assert result.profile.output == "line"
    assert result.profile.bands[0].gain_db == 6.5


def test_garbage_rejected():
    for bad in ("not an eq file at all", "", '{"filters": []}', "{broken json"):
        try:
            import_eq_text(bad)
        except ValueError:
            continue
        raise AssertionError(f"garbage {bad!r} was not rejected")


def test_clamping_and_extra_shelves_reported():
    text = "\n".join([
        "Filter 1: ON LSC Fc 10 Hz Gain 15.0 dB Q 0.20",
        "Filter 2: ON LSC Fc 80 Hz Gain 3.0 dB Q 0.70",
        "Filter 3: ON PK Fc 24000 Hz Gain -14.0 dB Q 12.0",
    ])
    res = import_eq_text(text)
    assert res.profile.bands[0].freq_hz == 20.0
    assert res.profile.bands[0].gain_db == 12.0
    assert res.profile.bands[0].q == 0.5
    assert any("converted extra low shelf" in w for w in res.warnings)
    assert any("20000 Hz" in w for w in res.warnings)
    assert any("clamped to 0.5.." in w for w in res.warnings)
