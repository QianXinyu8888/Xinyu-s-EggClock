# 🍳 Xinyu's EggClock

> A minimalist egg timer app built with SwiftUI. Features preset boiling modes, custom egg support, Siri shortcuts integration, and boiling statistics tracking.

## Features

- 🍳 **Four preset modes**: Onsen egg (8min), Soft-boiled (10min), Regular (18min), Overcooked (20min)
- ✏️ **Custom eggs**: Add your own egg types with custom duration and emoji
- 🔔 **Background notifications**: Get alerts when eggs are almost done or finished
- 📊 **Boiling statistics**: Track total eggs boiled and total time spent
- 🔗 **Siri shortcuts**: Add eggs to Siri for voice-activated timing
- 🎨 **iOS 26 style UI**: Clean, modern interface with warm yellow theme

## Tech Stack

- SwiftUI
- XcodeGen
- UserNotifications
- AppIntents
- iOS 17+

## Build

```bash
xcodegen generate
xcodebuild -project EggClock.xcodeproj -scheme EggClock -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Or open `EggClock.xcodeproj` in Xcode and run.

## Project Structure

```
Xinyu's EggClock/
├── ContentView.swift       # Main timer UI
├── Egg.swift               # Egg model + UserDefaults persistence
├── EggEditorView.swift     # Add/edit custom egg sheet
├── NotificationManager.swift # Background notification handling
├── SceneDelegate.swift     # SwiftUI entry point
├── AppDelegate.swift       # App delegate
└── Assets.xcassets/       # App icons and assets
```
