# 移动端 Google 登录配置指南

## 概述

本项目已集成移动端 Google 一键登录功能，支持 Android 和 iOS 平台。

## 架构说明

```
用户点击 Google 登录按钮
    ↓
GoogleSignInMobile.start_signin()
    ↓
调用原生插件（Android/iOS）
    ↓
Google 原生登录界面
    ↓
返回 ID Token 和 Email
    ↓
FirebaseAuth.login_google(id_token)
    ↓
Firebase 验证
    ↓
登录成功
```

## 需要的插件

### Android 平台
推荐使用：**GodotGoogleSignIn** 插件

插件地址：
- https://github.com/Iakobs/godot-google-signin

### iOS 平台
推荐使用：**GodotGoogleSignIn** 插件（同一个插件支持双平台）

## 配置步骤

### 第一步：获取 Google OAuth Client IDs

#### 1. 访问 Google Cloud Console
https://console.cloud.google.com/

#### 2. 选择项目
选择 `reg-training-tool` 项目

#### 3. 创建 OAuth 2.0 客户端 ID

需要创建 **3 个** Client ID：

**A. Web Client ID**（用于 Firebase）
- 应用类型：Web 应用
- 名称：Web client (auto created by Google Service)
- 这个 ID 会在 Android 和 iOS 中使用

**B. Android Client ID**
- 应用类型：Android
- 包名：`com.example.genname`（从 export_presets.cfg 获取）
- SHA-1 证书指纹：需要生成

**C. iOS Client ID**
- 应用类型：iOS
- Bundle ID：从 iOS 导出配置获取
- App Store ID：（可选）

#### 4. 获取 SHA-1 证书指纹（Android）

**调试版本**：
```bash
# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# macOS/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**发布版本**：
```bash
keytool -list -v -keystore your-release-key.keystore -alias your-key-alias
```

复制 SHA-1 指纹，例如：
```
SHA1: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
```

### 第二步：配置 Firebase

#### 1. 访问 Firebase Console
https://console.firebase.google.com/

#### 2. 选择项目
选择 `reg-training-tool` 项目

#### 3. 启用 Google 登录
- 进入 **Authentication** > **Sign-in method**
- 启用 **Google** 登录提供商
- 配置项目支持电子邮件

#### 4. 添加 Android 应用
- 进入 **Project Settings** > **Your apps**
- 点击 **Add app** > **Android**
- 包名：`com.example.genname`
- SHA-1 证书指纹：粘贴上面获取的指纹
- 下载 `google-services.json` 文件

#### 5. 添加 iOS 应用
- 点击 **Add app** > **iOS**
- Bundle ID：从 iOS 导出配置获取
- 下载 `GoogleService-Info.plist` 文件

### 第三步：安装 Godot 插件

#### 方法1：从 AssetLib 安装（推荐）

1. 打开 Godot 编辑器
2. 点击 **AssetLib** 标签
3. 搜索 "Google Sign-In"
4. 下载并安装插件

#### 方法2：手动安装

1. 下载插件：
   ```bash
   git clone https://github.com/Iakobs/godot-google-signin.git
   ```

2. 复制插件文件到项目：
   ```
   godot-google-signin/addons/godot-google-signin/
   → 复制到 →
   PotTrainer-game/addons/godot-google-signin/
   ```

3. 在 Godot 编辑器中启用插件：
   - **Project** > **Project Settings** > **Plugins**
   - 勾选 **Godot Google Sign-In**

### 第四步：配置项目

#### 1. 配置 Client IDs

编辑 `scripts/autoload/google_signin_mobile.gd`：

```gdscript
# 第 8-10 行
const ANDROID_CLIENT_ID := "YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com"
const IOS_CLIENT_ID := "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com"
const WEB_CLIENT_ID := "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
```

替换为你的实际 Client ID。

#### 2. 配置 Android

**A. 放置 google-services.json**
```
PotTrainer-game/android/build/google-services.json
```

**B. 配置 build.gradle**

编辑 `android/build/build.gradle`，添加：

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}

apply plugin: 'com.google.gms.google-services'
```

#### 3. 配置 iOS

**A. 放置 GoogleService-Info.plist**
```
PotTrainer-game/ios/GoogleService-Info.plist
```

**B. 配置 URL Schemes**

在 iOS 导出设置中添加 URL Scheme：
- 打开 **Project** > **Export**
- 选择 iOS 导出预设
- 在 **Custom Info.plist** 中添加：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

`YOUR_REVERSED_CLIENT_ID` 格式：`com.googleusercontent.apps.123456789`

### 第五步：测试

#### Android 测试

1. 导出 APK：
   ```
   Project > Export > Android
   ```

2. 安装到手机：
   ```bash
   adb install build/Pot-Trainer-test1.apk
   ```

3. 打开 APP，点击 Google 登录按钮

4. 选择 Google 账号登录

#### iOS 测试

1. 导出 Xcode 项目

2. 在 Xcode 中打开项目

3. 配置签名和证书

4. 运行到真机或模拟器

5. 测试 Google 登录

## 常见问题

### Q1: 点击 Google 登录没反应

**检查项**：
1. 插件是否正确安装
2. Client ID 是否正确配置
3. SHA-1 证书指纹是否正确
4. google-services.json 是否放置正确

**调试方法**：
```bash
# Android 查看日志
adb logcat | grep -i "google\|signin"
```

### Q2: Android 提示 "Developer Error"

**原因**：SHA-1 证书指纹不匹配

**解决方法**：
1. 重新生成 SHA-1 指纹
2. 在 Google Cloud Console 更新
3. 在 Firebase Console 更新
4. 重新下载 google-services.json

### Q3: iOS 提示 "Invalid Client ID"

**原因**：Bundle ID 或 Client ID 配置错误

**解决方法**：
1. 检查 Bundle ID 是否一致
2. 检查 URL Scheme 是否正确
3. 重新下载 GoogleService-Info.plist

### Q4: 登录成功但 Firebase 认证失败

**原因**：Firebase 未启用 Google 登录

**解决方法**：
1. 访问 Firebase Console
2. Authentication > Sign-in method
3. 启用 Google 登录
4. 确认 Web Client ID 正确

## 文件清单

### 新增文件
- `scripts/autoload/google_signin_mobile.gd` - Google 登录管理器

### 修改文件
- `project.godot` - 添加 GoogleSignInMobile 自动加载
- `scripts/main_menu/login_panel.gd` - 集成 Google 登录按钮
- `scripts/autoload/locale.gd` - 添加翻译文本

### 需要添加的文件（配置后）
- `android/build/google-services.json` - Android Firebase 配置
- `ios/GoogleService-Info.plist` - iOS Firebase 配置
- `addons/godot-google-signin/` - Google 登录插件

## 下一步

1. ✅ 代码已完成
2. ⚠️ 获取 Google OAuth Client IDs
3. ⚠️ 配置 Firebase
4. ⚠️ 安装 Godot 插件
5. ⚠️ 配置 Android/iOS
6. ⚠️ 测试登录功能

## 技术支持

如有问题，请检查：
1. Godot 输出日志
2. Android logcat
3. Xcode 控制台
4. Firebase Console 认证日志
