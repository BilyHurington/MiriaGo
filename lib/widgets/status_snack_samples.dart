import 'package:flutter/material.dart';

import 'app_status_banner.dart';

class StatusSnackSample {
  const StatusSnackSample({
    required this.kind,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.progressProcessed,
    this.progressTotal,
    this.footer,
    this.icon,
  });

  final AppStatusBannerKind kind;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final int? progressProcessed;
  final int? progressTotal;
  final String? footer;
  final IconData? icon;

  bool get hasProgress =>
      progressProcessed != null && progressTotal != null && progressTotal! > 0;
}

const statusSnackDebugSamples = <StatusSnackSample>[
  StatusSnackSample(
    kind: AppStatusBannerKind.running,
    title: '正在导出...',
    icon: Icons.ios_share_outlined,
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.running,
    title: '已取消导出',
    icon: Icons.cancel_outlined,
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.running,
    title: '正在缓存参考图...',
    progressProcessed: 8,
    progressTotal: 18,
    footer: '提示：缓存过程中请保持网络连接，避免切换页面或锁屏。',
    icon: Icons.cached_outlined,
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.running,
    title: '正在保存记录，请稍候。',
    icon: Icons.save_outlined,
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.running,
    title: '正在替换参考图...',
    icon: Icons.swap_horiz_outlined,
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.running,
    title: '正在读取参考图比例，请稍后拍摄。',
    icon: Icons.aspect_ratio_outlined,
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.running,
    title: '正在清除缓存并重新加载 Anitabi 点位...',
    icon: Icons.cleaning_services_outlined,
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.running,
    title: '正在导入 12 个点位...',
    icon: Icons.add_location_alt_outlined,
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.running,
    title: '正在缓存缩略图 8/12，成功 7',
    icon: Icons.photo_library_outlined,
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.running,
    title: '已取消保存',
    icon: Icons.cancel_outlined,
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.success,
    title: '参考图缓存完成',
    subtitle: '18 / 18 张成功，已保存到本地',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.success,
    title: '数据包已导出',
    subtitle: '已保存到本地',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.success,
    title: 'My Maps CSV 已导出',
    subtitle: '已通过系统分享送出',
  ),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已恢复初始设置'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '计划备忘录已保存'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已复制「宇治一日」'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已添加「声之形」。'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已填入坐标。'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已分配 6 个点位'),
  StatusSnackSample(
    kind: AppStatusBannerKind.success,
    title: '已将 3 个点位分配到「宇治站附近」',
  ),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已替换参考图'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已保存到相册'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '图片已保存'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已还原为原图'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已生成自动调色参数'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已保存调色结果'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '已导入计划「宇治一日」'),
  StatusSnackSample(kind: AppStatusBannerKind.success, title: '记录已保存，并备份到相册'),
  StatusSnackSample(
    kind: AppStatusBannerKind.success,
    title: '已保存并标记完成，下一个：平等院',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '参考图缓存完成',
    subtitle: '14 / 18 张成功 · 4 张失败',
    actionLabel: '重试失败',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '数据包已导出',
    subtitle: '3 张完整参考图下载失败，2 张巡礼照片缺失',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '已导入计划「宇治一日」，部分资源未恢复',
  ),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '当前计划没有需要缓存的参考图'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '当前计划还没有点位。'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '当前环境无法编辑点位。'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '至少需要保留一个计划'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '当前距离内没有可分配点位'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '请先完成片区分配'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '请先创建片区'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '框选范围内没有未分组点位'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '框选范围内没有可添加点位'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '无法读取剪贴板。'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '剪贴板中没有有效坐标。'),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '无法读取剪贴板，请手动粘贴 Anitabi 链接。',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '剪贴板中没有可用的 Anitabi 链接。',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '清除缓存功能尚未接入，仅展示界面。',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '巡礼图不可用，无法导出对比图片。',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '当前平台暂不支持保存导出偏好。',
  ),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '没有可用于自动调色的参考图'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '请先自动匹配色调'),
  StatusSnackSample(kind: AppStatusBannerKind.warning, title: '链接格式不正确'),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '手动添加的作品没有 Bangumi ID，无法从 Anitabi 地图导入点位。',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '点位已导入，但整理流程打开失败，可以稍后在计划中调整片区。',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '定位获取失败，本次照片不记录定位。',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.warning,
    title: '已导入 12 个点位，缩略图缓存 8/12，其余稍后会自动补齐。',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.error,
    title: '参考图缓存失败',
    subtitle: '0 / 18 张成功 · 18 张失败',
    actionLabel: '重试全部',
  ),
  StatusSnackSample(
    kind: AppStatusBannerKind.error,
    title: '导出失败',
    subtitle: '请稍后重试',
  ),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '导入文件读取失败'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '计划文件导入失败'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '导入失败'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '定位失败，请检查权限和定位服务。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '片区创建失败，请稍后重试。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '点位保存失败，请稍后重试。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '作品添加失败，请稍后重试。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '参考图读取失败，请重新选择。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '参考图替换失败，请稍后重试。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '计划备忘录保存失败'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '切换计划失败，请稍后重试。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '复制计划失败，请稍后重试。'),
  StatusSnackSample(
    kind: AppStatusBannerKind.error,
    title: '保存计划顺序失败，已恢复原来的顺序。',
  ),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '作品删除失败'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '照片导入失败，请重新选择。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '图片读取失败'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '保存失败，请稍后重试。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '巡礼图读取失败'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '自动调色失败'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '无法打开链接'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '无法打开 Google 地图。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '点位分配失败，请稍后重试。'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '最近分配失败'),
  StatusSnackSample(kind: AppStatusBannerKind.error, title: '框选分配失败'),
];
