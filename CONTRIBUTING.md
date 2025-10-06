# 贡献指南

感谢您考虑为 InkRoot 做出贡献！我们欢迎所有形式的贡献。

## 📋 目录

- [行为准则](#行为准则)
- [如何贡献](#如何贡献)
- [开发流程](#开发流程)
- [代码规范](#代码规范)
- [提交规范](#提交规范)
- [Pull Request 流程](#pull-request-流程)
- [问题反馈](#问题反馈)

---

## 行为准则

### 我们的承诺

为了营造一个开放和友好的环境，我们承诺：

- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注对社区最有利的事情
- 对其他社区成员表示同情

### 我们的标准

**积极行为包括：**

- ✅ 使用友好和包容的语言
- ✅ 尊重不同的观点和经验
- ✅ 优雅地接受建设性批评
- ✅ 关注对社区最有利的事情
- ✅ 对其他社区成员表示同情

**不可接受的行为包括：**

- ❌ 使用性化的语言或图像
- ❌ 侮辱性或贬损性评论
- ❌ 人身攻击
- ❌ 公开或私下的骚扰
- ❌ 未经许可发布他人的私人信息

---

## 如何贡献

### 🐛 报告 Bug

如果你发现了 Bug，请通过 [GitHub Issues](https://github.com/yyyyymmmmm/IntRoot/issues) 提交问题报告。

**好的 Bug 报告应该包含：**

- 清晰的标题和描述
- 详细的复现步骤
- 预期行为和实际行为
- 设备信息（操作系统、应用版本等）
- 相关的截图或日志
- 可能的解决方案（如果有）

**Bug 报告模板：**

```markdown
**问题描述**
简要描述问题

**复现步骤**
1. 打开应用
2. 点击 "XXX"
3. 滚动到 "XXX"
4. 看到错误

**预期行为**
应该发生什么

**实际行为**
实际发生了什么

**设备信息**
- 操作系统: [如 iOS 16.0]
- 应用版本: [如 1.0.3]
- 设备型号: [如 iPhone 14 Pro]

**截图**
如果可能，添加截图帮助说明问题

**日志**
如果可能，添加相关的错误日志
```

### 💡 功能建议

我们欢迎新功能建议！请通过 [GitHub Discussions](https://github.com/yyyyymmmmm/IntRoot/discussions) 提交。

**好的功能建议应该包含：**

- 清晰的功能描述
- 使用场景和需求背景
- 预期的实现方式（如果有想法）
- 可能的替代方案
- 对现有功能的影响

### 📖 改进文档

文档改进包括但不限于：

- 修正错别字和语法错误
- 补充缺失的说明
- 添加使用示例
- 改进文档结构
- 翻译文档到其他语言

### 💻 贡献代码

请遵循以下步骤贡献代码：

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的改动 (`git commit -m 'feat: 添加某个很棒的功能'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

---

## 开发流程

### 1. 环境准备

#### 安装 Flutter

```bash
# 访问 Flutter 官网下载安装
https://flutter.dev/docs/get-started/install

# 验证安装
flutter doctor
```

#### 克隆仓库

```bash
git clone https://github.com/yyyyymmmmm/IntRoot.git
cd IntRoot
```

#### 安装依赖

```bash
flutter pub get
```

### 2. 创建分支

```bash
# 从 master 创建新分支
git checkout -b feature/your-feature-name

# 或者修复 bug
git checkout -b fix/your-bug-fix
```

### 3. 开发和测试

```bash
# 运行应用（开发模式）
flutter run

# 运行在指定设备
flutter run -d <device-id>

# 运行测试
flutter test

# 代码检查
flutter analyze
```

### 4. 提交代码

```bash
# 添加改动
git add .

# 提交改动（遵循提交规范）
git commit -m "feat: 添加新功能"

# 推送到远程
git push origin feature/your-feature-name
```

### 5. 创建 Pull Request

1. 在 GitHub 上打开你的 Fork
2. 点击 "New Pull Request"
3. 填写 PR 标题和描述
4. 等待代码审查

---

## 代码规范

### 文件命名

- 使用小写字母和下划线：`user_profile_screen.dart`
- 测试文件添加 `_test` 后缀：`user_profile_screen_test.dart`

### 代码风格

遵循 [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)：

```dart
// ✅ 好的命名
class UserProfileScreen extends StatelessWidget { }
var userName = 'John';
const apiBaseUrl = 'https://api.example.com';

// ❌ 不好的命名
class userprofilescreen extends StatelessWidget { }
var UserName = 'John';
const API_BASE_URL = 'https://api.example.com';
```

### 注释规范

```dart
/// 文档注释使用三斜线，会被 dartdoc 生成文档
/// 
/// 可以使用 Markdown 语法
class UserService {
  // 单行注释使用双斜线
  void login() { }
  
  /* 
   * 多行注释使用这种格式
   * 通常用于临时注释代码
   */
}
```

### 代码格式化

提交前务必格式化代码：

```bash
# 格式化所有 Dart 文件
flutter format .

# 格式化指定文件
flutter format lib/main.dart
```

### 代码检查

提交前务必检查代码：

```bash
# 运行代码分析
flutter analyze

# 应该看到：No issues found!
```

---

## 提交规范

我们使用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/) 规范：

### 提交类型

- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档更新
- `style`: 代码格式调整（不影响代码运行）
- `refactor`: 代码重构（既不是新功能也不是 bug 修复）
- `perf`: 性能优化
- `test`: 添加或修改测试
- `build`: 构建系统或外部依赖的变动
- `ci`: CI 配置文件和脚本的变动
- `chore`: 其他不修改 src 或 test 文件的变动
- `revert`: 撤销之前的提交

### 提交格式

```
<类型>(<范围>): <简短描述>

<详细描述>

<页脚>
```

### 示例

```bash
# 简单提交
git commit -m "feat: 添加语音识别功能"

# 带范围的提交
git commit -m "fix(auth): 修复登录失败的问题"

# 完整提交
git commit -m "feat(note): 添加笔记导出功能

- 支持导出为 JSON 格式
- 支持导出为 Markdown 格式
- 添加批量导出功能

Closes #123"
```

### 提交消息规范

**✅ 好的提交消息：**

```
feat: 添加语音识别功能
fix: 修复笔记同步失败的问题
docs: 更新 README 安装说明
style: 格式化代码
refactor: 重构笔记列表组件
perf: 优化图片加载性能
test: 添加用户登录测试
```

**❌ 不好的提交消息：**

```
update
fix bug
修改代码
aaa
临时提交
```

---

## Pull Request 流程

### 1. 准备工作

在创建 PR 之前，请确保：

- [ ] 代码已通过 `flutter analyze`
- [ ] 代码已使用 `flutter format` 格式化
- [ ] 已添加必要的注释
- [ ] 已更新相关文档
- [ ] 已添加或更新测试（如适用）
- [ ] 已在本地测试功能正常工作

### 2. 创建 Pull Request

**PR 标题格式：**

```
<类型>: <简短描述>

示例：
feat: 添加语音识别功能
fix: 修复笔记同步问题
docs: 更新贡献指南
```

**PR 描述模板：**

```markdown
## 变更类型
- [ ] 新功能
- [ ] Bug 修复
- [ ] 文档更新
- [ ] 代码重构
- [ ] 性能优化
- [ ] 测试
- [ ] 其他

## 变更描述
简要描述你的改动

## 相关 Issue
Closes #123

## 测试
描述你如何测试这些改动

## 截图（如适用）
添加相关截图

## 检查清单
- [ ] 代码已通过 flutter analyze
- [ ] 代码已格式化
- [ ] 已添加必要的注释
- [ ] 已更新文档
- [ ] 已添加测试
- [ ] 已在真机上测试
```

### 3. 代码审查

PR 提交后：

1. 自动化检查会运行（CI/CD）
2. 维护者会审查你的代码
3. 可能会要求进行修改
4. 修改后更新 PR
5. 审查通过后会被合并

### 4. 合并后

PR 合并后：

1. 删除你的特性分支
2. 更新本地仓库
3. 关注后续的反馈

---

## 问题反馈

### 安全问题

如果你发现安全漏洞，**请不要**在公开的 Issue 中报告。

请发送邮件到：[sdwxgzh@126.com](mailto:sdwxgzh@126.com)

### 其他问题

对于非安全相关的问题，请通过以下方式联系：

- **GitHub Issues**: [提交 Issue](https://github.com/yyyyymmmmm/IntRoot/issues)
- **GitHub Discussions**: [参与讨论](https://github.com/yyyyymmmmm/IntRoot/discussions)
- **邮箱**: [sdwxgzh@126.com](mailto:sdwxgzh@126.com)

---

## 开发资源

### 文档

- [Flutter 官方文档](https://flutter.dev/docs)
- [Dart 语言文档](https://dart.dev/guides)
- [Material Design 3](https://m3.material.io)
- [Memos API 文档](https://github.com/usememos/memos)

### 工具

- [VS Code](https://code.visualstudio.com) + [Flutter 插件](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)
- [Android Studio](https://developer.android.com/studio) + [Flutter 插件](https://plugins.jetbrains.com/plugin/9212-flutter)
- [Xcode](https://developer.apple.com/xcode/) (macOS only)
- [DevTools](https://docs.flutter.dev/development/tools/devtools/overview)

### 学习资源

- [Flutter 实战](https://book.flutterchina.club)
- [Dart 编程语言](https://dart.cn)
- [Flutter 社区](https://flutter.cn)

---

## 获取帮助

如果你在贡献过程中遇到问题：

1. 查看 [README.md](README.md)
2. 搜索 [Issues](https://github.com/yyyyymmmmm/IntRoot/issues)
3. 在 [Discussions](https://github.com/yyyyymmmmm/IntRoot/discussions) 中提问
4. 发送邮件到 [sdwxgzh@126.com](mailto:sdwxgzh@126.com)

---

## 致谢

感谢所有为 InkRoot 做出贡献的人！

你的贡献让这个项目变得更好！❤️

---

**Happy Coding!** 🚀

