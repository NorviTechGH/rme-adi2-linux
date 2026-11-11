# macOS hardware qualification

## 2026-11-11 — ADI-2 DAC, basic sandbox communication

Test environment: Apple silicon Mac, macOS 27.2, ADI-2 DAC USB MIDI Port 1,
ADI-2 Companion 1.0.0 development build. The app was ad-hoc signed with only
App Sandbox and user-selected file read/write entitlements.

Verified:

- The physical DAC is discovered and its input/output endpoints are paired.
- A bounded read-only CoreMIDI probe receives 219 parameters without malformed
  SysEx frames. The sandboxed app connects and displays live EQ and output state.
- The app changes Phones volume down by 0.1 dB, synchronizes from the device,
  restores the initial value, and synchronizes again. Both hardware readbacks
  match the intended values. No preset or setup slot was written.

The first physical test exposed a sync bug: readiness incorrectly required a
right-side Bass/Treble switch that the device does not report. RME's official
MIDITable v1.2 documents EQ enable, Bass/Treble and preset selection on left EQ
addresses. The corrected app reads shared flags there, offers right-side band
controls only, and keeps complete left/right band validation before writes.
The firmware may report right-side EQ enable; this optional data does not
expand the documented write contract.

Primary reference: [RME protocol download](https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip),
`MIDITable_ADI-2_261030.ods`, `Channels!A80:G80`, `G99`, `A100:B106`,
`G107`, `A108:H110`. See the [Remote manual, page 3](https://rme-audio.de/downloads/adi2remote_e.pdf)
for the official protocol link. Synthetic regression tests preserve this
reported field shape without storing a real device's serial or personal EQ.

## Remaining acceptance

This is a basic communication result for one DAC and one Mac/OS combination.
It does not establish Pro/2/4 Pro support, Intel runtime compatibility, other
macOS releases, physical unplug/replug or power-cycle recovery, EQ Apply
readback, or persistent preset/setup memory writes. These still need tests on
the final signed build. Do not overwrite a user's saved memory slots as a test.

Full Xcode archive/XCTest validation, Apple distribution signing, App Store
Connect metadata and Apple's hardware demonstration video also remain open.
The development host currently has Command Line Tools and no signing identity.
