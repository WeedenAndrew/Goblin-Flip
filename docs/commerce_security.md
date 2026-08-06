# Goblin Flip commerce security

## Platform boundary

The `goblin_flip_1000_flips` product is digital game currency. App Store
builds must purchase it through Apple StoreKit, and Google Play builds must
purchase it through Google Play Billing, except where a platform-approved
regional alternative-billing program explicitly applies.

Do not place PayPal Checkout inside the mobile app for this product. Store and
ad-network earnings are paid out through the payout account configured with
Apple, Google Play, or the ad network. PayPal can be considered later for a web
build or an approved alternative-billing program, but a backend must still
capture and verify the order before granting flips.

## Trust model

The app must never grant flips from a bare `true` callback.

- A purchase returns a product ID, quantity, unique transaction ID, verification
  source, and verification time.
- A rewarded ad returns a unique reward ID, verification source, and
  verification time.
- Release builds accept only receipts that the production service obtained from
  the trusted verification backend.
- Debug receipts are accepted only in debug builds.
- Applied transaction and reward IDs are persisted in the encrypted game-state
  ledger. Replaying an ID is rejected.
- Receipt identifiers accept only letters, numbers, `.`, `_`, `:`, and `-`.
  Control characters, path fragments, markup, command-like text, and oversized
  values are rejected before they reach the ledger.
- Pending, cancelled, malformed, mismatched, and unverified results grant
  nothing.

The local receipt ledger makes normal retries and duplicate callbacks
idempotent. It is not a substitute for a server: a modified or rooted client can
patch its own application logic.

## Flip-counter integrity

The flip counter is part of the signed commerce ledger rather than an
independent UI preference.

- Each saved state is wrapped in an HMAC-SHA256 envelope using a random
  256-bit key held in platform secure storage.
- Primary and backup copies must both pass constant-time MAC verification.
- A separately stored monotonic revision head rejects replacement with an
  older, correctly signed balance.
- Before signing a new state, the store reconstructs the expected result from
  the previous state and permits only a known game transition: normal flip,
  verified 1,000-flip purchase, verified ad recovery, wager placement/result,
  power-up purchase, or the matching clear/recharge operation.
- Direct counter edits, unexplained balance jumps, same-revision forks,
  deletion of the signed ledger, and malformed envelopes fail closed instead
  of resetting to a free balance.
- Before the goblin is unlocked, ordinary flips can build the initial balance
  from zero. After the player has reached 50 once, a later zero balance cannot
  restart the free counter; the next tap opens the purchase-only zero-balance
  panel. A fresh launch never recreates the expired ad-recovery offer.

This protects the normal app from edited saves and rollback attempts. A local
key cannot defeat a fully modified/rooted client that patches the validation
code; the production verification backend must remain authoritative for paid
entitlements.

## Minimal production backend

A small serverless verification service is sufficient. It needs two operations:

1. `verify-purchase`
   - Accept the StoreKit transaction/JWS or Google Play purchase token.
   - Verify it directly with Apple or Google.
   - Require product ID `goblin_flip_1000_flips`, a completed purchase state,
     the correct app identity, and an unused transaction ID.
   - Atomically record the transaction and return the authoritative entitlement.
   - Acknowledge or consume the purchase as required by the store.
2. `admob-ssv`
   - Verify the AdMob server-side verification callback signature.
   - Validate the ad unit, custom data, reward amount, and unique transaction ID.
   - Atomically record the reward so the same callback cannot be redeemed twice.
   - Let the app retrieve the verified reward entitlement.

The backend database is the authoritative replay ledger. Keep store credentials,
Apple keys, Google service-account credentials, PayPal secrets, and ad-network
secrets only in the server's secret manager. Never compile them into Flutter,
commit them, place them in assets, or store them in the local encrypted save.

## Failure behavior

- Purchase pending: show pending status and grant nothing.
- Purchase cancelled or verification fails: grant nothing.
- Duplicate transaction or ad reward: return the existing entitlement without
  adding flips again.
- Local save fails after backend verification: retry entitlement synchronization
  rather than charging again.
- Ad closes or fails before verified completion: the loss remains and the
  transient recovery offer is not restored on relaunch.

## Current implementation status

The client contract and local replay protection are implemented. The debug
services generate clearly marked local receipts and are disabled in release
mode. StoreKit/Google Play Billing, AdMob server-side verification, and the
minimal verification backend still need provider accounts and product/ad-unit
configuration before they can be connected.

`test/commerce_security_test.dart` is the adversarial regression suite. Keep
forged product IDs, quantities, debug receipts, malformed reward IDs, replayed
IDs, hostile saved ledgers, and balance-overflow attempts in that file so the
commerce trust boundary remains easy to audit.

`test/game_state_store_test.dart` contains the counter-integrity attacks:
unsigned balance jumps, payload edits with a stale MAC, signed rollback,
ledger deletion, and legitimate transition coverage.
