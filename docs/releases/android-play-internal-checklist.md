# Android Play Internal Checklist

1. Confirm `applicationId`, versionCode, and versionName in `apps/android/app/build.gradle.kts`.
2. Validate Play API credentials: `./tools/scripts/playstore-setup.sh`.
3. Build signed release artifact and upload to internal track: `./tools/scripts/playstore-upload.sh`.
4. Add tester list/groups in Play Console.
5. Verify release notes and rollout settings.
6. Install from Play internal track and smoke test core flows.
