<h1 align="center">Dynamic Tab Bar</h1>

<p align="center">Dynamic Tab Bar is a Flutter package that provides a dynamic tab bar with a scrollable, load more and awesome other functions.</p><br>

<p align="center"><img src="https://github.com/hantrungkien/dynamic-tab-bar/blob/main/media/screen_record.gif?raw=true" width="256"/></p><br>

<p align="center">
  <a href="https://flutter.dev">
    <img src="https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter"
      alt="Platform" />
  </a>
  <a href="https://pub.dartlang.org/packages/dynamic_tab_bar">
    <img src="https://img.shields.io/pub/v/dynamic_tab_bar.svg"
      alt="Pub Package" />
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/github/license/hantrungkien/dynamic-tab-bar"
      alt="License: MIT" />
  </a>
  <br>
</p><br>

# Installing

### 1. Depend on it

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  load_more_tab_bar: ^1.0.0
```

### 2. Install it

You can install packages from the command line:

with `pub`:

```
$ pub get
```

with `Flutter`:

```
$ flutter pub get
```

### 3. Import it

Now in your `Dart` code, you can use:

```dart
import 'package:load_more_tab_bar/dynamic_tab_bar.dart';
```

# Usage

```dart
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
```
