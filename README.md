# ACR — Advanced Call Recorder

[![License: GPL-3.0-only](https://img.shields.io/badge/License-GPL--3.0--only-blue.svg)](LICENSE)
[![Android](https://img.shields.io/badge/Android-10%2B-green.svg)](https://developer.android.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)

高质量、全自动的 Android 通话录音应用。为已 root 设备、自定义 ROM 和 Xposed/LSPosed 框架用户设计。

> **🎙️ Vibe Coding** — 本项目由 [Claude Code](https://claude.ai/code) 驱动开发，通过 Skill 编排多智能体协作完成从需求分析到代码实现的全流程。

## 📱 截图

<!-- TODO: 截图待补充 -->

| 录音界面 | 归档列表 | 设置 |
| :---: | :---: | :---: |
| ![录音](screenshots/recording.png) | ![归档](screenshots/archive.png) | ![设置](screenshots/settings.png) |

## ✨ 功能

### 通话录音

- **全自动触发** — 通过 `InCallService` 监听通话状态，来电/去电自动开始录音
- **6 种输出格式** — Opus (OGG) · AAC (M4A) · FLAC · WAV (PCM) · AMR-WB · AMR-NB
- **智能规则引擎** — 按号码、通话方向、SIM 卡槽设置录音规则（保存 / 暂停 / 丢弃 / 忽略）
- **通配符匹配** — 号码模式支持 `*` 前缀/后缀匹配
- **前台通知** — 通话中常驻通知，支持暂停/恢复/保留/丢弃快捷操作
- **RMS 静音检测** — 基于均方根算法（默认 -40dBFS 阈值，90% 静音占比），自动丢弃无效录音
- **多音频源** — VOICE_CALL / VOICE_UPLINK_DOWNLINK（立体声分离）/ VOICE_UPLINK / VOICE_DOWNLINK

### 手动录音

- 与通话录音共享同一套 `AudioRecord` + `MediaCodec` 原生引擎
- 支持全部 6 种格式、自定义文件名模板、元数据 JSON 输出
- 暂停/恢复、长按停止（带进度环动画）

### 文件管理

- **SAF 输出** — 用户可选择任意目录（SD 卡 / 外部存储）
- **统一归档** — 通话录音和手动录音在同一列表中展示
- **方向标签** — 来电（绿）/ 去电（蓝）/ 会议（紫）
- **内联播放** — just_audio + ExoPlayer 原生支持 content:// URI
- **下拉刷新** — 及时同步文件变更
- **元数据 JSON** — 每次录音生成侧车文件（通话详情、格式参数、录音指标）
- **自动清理** — 按天数保留策略自动删除过期文件

### UI & 体验

- **Material 3** — ColorScheme.fromSeed() 动态主题，亮色/暗色/跟随系统
- **底部导航** — 录音 / 归档 / 设置三 Tab 布局
- **Firebase Auth** — Google 登录（无 GMS 设备优雅降级）
- **DirectBoot** — 未解锁设备也可录音，解锁后自动迁移

### 部署

- Magisk / KernelSU 模块安装（priv-app）
- Xposed / LSPosed 模块支持
- 仅支持 Android 10+ (API 29+)，目标 API 36

## 🚀 安装

### 方式一：Magisk / KernelSU 模块（推荐）

> 模块打包功能开发中，详见 [T-11](https://github.com/UnicomAndroid/ACR/issues)。

1. 下载最新 `acr-vX.Y.Z-ksu.zip`
2. 在 Magisk / KernelSU Manager 中刷入模块
3. 重启设备

### 方式二：手动安装为系统 priv-app

```bash
adb push app-release.apk /system/priv-app/studio.unicom.acr/studio.unicom.acr.apk
adb push privapp-permissions-studio.unicom.acr.xml /system/etc/permissions/
adb reboot
```

### 方式三：Xposed / LSPosed 模块

1. 安装 APK
2. 在 LSPosed Manager 中启用 ACR 模块
3. 选择推荐的作用域（电话、通讯录）

## 🛠️ 构建

### 环境要求

- Flutter 3.x (stable)
- Android SDK 34+
- JDK 21

```bash
# 克隆项目
git clone git@github.com:UnicomAndroid/ACR.git
cd ACR

# 安装依赖
flutter pub get

# 构建 APK
flutter build apk --release

# 输出: build/app/outputs/flutter-apk/app-release.apk
```

## 🏗️ 技术架构

```text
┌─────────────────────────────────────────┐
│              Flutter (Dart)             │
│  ┌─────────┐ ┌────────┐ ┌───────────┐  │
│  │ Rec Tab │ │Archive │ │ Settings  │  │
│  └────┬─────┘ └───┬────┘ └─────┬─────┘  │
│       └────────────┼────────────┘        │
│              NativeBridge                │
│         MethodChannel IPC                │
├─────────────────────────────────────────┤
│            Android (Kotlin)             │
│  ┌──────────────────────────────────┐   │
│  │       MainActivity.kt            │   │
│  │   MethodCallHandler + SAF Picker │   │
│  └──────────────┬───────────────────┘   │
│                 │                        │
│  ┌──────────────┴───────────────────┐   │
│  │    RecorderInCallService.kt      │   │
│  │     InCallService 前台服务        │   │
│  │     ┌─────────────────────┐      │   │
│  │     │   RecorderThread    │      │   │
│  │     │  AudioRecord +      │      │   │
│  │     │  MediaCodec 管道    │      │   │
│  │     └─────────────────────┘      │   │
│  └──────────────────────────────────┘   │
│  ┌──────────────────────────────────┐   │
│  │   ManualRecordingService.kt      │   │
│  │   手动录音 (复用 RecorderThread)  │   │
│  └──────────────────────────────────┘   │
│  ┌──────────────────────────────────┐   │
│  │  SilenceDetector · Retention     │   │
│  │  Format · RuleEngine · Notify    │   │
│  │  OutputDirUtils · CallMetadata   │   │
│  └──────────────────────────────────┘   │
│            Storage Access Framework      │
└─────────────────────────────────────────┘
```

## 📦 依赖

| 组件 | 用途 |
| :--- | :--- |
| `just_audio` / ExoPlayer | 音频播放，原生 content:// URI |
| `kotlinx-serialization-json` | 元数据 JSON 序列化 |
| `libphonenumber-android` | 电话号码格式化与匹配 |
| `libxposed` (API 101.0.0) | Xposed/LSPosed 模块接口 |
| `Firebase Auth` + Google Sign-In | 用户认证 |
| `MediaCodec` | 音频编码（Opus/AAC/FLAC/AMR） |
| `AudioRecord` | 音频捕获 |

## 🤝 致谢

本项目基于 **[BCR (Basic Call Recorder)](https://github.com/chenxiaolong/BCR)** 的原生录音引擎，由 **Andrew Gunnerson** 开发并维护。

- 原始项目 © 2022-2026 Andrew Gunnerson
- `RecorderThread`、`Format` 抽象、`OutputDirUtils`、`SilenceDetector` 等核心模块继承自 BCR 并进行了适配和增强
- Flutter UI、MethodChannel 通信桥、手动录音服务、Material 3 主题等为新增实现

**特别感谢 Andrew Gunnerson 和 BCR 项目的所有贡献者。**

## 🎙️ Vibe Coding

本项目采用 Vibe Coding 模式开发——与 AI 结对编程，由 Claude Code 作为主要编码代理：

- **AI 模型**：Claude Code (Anthropic)
- **工作流**：Skill 系统 + 多智能体协作（Plan → Explore → Implement → Review）
- **PRD → Tasks**：从产品需求文档自动生成结构化任务分解
- **全栈覆盖**：Kotlin 原生层、Flutter UI 层、MethodChannel IPC、构建配置

> "不是 AI 替你写代码，而是你和 AI 一起 Vibe。"

## 📄 许可

本项目基于 **GPL-3.0-only** 许可发布。详见 [LICENSE](LICENSE)。

```text
SPDX-FileCopyrightText: 2022-2026 Andrew Gunnerson
SPDX-FileCopyrightText: 2026 UnicomAndroid
SPDX-License-Identifier: GPL-3.0-only
```
