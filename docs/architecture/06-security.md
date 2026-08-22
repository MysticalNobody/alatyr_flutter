# 06 — Security

One rule underlies this page: runtime secrets have exactly one home
(`data_secure`), and public build-time configuration has exactly one
mechanism (`.dart-defines/`). Neither is allowed to substitute for the
other.

## The `.dart-defines/` scheme

`.dart-defines/<name>.env.example` is committed; `.dart-defines/<name>.env`
is gitignored and never leaves the developer's machine. Only **public
client values** belong in either file — an API base URL, an environment
name — never a token, key, or credential:

```
APP_ENV=dev
API_BASE_URL=https://api.example.invalid
```

Running the app passes the real file explicitly:
`flutter run --dart-define-from-file=.dart-defines/dev.env`. Values are
read at compile time via `String.fromEnvironment` in `AppConfig`, which
validates them (`config.invalid-env`, `config.invalid-url`) rather than
trusting the raw strings.

## `data_secure` — the only home of runtime secrets

Every runtime secret goes through the `SecureStore` port and nowhere else:

- `FlutterSecureStore.platform()` — the production adapter, backed by
  `flutter_secure_storage` (Keychain on iOS/macOS, Keystore on Android,
  libsecret on Linux, DPAPI on Windows, WebCrypto on web).
- `InMemorySecureStore` — volatile, for tests and previews; nothing is
  persisted.

`AppDependencies` constructs `secureStore` in the composition root
alongside every other production dependency ([04](04-composition.md)) even
though no shipped feature consumes it yet — the port exists so the first
feature that needs a secret reaches for it instead of reaching for drift,
shared preferences, or a log line.

## Platform prerequisites this port depends on

- **iOS and macOS** ship `keychain-access-groups` in the app shell's
  entitlements as an empty array — `app/ios/Runner/Runner.entitlements` for
  iOS, `app/macos/Runner/DebugProfile.entitlements` and
  `app/macos/Runner/Release.entitlements` for macOS (both carry the key);
  the App Group name goes in only when App Groups are enabled.
  `DEVELOPMENT_TEAM` is stripped from the iOS project — it is a
  per-developer signing identity, not something a template ships.
- **Linux** needs `libsecret-1-dev` installed and a running secret service
  for `flutter_secure_storage` to have a backend at all.

## The never-in-repo list

Tokens, API keys, refresh credentials, `.env` files (only `*.env.example`
is committed), and signing identities (`DEVELOPMENT_TEAM`, provisioning
profiles, keystores) never land in this repository, in any package, in
any log line, or in drift.

## Enforcement, not just convention

- **`tool/verify_imports.dart`** runs a heuristic secret-leak scan over
  `data_local`'s `lib/`: a token/secret/password/credential-shaped
  identifier there fails the gate (defense in depth, not a semantic
  guarantee — full tracking is a review-owned gap).
- **`.claude/settings.json`** denies **the `Read` tool** on
  `.dart-defines/*.env` — Claude reads the committed `*.env.example` files
  but never a real one through that tool. The deny binds that one tool: a
  shell `cat` is not covered, and Codex has no equivalent rule, so the
  never-in-repo list above (not the deny) is what keeps real secrets out.
