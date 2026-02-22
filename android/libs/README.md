# ZCS SDK AAR files (required for plugin build)

Place the ZCS SDK AAR file(s) here so the **plugin** compiles:

- **Required:** `SmartPos_2.0.1_R251024.aar`
- Optional: `emv_2.0.1_R251023.aar` (EMV; not used by this plugin)

The plugin’s `build.gradle` uses `compileOnly fileTree(dir: 'libs', include: ['*.jar', '*.aar'])`, so without at least the SmartPos AAR in this folder, `flutter build apk` (or building the plugin from source) will fail with unresolved references (e.g. `PrnTextFont`, `PrnStrFormat`).

If you are building an app that uses this plugin, you still need to add the same AAR(s) to your **app’s** `android/app/libs/` and `implementation fileTree(...)` in your app’s `android/app/build.gradle` for runtime.
