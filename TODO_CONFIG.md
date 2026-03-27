# 项目配置待办清单

## 📋 当前项目状态

### ✅ 已完成的功能
1. **布局优化**
   - 布局编辑器高度调整（650px）
   - 布局数据硬编码到项目

2. **登录系统**
   - 邮箱密码登录（完整可用）
   - Google 登录代码（已实现，需配置）
   - Firebase 认证集成
   - 登录状态持久化

3. **语言系统**
   - 中英文切换
   - 语言设置持久化

4. **游戏功能**
   - 完整的游戏逻辑
   - 布局编辑器
   - 音效和音乐

---

## ⚠️ 需要配置的内容

### 1. Google 登录配置（可选，但推荐）

#### 为什么需要配置？
- 提供更好的用户体验
- 一键登录，无需记密码
- 符合用户习惯

#### 需要做什么？

**第一步：安装 Godot 插件**
```
时间：5分钟
操作：
1. 打开 Godot 编辑器
2. 点击 AssetLib 标签
3. 搜索 "Google Sign-In"
4. 下载并安装 GodotGoogleSignIn 插件
5. Project > Project Settings > Plugins > 勾选启用

或者手动安装：
https://github.com/Iakobs/godot-google-signin
```

**第二步：获取 Google OAuth Client IDs**
```
时间：15分钟
操作：
1. 访问 https://console.cloud.google.com/
2. 选择项目 "reg-training-tool"
3. 创建 3 个 OAuth 2.0 客户端 ID：

   A. Web Client ID（Firebase 用）
      - 应用类型：Web 应用
      - 记录 Client ID

   B. Android Client ID
      - 应用类型：Android
      - 包名：com.example.genname
      - SHA-1 证书指纹：需要生成（见下方）

   C. iOS Client ID
      - 应用类型：iOS
      - Bundle ID：从 iOS 导出配置获取
```

**生成 SHA-1 证书指纹（Android）**
```bash
# Windows 调试版本
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# 发布版本（如果有）
keytool -list -v -keystore your-release-key.keystore -alias your-key-alias

# 复制输出中的 SHA1 指纹
# 格式：AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
```

**第三步：配置代码**
```
时间：2分钟
操作：
1. 打开文件：scripts/autoload/google_signin_mobile.gd
2. 找到第 8-10 行
3. 替换为你的实际 Client ID：

const ANDROID_CLIENT_ID := "你的Android_Client_ID.apps.googleusercontent.com"
const IOS_CLIENT_ID := "你的iOS_Client_ID.apps.googleusercontent.com"
const WEB_CLIENT_ID := "你的Web_Client_ID.apps.googleusercontent.com"
```

**第四步：配置 Firebase**
```
时间：10分钟
操作：
1. 访问 https://console.firebase.google.com/
2. 选择项目 "reg-training-tool"
3. Authentication > Sign-in method > 启用 Google
4. 添加 Android 应用：
   - 包名：com.example.genname
   - SHA-1：粘贴上面生成的指纹
   - 下载 google-services.json
5. 添加 iOS 应用：
   - Bundle ID：从 iOS 导出配置获取
   - 下载 GoogleService-Info.plist
```

**第五步：配置 Android 项目**
```
时间：5分钟
操作：
1. 将 google-services.json 放到：
   android/build/google-services.json

2. 编辑 android/build/build.gradle，添加：
   buildscript {
       dependencies {
           classpath 'com.google.gms:google-services:4.3.15'
       }
   }

   apply plugin: 'com.google.gms.google-services'
```

**第六步：配置 iOS 项目**
```
时间：5分钟
操作：
1. 将 GoogleService-Info.plist 放到：
   ios/GoogleService-Info.plist

2. 在 iOS 导出设置中添加 URL Scheme：
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

**第七步：测试**
```
时间：10分钟
操作：
1. 导出 Android APK
2. 安装到手机
3. 点击 "G 使用 Google 登录"
4. 验证登录成功
```

---

### 2. 如果不配置 Google 登录会怎样？

#### 用户体验
- ✅ 邮箱密码登录完全可用
- ✅ 所有游戏功能正常
- ❌ 没有 Google 一键登录按钮
- ❌ 用户需要记住密码

#### 代码行为
```
如果没有安装插件：
- Google 登录按钮会显示
- 点击后提示 "Google Sign-In not available"
- 不会崩溃，只是功能不可用

如果安装了插件但没配置：
- Google 登录按钮会显示
- 点击后可能提示 "Developer Error"
- 不会崩溃，用户可以用邮箱登录
```

#### 建议
- **推荐配置**：提供更好的用户体验
- **可以不配置**：邮箱登录完全够用
- **分阶段配置**：先发布邮箱登录版本，后续更新添加 Google 登录

---

## 📊 配置优先级

### 高优先级（必须配置）
无，项目可以直接使用

### 中优先级（推荐配置）
1. **Google 登录**
   - 提升用户体验
   - 降低登录门槛
   - 时间：约 50 分钟

### 低优先级（可选配置）
无

---

## 🚀 快速决策

### 方案A：立即发布（不配置 Google 登录）
```
优点：
✅ 立即可用
✅ 无需额外配置
✅ 邮箱登录完全够用

缺点：
❌ 用户体验稍差
❌ 需要记住密码

时间：0 分钟
```

### 方案B：配置后发布（推荐）
```
优点：
✅ 更好的用户体验
✅ 一键登录
✅ 符合用户习惯

缺点：
❌ 需要配置时间

时间：约 50 分钟
```

---

## 📝 配置文档

### 详细配置指南
- `README_GOOGLE_LOGIN.md` - 快速开始
- `GOOGLE_LOGIN_CHECKLIST.md` - 配置清单
- `MOBILE_GOOGLE_LOGIN.md` - 完整指南

### 如果遇到问题
1. 查看文档中的"常见问题"部分
2. 检查 Godot 输出日志
3. 检查 Android logcat 日志

---

## 🎯 总结

### 当前状态
- ✅ 代码 100% 完成
- ✅ 可以直接使用（邮箱登录）
- ⚠️ Google 登录需要配置（可选）

### 建议
1. **如果时间紧**：直接发布，使用邮箱登录
2. **如果有时间**：配置 Google 登录，提升体验
3. **分阶段发布**：先发布邮箱版本，后续更新添加 Google 登录

### 下一步
- 如果配置 Google 登录：查看 `README_GOOGLE_LOGIN.md`
- 如果直接发布：导出 APK/IPA 即可

---

## 📞 明天继续开发

### 如果需要配置 Google 登录
```
告诉 Claude Code：
"帮我配置 Google 登录，按照 README_GOOGLE_LOGIN.md 的步骤"
```

### 如果遇到问题
```
告诉 Claude Code：
"Google 登录配置遇到问题：[具体错误信息]"
```

### 如果要添加其他功能
```
告诉 Claude Code：
"我想添加 [具体功能]"
```

---

## ✅ 最终答案

**项目当前需要配置的内容：**

### 必须配置：无
- 项目可以直接使用
- 邮箱密码登录完全可用

### 推荐配置：Google 登录（可选）
- 时间：约 50 分钟
- 步骤：7 步
- 文档：`README_GOOGLE_LOGIN.md`

### 结论
**项目已经可以直接打包发布！**

**Google 登录是可选的增强功能，不配置也完全可用！**
