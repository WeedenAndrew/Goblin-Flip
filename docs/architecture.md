# Goblin Flip architecture

Goblin Flip keeps authoritative game rules separate from presentation and
external commerce providers.

## Responsibilities

- `lib/main.dart` is the deliberately small executable entrypoint.
- `lib/goblin_flip_app.dart` owns dependency injection and coordinates
  scene-level state, animation timing, persistence, and navigation.
- `lib/commerce_catalog.dart` is the single source of truth for store product
  identifiers and granted quantities.
- `lib/game_state.dart` is the authoritative game model. Balance, wager,
  recovery, and power-up changes must be expressed as validated `GameState`
  transitions.
- `lib/game_state_store.dart` encrypts, signs, backs up, and restores local
  state.
- `lib/game_state_transition_validator.dart` rejects persisted balance or
  receipt changes that cannot be explained by a legitimate game transition.
- The purchase and rewarded-ad service files define narrow provider boundaries.
  Debug providers cannot produce release-authorized rewards.
- `lib/audio/` owns playback policy and procedural interaction cues. Muting
  affects background music and goblin voice, never wager result cues.
- `lib/presentation/` contains scene composition and reusable visual elements.
  Presentation widgets receive values and callbacks; they do not write the
  ledger directly.

## Presentation modules

- `game_scene.dart`: layers the forest, goblin, table, coin, menus, and effects.
- `visual_skins.dart`: the single edit point for swappable surface artwork,
  panel insets, and text colors.
- `audio_controls.dart`: the scene-level music and goblin-voice mute control.
- `coin_effects.dart`: coin rendering, wager piles, counter, and rollback haze.
- `goblin_overlays.dart`: goblin introduction and recovery overlays.
- `wager_controls.dart`: quick-bet foundation and wager entry controls.
- `powerup_status.dart`: active power-up indicators.
- `speed_flip_dialogs.dart`: Speed Flip selection and result sequence.
- `scroll_panels.dart`: shared fantasy scroll surfaces and menu launchers.
- `wizard_shop.dart`: Wizard's Charms catalog and purchase actions.
- `wager_sheet.dart`: full wager form and side selection.

## Change rules

1. Keep balance changes inside `GameState`; UI callbacks should request a
   transition rather than mutate a counter.
2. Persist security-sensitive transitions before presenting them as complete.
3. Treat pending wagers and Speed Flips as resumable records until their final
   state is safely stored.
4. Verify provider evidence before crediting an ad reward or purchase.
5. Derive scene interactivity from the shared busy-state policy so controls do
   not disagree about whether an action is safe.
6. Add a regression test for every new balance path, interruption boundary, or
   provider result.
