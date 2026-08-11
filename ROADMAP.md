# Roadmap

## Google Play

- [x] Set the permanent Android application ID to `com.AIO.goblinFlip`.
- [x] Configure API 36, release signing, and guarded App Bundle builds.
- [x] Validate the game on a physical Android device.
- [ ] Create the Play Console listing, screenshots, and content rating.
- [ ] Configure the `goblin_flip_1000_flips` one-time product and rewarded ad
      unit.
- [ ] Decide and record the release network posture. Billing, ads, and the
      verification service all require `android.permission.INTERNET`, which
      `test/release_configuration_test.dart` currently asserts is absent.
      Change that expectation deliberately, not as a side effect of wiring a
      provider.
- [ ] Connect Google Play Billing and AdMob rewarded ads to the verification
      service below.
- [ ] Write the privacy policy and data-safety declaration after the backend and
      AdMob are connected, so it describes what is actually collected. The game
      today has no network permission and sends nothing off device, so filing
      this first would mean filing it twice.
- [ ] Establish versionCode handling before the first upload. `pubspec.yaml` is
      at `1.0.0+1` and Play rejects a repeated versionCode, so every internal,
      closed, and production upload needs a fresh build number.
- [ ] Complete internal and closed-track testing across supported phone sizes.
- [ ] Submit the production release to Google Play.

## Purchase verification service

`docs/commerce_security.md` specifies this service, and the client contract in
`lib/commerce_receipt_validator.dart` already assumes it exists. It is the
largest remaining piece of work in the project, so it is tracked here rather
than folded into a single Google Play checkbox.

- [ ] Stand up the serverless service and its secret manager.
- [ ] Implement `verify-purchase`: verify the StoreKit JWS or Play purchase
      token directly with Apple or Google, require product
      `goblin_flip_1000_flips` and a completed purchase state, atomically record
      the transaction ID, then acknowledge or consume the purchase.
- [ ] Implement `admob-ssv`: verify the callback signature, validate the ad unit,
      custom data, and reward amount, and atomically record the reward ID.
- [ ] Make the service database the authoritative replay ledger. The local
      receipt list stays an idempotency convenience, not the source of truth.
- [ ] Replace `DebugFlipPurchaseService` and `DebugRecoveryAdService` with
      release providers that return `trustedServer` receipts.
- [ ] Extend `test/commerce_security_test.dart` to cover pending, cancelled,
      duplicate, and network-failure outcomes from the real providers.

## Apple platforms

- [x] Set the Apple bundle identifier to `com.AIO.goblinFlip`.
- [ ] Validate the responsive interface on iPhone and iPad simulators.
- [ ] Configure the signing certificate and provisioning profiles on macOS.
- [ ] Connect StoreKit purchases and the iOS rewarded-ad provider.
- [ ] Verify Keychain persistence, interrupted purchases, and restore flows.
- [ ] Add App Store privacy disclosures, screenshots, metadata, and review
      notes.
- [ ] Complete TestFlight testing and submit to the App Store.

## Quality

- [x] Add accessibility labels and larger-text layout coverage.
      `test/accessibility_test.dart` asserts screen-reader labels and selection
      state for the wager and charm menus, and that both survive a doubled text
      scale on a 320-point phone.
- [ ] Add crash reporting only after privacy and data-retention policies are
      finalized.
- [ ] Profile animation, startup, memory, and battery use on low-end hardware.
