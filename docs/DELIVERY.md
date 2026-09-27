# MiriaGo Next · 交付说明

> 2026-09-27 · 本文件记录这次 UI 重写交付时的状态：做了什么、怎么运行、验证到什么程度、还有什么没做。
> 设计见 [`DESIGN.md`](DESIGN.md)，旧功能对照见 [`FEATURE_CHECKLIST.md`](FEATURE_CHECKLIST.md)，开发约定见 [`ENGINEERING.md`](ENGINEERING.md)。

## 1. 设计问题的最终决定

`DESIGN.md` §14 的待确认问题，全部按文档推荐执行（用户 2026-09-27 确认「全部按你决定比较合适的来做」）：

| # | 问题 | 决定 |
|---|---|---|
| 1 | 技术栈 | 继续 Flutter |
| 2 | 一级入口 | 计划 / 巡礼 / 记录 / 设置 |
| 3 | 行为变更 Δ1–Δ16 | 全部采纳 |
| 4 | 视觉 | 暖纸白 + 青绿 + 向日葵黄；主题色保留经典 / 深邃蓝 / 樱花粉 / 石墨黑 / 自定义 |
| 5 | 图标 | Material Symbols Rounded |
| 6 | 小窗参考模式 | 不做 |
| 7 | 定位 | 替换现有 App：包名、应用 ID、数据库、通道名保持不变，可以原地升级 |
| 8 | Git | `MiriaGo-Next` 本地仓库，按阶段提交，未推送，提交信息不含 AI 署名 |
| 9 | P2 项 | 大部分已做，见 §4 |

**一处偏离设计**：Δ17「文案集中到 ARB」没有做。七个子 agent 并行开发时，共用一个 ARB 文件会频繁冲突，所以字符串仍写在代码里，与旧版一致。以后可以单独做一次提取。

## 2. 怎么运行

```bash
flutter pub get
flutter build web --release --no-pub
npm run preview:web
```

浏览器打开 <http://127.0.0.1:8792>。普通 Web 预览使用示例数据：1 个计划、7 个片区、27 个点位、15 条记录。

| 地址 | 作用 |
|---|---|
| `/?seed=empty#/plan` | 空计划：检查引导和空状态 |
| `/?seed=stress#/plan/organize` | 600 个点位、40 个片区、300 条记录：压力测试 |
| `/?seed=many-plans#/plan` | 20 个计划：检查计划切换器 |
| `/?lab=1#/go` | 布局实验室：同屏预览手机、平板、桌面，可切换深色和字号，可加 `&route=/records` |
| `/#/_lab/components` | 组件画廊（不进入 Tauri 桌面版） |
| `/#/_lab/map` | 地图组件画廊（不进入 Tauri 桌面版） |

其他常用命令：

```bash
flutter analyze --no-pub
flutter test --no-pub
npm run desktop:dev
```

最后一条是 Tauri 桌面版，需要先 `npm install`。

**Android release 构建**：需要把旧仓库的 `android/key.properties` 和 release keystore 自行复制过来。这两个文件被 git 忽略，没有复制到新仓库，这是有意为之。

## 3. 交付内容

- **后端**：从旧仓库 `849fd9a` 原样导入，路径不变。同步方法见 [`BACKEND_SYNC.md`](BACKEND_SYNC.md)。
- **用例层** `lib/application/`：把旧页面里的业务流程逐行搬出，包括保存记录的提交协议、拍摄管线、Anitabi 导入、点位保存、片区批量操作与最近分配算法、导入导出、调色、对比图导出、应用内导航状态机、连接测试和缓存清理。
- **核心层**：
  - `PlanSession`：当前计划的唯一数据源，所有面板实时同步。
  - `PlansStore`、`SettingsStore`、`ReferenceCacheCenter`。
- **设计系统**：
  - 设计 token 和主题（浅色 / 深色，主题色由 HCT 色彩空间生成，保证对比度）。
  - 约 40 个组件，API 见 [`COMPONENTS_API.md`](COMPONENTS_API.md)。
  - 布局原语和自适应弹层。
- **地图基础层**：PlanMap、标记、聚合、片区外壳、框选、中心准星选点、地图 + 吸附面板布局。API 见 [`MAP_API.md`](MAP_API.md)。
- **应用壳**：
  - 按窗口大小切换导航：底栏、侧轨、侧边栏（可折叠）。
  - 后台缓存任务常驻指示器。
  - 全局提示（窄屏在底部，宽屏在右上角）。
  - 记住上次使用的标签。
- **功能页面**：约 40 个页面和弹层，覆盖 `FEATURE_CHECKLIST.md` 的 A–K 各节。

## 4. 验证情况

**自动化测试**
- `flutter analyze`：无问题。
- `flutter test`：全部通过，最终数字见 §6。
  - 旧仓库的逻辑测试 568 个，原样保留并通过。
  - 新增测试包括：组件、地图、各功能页面、用例层；关键页面在 320×568（字号 2.0）、844×390、820×1180、1440×900 等尺寸下的无溢出检查。

**人工检查**
- 在浏览器里查看了 Web 预览：手机、手机横屏、平板、桌面四种尺寸；浅色和深色；巡礼、计划、片区与点位、记录（列表-详情）、设置（双栏）、Anitabi 导入（读取真实数据）、相机的 Web 降级页面。

**独立审查**
- 三个只读审查 agent 分别检查了：
  - 业务逻辑与旧版是否一致；
  - 功能清单是否全部覆盖；
  - 平台和原生集成。
- 结论：没有 P1（数据丢失）问题。报告的 P2 / P3 问题已经修复，没修复的列在 §5。

**Web 端修复的两个问题**
- MapLibre 底图在 Web 上不显示：已修复（`web/maplibre_resize_nudge.js` + PlanMap 在尺寸变化时触发重绘）。
- Web 上关闭了背景模糊：玻璃效果在 Web 上改为不透明底色，避免遮挡原生地图。

## 5. 未验证 / 已知限制

**需要真机验证**（本次没有在模拟器或真机上运行）：
- 原生相机：CameraX / AVFoundation 预览、权限、旋转时复用同一个 PlatformView、镜头切换、闪光灯、裁切。
- CameraAwesome 回退路径、实体音量键拍照。
- 方向切换：
  - 打开选图器和确认页时临时切回竖屏的规则。
  - iPad 与大屏 Android 会忽略方向锁定。
- 照片 EXIF 时间读取、定位写入、相册保存、系统分享。
- 应用内导航：真实 GPS、罗盘、偏航重算、到达判定，以及 iOS 临时精确定位申请。
- 外部导航：Google Maps 的 Android Intent。
- 从其他 App 打开 `.sjhplan`（`seichi/plan_file` 通道），包括冷启动和运行中两种情况。
- Tauri 桌面：保存对话框、资源恢复、窗口尺寸；Windows WebView2 的鼠标后退键。
- 真机上的键盘与安全区（吸附面板叠在地图上时）。

**已知限制**
- **Web 浏览器后退**：go_router 下浏览器的后退按钮不经过 `PopScope`。只影响普通 Web 预览，原生应用不受影响。
- **Android 预测性返回动画**：manifest 里没有开启 `enableOnBackInvokedCallback`，所以 Android 13–15 上看不到这个动画，行为本身正常。
- **iOS 相机页**：以全屏弹层方式打开，不能侧滑返回，需要点返回按钮。
- **设置读取失败**：会显示启动失败页（有重试按钮），而不是旧版的应用内重试页。
- **没做的界面联动**：
  - 巡礼页和导入页里，鼠标悬停列表行时地图标记不会高亮。
  - 宽屏下「最近分配」仍然是整页，没有做成悬浮在整理页地图上的卡片。
- **Δ17 文案集中到 ARB**：未做（见 §1）。
- **路由与设计 §4.4 的差异**：
  - 点位记录的路径是 `/records/point/:id`。
  - 相机确认页、图片查看器、导入预览用命令式 push 打开，没有对应的 URL。

## 6. 提交记录与最终测试结果

- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub`：**1192 个测试全部通过**（1 个跳过，沿用旧仓库）。
- `flutter build web --release`：成功。Material Symbols 图标字体经 tree-shaking 从 15 MB 降到约 50 KB。
- 提交：`MiriaGo-Next` 本地 `main` 分支，从导入基线开始共约 25 个提交，**未推送**，也没有关联远端。
- 原项目目录 `Seichi-Junrei-Helper` 在整个开发过程中只读，没有修改（开发前写入过一次 `docs/memory/PROJECT_PROGRESS.md` 设计记录，发生在你要求「不要修改原项目」之前）。
