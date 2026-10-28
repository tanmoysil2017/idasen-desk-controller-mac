# macOS compatibility investigation and upgrade plan

Status: Rosetta-removal cutover implemented. The app now targets macOS 13+, uses native `SMAppService.mainApp`, and has no package dependency or embedded login helper. `just build` rejects Mach-O binaries lacking Apple Silicon support. See README for installation and manual retirement of old login-item entries.

The remaining sections preserve the original investigation and proposed wider compatibility work. Their old paths, build failures, bundled-release assessments, and unimplemented steps describe the pre-migration baseline, not the current source. Bluetooth recovery changes and full hardware/login acceptance remain separate work.

## Recommendation

Keep the existing AppKit menu-bar app and CoreBluetooth desk protocol. Restore builds with the current Xcode toolchain, replace the legacy launch-at-login component with Apple's native `SMAppService.mainApp`, and verify Bluetooth permissions and recovery on current macOS.

Apple's release pages currently list **macOS 27 Golden Gate 27.2** as the latest public macOS. Target that release for runtime acceptance, with macOS Tahoe 26 as the previous-major regression target. The local investigation used **macOS 26.7.1, Apple Silicon, Xcode 27.1, and the macOS 27.0 SDK**; compiling against that SDK does not establish runtime compatibility with macOS 27.2.

Recommended minimum OS: **macOS 13 Ventura**, which provides `SMAppService`. This intentionally drops the project's existing macOS 10.15–12 support and needs agreement before implementation. Keeping those older systems would require a separate compatibility strategy, not merely changing the latest-SDK setting. Preserve the existing Intel/Apple Silicon universal distribution where supported by the toolchain, testing Intel on a compatible macOS release.

## Findings and confidence

| Priority | Finding | Evidence | Meaning |
| --- | --- | --- | --- |
| P0 | Current Xcode rejects the deployment target | `Desk Controller.xcodeproj/project.pbxproj:332,387` sets `MACOSX_DEPLOYMENT_TARGET = 10.15`. A baseline build failed with a supported range of `12.0 to 27.0.x`. | Confirmed build blocker. An old minimum OS is not itself proof that an existing binary cannot run on new macOS. |
| P0 | AutoStand is missing an explicit framework import | `Desk Controller/AutoStand.swift:8,38` imports Foundation but uses `CGEventSource`, `CGEventSourceStateID`, and `CGEventType`. A diagnostic build with the minimum temporarily overridden to 13.0 failed on all three names. | Confirmed compiler errors. A separate executable Swift probe successfully resolved these symbols with `import CoreGraphics`. |
| P1 | Launch-at-login uses an archived, legacy dependency | `Package.resolved:8-9` pins LaunchAtLogin 4.0.0; `Preferences.swift:133-140` uses it; `project.pbxproj:242` runs its helper-copy script. The fetched 4.0.0 source calls `SMCopyAllJobDictionaries` and `SMLoginItemSetEnabled`. Upstream is now archived. | Confirmed legacy component. Apple recommends `SMAppService` for macOS 13+. Deprecation is not proof of removal or the user's exact runtime failure. |
| P1 | The shipped helper still needs Intel translation on Apple Silicon | `file` identified the bundled main executable as `x86_64 + arm64`, but `Contents/Library/LoginItems/LaunchAtLoginHelper.app/Contents/MacOS/LaunchAtLoginHelper` as `x86_64` only. | Confirmed architecture mismatch. The helper requires Rosetta on Apple Silicon; this is not evidence that Rosetta is already unavailable. Apple documents general-purpose Rosetta availability through macOS 27. |
| P1 | Bluetooth denial recovery gives incorrect guidance | `ViewController.swift:146-149` instructs users to delete/reinstall the app. Apple exposes Bluetooth authorization under System Settings > Privacy & Security > Bluetooth. | Confirmed recovery UX problem; not evidence that CoreBluetooth itself is unsupported. |
| P2 | Connection recovery can stall | `BluetoothManager.swift:50-54` only creates a central manager; it does not restart scans after one exists. Scanning stops on connection at line 123; disconnect/failure callbacks at lines 129-154 clear the peripheral without restarting scanning. `ViewController.swift:195-200` calls the creation-only method to reconnect. | Source-backed pre-existing defect; reproduce on hardware before fixing. Not established as an OS regression. |
| P2 | Locale API is deprecated | The diagnostic build warns about `NSLocale.current.usesMetricSystem` at `Preferences.swift:124`. | Non-blocking modernization; use `Locale.measurementSystem` while preserving saved preferences and cm/in behavior. |

### What does not currently need replacement

- AppKit/Cocoa, storyboards, the status item, and CoreBluetooth: no evidence from this investigation that these frameworks need replacing.
- Bluetooth prerequisites already exist: `NSBluetoothAlwaysUsageDescription` in `Info.plist:29`, and sandbox/Bluetooth entitlements in `Desk_Controller.entitlements:5-8`. Do not treat these as missing or disable the sandbox as a workaround.
- The bundled release is already signed and notarized: `spctl --assess --type execute --verbose=2 'Desk Controller.app'` returned `accepted`, `source=Notarized Developer ID`. This result applies to this local bundle and machine, not every downloaded copy.
- A SwiftUI rewrite or mandatory Swift 6 language-mode migration is not justified by the observed failures. Keep Swift 5 language mode initially and address actual diagnostics.

## Implementation sequence

### 1. Restore a reproducible modern-toolchain build — required

Files: `Desk Controller.xcodeproj/project.pbxproj`, `Desk Controller/AutoStand.swift`, `Desk Controller/Preferences/Preferences.swift`.

1. Set the agreed minimum deployment target consistently in Debug and Release; recommended value is 13.0. Keep `SDKROOT = macosx` so Xcode selects its installed SDK rather than hardcoding an old SDK.
2. Add the explicit CoreGraphics import to AutoStand; keep the idle-time behavior unchanged.
3. Replace the deprecated locale API without changing the `isMetric` UserDefaults key, overriding saved user choices, or changing the two supported display units. Check metric, US, and UK measurement-system semantics rather than assuming every non-US locale is metric.
4. Build again to expose any later linker, resource, signing, or helper-script failures. The investigation did not reach a successful complete build, so these later stages are not yet cleared.
5. Keep the existing bundle identifier and defaults keys unless distribution ownership requires a deliberate identity change. Do not use the original author's signing team for new releases.

Acceptance: clean Debug and Release builds with the chosen toolchain and supported architectures; no deployment-target or unresolved CoreGraphics-symbol errors. Locale behavior preserves saved preferences.

### 2. Replace LaunchAtLogin 4.0.0 — required modernization

Files: `Desk Controller/Preferences/Preferences.swift`, `Desk Controller/Preferences/PreferencesWindowController.swift`, `Desk Controller/Preferences/PreferencesWindowController.xib`, `Desk Controller/AppDelegate.swift`, `Desk Controller.xcodeproj/project.pbxproj`, and the SwiftPM `Package.resolved` file if no dependencies remain.

1. Use native ServiceManagement: `SMAppService.mainApp.register()`, `unregister()`, and `status`. This small AppKit app does not need another wrapper dependency for those operations.
2. Replace the current write-only-success assumption with explicit operation/error handling. Reflect `.enabled`, `.notRegistered`, `.requiresApproval`, and `.notFound`; do not show an enabled checkbox merely because registration was requested.
3. Add an action to open Login Items settings using `SMAppService.openSystemSettingsLoginItems()`, and refresh the preference when the app becomes active after the user changes system settings.
4. Remove automatic first-launch registration in `AppDelegate.swift:21-25`; make launch-at-login an explicit user choice. Preserve other first-launch state only if still used.
5. Design and exercise the upgrade path from `com.davidwilliames.Desk-Controller-LaunchAtLoginHelper`: retire the old registration without duplicate launches, preserve verified user intent, and never override an OS-level denial. If one-time legacy unregister code is necessary, isolate it as upgrade migration code, not a second permanent launch mechanism. If the old state cannot be determined reliably, ask the user to opt in through the setting rather than silently enabling it.
6. Remove the Swift package reference, linked product, helper-copy build phase, and obsolete package lockfile if unused. Produce a fresh app bundle with no legacy helper or package resources; do not hand-edit the signed bundled release.

Acceptance: enabling, disabling, approval-required, registration-error, external Settings changes, logout/login, and in-place upgrade all behave correctly. Exactly one app launches when enabled, none when disabled, and no Intel-only helper remains.

### 3. Verify Bluetooth permission and lifecycle behavior — required acceptance, targeted fixes

Files: `Desk Controller/BluetoothManager.swift`, `Desk Controller/ViewController.swift`, and, if queue ownership needs correction, `Desk Controller/Desk control/DeskController.swift`, `Desk Controller/Preferences/PreferencesWindowController.swift`, and the AppleScript command handlers.

1. Replace delete/reinstall advice with the Bluetooth privacy-settings path and clear denied/restricted/off/unavailable states. Keep the existing Bluetooth purpose string and entitlement, checking their presence in the actual built app.
2. Reproduce the stopped-scan/disconnect path. If reproduced, separate central-manager initialization from starting a scan, and resume discovery when powered on and authorized after disconnect/failure. Avoid a hot retry loop, duplicate scans, or repeated permission prompts.
3. Clear stale controller/control availability on disconnect and distinguish a discovered/connecting peripheral from a control-ready desk. Verify controls cannot issue movement through an obsolete connection.
4. Check queue ownership while exercising real callbacks. The central uses `BT_queue`, while UI and AppleScript also access the controller; the preferences position callback updates AppKit directly. Prefer main-queue ownership for this low-volume app if consolidation is needed, rather than introducing an actor/service rewrite. All AppKit updates must run on the main thread.
5. Preserve the Linak service/characteristic UUIDs and movement commands. Do not change calibration, desk selection, packet format, or movement timing without separate evidence requiring it.

Acceptance: first permission grant, denial and re-enable, Bluetooth off/on, desk power-cycle, disconnect/reconnect, and sleep/wake all produce truthful status and recover without reinstalling. Movement and stop behavior remain correct with a physical IDÅSEN desk.

### 4. Validate and package the release — required before claiming support

Files: project signing/version settings, `README.md`, and release packaging; add a focused test target and scheme entries only for behavioral regression coverage introduced with fixes. The shared scheme currently has no testables.

1. Exercise the actual menu-bar popover, right-click menu, preferences activation, saved heights/units, manual movement, sit/stand/stop, and AutoStand with the desk area clear.
2. Preserve existing AppleScript terminology and command classes. Exercise `move "to-sit"`, `move "to-stand"`, `move "up"`, `move "down"`, and `move to "80cm"`/inch/unitless variants under supervision. Do not redesign the scripting dictionary as part of this migration.
3. Add deterministic regressions for any fixed lifecycle/state bugs and login-setting state mapping. Test consumer-visible transitions and errors, not framework forwarding or copied source text. Hardware, permission dialogs, and actual login behavior still require manual smoke checks.
4. Test a fresh installation and an upgrade on macOS 27.2, plus a compatible previous-major system and the agreed minimum OS. Verify native Apple Silicon operation without requiring Rosetta; verify Intel on a supported Intel macOS if that architecture remains distributed.
5. Sign with the maintainer's own Developer ID and hardened runtime, preserve sandbox/Bluetooth capabilities, notarize and staple the new release, and assess a downloaded/quarantined copy. Replacing the original signing identity may affect permissions and login-item migration; explicitly test it.
6. Package the newly built app, not the stale checked-in `Desk Controller.app`. Update README minimum-OS, build instructions, Bluetooth troubleshooting, and release notes with the compatibility change and legacy-helper removal.

Acceptance: fresh and upgrade installs pass the hardware/UI/login matrix, retain settings, pass Gatekeeper, and have no legacy-helper dependency. A build alone is not a macOS compatibility sign-off.

## Verification performed during this investigation

The full Xcode installation was used per command via `DEVELOPER_DIR`; the system-wide developer-directory selection was not changed.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project 'Desk Controller.xcodeproj' \
  -scheme 'Desk Controller' -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/idasen-macos-compat-audit \
  -clonedSourcePackagesDirPath /tmp/idasen-macos-compat-packages \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO build
```

- Result: **failed**, exit 65; deployment target 10.15 is outside the toolchain's supported range.
- Repeating the diagnostic build with command-line `MACOSX_DEPLOYMENT_TARGET=13.0` advanced to Swift compilation, then **failed**, exit 65, on the three CoreGraphics type names in AutoStand. This override was diagnostic, not a saved project edit.
- `xcrun swift -e 'import Foundation; import CoreGraphics; print("CoreGraphics symbols available:", CGEventSource.self, CGEventSourceStateID.hidSystemState.rawValue, CGEventType.null.rawValue)'` under the same Xcode succeeded and printed `CoreGraphics symbols available: CGEventSourceRef 1 0`.
- `file` confirmed the universal main executable and Intel-only helper; `codesign --display --verbose=4` identified the existing Developer ID signature and stapled ticket; `spctl` accepted the bundled release.
- Xcode also reported an outdated CoreSimulator installation. That is a local toolchain diagnostic; the macOS build continued to package resolution and compilation, so it is not established as the app's build blocker. Repair that installation separately if it prevents further validation.

No application implementation was edited. The app was not launched: startup currently enables a login item automatically and saved AutoStand settings could cause physical desk movement. No desk interaction, login registration, or runtime verification on macOS 27.2 was performed.

## Open prerequisites and risks

- The precise reported runtime symptom is not yet identified. Build blockers, an obsolete login component, and existing recovery defects are proven separately; none should be presented as the sole cause of every failure.
- Physical desk access and a macOS 27.2 runtime are needed for final compatibility proof.
- A maintainer-controlled signing identity is needed for distributable release verification.
- Raising the minimum OS to 13 changes the support contract; agree on that before code changes.
- Preserve AppKit, existing callbacks, UserDefaults keys, and AppleScript names. Existing logging is mostly commented-out `print` statements, error handling mostly uses early-return guards, and no automated test target is configured; do not invent a large logging, persistence, or architecture layer for this migration.

## Primary sources

- [Apple: current macOS versions](https://support.apple.com/en-us/109033)
- [Apple: developer releases and Xcode versions](https://developer.apple.com/news/releases/)
- [LaunchAtLogin upstream: archived legacy repository](https://github.com/sindresorhus/LaunchAtLogin-Legacy)
- [LaunchAtLogin 4.0.0 source](https://github.com/sindresorhus/LaunchAtLogin-Legacy/blob/v4.0.0/Sources/LaunchAtLogin/LaunchAtLogin.swift)
- [Apple: SMLoginItemSetEnabled and its replacement](https://developer.apple.com/documentation/servicemanagement/smloginitemsetenabled(_:_:))
- [Apple: SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [Apple: mainApp login service](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)
- [Apple: registration states](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum)
- [Apple: Bluetooth privacy controls](https://support.apple.com/en-my/guide/mac-help/mchl211c911f/mac)
- [Apple: Rosetta support and limitations](https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment)
- [Apple: Locale.measurementSystem](https://developer.apple.com/documentation/foundation/locale/measurementsystem-swift.property)
