# StopSet

StopSet is a SwiftUI app for comparing Auckland bus departures across a user-defined group of stops.

## Requirements

- Xcode 16 or newer
- iOS 18.0 or newer

Open `StopSet.xcodeproj` in Xcode and select the StopSet scheme. The bundle identifier is currently `com.example.StopSet`; change it and select your signing team before running on a physical device.

## Using the app

1. Tap `+` and search an Auckland address or enter the start of a stop number (for example, `21`). Every search shows Apple Maps address suggestions. Numeric searches also find all bus stops across Auckland whose numbers start with those digits, ordered by stop number above the addresses. If no stops match, only address suggestions are shown. Tap a stop result to locate it on the map, then add it to your group; tap an address to see nearby stops. Stop codes are shown on markers and in the stop list. A selected stop also shows route numbers whose mapped lines pass nearby; these are a hint, not a guaranteed list of services at that stop.
2. Add one or more stops, tap Next, and name the group. Choose a symbol and colour if desired. Groups are stored on this device. Swipe right to edit, swipe left to delete, or use Edit to reorder them.
3. Open a group to see departures combined across its stops, with live estimates clearly distinguished from scheduled times. Use the stop menu to filter the board, or tap All buses to select one or more bus numbers. The filters work together, and bus selections remain active during refreshes; choose All buses in the selector to reset them. Use the map button to see the group's stops. Departures refresh every 10 seconds while the app is active; change the interval in Settings, or pull to refresh.
4. Tap a departure to see the last reported vehicle position, when AT provides one. The map refreshes every 15 seconds while active and can be recentered without losing the trip details.

The phone picker uses a resizable sheet over Apple Maps; iPad uses a side-by-side picker. The interface follows system appearance and Dynamic Type.

Address search uses Apple Maps. Bus stop and nearby route discovery use Auckland Transport's public ArcGIS layers, so group creation does not need an API key. Live departures and vehicle locations need a free [AT developer key](https://dev-portal.at.govt.nz/) subscribed to the Realtime and GTFS APIs. Enter it in Settings; it is saved to the device Keychain, not the project source.

## Current limitations

- AT's stop timetable and live feeds are combined by trip ID. A live estimate for a downstream stop uses the vehicle's latest reported delay, so it may differ from AT Mobile's own prediction. If AT does not track the trip, the scheduled time is shown.
- The direct-device API key setup is for a personal prototype. A public App Store release should proxy AT requests through a backend rather than distribute a shared key or ask each customer for one.
- The app does not estimate walking time.

## Testing

Run the `StopSet` scheme's tests in Xcode (Product > Test). The UI tests cover creating and editing groups with one or more stops, the one-stop minimum, combined stop and address search (including result order, text and mixed input, missing numbers, and stops outside the current map area), departure filtering, both maps, and accessibility-sized text, with screenshot attachments in the test report.

UI tests launch with `--ui-testing` to use deterministic sample groups and departures. This Debug-only mode uses a separate preferences suite and never changes saved user groups. Normal launches always use the real transport services.

The optional `StopSetLiveSearchTests` checks real Apple Maps suggestions while typing `21 holl` and `Queen Street`, then selects an address to load nearby stops. Run `xcodebuild test` with `TEST_RUNNER_STOPSET_LIVE_SEARCH_TESTS=1` in its environment to enable it. This test uses a normal app launch and requires network access; it is skipped in the default test run.
