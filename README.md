# Hex for SideStore

Unofficial builds of the [Hex](https://github.com/anomalyco/hex) iOS app, packaged so
[SideStore](https://sidestore.io) can install it with a free Apple ID. Not affiliated with
or endorsed by the Hex developers. Report problems with these builds here, not upstream.

A GitHub Actions workflow checks upstream's `dev` branch every day. When the iOS code
changes, it builds a new unsigned `.ipa`, attaches it to a release, and adds it to
[`source.json`](source.json). SideStore then offers it as an update.

## Install

1. Set up SideStore on your iPhone by following [its install guide](https://docs.sidestore.io).
2. In SideStore, open **Sources**, tap **+**, and add:

   ```text
   https://raw.githubusercontent.com/kyeshmz/hex-sidestore/main/source.json
   ```

3. Install **Hex** from that source. If SideStore offers to remove app extensions, keep
   them: the keyboard and the Live Activity widgets are extensions.
4. Go to Settings › General › Keyboard › Keyboards › Add New Keyboard, add **Hex
   Keyboard**, and turn on **Allow Full Access**. The keyboard needs Full Access to talk
   to the Hex app.

Free Apple IDs can have 3 sideloaded apps active at once (SideStore counts as one) and
register 10 App IDs a week. Hex uses 3 App IDs: the app, the keyboard, and the widgets.
SideStore re-signs apps before their 7-day free signature expires.

## What's different from upstream

SideStore signs the app under your Apple team, and that changes its identifiers: the App
Group becomes `group.com.kitlangton.hex.mobile.<TEAMID>` and the bundle IDs get your team
ID appended. Upstream hardcodes both, which would leave the keyboard unable to reach the
app. [`scripts/patch-upstream.sh`](scripts/patch-upstream.sh) makes two lines resolve them
at runtime instead:

- `KeyboardBridge.appGroup` reads the App Group from the app's embedded provisioning
  profile ([`SideloadAppGroup.swift`](scripts/SideloadAppGroup.swift)).
- `KeyboardSetupMonitor.keyboardBundleID` derives the keyboard's ID from the installed
  app's bundle ID.

If upstream changes either line, the build fails instead of publishing a broken keyboard.

The app is built with `CODE_SIGNING_ALLOWED=NO`, then ad-hoc signed with upstream's
entitlements so SideStore can see which App Group to register. Each build's version is
`<upstream major.minor>.<upstream commit count>`, so every build counts as an update.

## Build it yourself

You need Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
git clone -b dev https://github.com/anomalyco/hex.git upstream
scripts/build-ipa.sh upstream Hex.ipa 0.2.0 1
```

To rebuild in CI without an upstream change, run the workflow from the Actions tab with
**force** checked.

## License

Hex is MIT-licensed, © 2026 Christopher Langton. Each release includes upstream's
`LICENSE` and `THIRD_PARTY_NOTICES.md`.
