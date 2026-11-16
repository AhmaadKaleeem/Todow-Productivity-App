# Adopted build rules

## Verification commands

- `flutter test` runs the repository's Flutter unit and widget tests. It is listed in the README's test instructions.
- `flutter analyze` runs Dart and Flutter static analysis. It is listed in the README's test instructions.

## Change layers

1. **Feature** owns task-entry implementation, its tests, speech dependencies, and required Android and iOS permissions. It runs `flutter test` and commits as `feat(tasks): add voice dictation`.
2. **Join** owns product documentation and runs `flutter test && flutter analyze` across the repository. It is exclusive and scoped to `**`, so it catches cross-cutting failures after the feature layer. It commits as `docs(tasks): document voice dictation`.

The feature layer precedes the join so product documentation is written only after the task implementation and its tests pass. The repository has no workspace package graph or other declared package boundary to model.

## Excluded work

This adoption does not migrate the Flutter stack or review legacy code. Only new change-work enters the build graph; existing code remains outside its coverage.

## Repo shape, as of adoption

Snapshot read on 2026-11-17 at `feature/voice-to-task`, commit `ee66f64`.

Todow is a Flutter application. Dart source is under `lib/`, tests are under `test/`, and platform projects are under `android/` and `ios/`. Domain models and repository contracts live under `lib/domain/`; local SQLite implementations and device services live under `lib/data/`; screens, providers, and feature controllers live under `lib/presentation/`. Task UI and task-specific widgets are grouped under `lib/presentation/features/tasks/`. The app uses Riverpod and Provider, and stores task data locally with SQLite. Recent commits use Conventional Commit subjects. No enforced package dependency direction was observed (`pattern: none`): there is no workspace package manifest or declared package graph.

This is a dated snapshot, not a live architecture model. Refresh it by rerunning the adopted-core intake; do not edit this section by hand.
