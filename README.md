# MiriaGo

MiriaGo 是一个使用 Flutter 开发的开源跨平台应用，用于规划动漫圣地巡礼、从 Anitabi 导入点位、在现场拍摄时对照参考图，并整理巡礼记录与对比图。

当前主要面向 Android，Web 版本用于开发预览。

## 功能

- 多计划管理：创建、切换、重命名和导出巡礼计划。
- 作品管理：通过 Bangumi 搜索添加作品，也支持手动添加作品。
- Anitabi 点位导入：在作品地图上查看点位、缩略图和详情，并按需加入计划。
- 地图与定位：使用 OpenStreetMap 地图显示计划点位，导航交给外部地图应用。
- 点位管理：排序、筛选、批量完成、批量删除、缓存参考图。
- 拍摄参考：支持叠影参考、上下参考、相册导入和拍摄记录确认。
- 巡礼记录：按作品查看记录，支持筛选、搜索、详情查看和删除。
- 自动调色：根据参考图生成调色参数，用强度滑块控制应用比例。
- 对比图导出：导出参考图与巡礼图的分享图，支持主题、元数据和巡礼者名称。
- 计划导入/导出：导出计划文件并通过系统分享，支持从其他应用打开导入。

## 截图

截图和演示图后续补充。

## 下载与安装

当前还没有正式 Release。开发构建出的 Android release APK 位置为：

```text
build/app/outputs/flutter-apk/app-release.apk
```

如果仓库启用 GitHub Actions，可以在 GitHub Release 页面下载自动构建的 APK。

## 开发环境

需要安装：

- Flutter SDK
- Android Studio 或 Android SDK
- JDK
- 可选：已连接的 Android 设备

初始化依赖：

```bash
flutter pub get
```

检查代码：

```bash
flutter analyze --no-pub
flutter test --no-pub
```

构建 Android release APK：

```bash
flutter build apk --release --no-pub
```

构建 Web 预览：

```bash
flutter build web --no-pub
python3 -m http.server 8080 --directory build/web
```

安装到已连接 Android 设备：

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 第三方服务与数据

本项目代码使用 MIT License 开源，但应用中显示或访问的第三方数据不属于本项目。

- 地图瓦片和地图数据来自 OpenStreetMap。使用时应保留 `OpenStreetMap contributors` 署名，并遵守 OpenStreetMap 官方瓦片使用政策。
- 作品搜索使用 Bangumi API。非浏览器 API 请求需要设置清晰的 User-Agent，当前格式包含开发者 ID、应用名称、版本号和项目主页。
- 巡礼点位和参考图来自 Anitabi。点位、截图、图片和相关元数据的版权归原平台、贡献者或权利方所有。本项目只提供客户端访问与用户本地缓存能力，不在仓库中分发这些数据。

当前 Bangumi User-Agent：

```text
bilyhurington/MiriaGo/1.0.0 (https://github.com/bilyhurington/MiriaGo)
```

## 文档

- [使用指南](docs/USAGE.md)
- [GitHub Release 与自动构建](docs/RELEASE.md)

## 开源协议

本项目代码基于 [MIT License](LICENSE) 开源。
