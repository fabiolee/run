import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'html_text_view.dart';

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
  List<dom.Element> widgets = [];

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
