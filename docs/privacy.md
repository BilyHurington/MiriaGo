# MiriaGo Privacy Policy

Last updated: October 1, 2026

MiriaGo is an app for anime pilgrimage planning, location reference, camera-assisted shooting, visit record management, and local data import/export.

This Privacy Policy explains what data MiriaGo uses, where that data is stored, and how permissions are used.

## Summary

MiriaGo does not operate a user account system and does not intentionally collect, sell, or share personal data with an app-operated server.

Most app data, including plans, pilgrimage points, visit records, photos, cached reference images, settings, and imported/exported data packages, is stored locally on your device or in the local app data folder.

## Data Stored Locally

MiriaGo may store the following data locally:

- Pilgrimage plans, works, groups, points, map coordinates, and completion status.
- Visit records, including capture time, related point information, photo paths, reference modes, and color adjustment settings.
- Photos you take or import in the app.
- Reference images or cached thumbnails used for comparison.
- App settings such as theme and display preferences.
- Imported or exported `.sjhplan` data packages and related resources when you choose to create, restore, or share them.

Local storage does not mean every feature is offline. Features described below can send selected coordinates or resource requests to third-party services. Copies saved to a system photo library or another location may also be handled by that system's backup or synchronization settings.

## Permissions

MiriaGo may request the following system permissions:

- Camera: used to take pilgrimage photos and compare them with reference images.
- Photo Library / Photos: used to import images, choose reference photos, and save visit photos or exported comparison images.
- Location: used to show your current position on the pilgrimage map and help you navigate or record locations.
- Microphone: MiriaGo does not record sound. The system requires a microphone description because the camera component also supports video recording; MiriaGo only takes photos.
- Files / Documents: used when you import or export MiriaGo plan packages, CSV files, or related resources.

You can manage these permissions in your device settings.

## Photo Location And Metadata

The default photo-location setting asks you to choose a strategy on first capture. Depending on your selection, MiriaGo can use a recent location or request a location for the photo and write GPS metadata locally. This metadata can include latitude, longitude, a location timestamp, altitude, and accuracy when available. The app also reads available photo capture-time metadata when importing a photo.

Skipping location, disabling photo location, or failing to obtain a location means that no new location is added through that step. It does not strip GPS or other metadata already present in the original photo. Original photos saved to the photo library, exported, or shared may retain that information; review it before transferring those files.

## Third-Party Services And Data Sources

MiriaGo may access third-party services or public data sources when you use related features:

- Map tiles, map styles, and map attribution may be loaded from OpenFreeMap, OpenStreetMap, or a custom map service URL that you configure.
- Reference images may be loaded from Anitabi image hosts, including the default image host or an alternate image host selected in settings.
- Anime pilgrimage point/reference data may be imported from user-selected or supported sources such as Anitabi.
- Work metadata may be searched or imported from Bangumi-related APIs when you choose to use those features.
- In-app walking route previews and navigation use a Valhalla routing service, by default `https://valhalla1.openstreetmap.de`, or the service address you configure. Route requests send the start, destination, and intermediate stop coordinates. Rerouting can send your current position and the remaining stops. The connection-test button requests service status without sending route coordinates.
- To keep the Anitabi service addresses current, MiriaGo can read a small configuration file published in the MiriaGo GitHub repository, from `raw.githubusercontent.com` or the jsDelivr CDN (`cdn.jsdelivr.net`, `fastly.jsdelivr.net`). This happens when Anitabi requests fail (at most 3 counted checks a day; while no source is reachable, at most one attempt every 10 minutes) or when you choose "立即检查" in settings, and can be switched off there. The request contains no plan or location data.
- "从链接导入" downloads the plan file from the link you enter. For GitHub release or repository links, MiriaGo first asks the GitHub API (`api.github.com`) which files the release contains, then downloads the file you choose from GitHub. Downloads follow the redirects the server answers with (GitHub serves files from `*.githubusercontent.com`), but never to local network addresses. The desktop app performs this download through its own launcher. The link's server receives ordinary network information such as your IP address.
- Links such as the route planner skill guide open GitHub in your browser, where GitHub's own policies apply.
- External navigation can open Google Maps, Apple Maps, Amap, or Baidu Maps. MiriaGo passes destination coordinates, and for some providers also a destination name. The external app or website then handles navigation under its own settings and permissions.

When these services are used, your device may connect directly to those third parties. Selected map, routing, data, and image services can receive ordinary network information such as your IP address, along with requested tiles, style URLs, image URLs, search terms, or route coordinates as applicable. Custom service addresses change the recipient of the corresponding requests; configuring one does not make those requests private or offline. Some supported service or navigation URLs use HTTP rather than HTTPS. The recipients' own privacy policies and terms apply. MiriaGo does not specify or guarantee their retention periods or subsequent use of this data.

## System Photo Library Copies

On supported mobile platforms, saving a visit record can also copy its photo to the system photo library. The visit-photo backup setting defaults to on, including when some older databases gain this setting during migration; existing saved preferences may differ. Automatic comparison-image saving defaults to off. You can change these settings; successful saving also depends on system permissions and platform support.

These are local photo-library operations, not uploads to a MiriaGo server. However, the system photo library or a chosen file destination may synchronize or back up files to cloud services according to your device, account, and service settings. Deleting an app record does not automatically delete copies already saved or synchronized elsewhere.

## Import, Export, And Sharing

MiriaGo can export plan packages, CSV files, comparison images, and related resources. Exported files may include local plan data, map coordinates, visit records, and photos or cached reference images depending on the options you choose.

MiriaGo does not automatically upload these exports. You control where exported files are saved or shared.

Comparison images are generated locally and may visibly include selected fields such as point name, work title, capture time, coordinates, or a configured pilgrim name. Generation or plan-package export may need to download remote reference images when those resources are not available locally or are requested by the export options. This is a reference-resource request, not an upload of your captured photo, but it means that exporting is not always fully offline.

Importing from a link downloads the file first (see above). The temporary copy is deleted once it has been read; one left behind because the app was closed during an import is deleted the next time you open "从链接导入". When you import a data package, MiriaGo reads the package contents and may restore included images or resources into local app storage.

## Analytics And Advertising

MiriaGo does not include advertising SDKs and does not intentionally collect analytics data through an app-operated backend.

If future versions add diagnostics or analytics, this policy will be updated before those features are used.

## Children's Privacy

MiriaGo is not designed to knowingly collect personal information from children. Because MiriaGo stores app data locally and does not run an account service, users or guardians should manage local photos, location permissions, and exported files according to their own device and family settings.

## Data Deletion

You can delete plans, visit records, and local files from within the app where supported. You can also remove app data by deleting the app or clearing the app data folder on your device.

Exported files that you saved or shared outside the app must be deleted from those locations separately.

## Contact

For privacy questions or requests, please use the GitHub repository issue page:

https://github.com/BilyHurington/MiriaGo/issues

---

# MiriaGo 隐私政策

最后更新：2026 年 10 月 1 日

MiriaGo 是一款用于动漫圣地巡礼计划、地图点位参考、拍摄辅助、巡礼记录整理以及本地数据导入导出的应用。

本隐私政策说明 MiriaGo 会使用哪些数据、数据存储在哪里，以及系统权限的用途。

## 概要

MiriaGo 不提供用户账号系统，也不会主动通过应用自有服务器收集、出售或共享个人数据。

大部分应用数据，包括计划、巡礼点位、巡礼记录、照片、参考图缓存、设置以及导入/导出的数据包，都会保存在你的设备本地或本地应用数据文件夹中。

## 本地存储的数据

MiriaGo 可能会在本地保存以下数据：

- 巡礼计划、作品、片区、点位、地图坐标和完成状态。
- 巡礼记录，包括拍摄时间、关联点位、照片路径、参考模式和调色设置。
- 你在应用内拍摄或导入的照片。
- 用于对照的参考图或缩略图缓存。
- 主题、显示偏好等应用设置。
- 你主动创建、恢复或分享的 `.sjhplan` 数据包及相关资源。

本地存储不代表所有功能都离线运行。下述功能可能将所选坐标或资源请求发送至第三方服务。保存到系统相册或其他位置的副本，也可能受到对应系统备份或同步设置的影响。

## 权限用途

MiriaGo 可能请求以下系统权限：

- 相机：用于拍摄巡礼照片，并与参考图进行对照。
- 照片/相册：用于导入图片、选择参考图，以及保存巡礼照片或导出的对比图。
- 定位：用于在巡礼地图中显示当前位置，并辅助导航或记录地点。
- 麦克风：MiriaGo 拍摄巡礼照片时不会录制声音。此说明仅因相机组件包含录像能力而必须提供，MiriaGo 只拍摄照片。
- 文件/文档：用于导入或导出 MiriaGo 计划包、CSV 文件和相关资源。

你可以在设备系统设置中管理这些权限。

## 照片定位与元数据

照片定位默认在首次拍摄时询问所用策略。根据你的选择，MiriaGo 可以使用近期位置，或为照片请求定位，并在本地写入 GPS 元数据。可写入的信息包括经纬度、定位时间，以及可用时的海拔和精度。导入照片时，应用也会读取可用的拍摄时间元数据。

跳过定位、关闭照片定位或获取定位失败，表示该步骤不添加新的位置，并不会剥离原始照片已有的 GPS 或其他元数据。保存到相册、导出或分享的原始照片可能保留这些信息；转移文件前请检查其内容。

## 第三方服务和数据来源

当你使用相关功能时，MiriaGo 可能会访问第三方服务或公共数据来源：

- 地图瓦片、地图样式和地图署名信息可能来自 OpenFreeMap、OpenStreetMap，或你自行配置的自定义地图服务 URL。
- 参考图可能来自 Anitabi 图片服务，包括默认图片源或你在设置中选择的备用图片源。
- 动漫巡礼点位和参考图数据可能来自你选择或应用支持的数据源，例如 Anitabi。
- 作品元数据可能在你使用相关功能时通过 Bangumi 相关 API 搜索或导入。
- 应用内步行路线预览与导航使用 Valhalla 路线服务，默认地址为 `https://valhalla1.openstreetmap.de`，也可以使用你配置的服务地址。路线请求会发送起点、终点及途经点坐标；重新规划时可能发送当前位置及剩余站点。连接测试按钮仅请求服务状态，不发送路线坐标。
- 为保持 Anitabi 服务地址可用，MiriaGo 可能从 MiriaGo GitHub 仓库读取一个小型配置文件，来源为 `raw.githubusercontent.com` 或 jsDelivr CDN（`cdn.jsdelivr.net`、`fastly.jsdelivr.net`）。这会在 Anitabi 请求失败时（每天最多计 3 次；所有来源都无法连接时，最多每 10 分钟尝试一次）或你在设置中点击“立即检查”时进行，并可在设置中关闭。该请求不包含计划或位置数据。
- “从链接导入”会从你输入的链接下载计划文件。对于 GitHub 发布或仓库链接，MiriaGo 会先向 GitHub API（`api.github.com`）查询该发布包含的文件，再从 GitHub 下载你选择的文件。下载会跟随服务器返回的跳转（GitHub 文件由 `*.githubusercontent.com` 提供），但不会跳转到局域网地址。桌面版通过其启动器完成下载。链接所在服务器可收到 IP 地址等常规网络信息。
- 路线规划 Skill 使用说明等链接会在浏览器中打开 GitHub，适用 GitHub 自身的政策。
- 外部导航可以打开 Google Maps、Apple Maps、高德地图或百度地图。MiriaGo 会传递目的地坐标，部分服务还会收到目的地名称；外部应用或网站随后按其自身设置和权限处理导航。

使用这些服务时，你的设备可能会直接连接到第三方服务。所选地图、路线、数据或图片服务可收到 IP 地址等常规网络信息，以及对应功能请求的瓦片、地图样式 URL、图片 URL、搜索词或路线坐标。自定义服务地址会改变对应请求的接收方，并不意味着请求成为私密或离线操作。部分支持的服务或导航 URL 使用 HTTP 而非 HTTPS。接收方自身的隐私政策和使用条款适用；MiriaGo 不说明或保证其数据留存期限及后续用途。

## 系统相册副本

在支持的移动平台上，保存巡礼记录时也可以将照片复制到系统相册。巡礼照片相册备份设置默认开启，部分旧数据库迁移新增该设置时也是如此；已有的保存偏好可能不同。对比图自动保存默认关闭。你可以修改这些设置，实际保存还取决于系统权限和平台支持。

这些操作是本地相册写入，不是上传到 MiriaGo 服务器。但系统相册或所选文件保存位置可能按你的设备、账号和服务设置，将文件同步或备份到云服务。删除应用内记录不会自动删除已保存或同步到其他位置的副本。

## 导入、导出和分享

MiriaGo 可以导出计划包、CSV 文件、对比图以及相关资源。根据你选择的导出选项，导出的文件可能包含本地计划数据、地图坐标、巡礼记录、照片或参考图缓存。

MiriaGo 不会自动上传这些导出文件。你可以自行控制导出文件保存或分享的位置。

对比图在本地生成，画面可能包含你选择显示的点位名称、作品标题、拍摄时间、坐标或配置的巡礼者名称。生成对比图或导出计划包时，如果所需参考图不在本地，或导出选项要求包含相应资源，可能需要联网下载远端参考图。这是参考资源请求，并非上传你的拍摄照片，但意味着导出并不总是完全离线。

从链接导入时会先下载文件（见上文），读取完成后即删除临时副本；若导入途中关闭了 App，残留的副本会在下次打开“从链接导入”时删除。当你导入数据包时，MiriaGo 会读取包内内容，并可能将其中包含的图片或资源恢复到本地应用存储中。

## 分析和广告

MiriaGo 不包含广告 SDK，也不会通过应用自有后端主动收集分析数据。

如果未来版本加入诊断或分析功能，本政策会在相关功能启用前更新。

## 儿童隐私

MiriaGo 不以主动收集儿童个人信息为目的。由于 MiriaGo 主要在本地保存应用数据，用户或监护人应根据自己的设备和家庭设置管理本地照片、定位权限以及导出的文件。

## 数据删除

你可以在应用支持的范围内删除计划、巡礼记录和本地文件。你也可以通过删除应用或清除应用数据文件夹来移除应用数据。

如果你已将文件导出或分享到应用外部位置，需要在对应位置单独删除。

## 联系方式

如有隐私相关问题或请求，请使用 GitHub 仓库 issue 页面：

https://github.com/BilyHurington/MiriaGo/issues
