# Rebuilding libghostty

From the ghostty repo (not this repo). Default `zig build -Dapp-runtime=none` fails on macOS.

```
cd /path/to/ghostty
zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Dxcframework-target=native
cp macos/GhosttyKit.xcframework/macos-arm64/libghostty-fat.a /path/to/hootty/Vendors/lib/libghostty.a
cp -R macos/GhosttyKit.xcframework/macos-arm64/Headers/* /path/to/hootty/Sources/CGhostty/include/
```
