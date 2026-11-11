## 2026-11-11 — Resolve native CI compiler compatibility

- The first full-Xcode runner found ambiguous channel-index type inference and
  an EQ Canvas expression exceeding its type-checking budget before tests ran.
- Made the index collection explicitly typed and split graph drawing/dragging
  into small typed helpers. Geometry, drawing order, draft behavior and MIDI
  dispatch are unchanged; no hardware action or app restart was performed.
- Validation: 50 core/model cases / 323 assertions and universal development
  compilation pass locally. The next CI run must validate the older Xcode
  compiler and actual Xcode archive; this is not an App Store validation claim.
- Next: finish native CI and physical memory qualification, keeping the release
  PR as work in progress until the remaining release evidence is complete.

## 2026-11-11 — Use an original Mac example profile for release

- Replaced the Mac app's bundled DT 1990 reference with an original, gentle
  **Example EQ** for illustrating the editor. The previous five-band adaptation's
  exact upstream source/revision and commercial-use provenance were unresolved;
  this change makes no claim about infringement. The example is not marketed as
  a headphone-specific correction or listening recommendation.
- Demo state and its simulated first preset now use the example. Selecting it
  creates a draft for the chosen output; it never applies EQ automatically.
  Flat EQ, imports, the shared JSON schema, saved profiles and the Linux legacy
  source/data are unchanged. No migration or replacement of user profiles occurs.
- Updated Mac importer/library/preset test fixtures to the original example. The
  preset byte oracle was generated independently with the unchanged Linux
  encoder and the new illustrative numbers. Core/model CLT checks pass:
  33 core cases / 205 assertions and 17 fake-MIDI app cases / 118 assertions.
- Release Help now targets the prepared support page, and the privacy alert's
  paragraphs use real newlines. The accepted main-fader renderer is unchanged.
  The running app, connected DAC and pending personal EQ draft were not changed,
  restarted or applied by these source/test edits.
- Next: run native CI on this release source, prepare fresh capture assets from
  its resulting build, and publish the support/privacy pages through the source
  PR before using their URLs in App Store Connect.

## 2026-11-11 — Prepare the paid Mac App Store release

- Created the intended app record and explicit bundle identifier after the user
  completed Apple's updated Developer Program License Agreement. Saved the
  English (US) version draft and the requested USD 15.00 upfront base price.
  The paid agreement/compliance, signed upload and App Review remain pending.
- Added listing/review drafts, genuine screenshot capture preparation, synthetic
  fixtures and a public maintainer support page. Canonical URLs still need the
  source PR to land before they can be used in the submitted listing.
- Added a CI path retaining the actual unsigned universal Xcode archive/app,
  sandbox entitlements and a source/SDK/symbol-bound checksum receipt. Apple
  signing keys remain local. Static checks and 14 artifact verifier cases pass;
  the real Xcode integration run remains next.
- A fresh bounded read-only DAC snapshot is complete. The user reserved unused
  memory slots for qualification; EQ 20 and setup 9 are selected. No memory
  write is claimed here, and the accepted fader behavior is unchanged.
- Next: run native CI, qualify memory on the physical DAC, validate/sign the
  release package, finish Apple account fields and attach actual review assets.

## 2026-11-11 — Animate the main fader for physical-knob feedback

- Replaced the main fader renderer with a native AppKit control whose track,
  fill and knob use Core Animation layers. Incoming targets ease over 0.18 s
  from the current presentation position, retargeting without endpoint jumps
  or overshoot. Direct input stays immediate and quantized to 0.1 dB; keyboard,
  accessibility, focus and Reduce Motion remain supported. Animation emits no
  user-value callbacks or interpolated MIDI.
- The prior readout/tiny-level-bar smoothing was rejected by the user because
  the actual main fader still jumped while turning the physical DAC knob. That
  decorative indicator was removed. A read-only observation captured 86 live
  knob reports with a typical interval of 64.3 ms; device cadence is unchanged.
- Validation: 10 isolated component cases / 48 assertions pass, sampling actual
  presentation geometry across display frames, retargets/reversal, direct input,
  0.1 dB keyboard/accessibility steps, Reduce Motion, disabled input and callback
  separation. A mid-animation drag regression also verifies input starts from
  the actual volume rather than an intermediate animation frame. The universal
  sandboxed build and bundle checks pass. Reproducible
  CLT motion-harness instructions are in `macOS/README.md`.
- Reopened the new universal development app after the user quit the previous
  build, connected it and restored the pending EQ draft without applying it.
  The user tested the physical DAC knob and confirmed: “It’s smooth now.” No
  hardware parameter write or EQ Apply was performed by this change's checks.
- Acceptance covers the observed live DAC volume feedback. App Store signing,
  full Xcode archive validation and the other documented hardware workflows
  remain separate release gates.

## 2026-11-11 — Smooth volume feedback

- Added brief eased volume readout/level transitions, keeping direct dragging,
  native 0.1 dB stepping and Reduce Motion behavior. Animation is confined to
  presentation; the hardware binding and MIDI model are unchanged.
- Validation: universal release build and sandbox/signature checks pass; native
  demo accessibility adjustments remain exactly 0.1 dB. Independent code review
  confirms no animation path can send interpolated MIDI. No new tests needed for
  this presentation change; protocol and model source are unchanged.
- Reopened the updated app, read the live DAC volume, and restored the user's
  pending EQ draft from an export without applying it or changing hardware state.
- Source publication and remaining App Store release gates are unchanged.

## 2026-11-11 — Correct shared EQ controls and verify physical DAC communication

- A real DAC returned 219 parameters; the first Mac connection timed out because
  the port incorrectly required a right-side Bass/Treble flag. Aligned readiness,
  flag hydration, profile writes, preset selection and right-side controls with
  RME MIDITable v1.2's documented left-only shared controls.
- Validation: 50 Swift cases / 323 assertions pass. The universal sandboxed app
  connects to the DAC, reads live EQ, and writes/reads/restores a 0.1 dB Phones
  volume change. No persistent memory slot was written. Details and remaining
  acceptance are in `macOS/HARDWARE_TESTING.md`.
- Source publication still awaits the publishing account's repository write
  access decision. Full Xcode, distribution signing and wider hardware tests
  remain release requirements. No Apple submission or account change occurred.
- Next: validate EQ/preset workflows and the distribution-signed Xcode archive.

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
