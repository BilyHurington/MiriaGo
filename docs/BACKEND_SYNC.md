# Backend sync log

The backend (everything under `lib/` except `lib/ui/**`, `lib/application/**`
and `lib/main.dart`), native projects (`android/`, `ios/`), `src-tauri/`,
`web/`, `tool/`, bundled assets and the logic tests were imported verbatim
from the old repository:

- Source: `Seichi-Junrei-Helper`, branch `codex/pre-2-release-hardening`
- Base commit: **849fd9a** (`fix(export): escape formula-like +/- cells in My Maps CSV`)
- Import commit here: `48487e1`

To sync later fixes from the old repo, diff the old repo from `849fd9a`
to its new HEAD restricted to backend paths and apply the patch here (paths
are identical).

## Files removed here (old UI)

All screens/sheets/dialogs and UI-only widgets of the old app, plus 39
UI-coupled test files (see commit `e3a81ca`). Their behaviour is re-created
in `lib/ui/**` and `lib/application/**`.

## Intentional divergences from 849fd9a

| File | Change | Reason |
|---|---|---|
| `lib/main.dart` | rewritten | new app bootstrap |
| `pubspec.yaml` | new UI dependencies, Inter font, font license asset | new UI |
| `src-tauri/tauri.conf.json` | window 1280×800 (min 360×560 unchanged); devUrl port 8792 | desktop uses wide layouts; preview port |
| `tool/web_preview_server.mjs` | default port 8792 | avoid clashing with the old preview (8791) |
| `android/app/build.gradle.kts` | opt-in `miriagoApplicationIdSuffix` / `miriagoAppLabel` Gradle properties (defaults unchanged) | install Next next to the old app for testing |
| `android/app/src/main/AndroidManifest.xml` | `android:label="${appLabel}"` placeholder (default `MiriaGo`) | same |

`lib/app_theme.dart` is kept unchanged as a legacy module because backend
map helpers read `AppColors.*`; the new UI keeps it in sync through
`SettingsStore`.
