# AdMob 集成指南

## 已完成的代码集成

✅ 创建了 `AdMobManager` 单例（`scripts/autoload/admob_manager.gd`）
✅ 修改了 `AdOverlayManager` 支持真实广告 + fallback 倒计时
✅ 配置了测试广告 ID（开发阶段使用）

## 下一步：安装 AdMob 插件

### 1. 下载插件

访问 [Poing Studios Godot AdMob Plugin](https://github.com/Poing-Studios/godot-admob-plugin/releases)

下载最新版本（支持 Godot 4.x）：
- `godot-admob-android-vX.X.X.zip`（Android 版本）
- `godot-admob-ios-vX.X.X.zip`（iOS 版本，如果需要）

### 2. 安装插件

1. 解压下载的 zip 文件
2. 将 `addons/admob/` 文件夹复制到项目根目录的 `addons/` 文件夹中
   ```
   PotTrainer-game/
   ├── addons/
   │   └── admob/
   │       ├── plugin.cfg
   │       ├── admob.gdextension
   │       └── ...
   ```

3. 打开 Godot 编辑器
4. 进入 **项目 → 项目设置 → 插件**
5. 找到 **AdMob** 插件，勾选启用

### 3. 配置 Android 导出设置

1. 进入 **项目 → 导出**
2. 选择 **Android** 预设（如果没有则新建）
3. 在 **Options** 标签页中：
   - **Permissions** 部分：
     - 勾选 `INTERNET`（必需）
     - 勾选 `ACCESS_NETWORK_STATE`（必需）
   - **Custom Build** 部分：
     - 勾选 `Use Custom Build`（必需）

4. 在 **android/build/** 目录下创建或编辑 `AndroidManifest.xml`，添加 AdMob App ID：
   ```xml
   <manifest>
       <application>
           <!-- AdMob App ID (测试阶段使用测试 ID) -->
           <meta-data
               android:name="com.google.android.gms.ads.APPLICATION_ID"
               android:value="ca-app-pub-3940256099942544~3347511713"/>
       </application>
   </manifest>
   ```

### 4. 测试广告（开发阶段）

当前代码已配置测试广告 ID：
- **App ID**: `ca-app-pub-3940256099942544~3347511713`
- **插屏广告 ID**: `ca-app-pub-3940256099942544/1033173712`

这些是 Google 官方提供的测试 ID，不会产生真实收益，但可以验证集成是否正确。

**测试步骤**：
1. 导出 APK 并安装到 Android 真机（编辑器中无法测试广告）
2. 进入游戏，选择游客模式
3. 答对 3 题后应该弹出测试广告
4. 广告会显示 "Test Ad" 字样，倒计时 5 秒后可关闭

### 5. 上架前：替换为正式广告 ID

1. 访问 [Google AdMob 控制台](https://apps.admob.google.com/)
2. 创建应用并获取正式 App ID
3. 创建插屏广告单元并获取 Ad Unit ID
4. 修改 `scripts/autoload/admob_manager.gd`：
   ```gdscript
   # 替换为你的正式 ID
   const PROD_APP_ID := "ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"
   const PROD_AD_UNIT_ID := "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ"

   # 上架前改为 false
   var use_test_ads: bool = false
   ```
5. 同步更新 `AndroidManifest.xml` 中的 App ID

### 6. 故障排查

**广告不显示？**
- 检查控制台日志：`[AdMob] Plugin not found` → 插件未安装或未启用
- 检查网络权限：确保 `INTERNET` 权限已添加
- 检查真机测试：AdMob 只能在真机上运行，编辑器中无效

**广告加载失败？**
- 测试阶段：确认使用的是测试 ID
- 正式环境：新创建的广告单元可能需要几小时才能生效
- 网络问题：检查设备网络连接

**Fallback 倒计时界面显示？**
- 这是正常的降级行为，说明 AdMob 广告未就绪
- 开发阶段：插件未安装时会自动使用 fallback
- 正式环境：网络问题或无广告填充时会使用 fallback

## 代码逻辑

```
用户答对 3 题
  ↓
GameManager.increment_guest_answer_count()
  ↓
触发 show_ad_requested 信号
  ↓
AdOverlayManager.show_ad()
  ↓
检查 AdMobManager.is_ad_ready()
  ├─ 是 → 显示 AdMob 真实广告
  │         ↓
  │      用户关闭广告
  │         ↓
  │      AdMobManager 预加载下一个广告
  │
  └─ 否 → 显示 fallback 倒计时界面（15-30秒）
            ↓
         用户点击关闭按钮
```

## 收益优化建议

1. **预加载**：已实现，游戏启动和广告关闭后自动预加载
2. **频率控制**：当前每 3 题一次，可根据用户反馈调整
3. **登录激励**：已实现"登录即可免广告"提示
4. **广告类型**：当前使用插屏广告，未来可考虑激励视频（用户主动观看换取奖励）

## 注意事项

⚠️ **测试 ID 不能用于正式发布**：上架前必须替换为正式 ID，否则账号可能被封禁
⚠️ **首次广告加载需要时间**：建议在游戏启动时预加载，避免用户等待
⚠️ **广告填充率**：并非每次都能成功加载广告，fallback 机制确保用户体验
