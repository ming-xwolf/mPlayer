#!/bin/bash

echo "🎵 mPlayer 应用部署脚本"
echo "========================"

# 配置变量
PROJECT_NAME="mPlayer"
SCHEME_NAME="mPlayer"
BUNDLE_ID="xwolf-ming.mPlayer"
SIMULATOR_NAME="iPhone 16"
BUILD_DIR="build"

# 清理之前的构建
echo "🧹 清理之前的构建..."
rm -rf "$BUILD_DIR"
xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME" > /dev/null 2>&1

# 检查并启动模拟器
echo "📱 检查模拟器状态..."
DEVICE_STATUS=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep "Booted")
if [ -z "$DEVICE_STATUS" ]; then
    echo "🚀 启动 $SIMULATOR_NAME 模拟器..."
    DEVICE_ID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')
    if [ -z "$DEVICE_ID" ]; then
        echo "❌ 找不到 $SIMULATOR_NAME 模拟器"
        echo "📋 可用的模拟器："
        xcrun simctl list devices | grep iPhone
        exit 1
    fi
    xcrun simctl boot "$DEVICE_ID"
    echo "⏳ 等待模拟器启动..."
    sleep 5
else
    echo "✅ $SIMULATOR_NAME 模拟器已在运行"
fi

# 构建应用
echo "🔨 构建应用..."
xcodebuild build \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO

if [ $? -ne 0 ]; then
    echo "❌ 构建失败"
    exit 1
fi

echo "✅ 构建成功"

# 查找应用包
echo "📦 查找应用包..."
APP_PATH=$(find "$BUILD_DIR" -name "*.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
    echo "❌ 找不到应用包"
    exit 1
fi

echo "✅ 找到应用包: $APP_PATH"

# 卸载旧版本应用（如果存在）
echo "🗑️  卸载旧版本应用..."
xcrun simctl uninstall "$SIMULATOR_NAME" "$BUNDLE_ID" > /dev/null 2>&1

# 安装应用
echo "📲 安装应用到模拟器..."
xcrun simctl install "$SIMULATOR_NAME" "$APP_PATH"
if [ $? -ne 0 ]; then
    echo "❌ 安装失败"
    exit 1
fi

echo "✅ 安装成功"

# 启动应用
echo "🚀 启动应用..."
xcrun simctl launch "$SIMULATOR_NAME" "$BUNDLE_ID"
if [ $? -ne 0 ]; then
    echo "❌ 启动失败"
    exit 1
fi

echo "✅ 应用启动成功"

# 等待应用加载
echo "⏳ 等待应用加载..."
sleep 3

# 验证应用运行状态
echo "🔍 验证应用运行状态..."
APP_STATUS=$(xcrun simctl listapps "$SIMULATOR_NAME" | grep "$BUNDLE_ID")
if [ -n "$APP_STATUS" ]; then
    echo "✅ 应用正在运行"
else
    echo "❌ 应用未运行"
    exit 1
fi

echo ""
echo "🎉 部署完成！应用功能："
echo "   🎵 音乐播放器"
echo "   📚 资料库管理"
echo "   🔍 搜索功能"
echo "   📱 现代化UI界面"
echo ""
echo "📝 使用建议："
echo "   1. 在资料库页面测试下拉刷新显示搜索框"
echo "   2. 点击搜索图标测试搜索框显示"
echo "   3. 测试音乐播放功能"
echo "   4. 检查TabBar底部间距"
echo "   5. 测试不同标签页之间的切换"
echo ""
echo "🎵 mPlayer 部署完成！" 