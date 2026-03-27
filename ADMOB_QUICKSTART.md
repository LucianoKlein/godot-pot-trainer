# AdMob 快速开始指南

## 🎯 目标
让游客模式下的用户每答对 3 题观看一次真实的 Google AdMob 广告（15-30秒），登录用户免广告。

## ✅ 已完成（代码集成 100%）

所有代码已经写好并集成到项目中：
- ✅ `AdMobManager` 单例管理广告加载和显示
- ✅ `AdOverlayManager` 支持真实广告 + fallback 降级
- ✅ 测试广告 ID 已配置
- ✅ 自动预加载机制
- ✅ 答题计数和触发逻辑

**代码已经可以运行，只需要安装插件即可。**

## 📦 下一步：安装 AdMob 插件（5 分钟）

### 1. 下载插件
访问：https://github.com/Poing-Studios/godot-admob-plugin/releases
下载：`godot-admob-android-vX.X.X.zip`（选择最新版本）

### 2. 安装插件
```
1. 解压 zip 文件
2. 复制 addons/admob/ 到项目根目录
3. 打开 Godot 编辑器
4. 项目 → 项目设置 → 插件
5. 勾选启用 AdMob
```

### 3. 配置 Android 导出
```
1. 项目 → 导出 → 添加 Android 预设
2. 勾选权限：INTERNET, ACCESS_NETWORK_STATE
3. 勾选 Use Custom Build
```

### 4. 配置 AndroidManifest.xml
在 `android/build/AndroidManifest.xml` 中添加：
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

完整模板见：`ADMOB_INSTALL_GUIDE.md`

## 🧪 测试（真机测试）

```
1. 导出 APK（项目 → 导出 → 导出项目）
2. 安装到 Android 手机
3. 运行游戏，选择游客模式
4. 答对 3 题
5. 观察广告显示：
   - 插件已安装 → 显示测试广告（标有 "Test Ad"）
   - 插件未安装 → 显示 fallback 倒计时界面
```

⚠️ **重要**：AdMob 只能在真机上测试，编辑器中无法显示广告。

## 🚀 上架前准备

### 1. 注册 AdMob 账号
访问：https://apps.admob.google.com/
- 创建应用
- 创建插屏广告单元
- 获取正式 App ID 和 Ad Unit ID

### 2. 替换为正式广告 ID
编辑 `scripts/autoload/admob_manager.gd`：
```gdscript
const PROD_APP_ID := "ca-app-pub-你的AppID~YYYYYYYYYY"
const PROD_AD_UNIT_ID := "ca-app-pub-你的AppID/ZZZZZZZZZZ"
var use_test_ads: bool = false  // 改为 false
```

同时更新 `AndroidManifest.xml` 中的 App ID。

⚠️ **警告**：使用测试 ID 发布到 Google Play 会导致账号被封禁！

## 📚 详细文档

- **完整安装步骤**：`ADMOB_INSTALL_GUIDE.md`（推荐先看这个）
- **集成说明**：`ADMOB_SETUP.md`
- **检查清单**：`ADMOB_CHECKLIST.md`
- **集成总结**：`ADMOB_SUMMARY.md`

## 🔍 工作原理

```
用户答对 3 题
  ↓
触发广告请求
  ↓
检查 AdMob 是否就绪
  ├─ 是 → 显示真实广告（5秒后可关闭）
  └─ 否 → 显示 fallback 倒计时（15-30秒）
  ↓
用户关闭广告
  ↓
继续游戏
```

## ⚡ 快速验证

运行项目，查看输出面板：
- 看到 `[AdMob] Plugin found` → 插件已安装 ✅
- 看到 `[AdMob] Plugin not found` → 插件未安装，需要按上面步骤安装

## 💡 提示

1. **开发阶段**：使用测试 ID，可以无限次测试
2. **上架前**：必须替换为正式 ID
3. **Fallback 机制**：确保网络问题时不影响游戏体验
4. **登录用户**：不会触发广告（`is_guest_mode = false`）

---

**现在就开始**：按照"安装 AdMob 插件"部分的 4 个步骤操作，5 分钟即可完成！
