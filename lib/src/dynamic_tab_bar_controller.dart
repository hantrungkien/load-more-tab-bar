import 'package:flutter/material.dart';

class _DynamicTabControllerScope extends InheritedWidget {
  const _DynamicTabControllerScope({
    required this.controller,
    required super.child,
  });

  final TabController controller;

  @override
  bool updateShouldNotify(_DynamicTabControllerScope old) {
    return controller != old.controller;
  }

  static TabController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_DynamicTabControllerScope>()
        ?.controller;
  }
}

class DynamicTabController extends StatefulWidget {
  final Widget child;
  final int length;
  final int initialIndex;
  final Duration? animationDuration;

  const DynamicTabController({
    super.key,
    required this.child,
    required this.length,
    this.initialIndex = 0,
    this.animationDuration,
  });

  @override
  State<DynamicTabController> createState() => _DynamicTabControllerState();

  static TabController of(BuildContext context) {
    final TabController? controller =
        _DynamicTabControllerScope.maybeOf(context);
    assert(controller != null, 'No TabController found');
    return controller!;
  }
}

class _DynamicTabControllerState extends State<DynamicTabController>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(
      length: widget.length,
      vsync: this,
      initialIndex: widget.initialIndex,
      animationDuration: widget.animationDuration,
    );
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DynamicTabController oldWidget) {
    if (oldWidget.length != widget.length ||
        oldWidget.initialIndex != widget.initialIndex) {
      final currentIndex = _tabController.previousIndex;
      _tabController.dispose();
      var newIndex = currentIndex;
      if (currentIndex != widget.initialIndex) {
        newIndex = widget.initialIndex;
      }
      _tabController = TabController(
        length: widget.length,
        vsync: this,
        initialIndex: newIndex,
        animationDuration: widget.animationDuration,
      );
    }

    if (oldWidget.animationDuration != widget.animationDuration) {
      _tabController.dispose();
      _tabController = TabController(
        length: widget.length,
        vsync: this,
        initialIndex: _tabController.index,
        animationDuration: widget.animationDuration,
      );
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return _DynamicTabControllerScope(
      controller: _tabController,
      child: widget.child,
    );
  }
}
