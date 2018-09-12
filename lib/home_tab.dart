import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;

class HomeTabSearchDelegate extends SearchDelegate<dom.Element> {
  HomeTabSearchDelegate({this.data, this.history});

  final List<dom.Element> data;
  final List<dom.Element> history;

  @override
  Widget buildLeading(BuildContext context) {
    return new IconButton(
      tooltip: 'Back',
      icon: new AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final Iterable<dom.Element> suggestions = query.isEmpty
        ? history
        : data.where((dom.Element item) =>
            item.text.toLowerCase().contains(query.toLowerCase()));

    return new _SuggestionList(
      query: query,
      suggestions: suggestions.toList(),
      onSelected: (dom.Element suggestion) {
        query = suggestion.text;
        // TODO: Show results with API call.
        //showResults(context);
        close(context, suggestion);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final List<dom.Element> searched = data
        .where((dom.Element item) =>
            item.text.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (searched == null || searched.isEmpty) {
      return new Center(
        child: new Text(
          '"$query" is not found.\nTry again.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return new _ResultList(
      query: query,
      results: searched,
      searchDelegate: this,
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return <Widget>[
      query.isEmpty
          ? const Icon(null)
          /*
          TODO: Voice Search
          new IconButton(
              tooltip: 'Voice Search',
              icon: const Icon(Icons.mic),
              onPressed: () {
                showDialog<Null>(
                  context: context,
                  builder: (BuildContext context) {
                    return new AlertDialog(
                      content: new Text("Voice Search Coming Soon."),
                      actions: <Widget>[
                        new FlatButton(
                          child: const Text('OK'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            )
            */
          : new IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear),
              onPressed: () {
                query = '';
                showSuggestions(context);
              },
            )
    ];
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({this.results, this.query, this.searchDelegate});

  final List<dom.Element> results;
  final String query;
  final SearchDelegate<dom.Element> searchDelegate;

  @override
  Widget build(BuildContext context) {
    return new ListView.builder(
      itemCount: results.length,
      itemBuilder: (BuildContext context, int i) {
        return _buildListViewRow(context, results[i]);
      },
    );
  }

  Widget _buildListViewRow(BuildContext context, dom.Element item) {
    final String text = item.text;
    final int startIndex = text.toLowerCase().indexOf(query.toLowerCase());
    final int endIndex = startIndex + query.length;
    return new GestureDetector(
      child: new Container(
          child: new Padding(
              padding: new EdgeInsets.all(16.0),
              child: new Row(
                children: <Widget>[
                  new Padding(
                      padding: new EdgeInsets.only(right: 32.0),
                      child: new Icon(Icons.history, color: Colors.black38)),
                  new Expanded(
                      child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildRichText(context, text, startIndex, endIndex),
                    ],
                  )),
                ],
              )),
          decoration: new BoxDecoration(
              border:
                  new Border(bottom: new BorderSide(color: Colors.grey[200])))),
      onTap: () {
        searchDelegate.close(context, item);
      },
    );
  }

  Widget _buildRichText(
      BuildContext context, String text, int startIndex, int endIndex) {
    final ThemeData theme = Theme.of(context);
    return new RichText(
      text: new TextSpan(
        text: text.substring(0, startIndex),
        style: theme.textTheme.subhead,
        children: <TextSpan>[
          new TextSpan(
            text: text.substring(startIndex, endIndex),
            style:
                theme.textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
          ),
          new TextSpan(
            text: text.substring(endIndex),
            style: theme.textTheme.subhead,
          ),
        ],
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({this.suggestions, this.query, this.onSelected});

  final List<dom.Element> suggestions;
  final String query;
  final ValueChanged<dom.Element> onSelected;

  @override
  Widget build(BuildContext context) {
    return new ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (BuildContext context, int i) {
        return _buildListViewRow(context, suggestions[i]);
      },
    );
  }

  Widget _buildListViewRow(BuildContext context, dom.Element item) {
    final String text = item.text;
    final int startIndex = text.toLowerCase().indexOf(query.toLowerCase());
    final int endIndex = startIndex + query.length;
    debugPrint(
        'text: $text, query: $query, startIndex: $startIndex, endIndex: $endIndex');
    return new GestureDetector(
      child: new Container(
          child: new Padding(
              padding: new EdgeInsets.all(16.0),
              child: new Row(
                children: <Widget>[
                  new Padding(
                      padding: new EdgeInsets.only(right: 32.0),
                      child: new Icon(Icons.history, color: Colors.black38)),
                  new Expanded(
                      child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildRichText(context, text, startIndex, endIndex),
                    ],
                  )),
                ],
              )),
          decoration: new BoxDecoration(
              border:
                  new Border(bottom: new BorderSide(color: Colors.grey[200])))),
      onTap: () {
        onSelected(item);
      },
    );
  }

  Widget _buildRichText(
      BuildContext context, String suggestion, int startIndex, int endIndex) {
    final ThemeData theme = Theme.of(context);
    return new RichText(
      text: new TextSpan(
        text: suggestion.substring(0, startIndex),
        style: theme.textTheme.subhead,
        children: <TextSpan>[
          new TextSpan(
            text: suggestion.substring(startIndex, endIndex),
            style:
                theme.textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
          ),
          new TextSpan(
            text: suggestion.substring(endIndex),
            style: theme.textTheme.subhead,
          ),
        ],
      ),
    );
  }
}
