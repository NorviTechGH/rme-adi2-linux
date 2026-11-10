import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / "src"))
from adi2 import protocol as p  # noqa: E402
from adi2.eq import dt1990_profile, EqProfile  # noqa: E402
from adi2.params import freq_index_map  # noqa: E402


def test_dt1990_roundtrip_through_wire_format():
    profile = dt1990_profile()
    msg = profile.message(0x71)
    parsed = p.parse_message(msg)
    assert parsed and parsed[0] == 0x71 and parsed[1] == p.CMD_TO_DEVICE
    state = {(a, i): v for a, i, v in p.parse_params(parsed[2], freq_index_map())}
    left = p.OUTPUTS["phones"]["eq_left"]
    assert state[(left, 2)] == 1          # EQ Enable on
    assert state[(left, 20)] == 0         # Bass/Treble off
    assert state[(6, 20)] == 0            # Loudness off (Phones channel)
    expect = [(1, 6.5, 105, 0.7), (0, -2.0, 150, 0.5), (0, 4.5, 4200, 3.5),
              (0, -3.0, 7400, 3.4), (1, -7.5, 10000, 0.7)]
    gain_i, freq_i, q_i = (4, 7, 10, 13, 17), (5, 8, 11, 14, 18), (6, 9, 12, 15, 19)
    for n, (_, gain, freq, q) in enumerate(expect):
        assert state[(left, gain_i[n])] * 0.5 == gain
        assert state[(left, freq_i[n])] == freq
        assert round(state[(left, q_i[n])] * 0.1, 6) == q
    assert state[(left, 3)] == 1 and state[(left, 16)] == 1  # both Shelf


def test_profile_json_roundtrip(tmp_path=None):
    profile = dt1990_profile()
    clone = EqProfile.from_dict(__import__("json").loads(profile.to_json()))
    assert clone == profile


def test_invalid_band_rejected():
    profile = dt1990_profile()
    profile.bands[0].gain_db = 99.0
    try:
        profile.containers()
    except ValueError:
        return
    raise AssertionError("out-of-range gain was not rejected")


if __name__ == "__main__":
    test_dt1990_roundtrip_through_wire_format()
    test_profile_json_roundtrip()
    test_invalid_band_rejected()
    print("ok eq")
