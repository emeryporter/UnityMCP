# UnityMCP Proxy Plugin

C source code for UnityMCP's domain-reload-resistant HTTP server.

## Purpose

Unity's managed C# code is unloaded during domain reloads (entering/exiting Play mode, script recompilation). This plugin provides an HTTP server that persists across these reloads, allowing continuous communication with MCP clients.

## Folder Naming

The `~` suffix in `Proxy~` tells Unity to ignore this folder entirely. Unity will not attempt to import or process any files within it. This is intentional because:
- Unity cannot compile C source files
- We need to build these into platform-specific libraries externally

## Contents

- `mongoose.c` / `mongoose.h` - The Mongoose embedded HTTP library (https://github.com/cesanta/mongoose)
- `proxy.c` / `proxy.h` - UnityMCP proxy server implementation

## Getting the Plugins

Releases ship plugins built by CI (`.github/workflows/build-release.yml`), so you only need to build them when you change the C code here. Never commit built plugins; they're gitignored, and the "No prebuilt binaries" PR check rejects them.

**Not changing the C code?** Download the CI-built plugins instead (uses only git):

```bash
bash Proxy~/fetch_plugins.sh          # latest release
bash Proxy~/fetch_plugins.sh 3.0.0    # a specific 3.x release
```

## Build Instructions

Each script compiles the plugin and copies it, plus its `.meta` file from `../release-meta/`, into `../Package/Plugins/`:

| Platform | Script | Toolchain | Output |
|---|---|---|---|
| Windows x86_64 | `build_windows.bat` | MSVC (run from a Visual Studio Developer Command Prompt) | `Package/Plugins/Windows/x86_64/UnityMCPProxy.dll` |
| Windows x86_64 | `build_windows_gcc.bat` | MinGW-w64 `gcc` on `PATH` | same as above |
| macOS (universal) | `build_macos.sh` | `clang` | `Package/Plugins/macOS/UnityMCPProxy.bundle` |
| Linux x86_64 | `build_linux.sh` | `gcc` | `Package/Plugins/Linux/x86_64/libUnityMCPProxy.so` |

`build_all.sh` runs the script for the current platform and skips the others.

Restart Unity after rebuilding: Unity loads native plugins once per editor session and keeps the old one until you restart.

## Mongoose Library

Mongoose is a lightweight embedded web server library. We use it because:
- Single-file distribution (easy to include)
- No external dependencies
- Cross-platform support
- MIT licensed

Source: https://github.com/cesanta/mongoose
