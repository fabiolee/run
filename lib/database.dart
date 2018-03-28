import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

final String databaseName = "run.db";
final String tableFavorite = "favorite";
final String columnAutoIncrement = "_id";
final String columnId = "id";
final String columnTitle = "title";
final String columnUrlPath = "urlPath";

class FavoriteModel {
  String id;
  String title;
  String urlPath;

  Map<String, dynamic> toMap() {
    Map map = <String, dynamic>{
      columnId: id,
      columnTitle: title,
      columnUrlPath: urlPath
    };
    return map;
  }

  FavoriteModel(this.id, this.title, this.urlPath);

  FavoriteModel.fromMap(Map map) {
    id = map[columnId];
    title = map[columnTitle];
    urlPath = map[columnUrlPath];
  }
}

class FavoriteProvider {
  final String table = tableFavorite;
  Database db;

  Future open(String path) async {
    db = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
create table $table ( 
  $columnAutoIncrement integer primary key autoincrement, 
  $columnId text, 
  $columnTitle text not null, 
  $columnUrlPath text) 
''');
    });
  }

  Future<int> insert(FavoriteModel model) async {
    return await db.insert(table, model.toMap());
  }

  Future<List<FavoriteModel>> queryAll() async {
    List<Map> maps = await db.query(table,
        columns: [columnId, columnTitle, columnUrlPath],
        where: null,
        whereArgs: null);
    if (maps.length > 0) {
      List<FavoriteModel> list = [];
      maps.forEach((map) => list.add(new FavoriteModel.fromMap(map)));
      return list;
    }
    return null;
  }

  Future<FavoriteModel> queryByUrlPath(String urlPath) async {
    List<Map> maps = await db.query(table,
        columns: [columnId, columnTitle, columnUrlPath],
        where: "$columnUrlPath = ?",
        whereArgs: [urlPath]);
    if (maps.length > 0) {
      return new FavoriteModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> delete(String urlPath) async {
    return await db
        .delete(table, where: "$columnUrlPath = ?", whereArgs: [urlPath]);
  }

  Future<int> update(FavoriteModel model) async {
    return await db.update(table, model.toMap(),
        where: "$columnUrlPath = ?", whereArgs: [model.urlPath]);
  }

  Future close() async => db.close();
}

Future<bool> deleteFavorite(String urlPath) async {
  String path = await getPath();
  FavoriteProvider provider = new FavoriteProvider();
  try {
    await provider.open(path);
    int rowNo = await provider.delete(urlPath);
    return rowNo != 0;
  } catch (exception) {
    print("#deleteFavorite(), exception: " + exception);
  } finally {
    await provider.close();
  }
  return false;
}

Future<bool> insertFavorite(FavoriteModel model) async {
  String path = await getPath();
  FavoriteProvider provider = new FavoriteProvider();
  try {
    await provider.open(path);
    int id = await provider.insert(model);
    return id != 0;
  } catch (exception) {
    print("#insertFavorite(), exception: " + exception);
  } finally {
    await provider.close();
  }
  return false;
}

Future<List<FavoriteModel>> queryAllFavorites() async {
  String path = await getPath();
  FavoriteProvider provider = new FavoriteProvider();
  try {
    await provider.open(path);
    return await provider.queryAll();
  } catch (exception) {
    print("#queryAllFavorites(), exception: " + exception);
  } finally {
    await provider.close();
  }
  return null;
}

// =================================================================================================================

Future<String> getPath() async {
  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  print(documentsDirectory);

  String path = join(documentsDirectory.path, databaseName);

  // make sure the folder exists
  Directory pathDirectory = new Directory(dirname(path));
  if (await pathDirectory.exists()) {} else {
    try {
      await pathDirectory.create(recursive: true);
    } catch (exception) {
      print("#getPath(), exception: " + exception);
    }
  }
  return path;
}

// =================================================================================================================
