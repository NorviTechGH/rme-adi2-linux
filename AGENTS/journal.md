## 2026-11-10 — Profile library and device memory parity

- Added sandbox-local profile Save/Load, 20 EQ preset slots and nine device
  setups, preserving explicit draft Apply and confirming live recall/overwrite.
- Device preset storage uses the Linux app's exact five-band staging/commit/name
  frames; Bass/Treble and Loudness remain separate from device slot writes.
- Validation: 30 core cases/143 assertions and 16 fake-MIDI app cases/106
  assertions pass. Universal build and sandbox signature checks pass. Native
  profile Save/Load and simulated preset/setup save/recall confirmations were
  exercised. Physical hardware memory writes remain unverified.
- Fixed a duplicate destination label and shortened the sidebar label after
  reviewing the native screen. No Linux runtime or production deployment change.
- Release next step: qualify the signed sandbox on physical ADI-2 hardware and
  validate the full Xcode archive with genuine Apple signing credentials.

## 2026-11-10 — Native macOS application

- Added ADI-2 Companion alongside the Linux app: SwiftUI, CoreMIDI, EQ drafting,
  independent channel parameters, portable imports/exports and offline demo.
- Added strict fresh-state synchronization, device pairing and callback session
  guards, input validation and injectable MIDI transport for regression tests.
- Added an Xcode project, original icon, minimal sandbox entitlements, privacy
  material, universal development bundle scripts and macOS/Linux CI.
- Validation: 25 protocol/core cases (108 assertions), 11 fake-MIDI app cases
  (70 assertions), and 19 Linux tests pass; GTK module skipped on macOS.
  Both arm64 and x86_64 release slices compile and pass bundle/signature checks.
  Native sandbox UI editing, Apply in demo, export/import and disconnected
  controls verified. A native exported profile loads through the Linux model.
- Release: development only. Real DAC sandbox qualification, full Xcode archive,
  Apple distribution signing and hardware camera review video remain required.
- Next: run native CI and qualify the final signed app with physical hardware.
