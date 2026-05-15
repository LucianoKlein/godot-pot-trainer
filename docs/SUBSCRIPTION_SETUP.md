# PotTrainer 订阅接入指南

单一套餐 `pot_trainer_monthly` $12.99/月，解锁无广告无限答题。
四个平台按顺序操作，不来回切换。

## 代码状态（已完成，无需改动）

| 文件 | 状态 |
|---|---|
| `RevenueCatPlugin.kt` | ✅ 已创建，7 方法 6 信号 |
| `GodotApp.kt` | ✅ 已注册 RevenueCatPlugin |
| `build.gradle` | ✅ 已添加 `purchases:9.11.0` |
| `subscription_manager.gd` | ✅ PRODUCT_ID = `pot_trainer_monthly` |
| `AndroidManifest.xml` | ✅ AdMob App ID 已配置 |

## 关键参数速查

| 参数 | 值 |
|---|---|
| 包名 | `com.potLimitTrainer.game` |
| 产品 ID | `pot_trainer_monthly` |
| Entitlement ID | `pot_trainer` |
| 价格 | $12.99/月 |
| AdMob App ID | `ca-app-pub-6026501864639451~8989694651` |

---

## 第一站：Google Cloud Console（一次做完再离开）

> 如果你已经有 Service Account JSON（BoardAnalysis 用的那个），且该 Service Account 已经有 Pub/Sub Admin 权限，可以跳过此站，直接去第二站。

### 0.1 创建 Service Account（如果还没有）

1. 打开 Google Cloud Console → 选择你的项目（和 BoardAnalysis 同一个项目即可）
2. 左侧 **IAM & Admin → Service Accounts**
3. 如果已有 Service Account，跳到 0.2
4. 如果没有：点 **+ Create Service Account**
   - Name: `revenuecat-integration`（随意）
   - 点 Create and Continue
   - Role 添加两个：
     - `Pub/Sub Admin`
     - `Monitoring Viewer`（可选）
   - Done

### 0.2 确认权限

1. 点击已有的 Service Account
2. 确认 IAM 角色中包含 **Pub/Sub Admin**
3. 如果没有：去 **IAM & Admin → IAM** → 找到该 Service Account → Edit → Add Role → `Pub/Sub Admin` → Save

### 0.3 下载 JSON Key（如果还没有）

1. 点击 Service Account → **Keys** tab
2. **Add Key → Create new key → JSON → Create**
3. 下载保存好（RevenueCat 要用）
4. 如果 BoardAnalysis 已经下载过且还保留着，直接复用那个 JSON 文件，不需要重新创建

### 0.4 启用 API

1. 左侧 **APIs & Services → Enabled APIs**
2. 确认以下 API 已启用：
   - **Google Play Android Developer API**
   - **Cloud Pub/Sub API**
3. 如果没启用：搜索对应名称 → Enable

**Google Cloud Console 操作完毕，关掉页面。**

---

## 第二站：Google Play Console（一次做完再离开）

### 2.1 关联 Service Account

1. 打开 Google Play Console → 选择 Pot Trainer 应用
2. 左侧 **Settings → API access**
3. 找到你的 Service Account → 点 **Grant access** 或 **Manage permissions**
4. 勾选权限：
   - **View app information and download bulk reports**
   - **View financial data, orders, and cancellation survey responses**
   - **Manage orders and subscriptions**
   - **Manage store presence**
5. 点 **Invite user** / **Save changes**
6. 确认 Service Account 状态显示为已关联

### 2.2 创建订阅产品

1. 左侧 **Monetize → Subscriptions** → **Create subscription**
3. 填写：
   - Product ID: `pot_trainer_monthly`
   - Name: `Pot Trainer Monthly`
4. 保存后，点击进入该订阅 → **Add base plan**：
   - Base plan ID: `pot-trainer-monthly`（记住这个 ID，RevenueCat 要用）
   - Billing period: `1 Month`
   - Price: 设置 $12.99（点 Set price → 输入 12.99 → Apply to all countries）
5. 激活 base plan → 确认订阅状态为 **Active**

### 2.3 添加测试账号

1. 左侧 **Settings → License testing**
2. 添加你的测试 Gmail 邮箱
3. License response 选 `RESPOND_NORMALLY`
4. Save

### 2.4 创建 Internal Testing 轨道（如果还没有）

1. 左侧 **Test and release → Testing → Internal testing**
2. **Testers** tab → Create email list → 添加测试 Gmail
3. 后面打包好 AAB 后回来上传（第四站）

**Google Play Console 操作完毕，关掉页面。**

---

## 第三站：RevenueCat Dashboard（一次做完再离开）

### 3.1 创建项目（如果还没有）

1. 打开 RevenueCat Dashboard
2. 如果 Pot Trainer 项目已存在，直接进入；如果没有：
   - **+ New Project** → Name: `Pot Trainer`
   - 添加 App → Platform: **Google Play Store**
   - Package name: `com.potLimitTrainer.game`

### 3.2 连接 Google Play Store

1. 进入项目 → 左侧 **App Settings**（或 Service Credentials）
2. 上传 Google Cloud Service Account JSON（和 BoardAnalysis 用同一个 JSON 文件）
3. 等待显示 **Connected**（绿色）

### 3.3 创建 Product

1. 左侧 **Products** → **+ New**
2. 填写：
   - Display name: `pot_trainer_monthly`
   - Product type: **Subscription**
   - Subscription: `pot_trainer_monthly`
   - Base plan Id: `pot-trainer-monthly`（第二站 2.2 步创建的那个）
3. 点 **Create Product**
4. 确认状态为 **Published**（不是 Not found）

### 3.4 创建 Entitlement

1. 左侧 **Entitlements** → **+ New**
2. Identifier: `pot_trainer`
3. Save
4. 点进 `pot_trainer` → **Attach** → 选择 `pot_trainer_monthly:pot-trainer-monthly`
5. 确认产品已关联

### 3.5 创建 Offering

1. 左侧 **Offerings** → **+ New**
2. Identifier: `default`（如果已存在就用已有的）
3. Description: `Default Offering`
4. 创建后点进去 → **+ New Package**：
   - Identifier: 选 `Monthly`
   - Description: `Pot Trainer Monthly`
   - Product: 选 `pot_trainer_monthly:pot-trainer-monthly`
5. Save
6. 确认 `default` offering 是 **Current**（如果不是，点 `...` → Make Current / Make Default）

### 3.6 记录 API Key

1. 左侧 **API Keys**
2. 复制 **Public app-specific API key**（格式 `goog_xxxxx`）
3. 这个 key 要替换代码里的 `RC_API_KEY_ANDROID`

**RevenueCat 操作完毕，关掉页面。**

---

## 第四站：代码 + 打包 + 上传

### 4.1 更新 API Key（如果需要）

打开 `scripts/autoload/subscription_manager.gd`，替换：

```gdscript
const RC_API_KEY_ANDROID := "test_DLlkPwdXgQYkrExqXbYJtHkioUd"
```

改为 RevenueCat 给的正式 key：

```gdscript
const RC_API_KEY_ANDROID := "goog_你的正式key"
```

> 如果 RevenueCat 项目已经存在且 key 没变，跳过此步。

### 4.2 打包 AAB

1. Godot 编辑器 → Project → Export → Android
2. 确认：
   - Export format: **AAB**
   - Release mode（不是 Debug）
   - Keystore 路径和密码正确
3. 导出

### 4.3 上传到 Google Play Internal Testing

1. 回到 Google Play Console → Pot Trainer
2. **Test and release → Testing → Internal testing** → **Create new release**
3. 上传 AAB
4. Release name: `1.0.0-internal`
5. Release notes:
   ```
   Internal testing release with subscription integration.
   - RevenueCat subscription: $12.99/month unlimited access
   - AdMob rewarded ads for free tier
   ```
6. Save → Review → Start rollout

### 4.4 测试

1. 复制 Internal testing 的 **opt-in link**
2. 在测试设备上用测试 Gmail 打开链接 → 加入测试
3. 从 Google Play 安装
4. 测试订阅购买（沙盒环境，不会真实扣款）

---

## 常见问题

| 问题 | 解决 |
|---|---|
| RevenueCat Product 显示 "Not found" | Base plan ID 填错了，检查 Google Play Console 里的实际 ID |
| 购买时报 "Product not found in offerings" | Offering 没设为 Current，或 Package 没关联正确的产品 |
| Service Account 连接失败 | 确认 JSON 文件正确，且 Google Cloud 已启用 Pub/Sub API |
| 测试设备无法购买 | 确认 Gmail 在 License testing 列表中，且通过 opt-in link 加入了测试 |
| `GodotRevenueCat` singleton not found | GodotApp.kt 没注册 RevenueCatPlugin，检查 getHostPlugins() |
