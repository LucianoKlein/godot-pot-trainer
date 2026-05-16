#!/bin/bash
# post_export_ios.sh — Godot iOS 导出后自动修补 Xcode 项目
# 用法: ./post_export_ios.sh /path/to/exported/xcode/project/dir

set -e

PROJECT_DIR="${1:-.}"
APP_NAME="PotTrainer"
PLIST_PATH="$PROJECT_DIR/$APP_NAME/$APP_NAME-Info.plist"
ENTITLEMENTS_PATH="$PROJECT_DIR/$APP_NAME/$APP_NAME.entitlements"

echo "=== iOS Post-Export Patch Script ==="
echo "Project dir: $PROJECT_DIR"

# ============================================================================
# 1. Info.plist
# ============================================================================
if [ -f "$PLIST_PATH" ]; then
    echo "[1/3] Patching Info.plist..."

    # GADApplicationIdentifier
    if ! /usr/libexec/PlistBuddy -c "Print :GADApplicationIdentifier" "$PLIST_PATH" 2>/dev/null; then
        /usr/libexec/PlistBuddy -c "Add :GADApplicationIdentifier string ca-app-pub-XXXXXXXX~XXXXXXXXXX" "$PLIST_PATH"
        echo "  + Added GADApplicationIdentifier (TODO: replace placeholder)"
    fi

    # SKAdNetworkItems
    if ! /usr/libexec/PlistBuddy -c "Print :SKAdNetworkItems" "$PLIST_PATH" 2>/dev/null; then
        /usr/libexec/PlistBuddy -c "Add :SKAdNetworkItems array" "$PLIST_PATH"
        SKADNETWORK_IDS=(
            "cstr6suwn9.skadnetwork"
            "4fzdc2evr5.skadnetwork"
            "4pfyvq9l8r.skadnetwork"
            "2fnua5tdw4.skadnetwork"
            "ydx93a7ass.skadnetwork"
            "5a6flpkh64.skadnetwork"
            "p78ahlhg29.skadnetwork"
            "v72qych5uu.skadnetwork"
            "ludvb6z3bs.skadnetwork"
            "cp8zw746q7.skadnetwork"
            "3sh42y64q3.skadnetwork"
            "c6k4g5qg8m.skadnetwork"
            "s39g8k73mm.skadnetwork"
            "3qy4746246.skadnetwork"
            "f38h382jlk.skadnetwork"
            "hs6bdukanm.skadnetwork"
            "v4nxqhlyqp.skadnetwork"
            "wzmmz9fp6w.skadnetwork"
            "yclnxrl5pm.skadnetwork"
            "t38b2kh725.skadnetwork"
            "7ug5zh24hu.skadnetwork"
            "gta9lk7p23.skadnetwork"
            "vutu7akeur.skadnetwork"
            "y5ghdn5j9k.skadnetwork"
            "n6fk4nfna4.skadnetwork"
            "v9wttpbfk9.skadnetwork"
            "n38lu8286q.skadnetwork"
            "47vhws6wlr.skadnetwork"
            "kbd757ywx3.skadnetwork"
            "9t245vhmpl.skadnetwork"
            "eh6m2bh4zr.skadnetwork"
            "a2p9lx4jpn.skadnetwork"
            "22mmun2rn5.skadnetwork"
            "4468km3ulz.skadnetwork"
            "2u9pt9hc89.skadnetwork"
            "8s468mfl3y.skadnetwork"
            "klf5c3l5u5.skadnetwork"
            "ppxm28t8ap.skadnetwork"
            "ecpz2srf59.skadnetwork"
            "uw77j35x4d.skadnetwork"
            "pwa73g5rt2.skadnetwork"
            "mlmmfzh3r3.skadnetwork"
            "578prtvx9j.skadnetwork"
            "4dzt52r2t5.skadnetwork"
            "e5fvkxwrpn.skadnetwork"
            "8c4e2ghe7u.skadnetwork"
            "zq492l623r.skadnetwork"
            "3rd42ekr43.skadnetwork"
            "3qcr597p9d.skadnetwork"
        )
        for i in "${!SKADNETWORK_IDS[@]}"; do
            /usr/libexec/PlistBuddy -c "Add :SKAdNetworkItems:$i dict" "$PLIST_PATH"
            /usr/libexec/PlistBuddy -c "Add :SKAdNetworkItems:$i:SKAdNetworkIdentifier string ${SKADNETWORK_IDS[$i]}" "$PLIST_PATH"
        done
        echo "  + Added ${#SKADNETWORK_IDS[@]} SKAdNetworkItems"
    fi

    # NSUserTrackingUsageDescription (ATT)
    if ! /usr/libexec/PlistBuddy -c "Print :NSUserTrackingUsageDescription" "$PLIST_PATH" 2>/dev/null; then
        /usr/libexec/PlistBuddy -c "Add :NSUserTrackingUsageDescription string 'This app uses tracking to provide personalized ads.'" "$PLIST_PATH"
        echo "  + Added NSUserTrackingUsageDescription"
    fi

    # ITSAppUsesNonExemptEncryption
    if ! /usr/libexec/PlistBuddy -c "Print :ITSAppUsesNonExemptEncryption" "$PLIST_PATH" 2>/dev/null; then
        /usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST_PATH"
        echo "  + Added ITSAppUsesNonExemptEncryption = false"
    fi

    # Google Sign-In URL Scheme (TODO: replace with actual reversed client ID)
    GOOGLE_REVERSED_CLIENT_ID="com.googleusercontent.apps.TODO-IOS-CLIENT-ID"
    if ! /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$PLIST_PATH" 2>/dev/null; then
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$PLIST_PATH"
    fi
    FOUND_GOOGLE_SCHEME=false
    URL_TYPES_COUNT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$PLIST_PATH" 2>/dev/null | grep -c "Dict" || true)
    for ((i=0; i<URL_TYPES_COUNT; i++)); do
        SCHEME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:$i:CFBundleURLSchemes:0" "$PLIST_PATH" 2>/dev/null || true)
        if [ "$SCHEME" = "$GOOGLE_REVERSED_CLIENT_ID" ]; then
            FOUND_GOOGLE_SCHEME=true
            break
        fi
    done
    if [ "$FOUND_GOOGLE_SCHEME" = false ]; then
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$PLIST_PATH"
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST_PATH"
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $GOOGLE_REVERSED_CLIENT_ID" "$PLIST_PATH"
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$PLIST_PATH"
        echo "  + Added Google Sign-In URL scheme (TODO: replace placeholder)"
    fi
    echo "  Done."
else
    echo "[1/3] ERROR: Info.plist not found at $PLIST_PATH"
    exit 1
fi

# ============================================================================
# 2. Entitlements — Apple Sign-In
# ============================================================================
if [ -f "$ENTITLEMENTS_PATH" ]; then
    echo "[2/3] Patching Entitlements..."
    if ! /usr/libexec/PlistBuddy -c "Print :com.apple.developer.applesignin" "$ENTITLEMENTS_PATH" 2>/dev/null; then
        /usr/libexec/PlistBuddy -c "Add :com.apple.developer.applesignin array" "$ENTITLEMENTS_PATH"
        /usr/libexec/PlistBuddy -c "Add :com.apple.developer.applesignin:0 string Default" "$ENTITLEMENTS_PATH"
        echo "  + Added com.apple.developer.applesignin"
    fi
    echo "  Done."
else
    echo "[2/3] ERROR: Entitlements not found at $ENTITLEMENTS_PATH"
    exit 1
fi

# ============================================================================
# 3. project.pbxproj — 签名修复 + GoogleMobileAds embed 移除
# ============================================================================
PBXPROJ_PATH="$PROJECT_DIR/$APP_NAME.xcodeproj/project.pbxproj"

if [ -f "$PBXPROJ_PATH" ]; then
    echo "[3/3] Patching project.pbxproj..."

    if grep -q 'CODE_SIGN_IDENTITY = "Apple Distribution"' "$PBXPROJ_PATH"; then
        sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Distribution"/CODE_SIGN_IDENTITY = "Apple Development"/g' "$PBXPROJ_PATH"
        echo "  + Fixed CODE_SIGN_IDENTITY → Apple Development"
    fi

    if grep -q "589384010000000000000009" "$PBXPROJ_PATH"; then
        sed -i '' '/589384010000000000000009/d' "$PBXPROJ_PATH"
        echo "  + Removed GoogleMobileAds from Embed Frameworks"
    fi

    if grep -q "589384010000000000000007" "$PBXPROJ_PATH"; then
        sed -i '' '/589384010000000000000007$/d' "$PBXPROJ_PATH"
        echo "  + Removed GoogleMobileAds from Link phase"
    fi
    echo "  Done."
else
    echo "[3/3] ERROR: project.pbxproj not found at $PBXPROJ_PATH"
    exit 1
fi

echo ""
echo "=== Patch complete! ==="
echo "Next steps:"
echo "  1. Open $PROJECT_DIR/$APP_NAME.xcodeproj in Xcode"
echo "  2. Add Capabilities: Sign in with Apple + In-App Purchase"
echo "  3. Cmd+B to build"
echo "  4. Archive → Upload to TestFlight"
