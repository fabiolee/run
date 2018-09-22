import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';

import 'database.dart';
import 'favorite_icon_button.dart';
import 'home_tab.dart';
import 'html_text_view.dart';

void main() => runApp(new RunApp());

class RunApp extends StatelessWidget {
  static FirebaseAnalytics analytics = new FirebaseAnalytics();

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: 'Cari Runners',
        theme: new ThemeData(
          primarySwatch: Colors.blue,
          accentColor: Colors.lightBlue,
        ),
        home: new MainPage(analytics: analytics));
  }
}

class MainPage extends StatefulWidget {
  MainPage({Key key, this.analytics}) : super(key: key);

  final FirebaseAnalytics analytics;

  @override
  createState() => new _MainPageState(analytics);
}

class _MainPageState extends State<MainPage> {
  _MainPageState(this.analytics);

  final FirebaseAnalytics analytics;
  final FirebaseMessaging _firebaseMessaging = new FirebaseMessaging();
  final Action<bool> remoteIsDirtyAction = new Action<bool>();
  String status;
  List<FavoriteModel> favoriteList = [];

  @override
  void initState() {
    super.initState();
    _configureFirebaseMessaging();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return new CupertinoTabScaffold(
      tabBar: new CupertinoTabBar(
        items: const <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            title: const Text('Home'),
          ),
          const BottomNavigationBarItem(
            icon: const Icon(Icons.favorite),
            title: const Text('Favorites'),
          ),
          const BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            title: const Text('Settings'),
          ),
        ],
        activeColor: Theme.of(context).primaryColor,
      ),
      tabBuilder: (BuildContext context, int index) {
        return new CupertinoTabView(
          onGenerateRoute: (RouteSettings settings) {
            if (settings.name == '/') {
              return new MaterialPageRoute<Null>(
                settings: settings,
                builder: (BuildContext context) {
                  switch (index) {
                    case 0:
                      return new HomeTab(
                          analytics: analytics,
                          remoteIsDirtyAction: remoteIsDirtyAction,
                          favoriteList: favoriteList,
                          onFavoriteAdded: _handleFavoriteAdded,
                          onFavoriteRemoved: _handleFavoriteRemoved);
                      break;
                    case 1:
                      return new FavoriteTab(
                          analytics: analytics,
                          status: status,
                          favoriteList: favoriteList,
                          onFavoriteAdded: _handleFavoriteAdded,
                          onFavoriteRemoved: _handleFavoriteRemoved);
                      break;
                    case 2:
                      return new SettingTab();
                      break;
                    default:
                      break;
                  }
                },
                maintainState: true,
              );
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildDialog(BuildContext context, PostItem item) {
    return new AlertDialog(
      content: new Text(item.title),
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

  void _configureFirebaseMessaging() {
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) {
        debugPrint("onMessage: $message");
        _showPostItemDialog(message);
        remoteIsDirtyAction(true);
      },
      onLaunch: (Map<String, dynamic> message) {
        debugPrint("onLaunch: $message");
        _navigateToPostItem(message);
        remoteIsDirtyAction(true);
      },
      onResume: (Map<String, dynamic> message) {
        debugPrint("onResume: $message");
        _navigateToPostItem(message);
        remoteIsDirtyAction(true);
      },
    );
    _firebaseMessaging.requestNotificationPermissions(
        const IosNotificationSettings(sound: true, badge: true, alert: true));
    _firebaseMessaging.onIosSettingsRegistered
        .listen((IosNotificationSettings settings) {
      debugPrint("Settings registered: $settings");
    });
    _firebaseMessaging.getToken().then((String token) {
      assert(token != null);
      debugPrint("Push Messaging token: $token");
    });
  }

  void _handleFavoriteAdded(FavoriteModel model) {
    setState(() {
      status = null;
      favoriteList.add(model);
    });
  }

  void _handleFavoriteRemoved(FavoriteModel model) {
    setState(() {
      favoriteList.remove(model);
      if (favoriteList == null || favoriteList.isEmpty) {
        status = "No Favorite Found";
        favoriteList = [];
      }
    });
  }

  void _loadData() async {
    String status;
    List<FavoriteModel> favoriteList = [];
    try {
      favoriteList = await queryAllFavorites();
      if (favoriteList == null || favoriteList.isEmpty) {
        status = "No Favorite Found";
        favoriteList = [];
      }
    } catch (exception) {
      status = exception.toString();
    }
    setState(() {
      this.status = status;
      this.favoriteList = favoriteList;
    });
  }

  Future<Null> _navigateToPostItem(Map<String, dynamic> message) async {
    final PostItem item = _postItemForMessage(message);
    // Clear away dialogs
    Navigator.popUntil(context, (Route<dynamic> route) => route is PageRoute);
    FavoriteModel model;
    for (FavoriteModel favorite in favoriteList) {
      if (favorite.urlPath == (item.urlPath)) {
        model = favorite;
        break;
      }
    }
    if (model == null) {
      model = new FavoriteModel(null, item.title, item.urlPath);
    }
    Navigator.push(
        context,
        new MaterialPageRoute(
          builder: (context) => new FirebaseMessagingPostPage(
              analytics: analytics,
              model: model,
              favoriteList: favoriteList,
              onFavoriteAdded: _handleFavoriteAdded,
              onFavoriteRemoved: _handleFavoriteRemoved),
        ));
  }

  PostItem _postItemForMessage(Map<String, dynamic> message) {
    String title;
    String urlPath;
    if (message['data'] == null) {
      title = message['title'];
      urlPath = Uri.parse(message['url']).path;
      debugPrint("message['url']: $message['url']");
    } else {
      title = message['data']['title'];
      urlPath = Uri.parse(message['data']['url']).path;
      debugPrint("message['data']['url']: $message['data']['url']");
    }
    return new PostItem(title: title, urlPath: urlPath);
  }

  void _showPostItemDialog(Map<String, dynamic> message) {
    showDialog<bool>(
      context: context,
      builder: (_) => _buildDialog(context, _postItemForMessage(message)),
    ).then((bool shouldNavigate) {
      if (shouldNavigate == true) {
        _navigateToPostItem(message);
      }
    });
  }
}

class HomeTab extends StatefulWidget {
  HomeTab(
      {Key key,
      this.analytics,
      this.remoteIsDirtyAction,
      this.favoriteList,
      this.onFavoriteAdded,
      this.onFavoriteRemoved})
      : super(key: key);

  final FirebaseAnalytics analytics;
  final Action<bool> remoteIsDirtyAction;
  final List<FavoriteModel> favoriteList;
  final ValueChanged<FavoriteModel> onFavoriteAdded;
  final ValueChanged<FavoriteModel> onFavoriteRemoved;

  @override
  createState() => new _HomeTabState(analytics);
}

class _HomeTabState extends State<HomeTab> {
  _HomeTabState(this.analytics);

  final FirebaseAnalytics analytics;
  bool loading = true;
  String status;
  List<dom.Element> elementList = [];
  HomeTabSearchDelegate delegate;

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.remoteIsDirtyAction.listen(_handleRemoteIsDirty);
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: _buildAppBar(context), body: _buildBody(context));
  }

  Widget _buildAppBar(BuildContext context) {
    return new AppBar(title: const Text("Cari Runners"), actions: <Widget>[
      loading
          ? const Icon(null)
          : new IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () async {
                final dom.Element selected = await showSearch<dom.Element>(
                    context: context, delegate: delegate);
                if (selected != null) {
                  FavoriteModel model = _getFavoriteModel(selected);
                  Navigator.push(
                      context,
                      new MaterialPageRoute(
                        builder: (context) => new PostPage(
                            analytics: analytics,
                            model: model,
                            favoriteList: widget.favoriteList,
                            onFavoriteAdded: widget.onFavoriteAdded,
                            onFavoriteRemoved: widget.onFavoriteRemoved),
                      ));
                }
              },
            ),
    ]);
  }

  Widget _buildBody(BuildContext context) {
    if (_showLoadingDialog()) {
      return _buildProgressDialog();
    } else if (_showStatus()) {
      return _buildStatus();
    } else {
      return _buildListView(context, elementList);
    }
  }

  Widget _buildListView(BuildContext context, List<dom.Element> itemList) {
    return new Scrollbar(
        child: new RefreshIndicator(
      child: new ListView.builder(
          itemCount: itemList.length,
          itemBuilder: (context, position) {
            return _buildListViewRow(context, position, itemList);
          }),
      onRefresh: _refresh,
    ));
  }

  Widget _buildListViewRow(
      BuildContext context, int position, List<dom.Element> itemList) {
    String title = itemList[position].text;
    String urlPath = Uri
        .parse(itemList[position].querySelector("a").attributes["href"])
        .path;
    FavoriteModel model;
    bool isFavorited = false;
    for (FavoriteModel favorite in widget.favoriteList) {
      if (favorite.urlPath == (urlPath)) {
        model = favorite;
        isFavorited = true;
        break;
      }
    }
    ;
    if (model == null) {
      model = new FavoriteModel(null, title, urlPath);
    }
    return new GestureDetector(
      child: new Container(
          child: new Padding(
              padding: new EdgeInsets.all(16.0),
              child: new Row(
                children: <Widget>[
                  new Expanded(
                      child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      new Text(
                        title,
                        style: Theme.of(context).textTheme.subhead,
                      )
                    ],
                  )),
                  new FavoriteIconButton(model, isFavorited,
                      widget.onFavoriteAdded, widget.onFavoriteRemoved),
                ],
              )),
          decoration: new BoxDecoration(
              border:
                  new Border(bottom: new BorderSide(color: Colors.grey[200])))),
      onTap: () {
        Navigator.push(
            context,
            new MaterialPageRoute(
              builder: (context) => new PostPage(
                  analytics: analytics,
                  model: model,
                  favoriteList: widget.favoriteList,
                  onFavoriteAdded: widget.onFavoriteAdded,
                  onFavoriteRemoved: widget.onFavoriteRemoved),
            ));
      },
    );
  }

  Widget _buildProgressDialog() {
    return new Center(child: new CircularProgressIndicator());
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
                  _loadData();
                });
              },
              child: new Text('RETRY'),
            ),
          ],
        ),
      ),
    ));
  }

  FavoriteModel _getFavoriteModel(dom.Element item) {
    String title = item.text;
    String urlPath = Uri.parse(item.querySelector("a").attributes["href"]).path;
    FavoriteModel model;
    bool isFavorited = false;
    for (FavoriteModel favorite in widget.favoriteList) {
      if (favorite.urlPath == (urlPath)) {
        model = favorite;
        isFavorited = true;
        break;
      }
    }
    if (model == null) {
      model = new FavoriteModel(null, title, urlPath);
    }
    return model;
  }

  void _handleRemoteIsDirty(bool remoteIsDirty) {
    if (remoteIsDirty) {
      setState(() {
        loading = true;
        _loadData();
      });
    }
  }

  _loadData() async {
    String status;
    List<dom.Element> elementList = [];
    try {
      String dataUrl =
          "https://www.googleapis.com/blogger/v3/blogs/9027509069015616506/pages/6337578441124076615?key=AIzaSyDGktXyn4O-hKkVkVFna7NQOrEOxfcwqTA";
      http.Response response = await http.get(dataUrl);
      Map map = json.decode(response.body);
      dom.Document document = parse(map["content"]);
      elementList = document.querySelectorAll("ul li");
      if (elementList == null || elementList.isEmpty) {
        status = "No Content Found";
        elementList = [];
      }
    } catch (exception) {
      status = exception.toString();
    }
    setState(() {
      this.loading = false;
      this.status = status;
      this.elementList = elementList;
      this.delegate = new HomeTabSearchDelegate(data: elementList, history: []);
    });
  }

  Future<Null> _refresh() async {
    _loadData();
  }

  bool _showLoadingDialog() {
    return loading;
  }

  bool _showStatus() {
    return status != null;
  }
}

class FavoriteTab extends StatefulWidget {
  FavoriteTab(
      {Key key,
      this.analytics,
      this.status,
      this.favoriteList,
      this.onFavoriteAdded,
      this.onFavoriteRemoved})
      : super(key: key);

  final FirebaseAnalytics analytics;
  final String status;
  final List<FavoriteModel> favoriteList;
  final ValueChanged<FavoriteModel> onFavoriteAdded;
  final ValueChanged<FavoriteModel> onFavoriteRemoved;

  @override
  createState() => new _FavoriteTabState(analytics);
}

class _FavoriteTabState extends State<FavoriteTab> {
  _FavoriteTabState(this.analytics);

  final FirebaseAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text('Cari Runners'),
        ),
        body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (_showStatus()) {
      return _buildStatus();
    } else {
      return _buildListView(context);
    }
  }

  Widget _buildListView(BuildContext context) {
    return new Scrollbar(
        child: new ListView.builder(
            itemCount: widget.favoriteList.length,
            itemBuilder: (context, position) {
              return _buildListViewRow(context, position);
            }));
  }

  Widget _buildListViewRow(BuildContext context, int position) {
    FavoriteModel model = widget.favoriteList[position];
    String title = model.title;
    String urlPath = model.urlPath;
    return new GestureDetector(
      child: new Container(
          child: new Padding(
              padding: new EdgeInsets.all(16.0),
              child: new Row(
                children: <Widget>[
                  new Expanded(
                      child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      new Text(
                        title,
                        style: Theme.of(context).textTheme.subhead,
                      )
                    ],
                  )),
                  new FavoriteIconButton(model, true, widget.onFavoriteAdded,
                      widget.onFavoriteRemoved),
                ],
              )),
          decoration: new BoxDecoration(
              border:
                  new Border(bottom: new BorderSide(color: Colors.grey[200])))),
      onTap: () {
        Navigator.push(
            context,
            new MaterialPageRoute(
              builder: (context) => new PostPage(
                  analytics: analytics,
                  model: model,
                  favoriteList: widget.favoriteList,
                  onFavoriteAdded: widget.onFavoriteAdded,
                  onFavoriteRemoved: widget.onFavoriteRemoved),
            ));
      },
    );
  }

  Widget _buildStatus() {
    return new Container(
        child: new Padding(
      padding: new EdgeInsets.all(16.0),
      child: new Center(
        child: new Text(widget.status),
      ),
    ));
  }

  bool _showStatus() {
    return widget.status != null;
  }
}

class SettingTab extends StatefulWidget {
  @override
  createState() => new SettingTabState();
}

class SettingTabState extends State<SettingTab> {
  PackageInfo _packageInfo = new PackageInfo(
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text('Cari Runners'),
        ),
        body: _buildBody());
  }

  Widget _buildBody() {
    return new DecoratedBox(
      decoration: const BoxDecoration(color: const Color(0xFFEFEFF4)),
      child: new ListView(
        children: <Widget>[
          const Padding(padding: const EdgeInsets.only(top: 32.0)),
          new GestureDetector(
            child: new Container(
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
                    new Text("Privary Policy",
                        style: Theme.of(context).textTheme.body1),
                  ],
                ),
              ),
            ),
            onTap: () {
              launch("https://carirunners.blogspot.com/p/privacy-policy.html");
            },
          ),
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

  Future<Null> _initPackageInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }
}

class PostPage extends StatefulWidget {
  PostPage(
      {Key key,
      this.analytics,
      this.model,
      this.favoriteList,
      this.onFavoriteAdded,
      this.onFavoriteRemoved})
      : super(key: key);

  final FirebaseAnalytics analytics;
  final FavoriteModel model;
  final List<FavoriteModel> favoriteList;
  final ValueChanged<FavoriteModel> onFavoriteAdded;
  final ValueChanged<FavoriteModel> onFavoriteRemoved;

  @override
  createState() => new _PostPageState(analytics);
}

class _PostPageState extends State<PostPage> {
  _PostPageState(this.analytics);

  final FirebaseAnalytics analytics;
  bool loading = true;
  String status;
  String title;
  String logo;
  String content;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    bool isFavorited = false;
    for (FavoriteModel favorite in widget.favoriteList) {
      if (favorite.urlPath == (widget.model.urlPath)) {
        isFavorited = true;
        break;
      }
    }
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('Cari Runners'),
        actions: <Widget>[
          new FavoriteIconButton(widget.model, isFavorited,
              widget.onFavoriteAdded, widget.onFavoriteRemoved),
        ],
      ),
      body: _buildBody(context),
    );
  }

  _buildBody(BuildContext context) {
    if (_showLoadingDialog()) {
      return _buildProgressDialog();
    } else if (_showStatus()) {
      return _buildStatus();
    } else {
      return _buildListView(context);
    }
  }

  _buildListView(BuildContext context) {
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

  _buildProgressDialog() {
    return new Center(child: new CircularProgressIndicator());
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
                  _loadData();
                });
              },
              child: new Text('RETRY'),
            ),
          ],
        ),
      ),
    ));
  }

  _loadData() async {
    String status;
    String title;
    String logo;
    String content;
    try {
      String dataUrl =
          "https://www.googleapis.com/blogger/v3/blogs/9027509069015616506/posts/bypath?key=AIzaSyDGktXyn4O-hKkVkVFna7NQOrEOxfcwqTA&path=";
      http.Response response = await http.get(dataUrl + widget.model.urlPath);
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
      List<String> northernList = ["perlis", "kedah", "penang", "perak"];
      List<String> eastCoastList = ["kelantan", "terengganu", "pahang"];
      List<String> centralList = ["selangor", "kuala lumpur", "putrajaya"];
      List<String> southernList = ["negeri sembilan", "melaka", "johor"];
      List<String> eastMalaysiaList = ["sarawak", "sabah", "labuan"];
      List<String> labels = List.from(map["labels"]);
      if (labels != null && labels.isNotEmpty) {
        String eventName = "view_item";
        loop:
        for (String label in labels) {
          if (northernList.any((location) => location.contains(label))) {
            eventName += "_northern";
            break loop;
          } else if (eastCoastList
              .any((location) => location.contains(label))) {
            eventName += "_eastcoast";
            break loop;
          } else if (centralList.any((location) => location.contains(label))) {
            eventName += "_central";
            break loop;
          } else if (southernList.any((location) => location.contains(label))) {
            eventName += "_southern";
            break loop;
          } else if (eastMalaysiaList
              .any((location) => location.contains(label))) {
            eventName += "_eastmalaysia";
            break loop;
          }
        }
        Map<String, dynamic> parameters = {
          'item_category': labels.toString(),
        };
        _sendAnalyticsEvent(eventName, parameters);
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

  Future<Null> _sendAnalyticsEvent(
      String name, Map<String, dynamic> parameters) async {
    await analytics.logEvent(
      name: name,
      parameters: parameters,
    );
    debugPrint('logEvent(name: $name, parameters: $parameters)');
  }

  _showLoadingDialog() {
    return loading;
  }

  bool _showStatus() {
    return status != null;
  }
}

class FirebaseMessagingPostPage extends StatefulWidget {
  FirebaseMessagingPostPage(
      {Key key,
      this.analytics,
      this.model,
      this.favoriteList,
      this.onFavoriteAdded,
      this.onFavoriteRemoved})
      : super(key: key);

  final FirebaseAnalytics analytics;
  final FavoriteModel model;
  final List<FavoriteModel> favoriteList;
  final ValueChanged<FavoriteModel> onFavoriteAdded;
  final ValueChanged<FavoriteModel> onFavoriteRemoved;

  @override
  createState() => new _FirebaseMessagingPostPageState(analytics);
}

class _FirebaseMessagingPostPageState extends State<FirebaseMessagingPostPage> {
  _FirebaseMessagingPostPageState(this.analytics);

  final FirebaseAnalytics analytics;
  bool isFavorited = false;
  bool loading = true;
  String status;
  String title;
  String logo;
  String content;

  @override
  void initState() {
    super.initState();
    _initFavorite();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('Cari Runners'),
        actions: <Widget>[
          new IconButton(
              icon: (isFavorited
                  ? new Icon(Icons.favorite)
                  : new Icon(Icons.favorite_border)),
              onPressed: _toggle)
        ],
      ),
      body: _buildBody(context),
    );
  }

  _buildBody(BuildContext context) {
    if (_showLoadingDialog()) {
      return _buildProgressDialog();
    } else if (_showStatus()) {
      return _buildStatus();
    } else {
      return _buildListView(context);
    }
  }

  _buildListView(BuildContext context) {
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

  _buildProgressDialog() {
    return new Center(child: new CircularProgressIndicator());
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
                  _loadData();
                });
              },
              child: new Text('RETRY'),
            ),
          ],
        ),
      ),
    ));
  }

  void _initFavorite() {
    for (FavoriteModel favorite in widget.favoriteList) {
      if (favorite.urlPath == (widget.model.urlPath)) {
        setState(() {
          isFavorited = true;
        });
        break;
      }
    }
  }

  _loadData() async {
    String status;
    String title;
    String logo;
    String content;
    try {
      String dataUrl =
          "https://www.googleapis.com/blogger/v3/blogs/9027509069015616506/posts/bypath?key=AIzaSyDGktXyn4O-hKkVkVFna7NQOrEOxfcwqTA&path=";
      http.Response response = await http.get(dataUrl + widget.model.urlPath);
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
      List<String> northernList = ["perlis", "kedah", "penang", "perak"];
      List<String> eastCoastList = ["kelantan", "terengganu", "pahang"];
      List<String> centralList = ["selangor", "kuala lumpur", "putrajaya"];
      List<String> southernList = ["negeri sembilan", "melaka", "johor"];
      List<String> eastMalaysiaList = ["sarawak", "sabah", "labuan"];
      List<String> labels = List.from(map["labels"]);
      if (labels != null && labels.isNotEmpty) {
        String eventName = "view_item";
        loop:
        for (String label in labels) {
          if (northernList.any((location) => location.contains(label))) {
            eventName += "_northern";
            break loop;
          } else if (eastCoastList
              .any((location) => location.contains(label))) {
            eventName += "_eastcoast";
            break loop;
          } else if (centralList.any((location) => location.contains(label))) {
            eventName += "_central";
            break loop;
          } else if (southernList.any((location) => location.contains(label))) {
            eventName += "_southern";
            break loop;
          } else if (eastMalaysiaList
              .any((location) => location.contains(label))) {
            eventName += "_eastmalaysia";
            break loop;
          }
        }
        Map<String, dynamic> parameters = {
          'item_category': labels.toString(),
        };
        _sendAnalyticsEvent(eventName, parameters);
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

  Future<Null> _sendAnalyticsEvent(
      String name, Map<String, dynamic> parameters) async {
    await analytics.logEvent(
      name: name,
      parameters: parameters,
    );
    debugPrint('logEvent(name: $name, parameters: $parameters)');
  }

  _showLoadingDialog() {
    return loading;
  }

  bool _showStatus() {
    return status != null;
  }

  void _toggle() async {
    if (isFavorited) {
      await deleteFavorite(widget.model.urlPath);
      widget.onFavoriteRemoved(widget.model);
    } else {
      await insertFavorite(widget.model);
      widget.onFavoriteAdded(widget.model);
    }
    setState(() {
      isFavorited = !isFavorited;
    });
  }
}

class PostItem {
  final String title;
  final String urlPath;

  PostItem({this.title, this.urlPath});
}
