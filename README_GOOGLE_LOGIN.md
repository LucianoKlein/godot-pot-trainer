# 移动端 Google 登录 - 快速开始

## 📱 项目说明

**平台**：Android + iOS APP
**功能**：Google 一键登录

---

## ✅ 代码已完成

所有代码已实现，只需配置即可使用。

---

## ⚡ 快速配置（5步）

### 1️⃣ 安装插件（5分钟）

**插件名称**：GodotGoogleSignIn
**安装方法**：
```
Godot 编辑器 > AssetLib > 搜索 "Google Sign-In" > 安装
```

或手动下载：https://github.com/Iakobs/godot-google-signin

---

### 2️⃣ 获取 Client IDs（15分钟）

访问：https://console.cloud.google.com/

**需要创建 3 个 Client ID**：

| 类型 | 用途 | 需要配置 |
|------|------|----------|
| Web Client ID | Firebase 认证 | - |
| Android Client ID | Android 登录 | 包名 + SHA-1 |
| iOS Client ID | iOS 登录 | Bundle ID |

**生成 SHA-1（Android）**：
```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

---

### 3️⃣ 配置代码（2分钟）

编辑文件：`scripts/autoload/google_signin_mobile.gd`

```gdscript
# 第 8-10 行，替换为你的 Client ID
const ANDROID_CLIENT_ID := "你的Android_Client_ID.apps.googleusercontent.com"
const IOS_CLIENT_ID := "你的iOS_Client_ID.apps.googleusercontent.com"
const WEB_CLIENT_ID := "你的Web_Client_ID.apps.googleusercontent.com"
```

---

### 4️⃣ 配置 Firebase（10分钟）

访问：https://console.firebase.google.com/

**步骤**：
1. Authentication > Sign-in method > 启用 Google
2. 添加 Android 应用 → 下载 `google-services.json`
3. 添加 iOS 应用 → 下载 `GoogleService-Info.plist`

**放置配置文件**：
```
google-services.json → android/build/google-services.json
GoogleService-Info.plist → ios/GoogleService-Info.plist
```

---

### 5️⃣ 测试（10分钟）

**Android**：
```bash
Project > Export > Android
安装 APK 到手机
测试 Google 登录
```

**iOS**：
```bash
Project > Export > iOS
在 Xcode 中打开
运行到真机测试
```

---

## 📚 详细文档

| 文档 | 说明 |
|------|------|
| `GOOGLE_LOGIN_CHECKLIST.md` | 配置检查清单 |
| `MOBILE_GOOGLE_LOGIN.md` | 详细配置指南 |
| `GOOGLE_LOGIN_COMPLETE.md` | 完整实现说明 |

---

## 🐛 常见问题

### Q1: 点击按钮没反应
- 检查插件是否安装并启用

### Q2: Android "Developer Error"
- 检查 SHA-1 证书指纹是否正确

### Q3: iOS "Invalid Client ID"
- 检查 Bundle ID 是否一致

### Q4: Firebase 认证失败
- 检查是否启用 Google 登录

---

## 🎯 完成后效果

```
用户打开 APP
    ↓
点击 "G 使用 Google 登录"
    ↓
选择 Google 账号
    ↓
自动登录成功
```

**一键登录，无需密码！** 🎉

---

## 📞 需要帮助？

查看详细文档：
- `GOOGLE_LOGIN_CHECKLIST.md` - 配置清单
- `MOBILE_GOOGLE_LOGIN.md` - 完整指南
