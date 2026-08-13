# AGENTS.md

## 构建与测试命令

本项目为 HarmonyOS (ArkTS/ArkUI) 应用，构建工具为 hvigorw（位于 DevEco Studio 内）。

- **编译构建**：`/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --no-daemon assembleHap -p product=default`
- **运行单元测试**：`/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --no-daemon test -p product=default`
- **清理后构建**：在命令前加 `clean`，如 `... hvigorw --no-daemon clean assembleHap -p product=default`

注意：真实拍照/OCR/通知等系统能力（Core Vision Kit、Camera Kit、reminderAgentManager）需在真机或模拟器上验证，命令行构建仅能保证编译与单元测试通过。

## 架构约定

- 严格分层：`models` → `repository`(DatabaseHelper 单例 `dbHelper`) → `usecases` → `pages` + `components` + `services`(能力适配层)
- ArkTS 约束：静态方法内**禁止使用 `this`**（用 `ClassName.xxx`）；禁止 `any`/`unknown`；禁止索引访问类型 `T['k']`（直接 import 类型名）；`Length` 类型可能是 `Resource`，转 number 时需分类型判断。
- 新增页面需在 `entry/src/main/resources/base/profile/main_pages.json` 注册。
- 新增系统权限需在 `entry/src/main/module.json5` 的 `requestPermissions` 声明，并在 `string.json` 补充 reason。
