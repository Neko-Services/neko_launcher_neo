import 'dart:io';

import 'package:fimber_io/fimber_io.dart';
import 'package:flutter/material.dart';

import 'package:neko_launcher_neo/main.dart';
import 'package:neko_launcher_neo/src/games.dart';
import 'package:neko_launcher_neo/src/social.dart';

class GameDaemon extends ChangeNotifier {
  static Game? activeGame;

  void play(Game game) async {
    activeGame = game;

    var exec = game.exec;
    List<String> args = [];
    if (exec.isEmpty) {
      return;
    }
    if (game.emulate == true) {
      exec = launcherConfig.lePath;
      args.add(game.exec);
    }
    var start = DateTime.now();
    Fimber.i("(Game: ${game.name}) Launching: $exec");
    userProfile?.updateActivity(ActivityType.game, details: game.name);
    Process.run(exec, args, runInShell: game.emulate ? false : true)
        .then((value) {
      activeGame = null;
      userProfile?.updateActivity(ActivityType.online);
      var end = DateTime.now();
      var diff = end.difference(start);
      Fimber.i("(Game: ${game.name}) Finished in ${diff.inSeconds}s");
      game.time += diff.inSeconds;
      var activityKey = game.datePattern.format(start);
      stdout.writeln("Activity key: $activityKey");
      if (game.activity.containsKey(activityKey)) {
        game.activity[activityKey] += diff.inSeconds;
      } else {
        game.activity[activityKey] = diff.inSeconds;
      }
      game.save();
    });
  }
}
