import 'package:dynamic_tab_bar/dynamic_tab_bar.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var _length = 10;
  var _isFetchMore = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DynamicTabController(
        initialIndex: 0,
        length: _length,
        child: Builder(
          builder: (context) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                title: const Text(
                  'Dynamic Tab Bar',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                bottom: DynamicTabBar(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      if (notification.metrics.pixels ==
                          notification.metrics.maxScrollExtent) {
                        if (!_isFetchMore) {
                          _isFetchMore = true;
                          if (_length == 10) {
                            Future.delayed(const Duration(seconds: 1), () {
                              setState(() {
                                _length += 10;
                                _isFetchMore = false;
                              });
                            });
                          }
                        }
                      }
                    }
                    return true;
                  },
                  onTap: (index) {
                    print("onTap: index = $index");
                    if (index == _length - 1) {
                      showAboutDialog(
                        context: context,
                        applicationIcon: const FlutterLogo(),
                        applicationName: "Dynamic Tab Bar",
                      );
                    }
                    return index < _length - 1;
                  },
                  controller: DynamicTabController.of(context),
                  overlayColor:
                      MaterialStateProperty.all<Color>(Colors.transparent),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  labelColor: Colors.white,
                  tabBackgroundColor: Colors.transparent,
                  automaticIndicatorColorAdjustment: false,
                  isScrollable: true,
                  tabs: List.generate(
                    _length,
                    (index) {
                      if (index == _length - 1) {
                        return const Tab(
                          height: 54,
                          icon: Icon(Icons.settings),
                        );
                      } else {
                        return Tab(
                          height: 54,
                          text: 'Tab $index',
                        );
                      }
                    },
                  ),
                ),
              ),
              body: DynamicTabBarView(
                onPageChanged: (index) {
                  print("onPageChanged: index = $index");
                },
                physics: DynamicPageScrollPhysics(onCanDrag: (from, to) {
                  return to < _length - 1;
                }),
                controller: DynamicTabController.of(context),
                children: List.generate(
                  _length,
                  (index) {
                    if (index == _length - 1) {
                      return const SizedBox.shrink();
                    } else {
                      return Center(
                        child: Text(
                          'Tab $index',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
