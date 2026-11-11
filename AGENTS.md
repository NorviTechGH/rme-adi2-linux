# ADI-2 Control

Independent control software and EQ tools for RME ADI-2 hardware.
The Linux app is in `src/adi2`; the native macOS app is in `macOS`.

- Linux tests: `python3 -m pytest tests -q`.
- macOS tests: `cd macOS && swift test` (full Xcode selected).
- macOS development bundle: `macOS/scripts/build-app.sh`.
- Read `macOS/APP_STORE.md` before preparing a store release.
- Preserve byte-level protocol compatibility and the shared JSON profile format.
- Keep demo/offline editing separate from physical device writes.
- Public contribution branches use descriptive topic names.
- Append session outcomes at the top of `AGENTS/journal.md`.
