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
