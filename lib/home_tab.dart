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
        : data.where((dom.Element item) => item.text.contains(query));

    return new _SuggestionList(
      query: query,
      suggestions: suggestions.map((dom.Element item) => item).toList(),
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
    final List<dom.Element> searched = _getSearchList(data, query);
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

  List<dom.Element> _getSearchList(List<dom.Element> list, String query) {
    List<dom.Element> searchList = new List();
    for (dom.Element item in list) {
      String title = item.text;
      if (title.contains(query)) {
        searchList.add(item);
      }
    }
    return searchList;
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
        final String result = results[i].text;
        final int startIndex = result.indexOf(query);
        final int endIndex = startIndex + query.length;
        return new ListTile(
          leading: query.isEmpty ? const Icon(Icons.history) : const Icon(null),
          title: _buildRichText(context, result, startIndex, endIndex),
          onTap: () {
            searchDelegate.close(context, results[i]);
          },
        );
      },
    );
    /*
    final ThemeData theme = Theme.of(context);
    return new GestureDetector(
      onTap: () {
        searchDelegate.close(context, item);
      },
      child: new Card(
        child: new Padding(
          padding: const EdgeInsets.all(8.0),
          child: new Column(
            children: <Widget>[
              new Text(title),
              new Text(
                item.text,
                style: theme.textTheme.headline.copyWith(fontSize: 72.0),
              ),
            ],
          ),
        ),
      ),
    );
    */
  }

  Widget _buildRichText(
      BuildContext context, String text, int startIndex, int endIndex) {
    final ThemeData theme = Theme.of(context);
    if (startIndex == 0) {
      return new RichText(
        text: new TextSpan(
          text: text.substring(startIndex, endIndex),
          style: theme.textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
          children: <TextSpan>[
            new TextSpan(
              text: text.substring(endIndex),
              style: theme.textTheme.subhead,
            ),
          ],
        ),
      );
    } else {
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
        final String suggestion = suggestions[i].text;
        final int startIndex = suggestion.indexOf(query);
        final int endIndex = startIndex + query.length;
        debugPrint(
            'suggestion: $suggestion, query: $query, startIndex: $startIndex, endIndex: $endIndex');
        return new ListTile(
          leading: query.isEmpty ? const Icon(Icons.history) : const Icon(null),
          title: _buildRichText(context, suggestion, startIndex, endIndex),
          onTap: () {
            onSelected(suggestions[i]);
          },
        );
      },
    );
  }

  Widget _buildRichText(
      BuildContext context, String suggestion, int startIndex, int endIndex) {
    final ThemeData theme = Theme.of(context);
    if (startIndex == 0) {
      return new RichText(
        text: new TextSpan(
          text: suggestion.substring(startIndex, endIndex),
          style: theme.textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
          children: <TextSpan>[
            new TextSpan(
              text: suggestion.substring(endIndex),
              style: theme.textTheme.subhead,
            ),
          ],
        ),
      );
    } else {
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
}
