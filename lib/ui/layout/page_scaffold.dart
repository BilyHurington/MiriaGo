import 'package:flutter/material.dart';

import '../design/theme.dart';
import 'window_class.dart';

/// Standard page frame: app bar, actions, optional bottom bar, canvas
/// background and consistent gutters.
///
/// Two ways to provide content:
///
/// * [body] — any widget. A regular app bar is used.
/// * [slivers] — scroll content. On compact windows (not short) the app bar
///   uses the large-title style and collapses while scrolling; set
///   [padSlivers] to add the window gutter around every sliver.
///
/// ```dart
/// MiriaPageScaffold(
///   title: '作品',
///   actions: [MiriaIconButton(icon: Symbols.add_rounded, tooltip: '添加作品', onPressed: ...)],
///   slivers: [SliverList.list(children: rows)],
/// )
/// ```
class MiriaPageScaffold extends StatelessWidget {
  const MiriaPageScaffold({
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.automaticallyImplyLeading = true,
    this.body,
    this.slivers,
    this.padSlivers = false,
    this.bottomBar,
    this.floatingActionButton,
    this.largeTitle = true,
    this.appBarBottom,
    this.backgroundColor,
    this.scrollController,
    this.resizeToAvoidBottomInset = true,
    super.key,
  }) : assert(
         (body == null) != (slivers == null),
         'Provide exactly one of body or slivers.',
       );

  final String title;

  /// Small line under the title (only in the regular app bar).
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? body;
  final List<Widget>? slivers;

  /// Wraps every sliver in the window gutter.
  final bool padSlivers;

  /// Pinned bar at the bottom (primary actions). Gets a surface background,
  /// top hairline, gutters and the bottom safe area.
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  /// Use the collapsing large title on compact windows (sliver mode only).
  final bool largeTitle;
  final PreferredSizeWidget? appBarBottom;

  /// Defaults to `colors.canvas`.
  final Color? backgroundColor;
  final ScrollController? scrollController;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final layout = context.layout;
    final titleWidget = _Title(title: title, subtitle: subtitle);
    final trailing = [...actions, SizedBox(width: layout.gutter - 8)];

    Widget content;
    PreferredSizeWidget? appBar;
    if (slivers != null) {
      final useLarge =
          largeTitle && layout.isCompact && !layout.isShort && subtitle == null;
      final sliverBar = useLarge
          ? SliverAppBar.medium(
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              leading: leading,
              automaticallyImplyLeading: automaticallyImplyLeading,
              actions: trailing,
              bottom: appBarBottom,
              backgroundColor: backgroundColor ?? c.canvas,
              surfaceTintColor: Colors.transparent,
              titleSpacing: layout.gutter,
            )
          : SliverAppBar(
              pinned: true,
              title: titleWidget,
              leading: leading,
              automaticallyImplyLeading: automaticallyImplyLeading,
              actions: trailing,
              bottom: appBarBottom,
              backgroundColor: backgroundColor ?? c.canvas,
              surfaceTintColor: Colors.transparent,
              titleSpacing: leading == null ? layout.gutter : 0,
            );
      content = CustomScrollView(
        controller: scrollController,
        slivers: [
          sliverBar,
          for (final sliver in slivers!)
            padSlivers
                ? SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: layout.gutter),
                    sliver: sliver,
                  )
                : sliver,
          SliverPadding(padding: EdgeInsets.only(bottom: Space.x6)),
        ],
      );
    } else {
      appBar = AppBar(
        title: titleWidget,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: trailing,
        bottom: appBarBottom,
        backgroundColor: backgroundColor ?? c.canvas,
        titleSpacing: leading == null && !_canPop(context) ? layout.gutter : 0,
      );
      content = body!;
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? c.canvas,
      appBar: appBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      body: content,
      bottomNavigationBar: bottomBar == null
          ? null
          : _BottomBar(child: bottomBar!),
    );
  }

  bool _canPop(BuildContext context) =>
      automaticallyImplyLeading && (ModalRoute.of(context)?.canPop ?? false);
}

class _Title extends StatelessWidget {
  const _Title({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    if (subtitle == null) {
      return Text(title, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium,
        ),
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.caption,
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gutter = context.layout.gutter;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: Space.x2),
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, Space.x3, gutter, Space.x1),
          // Keep expanding children (Align, ContentColumn…) from taking the
          // whole screen height.
          child: Align(heightFactor: 1, child: child),
        ),
      ),
    );
  }
}
