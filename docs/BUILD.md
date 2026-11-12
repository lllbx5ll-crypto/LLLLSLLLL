# Building Android APK (Godot 4.7.2)

Push to `main` or manually run **Actions → Build Android APK → Run workflow**. After success, open the workflow run and download the artifact `Merchants-City-Al-Qmishi-Android-APK`. The artifact is a ZIP containing `merchants-city-debug.apk`. Unzip and install the APK on your own Android phone.

GitHub Actions installs the open-source Godot editor and export templates, Android SDK 35 and JDK 17, imports scripts and runs smoke checks, builds an **APK signed with a generated debug key**. The debug key is newly generated for each run: installing an update over an older APK may require uninstalling the older APK first. **Debug APKs are for testing, not Play Store publication.** A published version requires a stable private release signing key and AAB export.

The build must succeed before claiming the APK exists. GitHub Actions job and artifact links are visible in the repository Actions tab.

No third-party copyrighted voice performances, logos or photorealistic commercial assets are included. Graphics are generated primitives and audio is procedural placeholder. This is a playable technical foundation, not a finished AAA open world game.
