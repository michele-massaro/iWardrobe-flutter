# Task 005 — PreferencesService & app bootstrap

| | |
|---|---|
| **Phase** | 2 — Data layer |
| **Depends on** | 001 |
| **Primary references** | [Architecture](../architecture.md) §Tech stack, §Navigation & routing (Onboarding gate) · [Functional specification](../functional-specification.md) FR-1.6, FR-1.7, FR-10.5 |

## Objective

Deliver the two device-local persistence seams the rest of the app leans on: `PreferencesService` (a stateless wrapper over `shared_preferences`) and the `appBootstrap` object that is loaded **before** `runApp` so the router's redirect can read the onboarding flag without a provider lookup.

## What the agent must deliver

### 1. `lib/data/services/preferences_service.dart`

Stateless wrapper (knows nothing about the domain):

- `Future<bool> getOnboardingCompleted()` / `Future<void> setOnboardingCompleted(bool)` — FR-1.7: the flag persists across app restarts and device reboots.
- `Future<DateTime?> getLastSyncAt()` / `Future<void> setLastSyncAt(DateTime?)` — FR-10.5: each device records **its own** last successful sync (this value is never synchronized — iCloud sync doc §4 "What is not synchronized").
- Storage: `shared_preferences` with stable, documented key names (e.g. `onboarding_completed`, `last_sync_at` as UTC milliseconds).

### 2. `lib/app/bootstrap.dart` — the `appBootstrap` object

- A small final class holding the values loaded once during bootstrap (v1: `onboardingCompleted`); per the Architecture doc it exists so route evaluation needs no provider lookup.
- `Future<AppBootstrap> loadAppBootstrap({required PreferencesService preferences})` — reads the flag and returns the object. The future is awaited in `main.dart` before `runApp` (wired in task 013; here you deliver the load function and its tests).
- The onboarding-completed flag is **device-local by design**: it is never part of the sync payload (each install presents onboarding once — iCloud sync doc §12).

## Definition of done

**Build** (standard gate): all items of the standard build gate pass.

**Unit test constraints** — `test/data/preferences/`:

- [ ] Onboarding flag: unset → `false`; after `setOnboardingCompleted(true)` a **new service instance** (fresh `SharedPreferences` handle / cleared store) still reads `true` (restart semantics, FR-1.7).
- [ ] Last-sync timestamp: `null` before the first set; set → retrieved value equals the stored UTC instant (round-trip at second precision).
- [ ] Independence: writing the sync timestamp does not affect the onboarding flag and vice versa.
- [ ] `loadAppBootstrap`: returns `onboardingCompleted == true` when the flag is set, `false` otherwise; does not require any Flutter widget binding.
- [ ] Determinism: tests run on the test platform (no real device store), using `shared_preferences`' in-memory/test setup.

**Functional acceptance**

- [ ] No domain model types referenced (raw `bool`/`DateTime?` only).
- [ ] Key names are constants, not scattered string literals.

**Out of scope for this task:** the router redirect itself (task 013), `AppViewModel` (task 013), any sync logic (task 010).
