# Rebuilding libghostty

## Automated (recommended)

`make setup` (or `./scripts/setup.sh`) handles everything automatically:

1. Initializes the ghostty submodule
2. Builds libghostty with Zig
3. Caches the build at `~/.cache/hootty/ghosttykit/<sha>/`
4. Copies the static library and headers into the repo

To force a rebuild, delete the cache directory:

```sh
rm -rf ~/.cache/hootty/ghosttykit/
make setup
```

## Manual

From the ghostty repo (or the `ghostty/` submodule directory):

```
cd ghostty
zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Dxcframework-target=native
cp macos/GhosttyKit.xcframework/macos-arm64/libghostty-fat.a ../Vendors/lib/libghostty.a
cp -R macos/GhosttyKit.xcframework/macos-arm64/Headers/* ../Sources/CGhostty/include/
```
