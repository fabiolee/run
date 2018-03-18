import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;

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

class MainPageState extends State<MainPage> {
  final FirebaseMessaging _firebaseMessaging = new FirebaseMessaging();
  List<dom.Element> widgets = [];

  @override
  void initState() {
    super.initState();
    _configureFirebaseMessaging();
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

  void _configureFirebaseMessaging() {
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) {
        print("onMessage: $message");
        _navigateToPostItem(message);
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

  getBody() {
    if (showLoadingDialog()) {
      return getProgressDialog();
    } else {
      return getListView();
    }
  }

  ListView getListView() => new ListView.builder(
      itemCount: widgets.length,
      itemBuilder: (context, position) {
        return getRow(position);
      });

  getProgressDialog() {
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

  PostItem _postItemForMessage(Map<String, dynamic> message) {
    final String urlPath = Uri.parse(message['url']).path;
    return new PostItem(urlPath: urlPath);
  }

  loadData() async {
    String dataUrl =
        "https://www.googleapis.com/blogger/v3/blogs/9027509069015616506/pages/6337578441124076615?key=AIzaSyDGktXyn4O-hKkVkVFna7NQOrEOxfcwqTA";
    http.Response response = await http.get(dataUrl);
    setState(() {
      Map map = json.decode(response.body);
      dom.Document document = parse(map["content"]);
      widgets = document.querySelectorAll("ul li");
    });
  }

  Future<Null> _navigateToPostItem(Map<String, dynamic> message) async {
    final PostItem item = _postItemForMessage(message);
    // Clear away dialogs
    Navigator.popUntil(context, (Route<dynamic> route) => route is PageRoute);
    if (!item.route.isCurrent) {
      Navigator.push(context, item.route);
    }
  }

  showLoadingDialog() {
    return (widgets.length == 0);
  }
}

class PostPage extends StatefulWidget {
  final String urlPath;

  PostPage(this.urlPath);

  @override
  createState() => new PostPageState();
}

class PostPageState extends State<PostPage> {
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

  getBody() {
    if (showLoadingDialog()) {
      return getProgressDialog();
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
    String dataUrl =
        "https://www.googleapis.com/blogger/v3/blogs/9027509069015616506/posts/bypath?key=AIzaSyDGktXyn4O-hKkVkVFna7NQOrEOxfcwqTA&path=";
    http.Response response = await http.get(dataUrl + widget.urlPath);
    setState(() {
      Map map = json.decode(response.body);
      title = map["title"];
      dom.Document document = parse(map["content"]);
      dom.Element firstElement = document.querySelector("div");
      dom.Element imgElement = firstElement.querySelector("img");
      logo = imgElement.attributes["src"];
      firstElement.remove();
      content = document.body.innerHtml;
    });
  }

  showLoadingDialog() {
    return content == null;
  }
}

class PostItem {
  PostItem({this.urlPath});
  final String urlPath;

  static final Map<String, Route<Null>> routes = <String, Route<Null>>{};
  Route<Null> get route {
    final String routeName = '/post/$urlPath';
    return routes.putIfAbsent(
      routeName,
      () => new MaterialPageRoute<Null>(
            settings: new RouteSettings(name: routeName),
            builder: (BuildContext context) => new PostPage(urlPath),
          ),
    );
  }
}
