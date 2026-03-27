# AdMob 集成快速检查清单

## ✅ 代码集成（已完成）

- [x] 创建 `AdMobManager` 单例（`scripts/autoload/admob_manager.gd`）
- [x] 修改 `AdOverlayManager` 支持真实广告（`scripts/game/ui/ad_overlay_manager.gd`）
- [x] 在 `project.godot` 中注册 `AdMobManager` 自动加载
- [x] 配置测试广告 ID
- [x] 实现广告预加载逻辑
- [x] 实现 fallback 降级机制

## 📦 插件安装（待完成）

### 第一步：下载插件
- [ ] 访问 https://github.com/Poing-Studios/godot-admob-plugin/releases
- [ ] 下载最新的 `godot-admob-android-vX.X.X.zip`

### 第二步：安装插件
- [ ] 解压 zip 文件
- [ ] 复制 `addons/admob/` 到项目根目录
- [ ] 在 Godot 编辑器中打开项目
- [ ] 进入 **项目 → 项目设置 → 插件**
- [ ] 勾选启用 **AdMob** 插件

### 第三步：配置 Android 导出
- [ ] 进入 **项目 → 导出**
- [ ] 创建或选择 Android 预设
- [ ] 勾选权限：`INTERNET` 和 `ACCESS_NETWORK_STATE`
- [ ] 勾选 `Use Custom Build`

### 第四步：配置 AndroidManifest.xml
- [ ] 创建 `android/build/AndroidManifest.xml`
- [ ] 添加 AdMob App ID（测试 ID: `ca-app-pub-3940256099942544~3347511713`）
- [ ] 参考 `ADMOB_INSTALL_GUIDE.md` 中的完整模板

## 🧪 测试（待完成）

### 编辑器测试
- [ ] 运行项目，查看输出面板
- [ ] 确认看到 `[AdMob] Plugin found, initializing...`
- [ ] 如果看到 `[AdMob] Plugin not found`，说明插件未安装（正常，继续下一步）

### 真机测试
- [ ] 导出 APK（**项目 → 导出 → 导出项目**）
- [ ] 安装到 Android 手机
- [ ] 运行游戏，选择游客模式
- [ ] 答对 3 题，观察广告是否显示
- [ ] 预期结果：
  - **插件已安装**：显示测试广告（标有 "Test Ad"）
  - **插件未安装**：显示 fallback 倒计时界面（15-30秒）

## 🚀 上架准备（待完成）

### 注册 AdMob 账号
- [ ] 访问 https://apps.admob.google.com/
- [ ] 创建应用
- [ ] 获取正式 App ID（格式：`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`）
- [ ] 创建插屏广告单元
- [ ] 获取正式 Ad Unit ID（格式：`ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`）

### 替换为正式广告 ID
- [ ] 编辑 `scripts/autoload/admob_manager.gd`
- [ ] 修改 `PROD_APP_ID` 为你的正式 App ID
- [ ] 修改 `PROD_AD_UNIT_ID` 为你的正式 Ad Unit ID
- [ ] 将 `use_test_ads` 改为 `false`
- [ ] 更新 `android/build/AndroidManifest.xml` 中的 App ID

### 最终验证
- [ ] 导出正式版 APK
- [ ] 真机测试，确认显示真实广告（不再是 "Test Ad"）
- [ ] 测试 fallback 降级逻辑（断网情况下）
- [ ] 测试登录用户不显示广告

## 📝 文档参考

- **完整集成指南**：`ADMOB_SETUP.md`
- **详细安装步骤**：`ADMOB_INSTALL_GUIDE.md`
- **集成总结**：`ADMOB_SUMMARY.md`

## ⚠️ 重要提醒

1. **测试 ID 不能用于正式发布**
   - 使用测试 ID 发布会导致 AdMob 账号被封禁
   - 上架前必须替换为正式 ID

2. **AdMob 只能在真机上测试**
   - 编辑器中无法显示广告
   - 必须导出 APK 并安装到 Android 设备

3. **新广告单元需要时间生效**
   - 创建后可能需要几小时才能开始投放
   - 测试期间可以继续使用测试 ID

4. **Fallback 机制确保用户体验**
   - 网络问题或无广告填充时自动降级
   - 不会阻塞游戏流程

## 🎯 当前进度

```
代码集成    ████████████████████ 100%
插件安装    ░░░░░░░░░░░░░░░░░░░░   0%
真机测试    ░░░░░░░░░░░░░░░░░░░░   0%
AdMob注册   ░░░░░░░░░░░░░░░░░░░░   0%
正式ID配置  ░░░░░░░░░░░░░░░░░░░░   0%
```

## 📞 需要帮助？

- **插件安装问题**：查看 `ADMOB_INSTALL_GUIDE.md`
- **广告不显示**：检查网络权限和 AndroidManifest.xml 配置
- **Fallback 界面显示**：正常现象，说明 AdMob 广告未就绪
- **其他问题**：查看 Godot 输出面板的 `[AdMob]` 日志

---

**下一步建议**：按照"插件安装"部分的步骤，下载并安装 AdMob 插件，然后进行真机测试。
