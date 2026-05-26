# GitHub Release 与自动构建

GitHub Release 可以用来发布 APK、版本说明和源码压缩包。用户不需要自己 clone 项目，就可以在 Release 页面下载安装包。

## 推荐发布方式

建议使用以下流程：

1. 在本地完成开发和测试。
2. 更新 `pubspec.yaml` 中的版本号，例如 `1.0.1+2`。
3. 提交代码并推送到 GitHub。
4. 创建一个 Git tag，例如 `v1.0.1`。
5. 推送 tag。
6. GitHub Actions 自动构建 Android release APK。
7. Actions 自动创建 GitHub Release，并上传 APK。

## 手动创建 Release

如果暂时不使用自动构建，也可以手动发布：

1. 本地构建：

   ```bash
   flutter build apk --release --no-pub
   ```

2. 打开 GitHub 仓库页面。
3. 进入 Releases。
4. 点击 Draft a new release。
5. 创建 tag，例如 `v1.0.0`。
6. 填写标题和更新说明。
7. 上传 APK：

   ```text
   build/app/outputs/flutter-apk/app-release.apk
   ```

8. 发布 Release。

## 自动构建是否可行

可以。GitHub Actions 可以在每次推送 tag 时自动执行：

- 安装 Flutter
- 拉取依赖
- 运行 `flutter analyze`
- 运行 `flutter test`
- 构建 Android release APK
- 创建 GitHub Release
- 上传 APK

## 自动构建的注意事项

### 1. Android 签名

如果只是测试分发，可以先使用 Flutter/Android 默认 release 构建产物。但正式公开分发时，建议配置自己的签名证书。

正式签名通常需要：

- keystore 文件
- keystore 密码
- key alias
- key 密码

这些不应该提交到仓库，应该保存到 GitHub Actions Secrets。

### 2. API Token

公开仓库不建议硬编码个人 Bangumi API Token。

更稳妥的方案：

- 本地开发使用 `--dart-define`
- GitHub Actions 使用 Repository Secrets 注入
- App 内提供用户自行配置 Token 的设置项

示例：

```bash
flutter build apk --release --dart-define=BANGUMI_API_TOKEN=xxxx
```

### 3. Release APK 文件名

建议发布时重命名 APK，避免所有版本都叫 `app-release.apk`。

示例：

```text
seichi-junrei-helper-v1.0.0-android.apk
```

## 当前仓库的自动构建

仓库已经包含 GitHub Actions 工作流：

```text
.github/workflows/release.yml
```

它支持两种触发方式：

- 手动触发：在 GitHub Actions 页面选择 `Build Android Release`，点击 Run workflow。构建完成后可以在 workflow run 的 Artifacts 中下载 APK。
- 推送 tag：推送 `v*` 格式的 tag，例如 `v1.0.0`。构建完成后会自动创建 GitHub Release，并上传 APK。

发布一个新版本的命令示例：

```bash
git tag v1.0.0
git push origin v1.0.0
```

当前自动构建使用未额外配置签名的 release APK。后续正式分发时，建议再加入 Android keystore 签名配置。
