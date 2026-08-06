# Release readiness

The local game does not need store accounts or production service credentials yet.
Before the first Android or iOS store build:

1. The permanent Android and iOS identifier is `com.AIO.goblinFlip`, and the
   store/display name is `Goblin Flip`. Do not change the identifier after the
   first store upload.
2. Run `Create Upload Key.cmd` once. It creates the Android upload key outside
   the project, copies the ignored `android/key.properties` template, and opens
   it for the password you selected. Back up both the keystore and its password
   securely; neither Google nor the project can recover them.
3. Create the corresponding App Store signing identity and provisioning profile
   on a Mac when iOS packaging begins.
4. Add payment and advertising identifiers only after the provider accounts exist.
   Keep secret or environment-specific values out of source control.
5. The licensed forest soundtrack and Google font files are bundled locally.
   Release builds intentionally have no network permission until real payment
   and advertising providers are connected.

Current safeguards:

- Android release builds never fall back to the debug signing key.
- Android application backups are disabled so encrypted local game state is not
  restored without its matching device-bound key.
- Android's release manifest has no network permission while the game has no live
  payment or advertising integration.
- Cleartext Android traffic is disabled, and the project explicitly compiles
  and targets API 36 with the plugin-compatible NDK version.
- iOS release and profile builds include the keychain entitlement required by the
  secure-storage layer.

## Play Store bundle

`Build Play Bundle.cmd` creates the `.aab` required by Google Play, but refuses
to run unless `com.AIO.goblinFlip` is present and the upload signing file exists.
The script restores packages, runs static analysis and the complete test suite,
then builds a signed release bundle.

Upload the first bundle to an internal testing track. Do not move directly from
a local debug APK to production.

## Local Android build

Run `Build Android APK.cmd` from the project folder. It restores packages, runs
the complete test suite, and creates:

`build\app\outputs\flutter-apk\app-debug.apk`

This debug artifact uses the permanent application identifier with Android's
debug signing identity. Once installed, it runs directly from the phone without
a cable, computer, browser, or network connection.
After it builds, run `Install Android APK.cmd` with an emulator running or an
authorized USB-debugging phone connected. Choose the Android device ID printed
by Flutter; Chrome and Windows device IDs are not valid installation targets.
