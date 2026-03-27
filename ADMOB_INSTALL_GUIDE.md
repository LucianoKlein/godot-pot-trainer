# AdMob 插件安装步骤（详细版）

## 第一步：下载插件

1. 访问 GitHub 发布页面：
   ```
   https://github.com/Poing-Studios/godot-admob-plugin/releases
   ```

2. 找到最新的 Godot 4.x 版本（例如 v9.0.0）

3. 下载 Android 版本：
   ```
   godot-admob-android-v9.0.0.zip
   ```

## 第二步：解压并安装

1. 解压下载的 zip 文件，你会看到：
   ```
   godot-admob-android-v9.0.0/
   ├── addons/
   │   └── admob/
   │       ├── plugin.cfg
   │       ├── admob.gdextension
   │       ├── bin/
   │       └── ...
   ```

2. 将整个 `addons/admob/` 文件夹复制到项目根目录：
   ```
   PotTrainer-game/
   ├── addons/
   │   └── admob/          ← 复制到这里
   │       ├── plugin.cfg
   │       ├── admob.gdextension
   │       └── ...
   ├── assets/
   ├── scenes/
   ├── scripts/
   └── project.godot
   ```

## 第三步：在 Godot 编辑器中启用插件

1. 打开 Godot 编辑器，加载 PotTrainer-game 项目

2. 点击顶部菜单：**项目 → 项目设置**

3. 切换到 **插件** 标签页

4. 找到 **AdMob** 插件（如果看不到，说明文件夹位置不对）

5. 勾选 **启用** 复选框

6. 关闭项目设置窗口

## 第四步：配置 Android 导出

### 4.1 创建 Android 导出预设

1. 点击顶部菜单：**项目 → 导出**

2. 如果没有 Android 预设，点击 **添加** → 选择 **Android**

3. 在 **Options** 标签页中配置：

   **Permissions（权限）**：
   - ✅ `INTERNET`
   - ✅ `ACCESS_NETWORK_STATE`

   **Custom Build（自定义构建）**：
   - ✅ `Use Custom Build`

4. 点击 **关闭**

### 4.2 配置 AndroidManifest.xml

1. 在项目根目录创建 `android/build/` 文件夹（如果不存在）

2. 创建或编辑 `android/build/AndroidManifest.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- 网络权限（AdMob 必需） -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <application
        android:label="@string/godot_project_name_string"
        android:allowBackup="false"
        tools:ignore="GoogleAppIndexingWarning"
        android:icon="@mipmap/icon">

        <!-- AdMob App ID（测试阶段使用测试 ID） -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3940256099942544~3347511713"/>

        <!-- Godot Activity -->
        <activity android:name="com.godot.game.GodotApp"
            android:theme="@style/GodotAppMainTheme"
            android:exported="true"
            tools:ignore="AppLinkUrlError,UnusedAttribute">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

## 第五步：验证安装

### 5.1 检查插件是否加载

在 Godot 编辑器中打开 **输出** 面板，运行项目，查找：
```
[AdMob] Plugin found, initializing...
[AdMob] Initialized with App ID: ca-app-pub-3940256099942544~3347511713
[AdMob] Loading interstitial ad: ca-app-pub-3940256099942544/1033173712
```

如果看到 `[AdMob] Plugin not found`，说明插件未正确安装。

### 5.2 导出 APK 测试

⚠️ **重要**：AdMob 只能在真机上测试，编辑器中无法显示广告。

1. 点击 **项目 → 导出**
2. 选择 Android 预设
3. 点击 **导出项目**，保存为 `PotTrainer-test.apk`
4. 将 APK 安装到 Android 手机
5. 运行游戏，选择游客模式
6. 答对 3 题后应该弹出测试广告（显示 "Test Ad" 字样）

## 常见问题

### Q1: 插件列表中看不到 AdMob
**A**: 检查文件夹结构，确保 `addons/admob/plugin.cfg` 存在

### Q2: 编辑器中看到 "Plugin not found"
**A**: 正常现象，AdMob 插件只在 Android/iOS 导出版本中可用

### Q3: 真机测试时广告不显示
**A**:
- 检查网络连接
- 查看 logcat 日志：`adb logcat | grep AdMob`
- 确认 AndroidManifest.xml 中的 App ID 正确

### Q4: 显示 fallback 倒计时界面
**A**:
- 开发阶段：插件未安装或广告加载失败，这是正常的降级行为
- 正式环境：网络问题或无广告填充

## 下一步

✅ 插件安装完成后，代码已经准备好
✅ 测试阶段使用测试广告 ID（已配置）
✅ 上架前记得替换为正式广告 ID（见 ADMOB_SETUP.md）

## 参考资料

- [插件官方文档](https://github.com/Poing-Studios/godot-admob-plugin)
- [AdMob 测试广告 ID](https://developers.google.com/admob/android/test-ads)
- [AdMob 控制台](https://apps.admob.google.com/)
