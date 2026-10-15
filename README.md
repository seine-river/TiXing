# 题醒多平台工程

题醒是一款面向小学生家庭的智能错题记录、科学复习、AI 问答与兴趣观察应用。

## 目录结构

```text
TiXing/
├── harmonyos/   # HarmonyOS / ArkTS 应用工程
├── android/     # Android 应用工程（预留）
├── ios/         # iOS 应用工程（预留）
└── docs/        # 跨平台产品、架构与 UX 资料
```

## 当前状态

- `harmonyos/` 保存当前已实现的 HarmonyOS 版本。
- `android/` 与 `ios/` 为后续原生应用工程预留。
- iOS UX 设计参考截图见 `docs/ux_screenshots/reference/`。

## IDE 打开方式

不同平台使用各自目录独立打开，避免 IDE 把其他平台文件识别进当前工程：

- **DevEco Studio**：打开 `/Users/dfx/TiXing/harmonyos`
- **Android Studio**：后续工程落地后打开 `/Users/dfx/TiXing/android`
- **Xcode**：后续工程落地后打开 `/Users/dfx/TiXing/ios`
