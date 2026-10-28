![App icon](/images/Icon.png) 
# Idasen Desk Controller – Mac app


This is a Mac Status Bar application for controlling your [IKEA IDÅSEN (Linak) Desk](https://www.ikea.com/au/en/p/idasen-desk-sit-stand-black-beige-s79280979/)

If you find this at least a little bit useful, why don't you help me out by:
* Starring this project
* Shout me a cup of coffee via [PayPal](https://paypal.me/dtw/5)
* Follow me on Twitter [@davidwilliames](https://twitter.com/davidwilliames)


**macOS 13 or later. Runs natively on Apple Silicon without Rosetta.** Build this fork using the instructions below; the original upstream release still contains a legacy Intel-only login helper.

---

![Animated example](/images/example.gif)

![Preferences example](/images/preferences_example.png)



## Why?

The best way I've found to get myself to use my sit/stand desk more; is to remove as much friction around moving it as possible.

The Linak 'Desk Control' mobile app let's you set favourite positions — but then you need to open the app, and press **and hold** the up/down arrow until it get's into position. Having to hold the button the whole time was just a bit annoying for me; and I found myself changing height positions less.

I found a couple of different solutions across Github; but there were no truly Native Mac apps... until now.

I'm already on my Mac when sitting/standing at my desk — so why can't I quickly control the desk from here; without needing to open Linak's Desk Control Mobile app or having to use physical controller?


## Features

* Easy access from the Mac Status Bar
* View current height
* Save sit/stand height positions 
* Move up/down
* Move to sit/stand position without having to hold down the button
* Automatic launch on startup (configurable in preferences)
* Supports AppleScript to interact with it (e.g. via an [Alfred App](https://www.alfredapp.com) workflow)


![Animated example](/images/status_bar_example.png)


## Getting started

* Install the full Xcode app and [just](https://github.com/casey/just), then run `just deploy` from this repository.
* Open `/Applications/Desk Controller.app`.
* The app will appear in your Status Bar. Allow Bluetooth access when prompted.

Other info:
* To access the preferences either right-click on the Status bar icon and click `Preferences` – or after clicking on the icon, click on the settings icon in the bottom right
* To quit the application entirely; right-click on the Status bar icon and click `Quit`


## Building from source

Requires the full Xcode app and [just](https://github.com/casey/just) (`brew install just`).

```sh
just build
just deploy
```

* `just build` builds the complete Release app into `build/Build/Products/Release/Desk Controller.app`. It rejects any embedded Mach-O binary without an `arm64` slice and verifies the app signature.
* `just deploy` builds first, then replaces `/Applications/Desk Controller.app` with the new app bundle. Quit Desk Controller before deploying; deployment does not launch it.
* To install somewhere else, use `just deploy "$HOME/Applications"`.
* Xcode defaults to `/Applications/Xcode.app`; set `DEVELOPER_DIR` if it is installed elsewhere.

These recipes use ad-hoc signing for local use without the original author's signing credentials. The app targets macOS 13 or later and uses Apple's native `SMAppService.mainApp` for launch at login, with no third-party packages or bundled helper executables. The universal main executable also includes Intel support for compatible Macs; Apple Silicon runs its native `arm64` slice without translation.

Builds recreate the output app bundle before linking so old helper files cannot survive an incremental build. The obsolete prebuilt app is no longer checked into this repository. These local builds are not notarized distribution releases; removing Rosetta does not guarantee compatibility with every future macOS release.

### Launch at login and upgrading

Launch at login is now opt-in in Preferences. The checkbox reflects the system's actual registration state; a mixed state marked “pending” means approval is needed. Use **Login Items Settings…** to approve it. Registration failures are shown instead of silently claiming success, and the setting refreshes when returning from System Settings.

When upgrading from the old helper-based app:

1. Quit the old app, then run `just deploy` to replace the complete app bundle.
2. Remove any old Desk Controller/LaunchAtLoginHelper entry from **System Settings → General → Login Items** if it remains listed.
3. Open the new app and explicitly enable launch at login again if desired.

The new app does not execute the old helper or copy its registration state. Existing desk heights, units, calibration, and AutoStand preferences keep their original UserDefaults keys.


## Troubleshooting

* Make sure no other phones / computers currently have one of the 'Desk Control' apps open and connected to your desk, if you do, simply quit that app, and this Desk Controller app should work
* Make sure your Idasen Desk still has the word "Desk" in the name of the device — e.g if you changed its name via Linak's Desk Control mobile app
* If it's still not finding your desk; try resetting your desk. To do this:
    1. Lower your desk as low as it goes
    2. Now once more hold down the physical controller to lower it even more, after a second or 2 it should jump down and up
    3. Now press and hold the 'bluetooth' button on the front of the physical controller, for a few seconds – until the blue light starts blinking
    
---

## Interacting with AppleScript

If you want to interact with your Desk via AppleScript; you can talk directly through the 'Desk Controller' mac app.

This is great for setting up an  [Alfred App](https://www.alfredapp.com) workflow

#### Commands:

`move "to-sit"`: Will move to the saved 'Sitting position'

`move "to-stand"`: Will move to the saved 'Standing position'

`move "up"`: Will move the desk up a tiny bit

`move "down"`: Will move the desk down a tiny bit

`move to "120cm"`: Will move the desk to a height of 120cm

`move to "55in"`: Will move the desk to a height of 55 inches

`move to "80"`: Will move the desk to a height of either 80cm or 80in depending on your preferences


So you may have an AppleScript script that looks like this:
``` AppleScript
tell application "Desk Controller"
    move "to-sit"
end tell
```

