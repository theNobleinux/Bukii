# Bukii

Book local services in seconds, and give every business its own website.

Flutter app (Android, iOS, Web) with a Supabase backend.

## Documentation

| Doc | For |
|---|---|
| [docs/BACKEND.md](docs/BACKEND.md) | Full backend guide: auth, tables, booking engine, website generator, API, security, testing, deployment |
| [supabase/README.md](supabase/README.md) | Quick reference: tables, RPCs, test logins |

## Try it

- **Web preview:** https://thenobleinux.github.io/Bukii/
- **Test customer:** phone `800 000 0002`, code `123456`
- **Test business owner:** phone `800 000 0001`, code `123456`

## Run locally

```bash
flutter pub get
flutter run
```

## Checks

```bash
flutter analyze
flutter test
```

Database tests: paste `supabase/tests/engine_test.sql` and
`supabase/tests/website_test.sql` into the Supabase SQL Editor and run. Every line
should start with `ok`.
