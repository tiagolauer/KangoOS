# M0 verification baseline

Captured on 2026-08-26 on Windows x64 with Flutter 3.29.3, Dart 3.7.2 and the standalone Dart 3.7.3 CI pin.

Run the standard gate from the repository root:

```powershell
.\tool\verify.ps1
```

| Package | Analyze | Tests | First clean-toolchain run |
|---|---|---:|---:|
| `core` | clean | 171 passed | 22.9 s |
| `server` | clean | 29 passed | 15.2 s |
| `mcp` | clean | 1 passed | 19.0 s |
| `app` | clean | 105 passed | 121.8 s |

The standard gate covers 306 passing tests. The core suite has one additional SQLCipher integration test that is skipped until a Windows release bundle supplies its native library. No Drift multiple-database warnings were emitted.

Run the complete Windows release gate with:

```powershell
.\tool\verify.ps1 -BuildInstaller
```

That mode builds the Windows release, runs the SQLCipher migration test against the bundled `sqlite3.dll`, and compiles `app/dist/KangoOS-1.1.0-windows-x64-setup.exe`. The initial Windows build took 105.2 s, the encrypted upgrade test passed in 4.1 s, and Inno Setup packaging took 20.8 s. The installer embeds the Microsoft-signed Visual C++ x64 redistributable supplied through `-VcRedistSource` or the standard temporary/download locations.
