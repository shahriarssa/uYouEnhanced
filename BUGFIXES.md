# uYouEnhanced 21.20.4-3.0.5: bug-fix pass

Static review of `Sources/`, `Makefile` and the build workflow. All fixes are small and local, and each one has a comment at the change site explaining the old behavior. **None of this has been compiled or run on a device yet** (see "Verification" at the bottom).

## Crashes / hard failures

| # | File | Bug | Fix |
|---|------|-----|-----|
| 1 | `uYouPlus.xm` | `ELMContainerNode` gains `applyRedColorToSubscribeButton:` and `hideMatchingSubviews:` without `%new`. The class has no such methods, so the hooks were never installed, and the `dispatch_async` call to them crashed with "unrecognized selector" as soon as **Red Subscribe Button** or **Hide Button Containers** was on. (The existing selector-crash logger even lists these two names.) | Added `%new`. |
| 2 | `uYouPlusThemes.xm` | Custom dark theme selected with no saved color (or after Reset): `initForReadingFromData:nil` throws inside `%ctor`, so the app crashed on every launch. | Type-check the data and wrap decoding in `@try`; only accept a `UIColor`. |
| 3 | `uYouPatches.xm` | The process-wide `NSFileManager -moveItemAtPath:` hook re-entered itself with the same fallback path when the fallback move also failed, causing infinite recursion and a stack overflow. | Thread-local re-entrancy guard plus a same-path check. |
| 4 | `UYTMediaKit.m` | FFmpegKitNext's `ReturnCode` has `-getValue` and `-isValueSuccess` (`+isSuccess:` is a class method; checked against the upstream `ReturnCode.h`). The code probed `-isSuccess`/`-intValue`, so **every successful ffmpeg run was reported as a failure**. The `getState` fallback also formatted an `NSUInteger` with `%@`, which would crash. | Use the real API; read `SessionState` as an integer. |
| 5 | `Extractor.xm` | The iOS innertube key had a typo (`AAIzaSy…`), so it was always rejected. `JSONObjectWithData:nil` crashed on a network failure, and an unbounded sleep-poll loop had no timeout. | Fixed the key; semaphore with a 25 s timeout; nil guards. |
| 6 | `YTSigDecipher.m` | Non-UTF-8 watch page or `player.js`, or an unreadable cache file, passed `nil` into a regex or `JSONObjectWithData:`. That throws on a background queue and crashes. | Nil guards; a corrupt cache file is deleted. |
| 7 | `UYTSABR.xm` | The protobuf/UMP length checks `pos + c + l > len` can wrap on a huge varint and read out of bounds. A `nil` videoID crashed `-addObject:`. | Overflow-safe comparisons; videoID guard. |

## Features that silently did nothing or misbehaved

| # | File | Bug | Fix |
|---|------|-----|-----|
| 8 | `uYouPlusSettings.xm` | **Import Settings** did nothing. The `UIDocumentPickerDelegate` methods were added to `YTSettingsSectionItemManager` without `%new`, so they were never installed. | `%new` + security-scoped access + an error alert that is actually presented. |
| 9 | `uYouPlusSettings.xm` | Copy/Paste/Import presented a second alert in the same runloop (UIKit drops it). The export alert called YTLite's `YTLUserDefaults`, which is not in this build. | Removed both leftover alerts. |
| 10 | `uYouPlusSettings.xm` | Imported values were stored as strings, and any key in the file was written. | Parse numbers back to `NSNumber`; only accept keys the exporter writes. |
| 11 | `uYouPlus.xm` | **Disable resume to Shorts** redirected every switch to tab 1, so the Shorts tab could never be opened. | Redirect only the first Shorts selection within 8 s of launch. |
| 12 | `uYouPlus.xm` | First-launch ad-block defaults: two blocks against a stale key snapshot overwrote each other, and an upgrading user's Lite choice was flipped off. | Explicit both/one-missing logic. A fresh install still gets the full workaround, which is what the old code produced in practice. |
| 13 | `AdBlocking.xm` | With both toggles on, both hook groups were installed on the same selectors. | Full workaround wins (`else if`). |
| 14 | `uYouPatches.xm` | Playback-speed persistence: after choosing any speed you could **never return to 1×**. The speed menu ignored 1.0, and the getter re-applied the saved rate, across launches too. | The overlay speed-menu path records 1.0 as well. |
| 15 | `uYouPatches.xm` | The `NSFileManager` move hook redirected **any** failed move in the app (YouTube's caches and databases) into `Documents/uYouDownloads` and reported success. | Limited to media files under Documents/tmp; "file exists" errors go back to the caller. |
| 16 | `uYouPatches.xm` | The idle timer was disabled when a download started and only re-enabled when the app went to the background. | Re-enabled on `downloadDidCompleteNotification`. |
| 17 | `uYouPlusPatches.xm` | Jailbreak detection treated every stock iPhone as jailbroken (`LSApplicationWorkspace` and `/Applications` always exist), so the **Dynamic Island fix** never turned on for sideloaded installs. | Removed that test. |
| 18 | `uYouPlusPatches.xm` | `accessGroupID()` ran a keychain query on every keychain call and leaked the result each time. | Cache the value; `__bridge_transfer`. The same leak is fixed in `uYouPatches.xm`. |
| 19 | `uYouPlusPatches.xm` | Native share sheet on iPad: the popover `sourceRect` was in the wrong coordinate space. A bad field made URLs containing "(null)". | `sourceView.bounds`; nil guard. |
| 20 | `DownloadPipeline.xm` | Audio/video leg detection checked for "Video" anywhere in the path first, so the audio leg of a title like "…Official Music Video_Audio.webm" became the video leg. | Decide by the `_Audio`/`_Video` suffix first. |
| 21 | `DownloadPipeline.xm` | Race: `setRemoteURL:` can run before the async innertube refresh has stored anything. The audio leg was then refused any URL and stalled. | With no resolved data yet, keep uYou's URL. |
| 22 | `FixPlayback.xm` | `handleError:` swallowed playback error 14 without `%orig` when it would not reload, leaving an endless spinner with no error UI. | Fall through to `%orig`. |
| 23 | `UYTMediaKit.m` | The ffmpeg "YouTube fallback" root was the literal string `@executable_path/Frameworks`, which file paths never expand. The probe was not thread-safe. | `privateFrameworksPath`; `dispatch_once`. |
| 24 | `UYTLog.xm` | `NSSetUncaughtExceptionHandler` replaced any existing handler (crash reporters, FLEX). | Chain to the previous handler. |
| 25 | `NotificationsTab.xm` | The Notifications tab was inserted again on every `setRenderer:` call, producing duplicate tabs. | Skip if it is already present. |
| 26 | `uYouPlus.xm` | `iosUseSystemVolumeControlInFullscreen` returned a hard `NO` when the option was off, overriding YouTube's own flag. | `%orig`. |

## Build scripts

| # | File | Bug | Fix |
|---|------|-----|-----|
| 27 | `Makefile`, `buildapp.yml` | They referenced `tools/…`, but the directory is `Tools/`. It works on case-insensitive macOS, but breaks on case-sensitive volumes and Linux. `hashFiles('main/tools/…')` matched nothing, so the FFmpegKit cache key never changed. | `Tools/`. |
| 28 | `Makefile` | `make clean` deleted the bundled `com.miro.uyou_3.0.4_iphoneos-arm.deb`, forcing a re-download from a Dropbox link. | Keep the `.deb`. |

## Noticed but left alone (need a device to judge)

- `NotificationsTab.xm`: the badge count only ever increases, so it never clears after you read your notifications. Also, an empty `UIViewController` view is laid over the browse page. This is upstream behavior, but it may intercept touches on some versions.
- `uYouPlus.xm` `_ASDisplayView -didMoveToWindow` calls `removeFromSuperview` on Texture-managed views (Hide Comments / Channel links). This is upstream and works, but it is a known source of layout glitches.
- `FixPlayback.xm` `UYTFixIsPlayerPath` uses `containsString:@"/player"`, so it also rewrites `/player/heartbeat` and similar paths. This may be intended.
- Speed persistence (#14): if YouTube itself calls the overlay's `setPlaybackRate:1.0` on every new video, persistence across videos will stop working. That is acceptable compared with being stuck, but test it.

## Verification

- Every `.xm`/`.m` passed a structural check (balanced `%hook`/`%group`/`%end`, `%orig`/`%new` only inside hooks, balanced braces). The same check was run on the original as a baseline.
- **Not compiled.** Building needs macOS with Theos (or the GitHub Actions workflow), the iOS SDK, the git submodules, and a decrypted YouTube IPA. See `CLAUDE_CODE_BRIEF.md`.
