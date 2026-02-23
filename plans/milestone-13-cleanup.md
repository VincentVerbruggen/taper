# Milestone 13: UI Polish & Cleanup Plan

This milestone focuses on small but important UI/UX improvements to make the app feel more consistent and intuitive.

## 1. Unify Dashboard Title

- **File:** `lib/screens/dashboard_screen.dart`
- **Goal:** Modify the `AppBar` to keep the "Dashboard" title visible in edit mode.
- **Why:** A persistent title provides better context and consistency with other screens.
- **How:** The `AppBar`'s `title` property will be changed from a conditional widget to a static `Text('Dashboard')`. The existing "Done" checkmark icon button will remain as the primary action in edit mode.

## 2. Simplify Trackables List

- **File:** `lib/screens/settings/settings_screen.dart`
- **Goal:** Replace the `ReorderableListView` with a standard `ListView.builder`.
- **Why:** The drag-to-reorder functionality is no longer a design requirement, so we can simplify the UI and the code.
- **How:** We will swap the `ReorderableListView` widget with a `ListView.builder` that renders a `ListTile` for each trackable. The `onReorder` callback will be removed.

## 3. Organize Settings Screen

- **File:** `lib/screens/settings/settings_screen.dart`
- **Goal:** Add an "Appearance" section header.
- **Why:** Grouping related settings improves scannability and organization.
- **How:** We will add a non-interactive `ListTile` with `title: Text('Appearance', style: Theme.of(context).textTheme.titleSmall)` before the "Day starts at" and "Theme" settings.

## 4. Improve Dashboard Back Navigation

- **File:** `lib/screens/dashboard_screen.dart`
- **Goal:** Intercept the system back button press when in dashboard edit mode.
- **Why:** Exiting edit mode is a more intuitive action than closing the app when the user presses "back."
- **How:** The `Scaffold` will be wrapped in a `PopScope` widget. Its `onPopInvoked` callback will check if the app is in edit mode. If `true`, it will toggle edit mode off and prevent the default back action. If `false`, it will allow the app to exit as normal.
