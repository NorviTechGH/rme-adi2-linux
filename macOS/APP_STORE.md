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
- Experimental controls for 20 hardware EQ slots and 9 device setups, with
  confirmation for every recall/save. These paths remain hardware-unqualified.
- A CLI script that produces an ad-hoc-signed sandboxed development app.

The development bundle is not an `.xcarchive`, App Store signed build, installer
package, notarized distribution, or proof of Apple review acceptance.

## Current qualification

- **Software:** 50 cases and 323 assertions pass (core: 33/205; app model:
  17/118). The native and Linux jobs passed in
  [CI run 43042638214](https://github.com/NorviTechGH/rme-adi2-linux/actions/runs/43042638214)
  at `ec848fcdf4f1aea7a2b38758441141eb53e01257`.
- **Xcode archive:** That run produced an unsigned universal app and
  `.xcarchive` using Xcode 16.4 (16F6), macOS SDK 15.5 (24F74), and a macOS 14.0
  deployment target in both `arm64` and `x86_64` slices. Independent download
  verification passed the GitHub artifact digest, every payload checksum,
  source receipt, matching app/archive files and dSYM UUIDs, icon renditions,
  privacy/license resources, and supplied sandbox entitlements. No distribution
  signing authority, team, embedded profile or quarantine was present. This is
  archive/build evidence; Apple package validation and upload have not occurred.
- **Local distribution package:** A copy of that archive has been signed with
  the intended Mac App Store application identity and packaged with its
  installer identity. Local verification passed both architectures, exact
  sandbox entitlements, certificate identities, non-code resources, narrowly
  audited executable equivalence after signing, and identical expanded payload
  without installer scripts. This does not establish Transporter acceptance,
  installation, runtime qualification or review approval.
- **Volume presentation:** 10 isolated cases / 48 assertions pass, including
  actual Core Animation presentation layers, rapid retargets, 0.1 dB input and
  authoritative dragging during motion. The interpolation and burst cases step
  an isolated layer's Core Animation clock to verify intermediate geometry,
  bounds, final position and absence of input callbacks under hosted-runner
  load; they do not establish a real-time frame rate. Separate real-time
  retarget and mid-animation drag checks remain. A visible local replay passed
  all 48 assertions, and the user confirmed smooth physical-knob feedback with
  the development app.
- **Physical ADI-2 DAC, Apple silicon, macOS 27.2:** The native sandboxed app
  discovers the device and reads its complete 219-parameter settings state.
  A GUI Phones volume reduction of 0.1 dB and restoration passed, with fresh
  Sync readback confirming each step.
- **Capture assets:** Two genuine 2880×1800 app screenshots have been captured
  from an isolated demo capture copy of the same source revision and attached
  to the App Store Connect version draft. Its only
  source change was the default window size, from 1120×800 to 1440×900; its
  separate bundle/sandbox avoided the user's saved library. This establishes
  capture provenance, not hardware behavior or a final distribution signature.
- **Remaining scope:** Pro/2/4 hardware, unplug/replug, EQ Apply readback,
  EQ/setup memory recall/save, and Intel runtime behavior remain unverified.
  No persistent memory writes have been performed. Further physical checks
  require the test hardware to be available to this Mac. Final signed-build
  qualification, hardware camera video, Transporter processing and App Review
  remain open.

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
   not validated support. Read-only preset replies use a different flags index
   from the documented staging/commit control. Do not infer a changed write
   address from incoming reports alone. Qualify the documented write sequence
   in a reserved unused slot, with fresh readback and volume protection, before
   claiming reliable memory operation. Device memory remains experimental.
2. **Apple validation and runtime qualification:** Validate and upload the
   locally verified signed package through Transporter. Test the final build on
   physical hardware and the supported Mac/OS combinations. Structural archive,
   signature and package checks do not replace Apple's processing or runtime
   qualification.
3. **Apple account and signing:** The app record and bundle ID exist, and genuine
   Mac App Store application/installer signing identities have been created on
   the local development Mac. Keep the private keys local; CI contains no Apple
   signing credentials. Finish applicable account requirements and verify actual
   Transporter acceptance and build processing. Local signing alone is not an
   accepted upload.
4. **Hardware review video:** Film a physical Mac running the app as it connects
   to and interacts with a physical ADI-2. Apple specifies a video, not a screen
   recording. Attach it in review information with hardware requirements and
   exact setup steps. Demo mode does not replace this hardware evidence.
5. **Product and rights review:** Confirm final name, seller/developer identity,
   pricing, territories, support arrangements, and permission for any third-party
   protected material. The current icon is original and the app is explicitly
   independent. Do not use RME's logo or imply an official relationship.
6. **Final metadata:** Review the draft below, select and verify the captured
   screenshots against the shipping UI, finish current
   age-rating/privacy/export-compliance questions and applicable trader/account
   information, verify live URLs at the released revision, and beta test the
   final build. Do not submit while those fields or evidence are incomplete.

Track these gates durably in the project tracker; update this file with actual
test results rather than turning planned checks into claimed validation.

## Current submission preparation — November 11, 2026

The app record and bundle identifier have been created in the intended Apple
Developer account. The English (US) version draft is 1.0.0, with a saved
USD 15.00 upfront base price for the first release. It has not been submitted
for review. Local distribution signing and package verification are complete;
applicable paid-app account requirements, upload/processing and hardware review
evidence remain in progress.
Public listing text, synthetic screenshot fixtures and the capture instructions
are in [AppStore/](AppStore/README.md). The support page is [SUPPORT.md](SUPPORT.md).

Full Xcode is unavailable on the development Mac. The green CI run above
retained the actual universal unsigned Xcode-built app and archive through
`scripts/build-xcode-artifact.py`; both were downloaded and independently
verified. The receipt binds the source SHA, SDK, artifact hashes and matching
debug-symbol UUIDs. Apple signing keys stay local; CI receives no Apple
credentials. The verified output remains unsigned for distribution and is not
an App Store upload package.

Apple supports manual Mac distribution signing and a single-app `productbuild`
package, which can be verified and delivered with standalone Transporter. See
[Apple signing](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac),
[packaging](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
and [Transporter](https://support.apple.com/guide/transporter-app/welcome/mac).
This CI/local split still requires an actual signed-package validation and
physical final-build test. TestFlight requires an appropriate profile even
though unrestricted Mac App Store entitlements alone need none; see
[TN3125](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles).

## Build and archive

With full Xcode selected, run core XCTest tests using `swift test` from this
directory. Command Line Tools alone do not include the required XCTest framework;
`./scripts/test-cli.sh` runs the same test bodies through standalone assertion
harnesses in that environment. The tests use fake MIDI rather than hardware. Use
`./scripts/build-app.sh --universal` to exercise a local universal development
bundle. Its verification script checks bundle files and sandbox signing; that
does not replace Xcode validation or hardware testing.

On a machine with full Xcode, open `ADI2Companion.xcodeproj`, choose your team,
and choose the shared **ADI2Companion** scheme with a Mac destination.
Product → Archive creates an archive; Organizer → Validate App performs Apple's
initial checks, and Distribute App → TestFlight & App Store handles distribution
signing and upload. The current release uses the verified CI archive and the
local signing/`productbuild`/Transporter route described above. Preserve the
unsigned artifact and receipt, and sign a fresh copy for that route.
Set version, build number, and bundle identifier in
`Resources/App.xcconfig`; both the Xcode target and development-bundle script
read that configuration. Use a new build number for each new upload.

Verify the final bundle with `scripts/verify-app.sh /path/to/ADI2Companion.app`.
Also verify the actual distribution authority, entitlements and installer
signature through Xcode or the local packaging tools. The development check
does not authenticate an Apple distribution identity. Remove any quarantine
extended attribute from the submission bundle before upload, then revalidate.

## App Store Connect metadata draft

These strings are a reviewable source draft for the existing app record, not
an approved or published App Store listing. Reconcile them with the final
App Store Connect fields before submission.

| Field | Draft |
| --- | --- |
| Name | ADI-2 Companion |
| Subtitle | Parametric EQ and MIDI control |
| Primary category | Music |
| Bundle ID | `tech.norvi.ADI2Companion` — match the signed application |
| Version | 1.0.0 |
| Build | 1 |
| Keywords | equalizer,parametric,EQ,MIDI,DAC,headphones,audio |
| Support URL | https://github.com/spencernorton/rme-adi2-linux/blob/main/macOS/SUPPORT.md |
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
hardware connection. Two genuine 2880×1800 capture assets are available as
described above; review their final selection, visible state and attachment in
App Store Connect. They do not replace the required physical hardware video.

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

## Apple references checked November 10–11, 2026

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
