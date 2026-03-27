# Google 登录快速配置清单

## ✅ 已完成的工作

### 代码实现
- ✅ GoogleSignInMobile 管理器（支持 Android/iOS）
- ✅ 登录面板集成 Google 登录按钮
- ✅ Firebase 认证集成
- ✅ 信号连接和回调处理
- ✅ 多语言支持

### 文件清单
```
新增：
- scripts/autoload/google_signin_mobile.gd

修改：
- project.godot
- scripts/main_menu/login_panel.gd
- scripts/autoload/locale.gd
```

---

## ⚠️ 需要配置的内容

### 1. 安装 Godot 插件（必需）

**推荐插件**：GodotGoogleSignIn
- GitHub: https://github.com/Iakobs/godot-google-signin
- 支持 Android 和 iOS

**安装方法**：
```bash
# 方法1：从 AssetLib 搜索 "Google Sign-In" 安装

# 方法2：手动下载
git clone https://github.com/Iakobs/godot-google-signin.git
# 复制 addons/godot-google-signin/ 到项目
```

**启用插件**：
- Project > Project Settings > Plugins
- 勾选 "Godot Google Sign-In"

---

### 2. 获取 Google Client IDs（必需）

访问：https://console.cloud.google.com/

**需要创建 3 个 Client ID**：

#### A. Web Client ID
```
应用类型：Web 应用
用途：Firebase 认证
示例：123456789-abcdefg.apps.googleusercontent.com
```

#### B. Android Client ID
```
应用类型：Android
包名：com.example.genname
SHA-1：需要生成（见下方）
```

#### C. iOS Client ID
```
应用类型：iOS
Bundle ID：从 iOS 导出配置获取
```

**生成 SHA-1 证书指纹（Android）**：
```bash
# 调试版本
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# 发布版本
keytool -list -v -keystore your-release-key.keystore -alias your-key-alias
```

---

### 3. 配置代码中的 Client IDs（必需）

编辑文件：`scripts/autoload/google_signin_mobile.gd`

```gdscript
# 第 8-10 行，替换为你的实际 Client ID
const ANDROID_CLIENT_ID := "YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com"
const IOS_CLIENT_ID := "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com"
const WEB_CLIENT_ID := "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
```

---

### 4. 配置 Firebase（必需）

访问：https://console.firebase.google.com/

#### 启用 Google 登录
```
Authentication > Sign-in method > Google > 启用
```

#### 添加 Android 应用
```
Project Settings > Your apps > Add app > Android
- 包名：com.example.genname
- SHA-1：粘贴上面生成的指纹
- 下载：google-services.json
```

#### 添加 iOS 应用
```
Project Settings > Your apps > Add app > iOS
- Bundle ID：从 iOS 导出配置获取
- 下载：GoogleService-Info.plist
```

---

### 5. 配置 Android 项目（必需）

#### A. 放置配置文件
```
下载的 google-services.json
→ 放到 →
android/build/google-services.json
```

#### B. 修改 build.gradle
编辑：`android/build/build.gradle`

添加：
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}

apply plugin: 'com.google.gms.google-services'
```

---

### 6. 配置 iOS 项目（必需）

#### A. 放置配置文件
```
下载的 GoogleService-Info.plist
→ 放到 →
ios/GoogleService-Info.plist
```

#### B. 配置 URL Scheme
在 iOS 导出设置中添加：
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

---

## 🧪 测试步骤

### Android 测试
```bash
1. Project > Export > Android
2. 导出 APK
3. adb install build/Pot-Trainer-test1.apk
4. 打开 APP
5. 点击 "G 使用 Google 登录"
6. 选择 Google 账号
7. 验证登录成功
```

### iOS 测试
```bash
1. Project > Export > iOS
2. 在 Xcode 中打开
3. 配置签名
4. 运行到真机
5. 测试 Google 登录
```

---

## 🐛 常见问题

### 问题1：点击按钮没反应
- [ ] 检查插件是否安装
- [ ] 检查插件是否启用
- [ ] 查看 Godot 输出日志

### 问题2：Android "Developer Error"
- [ ] 检查 SHA-1 是否正确
- [ ] 检查包名是否一致
- [ ] 重新下载 google-services.json

### 问题3：iOS "Invalid Client ID"
- [ ] 检查 Bundle ID 是否一致
- [ ] 检查 URL Scheme 是否正确
- [ ] 重新下载 GoogleService-Info.plist

### 问题4：登录成功但 Firebase 失败
- [ ] 检查 Firebase 是否启用 Google 登录
- [ ] 检查 Web Client ID 是否正确
- [ ] 查看 Firebase Console 日志

---

## 📋 配置检查清单

### 代码配置
- [ ] 安装 GodotGoogleSignIn 插件
- [ ] 启用插件
- [ ] 配置 3 个 Client IDs

### Firebase 配置
- [ ] 启用 Google 登录
- [ ] 添加 Android 应用
- [ ] 添加 iOS 应用
- [ ] 下载配置文件

### Android 配置
- [ ] 生成 SHA-1 指纹
- [ ] 放置 google-services.json
- [ ] 修改 build.gradle

### iOS 配置
- [ ] 放置 GoogleService-Info.plist
- [ ] 配置 URL Scheme

### 测试
- [ ] Android 测试通过
- [ ] iOS 测试通过

---

## 📚 相关文档

- **详细配置指南**：`MOBILE_GOOGLE_LOGIN.md`
- **项目架构说明**：`CLAUDE.md`
- **插件文档**：https://github.com/Iakobs/godot-google-signin

---

## 💡 提示

1. **调试版本和发布版本的 SHA-1 不同**
   - 调试：使用 debug.keystore
   - 发布：使用你的发布密钥

2. **每次更换密钥需要重新配置**
   - 生成新的 SHA-1
   - 在 Google Cloud Console 添加
   - 在 Firebase Console 更新

3. **iOS 需要真机测试**
   - 模拟器可能不支持 Google 登录
   - 需要配置开发者证书

4. **首次登录可能较慢**
   - Google 需要验证配置
   - 后续登录会更快

---

## ✅ 完成后的效果

用户体验：
1. 打开 APP
2. 点击"登录"
3. 看到 "G 使用 Google 登录" 按钮
4. 点击按钮
5. 弹出 Google 账号选择界面
6. 选择账号
7. 自动登录成功
8. 进入游戏

**一键登录，无需输入密码！** 🎉
