# StopSet app icon

The active icon is `StopSet/StopSetIcon.icon`, an Apple Icon Composer document containing one custom vector bus symbol. The Xcode app target uses `StopSetIcon` in both Debug and Release.

- Default: white bus on green (`#34C759`).
- Dark: green bus on black.
- Mono: automatic system colors for Home Screen tinting and Clear appearances.

The windshield, destination panel, headlights, and bumper are transparent cutouts in the silhouette, so they adapt with the background. iOS applies corner masking and the system's icon material effects.

The document was imported and saved through Icon Composer. Light, Dark, Tinted Dark, and Clear Light were rendered and inspected with Apple's `ictool`; the simulator build passed. The previews in this directory show the system-rendered appearances, with purple used as an example custom tint. Clear preview transparency is shown against the renderer's neutral backdrop; its appearance on a phone depends on the wallpaper.

The previous blue raster design remains in `StopSet/Assets.xcassets/AppIcon.appiconset` for reference and is not the app's selected icon.
