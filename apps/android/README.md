# Android App

Native Android app scaffold with module boundaries aligned to iOS feature flows:

- `app`: Android entrypoint/activity.
- `core:network`: discovery/network primitives.
- `core:bridge`: JSON-RPC bridge surface placeholders.
- `feature:discovery`: server discovery flow.
- `feature:sessions`: session listing/resume flow.
- `feature:conversation`: turn/message flow.

## Rust Bridge (Android)

The Android bridge module loads a Rust shared library named `libcodex_bridge.so`.

Build and copy JNI artifacts into `core:bridge`:

```bash
./tools/scripts/build-android-rust.sh
```

Prerequisites:
- Android NDK (`ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT` set)
- `cargo-ndk` (`cargo install cargo-ndk`)
