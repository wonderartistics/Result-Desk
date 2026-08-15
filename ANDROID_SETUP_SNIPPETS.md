# Android config to set after `flutter create`

`flutter create` generates the `android/` folder for you (this is why you
don't need Android Studio — you never hand-write this). After you run it,
make these two small edits so the app name and package ID match Result Desk.

## 1. App label
File: `android/app/src/main/AndroidManifest.xml`

Find:
```xml
<application
    android:label="result_desk_flutter"
    ...
```
Change `android:label` to:
```xml
<application
    android:label="Result Desk"
    ...
```

## 2. Package / applicationId (optional but recommended)
File: `android/app/build.gradle` (or `build.gradle.kts`)

Find:
```
defaultConfig {
    applicationId "com.example.result_desk_flutter"
```
Change to something unique to you, e.g.:
```
defaultConfig {
    applicationId "com.taimoorhassan.resultdesk"
```

> If you change the applicationId, also rename the folder path under
> `android/app/src/main/kotlin/...` to match, or just re-run
> `flutter create --org com.taimoorhassan .` from the project root *before*
> you start editing — that sets the org/package correctly from the start
> and regenerates the android/ios folders to match (safe to run even if
> the folders already exist).

## 3. Minimum SDK version
`syncfusion_flutter_pdf` and `file_picker` need `minSdkVersion 21+`.
In the same `build.gradle`, under `defaultConfig`, make sure:
```
minSdkVersion 21
```
(Flutter's default template already sets this to 21+ in recent versions —
just double check.)
