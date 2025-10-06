# 构建指南

本文档详细说明如何从源码构建 InkRoot 应用。

## 📋 目录

- [前置要求](#前置要求)
- [Android 构建](#android-构建)
- [iOS 构建](#ios-构建)
- [常见问题](#常见问题)

---

## 前置要求

### 通用环境

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| **Flutter SDK** | 3.24.5+ | **推荐 3.35.5** |
| **Dart SDK** | 3.0.0+ | **推荐 3.9.2** (随 Flutter 安装) |
| **Git** | 最新稳定版 | 用于版本控制 |

### Android 开发环境（⚠️ 配置详解）

由于 Android 环境配置复杂，请严格按照以下版本配置：

| 组件 | 精确版本 | 下载/配置方式 | 说明 |
|------|---------|--------------|------|
| **Android Studio** | 2025.1.1 (Ladybug) | [官网下载](https://developer.android.com/studio) | 最新稳定版 |
| **Android SDK Platform** | API 23, 34, 35 | SDK Manager 中安装 | **必需 API 23** |
| **Android SDK Build-Tools** | 35.0.0 | SDK Manager 中安装 | 最新版本 |
| **Android SDK Platform-Tools** | 35.0.0+ | 随 SDK 自动安装 | adb、fastboot |
| **Android SDK Command-line Tools** | latest | SDK Manager 中安装 | 命令行工具 |
| **Android Emulator** | 35.6.11+ | SDK Manager 中安装 | 可选 |
| **JDK** | **JDK 21** | Android Studio 自带 | 路径：`D:\Android\jbr` |
| **Gradle** | **8.12** | 自动下载 | 已在项目中配置 |
| **NDK** | **27.0.12077973** | SDK Manager 中安装 | 原生开发工具 |
| **Kotlin Plugin** | 1.9.0+ | Android Studio 自带 | Kotlin 支持 |

#### 详细配置步骤

##### 1. 安装 Android Studio

```bash
# 下载地址
https://developer.android.com/studio

# Windows: 下载 .exe 安装包
# macOS: 下载 .dmg 镜像
# Linux: 下载 .tar.gz 压缩包
```

安装完成后首次启动会出现 Setup Wizard，选择 **Standard** 安装类型。

##### 2. 配置 Android SDK（关键步骤）

打开 Android Studio：
- **Windows**: File > Settings > Appearance & Behavior > System Settings > Android SDK
- **macOS**: Android Studio > Preferences > Appearance & Behavior > System Settings > Android SDK

**SDK Platforms 标签页** - 勾选以下版本（最低要求）：

- ✅ **Android 6.0 (Marshmallow) - API 23** ← 必需！项目最低要求
- ✅ **Android 14.0 (UpsideDownCake) - API 34** ← 推荐
- ✅ **Android 15.0 - API 35** ← 最新版本

**SDK Tools 标签页** - 勾选以下工具（必需）：

- ✅ **Android SDK Build-Tools 35.0.0**
- ✅ **NDK (Side by side) 27.0.12077973** ← 注意版本号
- ✅ **Android SDK Command-line Tools (latest)**
- ✅ **Android Emulator**
- ✅ **Android SDK Platform-Tools**
- ✅ **Intel x86 Emulator Accelerator (HAXM)** - 仅 Intel CPU 需要

点击 **Apply** 开始下载安装（可能需要较长时间）。

##### 3. 配置环境变量（重要）

**Windows 系统：**

```powershell
# 右键"此电脑" > 属性 > 高级系统设置 > 环境变量

# 新建系统变量
变量名：ANDROID_HOME
变量值：D:\AndroidSdk  # 替换为你的实际 SDK 路径

# 编辑 Path 变量，添加以下路径：
%ANDROID_HOME%\platform-tools
%ANDROID_HOME%\tools
%ANDROID_HOME%\tools\bin
%ANDROID_HOME%\emulator
```

验证：
```powershell
# 打开新的命令行窗口
echo %ANDROID_HOME%
adb version
```

**macOS/Linux 系统：**

```bash
# 编辑 ~/.bashrc 或 ~/.zshrc (根据你使用的 shell)
nano ~/.zshrc  # 或 nano ~/.bashrc

# 添加以下内容
export ANDROID_HOME=$HOME/Library/Android/sdk  # macOS
# export ANDROID_HOME=$HOME/Android/Sdk  # Linux

export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/emulator

# 保存后执行
source ~/.zshrc  # 或 source ~/.bashrc
```

验证：
```bash
echo $ANDROID_HOME
adb version
```

##### 4. 配置 Flutter 的 Android 设置

```bash
# 设置 Android SDK 路径
flutter config --android-sdk D:\AndroidSdk  # Windows
flutter config --android-sdk $ANDROID_HOME  # macOS/Linux

# 设置 JDK 路径（使用 Android Studio 自带的 JDK 21）
flutter config --jdk-dir "D:\Android\jbr"  # Windows
flutter config --jdk-dir "/Applications/Android Studio.app/Contents/jbr/Contents/Home"  # macOS

# 接受所有 Android 许可协议（重要！）
flutter doctor --android-licenses
# 全部输入 y 接受
```

##### 5. 验证环境配置

```bash
flutter doctor -v
```

**成功的输出应该是：**

```
[✓] Flutter (Channel stable, 3.35.5, on Microsoft Windows, locale zh-CN)
    • Flutter version 3.35.5
    • Dart version 3.9.2

[✓] Android toolchain - develop for Android devices (Android SDK version 35.0.0)
    • Android SDK at D:\AndroidSdk
    • Platform android-35, build-tools 35.0.0
    • Java binary at: D:\Android\jbr\bin\java
    • Java version OpenJDK Runtime Environment (build 21.0.6)
    • All Android licenses accepted.

[✓] Android Studio (version 2025.1.1)
    • Android Studio at D:\Android
    • Flutter plugin can be installed
    • Dart plugin can be installed
    • Java version OpenJDK Runtime Environment (build 21.0.6)
```

### iOS 开发环境（仅 macOS）

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| **Xcode** | 14.0+ | 从 App Store 安装，推荐最新版 |
| **iOS SDK** | 13.0+ | 随 Xcode 安装 |
| **CocoaPods** | 1.11.0+ | iOS 依赖管理工具 |
| **Command Line Tools** | 最新版 | Xcode 命令行工具 |
| **Apple 开发者账号** | 可选 | 真机调试和发布需要 |

#### iOS 配置步骤

1. **安装 Xcode**
   - 从 App Store 搜索并安装 Xcode
   - 首次启动会自动安装必需组件

2. **安装 Command Line Tools**
   ```bash
   xcode-select --install
   ```

3. **安装 CocoaPods**
   ```bash
   sudo gem install cocoapods
   pod setup
   ```

4. **配置 Xcode 路径**
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```

5. **验证环境**
   ```bash
   flutter doctor -v
   
   # 应该看到：
   # [✓] Xcode - develop for iOS and macOS (Xcode 15.0)
   ```

---

## Android 构建

### 1. 环境检查

```bash
# 检查 Flutter 环境
flutter doctor

# 应该看到：
# [✓] Flutter (Channel stable, 3.35.5)
# [✓] Android toolchain
# [✓] Android Studio
```

### 2. 克隆仓库

```bash
git clone https://github.com/yyyyymmmmm/IntRoot.git
cd IntRoot
```

### 3. 安装依赖

```bash
flutter pub get
```

### 4. 构建 APK

#### 方式一：通用 APK（不推荐，文件较大）

```bash
flutter build apk --release
```

生成文件：`build/app/outputs/flutter-apk/app-release.apk` (~63 MB)

#### 方式二：分架构 APK（推荐）

```bash
flutter build apk --split-per-abi --release
```

生成文件：
- `app-arm64-v8a-release.apk` (~24 MB) - 适用于大多数现代设备
- `app-armeabi-v7a-release.apk` (~23 MB) - 适用于老旧设备
- `app-x86_64-release.apk` (~26 MB) - 适用于模拟器

#### 方式三：App Bundle（用于 Google Play）

```bash
flutter build appbundle --release
```

生成文件：`build/app/outputs/bundle/release/app-release.aab`

### 5. 签名配置

如需自定义签名，编辑 `android/key.properties`:

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=path/to/your/keystore.jks
```

生成密钥库：

```bash
keytool -genkey -v -keystore inkroot-release.keystore -alias inkroot -keyalg RSA -keysize 2048 -validity 10000
```

### 6. 安装 APK

```bash
# 通过 adb 安装
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# 或者直接传输到设备安装
```

---

## iOS 构建

### 1. 环境检查

```bash
# 检查 Flutter 环境
flutter doctor

# 应该看到：
# [✓] Flutter (Channel stable, 3.35.5)
# [✓] Xcode - develop for iOS
```

### 2. 安装 CocoaPods 依赖

```bash
cd ios
pod install
cd ..
```

### 3. 配置签名

1. 用 Xcode 打开 `ios/Runner.xcworkspace`
2. 选择 Runner 项目
3. 在 "Signing & Capabilities" 标签页：
   - 选择你的 Team
   - 修改 Bundle Identifier（如需要）

### 4. 构建 IPA

#### 方式一：构建但不签名（仅测试）

```bash
flutter build ios --release --no-codesign
```

#### 方式二：构建并签名

```bash
# 自动签名
flutter build ios --release

# 构建 IPA 文件
flutter build ipa --release
```

生成文件：`build/ios/ipa/InkRoot.ipa`

#### 方式三：使用 Xcode 构建

1. 打开 `ios/Runner.xcworkspace`
2. 选择 Product > Archive
3. 等待构建完成
4. 在 Organizer 中选择导出方式：
   - **App Store Connect** - 上传到 App Store
   - **Ad Hoc** - 企业分发
   - **Development** - 开发测试
   - **Save for Export** - 导出 IPA

### 5. 安装 IPA

#### 方式一：TestFlight

1. 上传到 App Store Connect
2. 等待审核通过
3. 通过 TestFlight 安装

#### 方式二：Xcode

1. 连接 iOS 设备
2. 在 Xcode 中选择设备
3. Product > Run

#### 方式三：工具安装

```bash
# 使用 ideviceinstaller
ideviceinstaller -i build/ios/ipa/InkRoot.ipa

# 或使用 Xcode
xcrun simctl install booted build/ios/ipa/InkRoot.ipa
```

---

## 常见问题

### Android 问题

#### 1. Gradle 构建失败

```bash
# 清理构建缓存
flutter clean
cd android
./gradlew clean
cd ..

# 重新构建
flutter pub get
flutter build apk --release
```

#### 2. SDK 版本问题

确保 `android/app/build.gradle` 中的 SDK 版本正确：

```gradle
android {
    compileSdk 34
    
    defaultConfig {
        minSdk 23
        targetSdk 34
    }
}
```

#### 3. 签名错误

检查 `android/key.properties` 文件是否存在且配置正确。

#### 4. 内存不足

在 `android/gradle.properties` 中增加内存：

```properties
org.gradle.jvmargs=-Xmx2048m
```

### iOS 问题

#### 1. CocoaPods 问题

```bash
# 更新 CocoaPods
sudo gem install cocoapods

# 清理缓存
cd ios
pod cache clean --all
pod deintegrate
pod install
cd ..
```

#### 2. 签名问题

- 确保你有有效的开发者账号
- 检查 Bundle Identifier 是否唯一
- 确保 Provisioning Profile 正确

#### 3. 架构问题

如果遇到 `arm64` 架构问题：

```ruby
# 在 ios/Podfile 中添加
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end
```

#### 4. 部署目标版本

确保 `ios/Podfile` 中的版本正确：

```ruby
platform :ios, '13.0'
```

### 通用问题

#### 1. Flutter 版本问题

```bash
# 更新 Flutter
flutter upgrade

# 切换到稳定版
flutter channel stable
flutter upgrade
```

#### 2. 依赖冲突

```bash
# 清理并重新获取依赖
flutter clean
flutter pub get
```

#### 3. 缓存问题

```bash
# 清理所有缓存
flutter clean
flutter pub cache repair
```

---

## 构建优化

### 减小 APK 体积

1. **使用分架构构建**
   ```bash
   flutter build apk --split-per-abi --release
   ```

2. **启用代码压缩**
   
   在 `android/app/build.gradle` 中：
   ```gradle
   buildTypes {
       release {
           minifyEnabled true
           shrinkResources true
           proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
       }
   }
   ```

3. **移除未使用的资源**
   ```bash
   flutter build apk --target-platform android-arm64 --release --tree-shake-icons
   ```

### 加快构建速度

1. **启用 Gradle 并行构建**
   
   在 `android/gradle.properties` 中：
   ```properties
   org.gradle.parallel=true
   org.gradle.caching=true
   ```

2. **使用 Flutter 构建缓存**
   ```bash
   flutter build apk --release --build-shared-library
   ```

---

## 发布检查清单

### Android

- [ ] 更新版本号（`pubspec.yaml`）
- [ ] 更新更新日志（`CHANGELOG.md`）
- [ ] 运行代码分析（`flutter analyze`）
- [ ] 运行所有测试（`flutter test`）
- [ ] 在多个设备上测试
- [ ] 检查权限配置
- [ ] 配置正确的签名
- [ ] 生成发布 APK/AAB
- [ ] 测试安装和运行
- [ ] 准备应用商店截图和描述

### iOS

- [ ] 更新版本号（`pubspec.yaml` 和 `Info.plist`）
- [ ] 更新更新日志（`CHANGELOG.md`）
- [ ] 运行代码分析（`flutter analyze`）
- [ ] 运行所有测试（`flutter test`）
- [ ] 在多个设备上测试
- [ ] 检查权限配置
- [ ] 配置正确的签名和证书
- [ ] 生成发布 IPA
- [ ] 通过 TestFlight 测试
- [ ] 准备 App Store 截图和描述
- [ ] 通过 App Store 审核

---

## 获取帮助

如果遇到构建问题：

1. 查看 [Flutter 官方文档](https://flutter.dev/docs)
2. 搜索 [GitHub Issues](https://github.com/yyyyymmmmm/IntRoot/issues)
3. 在 [Discussions](https://github.com/yyyyymmmmm/IntRoot/discussions) 中提问
4. 发送邮件到 [sdwxgzh@126.com](mailto:sdwxgzh@126.com)

---

**祝构建顺利！** 🚀

