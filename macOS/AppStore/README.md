# App Store submission draft

Prepared November 11, 2026 from the accepted app baseline `ea719ef`. The app
record and USD 15.00 base price are now saved in App Store Connect. The assets
in this directory remain preparation material; no release is submitted yet.

`metadata-en-US.json` contains concrete English (US) listing strings and review
notes. It is a preparation format, not an App Store Connect API request. The
current name, Music category, bundle identifier, version/build, macOS minimum,
and copyright follow the app's checked-in configuration. The user selected a
paid upfront, one-time purchase at **USD 15.00**. The app record uses SKU
`tech.norvi.adi2companion.mac`; keep this distinct from the app bundle identifier.

## Copy and asset checks

| Field | Draft length | Apple limit |
| --- | ---: | ---: |
| Name | 15 characters | 30 characters |
| Subtitle | 30 characters | 30 characters |
| Promotional text | 155 characters | 170 characters |
| Description | 1,988 characters | 4,000 characters |
| Keywords | 73 UTF-8 bytes | 100 bytes |

The keyword list uses generic terms of at least three characters and omits
company names. Promotional text is optional; use it only if available for this
platform. A first release has no What's New field. These constraints come from
Apple's [app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)
and [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
references, checked November 11, 2026.

See [the screenshot shot-list](screenshots.md). The supplied fixtures are newly
created examples, not a user's saved EQ or measurements. Import them only into
an isolated demo/offline session for screenshots; they are not listening advice.

The listing uses **ADI-2 Companion** with original app artwork. Hardware names
identify compatibility. Do not add RME logos, an “official” label, or a claim of
RME endorsement. The text describes offline editing, the local library, and the
observed DAC volume workflow. It explicitly identifies device memory as
Experimental and Pro/2/4 hardware as not yet qualified. That disclosure does not
replace release qualification of the controls shipped in the final app.

## Required field status

| Item | Current public preparation | Remaining action |
| --- | --- | --- |
| Product record | ADI-2 Companion; macOS; English (US); Music | Confirm the existing record matches these fields |
| SKU | `tech.norvi.adi2companion.mac` | Preserve the SKU already selected for this app |
| Bundle ID | `tech.norvi.ADI2Companion` | Match the genuine signed archive |
| Version / build | 1.0.0 / 1 in current source | Increase the build number for a new upload as needed |
| Pricing | **USD 15.00 upfront, one time**, no in-app purchases or subscriptions | Select the matching App Store price point and verify storefront pricing |
| Listing text | JSON strings fit the checked Apple limits | Reconcile hardware claims with the final release scope |
| Public support | `../SUPPORT.md` provides a maintainer contact route through GitHub issues | Publish the page through the release PR, then verify its public URL and contact link |
| Privacy policy | `../PRIVACY.md` exists in source | Publish and verify the public policy URL |
| Screenshots | Shot-list and synthetic fixtures prepared | Capture genuine final-app images; validate dimensions and transparency |
| Availability and questionnaires | No values invented in this public pack | Complete actual storefront, privacy, age-rating, export and applicable declarations |
| Distribution build | Local development packaging exists | Validate the genuine signed archive, upload and select its processed build |
| Review information | Notes drafted; hardware requirements described | Attach the hardware camera video and final tested-build/device list |

Team/account identifiers, legal account details and the private review contact
belong in App Store Connect and are intentionally absent from this public pack.
Do not infer those fields from the app name or MIT license.

## Public support requirement

Apple's [Support URL definition](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
requires actual contact information, with address/email/phone examples qualified
by local law. [Review Guideline 1.5](https://developer.apple.com/app-store/review/guidelines/#developer-information)
requires an easy contact route in the app and at the Support URL. Neither text
states a universal requirement to publish an email address specifically. A clear
maintainer/contact-form page is stronger than a bare empty issue list, but this
preparation does not guarantee Apple's acceptance of GitHub as the sole contact
channel or resolve local-law requirements. No private contact has been invented
or published.

As checked November 11, the existing candidate GitHub `main/macOS/README.md` and
`main/macOS/PRIVACY.md` URLs returned **404**, while the issues page loaded. The
new `SUPPORT.md` page is also pending publication. Ship these documents through
the normal PR workflow and verify the final main-branch URLs after merge before
using them in App Store Connect. A prepared page or an open fork PR is not a
live production URL.

## Evidence still needed

Use the release gates in [APP_STORE.md](../APP_STORE.md) and the hardware record
in [HARDWARE_TESTING.md](../HARDWARE_TESTING.md). The physical DAC observation and
accepted main-fader motion do not establish EQ Apply readback, persistent-memory
reliability, Pro/2/4 compatibility, Intel runtime behavior, or every supported OS.
Keep the description, screenshot states and review notes aligned with the final
qualified build; never turn an implementation target into a tested claim.

Complete the final signed archive, build validation, genuine screenshots and
privacy/age-rating/export-compliance questionnaires from the shipping binary.
The current code has no app-operated collection or tracking; retain “Data Not
Collected” only if the final app and its dependencies still match that claim.
Do not claim a completed accessibility nutrition-label assessment from the
fader's keyboard/VoiceOver tests alone.

App Review also needs a camera video showing a physical Mac connecting to and
interacting with the required hardware, plus the tested device/OS list. A demo
or screen recording does not replace that video. See Apple's
[complete review information](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/).
The metadata review notes record current evidence, but their final paragraph
must be reconciled with the actual video, tested final build and review contact
before submission.
