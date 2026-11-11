# Contributing to Unity MCP

Thanks for helping out. This page covers working on the package from a local checkout.

## Set up a local checkout

1. Clone the repository (or your fork).
2. Get the native plugins. The `main` branch doesn't contain them, so choose one:
   - **Download the CI-built plugins** (no compiler needed; uses only git):
     ```bash
     bash Proxy~/fetch_plugins.sh
     ```
     This copies the plugins from the latest release. Pass a 3.x version to match a specific release, for example `bash Proxy~/fetch_plugins.sh 3.0.0`.
   - **Build them yourself**, if you're changing the native code in `Proxy~/`. See [Proxy~/README.md](Proxy~/README.md).
3. Add the package to a Unity project as a local package. In the project's `Packages/manifest.json`:
   ```json
   "com.emeryporter.unitymcp": "file:<path to your clone>/Package"
   ```
4. Restart Unity whenever you replace a native plugin. Unity loads native plugins once per editor session.

The plugins you fetch or build are gitignored, so they never show up as changes.

## Making changes

- **Don't commit native binaries** (`.dll`, `.bundle`, `.so`, `.dylib`). CI builds them from `Proxy~/` for every release.
- **Let Unity create `.meta` files.** When you add a file under `Package/`, open the project in Unity so it generates the `.meta`, then commit both. Don't write `.meta` files by hand.
- **Don't commit deleted plugin `.meta` files.** If you open the project before getting the plugins, Unity deletes the `.meta` files in `Package/Plugins/`. Running `fetch_plugins.sh` (or a build script) restores them, and the PR check blocks committing their deletion.
- **Shell scripts use LF line endings.** `.gitattributes` enforces this; keep it in mind if your editor converts line endings.

## Pull request checks

Every pull request to `main` runs:

| Check | What it does |
|---|---|
| **No prebuilt binaries** | Fails if the PR adds or changes native binaries, or plugin files under `Package/Plugins/`. Remove them from the PR; CI builds them. |
| **Script tests** | Runs the release script tests in `.github/scripts/tests/`. |

To run the script tests yourself (Git Bash on Windows works):

```bash
for t in .github/scripts/tests/test-*.sh; do bash "$t"; done
```

## How releases work

Merging a pull request into `main` publishes a release automatically:

1. CI builds the native plugins for Windows, macOS and Linux from `Proxy~/`.
2. It assembles the package (contents at the root, plus the plugins) and commits it to the `latest` branch.
3. It tags that commit with the version and creates a GitHub Release.

Patch versions increase automatically. For a minor or major release, raise `version` in `Package/package.json` in your pull request.

Maintainers can test the release workflow on a branch without publishing anything:

```bash
gh workflow run build-release.yml --ref <branch> -f dry_run=true
```
