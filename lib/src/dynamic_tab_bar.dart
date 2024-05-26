import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

const double _kTabHeight = 56.0;
const double _kTextAndIconTabHeight = 72.0;

class _TabStyle extends AnimatedWidget {
  const _TabStyle({
    super.key,
    required Animation<double> animation,
    required this.selected,
    required this.labelColor,
    required this.unselectedLabelColor,
    required this.labelStyle,
    required this.unselectedLabelStyle,
    required this.child,
  }) : super(listenable: animation);

  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final bool selected;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);
    final TabBarTheme tabBarTheme = TabBarTheme.of(context);
    final TabBarTheme defaults = themeData.useMaterial3
        ? _TabsDefaultsM3(context)
        : _TabsDefaultsM2(context);
    final Animation<double> animation = listenable as Animation<double>;

    // To enable TextStyle.lerp(style1, style2, value), both styles must have
    // the same value of inherit. Force that to be inherit=true here.
    final TextStyle defaultStyle =
        (labelStyle ?? tabBarTheme.labelStyle ?? defaults.labelStyle!)
            .copyWith(inherit: true);
    final TextStyle defaultUnselectedStyle = (unselectedLabelStyle ??
            tabBarTheme.unselectedLabelStyle ??
            labelStyle ??
            defaults.unselectedLabelStyle!)
        .copyWith(inherit: true);
    final TextStyle textStyle = selected
        ? TextStyle.lerp(defaultStyle, defaultUnselectedStyle, animation.value)!
        : TextStyle.lerp(
            defaultUnselectedStyle, defaultStyle, animation.value)!;

    final Color selectedColor =
        labelColor ?? tabBarTheme.labelColor ?? defaults.labelColor!;
    final Color unselectedColor = unselectedLabelColor ??
        tabBarTheme.unselectedLabelColor ??
        (themeData.useMaterial3
            ? defaults.unselectedLabelColor!
            : selectedColor.withAlpha(0xB2)); // 70% alpha
    final Color color = selected
        ? Color.lerp(selectedColor, unselectedColor, animation.value)!
        : Color.lerp(unselectedColor, selectedColor, animation.value)!;

    return DefaultTextStyle(
      style: textStyle.copyWith(color: color),
      child: IconTheme.merge(
        data: IconThemeData(
          size: 24.0,
          color: color,
        ),
        child: child,
      ),
    );
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter({
    required this.controller,
    required this.indicator,
    required this.indicatorSize,
    required this.tabKeys,
    required _IndicatorPainter? old,
    required this.indicatorPadding,
  }) : super(repaint: controller.animation) {
    if (old != null) {
      saveTabOffsets(old._currentTabOffsets, old._currentTextDirection);
    }
  }

  final TabController controller;
  final Decoration indicator;
  final TabBarIndicatorSize? indicatorSize;
  final EdgeInsetsGeometry indicatorPadding;
  final List<GlobalKey> tabKeys;

  // _currentTabOffsets and _currentTextDirection are set each time TabBar
  // layout is completed. These values can be null when TabBar contains no
  // tabs, since there are nothing to lay out.
  List<double>? _currentTabOffsets;
  TextDirection? _currentTextDirection;

  Rect? _currentRect;
  BoxPainter? _painter;
  bool _needsPaint = false;

  void markNeedsPaint() {
    _needsPaint = true;
  }

  void dispose() {
    _painter?.dispose();
  }

  void saveTabOffsets(List<double>? tabOffsets, TextDirection? textDirection) {
    _currentTabOffsets = tabOffsets;
    _currentTextDirection = textDirection;
  }

  int get maxTabIndex => _currentTabOffsets!.length - 2;

  double centerOf(int tabIndex) {
    assert(_currentTabOffsets != null);
    assert(_currentTabOffsets!.isNotEmpty);
    assert(tabIndex >= 0);
    assert(tabIndex <= maxTabIndex);
    return (_currentTabOffsets![tabIndex] + _currentTabOffsets![tabIndex + 1]) /
        2.0;
  }

  Rect indicatorRect(Size tabBarSize, int tabIndex) {
    assert(_currentTabOffsets != null);
    assert(_currentTextDirection != null);
    assert(_currentTabOffsets!.isNotEmpty);
    assert(tabIndex >= 0);
    assert(tabIndex <= maxTabIndex);
    double tabLeft, tabRight;
    switch (_currentTextDirection!) {
      case TextDirection.rtl:
        tabLeft = _currentTabOffsets![tabIndex + 1];
        tabRight = _currentTabOffsets![tabIndex];
        break;
      case TextDirection.ltr:
        tabLeft = _currentTabOffsets![tabIndex];
        tabRight = _currentTabOffsets![tabIndex + 1];
        break;
    }

    if (indicatorSize == TabBarIndicatorSize.label) {
      final double tabWidth = tabKeys[tabIndex].currentContext!.size!.width;
      final double delta = ((tabRight - tabLeft) - tabWidth) / 2.0;
      tabLeft += delta;
      tabRight -= delta;
    }

    final EdgeInsets insets = indicatorPadding.resolve(_currentTextDirection);
    final Rect rect =
        Rect.fromLTWH(tabLeft, 0.0, tabRight - tabLeft, tabBarSize.height);

    if (!(rect.size >= insets.collapsedSize)) {
      throw FlutterError(
        'indicatorPadding insets should be less than Tab Size\n'
        'Rect Size : ${rect.size}, Insets: ${insets.toString()}',
      );
    }
    return insets.deflateRect(rect);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _needsPaint = false;
    _painter ??= indicator.createBoxPainter(markNeedsPaint);

    final double index = controller.index.toDouble();
    final double value = controller.animation!.value;
    final bool ltr = index > value;
    final int from = (ltr ? value.floor() : value.ceil()).clamp(0, maxTabIndex);
    final int to = (ltr ? from + 1 : from - 1).clamp(0, maxTabIndex);
    final Rect fromRect = indicatorRect(size, from);
    final Rect toRect = indicatorRect(size, to);
    _currentRect = Rect.lerp(fromRect, toRect, (value - from).abs());
    assert(_currentRect != null);

    final ImageConfiguration configuration = ImageConfiguration(
      size: _currentRect!.size,
      textDirection: _currentTextDirection,
    );
    _painter!.paint(canvas, _currentRect!.topLeft, configuration);
  }

  @override
  bool shouldRepaint(_IndicatorPainter old) {
    bool rePaint = _needsPaint ||
        controller != old.controller ||
        indicator != old.indicator ||
        tabKeys.length != old.tabKeys.length ||
        (!listEquals(_currentTabOffsets, old._currentTabOffsets)) ||
        _currentTextDirection != old._currentTextDirection;

    return rePaint;
  }
}

class _ChangeAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ChangeAnimation(this.controller);

  final TabController controller;

  @override
  Animation<double> get parent => controller.animation!;

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    if (controller.animation != null) super.removeStatusListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (controller.animation != null) super.removeListener(listener);
  }

  @override
  double get value => _indexChangeProgress(controller);

  double _indexChangeProgress(TabController controller) {
    final double controllerValue = controller.animation!.value;
    final double previousIndex = controller.previousIndex.toDouble();
    final double currentIndex = controller.index.toDouble();

    if (!controller.indexIsChanging) {
      return (currentIndex - controllerValue).abs().clamp(0.0, 1.0);
    }

    return (controllerValue - currentIndex).abs() /
        (currentIndex - previousIndex).abs();
  }
}

class _DragAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _DragAnimation(this.controller, this.index);

  final TabController controller;
  final int index;

  @override
  Animation<double> get parent => controller.animation!;

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    if (controller.animation != null) super.removeStatusListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (controller.animation != null) super.removeListener(listener);
  }

  @override
  double get value {
    assert(!controller.indexIsChanging);
    final double controllerMaxValue = (controller.length - 1).toDouble();
    final double controllerValue =
        controller.animation!.value.clamp(0.0, controllerMaxValue);
    return (controllerValue - index.toDouble()).abs().clamp(0.0, 1.0);
  }
}

/// https://github.com/OrtakProje-1/reorderable_tabbar
class DynamicTabBar extends StatefulWidget implements PreferredSizeWidget {
  final BorderRadius? tabBorderRadius;

  final Color? tabBackgroundColor;

  final List<Widget> tabs;

  final TabController? controller;

  final bool isScrollable;

  final EdgeInsetsGeometry? padding;

  final Color? indicatorColor;

  final double indicatorWeight;

  final EdgeInsetsGeometry indicatorPadding;

  final Decoration? indicator;

  final bool automaticIndicatorColorAdjustment;

  final TabBarIndicatorSize? indicatorSize;

  final Color? labelColor;

  final Color? unselectedLabelColor;

  final TextStyle? labelStyle;

  final EdgeInsetsGeometry? labelPadding;

  final TextStyle? unselectedLabelStyle;

  final MaterialStateProperty<Color?>? overlayColor;

  final MouseCursor? mouseCursor;

  final bool? enableFeedback;

  final ScrollPhysics? physics;

  final bool Function(int index)? onTap;

  final NotificationListenerCallback<ScrollNotification>? onNotification;

  const DynamicTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.padding,
    this.indicatorColor,
    this.automaticIndicatorColorAdjustment = true,
    this.indicatorWeight = 2.0,
    this.indicatorPadding = EdgeInsets.zero,
    this.indicator,
    this.indicatorSize,
    this.labelColor,
    this.labelStyle,
    this.labelPadding,
    this.unselectedLabelColor,
    this.unselectedLabelStyle,
    this.overlayColor,
    this.mouseCursor,
    this.enableFeedback,
    this.physics,
    this.tabBorderRadius,
    this.tabBackgroundColor,
    this.onTap,
    this.onNotification,
  }) : assert(indicator != null || (indicatorWeight > 0.0));

  @override
  Size get preferredSize {
    double maxHeight = _kTabHeight;
    for (final Widget item in tabs) {
      if (item is PreferredSizeWidget) {
        final double itemHeight = item.preferredSize.height;
        maxHeight = math.max(itemHeight, maxHeight);
      }
    }
    return Size.fromHeight(maxHeight + indicatorWeight);
  }

  bool get tabHasTextAndIcon {
    for (final Widget item in tabs) {
      if (item is PreferredSizeWidget) {
        if (item.preferredSize.height == _kTextAndIconTabHeight) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  State<DynamicTabBar> createState() => _DynamicTabBarState();
}

class _DynamicTabBarState extends State<DynamicTabBar> {
  ScrollController? _scrollController;
  TabController? _controller;
  _IndicatorPainter? _indicatorPainter;
  ScrollController? _reorderController;
  int? _currentIndex;
  double? _tabStripWidth;
  List<double> xOffsets = [];
  double? height;
  bool isScrollToCurrentIndex = false;
  late double screenWidth;
  late List<GlobalKey> _tabKeys;
  late List<GlobalKey> _tabExtendKeys;
  late LinkedScrollControllerGroup _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _reorderController = _controllers.addAndGet();
    _scrollController = _controllers.addAndGet();
    _tabKeys = widget.tabs.map((Widget tab) => GlobalKey()).toList();
    _tabExtendKeys = widget.tabs.map((Widget tab) => GlobalKey()).toList();
  }

  Decoration get _indicator {
    final ThemeData theme = Theme.of(context);
    final TabBarTheme tabBarTheme = TabBarTheme.of(context);
    final TabBarTheme defaults = theme.useMaterial3
        ? _TabsDefaultsM3(context)
        : _TabsDefaultsM2(context);

    if (widget.indicator != null) {
      return widget.indicator!;
    }
    if (tabBarTheme.indicator != null) {
      return tabBarTheme.indicator!;
    }

    Color color = widget.indicatorColor ??
        (theme.useMaterial3
            ? tabBarTheme.indicatorColor ?? defaults.indicatorColor!
            : Theme.of(context).indicatorColor);
    // ThemeData tries to avoid this by having indicatorColor avoid being the
    // primaryColor. However, it's possible that the tab bar is on a
    // Material that isn't the primaryColor. In that case, if the indicator
    // color ends up matching the material's color, then this overrides it.
    // When that happens, automatic transitions of the theme will likely look
    // ugly as the indicator color suddenly snaps to white at one end, but it's
    // not clear how to avoid that any further.
    //
    // The material's color might be null (if it's a transparency). In that case
    // there's no good way for us to find out what the color is so we don't.
    //
    // TODO(xu-baolin): Remove automatic adjustment to white color indicator
    // with a better long-term solution.
    // https://github.com/flutter/flutter/pull/68171#pullrequestreview-517753917
    if (widget.automaticIndicatorColorAdjustment &&
        color.value == Material.maybeOf(context)?.color?.value) {
      color = Colors.white;
    }

    return UnderlineTabIndicator(
      borderSide: BorderSide(
        width: widget.indicatorWeight,
        color: color,
      ),
    );
  }

  // If the TabBar is rebuilt with a new tab controller, the caller should
  // dispose the old one. In that case the old controller's animation will be
  // null and should not be accessed.
  bool get _controllerIsValid => _controller?.animation != null;

  void _updateTabController() {
    final TabController newController =
        widget.controller ?? DefaultTabController.of(context);

    if (newController == _controller) return;

    if (_controllerIsValid) {
      _controller!.animation!.removeListener(_handleTabControllerAnimationTick);
      _controller!.removeListener(_handleTabControllerTick);
    }
    _controller = newController;
    if (_controller != null) {
      _controller!.animation!.addListener(_handleTabControllerAnimationTick);
      _controller!.addListener(_handleTabControllerTick);
      _currentIndex = _controller!.index;
    }
  }

  void _initIndicatorPainter() {
    _indicatorPainter = !_controllerIsValid
        ? null
        : _IndicatorPainter(
            controller: _controller!,
            indicator: _indicator,
            indicatorSize:
                widget.indicatorSize ?? TabBarTheme.of(context).indicatorSize,
            indicatorPadding: widget.indicatorPadding,
            tabKeys: _tabKeys,
            old: _indicatorPainter,
          );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(debugCheckHasMaterial(context));
    screenWidth = MediaQuery.of(context).size.width;
    _updateTabController();
    _initIndicatorPainter();
  }

  @override
  void reassemble() {
    _initIndicatorPainter();
    super.reassemble();
  }

  @override
  void didUpdateWidget(DynamicTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _updateTabController();
      _initIndicatorPainter();
    } else if (widget.indicatorColor != oldWidget.indicatorColor ||
        widget.indicatorWeight != oldWidget.indicatorWeight ||
        widget.indicatorSize != oldWidget.indicatorSize ||
        widget.indicator != oldWidget.indicator) {
      _initIndicatorPainter();
    }

    if (widget.tabs.length > oldWidget.tabs.length) {
      final int delta = widget.tabs.length - oldWidget.tabs.length;
      _tabKeys.addAll(List<GlobalKey>.generate(delta, (int n) => GlobalKey()));
      _tabExtendKeys
          .addAll(List<GlobalKey>.generate(delta, (int n) => GlobalKey()));
    } else if (widget.tabs.length < oldWidget.tabs.length) {
      _tabKeys.removeRange(widget.tabs.length, oldWidget.tabs.length);
      _tabExtendKeys.removeRange(widget.tabs.length, oldWidget.tabs.length);
    }
    if (oldWidget.isScrollable != widget.isScrollable) {
      if (widget.isScrollable) {
        isScrollToCurrentIndex = true;
      }
    }
  }

  @override
  void dispose() {
    _indicatorPainter?.dispose();
    if (_controllerIsValid) {
      _controller!.animation!.removeListener(_handleTabControllerAnimationTick);
      _controller!.removeListener(_handleTabControllerTick);
    }
    _controller = null;

    super.dispose();
  }

  int get maxTabIndex => _indicatorPainter!.maxTabIndex;

  double _tabScrollOffset(
      int index, double viewportWidth, double minExtent, double maxExtent) {
    if (!widget.isScrollable) return 0.0;

    double tabCenter = _indicatorPainter!.centerOf(index);
    switch (Directionality.of(context)) {
      case TextDirection.rtl:
        tabCenter = _tabStripWidth! - tabCenter;
        break;
      case TextDirection.ltr:
        break;
    }
    return (tabCenter - viewportWidth / 2.0).clamp(minExtent, maxExtent);
  }

  double _tabCenteredScrollOffset(int index) {
    final ScrollPosition? position = _reorderController?.position;

    return _tabScrollOffset(
        index,
        position?.viewportDimension ?? screenWidth,
        position?.minScrollExtent ?? 0,
        position?.maxScrollExtent ?? screenWidth);
  }

  void _initialScrollOffset() {
    if (!widget.isScrollable) {
      _controllers.animateTo(0.01,
          curve: Curves.linear, duration: const Duration(milliseconds: 1));
    }
  }

  void _scrollToCurrentIndex() {
    final double offset = _tabCenteredScrollOffset(_currentIndex!);

    _controllers.animateTo(offset,
        duration: kTabScrollDuration, curve: Curves.ease);
  }

  void _scrollToControllerValue() {
    final double? leadingPosition = _currentIndex! > 0
        ? _tabCenteredScrollOffset(_currentIndex! - 1)
        : null;
    final double middlePosition = _tabCenteredScrollOffset(_currentIndex!);
    final double? trailingPosition = _currentIndex! < maxTabIndex
        ? _tabCenteredScrollOffset(_currentIndex! + 1)
        : null;

    final double index = _controller!.index.toDouble();
    final double value = _controller!.animation!.value;
    final double offset;
    if (value == index - 1.0) {
      offset = leadingPosition ?? middlePosition;
    } else if (value == index + 1.0) {
      offset = trailingPosition ?? middlePosition;
    } else if (value == index) {
      offset = middlePosition;
    } else if (value < index) {
      offset = leadingPosition == null
          ? middlePosition
          : lerpDouble(middlePosition, leadingPosition, index - value)!;
    } else {
      offset = trailingPosition == null
          ? middlePosition
          : lerpDouble(middlePosition, trailingPosition, value - index)!;
    }

    _controllers.jumpTo(offset);
  }

  void _handleTabControllerAnimationTick() {
    assert(mounted);
    if (!_controller!.indexIsChanging && widget.isScrollable) {
      _currentIndex = _controller!.index;
      _scrollToControllerValue();
    }
  }

  void _handleTabControllerTick() {
    if (_controller!.index != _currentIndex) {
      _currentIndex = _controller!.index;
      if (widget.isScrollable) _scrollToCurrentIndex();
    }
    setState(() {});
  }

  void _saveTabOffsets(
    List<double> tabOffsets,
    TextDirection textDirection,
    double width,
  ) {
    xOffsets = tabOffsets;
    _tabStripWidth = width;
    _indicatorPainter?.saveTabOffsets(tabOffsets, textDirection);
  }

  void _handleTap(int index) async {
    assert(index >= 0 && index < widget.tabs.length);
    final onTap = widget.onTap;
    if (onTap == null || onTap.call(index)) {
      _controller!.animateTo(index);
    }
  }

  Widget _buildStyledTab(
    Widget child,
    bool selected,
    Animation<double> animation,
  ) {
    return _TabStyle(
      animation: animation,
      selected: selected,
      labelColor: widget.labelColor,
      unselectedLabelColor: widget.unselectedLabelColor,
      labelStyle: widget.labelStyle,
      unselectedLabelStyle: widget.unselectedLabelStyle,
      child: child,
    );
  }

  _calculateTabStripWidth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      double width = 0;
      List<double> offsets = [0];
      TextDirection textDirection = Directionality.maybeOf(context)!;
      for (var key in (textDirection == TextDirection.rtl
          ? _tabExtendKeys.reversed.toList()
          : _tabExtendKeys)) {
        width += key.currentContext?.size?.width ?? 40;
        switch (textDirection) {
          case TextDirection.rtl:
            offsets.insert(0, width);
            break;
          case TextDirection.ltr:
            offsets.add(width);
            break;
        }
      }
      if ((_tabStripWidth ?? 0).floor() != width.floor() ||
          !listEquals<double>(offsets, xOffsets)) {
        _saveTabOffsets(offsets, textDirection, width);
        if (!widget.isScrollable) {
          _initialScrollOffset();
        }
        setState(() {});
      }

      if (isScrollToCurrentIndex) {
        _scrollToCurrentIndex();
        isScrollToCurrentIndex = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    assert(() {
      if (_controller!.length != widget.tabs.length) {
        throw FlutterError(
          "Controller's length property (${_controller!.length}) does not match the "
          "number of tabs (${widget.tabs.length}) present in TabBar's tabs property.",
        );
      }
      return true;
    }());
    final localizations = MaterialLocalizations.of(context);
    if (_controller!.length == 0) {
      return Container(
        height: _kTabHeight + widget.indicatorWeight,
      );
    }

    final tabBarTheme = TabBarTheme.of(context);

    final wrappedTabs = List<Widget>.generate(widget.tabs.length, (int index) {
      const verticalAdjustment = (_kTextAndIconTabHeight - _kTabHeight) / 2.0;
      EdgeInsetsGeometry? adjustedPadding;

      if (widget.tabs[index] is PreferredSizeWidget) {
        final tab = widget.tabs[index] as PreferredSizeWidget;
        if (widget.tabHasTextAndIcon &&
            tab.preferredSize.height == _kTabHeight) {
          if (widget.labelPadding != null || tabBarTheme.labelPadding != null) {
            adjustedPadding = (widget.labelPadding ?? tabBarTheme.labelPadding!)
                .add(const EdgeInsets.symmetric(
              vertical: verticalAdjustment,
            ));
          } else {
            adjustedPadding = const EdgeInsets.symmetric(
              vertical: verticalAdjustment,
              horizontal: 16.0,
            );
          }
        }
      }

      return Center(
        heightFactor: 1.0,
        child: Padding(
          padding: adjustedPadding ??
              widget.labelPadding ??
              tabBarTheme.labelPadding ??
              kTabLabelPadding,
          child: KeyedSubtree(
            key: _tabKeys[index],
            child: widget.tabs[index],
          ),
        ),
      );
    });

    if (_controller != null) {
      final int previousIndex = _controller!.previousIndex;

      if (_controller!.indexIsChanging) {
        assert(_currentIndex != previousIndex);
        final Animation<double> animation = _ChangeAnimation(_controller!);
        wrappedTabs[_currentIndex!] = _buildStyledTab(
          wrappedTabs[_currentIndex!],
          true,
          animation,
        );
        wrappedTabs[previousIndex] = _buildStyledTab(
          wrappedTabs[previousIndex],
          false,
          animation,
        );
      } else {
        final int tabIndex = _currentIndex!;
        final Animation<double> centerAnimation =
            _DragAnimation(_controller!, tabIndex);
        wrappedTabs[tabIndex] = _buildStyledTab(
          wrappedTabs[tabIndex],
          true,
          centerAnimation,
        );
        if (_currentIndex! > 0) {
          final int tabIndex = _currentIndex! - 1;
          final Animation<double> previousAnimation =
              ReverseAnimation(_DragAnimation(_controller!, tabIndex));
          wrappedTabs[tabIndex] = _buildStyledTab(
            wrappedTabs[tabIndex],
            false,
            previousAnimation,
          );
        }
        if (_currentIndex! < widget.tabs.length - 1) {
          final int tabIndex = _currentIndex! + 1;
          final Animation<double> nextAnimation =
              ReverseAnimation(_DragAnimation(_controller!, tabIndex));
          wrappedTabs[tabIndex] = _buildStyledTab(
            wrappedTabs[tabIndex],
            false,
            nextAnimation,
          );
        }
      }
    }

    final int tabCount = widget.tabs.length;

    for (int index = 0; index < tabCount; index += 1) {
      wrappedTabs[index] = InkWell(
        borderRadius: widget.tabBorderRadius,
        mouseCursor: widget.mouseCursor ?? SystemMouseCursors.click,
        onTap: () {
          _handleTap(index);
        },
        enableFeedback: widget.enableFeedback ?? true,
        overlayColor: widget.overlayColor,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: widget.tabBorderRadius,
            color: widget.tabBackgroundColor,
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.indicatorWeight),
            child: Stack(
              children: <Widget>[
                wrappedTabs[index],
                Semantics(
                  selected: index == _currentIndex,
                  label: localizations.tabLabel(
                    tabIndex: index + 1,
                    tabCount: tabCount,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    Widget? tabBar;

    height ??= widget.preferredSize.height;

    double? tabWidth;
    if (!widget.isScrollable) {
      tabWidth = (screenWidth - (widget.padding?.horizontal ?? 0)) /
          wrappedTabs.length;
    }
    for (var i = 0; i < wrappedTabs.length; i++) {
      Widget child = wrappedTabs[i];

      wrappedTabs[i] = SizedBox(
        key: _tabExtendKeys[i],
        width: tabWidth,
        height: height,
        child: _TabStyle(
          animation: kAlwaysDismissedAnimation,
          selected: false,
          labelColor: widget.labelColor,
          unselectedLabelColor: widget.unselectedLabelColor,
          labelStyle: widget.labelStyle,
          unselectedLabelStyle: widget.unselectedLabelStyle,
          child: child,
        ),
      );
    }
    tabBar = Stack(
      children: [
        SizedBox(
          height: height,
          width: double.maxFinite,
          child: ListView.builder(
            padding: widget.padding,
            cacheExtent: double.maxFinite,
            physics: widget.physics,
            controller: _reorderController,
            scrollDirection: Axis.horizontal,
            itemCount: wrappedTabs.length,
            itemBuilder: (context, index) {
              return wrappedTabs[index];
            },
          ),
        ),
        if (_tabStripWidth != null) getIndicatorPainter(),
      ],
    );
    _calculateTabStripWidth();

    return NotificationListener<ScrollNotification>(
      onNotification: widget.onNotification,
      child: tabBar,
    );
  }

  Positioned getIndicatorPainter() {
    double width = _tabStripWidth!;
    if (!widget.isScrollable) {
      if (width > (screenWidth - (widget.padding?.horizontal ?? 0))) {
        width = screenWidth - (widget.padding?.horizontal ?? 0);
      }
    }
    return Positioned(
      bottom: 0,
      right: 0,
      left: 0,
      height: widget.indicatorWeight,
      child: SingleChildScrollView(
        padding: widget.padding,
        physics: widget.physics,
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: CustomPaint(
          painter: _indicatorPainter,
          child: SizedBox(
            height: widget.indicatorWeight,
            width: width,
          ),
        ),
      ),
    );
  }
}

class _TabsDefaultsM2 extends TabBarTheme {
  const _TabsDefaultsM2(this.context)
      : super(indicatorSize: TabBarIndicatorSize.tab);

  final BuildContext context;

  @override
  Color? get indicatorColor => Theme.of(context).indicatorColor;

  @override
  Color? get labelColor => Theme.of(context).primaryTextTheme.bodyLarge!.color!;

  @override
  TextStyle? get labelStyle => Theme.of(context).primaryTextTheme.bodyLarge;

  @override
  TextStyle? get unselectedLabelStyle =>
      Theme.of(context).primaryTextTheme.bodyLarge;

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory;
}

class _TabsDefaultsM3 extends TabBarTheme {
  _TabsDefaultsM3(this.context)
      : super(indicatorSize: TabBarIndicatorSize.label);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get dividerColor => _colors.surfaceVariant;

  @override
  Color? get indicatorColor => _colors.primary;

  @override
  Color? get labelColor => _colors.primary;

  @override
  TextStyle? get labelStyle => _textTheme.titleSmall;

  @override
  Color? get unselectedLabelColor => _colors.onSurfaceVariant;

  @override
  TextStyle? get unselectedLabelStyle => _textTheme.titleSmall;

  @override
  MaterialStateProperty<Color?> get overlayColor {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        if (states.contains(MaterialState.hovered)) {
          return _colors.primary.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.primary.withOpacity(0.12);
        }
        if (states.contains(MaterialState.pressed)) {
          return _colors.primary.withOpacity(0.12);
        }
        return null;
      }
      if (states.contains(MaterialState.hovered)) {
        return _colors.onSurface.withOpacity(0.08);
      }
      if (states.contains(MaterialState.focused)) {
        return _colors.onSurface.withOpacity(0.12);
      }
      if (states.contains(MaterialState.pressed)) {
        return _colors.primary.withOpacity(0.12);
      }
      return null;
    });
  }

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory;
}

/// https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/tabs.dart#L1864
class DynamicTabBarView extends StatefulWidget {
  /// Creates a page view with one child per tab.
  ///
  /// The length of [children] must be the same as the [controller]'s length.
  const DynamicTabBarView({
    super.key,
    required this.children,
    this.controller,
    this.physics,
    this.dragStartBehavior = DragStartBehavior.start,
    this.viewportFraction = 1.0,
    this.clipBehavior = Clip.hardEdge,
    this.onPageChanged,
  });

  /// This widget's selection and animation state.
  ///
  /// If [TabController] is not provided, then the value of [DefaultTabController.of]
  /// will be used.
  final TabController? controller;

  /// One widget per tab.
  ///
  /// Its length must match the length of the [TabBar.tabs]
  /// list, as well as the [controller]'s [TabController.length].
  final List<Widget> children;

  /// How the page view should respond to user input.
  ///
  /// For example, determines how the page view continues to animate after the
  /// user stops dragging the page view.
  ///
  /// The physics are modified to snap to page boundaries using
  /// [PageScrollPhysics] prior to being used.
  ///
  /// Defaults to matching platform conventions.
  final ScrollPhysics? physics;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@macro flutter.widgets.pageview.viewportFraction}
  final double viewportFraction;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  final ValueChanged<int>? onPageChanged;

  @override
  State<DynamicTabBarView> createState() => _DynamicTabBarViewState();
}

class _DynamicTabBarViewState extends State<DynamicTabBarView> {
  TabController? _controller;
  PageController? _pageController;
  late List<Widget> _childrenWithKey;
  int? _currentIndex;
  int _warpUnderwayCount = 0;
  int _scrollUnderwayCount = 0;
  bool _debugHasScheduledValidChildrenCountCheck = false;

  // If the TabBarView is rebuilt with a new tab controller, the caller should
  // dispose the old one. In that case the old controller's animation will be
  // null and should not be accessed.
  bool get _controllerIsValid => _controller?.animation != null;

  void _updateTabController() {
    final TabController? newController =
        widget.controller ?? DefaultTabController.maybeOf(context);
    assert(() {
      if (newController == null) {
        throw FlutterError(
          'No TabController for ${widget.runtimeType}.\n'
          'When creating a ${widget.runtimeType}, you must either provide an explicit '
          'TabController using the "controller" property, or you must ensure that there '
          'is a DefaultTabController above the ${widget.runtimeType}.\n'
          'In this case, there was neither an explicit controller nor a default controller.',
        );
      }
      return true;
    }());

    if (newController == _controller) {
      return;
    }

    if (_controllerIsValid) {
      _controller!.animation!.removeListener(_handleTabControllerAnimationTick);
    }
    _controller = newController;
    if (_controller != null) {
      _controller!.animation!.addListener(_handleTabControllerAnimationTick);
    }
  }

  void _jumpToPage(int page) {
    _warpUnderwayCount += 1;
    _pageController!.jumpToPage(page);
    _warpUnderwayCount -= 1;
  }

  Future<void> _animateToPage(
    int page, {
    required Duration duration,
    required Curve curve,
  }) async {
    _warpUnderwayCount += 1;
    await _pageController!
        .animateToPage(page, duration: duration, curve: curve);
    _warpUnderwayCount -= 1;
  }

  @override
  void initState() {
    super.initState();
    _updateChildren();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTabController();
    _currentIndex = _controller!.index;
    if (_pageController == null) {
      _pageController = PageController(
        initialPage: _currentIndex!,
        viewportFraction: widget.viewportFraction,
      );
    } else {
      _pageController!.jumpToPage(_currentIndex!);
    }
  }

  @override
  void didUpdateWidget(DynamicTabBarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _updateTabController();
      _currentIndex = _controller!.index;
      _jumpToPage(_currentIndex!);
    }
    if (widget.viewportFraction != oldWidget.viewportFraction) {
      _pageController?.dispose();
      _pageController = PageController(
        initialPage: _currentIndex!,
        viewportFraction: widget.viewportFraction,
      );
    }
    // While a warp is under way, we stop updating the tab page contents.
    // This is tracked in https://github.com/flutter/flutter/issues/31269.
    if (widget.children != oldWidget.children && _warpUnderwayCount == 0) {
      _updateChildren();
    }
  }

  @override
  void dispose() {
    if (_controllerIsValid) {
      _controller!.animation!.removeListener(_handleTabControllerAnimationTick);
    }
    _controller = null;
    _pageController?.dispose();
    // We don't own the _controller Animation, so it's not disposed here.
    super.dispose();
  }

  void _updateChildren() {
    _childrenWithKey = KeyedSubtree.ensureUniqueKeysForList(widget.children);
  }

  void _handleTabControllerAnimationTick() {
    if (_scrollUnderwayCount > 0 || !_controller!.indexIsChanging) {
      return;
    } // This widget is driving the controller's animation.

    if (_controller!.index != _currentIndex) {
      _currentIndex = _controller!.index;
      _warpToCurrentIndex();
    }
  }

  void _warpToCurrentIndex() {
    if (!mounted || _pageController!.page == _currentIndex!.toDouble()) {
      return;
    }

    final bool adjacentDestination =
        (_currentIndex! - _controller!.previousIndex).abs() == 1;
    if (adjacentDestination) {
      _warpToAdjacentTab(_controller!.animationDuration);
    } else {
      _warpToNonAdjacentTab(_controller!.animationDuration);
    }
  }

  Future<void> _warpToAdjacentTab(Duration duration) async {
    if (duration == Duration.zero) {
      _jumpToPage(_currentIndex!);
    } else {
      await _animateToPage(_currentIndex!,
          duration: duration, curve: Curves.ease);
    }
    if (mounted) {
      setState(() {
        _updateChildren();
      });
    }
    return Future<void>.value();
  }

  Future<void> _warpToNonAdjacentTab(Duration duration) async {
    final int previousIndex = _controller!.previousIndex;
    assert((_currentIndex! - previousIndex).abs() > 1);

    // initialPage defines which page is shown when starting the animation.
    // This page is adjacent to the destination page.
    final int initialPage = _currentIndex! > previousIndex
        ? _currentIndex! - 1
        : _currentIndex! + 1;

    setState(() {
      // Needed for `RenderSliverMultiBoxAdaptor.move` and kept alive children.
      // For motivation, see https://github.com/flutter/flutter/pull/29188 and
      // https://github.com/flutter/flutter/issues/27010#issuecomment-486475152.
      _childrenWithKey = List<Widget>.of(_childrenWithKey, growable: false);
      final Widget temp = _childrenWithKey[initialPage];
      _childrenWithKey[initialPage] = _childrenWithKey[previousIndex];
      _childrenWithKey[previousIndex] = temp;
    });

    // Make a first jump to the adjacent page.
    _jumpToPage(initialPage);

    // Jump or animate to the destination page.
    if (duration == Duration.zero) {
      _jumpToPage(_currentIndex!);
    } else {
      await _animateToPage(_currentIndex!,
          duration: duration, curve: Curves.ease);
    }

    if (mounted) {
      setState(() {
        _updateChildren();
      });
    }
  }

  void _syncControllerOffset() {
    _controller!.offset =
        clampDouble(_pageController!.page! - _controller!.index, -1.0, 1.0);
  }

  // Called when the PageView scrolls
  bool _handleScrollNotification(ScrollNotification notification) {
    if (_warpUnderwayCount > 0 || _scrollUnderwayCount > 0) {
      return false;
    }

    if (notification.depth != 0) {
      return false;
    }

    if (!_controllerIsValid) {
      return false;
    }

    _scrollUnderwayCount += 1;
    final double page = _pageController!.page!;
    if (notification is ScrollUpdateNotification &&
        !_controller!.indexIsChanging) {
      final bool pageChanged = (page - _controller!.index).abs() > 1.0;
      if (pageChanged) {
        _controller!.index = page.round();
        _currentIndex = _controller!.index;
      }
      _syncControllerOffset();
    } else if (notification is ScrollEndNotification) {
      _controller!.index = page.round();
      _currentIndex = _controller!.index;
      if (!_controller!.indexIsChanging) {
        _syncControllerOffset();
      }
    }
    _scrollUnderwayCount -= 1;

    return false;
  }

  bool _debugScheduleCheckHasValidChildrenCount() {
    if (_debugHasScheduledValidChildrenCountCheck) {
      return true;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
      _debugHasScheduledValidChildrenCountCheck = false;
      if (!mounted) {
        return;
      }
      assert(() {
        if (_controller!.length != widget.children.length) {
          throw FlutterError(
            "Controller's length property (${_controller!.length}) does not match the "
            "number of children (${widget.children.length}) present in TabBarView's children property.",
          );
        }
        return true;
      }());
    }, debugLabel: 'TabBarView.validChildrenCountCheck');
    _debugHasScheduledValidChildrenCountCheck = true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    assert(_debugScheduleCheckHasValidChildrenCount());

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: PageView(
        onPageChanged: widget.onPageChanged,
        dragStartBehavior: widget.dragStartBehavior,
        clipBehavior: widget.clipBehavior,
        controller: _pageController,
        physics: widget.physics == null
            ? const PageScrollPhysics().applyTo(const ClampingScrollPhysics())
            : const PageScrollPhysics().applyTo(widget.physics),
        children: _childrenWithKey,
      ),
    );
  }
}

typedef OnDynamicPageCanDrag = Function(int from, int to);

/// https://github.com/RobluScouting/FlutterBoardView/blob/master/lib/boardview_page_controller.dart
class DynamicPageScrollPhysics extends ScrollPhysics {
  /// Requests whether a drag may occur from the page at index "from"
  /// to the page at index "to". Return true to allow, false to deny.
  final OnDynamicPageCanDrag onCanDrag;

  /// Creates physics for a [PageView].
  const DynamicPageScrollPhysics({super.parent, required this.onCanDrag});

  @override
  DynamicPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return DynamicPageScrollPhysics(
      parent: buildParent(ancestor),
      onCanDrag: onCanDrag,
    );
  }

  double _getPage(ScrollMetrics position) {
    return position.pixels / position.viewportDimension;
  }

  double _getPixels(ScrollMetrics position, double page) {
    return page * position.viewportDimension;
  }

  double _getTargetPixels(
      ScrollMetrics position, Tolerance tolerance, double velocity) {
    double page = _getPage(position);
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return _getPixels(position, page.roundToDouble());
  }

  // position is the pixels of the left edge of the screen
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    assert(() {
      if (value == position.pixels) {
        throw FlutterError(
            '$runtimeType.applyBoundaryConditions() was called redundantly.\n'
            'The proposed new position, $value, is exactly equal to the current position of the '
            'given ${position.runtimeType}, ${position.pixels}.\n'
            'The applyBoundaryConditions method should only be called when the value is '
            'going to actually change the pixels, otherwise it is redundant.\n'
            'The physics object in question was:\n'
            '  $this\n'
            'The position object in question was:\n'
            '  $position\n');
      }
      return true;
    }());

    /*
     * Handle the hard boundaries (min and max extents)
     * (identical to ClampingScrollPhysics)
     */
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      // under-scroll
      return value - position.pixels;
    }
    if (position.maxScrollExtent <= position.pixels &&
        position.pixels < value) {
      // over-scroll
      return value - position.pixels;
    }
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) {
      // hit top edge
      return value - position.minScrollExtent;
    }
    if (position.pixels < position.maxScrollExtent &&
        position.maxScrollExtent < value) {
      // hit bottom edge
      return value - position.maxScrollExtent;
    }

    bool left = value < position.pixels;

    int fromPage, toPage;
    double overScroll = 0;

    if (left) {
      fromPage = position.pixels.ceil() ~/ position.viewportDimension;
      toPage = value ~/ position.viewportDimension;

      overScroll = value - fromPage * position.viewportDimension;
      overScroll = overScroll.clamp(value - position.pixels, 0.0);
    } else {
      fromPage = (position.pixels + position.viewportDimension - 1).floor() ~/
          position.viewportDimension;
      toPage =
          (value + position.viewportDimension) ~/ position.viewportDimension;

      overScroll = value - fromPage * position.viewportDimension;
      overScroll = overScroll.clamp(0.0, value - position.pixels);
    }

    if (fromPage != toPage && !onCanDrag(fromPage, toPage) && true) {
      return overScroll;
    } else {
      return super.applyBoundaryConditions(position, value);
    }
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // If we're out of range and not headed back in range, defer to the parent
    // ballistics, which should put us back in range at a page boundary.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    final double target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels) {
      return ScrollSpringSimulation(spring, position.pixels, target, velocity,
          tolerance: tolerance);
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
