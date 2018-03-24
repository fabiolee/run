import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:package_info/package_info.dart';

import 'package:run/html_text_view.dart';

void main() => runApp(new RunApp());

class RunApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: 'Cari Runners',
        theme: new ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: new MainPage());
  }
}

class MainPage extends StatefulWidget {
  @override
  createState() => new MainPageState();
}

class MainPageState extends State<MainPage> with TickerProviderStateMixin {
  final FirebaseMessaging _firebaseMessaging = new FirebaseMessaging();
  bool loading = true;
  String status;
  List<dom.Element> widgets = [];
  int _currentIndex = 0;
  List<NavigationIconView> _navigationViews;
  PackageInfo _packageInfo = new PackageInfo(
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _configureFirebaseMessaging();
    _initBottomNavigation();
    _initPackageInfo();
    loadData();
  }

  @override
  void dispose() {
    _disposeBottomNavigation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BottomNavigationBar botNavBar = new BottomNavigationBar(
      items: _navigationViews
          .map((NavigationIconView navigationView) => navigationView.item)
          .toList(),
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (int index) {
        setState(() {
          _navigationViews[_currentIndex].controller.reverse();
          _currentIndex = index;
          _navigationViews[_currentIndex].controller.forward();
        });
      },
    );

    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Cari Runners'),
      ),
      body: _buildTransitionsStack(),
      bottomNavigationBar: botNavBar,
    );
  }

  Widget _buildDialog(BuildContext context, PostItem item) {
    return new AlertDialog(
      content: new Text("New Run Available!"),
      actions: <Widget>[
        new FlatButton(
          child: const Text('CLOSE'),
          onPressed: () {
            Navigator.pop(context, false);
          },
        ),
        new FlatButton(
          child: const Text('SHOW'),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
      ],
    );
  }

  Widget _buildSettings() {
    return new DecoratedBox(
      decoration: const BoxDecoration(color: const Color(0xFFEFEFF4)),
      child: new ListView(
        children: <Widget>[
          const Padding(padding: const EdgeInsets.only(top: 32.0)),
          new Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: const BorderSide(
                    color: const Color(0xFFBCBBC1), width: 0.0),
                bottom: const BorderSide(
                    color: const Color(0xFFBCBBC1), width: 0.0),
              ),
            ),
            height: 44.0,
            child: new Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  new Text("Version", style: Theme.of(context).textTheme.body1),
                  new Text(
                    _getVersion(_packageInfo),
                    style: Theme.of(context).textTheme.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    var spacer = new SizedBox(height: 32.0);
    return new Container(
        child: new Padding(
      padding: new EdgeInsets.all(16.0),
      child: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Text(status),
            spacer,
            new RaisedButton(
              onPressed: () {
                setState(() {
                  loading = true;
                  loadData();
                });
              },
              child: new Text('RETRY'),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildTransitionsStack() {
    final List<FadeTransition> transitions = <FadeTransition>[];

    for (NavigationIconView view in _navigationViews) {
      Widget body;
      switch (view._title) {
        case "Home":
          body = getBody();
          break;
        case "Favorites":
          body = new Center(child: new Text("Favorites"));
          break;
        case "Settings":
          body = _buildSettings();
          break;
      }
      transitions.add(view.transition(context, body));
    }

    // We want to have the newly animating (fading in) views on top.
    transitions.sort((FadeTransition a, FadeTransition b) {
      final Animation<double> aAnimation = a.opacity;
      final Animation<double> bAnimation = b.opacity;
      final double aValue = aAnimation.value;
      final double bValue = bAnimation.value;
      return aValue.compareTo(bValue);
    });

    return new Stack(children: transitions);
  }

  void _configureFirebaseMessaging() {
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) {
        print("onMessage: $message");
        _showPostItemDialog(message);
      },
      onLaunch: (Map<String, dynamic> message) {
        print("onLaunch: $message");
        _navigateToPostItem(message);
      },
      onResume: (Map<String, dynamic> message) {
        print("onResume: $message");
        _navigateToPostItem(message);
      },
    );
    _firebaseMessaging.requestNotificationPermissions(
        const IosNotificationSettings(sound: true, badge: true, alert: true));
    _firebaseMessaging.onIosSettingsRegistered
        .listen((IosNotificationSettings settings) {
      print("Settings registered: $settings");
    });
    _firebaseMessaging.getToken().then((String token) {
      assert(token != null);
      print("Push Messaging token: $token");
    });
  }

  _disposeBottomNavigation() {
    for (NavigationIconView view in _navigationViews) view.controller.dispose();
  }

  Widget getBody() {
    if (_showLoadingDialog()) {
      return getProgressDialog();
    } else if (_showStatus()) {
      return _buildStatus();
    } else {
      return getListView();
    }
  }

  ListView getListView() => new ListView.builder(
      itemCount: widgets.length,
      itemBuilder: (context, position) {
        return getRow(position);
      });

  Widget getProgressDialog() {
    return new Center(child: new CircularProgressIndicator());
  }

  Widget getRow(int position) {
    return new GestureDetector(
      child: new Container(
          child: new Padding(
              padding: new EdgeInsets.all(16.0),
              child: new Text(widgets[position].text)),
          decoration: new BoxDecoration(
              border:
                  new Border(bottom: new BorderSide(color: Colors.grey[200])))),
      onTap: () {
        String urlPath = Uri
            .parse(widgets[position].querySelector("a").attributes["href"])
            .path;
        Navigator.push(
            context,
            new MaterialPageRoute(
              builder: (context) => new PostPage(urlPath),
            ));
      },
    );
  }

  String _getVersion(PackageInfo _packageInfo) {
    String version;
    const bool _kReleaseMode = const bool.fromEnvironment("dart.vm.product");
    if (_kReleaseMode) {
      version = _packageInfo.version;
    } else {
      version = _packageInfo.version + " (" + _packageInfo.buildNumber + ")";
    }
    return version;
  }

  void _initBottomNavigation() {
    _navigationViews = <NavigationIconView>[
      new NavigationIconView(
        icon: const Icon(Icons.home),
        title: 'Home',
        vsync: this,
      ),
      new NavigationIconView(
        icon: const Icon(Icons.favorite),
        title: 'Favorites',
        vsync: this,
      ),
      new NavigationIconView(
        icon: const Icon(Icons.settings),
        title: 'Settings',
        vsync: this,
      ),
    ];

    for (NavigationIconView view in _navigationViews)
      view.controller.addListener(_rebuild);

    _navigationViews[_currentIndex].controller.value = 1.0;
  }

  Future<Null> _initPackageInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  PostItem _postItemForMessage(Map<String, dynamic> message) {
    final String urlPath = Uri.parse(message['url']).path;
    return new PostItem(urlPath: urlPath);
  }

  loadData() async {
    String status;
    List<dom.Element> widgets = [];
    try {
      String dataUrl =
          "https://www.googleapis.com/blogger/v3/blogs/9027509069015616506/pages/6337578441124076615?key=AIzaSyDGktXyn4O-hKkVkVFna7NQOrEOxfcwqTA";
      http.Response response = await http.get(dataUrl);
      Map map = json.decode(response.body);
      dom.Document document = parse(map["content"]);
      widgets = document.querySelectorAll("ul li");
      if (widgets == null || widgets.isEmpty) {
        status = "No Content Found";
        widgets = [];
      }
    } catch (exception) {
      status = exception.toString();
    }
    setState(() {
      loading = false;
      this.status = status;
      this.widgets = widgets;
    });
  }

  Future<Null> _navigateToPostItem(Map<String, dynamic> message) async {
    final PostItem item = _postItemForMessage(message);
    Navigator.push(
        context,
        new MaterialPageRoute(
          builder: (context) => new PostPage(item.urlPath),
        ));
  }

  void _rebuild() {
    setState(() {
      // Rebuild in order to animate views.
    });
  }

  bool _showLoadingDialog() {
    return loading;
  }

  void _showPostItemDialog(Map<String, dynamic> message) {
    showDialog<bool>(
      context: context,
      child: _buildDialog(context, _postItemForMessage(message)),
    ).then((bool shouldNavigate) {
      if (shouldNavigate == true) {
        _navigateToPostItem(message);
      }
    });
  }

  bool _showStatus() {
    return status != null;
  }
}

class NavigationIconView {
  NavigationIconView({
    Widget icon,
    String title,
    TickerProvider vsync,
  })
      : _icon = icon,
        _title = title,
        item = new BottomNavigationBarItem(
          icon: icon,
          title: new Text(title),
        ),
        controller = new AnimationController(
          duration: kThemeAnimationDuration,
          vsync: vsync,
        ) {
    _animation = new CurvedAnimation(
      parent: controller,
      curve: const Interval(0.5, 1.0, curve: Curves.fastOutSlowIn),
    );
  }

  final Widget _icon;
  final String _title;
  final BottomNavigationBarItem item;
  final AnimationController controller;
  CurvedAnimation _animation;

  FadeTransition transition(BuildContext context, Widget body) {
    final ThemeData themeData = Theme.of(context);
    Color iconColor = themeData.brightness == Brightness.light
        ? themeData.primaryColor
        : themeData.accentColor;

    return new FadeTransition(
      opacity: _animation,
      child: new SlideTransition(
          position: new Tween<Offset>(
            begin: const Offset(0.0, 0.02), // Slightly down.
            end: Offset.zero,
          )
              .animate(_animation),
          child: body),
    );
  }
}

class PostPage extends StatefulWidget {
  final String urlPath;

  PostPage(this.urlPath);

  @override
  createState() => new PostPageState();
}

class PostPageState extends State<PostPage> {
  bool loading = true;
  String status;
  String title;
  String logo;
  String content;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Cari Runners'),
      ),
      body: getBody(),
    );
  }

  Widget _buildStatus() {
    var spacer = new SizedBox(height: 32.0);
    return new Container(
        child: new Padding(
      padding: new EdgeInsets.all(16.0),
      child: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Text(status),
            spacer,
            new RaisedButton(
              onPressed: () {
                setState(() {
                  loading = true;
                  loadData();
                });
              },
              child: new Text('RETRY'),
            ),
          ],
        ),
      ),
    ));
  }

  getBody() {
    if (_showLoadingDialog()) {
      return getProgressDialog();
    } else if (_showStatus()) {
      return _buildStatus();
    } else {
      return getListView();
    }
  }

  getListView() {
    return new ListView(
      children: <Widget>[
        new Container(
            padding: new EdgeInsets.all(16.0),
            child:
                new Text(title, style: Theme.of(context).textTheme.headline)),
        new ConstrainedBox(
          constraints: new BoxConstraints(maxHeight: 300.0, maxWidth: 300.0),
          child: new CachedNetworkImage(imageUrl: logo),
        ),
        new HtmlTextView(data: content)
      ],
    );
  }

  getProgressDialog() {
    return new Center(child: new CircularProgressIndicator());
  }

  loadData() async {
    String status;
    String title;
    String logo;
    String content;
    try {
      String dataUrl =
          "https://www.googleapis.com/blogger/v3/blogs/9027509069015616506/posts/bypath?key=AIzaSyDGktXyn4O-hKkVkVFna7NQOrEOxfcwqTA&path=";
      http.Response response = await http.get(dataUrl + widget.urlPath);
      Map map = json.decode(response.body);
      title = map["title"];
      dom.Document document = parse(map["content"]);
      dom.Element firstElement = document.querySelector("div");
      dom.Element imgElement = firstElement.querySelector("img");
      logo = imgElement.attributes["src"];
      firstElement.remove();
      content = document.body.innerHtml;
      if (title == null || logo == null || content == null) {
        status = "No Content Found";
      }
    } catch (exception) {
      status = exception.toString();
    }
    setState(() {
      loading = false;
      this.status = status;
      this.title = title;
      this.logo = logo;
      this.content = content;
    });
  }

  _showLoadingDialog() {
    return loading;
  }

  bool _showStatus() {
    return status != null;
  }
}

class PostItem {
  PostItem({this.urlPath});
  final String urlPath;
}
