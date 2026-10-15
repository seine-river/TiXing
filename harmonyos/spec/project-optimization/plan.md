# Implementation Plan: TiXing 工程全面优化（安全/数据/性能/功能/质量）

**Input**: Feature specification from `spec/project-optimization/spec.md`

## Summary

对现有错题管理应用 TiXing 进行五批次工程整改：A 安全合规（API Key 出库至 rawfile 本地配置、签名密码出库、gitignore 整改、release 混淆）；B 数据可靠与核心功能修复（统一错误处理、复习提交原子化用例、DB 就绪机制、提醒权限与幂等、导入导出补全、删除确认与事务）；C 性能（索引、SQL 聚合、懒加载、图片降采样、句柄/内存释放、临时文件清理）；D 功能收口（OCR 置信度、streak、dailyLimit 消费、学科检测、判分归一化）；E 质量债（颜色资源化+深色模式、公共组件提炼、CapturePage 拆分、DB 版本化迁移、死代码清理）。

## Technical Context

**Language/Version**: ArkTS（API 12+，Stage 模型），hvigorw 构建  
**Primary Dependencies**: @kit.AbilityKit、@kit.ArkData（relationalStore/Preferences）、@kit.MediaKit（photoAccessHelper/cameraPicker）、@kit.CoreVisionKit（OCR/textRecognition）、@kit.BackgroundTasksKit（reminderAgentManager）、@ohos.zlib（压缩）、@kit.NetworkKit（http，AI 请求）  
**State Management**: 保留项目现有 State Management V1（@State/@Prop/@Builder）——增量改造项目，不做 V2 迁移（遵循增量项目保留既有状态管理的规则）  
**Storage**: 关系型数据库 relationalStore（RDB/SQLite）为主，Preferences 存轻量状态（reminderId 等），rawfile 存本地密钥配置，文件系统存错题图片  
**Testing**: hvigorw test（hypium 单元测试）+ 命令行构建验证；真机能力（提醒/OCR/拍照）以模拟器/真机 UI 验证为准  
**Target Platform**: HarmonyOS 手机（phone）  
**Project Type**: 移动应用（单 entry 模块）  
**Performance Goals**: 500+ 错题规模下列表滑动流畅、统计页秒开、冷启动首屏无空数据；复习提交零状态覆盖  
**Constraints**: 遵循 AGENTS.md 约定（分层 models→repository→usecases→pages、静态方法禁 this、禁 any/unknown、禁索引访问类型、新页面注册 main_pages.json、权限声明+reason）；深色模式仅配色资源化；不做 i18n/云同步/账号体系  
**Scale/Scope**: 改造约 50 个 .ets 文件中的 ~30 个，新增 ~8 个文件；8 个用户故事、27 条 FR

## Project Structure

### Documentation (this feature)

```text
spec/project-optimization/
├── spec.md              # 需求规格（已确认）
├── plan.md              # 本文件
└── tasks.md             # 任务清单（Phase 3 生成）
```

### Source Code (repository root)

```text
# 现有分层架构保持不变（models→repository→usecases→pages+components+services+common）

entry/src/main/ets/
├── common/
│   ├── Constants.ets            # [改] AppColors 改为 $r 资源引用；新增答案归一化、标题截断等公共函数
│   ├── AiConfig.ets             # [新] 密钥配置读取器（读 rawfile/ai_config.json，缺失时安全降级）
│   ├── DbResult.ets             # [新] 轻量操作结果类型（成功/失败+原因），供写操作返回
│   └── Toast.ets                # [改] 不再静态持有 UIContext，改从上下文实时获取
├── models/
│   ├── Enums.ets                # [改] 补科学特征；移除不可达枚举值（SubscriptionPlanType 等按使用核查）
│   └── Mistake.ets 等           # [改] 死字段核查清理（如 RedeemableItem.owned 迁出持久化模型）
├── repository/
│   └── DatabaseHelper.ets       # [改] 核心：错误处理统一、whenReady 就绪机制、索引、版本化迁移(PRAGMA user_version)、
│                                #      事务（删除/种子/upsert）、聚合查询、分页查询、updateMistake 补 imageUrl、
│                                #      复习队列按学生过滤+消费 dailyLimit/科目开关、streak 查询、单例收敛
├── usecases/
│   ├── ReviewSubmitter.ets      # [新] 原子化复习提交用例（日志→判掌握→状态→积分→画像重算调度）
│   ├── StreakCalculator.ets     # [新] 连续学习天数计算（按日去重，含当日去重发分判断）
│   ├── SubjectDetector.ets      # [改] 全角括号修正、科学学科识别
│   ├── CaptureOrchestrator.ets  # [改] 真实 OCR 置信度传递、质检 fail-closed
│   └── KnowledgeProfileAggregator.ets  # [改] 按学生过滤、增量/延迟重算、僵尸画像清理
├── services/
│   ├── AiService.ets            # [改] 密钥改读 AiConfig；解析错误不再吞；错误信息带响应体
│   ├── ReminderService.ets      # [改] 运行时权限申请、getValidReminders 幂等清理、reminderId 持久化、
│   │                            #      失败如实上抛、行动按钮拉起应用
│   ├── MediaService.ets         # [改] fd/PixelMap try-finally 释放、persistUri 失败不降级临时uri、
│   │                            #      startsWith 路径判断、临时文件清理（含删除错题联动删图）
│   ├── DataPortabilityService.ets  # [改] zip 备份包（数据+图片）、导入恢复复习记录（去重）、
│   │                            #      异步解析+大小上限+格式校验、导出目录限量保留
│   └── PerformanceMonitor.ets   # [改] 补 Promise rejection 处理
├── components/
│   ├── CommonComponents.ets     # [改] 颜色走资源；PageHeader 触摸区/无障碍
│   ├── BasicWidgets.ets         # [新] FilterChip / PrimaryButton / AppCard / EmptyBlock / SectionCard
│   ├── MistakeCard.ets          # [新] 错题卡片+缩略图（降采样占位）复用组件
│   ├── GradientHeader.ets       # [新] 渐变头图+状态栏避让复用组件
│   └── CaptureSteps.ets         # [新] CapturePage 四步流程子组件（选源/裁剪/确认/结果）
├── pages/
│   ├── Index.ets                # [改] init 就绪等待+失败提示；Tab 图标无障碍
│   ├── HomePage.ets             # [改] 聚合统计、复用组件、图片降采样、资源化颜色
│   ├── MistakesPage.ets         # [改] LazyForEach+分页、删除二次确认、FilterChip 复用、loading态
│   ├── CapturePage.ets          # [改] 拆分为 CaptureSteps 子组件、alive 防护、写库失败如实提示
│   ├── MistakeDetailPage.ets    # [改] imageUrl 更新落库、清理死状态/导入、文案与行为一致
│   ├── ReviewPage.ets           # [改] 改用 ReviewSubmitter、判分归一化、onBackPress 确认、空态复用
│   ├── ReportPage.ets           # [改] 聚合查询、标签名展示、复用组件
│   ├── PointsCenterPage.ets     # [改] SUM 聚合、PointsActionType 映射、streak 展示
│   ├── ProfilePage.ets          # [改] 复用 GradientHeader/文案常量
│   ├── ProfileSettingPage.ets   # [改] 输入状态拆分、Chip 复用
│   ├── ReminderSettingPage.ets  # [改] TimePicker 编辑时间段、保存前权限申请、真实结果提示
│   ├── DataManagementPage.ets   # [改] 异步解析+busy 保护、死状态清理
│   └── OpsOverviewPage.ets      # [改] 聚合查询、初始化去重
└── entryability/
    └── EntryAbility.ets         # [改] 深色模式跟随与资源一致、onConfigurationUpdate、日志 tag

entry/src/main/resources/
├── base/element/color.json      # [新] 全量颜色资源（亮色）
├── dark/element/color.json      # [新] 深色配色
├── base/element/string.json     # [改] 补 INTERNET reason 等权限文案
├── rawfile/
│   ├── ai_config.json           # [新][gitignore] 本地密钥配置（不入库）
│   └── ai_config.example.json   # [新][入库] 配置模板与说明
entry/src/main/module.json5      # [改] INTERNET 补 reason/usedScene
entry/build-profile.json5        # [改] release 开启混淆
build-profile.json5（根）        # [改] 签名密码出库（本地化处理）
.gitignore                       # [改] 补 /Key/ /.cache/ .DS_Store /App截图/ /rawfile 密钥文件
```

**Structure Decision**: 本计划遵循项目现有分层架构（models→repository→usecases→pages+components+services+common），不引入 MVVM 目录、不做 V1→V2 状态管理迁移——本次为存量工程优化，未收到 MVVM 迁移请求。新增文件仅按现有职责边界放置：原子用例入 usecases、复用 UI 入 components、轻量类型入 common、本地密钥入 resources/rawfile（资源不放 ets 目录）。文件总数新增 8 个（AiConfig/DbResult/ReviewSubmitter/StreakCalculator/BasicWidgets/MistakeCard/GradientHeader/CaptureSteps），均为职责单一且被多处复用，无进一步合并空间。

## Complexity Tracking

无 Constitution Check 违规需要豁免。（新增 8 个文件均有明确复用面：4 个被 ≥3 页面复用的 UI 组件、2 个核心用例、2 个基础设施类型。）

## Research & Decisions

**D1 API Key 载体：rawfile 本地 JSON 配置（gitignore）+ 入库模板**
- **Decision**: 密钥存 `entry/src/main/resources/rawfile/ai_config.json`（.gitignore 覆盖），提交 `ai_config.example.json` 模板；`common/AiConfig.ets` 启动时读取，密钥为空时 AI 功能禁用并给出配置指引提示。
- **Rationale**: 配置缺失不破坏编译（对比 gitignore 一个 .ets 模块会导致新 clone 无法编译）；满足 FR-001"缺失时明确指引而非崩溃"；密钥不进 git 仓库。
- **Alternatives considered**: ① gitignored .ets 常量模块（编译期缺失即构建失败，DX 差，弃）；② 用户运行时输入存 Preferences（每个使用者需自行申请 Key，当前产品形态下负担过重，用户已否决）；③ 服务端代理（需服务器设施，用户已否决）。注意：密钥仍随安装包分发（rawfile 不加密），依赖用户吊销旧 Key + 新 Key 私自分发控制，已在 spec 假设中确认。

**D2 统一错误处理：写操作返回轻量 DbResult + hilog 统一记录，不引入异常上抛链**
- **Decision**: 新增 `common/DbResult.ets`（成功/失败+原因码）。DatabaseHelper 全部写操作返回 DbResult（不再空 catch），内部经统一的日志封装记录 tag+操作+错误；关键页面写路径检查结果并 Toast。读操作失败返回空集合/undefined 但必记日志；init 失败记录致命日志并向上返回失败，Index 弹提示。
- **Rationale**: 布尔+原因的轻量模式对 ~40 处改动是机械且低风险的；全链路 try/throw 会波及所有调用方签名，改动面失控。
- **Alternatives considered**: ① 全部改 throw（改动面大、易漏 catch 反而新增崩溃面，弃）；② 仅加日志保留 void 返回（页面仍无法感知失败，不满足 FR-005，弃）。

**D3 DB 就绪机制：repository 内部 ensureReady 全局兜底 + 首屏等待**
- **Decision**: DatabaseHelper 的 init 幂等（缓存就绪 Promise），全部公开读写方法入口先 await 就绪 Promise 再执行；Index 不再 fire-and-forget，init 完成后再触发 Tab 首次加载，失败 Toast。
- **Rationale**: 在 repository 层兜底可一次性消除所有页面的竞态（含未来新增页面），页面层仅补 loading 态；只改页面不改仓库无法覆盖全部入口。
- **Alternatives considered**: 仅页面层 await whenReady（依赖每个页面自觉，易漏，作为补充保留）。

**D4 原子复习提交：usecases 层 ReviewSubmitter 串行编排，不做 DB 跨表事务**
- **Decision**: 新增 `usecases/ReviewSubmitter.ets`：提交（错题，日志）→ 串行 await 插入日志 → 查询该题全部日志 → 掌握判定 → 一次 updateMistake 写入最终状态（消除两次并发写覆盖）→ 计算积分（幂等：按 clientOperationId 当日去重）→ 调度延迟的知识画像重算。ReviewPage 只调用该用例。
- **Rationale**: 竞态根因是页面层 fire-and-forget 编排，串行化+单次终态写入即可消除覆盖，无需 SQLite 跨表事务的复杂性；RDB 事务 API（beginTransaction/commit）保留给同表多行强一致场景（删除错题+日志）。
- **Alternatives considered**: DB 层新增跨表事务方法（跨层职责、参数爆炸，弃）。

**D5 提醒幂等：getValidReminders 清理 + Preference 持久化 reminderId**
- **Decision**: ReminderService 新增启动同步流程：`getValidReminders()` 查询本应用有效提醒并全部取消 → 按设置重新发布 → 新 reminderId 写入 Preferences。发布/取消失败如实返回；ReminderSettingPage 保存前经 atManager.requestPermissionsFromUser 申请权限，被拒过一次（不再弹窗）时引导跳系统设置。
- **Rationale**: 官方文档确认 user_grant 权限必须运行时申请、拒绝一次后不再弹窗；以"启动清光重建"实现幂等最简单可靠。
- **Alternatives considered**: 仅持久化 reminderId（进程数据损坏/多设备恢复时仍会泄漏，清光重建更稳）。

**D6 备份格式：@ohos.zlib zip 包（backup.json + images/ 目录）**
- **Decision**: 导出产物为单个 zip：内含 backup.json（app/version/student/mistakes/reviewLogs/settings 元数据）与 images/ 目录（按 mistakeId 命名的图片文件）。导出流程：临时目录组织文件 → zlib.compressFile 打包 → 拷贝到用户目录；导入逆向（decompressFile 到沙箱临时目录 → 校验 app 标识/版本 → 解析 → 事务写入 → 图片落 filesDir/mistakes → 更新 imageUrl）。解析预览走 taskpool 异步 + 10MB 上限。
- **Rationale**: 官方 zlib（API 7+）提供 compressFile/decompressFile，成熟稳定；图片二进制随迁满足 FR-013；单文件便于用户分享保存。
- **Alternatives considered**: ① base64 内嵌 JSON（实现最简但体积 +33%、大备份内存峰值高，作为 zlib 不可用时的降级方案保留）；② API 26 archive 归档模块（目标 SDK 兼容性未确认，不冒进）。

**D7 深色模式：颜色全量资源化（base + dark 限定词目录），AppColors 改为资源引用**
- **Decision**: 新建 resources/base/element/color.json（亮色）与 resources/dark/element/color.json（深色）；Constants.ets 的 AppColors 常量改为 `$r('app.color.*')` 资源引用（保持调用点 API 不变，页面代码从 AppColors.PRIMARY 取值即自动适配）；EntryAbility 保持跟随系统并处理 onConfigurationUpdate；全部页面/组件硬编码 hex 清零收敛至 AppColors。若模块级常量持有 $r 在验证中出现问题，降级为静态方法获取。
- **Rationale**: 调用点零改动即可完成资源化迁移（改动收敛在 Constants 与资源文件）；HarmonyOS 限定词目录是深色适配的标准机制。
- **Alternatives considered**: 页面直接散写 $r（50 处调用点全改，风险高，弃）。

**D8 列表性能：LazyForEach + IDataSource + DB 分页**
- **Decision**: DatabaseHelper.queryMistakes 增加 LIMIT/OFFSET 参数；MistakesPage 用自定义 IDataSource 数据源（键值用 mistake.id），滚动触底加载下一页；统计口径全部改 SQL 聚合（COUNT/SUM/GROUP BY）。
- **Rationale**: 官方 FAQ 明确 LazyForEach 键值与数据变更通知（notifyDataAdd/Reload）的正确用法；聚合下推 SQLite 消除四页重复全量加载。
- **Alternatives considered**: 仅 LazyForEach 不分页（@State 全量数组仍在，内存不降，弃）。

**D9 数据库版本化迁移：PRAGMA user_version，基线版本 2**
- **Decision**: getRdbStore 后读 `PRAGMA user_version`：0=存量库（执行现有全部 ALTER 的幂等合集+索引，成功后置 2）；新建库直接按最新结构建表+索引并置 2。迁移过程包错误上报（DbResult），任一步失败记录致命日志并提示。索引以 `CREATE INDEX IF NOT EXISTS` 建于两路径。
- **Rationale**: SQLite PRAGMA 走 executeSql 透传即可；现有 44 条 ALTER 的"靠报错跳过"模式在迁移期内仍需兼容存量库，故合集保持幂等。
- **Alternatives considered**: 破坏性重建（丢用户数据，不可接受）。

**D10 混淆开启策略**
- **Decision**: entry/build-profile.json5 的 release obfuscation.enable 置 true，沿用已有 obfuscation-rules.txt；启用后构建+全功能回归验证（重点关注 JSON 手工映射、RDB ValuesBucket 字段名）。
- **Rationale**: 代码内无反射依赖属性名的逻辑（RDB/JSON 均显式字段映射），混淆风险可控。
- **Alternatives considered**: 保持关闭（密钥已出库但业务逻辑仍裸露，且 spec FR-003 明确要求开启）。

**D11 死代码处置分级**
- **Decision**: 直接删除：未使用导入、死状态（isConfirmed/reviewMode/isLoaded/importPath）、未用的 RouteParams 类型、resetMastery、三元同分支等；实现收口：SCIENCE 学科检测、STREAK 积分、dailyLimit/科目开关、ImageQuality 低置信度提醒；暂保留并注释：ImageQualityIssue 中暂无生产方的枚举值（TILT/GLARE 属于 roadmap，保留枚举但确保不被误判为"功能已实现"）——若 string.json/页面有对应 UI 则同步清理。
- **Rationale**: spec FR-026 要求"实现或移除"二选一；枚举值删除可能破坏已入库数据的反序列化兼容（TEXT 列），保留枚举+清理 UI 引用是安全解。
- **Alternatives considered**: 一刀切删除全部"无生产方"枚举（存量 TEXT 数据兼容风险，弃）。

## Data Model

### 数据库（RDB）结构变更

**版本管理**：新增 `PRAGMA user_version` 版本跟踪，基线 v2（v1 视为当前无版本存量结构，v2=完整结构+索引）。

**新增索引（全部 IF NOT EXISTS）**：
- `idx_mistake_next_review` ON mistake(nextReviewDate)
- `idx_mistake_student` ON mistake(studentId)
- `idx_review_log_mistake` ON review_log(mistakeId)
- `idx_review_log_student_time` ON review_log(studentId, occurredAt)（streak 按日聚合用）
- `idx_points_log_student` ON points_log(studentId)
- `idx_analytics_event_type` ON analytics_event(eventType)
- `idx_knowledge_profile_student` ON knowledge_profile(studentId)
- `idx_redemption_student` ON redemption(studentId)

**行为变更（不改列）**：
- `updateMistake` 的更新集合补充 `imageUrl`（FR-027）
- `queryTodayReviewMistakes` 增加参数：studentId 过滤 + dailyLimit 截断 + 科目开关过滤（FR-012）
- `queryMistakes` 增加 LIMIT/OFFSET（FR-019）；新增 `queryMistakeStats`（按状态 GROUP BY 计数）、`queryPointsSummary` 改 SQL SUM（FR-019）
- 新增 `queryActiveDays(studentId)`（DISTINCT 活动日，streak 用）
- 删除错题与 review_log 同事务；种子数据批量事务；upsert（画像/提醒设置）事务化
- 表结构（列定义）本次不变——逗号分隔 knowledgeTagIds 的范式问题记录为已知债，不在本次范围（涉及全量数据迁移，风险收益比不匹配）

### 本地配置文件

**rawfile/ai_config.json**（gitignored）：`{ apiKey: string, model: string, baseUrl: string }`；模板 ai_config.example.json 含填写说明。缺失/空 apiKey 时 AiService 返回明确配置缺失错误（带指引文案），不崩溃。

### Preferences 新增键

- `reminder.publishedId`（string）：最近发布的 reminderId，配合启动清光重建使用。

### 备份包格式（BackupBundle）

zip 根：`manifest.json`（app:"tixing"、version、exportedAt、学生信息）+ `data.json`（mistakes[]、reviewLogs[]、settings）+ `images/{mistakeId}.jpg`。导入校验 manifest.app 与 version 兼容性；预览解析上限 10MB。

## Contracts & Interfaces

（签名级契约；均遵循 ArkTS 约束：禁 any/unknown、静态方法禁 this、禁索引访问类型）

**common/DbResult.ets**
- `class DbResult { static ok(): DbResult; static fail(op: string, reason: string): DbResult; readonly success: boolean; readonly op: string; readonly reason: string }`

**common/AiConfig.ets**
- `class AiConfig { static async load(): Promise<void>; static get apiKey(): string; static get model(): string; static get configured(): boolean }`

**repository/DatabaseHelper.ets（关键变更面）**
- `init(context: Context): Promise<DbResult>`（幂等，缓存就绪 Promise）
- `whenReady(): Promise<void>`
- 全部写操作返回 `Promise<DbResult>`：insertMistake / updateMistake（含 imageUrl）/ deleteMistake（事务）/ insertPointsLog / insertReviewLog / saveReminderSettings / upsertKnowledgeProfile / seedKnowledgeTags（事务）等
- `queryTodayReviewMistakes(studentId: string, limit: number, subjects: Subject[]): Promise<Mistake[]>`
- `queryMistakes(filter: MistakeFilter, offset: number, limit: number): Promise<Mistake[]>`（MistakeFilter 为既有筛选条件 + 新增 totalCount 回填）
- `queryMistakeStats(studentId: string): Promise<MistakeStats>`（total/mastered/reviewing/unmastered）
- `queryPointsSummary(studentId: string): Promise<PointsSummary>`（SQL SUM + streakDays 真实值）
- `queryActiveDays(studentId: string): Promise<string[]>`（ISO 日期串）
- 单例收敛：constructor 私有化，保留导出常量 dbHelper

**usecases/ReviewSubmitter.ets**
- `class ReviewSubmitter { static async submit(mistake: Mistake, log: ReviewLog): Promise<ReviewSubmitResult> }`（ReviewSubmitResult：成功标志 + 获得积分 + 最新状态 + 失败原因；内部串行编排，积分按 clientOperationId 幂等）

**usecases/StreakCalculator.ets**
- `class StreakCalculator { static compute(activeDays: string[]): number; static shouldAwardToday(activeDays: string[], lastStreakAwardDay: string): boolean }`

**services/AiService.ets**
- 密钥来源改为 AiConfig；`recognize/parseQuestion/parseAnalysis` 失败返回带 reason 的错误信息（含响应体摘要）

**services/ReminderService.ets**
- `static async ensurePermission(context: Context): Promise<boolean>`（requestPermissionsFromUser；已拒→返回 false 供页面引导设置）
- `static async syncAndApply(settings: ReminderSettings): Promise<DbResult>`（清光重建+持久化 id）
- 行动按钮配置 wantAgent 拉起应用

**services/MediaService.ets**
- `persistUri` 失败返回 undefined（不降级临时 uri）
- `static cleanupTemp(): Promise<void>`、`static deleteImageIfOwned(path: string): Promise<void>`（删除错题联动）
- 全部资源获取路径 try/finally 释放

**services/DataPortabilityService.ets**
- `static async exportBundle(studentId: string): Promise<string>`（返回 zip 路径；失败 throw）
- `static async parseBundlePreview(path: string): Promise<BundlePreview>`（taskpool 异步 + 上限校验 + manifest 校验）
- `static async importBundle(preview: BundlePreview): Promise<DbResult>`（恢复错题+日志（去重）+图片+设置）

**components/BasicWidgets.ets**
- `FilterChip(text, selected, onTap)`、`PrimaryButton(text, enabled, onTap)`、`AppCard`（默认卡片容器）、`SectionCard(title)`、`EmptyBlock(msg)`——统一走资源色，触摸目标 ≥44vp，含 accessibilityText

**components/MistakeCard.ets**
- `MistakeCard(mistake, onClick)`：两级标题截断 + 科目/状态标签 + 64vp 降采样缩略图（占位+alt）

**components/GradientHeader.ets**
- `GradientHeader(title, subtitle, badge?): ForwardedSlots`——渐变头图 + 状态栏避让高度内聚（SystemBarHelper 结果缓存）

**components/CaptureSteps.ets**
- 四个步骤子组件（SourceSelect / RegionSelect / OcrConfirm / ResultView），通过回调与 CapturePage 交互，各自持有步骤内状态；CapturePage 保留流程编排与持久化

**页面契约变更（代表性）**
- ReviewPage：提交走 ReviewSubmitter；`onBackPress()` 有进度时弹确认；画像重算移至会话结束
- MistakesPage：删除前 AlertDialog 确认；列表 LazyForEach+触底分页
- ReminderSettingPage：时间段点击弹 TimePicker；保存前 ensurePermission
- DataManagementPage：parseBundlePreview 全程 busy；失败如实展示
- Index：await init（whenReady）后再加载 Tab；失败 Toast+日志

**构建/配置契约**
- .gitignore 追加：`/Key/`、`/.cache/`、`.DS_Store`、`/App截图/`、`entry/src/main/resources/rawfile/ai_config.json`；`git rm --cached` 移除已追踪的 .cache 产物
- 根 build-profile.json5 签名密码出库（本地文件保留，仓库不含明文）
- entry/build-profile.json5：release obfuscation.enable=true
- module.json5：INTERNET 补 reason（$string:reason_internet）与 usedScene
