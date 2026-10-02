# Daykeeper

Daykeeper is an offline-first personal life-management app for iPhone. It brings everyday tasks, grocery trips, home maintenance and projects, bills, and subscriptions together in one local app.

## Product overview

The five primary tabs are **Today**, **Tasks**, **Groceries**, **Home**, and **Money**. Calendar, Search, Statistics, and Settings are available from the More tools button on Today.

- **Today:** A daily overview of tasks, upcoming dates, home maintenance, projects, bills, and renewals.
- **Tasks:** Create, edit, complete, snooze, and delete tasks. Tasks include priority, category, due date, repeat rule, and an optional local reminder.
- **Groceries:** Keep a reusable master catalog. Stage items and quantities for today's trip, mark purchases with a strikethrough, undo an accidental mark by tapping the check again, and clear the trip with **Done for the day**.
- **Home:** Track maintenance and home projects. Projects contain checklist tasks and derive progress from completed project tasks.
- **Money:** Track bills and subscriptions, upcoming dates, monthly and annual subscription costs, and category spending.
- **More tools:** Calendar, global text search, basic statistics, appearance, preferred name, and notification settings.

Quick Add defaults to a type that fits the selected tab: Task on Today and Tasks, Grocery on Groceries, Maintenance on Home, and Subscription on Money. Other item types remain available in the picker.

## Requirements

- Xcode with an iOS 18 or newer SDK
- iOS 18 or newer deployment target
- Swift and SwiftUI
- SwiftData, UserNotifications, and Swift Charts (Apple frameworks)
- No third-party packages, backend, or user account

## Open and run

1. Open `LifeCommandCenter.xcodeproj` in Xcode.
2. Select the `LifeCommandCenter` scheme.
3. Choose an iPhone simulator or connected iPhone as the run destination.
4. For a simulator, press **⌘R**. For an iPhone, set the signing team and a unique bundle identifier under **Signing & Capabilities**, then press **⌘R**.

The app is named **Daykeeper** on the Home Screen. On a new install, it adds example tasks, home data, bills, and subscriptions. The starter grocery catalog is seeded once, including for an existing install that upgrades to the grocery feature. User content is stored on the device.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the component diagram, model relationships, and data flow.

At a glance, `LifeCommandCenterApp.swift` defines the SwiftData schema, local models, app entry point, and notification service. `Views.swift` contains the tab screens, reusable components, and forms. Screens observe data with `@Query` and edit it through the shared SwiftData `ModelContext`.

## Data and privacy

- SwiftData stores app content in the app's local container.
- There is no network service, sign-in, analytics, or tracking in this project.
- The app does not store full card numbers. Payment method fields are ordinary descriptive text and should contain labels only (for example, “Visa ending 42”), never a full card number or security code.
- Notifications are local. The app asks for notification permission when the user enables a reminder.
- iCloud/CloudKit synchronization, Apple Reminders, and Apple Calendar are not configured.
- There is no in-app export or restore feature yet. Back up the iPhone before installing development builds or removing the app.

### Persistence and upgrades

The app creates its SwiftData `ModelContainer` from the model schema in `LifeCommandCenterApp.swift`. Lightweight store migration is inferred by SwiftData. The `GroceryItem.isPurchased` field has an explicit `false` default so records created by the earlier grocery schema can migrate as unpurchased. Avoid deleting the app or its store to work around a migration failure; preserve the store and investigate the migration first.

For future schema changes, add an explicit `VersionedSchema` and `SchemaMigrationPlan` before shipping changes that cannot be handled by lightweight migration. The current app container uses `try!` during startup, so an unrecoverable store-opening error will stop launch; production hardening should replace this with a user-facing recovery and support flow.

## Notifications currently supported

- Task and reminder forms can schedule a local notification at the selected date and time.
- Bill creation can optionally schedule a local notification at the due date.
- Notification text includes the preferred name from Settings when one has been set.
- Completing a task cancels its pending reminder.

Subscription renewal lead-time options (such as 7 days, 1 day, and renewal day), maintenance reminders, project deadline reminders, global quiet hours, and notification rescheduling when dates change are not implemented yet. Notification delivery also depends on iOS authorization and device settings.

## Prepare a release build

The repository is a development MVP. Before distributing through TestFlight or the App Store:

1. **Set app identity:** In the `LifeCommandCenter` target's Signing & Capabilities, replace the current placeholder bundle identifier `com.example.LifeCommandCenter` with a unique reverse-DNS identifier you control. Set the Apple Developer team and enable automatic signing.
2. **Set release metadata:** Confirm the display name is Daykeeper, set a deliberate marketing version and build number, and review supported devices and orientation.
3. **Review the icon:** Check the 1024×1024 `AppIcon` asset on the Home Screen and in App Store Connect.
4. **Review privacy and permissions:** Confirm the notification permission prompt and user-facing copy. Complete App Store privacy disclosures accurately; this app has no backend or tracking, but only the publisher can make the final privacy declarations.
5. **Validate existing data:** Test an upgrade from the previously installed build with real SwiftData content. Verify data remains after migration and app relaunch. Keep a device backup before testing upgrades.
6. **Run device smoke checks:** Test first launch, Quick Add defaults on every tab, task create/edit/complete/repeat, grocery stage/purchase/undo/Done for the day, project progress, bill and task notifications, preferred-name greeting, dark mode, Dynamic Type, and relaunch persistence.
7. **Archive:** Select **Any iOS Device (arm64)** or a supported generic iOS device destination, choose **Product → Archive**, then validate and distribute from Xcode Organizer.
8. **Check store requirements:** Provide App Store screenshots, description, age rating, support and privacy URLs, export compliance answers, and review notes in App Store Connect.

Do not distribute the current placeholder bundle identifier or treat the simulator build as a release validation. No App Store archive, TestFlight upload, or end-to-end device release test has been performed from this repository.

## Current limitations

- Custom repeat weekday rules, custom categories/areas, attachments/photos, JSON/CSV export/import, widgets, and Apple integrations are not implemented.
- Subscription and maintenance notification schedules are not implemented; see [Notifications currently supported](#notifications-currently-supported).
- Statistics are a basic local summary; no remote analytics are used.
- There is no automated test target yet. The project has been built for the iOS Simulator SDK, but the release smoke checks above still need to be run on a simulator and physical device.

## Project files

```text
iOS App/
├── LifeCommandCenter.xcodeproj/
├── LifeCommandCenter/
│   ├── Assets.xcassets/AppIcon.appiconset/
│   ├── LifeCommandCenterApp.swift
│   ├── Views.swift
│   └── render_app_icon.swift
├── ARCHITECTURE.md
└── README.md
```
