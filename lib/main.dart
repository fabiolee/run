import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:package_info/package_info.dart';

import 'database.dart';
import 'html_text_view.dart';

void main() => runApp(new RunApp());

class RunApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: 'Cari Runners',
        theme: new ThemeData(
          primarySwatch: Colors.blue,
          accentColor: Colors.lightBlue,
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
      ),
      tabBuilder: (BuildContext context, int index) {
        return new CupertinoTabView(
          builder: (BuildContext context) {
            switch (index) {
              case 0:
                return new HomeTab(
                    favoriteList, _handleFavoriteAdded, _handleFavoriteRemoved);
                break;
              case 1:
                return new FavoriteTab(status, favoriteList,
                    _handleFavoriteAdded, _handleFavoriteRemoved);
                break;
              case 2:
                return new SettingTab();
                break;
              default:
                break;
            }
          },
        );
      },
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
    Navigator.push(
        context,
        new MaterialPageRoute(
          builder: (context) => new PostPage(item.urlPath),
        ));
  }

  PostItem _postItemForMessage(Map<String, dynamic> message) {
    final String urlPath = Uri.parse(message['url']).path;
    return new PostItem(urlPath: urlPath);
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
}

class HomeTab extends StatefulWidget {
  final List<FavoriteModel> favoriteList;
  final ValueChanged<FavoriteModel> onFavoriteAdded;
  final ValueChanged<FavoriteModel> onFavoriteRemoved;

  HomeTab(this.favoriteList, this.onFavoriteAdded, this.onFavoriteRemoved);

  @override
  createState() => new HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  bool loading = true;
  String status;
  List<dom.Element> elementList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text('Cari Runners'),
        ),
        body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (_showLoadingDialog()) {
      return _buildProgressDialog();
    } else if (_showStatus()) {
      return _buildStatus();
    } else {
      return _buildListView(context);
    }
  }

  Widget _buildListView(BuildContext context) {
    return new RefreshIndicator(
      child: new ListView.builder(
          itemCount: elementList.length,
          itemBuilder: (context, position) {
            return _buildListViewRow(context, position);
          }),
      onRefresh: _refresh,
    );
  }

  Widget _buildListViewRow(BuildContext context, int position) {
    String title = elementList[position].text;
    String urlPath = Uri
        .parse(elementList[position].querySelector("a").attributes["href"])
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
              builder: (context) => new PostPage(urlPath),
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
              textColor: Colors.white,
              color: Colors.blue[600],
              child: new Text('RETRY'),
            ),
          ],
        ),
      ),
    ));
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
    });
  }

  Future _refresh() async {
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
  final String status;
  final List<FavoriteModel> favoriteList;
  final ValueChanged<FavoriteModel> onFavoriteAdded;
  final ValueChanged<FavoriteModel> onFavoriteRemoved;

  FavoriteTab(this.status, this.favoriteList, this.onFavoriteAdded,
      this.onFavoriteRemoved);

  @override
  createState() => new FavoriteTabState();
}

class FavoriteTabState extends State<FavoriteTab> {
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

  ListView _buildListView(BuildContext context) => new ListView.builder(
      itemCount: widget.favoriteList.length,
      itemBuilder: (context, position) {
        return _buildListViewRow(context, position);
      });

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
              builder: (context) => new PostPage(urlPath),
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

class FavoriteIconButton extends StatefulWidget {
  final FavoriteModel _model;
  final bool _isFavorited;
  final ValueChanged<FavoriteModel> _onFavoriteAdded;
  final ValueChanged<FavoriteModel> _onFavoriteRemoved;

  FavoriteIconButton(this._model, this._isFavorited, this._onFavoriteAdded,
      this._onFavoriteRemoved);

  @override
  createState() => new FavoriteIconButtonState();
}

class FavoriteIconButtonState extends State<FavoriteIconButton> {
  @override
  Widget build(BuildContext context) {
    return new Container(
        child: new IconButton(
            icon: (widget._isFavorited
                ? new Icon(Icons.favorite)
                : new Icon(Icons.favorite_border)),
            onPressed: _toggle));
  }

  void _toggle() async {
    if (widget._isFavorited) {
      await deleteFavorite(widget._model.urlPath);
      widget._onFavoriteRemoved(widget._model);
    } else {
      await insertFavorite(widget._model);
      widget._onFavoriteAdded(widget._model);
    }
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
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Cari Runners'),
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
              textColor: Colors.white,
              color: Colors.blue[600],
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
