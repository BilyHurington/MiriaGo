# 圣地巡礼助手

**Seichi Junrei Helper** is an open-source Flutter app for anime pilgrimage
planning and on-site photo reference.

The first version focuses on the camera reference workflow:

- Choose a local reference image.
- Compare the reference with the live camera preview.
- Switch between split and overlay reference modes.
- Adjust overlay opacity.
- Capture and save photos locally.

Future phases will connect Anitabi data, map points, route planning, and nearby
location prompts.

## Development

Install Flutter, then run:

```bash
flutter pub get
flutter analyze
flutter test
```

Run on a connected Android device:

```bash
flutter run -d <device-id>
```
