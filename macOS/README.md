# ADI-2 Companion for macOS

A native SwiftUI controller and offline EQ editor for RME ADI-2 DAC, ADI-2 Pro,
and ADI-2/4 Pro hardware. The Mac app uses CoreMIDI and the same published RME
SysEx protocol as this repository's Linux app. It has no GTK, Python, ALSA,
network service, driver installer, or administrator requirement.

This is independent software, not affiliated with or endorsed by RME.

## Current scope

- Five-band EQ with a combined response curve, numeric controls,
  and per-output draft editing.
- Explicit connection and state synchronization through USB MIDI. Hardware
  writes stay disabled until a compatible device returns its EQ state.
- Apply a reviewed EQ draft to both channels of the selected output.
- Parameter controls for output, device, and supported analog input settings,
  including channel EQ/tone parameters. These controls write immediately when
  connected; the separate EQ band editor uses the explicit Apply action.
- Import Equalizer APO/REW filter text, CSV filter data, and compatible JSON.
  Import warnings describe adjustments to the hardware's five-band limits.
- Export a local JSON EQ profile through the macOS file picker.
- Save and load profiles in a local library inside the app's sandbox.
- Recall and save the ADI-2's 20 EQ memory slots and its 9 device setups, with
  confirmation before every hardware memory recall or save. These operations
  follow the protocol and still require Mac hardware testing.
- A clearly marked demo mode that sends no MIDI, including the DT 1990
  reference profile carried over from the Linux version.

The macOS app does not apply the Linux PipeWire configuration, manage macOS
audio routing, or change the system sample rate. No audio is captured or
processed by this app; the ADI-2 performs its DSP.

## Requirements and connection

- macOS 14 or later.
- An ADI-2 with firmware supporting RME's MIDI control protocol, connected by USB.
- Enable **MIDI Control** on the hardware. RME's current Remote manual names
  **Remap Keys/Diag** for the DAC and **Device Mode** for Pro/2/4 models;
  menu wording can vary with firmware.

Choose the device in the sidebar, then click **Connect**. The app reads its
current state before enabling writes. **Sync** reads settings again after a
front-panel change. Disconnecting does not reset the hardware. Closing the app
leaves the ADI-2's settings in place.

EQ imports create drafts. Review the curve, band values, and import warnings,
then choose **Apply EQ to Both Channels**. Imported preamp gain has no direct
ADI-2 equivalent; heed the reported warning and adjust output volume separately.
Use an appropriate listening level before changing gain or output settings.

Without hardware, choose **Explore demo**, or import and edit a profile offline.
Leaving demo clears simulated settings. Demo is not a hardware validation.

## Local profiles and hardware memory

Open **Profiles and device memory** in the sidebar. Local profiles belong to
this Mac app's sandboxed Application Support library (`ADI2Companion/Profiles`).
Loading a local profile creates an EQ draft; it does not send MIDI. Use Export
to save a copy outside the library or share it with another machine. Library
profiles remain in the app's sandbox until its app data is removed. Exported
copies and hardware settings are independent of that app data.

Hardware memory is separate from local profiles. The ADI-2 has 20 EQ memory
slots and 9 device setup slots. Recalling an EQ slot changes the selected
output's active hardware EQ and replaces the editor draft; it is not an offline
draft load. Review the selected slot and confirmation before each hardware
memory operation. Recalling a setup may change volume, routing, and other
device-wide settings, and replaces the editor state. Saving a device setup uses
the hardware's current settings, excluding unapplied drafts. Saving an EQ memory
slot stores the five filter bands only;
the Bass/Treble and Loudness switches are not part of that memory write. Applying
the current EQ draft to an output remains a separate action.

These hardware memory features are implemented from RME's published protocol
and covered by software tests. Real readback, persistent-slot behavior, and
setup recall/save from this Mac build are not yet hardware-qualified.

## Build a local development app

The command-line build needs Apple's Swift toolchain and macOS SDK, available
through Xcode or the Command Line Tools. The XCTest suite additionally needs
full Xcode. From this directory:

```sh
swift test                 # requires full Xcode's XCTest framework
./scripts/build-app.sh
open "build/ADI-2 Companion.app"
```

With Command Line Tools alone, run `./scripts/test-cli.sh`. It compiles the core
and connection-state test bodies with standalone assertion runners when XCTest
is unavailable. On a toolchain exposing XCTest, it uses `swift test` instead.
These tests use fake MIDI and do not verify physical device communication.

Current software validation passes 50 cases with 323 assertions: 33 core cases
with 205 assertions and 17 app-model cases with 118 assertions. A sandboxed
universal app builds for Apple silicon and Intel.

The native sandboxed app has been tested with a physical **ADI-2 DAC on Apple
silicon, macOS 27.2**. USB MIDI discovery, a complete 219-parameter settings
read, and a GUI Phones volume reduction of 0.1 dB followed by restoration all
passed, with a fresh hardware Sync confirming each volume step.

This qualifies those basic DAC workflows. Pro/2/4 models, unplug/replug, EQ Apply
readback, EQ/setup memory recall/save, Intel runtime behavior, full Xcode
archiving, and Apple distribution signing remain unverified.

To open the demo directly:

```sh
open "build/ADI-2 Companion.app" --args --demo
```

The script builds a release executable, creates a self-contained app bundle,
copies the icon, license, and privacy manifest, then signs it ad hoc with App
Sandbox enabled. It checks the signature, required bundle files, entitlements,
and quarantine attributes. This is a development app for this Mac, not an Apple
distribution-signed or notarized release.

To build both Apple silicon and Intel slices:

```sh
./scripts/build-app.sh --universal
```

To choose an output directory:

```sh
./scripts/build-app.sh --output /absolute/path/to/output
```

## Xcode and App Store preparation

Open `ADI2Companion.xcodeproj` in full Xcode. The shared **ADI2Companion** scheme
builds the SwiftUI app and the local Swift package's `ADI2Core` library. The
project has an app icon, privacy manifest, bundle identifier, version/build
number, and sandbox entitlements checked in; it needs no project generator.

Select your Apple Developer team in Signing & Capabilities. Confirm that the
bundle identifier `tech.norvi.ADI2Companion` is available for that team before
registering it. Use Product → Archive, validate the archive, and distribute via
TestFlight & App Store. An Apple account, signing assets, App Store Connect
record, and complete review metadata are required.

See [App Store preparation](APP_STORE.md) for the remaining release work and
current Apple source links. Full Xcode archiving and distribution signing still
need verification. The DAC checks above do not establish Pro/2/4 compatibility
or qualify the remaining EQ and persistent-memory workflows.

## Protocol reference

The authoritative reference is RME's
[MIDI protocol download](https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip),
linked from its [ADI-2 Remote manual](https://rme-audio.de/downloads/adi2remote_e.pdf).
The archive contains `MIDITable_ADI-2_261030.ods`, version 1.2, dated
October 30, 2026; its stated firmware bases are Pro 130, DAC 62, 2/4 SE 43,
and 2/4 EX 106.

In the `Channels` sheet, EQ Enable (index 2, row 80), Bass/Treble (indices
20–26, rows 99–106), and preset behavior (indices 27–28, rows 107–110) are shared
controls on the documented left EQ addresses. Bilateral band controls use
indices 3–19. The official examples and the live DAC settings dump also report
index 2 on right EQ addresses; the app accepts that incoming state without
requiring it or sending a right-side enable/tone/preset write. Shared switches
are written once at their documented left address.

## Source layout

| Path | Purpose |
| --- | --- |
| `Sources/ADI2Core` | SysEx protocol, parameter registry, profiles, imports, EQ response |
| `Sources/ADI2Mac` | SwiftUI app, local CoreMIDI transport, file pickers |
| `Tests` | Protocol, import, library, and fake-MIDI connection-state tests |
| `Resources` | App metadata, sandbox entitlements, privacy manifest, original icon |
| `scripts` | Development bundle build, verification, icon rendering |

To regenerate the original icon artwork:

```sh
swift scripts/render-icon.swift
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
```

## Privacy, support, and credits

The app has no network entitlement, accounts, advertising, or telemetry.
Profile files are opened or saved only at locations you choose. See the
[privacy policy](PRIVACY.md). Report reproducible problems through this
repository's [issue tracker](https://github.com/spencernorton/rme-adi2-linux/issues),
including macOS version, Mac architecture, ADI-2 model/firmware, and steps.
Do not include personal files or sensitive diagnostic data.

Code is MIT licensed; the bundled license preserves the copyright notice.
RME's published MIDITable is the protocol reference. The DT 1990 Pro analytic-pad
reference derives from the Linux app's oratory1990/AutoEq profile. All product
names identify compatible hardware and remain their owners' property.
