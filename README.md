<img src="site/assets/icon.png" alt="" width="96" height="96">

# Petit Café

A small macOS menu-bar app that keeps your Mac awake. Order a café, and it turns itself off when the time is up. It is `caffeinate`, from the menu bar.

**→ [Website](https://petitcafe.view.fast/)**: the download there always points at the latest release.

**Requires a Mac with Apple silicon and macOS 26 (Tahoe) or later. There is no Intel build. Unsigned: no Apple Developer Program needed.**

---

## For users

### What it does

Click the cup in the menu bar and order from the carte:

| Café | Keeps your Mac awake for |
| --- | --- |
| Expresso | 15 minutes |
| Noisette | 30 minutes |
| Allongé | 1 hour |
| Double | 2 hours |
| Grand crème | 5 hours |
| À volonté | Indefinitely |

- **Right-click for À volonté.** Right-click the cup to keep the Mac awake indefinitely without opening the menu. Right-click again to switch it off.
- **Notifications.** A macOS notification confirms each café as it starts and tells you when your Mac can sleep again. macOS asks for permission the first time.
- **Updates.** About Petit Café shows the version and checks GitHub Releases for a new one. It can check automatically on launch, and installs an update in place, no drag-and-drop.
- **It turns itself off.** A timed café ends on its own, so the Mac is never left awake by accident. Order the same café again to switch it off early.
- **Launch at Login.** On by default once the app is in your Applications folder. It is the one option, in the same menu.
- **One menu.** No settings window, nothing to set up. A steaming cup in the menu bar means it is on; a cup without steam means your Mac can sleep.

It uses the same kind of power assertion as the built-in `caffeinate` command, and keeps the display awake too. No analytics, no account. The only network request is the update check against GitHub Releases, which you can turn off in the About window.

### Install

The app is unsigned, so macOS blocks it on first launch. To allow it:

1. Open the disk image and drag **Petit Café** to Applications.
2. Double-click it. When macOS warns it "can't verify the developer," click **Done** (not "Move to Trash").
3. Open **System Settings → Privacy & Security**, scroll to the **Security** section, and click **Open Anyway**.

macOS only asks once. After that, look for the cup in your menu bar.

---

## For developers

### Requirements

- An Apple silicon Mac, macOS 26 (Tahoe)+, Xcode 26+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`), run in the build phase when installed
- [create-dmg](https://github.com/create-dmg/create-dmg) (`brew install create-dmg`), only for packaging

### Layout

- `PetitCafeKit/`: a pure Swift package with all the logic and the tests.
- `App/`: the SwiftUI menu-bar app, generated from `App/project.yml` with xcodegen.
- `site/`: the website, one static `index.html`.
- `scripts/`: `make-dmg.sh` and `make-icon.swift`.
- `App/Icon/petit-cafe-glyph.svg`: the cup glyph every icon is rendered from.

### Test

```sh
cd PetitCafeKit && swift test
```

### Build and run

```sh
cd App && xcodegen
xcodebuild -project PetitCafe.xcodeproj -scheme PetitCafe -destination 'platform=macOS' build
```

### Package a DMG

```sh
./scripts/make-dmg.sh
```

The DMG lands in `dist/`.

## License

[MIT](LICENSE)
