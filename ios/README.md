# TiXing iOS

此目录是题醒 iOS 原生应用工程。

## 打开与构建

用 Xcode 打开：

```text
/Users/dfx/TiXing/ios/TiXing.xcodeproj
```

默认 Scheme 为 `TiXing`，最低部署版本 iOS 17.0。

## AI 配置

AI 使用固定模型 `glm-5.3-flash`，配置文件位置：

```text
ios/TiXing/Resources/apiconfig.json
```

该文件不入库。构建脚本会在文件存在时复制进 App Bundle；缺失时应用可编译运行，但 AI 功能会提示未配置。

## 工程结构

```text
TiXing/
├── App/          # 入口、根导航
├── Models/       # 领域模型与 AI 模型
├── Store/        # 本地持久化与业务状态
├── Services/     # AI、语音、提醒、备份等能力适配
├── Features/     # 页面模块
├── Theme/        # 设计系统
└── Resources/    # Info.plist、图标、AI 配置
```

## 数据与兼容

- 本地数据由 `SQLiteStoreService` 持久化到 Application Support 中的 `tixing-v3.db`，逻辑 schema 为 v3。
- SQLite 建有错题复习时间、学生、复习日志、积分、分析事件、知识画像、问一问时间等索引。
- 旧版 `store-v3.json` 会在首次启动时自动迁移到 SQLite；迁移失败时临时降级 JSON，避免数据不可用。
- 错题图片保存在 Documents/Mistakes。
- 讲解图片笔记保存在 Documents/Mistakes，文件名以 `note-` 开头。
- 问一问原始录音保存在 Documents/VoiceAsks。
- 导出 / 导入使用 tixing bundle v3，`data.json` 与 HarmonyOS 字段结构兼容。

## 质量基线

- 单元测试：53 个，覆盖 SQLite、迁移、备份、图片质量、复习算法、知识画像和好奇星球。
- 压测：500 条错题 SQLite 写入 / 读取自动验证。
- 备份：真实 1600 × 1200 JPEG 自动打包 / 解包验证。
- 构建：Debug 与 Release 均已验证。
