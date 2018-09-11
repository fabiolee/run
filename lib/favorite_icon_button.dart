import 'package:flutter/material.dart';

import 'database.dart';

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
    return new IconButton(
        icon: (widget._isFavorited
            ? new Icon(Icons.favorite)
            : new Icon(Icons.favorite_border)),
        onPressed: _toggle);
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
