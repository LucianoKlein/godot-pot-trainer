# AdMob 集成总结

## ✅ 已完成的工作

### 1. 代码集成（100% 完成）

#### 创建了 AdMobManager 单例
- 文件：`scripts/autoload/admob_manager.gd`
- 功能：
  - 初始化 AdMob SDK
  - 加载和显示插屏广告
  - 处理广告回调（加载成功/失败、显示成功/失败、关闭）
  - 自动预加载下一个广告
  - 测试/正式广告 ID 切换

#### 修改了 AdOverlayManager
- 文件：`scripts/game/ui/ad_overlay_manager.gd`
- 改动：
  - 优先调用 AdMob 真实广告
  - 广告失败时自动降级到 fallback 倒计时界面
  - 监听 AdMob 回调信号

#### 配置了测试广告 ID
- 测试 App ID: `ca-app-pub-3940256099942544~3347511713`
- 测试插屏广告 ID: `ca-app-pub-3940256099942544/1033173712`
- 这些是 Google 官方测试 ID，可以验证集成但不产生收益

### 2. 文档（100% 完成）

- ✅ `ADMOB_SETUP.md` - 完整的集成指南和配置说明
- ✅ `ADMOB_INSTALL_GUIDE.md` - 详细的插件安装步骤

## 📋 下一步操作清单

### 必须完成（上架前）

1. **安装 AdMob 插件**
   - 下载：https://github.com/Poing-Studios/godot-admob-plugin/releases
   - 解压并复制 `addons/admob/` 到项目根目录
   - 在 Godot 编辑器中启用插件
   - 详见：`ADMOB_INSTALL_GUIDE.md`

2. **配置 Android 导出**
   - 添加网络权限（INTERNET, ACCESS_NETWORK_STATE）
   - 启用自定义构建（Use Custom Build）
   - 配置 AndroidManifest.xml（添加 AdMob App ID）
   - 详见：`ADMOB_INSTALL_GUIDE.md` 第四步

3. **真机测试**
   - 导出 APK 并安装到 Android 手机
   - 进入游客模式，答对 3 题
   - 验证测试广告是否正常显示
   - 检查 fallback 降级逻辑是否正常

4. **注册 AdMob 账号并创建广告单元**
   - 访问：https://apps.admob.google.com/
   - 创建应用，获取正式 App ID
   - 创建插屏广告单元，获取 Ad Unit ID

5. **替换为正式广告 ID**
   - 编辑 `scripts/autoload/admob_manager.gd`
   - 修改 `PROD_APP_ID` 和 `PROD_AD_UNIT_ID`
   - 将 `use_test_ads` 改为 `false`
   - 更新 AndroidManifest.xml 中的 App ID

### 可选优化

- 调整广告频率（当前每 3 题一次）
- 添加激励视频广告（用户主动观看换取奖励）
- 优化预加载时机
- 添加广告加载失败的重试逻辑

## 🔍 代码逻辑流程

```
游戏启动
  ↓
AdMobManager._ready()
  ↓
检查插件是否存在
  ├─ 是 → 初始化 AdMob SDK
  │         ↓
  │      预加载第一个广告
  │
  └─ 否 → 打印警告，所有广告请求将使用 fallback

用户答对 3 题
  ↓
GameManager.increment_guest_answer_count()
  ↓
触发 show_ad_requested 信号
  ↓
AdOverlayManager.show_ad()
  ↓
检查 AdMobManager.is_ad_ready()
  ├─ 是 → AdMobManager.show_interstitial()
  │         ↓
  │      显示 AdMob 真实广告
  │         ↓
  │      用户关闭广告
  │         ↓
  │      触发 ad_closed 信号
  │         ↓
  │      AdMobManager 自动预加载下一个广告
  │         ↓
  │      AdOverlayManager 清理状态
  │
  └─ 否 → _show_fallback_ad()
            ↓
         显示倒计时界面（15-30秒）
            ↓
         用户点击关闭按钮
            ↓
         AdOverlayManager 清理状态
```

## ⚠️ 重要提醒

1. **测试 ID 不能用于正式发布**
   - 使用测试 ID 发布到 Google Play 会导致账号被封禁
   - 上架前必须替换为正式 ID

2. **AdMob 只能在真机上测试**
   - 编辑器中无法显示广告
   - 必须导出 APK 并安装到 Android 设备

3. **新广告单元需要时间生效**
   - 在 AdMob 后台创建广告单元后，可能需要几小时才能开始投放
   - 测试期间可以继续使用测试 ID

4. **Fallback 机制很重要**
   - 网络问题、无广告填充时会自动降级
   - 确保用户体验不受影响

## 📊 预期效果

- **开发阶段**：显示 Google 官方测试广告（标有 "Test Ad"）
- **上架后**：显示真实广告，产生收益
- **网络异常**：自动降级到倒计时界面，不影响游戏流程
- **登录用户**：不触发广告（`is_guest_mode = false`）

## 🎯 当前状态

✅ 代码集成完成
✅ 测试配置完成
✅ 文档编写完成
⏳ 等待插件安装和真机测试
⏳ 等待 AdMob 账号注册和正式 ID 配置

---

**下一步建议**：按照 `ADMOB_INSTALL_GUIDE.md` 安装插件，然后导出 APK 进行真机测试。
