# AGENTS.md

## 仓库结构

本仓库是题醒多平台工程：

- `harmonyos/`：HarmonyOS / ArkTS 工程，当前可构建版本。
- `android/`：Android 工程目录，当前为预留目录。
- `ios/`：iOS / SwiftUI 工程目录，当前已实现 v1.0.3 功能基线。
- `docs/`：跨平台产品、架构与 UX 资料。

## 平台约定

- 修改 HarmonyOS 代码时，进入 `harmonyos/` 目录执行构建和测试；具体命令和 ArkTS 约束见 `harmonyos/AGENTS.md`。
- 使用 IDE 时必须打开平台自身目录：DevEco Studio 打开 `harmonyos/`，Android Studio 打开 `android/`，Xcode 打开 `ios/`；不要用平台 IDE 直接打开仓库根目录。
- Android 工程落地后，应在各自目录补充平台级 `AGENTS.md`，说明构建、测试、架构和资源约定。
- 跨平台共享的产品结论、设计规范和 UX 截图放在根目录 `docs/`，避免为每个平台重复维护一份。
