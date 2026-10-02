# Daykeeper

An offline-first SwiftUI life-management app for iOS 18 and later. Open `LifeCommandCenter.xcodeproj` in Xcode and run the `LifeCommandCenter` scheme on an iOS simulator or device.

## Included

- Today dashboard with due tasks, upcoming bills and renewals, home maintenance, and active projects.
- Task creation, editing, completion, snoozing, deletion, categories, priorities, recurrence, and local notifications.
- Home maintenance and home projects with project task checklists and automatic progress calculation.
- Subscription and bill tracking, upcoming payment lists, subscription cost totals, and category chart.
- Calendar, global text search, basic statistics, and local settings.
- SwiftData persistence and a sample household added on first launch.

Data stays on device. The project has no server dependency or third-party packages.

## Current scope

This is a working first version. Recurrence supports daily, weekly, monthly, quarterly, and yearly task intervals. Custom weekday schedules, attachment/photo storage, user-defined categories and home areas, JSON/CSV export and import, widgets, and Apple Calendar/Reminders integration are not implemented yet. The sample data is inserted once when the app first opens.

## Build verification

The app builds against the iOS Simulator SDK with Xcode. A simulator runtime was not installed in the development environment, so interactive simulator flows and appearance checks could not be run here.
