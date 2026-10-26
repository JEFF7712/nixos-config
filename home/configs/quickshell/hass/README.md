# hass

Home Assistant control for the Quickshell bar, ported from
[konradk/hass](https://github.com/konradk/hass) (`v0.5.0`, MIT, see LICENSE).
Upstream is an Omarchy 4 plugin; the transport (`bin/hass-bridge`, packaged
as `pkgs/hass-bridge`) and the pure state modules (`Service.qml`,
`Model.js`, `EntityStore.js`, `ConfigStore.js`, `RowModel.js`,
`Connection.js`, `PanelState.js`, `BridgeController.qml`,
`CredentialManager.qml`) are used as-is. The Omarchy shell UI
(`Panel.qml`, `Settings.qml`, `SettingsEntityRow.qml`,
`EntityRow.qml`, `RoomReadingsCard.qml`, `controls/`) is NOT used; the bar
renders `../HassPopup.qml` instead, in this repo's popup style.

NixOS adaptations:

- `Service.qml`: config lives at `~/.config/hass/config.json` (was
  `~/.config/omarchy/hass`); bridge runs as `hass-bridge` from PATH
  (was `$pluginDir/bin/hass-bridge`)
- `Connection.js`: `parseNmcliActiveSsid` renamed to `parseTerseActiveSsid`
  with the tool name out of comments — this repo forbids the `nmcli`
  string anywhere under `home/configs/quickshell`
- `Panel.qml`, `Settings.qml`, `SettingsEntityRow.qml` are not vendored
  here; pristine copies live in `home/configs/hass-upstream/` as rewrite
  reference (kept out of the scanned tree: upstream `Settings.qml`
  constructs its own `nmcli` call)

Setup: the keyring holds the token (service `hass`, origin
`https://ha.rupan.dev:443` — note the explicit port, that is the plugin's
normalized origin form). `~/.config/hass/config.json` carries only the URL:

```json
{ "baseUrl": "https://ha.rupan.dev" }
```

Store a new token with:

```fish
printf '%s' '<long-lived-token>' | secret-tool store --label='Home Assistant' service hass origin 'https://ha.rupan.dev:443'
```

The popup header opens setup (URL, token, local URL, trusted Wi-Fi, demo
mode, retry, remove). Star devices from the devices tab to build favorites.
The Topbar pill shows the count of entities currently on, accent when
connected; right-click refreshes.

Deliberately v1: no color wheel / color-temp controls, no climate
fan/preset/swing selectors, no room-reading expanded cards, no keyboard
navigation or keybind IPC (the bar has no shell IPC surface for that yet).
