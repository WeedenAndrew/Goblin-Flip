# Roadmap

## Google Play

- [x] Set the permanent Android application ID to `com.AIO.goblinFlip`.
- [x] Configure API 36, release signing, and guarded App Bundle builds.
- [x] Validate the game on a physical Android device.
- [ ] Create the Play Console listing, screenshots, privacy policy, content
      rating, and data-safety declaration.
- [ ] Configure the `goblin_flip_1000_flips` one-time product and rewarded ad
      unit.
- [ ] Connect Google Play Billing, AdMob rewarded ads, purchase verification,
      and AdMob server-side verification.
- [ ] Complete internal and closed-track testing across supported phone sizes.
- [ ] Submit the production release to Google Play.

## Apple platforms

- [ ] Validate the responsive interface on iPhone and iPad simulators.
- [x] Set the Apple bundle identifier to `com.AIO.goblinFlip`.
- [ ] Configure the signing certificate and provisioning profiles on macOS.
- [ ] Connect StoreKit purchases and the iOS rewarded-ad provider.
- [ ] Verify Keychain persistence, interrupted purchases, and restore flows.
- [ ] Add App Store privacy disclosures, screenshots, metadata, and review
      notes.
- [ ] Complete TestFlight testing and submit to the App Store.

## Quality

- [ ] Add accessibility labels and larger-text layout coverage.
- [ ] Add crash reporting only after privacy and data-retention policies are
      finalized.
- [ ] Profile animation, startup, memory, and battery use on low-end hardware.
