#!/bin/bash
# AdMob 插件安装辅助脚本
# 使用方法：将下载的 godot-admob-android-vX.X.X.zip 放到项目根目录，然后运行此脚本

set -e

echo "=========================================="
echo "AdMob 插件安装辅助脚本"
echo "=========================================="
echo ""

# 检查是否在项目根目录
if [ ! -f "project.godot" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    exit 1
fi

echo "✅ 检测到项目根目录"
echo ""

# 查找 zip 文件
ZIP_FILE=$(find . -maxdepth 1 -name "godot-admob-android-*.zip" | head -1)

if [ -z "$ZIP_FILE" ]; then
    echo "❌ 错误：未找到 AdMob 插件 zip 文件"
    echo ""
    echo "请按以下步骤操作："
    echo "1. 访问 https://github.com/Poing-Studios/godot-admob-plugin/releases"
    echo "2. 下载最新的 godot-admob-android-vX.X.X.zip"
    echo "3. 将 zip 文件放到项目根目录（与 project.godot 同级）"
    echo "4. 重新运行此脚本"
    exit 1
fi

echo "✅ 找到插件文件：$ZIP_FILE"
echo ""

# 创建 addons 目录
if [ ! -d "addons" ]; then
    echo "📁 创建 addons 目录..."
    mkdir -p addons
fi

# 解压插件
echo "📦 解压插件文件..."
unzip -q "$ZIP_FILE" -d temp_admob

# 查找 admob 文件夹
ADMOB_DIR=$(find temp_admob -type d -name "admob" | head -1)

if [ -z "$ADMOB_DIR" ]; then
    echo "❌ 错误：zip 文件中未找到 admob 文件夹"
    rm -rf temp_admob
    exit 1
fi

# 复制到 addons 目录
echo "📋 复制插件到 addons/admob/..."
rm -rf addons/admob
cp -r "$ADMOB_DIR" addons/

# 清理临时文件
echo "🧹 清理临时文件..."
rm -rf temp_admob

# 验证安装
if [ -f "addons/admob/plugin.cfg" ]; then
    echo ""
    echo "=========================================="
    echo "✅ AdMob 插件安装成功！"
    echo "=========================================="
    echo ""
    echo "下一步操作："
    echo "1. 打开 Godot 编辑器"
    echo "2. 进入 项目 → 项目设置 → 插件"
    echo "3. 勾选启用 AdMob 插件"
    echo "4. 配置 Android 导出（见 ADMOB_INSTALL_GUIDE.md）"
    echo ""
    echo "详细步骤请查看：ADMOB_INSTALL_GUIDE.md"
else
    echo ""
    echo "❌ 安装失败：未找到 plugin.cfg 文件"
    echo "请手动安装或查看 ADMOB_INSTALL_GUIDE.md"
fi
