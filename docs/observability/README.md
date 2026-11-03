# 题醒稳定性与性能监控架构

## 目标

题醒在 HarmonyOS 与 iOS 两端接入友盟 U-App / U-APM 与腾讯 Bugly Pro，形成互补的质量数据链路：

- 友盟：功能行为、关键链路耗时、AI 请求成败；iOS 同时启用 U-APM 的启动与页面异常能力。
- Bugly：崩溃、JS/ObjC/Native 异常、卡顿、内存、启动、页面加载与网络质量。
- 统一脱敏：所有第三方事件先经过事件名/属性过滤，儿童学习内容不出设备。

Android 目录目前仍是预留工程，待 Android 应用工程落地后按同一架构接入。

## 分层架构

```text
业务页面 / 服务
  ├─ HarmonyOS: PerformanceMonitor
  └─ iOS: ObservabilityService / AppStore.track
        ↓
统一事件模型 + 脱敏器 + 隐私同意门闸
  ├─ Umeng Provider：行为、耗时、APM
  └─ Bugly Provider：崩溃、自定义错误、性能
```

设计约束：

- 页面和服务不得直接 import 厂商 SDK，只能依赖统一入口。
- 首次启动先展示匿名质量统计说明；拒绝时功能完全可用，但第三方 SDK 不激活、不上报。
- 已同意后的启动会尽早恢复 SDK；同时接入多个崩溃 SDK 时按官方建议先激活 Bugly，再激活友盟。
- SDK Provider 可单独失败，不影响业务线程；替换或新增厂商只改 Observability/Telemetry 层。

## 隐私与脱敏

统一脱敏规则：

- 事件名只保留 ASCII 字母、数字、下划线。
- 属性最多 16 个；key 最长 64；字符串值最长 180。
- 错误 `message/detail` 均清洗后上报，堆栈类信息按平台限制截断。
- Bearer token 替换为 `[token]`，邮箱替换为 `[email]`。
- 阻止 `api_key`、`authorization`、`question`、`answer`、`text`、`content`、`image`、`audio`、`nickname`、`student_id` 等敏感字段。
- 不上传题目照片、学生答案、AI 回答、语音文本、录音/图片路径、姓名或联系方式。

设备标识策略：

- HarmonyOS 友盟禁用 OAID、屏幕与运营商信息；Bugly 使用本地生成并持久化的随机 deviceId。
- iOS Bugly 使用本地生成并持久化的随机 `clientTag`，不读取精确位置或通讯录。
- iOS Bugly 额外关闭地区编码与越狱状态采集。

## 配置

### HarmonyOS

友盟配置：

- `harmonyos/AppScope/resources/rawfile/umconfig.json`

```json
{
  "appKey": "6ae5a2846545637cd62c8fb5",
  "channel": "AppGallery"
}
```

Bugly 配置：

- `harmonyos/AppScope/resources/rawfile/monitoringconfig.json`

```json
{
  "channel": "AppGallery",
  "buglyAppId": "",
  "buglyAppKey": ""
}
```

在 Bugly 后台创建 **Harmony** 产品后，将产品信息里的 AppId/AppKey 填入。为空时 Bugly 不初始化，友盟和业务功能不受影响。

### iOS

- 友盟 AppKey：`ios/TiXing/Services/Observability/ObservabilityConfig.swift`
- 渠道：`App Store`
- Bugly 配置：`ios/TiXing/Resources/buglyconfig.json`（本地文件，不入库）

```json
{
  "appId": "在 Bugly 后台创建 iOS 产品后填写",
  "appKey": "在 Bugly 后台创建 iOS 产品后填写"
}
```

在 Bugly 后台创建 **iOS** 产品后填写同一 App 的一份本地配置。该文件不存在或凭据为空时 Provider 保持 no-op。

> 注意：友盟 AppKey 不能复用为 Bugly 凭据。Bugly 需要按平台分别创建产品并获得自己的 AppId/AppKey。

### SDK 安装

iOS 二进制 SDK 不入库，新环境执行：

```bash
cd /Users/dfx/TiXing/ios
./Scripts/install_observability_sdks.sh
```

脚本会：

1. 从友盟官方下载接口安装 `UMCommon`、`UMDevice`、`UMAPM` XCFramework。
2. 从 Bugly 官方 GitHub Release 安装 `BuglyPro.xcframework` 2.8.2.14。
3. 重新执行 `generate_project.py`，把本地 Vendor 框架链接进 Xcode 工程。

Bugly 脚本会复用 `/tmp/BuglyPro-<version>.zip` 或 `BUGLY_SDK_ARCHIVE` 指定的完整缓存包。官方压缩包同时包含整体包和分模块包；本工程采用 Bugly 默认整体 Subspec，只安装 `BuglyPro.xcframework`，避免整体包与模块包符号冲突。

## 指标覆盖

| 类别 | 指标 / 事件 | 说明 |
| --- | --- | --- |
| 启动 | `metric_app_first_frame`、`metric_perf_trace(trace_name=app_bootstrap)` | iOS 首帧；HarmonyOS 关键启动链路耗时 |
| 拍照录入 | `behavior_capture`、`metric_ai_recognize` | 录入成败、识别耗时、识别题目数、失败阶段 |
| 复习 | `behavior_review_submit`、`fault_review_submit_failed` | 提交结果与失败原因码 |
| 问一问 | `metric_voice_transcription`、`metric_voice_answer` | 转写与回答成败、耗时、失败阶段 |
| AI | `metric_ai_request` | 请求耗时、HTTP 状态、transport/decode/config 阶段 |
| 备份 | `metric_backup_export/import/preview` | 导入导出成败、耗时、数据规模 |
| 稳定性 | Bugly Crash / Freeze / JS / ObjC / Native | SDK 自动采集与上传 |
| 性能 | Bugly 卡顿、内存、启动、页面加载、网络 | SDK 自动采集；采样率需在后台配置 |

Bugly 后台接入期建议将测试设备加入白名单并把性能采样率调为 1；崩溃默认全量上报。正式环境可按版本配置灰度/发布采样率。

## 验证

已完成的本地回归：

- HarmonyOS：`hvigorw test` 通过，`assembleHap` 通过。
- iOS：`xcodebuild test` 67/67 通过，Release `build` 通过。

线上联调步骤：

1. 安装并首次启动，确认匿名质量统计弹窗；拒绝后不初始化第三方 SDK。
2. 同意后触发拍照、复习、问一问、备份，在友盟集成测试/自定义事件中查看 `behavior_telemetry_consent`、`behavior_capture`、`metric_ai_request`。
3. 填入 Bugly 凭据后触发一个受控自定义错误，在 Bugly“错误”页确认聚类。
4. 在 Bugly 后台确认 Crash、卡顿、内存、启动、页面加载、网络模块数据开始入库。
