# ADI-2 Companion Privacy Policy

Effective November 10, 2026.

ADI-2 Companion is a local macOS controller and EQ editor. The app does not
collect, upload, sell, or share personal information, audio, MIDI data, device
identifiers, EQ profiles, usage analytics, or app-provided crash telemetry.
It has no account system, advertising, tracking SDKs, or network entitlement.

## What happens on your Mac

The app reads available MIDI endpoints and exchanges control messages with the
ADI-2 you explicitly connect. Device settings and unsaved EQ drafts are held in
memory while the app is running. Demo mode uses simulated settings and sends no MIDI.

When you save a profile to the app's local library, its name, output selection,
EQ bands, and related profile settings are stored as a file in Application
Support inside the app's sandbox container. These files stay on your Mac and
are not uploaded. Loading a library profile creates an editable draft. Saved
library profiles remain until you remove the app's sandbox data; exported
copies are separate.

EQ import and export use the system file picker. The app reads the file you
select or writes the profile to the location you choose. It does not scan
folders, upload files, or retain access to those locations between sessions.
Your exported profile remains until you delete it in Finder. Hardware settings,
EQ memory slots, and device setups remain on the ADI-2 under the device's own
behavior; closing or uninstalling the app does not erase them.

The app runs in Apple's App Sandbox and requests user-selected file read/write
access. It does not request microphone, camera, contacts, Bluetooth, or network
access. It neither records nor processes your playback audio.

## Links and diagnostics

Opening support or policy links launches your default web browser. Those
websites operate under their own privacy policies. Information you voluntarily
post to a public GitHub issue is public; include only what you want to share.

macOS and Apple's distribution services may provide their own crash reporting
or diagnostic features according to your system settings and Apple's policies.
The app does not embed a separate telemetry service.

## Deletion and contact

No information is stored on an app-operated server, so there is no server
account or retained server data to delete. To erase the local library, remove
the app's sandbox data on your Mac. Delete exported profiles separately in
Finder. Removing the app alone may leave its sandbox container behind. For
questions about this policy,
use the [project issue tracker](https://github.com/spencernorton/rme-adi2-linux/issues).
Do not post confidential information there.
