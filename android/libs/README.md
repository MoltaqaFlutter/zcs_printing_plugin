# ZCS SDK AAR files (required for plugin build)

Place the ZCS SDK AAR file(s) here. This is the **only** place the AAR is required; apps that use the plugin get the SDK transitively.

- **Required:** `SmartPos_2.0.1_R251024.aar`
- Optional: `emv_2.0.1_R251023.aar` (EMV; not used by this plugin)

The plugin’s `build.gradle` uses `implementation fileTree(dir: 'libs', include: ['*.jar', '*.aar'])`. Without at least the SmartPos AAR in this folder, `flutter build apk` (or building the plugin from source) will fail with unresolved references (e.g. `PrnTextFont`, `PrnStrFormat`).

Consuming apps do **not** need to add the AAR in their own project.
