# AGENTS.md

## 构建与测试

iOS 工程位于本目录，入口是 `TiXing.xcodeproj`，默认 Scheme 为 `TiXing`。

```bash
xcodebuild -project TiXing.xcodeproj \
  -scheme TiXing \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build

xcodebuild -project TiXing.xcodeproj \
  -scheme TiXing \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

## 架构约定

- `Models/`：纯领域模型与 AI 响应模型，不引用 SwiftUI。
- `Store/`：`AppStore` 负责本地状态、复习提交、积分和导入合并；`SQLiteStoreService` 负责 schema v3、索引、事务、持久化和 JSON 迁移。
- `Services/`：AI、语音、提醒、备份、哈希等平台能力适配。
- `Features/`：按业务模块拆分 SwiftUI 页面。
- `Theme/`：跨页面设计系统与复用控件。
- 页面不直接持久化数据；需要写数据时通过 `AppStore`。

## 平台能力

- AI：`glm-5.3-flash`，配置从 `TiXing/Resources/apiconfig.json` 读取；该文件不入库。
- 语音识别：Apple Speech framework，中文、端侧优先。
- 语音合成：`AVSpeechSynthesizer`。
- 提醒：UserNotifications 优先，EventKit 日历降级。
- 备份：自定义 stored ZIP，bundle version 3，与 HarmonyOS 数据结构兼容。
- 图片质量：`ImageQualityService` 做解码、分辨率、亮度、反光、对比度和长宽比检查。
- 知识画像：每次保存前按标签聚合总数、掌握数、掌握率和趋势。

## 注意事项

- `generate_project.py` 用于重建 Xcode 工程文件；新增或删除 Swift 文件后需要重新执行。
- 修改领域模型时必须评估备份兼容性。
- 修改 SQLite 表结构时必须递增迁移策略并补齐 `AlignmentTests`。
- 修改复习算法时必须同步维护 `TiXingTests` 与 HarmonyOS 实现。
