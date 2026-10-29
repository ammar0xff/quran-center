# Architecture — Quran Memorization Center Management System

## 1. Overview

One Flutter mobile application (Dart, null safety) serving three roles — teacher, student, director — from a single installed binary. Firebase (Auth, Firestore, Cloud Functions, FCM, App Check, Storage optional) is the shared backend. The app is Arabic-first with full RTL support.

## 2. High-level architecture

```
lib/
  main.dart                 - Entry point. Initializes Firebase, then App.
  bootstrap.dart            - Firebase + provider container setup.

  app/
    app.dart                - MaterialApp, theme, localization, router.
    router.dart             - GoRouter declarative routes + route guards (auth/role).
    app_lifecycle.dart      - App state lifecycle (auth state changes, sign-out cleanup).

  core/
    auth/                   - Firebase Auth wrapper, session restore, sign-out.
    authorization/          - Role resolution from trusted profile + custom claims.
    config/                 - Environment / Firebase config.
    errors/                 - App exceptions, Arabic error messages, error UI.
    firebase/               - Firebase service abstractions (Firestore, FCM, Storage).
    localization/           - l10n setup, Arabic strings.
    logging/                - Structured logging + Crashlytics integration.
    network/                - Connectivity monitoring.
    offline/                - Local queue, outbox, sync engine, Drift/SQLite.
    permissions/            - Feature/permission guards.
    theme/                  - Design tokens, light/dark theme, Arabic typography.
    utils/                  - Helpers (date, timezone, surah/ayah validation).
    validation/             - Domain form validators (email, ayah range, etc.).

  design_system/
    tokens/                 - Colors, spacing, radius, elevation, animation.
    typography/             - Arabic font scale, line heights.
    icons/                  - Custom icon set (non-mirrored where semantics fixed).
    components/             - Reusable premium widgets (buttons, fields, cards, chips...).
    animations/             - Route/page transitions, feedback animations.
    layouts/                - Shell layouts, app bar, bottom nav, drawer.

  features/
    authentication/         - Splash, login, forgot password, pending/suspended.
    teacher/                - Dashboard, circles, students, sessions, attendance, memorization...
    student/                - Dashboard, tasks, progress, attendance, schedule, feedback...
    director/               - Dashboard, students, teachers, circles, reports, announcements, settings...
    shared/                 - Student profiles, circles, schedules, notifications (cross-role).

  data/
    models/                 - Strongly typed immutable models + fromJson/toJson.
    repositories/           - Repository interfaces + Firestore implementations.
    datasources/            - Firestore/remote + local data sources.
    services/               - Business services (sync, provisioning, reports).

  routing/                  - Route constants, guard logic.
  l10n/                     - ARB localization files.

test/ unit, widget
integration_test/
```

## 3. Layer boundaries

- **Presentation (UI widgets)**: reads state via Riverpod providers, never calls Firestore directly.
- **Application/business logic (services/providers)**: orchestrates use cases, validation, offline queue.
- **Data access (repositories/datasources)**: Firestore queries, local DB, idempotent writes.
- **Domain models**: immutable classes, JSON serialization, enum state machines.

## 4. Authentication & role resolution flow

1. `main.dart` initializes Firebase + App Check.
2. Splash screen restores Auth session.
3. No session → login. Session → load authoritative `users/{uid}` profile.
4. Verify active status + center membership; resolve role from profile + custom claims (never client-trusted).
5. Load role-specific shell; fetch only permitted data.
6. Suspended/incomplete → recovery path, no privileged data.

## 5. Offline strategy

- Firestore offline persistence for read caching.
- Drift/SQLite durable outbox for critical writes (attendance, assessments).
- Transactional outbox with idempotency keys, retry, conflict detection.
- Visible sync status: saved locally / waiting / syncing / synced / conflict / failed.
- Never label an unsynchronized write as server-confirmed.

## 6. Security

- Firestore Security Rules enforce least privilege (backend, not frontend).
- Cloud Functions (TypeScript) perform their own authorization (Admin SDK bypasses rules).
- Firebase App Check; rate limiting; secure account provisioning via callable functions.
- Audit log collection; no secrets in client; no hardcoded credentials.

## 7. Design system

Light mode first. Tokens: primary `#174C3C`, deep `#10382E`, mint `#E6F1EA`, off-white `#FAF9F6`, text `#202923`, secondary `#6B756E`, borders `#E3E7E2`, success `#237A4B`, warning `#B7791F`, error `#B42318`, info `#245DB5`. Arabic font (IBM Plex Sans Arabic / Noto Sans Arabic). RTL throughout. 48dp touch targets. Motion for comprehension, not decoration.

## 8. Tech stack (documented versions in pubspec.yaml)

- Flutter stable, Dart null safety
- flutter_riverpod (state/DI)
- go_router (navigation)
- cloud_firestore, firebase_auth, firebase_messaging, firebase_app_check, firebase_crashlytics
- drift + sqlite3_flutter_libs (local queue)
- intl, flutter_localizations (Arabic l10n)
- Equatable/freezed (models)
- flutter_test, integration_test, mockito (tests)

## 9. Phases

1. Repository inspection & planning (this doc set)
2. Design system & foundation (bootstrap, Firebase, routing, auth, role resolution, theme, shared components, Security Rules, emulator)
3. Core data & security (models, repositories, queries, Security Rules, provisioning, students, circles, enrollment, schedules, audit logging; tests first)
4. Director core workflows
5. Teacher core workflows
6. Student self-service
7. Reports & notifications
8. Offline reliability
9. Hardening & release