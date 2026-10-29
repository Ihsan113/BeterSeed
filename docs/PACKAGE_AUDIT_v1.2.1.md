# BetterSeed v1.2.1 — Complete Clean ZIP Audit

The earlier distribution archive accidentally omitted the entire `native/android/` folder. This repack includes all five Kotlin integration files, 17 widget resources, and the three Theme Pack standard reference documents.

No app source logic or signing code was changed; app version remains `1.2.1+32`.

The ZIP uses the repository root as its top level, and includes `.github/workflows/android-apk.yml`.

The permanent signing keystore and passwords are not stored in the repository or archive; configure GitHub Actions Secrets/Variable as documented.

Python signing configuration tests, visual asset checks, and native source checks were run, but Flutter analyze/test/build still require a Flutter SDK / GitHub Actions run.
