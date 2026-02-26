# Performance + UX Parity Baseline

## Phase 0 Capture Checklist

Capture before/after media for these flows:

- Sidebar open/close with session search and workspace groups
- Session list filtering (query + fork filter + server filter)
- Directory picker open, navigate, search, continue in last folder, select folder, and error state

Store recordings in:

- `docs/artifacts/android/` (`sidebar.mp4`, `session-list.mp4`, `directory-picker.mp4`)
- `docs/artifacts/ios/` (`sidebar.mov`, `session-list.mov`, `directory-picker.mov`)

Suggested capture commands:

```bash
# Android (emulator/device)
adb shell screenrecord /sdcard/litter-directory-picker.mp4
adb pull /sdcard/litter-directory-picker.mp4 docs/artifacts/android/directory-picker.mp4

# iOS Simulator
xcrun simctl io booted recordVideo docs/artifacts/ios/directory-picker.mov
```

## Profiling Checkpoints

Android (Compose recomposition checkpoints):

- `LitterComposePerf` logs emitted from:
  - `LitterAppShell`
  - `SessionSidebar`
  - `ConversationPanel`
  - `InputBar`
  - `DirectoryPickerSheet`

iOS (Instruments signposts):

- Category `SessionSidebar`:
  - `LoadSessions`
- Category `DirectoryPicker`:
  - `LoadInitialPath`
  - `ListDirectory`

## Acceptance Criteria

### Sidebar composition gating

- Sidebar subtree is not composed while closed.
- Opening sidebar preserves local sidebar UI state (fork filter, server filter, collapsed groups).

### Session filtering/search

- Query normalization is computed once per query update.
- Filtering + grouping do not allocate repeatedly during unchanged inputs.

### Lineage map

- Parent/sibling/children relationships are precomputed once per session list update.
- Row rendering only consumes precomputed lineage maps.

### Markdown + inline media

- Markwon instances are reused at conversation scope for assistant/system rendering.
- Inline image decode runs off main thread.

### Composer input scope

- Fast typing updates remain local to input composable.
- Debounced commit updates app-level draft state.

### Directory picker parity

- One-tap `Continue in <last folder>` action exists.
- Top controls (server chip/status + search) remain visible while list scrolls.
- Breadcrumb + up navigation show current path and support direct jumps.
- Bottom CTA is persistent: `Select <path>` + disabled helper text.
- Error state includes explicit `Retry` and `Change server` actions.
- Clear recents requires destructive confirmation.
- Back behavior: navigate up first, dismiss only at root.

### Theme/API consistency

- Hardcoded separator/scrim colors replaced with semantic theme tokens in picker/sidebar flows.
- Typography and string usage are consistent for picker parity surfaces.

### Strings + localization

- Picker microcopy is backed by localized string resources on both platforms.
- iOS and Android picker labels/actions are text-parity aligned.
