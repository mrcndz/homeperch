<div align="center">

# 🏠 HomePerch

**Home Assistant control, perched in your macOS menu bar.**

![Platform](https://img.shields.io/badge/platform-macOS%2014+-blue)
![Swift](https://img.shields.io/badge/Swift-5.10-orange)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

A tiny, native menu bar app for toggling lights, switches, and checking sensors from your [Home Assistant](https://www.home-assistant.io) instance. No Electron, no dashboard tab, just a click on the menu bar.

## Features

- ⚡ **One-click toggles**: click a row to switch a light or outlet, with instant optimistic UI (no waiting for the device to respond)
- ⭐ **Favorites**: pin the entities you actually use; the popover opens straight on them
- ✏️ **Custom names and icons**: rename `switch.tomada_da_sala_switch_1` to "Living Room Outlet" and give it any SF Symbol icon
- 🌡️ **Sensors**: temperature and other sensor values shown as badges
- 🗂️ **Filter chips**: browse by favorites or entity domain
- 📄 **Dotfile config**: everything lives in a plain `~/.homeperch` file, dotfiles-friendly
- 🪶 **Native and tiny**: pure SwiftUI, a single ~500 KB binary, no Dock icon

## Install

**Download**: grab `HomePerch.app.zip` from the [latest release](https://github.com/mrcndz/homeperch/releases/latest), unzip, and move `HomePerch.app` to `/Applications`. The app is not notarized, so on first launch right-click it and choose **Open** (or run `xattr -d com.apple.quarantine /Applications/HomePerch.app`).

**Or build from source** (needs Xcode command line tools, macOS 14+):

```sh
git clone https://github.com/mrcndz/homeperch.git
cd homeperch
./make-app.sh          # builds HomePerch.app
cp -r HomePerch.app /Applications
```

Add it to **System Settings → General → Login Items** to start it at login.

## Configure

Create `~/.homeperch`:

```ini
ha_base_url=https://your-home-assistant.example
ha_api_key=<long-lived access token>
```

Get the token in Home Assistant under **Profile → Security → Long-lived access tokens**. Favorites, custom names, and icons are managed from the app's Settings window and saved to the same file.

> **Note**: the token is stored in plaintext; consider `chmod 600 ~/.homeperch`.

## Development

```sh
swift run              # run from source
swift build            # just compile
```

It's a plain Swift Package, `Package.swift` opens directly in Xcode.

## License

MIT
