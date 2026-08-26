# M8 release gate

M8 hardens the release without changing the local-first privacy boundary. The default verification is deterministic and does not transmit captured content.

## Automated gates

Run the full local gate on Windows:

```powershell
.\tool\verify.ps1 -M8 -SoakSeconds 5
```

This runs all package suites plus:

- the fixed seven-day corpus and its eight canonical questions;
- contradiction detection and Desktop/MCP evidence equivalence;
- granular deletion, including derived search surfaces;
- aggregate diagnostics with no titles, prompts or captured content;
- 50,000-episode p95 latency and regression gates;
- a configurable soak process with correctness and RSS-growth limits;
- native Windows window, clipboard, OCR, denylist, lock-state and audio-helper checks.

The native lock gate reads the real Windows lock state, then verifies the blocked transition without locking the developer's active workstation. A physical lock/unlock pass remains a manual release check.

## LM Studio

Load `qwen/qwen3-8b`, start LM Studio on `http://127.0.0.1:1234/v1`, and run:

```powershell
cd core
dart run benchmark/m8_lm_studio_e2e.dart
```

The gate passes only when all eight questions finish, retrieve the expected episode ids, reflect and cite evidence. Output contains counts, durations, tool names and stop reasons, not answers or corpus text.

## Soak

`benchmark/m8_soak.dart` defaults to 24 hours. Use a shorter value only for smoke verification:

```powershell
$env:KANGOOS_M8_SOAK_SECONDS = '86400'
cd core
dart run benchmark/m8_soak.dart
```

Do not mark the 24-hour gate passed from a short run.

## Installer and encrypted upgrade

`app/pubspec.yaml` is the version source. The Inno Setup script refuses to compile unless `tool/verify.ps1` supplies that version and build number. The Windows CI job downloads Microsoft's official x64 VC++ Redistributable, runs M8, verifies SQLCipher backup/upgrade tests, builds the installer and uploads both the `.exe` and its `.sha256` file.

Before upgrading a real installation, create an encrypted backup from Settings and keep the keychain entry. After installing, confirm the app opens the existing Timeline and run the granular search/deletion smoke. CI uses disposable encrypted databases; it never accesses a developer's personal database.

The Windows reference run upgraded `1.1.0+2` to `1.2.0+3` after copying the encrypted database and keychain container to a recoverable backup. The installer preserved the database byte-for-byte; the read-only SQLCipher probe reported schema 22, a clean integrity check and identical aggregate row counts before and after installation. The installed app then reopened the same database successfully.

## Platform declarations

Windows is the supported target. Linux and macOS compile in independent CI jobs, but remain experimental until native capture, keychain, tray and installer flows pass on real machines. A green compile job alone is not runtime support.

## Release checklist

- `cd core; dart run benchmark/m8_lm_studio_e2e.dart`: 8/8.
- `cd core; dart run benchmark/m4_benchmark.dart`: 50,000 episodes within p95 gates.
- In `core`, set `KANGOOS_M8_SOAK_SECONDS=86400` and run `dart run benchmark/m8_soak.dart`: zero failures and RSS within gate.
- `.\tool\verify.ps1 -M8 -BuildInstaller -VcRedistSource <path>`: clean.
- Upgrade a backed-up real encrypted installation and verify Timeline/search.
- Review independent Linux/macOS jobs; keep them experimental until runtime checks exist.
