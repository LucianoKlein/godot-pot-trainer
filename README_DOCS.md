# 项目文档索引

## 🎯 Google AdMob 广告集成（最新）

### 快速开始
- **[ADMOB_QUICKSTART.md](ADMOB_QUICKSTART.md)** ⭐ **推荐先看**
  - 3 分钟了解整体流程
  - 5 分钟完成插件安装
  - 快速验证和测试指南

### 详细文档
- **[ADMOB_INTEGRATION_REPORT.md](ADMOB_INTEGRATION_REPORT.md)** - 完整的集成报告
  - 代码集成状态（100% 完成）
  - 工作流程图
  - 下一步操作清单
  - 技术亮点和代码统计

- **[ADMOB_INSTALL_GUIDE.md](ADMOB_INSTALL_GUIDE.md)** - 详细的插件安装步骤
  - 下载和安装插件
  - 配置 Android 导出
  - AndroidManifest.xml 模板
  - 常见问题解答

- **[ADMOB_SETUP.md](ADMOB_SETUP.md)** - 完整的集成说明
  - 集成思路和架构
  - 代码改动点
  - 测试 vs 正式环境
  - 收益优化建议

- **[ADMOB_CHECKLIST.md](ADMOB_CHECKLIST.md)** - 检查清单
  - 代码集成检查
  - 插件安装检查
  - 测试检查
  - 上架准备检查

- **[ADMOB_SUMMARY.md](ADMOB_SUMMARY.md)** - 集成总结
  - 已完成的工作
  - 待完成的任务
  - 预期效果
  - 当前状态

### 核心代码文件
- `scripts/autoload/admob_manager.gd` - AdMob 管理单例（新建）
- `scripts/game/ui/ad_overlay_manager.gd` - 广告界面管理器（已修改）

---

## 🔐 Google 登录集成

- **[GOOGLE_LOGIN_COMPLETE.md](GOOGLE_LOGIN_COMPLETE.md)** - 完整的登录集成报告
- **[GOOGLE_LOGIN_CHECKLIST.md](GOOGLE_LOGIN_CHECKLIST.md)** - 登录功能检查清单
- **[MOBILE_GOOGLE_LOGIN.md](MOBILE_GOOGLE_LOGIN.md)** - 移动端 Google 登录指南
- **[README_GOOGLE_LOGIN.md](README_GOOGLE_LOGIN.md)** - Google 登录快速说明

---

## ⚙️ 项目配置

- **[TODO_CONFIG.md](TODO_CONFIG.md)** - 配置待办事项
- **[CLAUDE.md](CLAUDE.md)** - 项目结构和开发指南（9.7 KB）
  - 项目架构
  - 文件结构
  - 修改指南
  - 信号流程

---

## 📊 文档统计

- **总文档数**：12 个
- **AdMob 相关**：6 个（22 KB）
- **Google 登录相关**：4 个（22 KB）
- **项目配置**：2 个（16 KB）

---

## 🚀 快速导航

### 我想...

#### 接入 Google AdMob 广告
1. 阅读 [ADMOB_QUICKSTART.md](ADMOB_QUICKSTART.md)（3 分钟）
2. 按照 [ADMOB_INSTALL_GUIDE.md](ADMOB_INSTALL_GUIDE.md) 安装插件（5 分钟）
3. 导出 APK 进行真机测试（10 分钟）

#### 了解 AdMob 集成状态
- 查看 [ADMOB_INTEGRATION_REPORT.md](ADMOB_INTEGRATION_REPORT.md)

#### 检查 AdMob 是否遗漏步骤
- 使用 [ADMOB_CHECKLIST.md](ADMOB_CHECKLIST.md)

#### 配置 Google 登录
- 查看 [GOOGLE_LOGIN_COMPLETE.md](GOOGLE_LOGIN_COMPLETE.md)

#### 了解项目结构
- 阅读 [CLAUDE.md](CLAUDE.md)

---

## ⚠️ 重要提醒

### AdMob 集成
- ✅ 代码已 100% 完成，只需安装插件
- ⚠️ 测试 ID 不能用于正式发布
- ⚠️ AdMob 只能在真机上测试
- ⚠️ 上架前必须替换为正式广告 ID

### Google 登录
- ✅ 已集成 Firebase Auth
- ✅ 支持邮箱密码登录
- ✅ 支持 Google 登录（移动端）
- ✅ 支持游客模式

---

## 📞 需要帮助？

- **AdMob 问题**：查看 [ADMOB_INSTALL_GUIDE.md](ADMOB_INSTALL_GUIDE.md) 的常见问题部分
- **登录问题**：查看 [GOOGLE_LOGIN_CHECKLIST.md](GOOGLE_LOGIN_CHECKLIST.md)
- **项目结构**：查看 [CLAUDE.md](CLAUDE.md)

---

**最后更新**：2026-03-23
