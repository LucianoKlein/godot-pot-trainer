#!/bin/zsh
set -e

echo "=== 编译 NativePlugin ==="

xcodebuild build \
    -scheme NativePlugin \
    -destination "generic/platform=iOS" \
    -configuration Release \
    -derivedDataPath .build/arm64-apple-ios \
    SKIP_INSTALL=NO

BUILD_DIR=".build/arm64-apple-ios/Build/Products/Release-iphoneos"

if [ ! -d "$BUILD_DIR/PackageFrameworks" ]; then
    echo "编译失败：找不到产物目录 $BUILD_DIR/PackageFrameworks"
    exit 1
fi

mkdir -p Bin
cp -R "$BUILD_DIR/PackageFrameworks/NativePlugin.framework" Bin/
cp -R "$BUILD_DIR/PackageFrameworks/SwiftGodot.framework" Bin/

for fw in GoogleMobileAds RevenueCat; do
    if [ -d "$BUILD_DIR/PackageFrameworks/$fw.framework" ]; then
        cp -R "$BUILD_DIR/PackageFrameworks/$fw.framework" Bin/
        echo "  已复制: $fw.framework"
    fi
done

echo ""
echo "=== 编译完成 ==="
echo "产物在 Bin/ 目录:"
ls -la Bin/
echo ""
echo "=== 接下来 ==="
echo "1. 在 Godot 编辑器中导出 iOS 项目"
echo "2. 用 Xcode 打开导出的项目"
echo "3. Target → Signing & Capabilities → 添加 Sign in with Apple"
echo "4. Target → Signing & Capabilities → 添加 In-App Purchase"
echo "5. Info.plist 添加 GADApplicationIdentifier"
echo "6. 连接 iPhone，Build & Run"
