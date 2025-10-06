<div align="center">
  <img src="assets/images/logo.png" alt="InkRoot Logo" width="120" height="120">
  
# InkRoot - 墨鸣笔记

  **一款基于 Memos 系统打造的第三方极简笔记应用**
  
  专为追求高效记录与深度积累的用户设计。它帮助你默默书写、静心沉淀，让每一次落笔都成为未来思想生根发芽的力量。
  
  完美对接 Memos 服务器，保障数据安全与私密，适合个人及团队的知识管理需求。
  
  无论是快速捕捉灵感，还是系统性整理思考，墨鸣都助你沉淀积累，厚积薄发。

  [![GitHub release](https://img.shields.io/badge/version-1.0.3-blue.svg)](https://github.com/yyyyymmmmm/IntRoot/releases)
  [![Flutter](https://img.shields.io/badge/Flutter-3.35.5-02569B?logo=flutter)](https://flutter.dev)
  [![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/yyyyymmmmm/IntRoot/blob/master/LICENSE)
  [![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey.svg)](https://github.com/yyyyymmmmm/IntRoot)

  [官方网站](https://inkroot.cn) · [在线演示](https://inkroot.cn) · [问题反馈](https://github.com/yyyyymmmmm/IntRoot/issues) · [功能建议](https://github.com/yyyyymmmmm/IntRoot/discussions) · [常见问题](FAQ.md)

</div>

---

## 📖 目录

- [✨ 特性](#-特性)
- [📱 系统要求](#-系统要求)
- [🚀 快速开始](#-快速开始)
- [📦 安装部署](#-安装部署)
- [🏗️ 项目架构](#️-项目架构)
- [⚙️ 配置说明](#️-配置说明)
- [🛠️ 开发指南](#️-开发指南)
- [📝 API 文档](#-api-文档)
- [🤝 贡献指南](#-贡献指南)
- [📜 更新日志](#-更新日志)
- [❓ 常见问题](#-常见问题)
- [📄 许可证](#-许可证)
- [📧 联系方式](#-联系方式)

---

## ✨ 特性

### 🎯 核心功能

- **📝 Markdown 支持** - 完整的 Markdown 语法支持，包括代码高亮、表格、任务列表等
- **☁️ 云端同步** - 完美对接 Memos 服务器，支持实时同步与离线编辑
- **🎤 语音识别** - 内置语音转文字功能，快速记录灵感
- **🖼️ 图片管理** - 支持图片上传、预览、裁剪与压缩
- **🏷️ 标签系统** - 灵活的标签分类，快速组织和检索笔记
- **🔍 全文搜索** - 强大的搜索功能，支持标题、内容、标签多维度搜索
- **⏰ 智能提醒** - 定时提醒通知，不错过重要事项
- **🌓 深色模式** - 护眼舒适的日夜双主题自动切换

### 💡 特色亮点

#### 使用灵活性
- **🆓 本地模式** - 无需服务器，开箱即用，完全免费
- **☁️ 云端同步** - 可选连接 Memos 服务器实现多设备同步
- **🔒 数据私有** - 本地模式数据不上传；云端模式数据存储在你自己的服务器

#### 特色功能
- **🎤 语音识别** - 实时语音转文字，快速记录灵感
- **📌 笔记引用** - `[[笔记标题]]` 创建双向链接，构建知识网络
- **🔗 反向链接** - 自动显示哪些笔记引用了当前笔记
- **🎲 随机回顾** - 智能推荐历史笔记，巩固记忆
- **⏰ 智能提醒** - 定时通知，不错过重要事项
- **🔍 全文搜索** - 快速查找任何笔记内容

#### 技术优势
- **📤 导入导出** - 支持 JSON/Markdown 格式，数据完全可控
- **🔄 增量同步** - 智能同步机制，节省流量（云端模式）
- **📱 跨平台** - 同时支持 iOS 和 Android 双平台
- **🎨 精美界面** - 采用 Material Design 3 设计语言
- **⚡ 高性能** - 本地 SQLite 数据库，响应迅速
- **🔐 安全存储** - 敏感信息使用安全存储加密
- **📝 Markdown** - 完整支持 Markdown 语法，包括代码高亮、表格、任务列表

### 🆕 实验室功能

- **🤖 企业微信集成** - 支持企业微信通知推送
- **📊 数据统计** - 笔记数量、字数统计与分析
- **🎲 随机回顾** - 随机抽取历史笔记进行回顾
- **📌 本地引用** - 笔记间双向链接功能

---

## 📱 系统要求

### 用户端要求

#### iOS

- **最低版本**: iOS 13.0+
- **推荐版本**: iOS 15.0+
- **架构支持**: arm64
- **安装方式**: App Store / TestFlight / IPA 旁加载

#### Android

- **最低版本**: Android 6.0 (API 23)+
- **推荐版本**: Android 11.0 (API 30)+
- **架构支持**: arm64-v8a, armeabi-v7a, x86_64
- **安装方式**: APK 直接安装 / 各大应用商店

### 开发环境要求

#### 通用环境

| 组件 | 版本要求 | 备注 |
|------|---------|------|
| **Flutter SDK** | 3.24.5+ | **推荐 3.35.5** |
| **Dart SDK** | 3.0.0+ | **推荐 3.9.2** (随 Flutter 安装) |
| **Git** | 最新稳定版 | 用于版本控制 |

#### Android 开发环境（⚠️ 重要）

由于 Android 环境配置较为复杂，请严格按照以下版本配置：

| 组件 | 版本要求 | 下载地址 | 说明 |
|------|---------|---------|------|
| **Android Studio** | 2023.1.1+ | [官网下载](https://developer.android.com/studio) | **推荐 2025.1.1 (Ladybug)** |
| **Android SDK Platform** | API 23 - API 36 | Android Studio SDK Manager | **必需 API 23, 推荐 API 34/35** |
| **Android SDK Build-Tools** | 35.0.0 | Android Studio SDK Manager | **最新版本** |
| **Android SDK Platform-Tools** | 35.0.0+ | 随 SDK 安装 | adb、fastboot 等工具 |
| **Android SDK Command-line Tools** | 最新版 | Android Studio SDK Manager | 命令行工具 |
| **Android Emulator** | 35.6.11+ | Android Studio SDK Manager | 可选，用于模拟器调试 |
| **JDK** | JDK 11 或 JDK 21 | Android Studio 自带 | **推荐使用 Android Studio 自带的 JDK 21** |
| **Gradle** | 8.12 | 自动下载 | 已在项目中配置 |
| **NDK** | 27.0.12077973 | Android Studio SDK Manager | 原生开发工具包 |
| **Kotlin** | 1.9.0+ | 随 Android Studio 安装 | Kotlin 编译器 |

#### Android 环境配置步骤（完整版）

1. **安装 Android Studio**
   ```bash
   # 下载地址
   https://developer.android.com/studio
   
   # 安装后启动 Android Studio
   # 首次启动会自动下载 Android SDK
   ```

2. **配置 Android SDK**
   
   打开 Android Studio > Settings (或 Preferences) > Appearance & Behavior > System Settings > Android SDK
   
   **SDK Platforms 标签页** - 勾选以下版本：
   - ✅ Android 14.0 (UpsideDownCake) - API 34
   - ✅ Android 13.0 (Tiramisu) - API 33  
   - ✅ Android 12.0 (S) - API 31
   - ✅ Android 11.0 (R) - API 30
   - ✅ Android 10.0 (Q) - API 29
   - ✅ Android 6.0 (Marshmallow) - API 23 **(必需，项目最低要求)**
   
   **SDK Tools 标签页** - 勾选以下工具：
   - ✅ Android SDK Build-Tools 35.0.0
   - ✅ NDK (Side by side) 27.0.12077973
   - ✅ Android SDK Command-line Tools (latest)
   - ✅ Android Emulator
   - ✅ Android SDK Platform-Tools
   - ✅ Intel x86 Emulator Accelerator (HAXM installer) - 如果使用 Intel CPU
   
   点击 **Apply** 开始下载安装

3. **配置环境变量**
   
   **Windows:**
   ```powershell
   # 系统环境变量中添加
   ANDROID_HOME = D:\AndroidSdk  # 你的 SDK 路径
   
   # Path 中添加
   %ANDROID_HOME%\platform-tools
   %ANDROID_HOME%\tools
   %ANDROID_HOME%\tools\bin
   ```
   
   **macOS/Linux:**
   ```bash
   # 在 ~/.bashrc 或 ~/.zshrc 中添加
   export ANDROID_HOME=$HOME/Android/Sdk
   export PATH=$PATH:$ANDROID_HOME/platform-tools
   export PATH=$PATH:$ANDROID_HOME/tools
   export PATH=$PATH:$ANDROID_HOME/tools/bin
   ```

4. **配置 Flutter 环境**
   ```bash
   # 设置 Android SDK 路径
   flutter config --android-sdk $ANDROID_HOME
   
   # 设置 JDK 路径（使用 Android Studio 自带的 JDK）
   flutter config --jdk-dir "D:\Android\jbr"  # Windows
   flutter config --jdk-dir "/Applications/Android Studio.app/Contents/jbr/Contents/Home"  # macOS
   
   # 接受 Android 许可协议
   flutter doctor --android-licenses
   # 全部输入 y 接受
   ```

5. **验证环境配置**
   ```bash
   flutter doctor -v
   
   # 应该看到：
   # [✓] Flutter (Channel stable, 3.35.5)
   # [✓] Android toolchain - develop for Android devices (Android SDK version 35.0.0)
   # [✓] Android Studio (version 2025.1.1)
   ```

#### iOS 开发环境（仅 macOS）

| 组件 | 版本要求 | 下载地址 | 说明 |
|------|---------|---------|------|
| **Xcode** | 14.0+ | App Store | **推荐最新版** |
| **iOS SDK** | 13.0+ | 随 Xcode 安装 | |
| **CocoaPods** | 1.11.0+ | `sudo gem install cocoapods` | iOS 依赖管理 |
| **Command Line Tools** | 最新版 | `xcode-select --install` | Xcode 命令行工具 |

#### iOS 环境配置步骤

1. **安装 Xcode**
   - 从 App Store 下载安装 Xcode
   - 首次启动会自动安装组件

2. **安装命令行工具**
   ```bash
   xcode-select --install
   ```

3. **安装 CocoaPods**
   ```bash
   sudo gem install cocoapods
   pod setup
   ```

4. **配置 Xcode**
   ```bash
   # 设置 Xcode 路径
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   
   # 同意许可协议
   sudo xcodebuild -license accept
   ```

5. **验证环境**
   ```bash
   flutter doctor -v
   
   # 应该看到：
   # [✓] Xcode - develop for iOS and macOS
   ```

### 🔧 环境问题排查

如果 `flutter doctor` 检查出现问题：

#### Android 相关问题

1. **找不到 Android SDK**
   ```bash
   flutter config --android-sdk <你的SDK路径>
   ```

2. **JDK 版本不对**
   ```bash
   # 使用 Android Studio 自带的 JDK
   flutter config --jdk-dir "D:\Android\jbr"
   ```

3. **许可协议未接受**
   ```bash
   flutter doctor --android-licenses
   # 全部输入 y
   ```

4. **Gradle 下载慢**
   ```bash
   # 已配置腾讯云镜像
   # 如果还是慢，可以手动下载 gradle-8.12-all.zip
   # 放到 C:\Users\你的用户名\.gradle\wrapper\dists\
   ```

#### iOS 相关问题（macOS）

1. **CocoaPods 安装失败**
   ```bash
   # 使用 Homebrew 安装
   brew install cocoapods
   ```

2. **找不到 Xcode**
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

---

## 🚀 快速开始

### 1. 选择使用模式

InkRoot 支持两种使用模式，根据需求选择：

#### 💡 模式一：本地模式（推荐新手）

**无需服务器，开箱即用！**

- ✅ 安装后直接使用，无需配置
- ✅ 所有数据存储在本地
- ✅ 完全离线可用
- ✅ 隐私保护，数据不上传
- ✅ 支持全部核心功能

**适合场景：**
- 个人笔记管理
- 不需要多设备同步
- 重视数据隐私

**使用方法：**
1. 安装应用
2. 跳过服务器配置
3. 直接开始记笔记！

---

#### ☁️ 模式二：云端同步模式（可选）

**需要 Memos 服务器，支持多设备同步！**

**⚠️ 重要：需要 Memos v0.21.0 或更高版本**

**选项A: 使用 Docker 部署 Memos（推荐）**

```bash
# 方式一：指定版本（推荐）
docker run -d \
  --name memos \
  --publish 5230:5230 \
  --volume ~/.memos/:/var/opt/memos \
  neosmemo/memos:0.21.0

# 方式二：使用最新稳定版（确保 >= 0.21.0）
docker run -d \
  --name memos \
  --publish 5230:5230 \
  --volume ~/.memos/:/var/opt/memos \
  neosmemo/memos:stable
```

**版本要求说明：**
- ✅ **支持版本**：Memos v0.21.0+
- ❌ **不支持**：Memos v0.20.x 及以下（API 不兼容）
- 📌 **推荐版本**：v0.21.0 或更高

**选项B: 下载 Memos 二进制文件**

前往 [Memos Releases](https://github.com/usememos/memos/releases) 下载 v0.21.0 或更高版本。

**选项C: 使用官方演示服务器（仅测试用）**

```
服务器地址: https://memos.didichou.site
版本: v0.21.0+
注意：演示服务器数据可能会被定期清理，不建议长期使用
```

### 2. 配置应用（如果选择云端同步模式）

如果选择云端同步模式，需要配置服务器：

1. 打开 InkRoot 应用
2. 进入「设置」→「服务器信息」
3. 输入你的 Memos 服务器地址
   - 格式：`http://your-server:5230` 或 `https://your-domain.com`
   - 确保服务器版本 >= v0.21.0
4. 注册新账号或登录现有账号

**如果选择本地模式，跳过此步骤！**

### 3. 开始使用

#### 📝 基础功能
- 点击「+」按钮创建新笔记
- 使用 Markdown 语法编写内容
- 添加标签方便分类：`#标签名`
- 支持上传和管理图片

#### 🌟 特色功能（亮点）

**1. 语音识别** 🎤
- 点击麦克风图标开始语音输入
- 实时转换语音为文字
- 支持中文、英文识别
- 连续识别模式

**2. 本地引用（笔记链接）** 📌
- 使用 `[[笔记标题]]` 创建引用
- 自动生成双向链接
- 点击引用快速跳转
- 查看反向链接（哪些笔记引用了当前笔记）

**3. 智能提醒** ⏰
- 为笔记设置定时提醒
- 支持一次性和重复提醒
- 通知点击直达笔记内容

**4. 随机回顾** 🎲
- 随机抽取历史笔记复习
- 支持按标签筛选
- 帮助巩固记忆

**5. 数据导入导出** 📤
- 导出为 JSON 或 Markdown
- 支持批量导出
- 数据完全可控

**6. 全文搜索** 🔍
- 快速搜索笔记内容
- 支持标题、内容、标签搜索
- 实时搜索建议

---

## 📦 安装部署

### 方式一：从源码构建

#### 前置要求

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.24.5+
- [Git](https://git-scm.com/)
- iOS 开发需要 Xcode 14.0+
- Android 开发需要 Android Studio 或 Android SDK

#### 克隆仓库

```bash
git clone https://github.com/yyyyymmmmm/IntRoot.git
cd IntRoot
```

#### 安装依赖

```bash
flutter pub get
```

#### 构建 Android APK

```bash
# 构建通用 APK（包含所有架构，体积较大）
flutter build apk --release

# 构建分架构 APK（推荐，每个文件约 24MB）
flutter build apk --split-per-abi --release

# 构建 App Bundle（用于上传 Google Play）
flutter build appbundle --release
```

构建完成后，APK 文件位于：`build/app/outputs/flutter-apk/`

#### 构建 iOS IPA

```bash
# 安装 CocoaPods 依赖
cd ios && pod install && cd ..

# 构建 iOS（需要 Apple 开发者账号）
flutter build ios --release

# 构建 IPA（需要配置签名）
flutter build ipa --release
```

构建完成后，IPA 文件位于：`build/ios/ipa/`

### 方式二：下载预编译版本

访问 [Releases 页面](https://github.com/yyyyymmmmm/IntRoot/releases) 下载最新版本。

---

## 🏗️ 项目架构

### 技术栈

| 技术 | 说明 | 版本 |
|------|------|------|
| **Flutter** | 跨平台 UI 框架 | 3.35.5 |
| **Dart** | 编程语言 | 3.9.2 |
| **Provider** | 状态管理 | ^6.1.2 |
| **GoRouter** | 路由管理 | ^10.2.0 |
| **SQLite** | 本地数据库 | sqflite ^2.3.3 |
| **flutter_local_notifications** | 本地通知 | ^17.2.3 |
| **speech_to_text** | 语音识别 | ^7.3.0 |
| **image_picker** | 图片选择 | ^1.1.2 |
| **flutter_markdown** | Markdown 渲染 | ^0.6.23 |
| **http** | 网络请求 | ^1.2.2 |

### 项目结构

```
IntRoot-master/
├── android/                    # Android 原生代码
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── kotlin/        # Kotlin 代码
│   │   │   ├── res/           # Android 资源
│   │   │   └── AndroidManifest.xml
│   │   ├── build.gradle       # 应用级 Gradle 配置
│   │   └── key.properties     # 签名配置
│   └── build.gradle           # 项目级 Gradle 配置
│
├── ios/                        # iOS 原生代码
│   ├── Runner/
│   │   ├── AppDelegate.swift  # 应用代理
│   │   ├── Info.plist         # iOS 配置
│   │   └── Assets.xcassets/   # iOS 资源
│   ├── Podfile                # CocoaPods 配置
│   └── Runner.xcodeproj/      # Xcode 项目
│
├── lib/                        # Flutter 源代码
│   ├── config/                 # 配置文件
│   │   ├── app_config.dart    # 应用配置（服务器地址、版本信息等）
│   │   └── asset_config.dart  # 资源配置
│   │
│   ├── models/                 # 数据模型
│   │   ├── note_model.dart    # 笔记模型
│   │   ├── user_model.dart    # 用户模型
│   │   ├── announcement_model.dart  # 公告模型
│   │   └── cloud_verification_models.dart
│   │
│   ├── providers/              # 状态管理
│   │   └── app_provider.dart  # 全局应用状态
│   │
│   ├── routes/                 # 路由配置
│   │   └── app_router.dart    # GoRouter 路由配置
│   │
│   ├── screens/                # 页面 UI
│   │   ├── splash_screen.dart          # 启动页
│   │   ├── login_screen.dart           # 登录页
│   │   ├── register_screen.dart        # 注册页
│   │   ├── home_screen.dart            # 主页
│   │   ├── note_detail_screen.dart     # 笔记详情
│   │   ├── settings_screen.dart        # 设置页
│   │   ├── tags_screen.dart            # 标签管理
│   │   ├── notifications_screen.dart   # 通知管理
│   │   ├── import_export_screen.dart   # 导入导出
│   │   ├── laboratory_screen.dart      # 实验室功能
│   │   ├── random_review_screen.dart   # 随机回顾
│   │   └── ...
│   │
│   ├── services/               # 业务逻辑层
│   │   ├── api_service.dart              # API 服务基类
│   │   ├── memos_api_service_fixed.dart  # Memos API 实现
│   │   ├── database_service.dart         # 本地数据库服务
│   │   ├── preferences_service.dart      # 本地偏好设置
│   │   ├── notification_service.dart     # 通知服务
│   │   ├── speech_service.dart           # 语音识别服务
│   │   ├── incremental_sync_service.dart # 增量同步服务
│   │   ├── memos_resource_service.dart   # 资源管理服务
│   │   ├── permission_manager.dart       # 权限管理
│   │   └── ...
│   │
│   ├── themes/                 # 主题样式
│   │   ├── app_theme.dart     # 应用主题定义
│   │   └── app_typography.dart # 字体排版
│   │
│   ├── utils/                  # 工具类
│   │   ├── date_utils.dart           # 日期工具
│   │   ├── image_cache_manager.dart  # 图片缓存管理
│   │   ├── markdown_utils.dart       # Markdown 工具
│   │   └── ...
│   │
│   ├── widgets/                # 自定义组件
│   │   ├── note_card.dart            # 笔记卡片组件
│   │   ├── tag_chip.dart             # 标签芯片组件
│   │   ├── markdown_editor.dart      # Markdown 编辑器
│   │   └── ...
│   │
│   └── main.dart               # 应用入口
│
├── assets/                     # 资源文件
│   ├── images/                 # 图片资源
│   │   └── logo.png           # 应用图标
│   └── fonts/                  # 字体文件
│       ├── SF-Pro-Display-*.ttf
│       └── SF-Mono-Regular.ttf
│
├── pubspec.yaml               # Flutter 项目配置
├── analysis_options.yaml      # 代码分析配置
├── README.md                  # 项目说明文档
└── LICENSE                    # 开源协议
```

### 架构设计

InkRoot 采用分层架构设计，确保代码的可维护性和可扩展性：

```
┌─────────────────────────────────────┐
│         Presentation Layer          │  UI 层（Screens + Widgets）
│  (Flutter Widgets & Screens)        │
└─────────────────────────────────────┘
              ↓↑
┌─────────────────────────────────────┐
│        State Management Layer       │  状态管理层（Provider）
│           (Provider)                 │
└─────────────────────────────────────┘
              ↓↑
┌─────────────────────────────────────┐
│         Business Logic Layer        │  业务逻辑层（Services）
│           (Services)                 │
└─────────────────────────────────────┘
              ↓↑
┌──────────────────┬──────────────────┐
│   Data Layer     │   Data Layer     │  数据层
│  (Local SQLite)  │ (Remote Memos)   │
└──────────────────┴──────────────────┘
```

#### 数据流

1. **用户操作** → UI 组件
2. **UI 组件** → 触发 Provider 状态更新
3. **Provider** → 调用 Service 层业务逻辑
4. **Service** → 与本地数据库或远程 API 交互
5. **数据返回** → 更新 Provider 状态 → UI 自动刷新

---

## ⚙️ 配置说明

### Memos 服务器配置

#### 支持的版本

- Memos v0.21.0+
- API 版本: v1

#### 服务器地址格式

```
# HTTP (本地测试)
http://localhost:5230
http://192.168.1.100:5230

# HTTPS (生产环境推荐)
https://your-domain.com
https://memos.example.com
```

### 应用配置文件

主要配置位于 `lib/config/app_config.dart`:

```dart
class AppConfig {
  // 应用基本信息
  static const String appName = 'InkRoot';
  static const String appVersion = '1.0.3';
  static const String packageName = 'com.didichou.inkroot';
  
  // 官方服务器配置
  static const String officialMemosServer = 'https://memos.didichou.site';
  
  // 反馈与支持
  static const String supportEmail = 'sdwxgzh@126.com';
  static const String officialWebsite = 'https://inkroot.cn/';
  static const String githubRepo = 'https://github.com/yyyyymmmmm/IntRoot';
}
```

### 权限配置

#### iOS 权限 (Info.plist)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限以使用语音识别功能</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>需要相册权限以选择和保存图片</string>

<key>NSCameraUsageDescription</key>
<string>需要相机权限以拍摄照片</string>
```

#### Android 权限 (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

---

## 🛠️ 开发指南

### 环境搭建

#### 1. 安装 Flutter

参考 [Flutter 官方文档](https://flutter.dev/docs/get-started/install)

```bash
# 检查 Flutter 环境
flutter doctor

# 输出示例：
# [✓] Flutter (Channel stable, 3.35.5)
# [✓] Android toolchain
# [✓] Xcode (iOS 开发)
# [✓] Android Studio
```

#### 2. 克隆项目

```bash
git clone https://github.com/yyyyymmmmm/IntRoot.git
cd IntRoot
```

#### 3. 安装依赖

```bash
flutter pub get
```

#### 4. 配置开发环境

```bash
# 查看可用设备
flutter devices

# 运行应用（开发模式）
flutter run

# 运行在指定设备
flutter run -d <device-id>
```

### 开发规范

#### 代码风格

- 遵循 [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- 使用 `flutter format` 格式化代码
- 提交前运行 `flutter analyze` 检查代码

#### 命名规范

- 文件名：使用小写 + 下划线（如：`note_detail_screen.dart`）
- 类名：使用大驼峰（如：`NoteDetailScreen`）
- 变量名：使用小驼峰（如：`noteTitle`）
- 常量名：使用小写 + 下划线（如：`api_base_url`）

#### Git 提交规范

```
feat: 新功能
fix: 修复问题
docs: 文档更新
style: 代码格式调整
refactor: 代码重构
test: 测试相关
chore: 构建/工具相关

示例：
feat: 添加语音识别功能
fix: 修复笔记同步失败的问题
docs: 更新 README 安装说明
```

### 调试技巧

#### 启用调试日志

在 `lib/config/app_config.dart` 中设置：

```dart
static const bool debugMode = true;
static const bool verboseLogging = true;
static const bool enableNetworkLogging = true;
```

#### 查看网络请求

```bash
# 使用 Charles 或 Fiddler 抓包
flutter run --dart-define=ENABLE_NETWORK_LOGGING=true
```

#### 性能分析

```bash
# 启动性能分析
flutter run --profile

# 打开 DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

---

## 📝 API 文档

InkRoot 使用 Memos v1 API。以下是主要接口说明：

### 认证接口

#### 用户登录

```http
POST /api/v1/auth/signin
Content-Type: application/json

{
  "username": "your_username",
  "password": "your_password"
}

Response:
{
  "user": {
    "id": 1,
    "username": "your_username",
    "email": "user@example.com",
    ...
  },
  "accessToken": "jwt_token_here"
}
```

#### 用户注册

```http
POST /api/v1/auth/signup
Content-Type: application/json

{
  "username": "your_username",
  "password": "your_password",
  "email": "user@example.com"
}
```

### 笔记接口

#### 获取笔记列表

```http
GET /api/v1/memo?limit=20&offset=0
Authorization: Bearer {access_token}

Response:
[
  {
    "id": 1,
    "content": "笔记内容",
    "visibility": "PRIVATE",
    "createdTs": 1234567890,
    "updatedTs": 1234567890,
    ...
  }
]
```

#### 创建笔记

```http
POST /api/v1/memo
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "content": "笔记内容",
  "visibility": "PRIVATE"
}
```

#### 更新笔记

```http
PATCH /api/v1/memo/{id}
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "content": "更新后的内容"
}
```

#### 删除笔记

```http
DELETE /api/v1/memo/{id}
Authorization: Bearer {access_token}
```

### 资源接口

#### 上传图片

```http
POST /api/v1/resource/blob
Authorization: Bearer {access_token}
Content-Type: multipart/form-data

file: <binary_data>
```

#### 获取资源列表

```http
GET /api/v1/resource?limit=20&offset=0
Authorization: Bearer {access_token}
```

更多 API 详情请参考 [Memos API 文档](https://github.com/usememos/memos#api)

---

## 🤝 贡献指南

我们欢迎所有形式的贡献！无论是新功能、Bug 修复、文档改进还是问题反馈。

### 如何贡献

1. **Fork 本仓库**
2. **创建特性分支** (`git checkout -b feature/AmazingFeature`)
3. **提交改动** (`git commit -m 'feat: 添加某个很棒的功能'`)
4. **推送到分支** (`git push origin feature/AmazingFeature`)
5. **开启 Pull Request**

### 贡献类型

#### 🐛 Bug 报告

如果发现 Bug，请通过 [GitHub Issues](https://github.com/yyyyymmmmm/IntRoot/issues) 报告，并包含：

- 问题描述
- 复现步骤
- 预期行为 vs 实际行为
- 设备信息（系统版本、应用版本）
- 相关截图或日志

#### 💡 功能建议

欢迎通过 [GitHub Discussions](https://github.com/yyyyymmmmm/IntRoot/discussions) 提出功能建议。

#### 📖 文档改进

文档改进包括但不限于：

- 修正错别字
- 补充说明
- 添加示例
- 翻译文档

#### 💻 代码贡献

提交代码前请确保：

- [ ] 代码已通过 `flutter analyze`
- [ ] 代码已使用 `flutter format` 格式化
- [ ] 已添加必要的注释
- [ ] 已更新相关文档
- [ ] 已测试功能正常工作

### 开发流程

1. **领取或创建 Issue**
2. **本地开发并自测**
3. **提交 Pull Request**
4. **代码审查**
5. **合并到主分支**

---

## 📜 更新日志

### v1.0.3 (2025-10-06)

#### 🎉 新增
- ✨ 更新到 Flutter 3.35.5
- ✨ 优化 APK 构建配置，支持分架构构建
- ✨ 更新主题系统，适配最新 Material Design 3

#### 🔧 优化
- 🔧 修复头像加载问题
- 🔧 优化图片缓存机制
- 🔧 改进网络请求错误处理

#### 🐛 修复
- 🐛 修复部分 Android 设备通知不显示的问题
- 🐛 修复语音识别在某些设备上崩溃的问题
- 🐛 修复深色模式下部分文字看不清的问题

### v1.0.2 (2025-09-30)

#### 🆕 新增
- 🏢 实验室新增企业微信对接功能
- 📊 新增笔记统计功能
- 🎲 新增随机回顾功能

#### 🔧 优化
- 🔧 修复头像加载问题
- 🔧 优化笔记列表加载性能
- 🔧 改进同步机制，减少流量消耗

#### 🐛 修复
- 🐛 修复已知 Bug
- 🐛 修复部分 iOS 设备闪退问题

### v1.0.1 (2025-09-20)

#### 🎉 首次发布
- ✨ 完整的笔记管理功能
- 📱 Android 和 iOS 双平台支持
- 🔄 Memos 服务器同步
- 🎤 语音识别功能
- 🏷️ 标签系统
- ⏰ 定时提醒
- 🌓 深色模式

查看完整更新日志：[CHANGELOG.md](CHANGELOG.md)

---

## ❓ 常见问题

### 快速查询

- **[安装相关](FAQ.md#安装相关)** - 应用下载、安装问题
- **[登录注册](FAQ.md#登录与注册)** - 账号、密码、服务器配置
- **[同步问题](FAQ.md#同步问题)** - 数据同步、速度优化
- **[功能使用](FAQ.md#功能使用)** - Markdown、标签、搜索、导出
- **[通知提醒](FAQ.md#通知提醒)** - 通知权限、定时提醒
- **[图片上传](FAQ.md#图片上传)** - 图片上传、压缩、加载
- **[性能问题](FAQ.md#性能问题)** - 启动慢、卡顿、耗电
- **[Android 问题](FAQ.md#android-特定问题)** - 小米、华为、OPPO 特殊设置
- **[iOS 问题](FAQ.md#ios-特定问题)** - TestFlight、权限、闪退
- **[开发相关](FAQ.md#开发相关)** - 构建、贡献代码

### 热门问题

#### Q: 为什么收不到通知？

**A:** 需要检查以下几点：
1. 应用通知权限是否开启
2. 系统勿扰模式是否关闭
3. 小米/华为等需要设置自启动和后台运行权限
4. Android 12+ 需要授予"精确闹钟"权限

详细解决方案：[FAQ.md - 通知提醒](FAQ.md#通知提醒)

#### Q: 笔记没有同步怎么办？

**A:** 排查步骤：
1. 检查网络连接
2. 下拉刷新手动触发同步
3. 重新登录账号
4. 查看设置 > 实验室 > 同步日志

详细解决方案：[FAQ.md - 同步问题](FAQ.md#同步问题)

#### Q: 如何搭建自己的 Memos 服务器？

**A:** 推荐使用 Docker：
```bash
docker run -d \
  --name memos \
  --publish 5230:5230 \
  --volume ~/.memos/:/var/opt/memos \
  neosmemo/memos:stable
```

详细教程：[FAQ.md - 服务器配置](FAQ.md#服务器配置)

### 更多问题

查看完整的常见问题解答：**[FAQ.md](FAQ.md)**

---

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

```
MIT License

Copyright (c) 2025 InkRoot

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📧 联系方式

- **开发者邮箱**: [sdwxgzh@126.com](mailto:sdwxgzh@126.com)
- **官方网站**: [https://inkroot.cn](https://inkroot.cn)
- **GitHub 仓库**: [https://github.com/yyyyymmmmm/IntRoot](https://github.com/yyyyymmmmm/IntRoot)
- **问题反馈**: [GitHub Issues](https://github.com/yyyyymmmmm/IntRoot/issues)
- **功能建议**: [GitHub Discussions](https://github.com/yyyyymmmmm/IntRoot/discussions)

---

## 🔗 相关链接

- **Memos 项目**: [https://github.com/usememos/memos](https://github.com/usememos/memos)
- **Flutter 官网**: [https://flutter.dev](https://flutter.dev)
- **Material Design 3**: [https://m3.material.io](https://m3.material.io)
- **Dart 语言**: [https://dart.dev](https://dart.dev)

---

## 🙏 致谢

感谢以下开源项目和贡献者：

- **[Flutter](https://flutter.dev)** - Google 的跨平台 UI 框架
- **[Memos](https://github.com/usememos/memos)** - 优秀的开源笔记服务
- **[Material Design](https://material.io)** - Google 的设计语言系统
- 所有为本项目做出贡献的开发者
- 所有提供反馈和建议的用户

---

## 🌟 支持项目

如果这个项目对你有帮助，请给我们一个 ⭐️ Star！

你也可以通过以下方式支持我们：

- 🌟 给项目点个 Star
- 🐛 提交 Bug 报告
- 💡 提出功能建议
- 📝 改进文档
- 💻 贡献代码
- 🌐 帮助翻译
- 📢 分享给更多人

---

<div align="center">

### Made with ❤️ by InkRoot

**如果觉得不错，请给我们一个 ⭐️**

[⬆ 回到顶部](#inkroot---墨鸣笔记)

</div>
