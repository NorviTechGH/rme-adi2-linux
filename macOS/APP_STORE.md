# Mac App Store preparation

ADI-2 Companion has a native macOS implementation and checked-in app packaging.
It is not yet a validated App Store submission. This document separates the
prepared material from evidence and account work still required.

## Prepared in source

- SwiftUI app using public CoreMIDI, AppKit, and Foundation APIs; macOS 14+.
- Xcode app target and shared Archive scheme, with local `ADI2Core` package.
- Original app icon, bundle metadata, Music category, version 1.0.0 / build 1.
- `com.apple.security.app-sandbox` and user-selected file read/write only.
- Bundled `PrivacyInfo.xcprivacy` declaring no tracking or collected data.
- In-app privacy explanation and links to setup/support and privacy policy.
- Offline EQ editing and explicit demo mode for exploration without hardware.
- A sandboxed local profile library, plus file-picker import/export.
- Protocol-backed access to 20 hardware EQ slots and 9 device setups, with
  confirmation for every recall/save; these paths remain hardware-unqualified.
- A CLI script that produces an ad-hoc-signed sandboxed development app.

The development bundle is not an `.xcarchive`, App Store signed build, installer
package, notarized distribution, or proof of Apple review acceptance.

## Current qualification

- **Software:** 50 cases and 323 assertions pass (core: 33/205; app model:
  17/118). A sandboxed universal development app builds for Apple silicon and
  Intel.
- **Physical ADI-2 DAC, Apple silicon, macOS 27.2:** The native sandboxed app
  discovers the device and reads its complete 219-parameter settings state.
  A GUI Phones volume reduction of 0.1 dB and restoration passed, with fresh
  Sync readback confirming each step.
- **Remaining scope:** Pro/2/4 hardware, unplug/replug, EQ Apply readback,
  EQ/setup memory recall/save, and Intel runtime behavior remain
  unverified. Full Xcode archive validation and Apple distribution signing
  remain open too.

The basic DAC evidence above does not qualify every advertised control or the
other device models. Store submission still depends on the release gates below.

## Release gates still open

1. **Complete hardware qualification:** Extend the basic DAC checks above to
   every advertised workflow and ADI-2 model/firmware. Check input/output
   pairing, EQ writes and readback, other parameter edits, hardware EQ slot
   recall/save/names, setup recall/save, unplug/replug, device power cycling,
   and coexistence with other MIDI apps. Record model, firmware,
   Mac architecture, OS version, app revision, and observed results. Until
   then, describe the untested models and workflows as implementation targets,
   not validated support.
2. **Full Xcode validation:** Open the project, resolve its local package, build
   both architectures, archive, validate, and test the final signed build on the
   current macOS release. The initial development host has Command Line Tools
   but no full Xcode, so the checked-in project has not been archived there.
3. **Apple account and signing:** Enroll/use the intended Apple Developer team,
   confirm the bundle ID, configure signing/provisioning, and create the macOS
   App Store Connect record. The development host initially has no valid signing
   identities. Use the team's genuine distribution assets.
4. **Hardware review video:** Film a physical Mac running the app as it connects
   to and interacts with a physical ADI-2. Apple specifies a video, not a screen
   recording. Attach it in review information with hardware requirements and
   exact setup steps. Demo mode does not replace this hardware evidence.
5. **Product and rights review:** Confirm final name, seller/developer identity,
   pricing, territories, support arrangements, and permission for any third-party
   protected material. The current icon is original and the app is explicitly
   independent. Do not use RME's logo or imply an official relationship.
6. **Final metadata:** Review the draft below, supply screenshots, finish current
   age-rating/privacy/export-compliance questions and applicable trader/account
   information, verify live URLs at the released revision, and beta test the
   final build. Do not submit while those fields or evidence are incomplete.

Track these gates durably in the project tracker; update this file with actual
test results rather than turning planned checks into claimed validation.

## Build and archive

With full Xcode selected, run core XCTest tests using `swift test` from this
directory. Command Line Tools alone do not include the required XCTest framework;
`./scripts/test-cli.sh` runs the same test bodies through standalone assertion
harnesses in that environment. The tests use fake MIDI rather than hardware. Use
`./scripts/build-app.sh --universal` to exercise a local universal development
bundle. Its verification script checks bundle files and sandbox signing; that
does not replace Xcode validation or hardware testing.

For the store build, open `ADI2Companion.xcodeproj`, choose your team, and choose
the shared **ADI2Companion** scheme with a Mac destination. Product → Archive
creates the archive. Organizer → Validate App performs Apple's initial checks;
then Distribute App → TestFlight & App Store handles distribution signing and
upload. Set version, build number, and bundle identifier in
`Resources/App.xcconfig`; both the Xcode target and development-bundle script
read that configuration. Use a new build number for each new upload.

Verify the final bundle with `scripts/verify-app.sh /path/to/ADI2Companion.app`.
Also verify actual signing/provisioning through Xcode. The development check
does not authenticate an Apple distribution identity. Remove any quarantine
extended attribute from the submission bundle before upload, then revalidate.

## App Store Connect metadata draft

These are draft strings, not an existing or reserved App Store listing.

| Field | Draft |
| --- | --- |
| Name | ADI-2 Companion |
| Subtitle | EQ editor and MIDI control |
| Primary category | Music |
| Bundle ID | `tech.norvi.ADI2Companion` — confirm with the selected team |
| Version | 1.0.0 |
| Build | 1 |
| Keywords | equalizer,parametric,EQ,MIDI,DAC,headphones,audio |
| Support URL | https://github.com/spencernorton/rme-adi2-linux/issues |
| Privacy URL | https://github.com/spencernorton/rme-adi2-linux/blob/main/macOS/PRIVACY.md |
| Marketing URL | https://github.com/spencernorton/rme-adi2-linux/blob/main/macOS/README.md |

### Description draft

Build and review a five-band EQ on your Mac, then apply it to compatible ADI-2
hardware through USB MIDI.

ADI-2 Companion provides a native Mac interface for output EQ, parameter
controls, a local profile library, and clear import warnings. Bring in Equalizer APO or
REW filter text, CSV, or compatible JSON; inspect the response curve and adjust
the bands before sending your EQ to both channels of an output. Export profiles
to share your work. Keep frequently used profiles in the app's local library.

Hardware memory controls address 20 EQ slots and 9 device setups, with explicit
confirmation before every recall or save. EQ slot writes store the five filter
bands; Bass/Treble and Loudness switches are separate from that memory write.
Advertise these hardware workflows only after qualification of the final build.

Explore the interface in demo mode without connecting hardware. The app has no
accounts, ads, or telemetry, and it does not record your audio.

Hardware control requires compatible ADI-2 firmware, USB connection, and MIDI
Control enabled on the device. Final listing must name only hardware models
qualified with the released Mac build. Independent software; not affiliated
with or endorsed by RME.

### Review notes draft

This is a local USB MIDI controller and offline EQ editor. No login, subscription,
network backend, privileged helper, or audio recording is used.

To explore without hardware, choose **Explore demo** in the sidebar or
**Device → Explore Demo**. The banner identifies simulated hardware; no MIDI is
sent. Select an output, edit the EQ, and use Import/Export with local files.

For hardware testing, enable MIDI Control on the ADI-2, connect it by USB, select
its MIDI endpoint, and click Connect. Settings are read before hardware writes
are enabled. EQ band changes remain drafts until **Apply EQ to Both Channels**;
other enabled parameter controls write immediately. Sync reads the current
hardware settings again. Local library saves remain inside the app's sandbox;
loading a local profile creates a draft without changing hardware. Hardware EQ
memory and device setup operations are separate, with confirmation before every
recall or save. Loading an EQ slot changes live EQ and replaces the editor draft.
Loading a setup can change device-wide volume/routing and replaces the editor
state. Setup saves use current hardware settings, excluding unapplied drafts.
EQ memory saves contain the five bands, not Bass/Treble or Loudness switches.

The current physical check covers DAC discovery, full settings sync, and a
0.1 dB Phones volume reduction/restoration on Apple silicon with macOS 27.2.
Before submitting these notes, complete the remaining workflow qualification,
add the exact tested Mac/OS/device/firmware list,
attach the required camera video, and provide any hardware/resources Apple needs
for complete review. Keep the model claims consistent with the final description.

## Screenshots and privacy answers

Use genuine app screenshots without transparency. Mac screenshots must be 16:10
at **1280×800, 1440×900, 2560×1600, or 2880×1800**; at least one is required.
Useful views are the output EQ, import warning flow, and device settings. If
screenshots use demo mode, retain the visible demo banner; do not imply a live
hardware connection.

The app itself collects no data. Confirm that the shipping code and any future
dependencies still match this claim before selecting the corresponding privacy
answers in App Store Connect. The manifest currently declares no tracking,
collected data, or required-reason API use. Apple documents collected-data
information across all platforms, while its current required-reason API scope
lists iOS, iPadOS, tvOS, visionOS, and watchOS. Recheck current rules at release.

## RME protocol reference

RME's [official protocol archive](https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip)
is linked from the [Remote manual](https://rme-audio.de/downloads/adi2remote_e.pdf),
page 3. Its `MIDITable_ADI-2_261030.ods` is version 1.2, dated October 30, 2026,
with firmware bases Pro 130, DAC 62, 2/4 SE 43, and 2/4 EX 106.

The `Channels` sheet documents EQ Enable index 2 on the left addresses
(`A80:G80`), left-only Bass/Treble indices 20–26 (`G99`, `A100:B106`), and
left-only preset behavior indices 27–28 (`G107`, `A108:H110`). Band controls
3–19 are bilateral. Incoming right-channel index 2 appears in both the official
examples and the live DAC dump; accepting that report does not imply a right-side
write contract. The app requires and writes the shared controls at their
documented left addresses.

## Apple references checked November 10, 2026

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/):
  sandboxed, self-contained Mac app packaging, public APIs, metadata, privacy,
  and intellectual-property requirements.
- [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox):
  sandbox capability and resource entitlements. Basic local CoreMIDI access is
  now verified in the sandboxed development app; no speculative MIDI or broad
  USB/network/audio entitlements are included.
- [Complete review information](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review):
  actual-device hardware video and tested device/OS information.
- [Distribution workflow](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases):
  membership, signing, archives, validation, TestFlight, and submission.
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/):
  current table lists macOS builds using Xcode 6+ and uploads using Xcode 14+.
  Use a current supported Xcode; the separate Xcode 26 SDK notice does not list
  macOS as having the same minimum as iOS/tvOS.
- [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/):
  current submission changes, including macOS quarantine attributes.
- [Privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
  and [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api):
  manifest contents and current platform scope.
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications):
  accepted Mac dimensions and file requirements.

Apple can change these requirements. Recheck the linked current pages before
the actual submission; passing automated validation does not guarantee review.
