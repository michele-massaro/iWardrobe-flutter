# Task 006 — SyncService abstraction & iCloud setup

| | |
|---|---|
| **Phase** | 2 — Data layer |
| **Depends on** | 001 |
| **Primary references** | [iCloud sync](../icloud-sync.md) §2 Platform support, §3 Container & Xcode setup, §5 Package API mapping · [Architecture](../architecture.md) §Cross-platform strategy |

## Objective

Introduce the **single platform seam** of the whole app: the `SyncService` interface, its no-op Android implementation, and the `IcloudSyncService` that maps the interface onto `icloud_storage_sync` 0.0.5 — plus the Xcode/iCloud container configuration that makes the Apple targets able to use the container at all. After this task, no code outside this seam may branch on platform (Architecture §Cross-platform strategy).

## What the agent must deliver

### 1. Interface — `lib/data/services/sync_service.dart`

An abstract `SyncService` whose operations are exactly the container operations of the iCloud sync doc §5 (arguments as documented):

| Operation | Signature (semantic) | Plugin method (0.0.5) |
|---|---|---|
| List container files | `Future<List<ContainerFile>> listFiles({required String prefix, Duration timeout})` — throws the transient timeout error on metadata timeout | `gather(containerId, relativePathPrefix, timeout)` |
| Fetch file bytes | `Future<Uint8List?> fetchFile(String relativePath)` | `getCloudFiles(containerId)` + select matching entry |
| Upload new file | `Future<void> upload({required String localPath, required String destinationRelativePath, void Function(double) onProgress})` | `upload` |
| Replace existing file | `Future<void> replace({required String localPath, required String relativePath})` | `replace` |
| Delete file | `Future<void> delete(String relativePath)` | `delete(isDirectory: false)` |
| Quarantine (rename) | `Future<void> rename({required String relativePath, required String newName})` | `rename` |

Plus `bool get available` (true on Apple, false on Android) and, if needed for the pipeline, `move` as a reserved/unused operation (documented in the doc as unused in v1). A small `ContainerFile` value (name, relativePath, size/mtime as exposed by 0.0.5 — **re-verify the exact `ICloudFile` shape against the published 0.0.5 API at implementation time**, per the doc §3 checklist item 4).

### 2. `NoopSyncService`

Same interface, zero behavior: `available == false`; list → empty; fetch → null; uploads/replaces/deletes/rename → no-op. On Android the local-change event hits this and **nothing happens** — no queue, no retry, no status state (FR-10.6).

### 3. `IcloudSyncService`

Wraps the plugin instance `icloudSyncPlugin`; `available == true`; maps each interface operation to the plugin call exactly per the doc §5 table, including:

- `listFiles` scoped with `relativePathPrefix: 'Documents/'` and a bounded `timeout`; `PlatformException` code `METADATA_QUERY_TIMEOUT` is rethrown as a **transient** error (the pipeline backs off; the app is never blocked — NFR-1, FR-10.4).
- `upload`/`replace` with `onProgress` forwarded from the plugin's `StreamHandler<double>`.
- A single constant `containerId` = `iCloud.<team-id>.<bundle-id>` (use the documented placeholder form `iCloud.TEAM123.com.example.iwardrobe` until the real team id is set — flag it clearly).

### 4. Xcode / iCloud setup (Apple targets)

Per the iCloud sync doc §3, for **both** the iOS and the macOS target:

- Signing & Capabilities → ＋ Capability → iCloud, container id assigned.
- `ios/Runner/Info.plist` and the macOS `Info.plist`: `com.apple.developer.icloud-container-identifiers` array with the container id.
- `ios/Runner/Runner.entitlements` and the macOS entitlements: the same array (exact XML snippets are in the doc).
- The identical container id is assigned to both App IDs (the documented gotcha: a macOS App ID derived from a different base bundle id would create a different container).

### 5. Registration seam (wired in task 013)

The canonical provider registration lives here as the reference snippet (task 013 puts it into `app.dart`):

```dart
Provider<SyncService>(
  create: (_) => defaultTargetOs == TargetPlatform.iOS ||
          defaultTargetOs == TargetPlatform.macOS
      ? IcloudSyncService()
      : const NoopSyncService(),
)
```

## Definition of done

**Build** (standard gate): all items pass. `flutter build ios --no-codesign` and `flutter build macos` succeed with the new entitlements/Info.plist content.

**Unit test constraints** — `test/data/sync/` (tests must run on the host platform without a real iCloud account — inject a fake plugin seam where needed):

- [ ] **NoopSyncService:** `available` false; every operation is a no-op returning the documented empty values.
- [ ] **IcloudSyncService mapping:** for each interface operation the correct plugin call is made with the documented arguments (assert via the injected fake plugin seam): `gather` gets `relativePathPrefix: 'Documents/'` + timeout; `upload` gets local path + `Documents/...` destination + progress handler; `replace`/`delete`/`rename` map 1:1; `rename` target follows `Documents/sync/wardrobe.json.bad-<timestamp>` naming.
- [ ] **Transient timeout:** a `METADATA_QUERY_TIMEOUT` plugin error is surfaced as the transient error type the pipeline (task 010) recognizes.
- [ ] **Fetch selection:** `fetchFile` picks the entry matching the requested relative path from the plugin's file list.
- [ ] **Platform branch:** the registration expression selects `IcloudSyncService` for iOS/macOS and `NoopSyncService` otherwise (test the pure decision function, not `defaultTargetOs` directly).

**Functional acceptance**

- [ ] iOS + macOS `Info.plist` and both entitlements files contain the container key and are committed (Xcode regenerates them; they must exist in source control per the doc).
- [ ] No other file in `lib/` references `icloud_storage_sync` or branches on `TargetPlatform` (the single-platform-branch rule, instructions.md §7).
- [ ] The 0.0.5 API notes (field shapes, selection behavior) are re-verified against the published package and any discrepancy recorded in the commit message.

**Out of scope for this task:** the pipeline/merge (007/010), the status indicator (025), provider wiring in `app.dart` (013).
