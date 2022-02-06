import 'dart:ui';
import 'dart:math' as maths;
import 'package:fimber_io/fimber_io.dart';
import 'package:flutter/material.dart';
import "dart:convert";
import "dart:io";
import "package:intl/intl.dart";
import "package:file_picker/file_picker.dart";
import "package:charts_flutter/flutter.dart" as charts;

import 'package:neko_launcher_neo/main.dart';
import 'package:neko_launcher_neo/src/daemon.dart';
import 'package:neko_launcher_neo/src/social.dart';
import 'package:neko_launcher_neo/src/stylesheet.dart';

class UpdateException implements Exception {
  final Object rootCause;
  UpdateException(this.rootCause);
}

class Game extends ChangeNotifier {
  late String path;
  String name = "Name missing";
  String exec = "";
  String bg = "";
  String desc = "No description.";
  int time = 0;
  List<dynamic> tags = [];
  Map<String, dynamic> activity = {};
  bool emulate = false;
  bool favourite = false;
  bool nsfw = false;
  late ImageProvider<Object> imgProvider;

  final datePattern = DateFormat("yyyy-MM-dd");

  Game(this.path) {
    Fimber.i("Creating game object from JSON $path");
    update();
  }

  Game.fromExe(this.exec) {
    Fimber.i("Creating game object from executable $exec");
    var file = File(exec);
    path = gamesFolder.path +
        "\\" +
        (file.path.split("\\").last).split(".").first +
        ".json";
    if (File(path).existsSync()) {
      path = gamesFolder.path +
          "\\" +
          (file.path.split("\\").last).split(".").first +
          DateTime.now().millisecondsSinceEpoch.toString() +
          ".json";
    }
    File(path).createSync();
    stdout.writeln(file.parent.path);
    name = file.parent.path.split("\\").last;
    save();
    resolveImageProvider();
    listKey.currentState!.loadGames();
  }

  void resolveImageProvider() {
    if (bg.startsWith("http")) {
      imgProvider = NetworkImage(bg);
    } else {
      imgProvider = FileImage(File(bg));
    }
  }

  void updateActivity() {
    var end = DateTime.now();
    var start = end.subtract(const Duration(days: 28));
    var difference = end.difference(start);
    var days = List.generate(
        difference.inDays + 1, (i) => start.add(Duration(days: i)));
    var oldAvtivity = activity;
    Map<String, dynamic> newActivity = {};
    for (var day in days) {
      newActivity[datePattern.format(day)] =
          oldAvtivity[datePattern.format(day)] ?? 0;
    }
    activity = newActivity;
  }

  void update() {
    try {
      var json = jsonDecode(File(path).readAsStringSync());
      name = json["name"] ?? "Untitled game";
      exec = json["exec"];
      bg = json["bg"] ?? "";
      desc = json["desc"] ?? "";
      time = json["time"] ?? 0;
      tags = json["tags"] ?? [];
      tags.sort();
      activity = json["activity"] ?? {};
      emulate = json["emulate"] ?? false;
      favourite = json["is_favourite"] ?? false;
      nsfw = json["nsfw"] ?? false;
      resolveImageProvider();
      updateActivity();
      notifyListeners();
    } catch (e) {
      Fimber.e("Error while updating game object: $e");
      throw UpdateException(e);
    }
  }

  void save() {
    var json = {
      "name": name,
      "exec": exec,
      "bg": bg,
      "desc": desc,
      "time": time,
      "tags": tags,
      "activity": activity,
      "emulate": emulate,
      "is_favourite": favourite,
      "nsfw": nsfw
    };
    File(path).writeAsStringSync(jsonEncode(json));
    update();
  }

  void folder() {
    Fimber.i("(Game: $name) Opening folder.");
    if (exec.isEmpty) {
      return;
    }
    Process.run("explorer", [File(exec).parent.path]);
  }

  void favouriteToggle() {
    Fimber.i("(Game: $name) Toggling favourite.");
    favourite = !favourite;
    save();
  }

  Future<void> delete(context) async {
    Fimber.i("(Game: $name) Deletion pending...");
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete $name?"),
          content: SingleChildScrollView(
            child: ListBody(
              children: const [
                Text("Are you sure you want to delete this game?"),
                Text(
                  "All recorded activity will be lost.",
                  style: Styles.bold,
                )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Yes", style: Styles.bold),
              onPressed: () {
                Fimber.i("(Game: $name) Deleting.");
                File(path).deleteSync();
                Navigator.of(context).pop();
                navigatorKey.currentState!.pushReplacementNamed("/");
                stdout.writeln("Deleted $name");
                listKey.currentState!.loadGames();
                Fimber.i(
                    "(Game: $name) Deleted the game and reloaded the game list.");
              },
            ),
            TextButton(
              child: const Text("No", style: Styles.bold),
              onPressed: () {
                Fimber.i("(Game: $name) Deletion cancelled.");
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Map<String, String> prettyTime() {
    var s = time;
    var m = s ~/ 60;
    var h = m / 60;
    var d = h / 24;

    var text = "$s seconds";
    if (m > 0 && h < 1) {
      text = m == 1 ? "$m minute" : "$m minutes";
    } else if (h >= 1 && d < 1) {
      text = h == 1
          ? "${h.toStringAsPrecision(2)} hour"
          : "${h.toStringAsPrecision(2)} hours";
    } else if (d >= 1) {
      text = d == 1
          ? "${d.toStringAsPrecision(2)} day"
          : "${d.toStringAsPrecision(2)} days";
    }

    var sentenceTime = d >= 1 ? "$h hours" : "$m minutes";

    var anecdote = "You couldn't really have done anything in that time.";

    return {
      "text": text,
      "sentence": sentenceTime,
      "anecdote": anecdote,
    };
  }
}

class ActivitySeries {
  final DateTime date;
  final int time;

  ActivitySeries({required this.date, required this.time});
}

class GameButton extends StatefulWidget {
  final Game game;
  final void Function() onTap;

  const GameButton({
    Key? key,
    required this.game,
    required this.onTap,
  }) : super(key: key);

  @override
  _GameButtonState createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool isHovering = false;

  void refreshState() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.game.addListener(refreshState);
    launcherConfig.addListener(refreshState);
  }

  @override
  void dispose() {
    widget.game.removeListener(refreshState);
    launcherConfig.removeListener(refreshState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Fimber.i("(Game: ${widget.game.name}) Building GameButton widget.");
    return (launcherConfig.hideNsfw && widget.game.nsfw)
        ? const SizedBox.shrink()
        : AnimatedContainer(
            transformAlignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..translate(isHovering ? 10.0 : 0.0, 0.0, 0.0),
            curve: Curves.easeInOut,
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.black,
              image: DecorationImage(
                filterQuality: FilterQuality.low,
                opacity: 0.33,
                image: widget.game.imgProvider,
                fit: BoxFit.cover,
              ),
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: (launcherConfig.blurNsfw && widget.game.nsfw) &&
                            !isHovering
                        ? 10.0
                        : 0.0),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onTap,
                    onHover: (val) {
                      setState(() {
                        isHovering = val;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                            child: Icon(
                              Icons.favorite,
                              color: widget.game.favourite
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.transparent,
                            ),
                          ),
                          Flexible(
                            child: Stack(
                                alignment: AlignmentDirectional.centerStart,
                                children: [
                                  Text(
                                    widget.game.name,
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: (launcherConfig.blurNsfw &&
                                                    widget.game.nsfw) &&
                                                !isHovering
                                            ? Colors.transparent
                                            : null),
                                  ),
                                  AnimatedOpacity(
                                    duration: Styles.duration,
                                    opacity: (launcherConfig.blurNsfw &&
                                                widget.game.nsfw) &&
                                            !isHovering
                                        ? 1.0
                                        : 0.0,
                                    child: const Chip(
                                        label: Text("NSFW"),
                                        backgroundColor: Colors.redAccent),
                                  ),
                                ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
  }
}

class NekoActivityChart extends StatelessWidget {
  final List<ActivitySeries> data;

  const NekoActivityChart({Key? key, required this.data}) : super(key: key);

  String timeFormatter(num? value) {
    if (value != null) {
      if (value > 3600) {
        return "${(value / 3600).toStringAsFixed(1)}h";
      } else if (value > 60) {
        return "${(value / 60).toStringAsFixed(0)}m";
      } else {
        return "${value.toStringAsFixed(0)}s";
      }
    } else {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    Fimber.i("Building NekoActivityChart widget.");
    final series = [
      charts.Series<ActivitySeries, DateTime>(
        id: 'Time',
        domainFn: (dynamic activity, _) => activity.date,
        measureFn: (dynamic activity, _) => activity.time,
        colorFn: (dynamic activity, _) => charts.ColorUtil.fromDartColor(
            Theme.of(context).colorScheme.primary),
        data: data,
      )
    ];

    var max = data.map((d) => d.time).reduce(maths.max);
    List<charts.TickSpec<num>> timeTicks = [];
    if (max > 7200) {
      for (var i = 0; i <= (max ~/ 3600) + 1; i++) {
        timeTicks.add(charts.TickSpec(i * 3600));
      }
    } else if (max > 1800) {
      for (var i = 0; i <= (max ~/ 1800) + 1; i++) {
        timeTicks.add(charts.TickSpec(i * 1800));
      }
    } else {
      for (var i = 0; i <= (max ~/ 300) + 1; i++) {
        timeTicks.add(charts.TickSpec(i * 300));
      }
    }

    List<charts.TickSpec<DateTime>> dateTicks =
        data.map((e) => charts.TickSpec(e.date)).toList();

    return charts.TimeSeriesChart(
      series,
      animate: true,
      defaultRenderer: charts.BarRendererConfig<DateTime>(),
      primaryMeasureAxis: charts.NumericAxisSpec(
        renderSpec: charts.GridlineRendererSpec(
          lineStyle: charts.LineStyleSpec(
            thickness: 1,
            color: charts.ColorUtil.fromDartColor(Colors.grey.shade800),
          ),
        ),
        tickProviderSpec: charts.StaticNumericTickProviderSpec(timeTicks),
        tickFormatterSpec: charts.BasicNumericTickFormatterSpec(timeFormatter),
      ),
      domainAxis: charts.DateTimeAxisSpec(
        renderSpec: const charts.SmallTickRendererSpec(
          labelCollisionOffsetFromAxisPx: 26,
          labelCollisionOffsetFromTickPx: 28,
          labelCollisionRotation: -45,
        ),
        tickProviderSpec: charts.StaticDateTimeTickProviderSpec(dateTicks),
        tickFormatterSpec: const charts.AutoDateTimeTickFormatterSpec(
          day: charts.TimeFormatterSpec(
            format: 'dd MMM',
            transitionFormat: 'dd MMM',
          ),
        ),
      ),
      behaviors: [
        charts.SeriesLegend(
          position: charts.BehaviorPosition.end,
          horizontalFirst: false,
          cellPadding: EdgeInsets.only(right: 4.0, bottom: 4.0),
          showMeasures: true,
          measureFormatter: timeFormatter,
        ),
      ],
    );
  }
}

class GameDetails extends StatefulWidget {
  final Game game;

  const GameDetails({Key? key, required this.game}) : super(key: key);

  @override
  GameDetailsState createState() => GameDetailsState();
}

class GameDetailsState extends State<GameDetails> {
  bool canPlay = true;
  final _tagController = TextEditingController();
  final _tagFocus = FocusNode();

  void addTag(String tag) {
    Fimber.i("(Game: ${widget.game.name}) Adding tag: $tag");
    if (widget.game.tags.contains(tag) || tag.isEmpty) {
      return;
    }
    _tagController.clear();
    widget.game.tags.add(tag);
    widget.game.save();
    _tagFocus.requestFocus();
  }

  void play() {
    setState(() {
      canPlay = false;
    });
    gameDaemon.play(widget.game);
  }

  void refreshState() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    gameDaemon.addListener(refreshState);
    widget.game.addListener(refreshState);
  }

  @override
  void dispose() {
    _tagController.dispose();
    _tagFocus.dispose();
    widget.game.removeListener(refreshState);
    gameDaemon.removeListener(refreshState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    canPlay = GameDaemon.activeGame == null;
    Fimber.i("(Game: ${widget.game.name}) Building GameDetails widget.");
    var time = widget.game.prettyTime();
    var activityData = <ActivitySeries>[];
    widget.game.activity.forEach((key, value) {
      activityData.add(ActivitySeries(
          date: widget.game.datePattern.parse(key), time: value));
    });
    return Stack(
      children: [
        Container(
            decoration: BoxDecoration(
                image: DecorationImage(
          image: widget.game.imgProvider,
          fit: BoxFit.cover,
        ))),
        Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.9),
              Colors.black.withOpacity(0.99),
            ],
          )),
        ),
        Scaffold(
            floatingActionButton: FloatingActionButton(
              child: Icon(widget.game.favourite
                  ? Icons.favorite
                  : Icons.favorite_border),
              onPressed: () => {
                setState(() => {widget.game.favouriteToggle()}),
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  width: 600,
                  duration: const Duration(seconds: 2),
                  content: Text(
                    !widget.game.favourite
                        ? "Removed ${widget.game.name} from favourites."
                        : "Added ${widget.game.name} to favourites",
                  ),
                  action: SnackBarAction(
                      label: "Undo",
                      onPressed: () => {
                            setState(() => {widget.game.favouriteToggle()})
                          }),
                ))
              },
              tooltip: widget.game.favourite
                  ? "Remove from favourites"
                  : "Add to favourites",
            ),
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              shadowColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              title: Row(
                children: [
                  Text(
                    widget.game.name,
                    style: const TextStyle(fontSize: 36),
                  ),
                  if (widget.game.nsfw)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Chip(
                        label: Text("NSFW"),
                        backgroundColor: Colors.redAccent,
                      ),
                    ),
                ],
              ),
              actions: [
                ButtonBar(
                  children: [
                    Row(
                      children: [
                        if (launcherConfig.lePath == "" &&
                            widget.game.emulate == true)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Tooltip(
                              child: Icon(
                                Icons.error,
                                color: Theme.of(context).errorColor,
                              ),
                              message:
                                  "Set LocaleEmulator path in the Launcher's settings to play.",
                            ),
                          ),
                        ElevatedButton(
                            child: Row(
                              children: widget.game.emulate == true
                                  ? ([
                                      const Icon(Icons.language),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      const Text(
                                        "スタート",
                                        style: Styles.bold,
                                      ),
                                    ])
                                  : ([
                                      const Text(
                                        "PLAY",
                                        style: Styles.bold,
                                      ),
                                    ]),
                            ),
                            onPressed: canPlay &&
                                    (launcherConfig.lePath != "" ||
                                        widget.game.emulate == false)
                                ? play
                                : null),
                      ],
                    ),
                    OutlinedButton(
                        child: const Text(
                          "FOLDER",
                          style: Styles.bold,
                        ),
                        onPressed: widget.game.folder),
                    OutlinedButton(
                        child: const Text(
                          "CONFIG",
                          style: Styles.bold,
                        ),
                        onPressed: () => navigatorKey.currentState!
                            .pushNamed("/config", arguments: widget.game)),
                  ],
                ),
              ],
            ),
            body: ListView(
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                          child: NekoCard(
                              title: time["text"],
                              body: RichText(
                                  text: TextSpan(children: [
                                const TextSpan(text: "You have played "),
                                TextSpan(
                                    text: widget.game.name, style: Styles.bold),
                                const TextSpan(text: " for "),
                                TextSpan(
                                    text: time["sentence"], style: Styles.bold),
                                const TextSpan(text: ".\n"),
                                TextSpan(text: time["anecdote"]),
                              ])))),
                      Expanded(
                        child: NekoCard(
                          title: "Tags",
                          body: Wrap(
                            children: widget.game.tags.map((tag) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Chip(
                                  onDeleted: () {
                                    widget.game.tags.remove(tag);
                                    widget.game.save();
                                  },
                                  label: Text(tag),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                ),
                              );
                            }).toList(),
                          ),
                          actions: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  focusNode: _tagFocus,
                                  controller: _tagController,
                                  decoration: const InputDecoration(
                                    labelText: "Add tag",
                                    hintText: "Tag",
                                  ),
                                  onSubmitted: addTag,
                                ),
                              ),
                              IconButton(
                                splashRadius: Styles.splash,
                                icon: const Icon(Icons.add),
                                onPressed: () =>
                                    addTag(_tagController.value.text),
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                        child: NekoCard(
                      title: "Activity",
                      body: SizedBox(
                          height: 250,
                          child: NekoActivityChart(data: activityData)),
                    ))
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child: NekoCard(
                      title: "Description",
                      body: Text(widget.game.desc),
                    ))
                  ],
                )
              ],
            )),
      ],
    );
  }
}

class GameConfig extends StatefulWidget {
  final Game game;

  const GameConfig({Key? key, required this.game}) : super(key: key);

  @override
  GameConfigState createState() => GameConfigState();
}

class GameConfigState extends State<GameConfig> {
  final _formKey = GlobalKey<FormState>();
  final _execKey = GlobalKey<FormFieldState>();
  final _bgKey = GlobalKey<FormFieldState>();
  bool pendingChanges = false;

  void highlightSave() {
    setState(() {
      pendingChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Fimber.i("(Game: ${widget.game.name}) Building GameConfig widget.");
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: Text("Editing " + widget.game.name),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                tooltip: "Open JSON in text editor",
                splashRadius: Styles.splash,
                icon: const Icon(Icons.edit),
                onPressed: () => {
                  Process.run("start", ['"edit"', widget.game.path],
                      runInShell: true)
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                tooltip: "Save changes",
                splashRadius: Styles.splash,
                icon: const Icon(
                  Icons.save,
                ),
                onPressed: !pendingChanges
                    ? null
                    : () => {
                          _formKey.currentState!.save(),
                          widget.game.save(),
                          Navigator.pop(context),
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            behavior: SnackBarBehavior.floating,
                            width: 600,
                            duration: const Duration(seconds: 2),
                            content: Text(
                              "Saved ${widget.game.name}",
                            ),
                          ))
                        },
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
              onChanged: highlightSave,
              key: _formKey,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    onSaved: (newValue) =>
                        widget.game.name = newValue ?? widget.game.name,
                    initialValue: widget.game.name,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Title",
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    key: _execKey,
                    onSaved: (newValue) =>
                        widget.game.exec = newValue ?? widget.game.exec,
                    initialValue: widget.game.exec,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: "Executable path",
                        suffixIcon: NekoPathSuffix(
                          fieldKey: _execKey,
                          type: FileType.custom,
                          extensions: const ["exe"],
                        )),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    key: _bgKey,
                    onSaved: (newValue) =>
                        widget.game.bg = newValue ?? widget.game.bg,
                    initialValue: widget.game.bg,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: "Background image path",
                        suffixIcon: NekoPathSuffix(
                          fieldKey: _bgKey,
                          type: FileType.image,
                        )),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      textAlignVertical: TextAlignVertical.top,
                      expands: true,
                      maxLines: null,
                      onSaved: (newValue) =>
                          widget.game.desc = newValue ?? widget.game.desc,
                      initialValue: widget.game.desc,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Description",
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            FormField(
                              initialValue: widget.game.emulate,
                              onSaved: (bool? newValue) => widget.game.emulate =
                                  newValue ?? widget.game.emulate,
                              builder: (FormFieldState<bool> field) {
                                return Row(
                                  children: [
                                    const Text("Emulate Locale"),
                                    Switch(
                                      value: field.value ?? false,
                                      onChanged: (bool value) =>
                                          field.didChange(value),
                                    ),
                                    if (field.hasError)
                                      Text(field.errorText ?? "",
                                          style: TextStyle(
                                              color:
                                                  Theme.of(context).errorColor))
                                  ],
                                );
                              },
                              autovalidateMode: AutovalidateMode.always,
                              validator: (value) {
                                if (value == true &&
                                    launcherConfig.lePath == "") {
                                  return "Set LocaleEmulator path in the Launcher's settings!";
                                }
                                return null;
                              },
                            ),
                            const VerticalDivider(),
                            FormField(
                              initialValue: widget.game.nsfw,
                              onSaved: (bool? newValue) => widget.game.nsfw =
                                  newValue ?? widget.game.nsfw,
                              builder: (FormFieldState<bool> field) {
                                return Row(
                                  children: [
                                    const Text("NSFW"),
                                    Switch(
                                      value: field.value ?? false,
                                      onChanged: (bool value) =>
                                          field.didChange(value),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ButtonStyle(backgroundColor:
                            MaterialStateColor.resolveWith((states) {
                          return states.contains(MaterialState.disabled)
                              ? Colors.grey.shade600.withOpacity(0.5)
                              : Colors.redAccent;
                        })),
                        child: const Text("DELETE", style: Styles.bold),
                        onPressed: () {
                          widget.game.delete(context);
                        },
                      ),
                    ],
                  ),
                )
              ])),
        ));
  }
}

class GameList extends StatefulWidget {
  const GameList({Key? key}) : super(key: key);

  @override
  GameListState createState() => GameListState();
}

enum Sorting {
  nameAsc,
  nameDesc,
  timeAsc,
  timeDesc,
}

enum Filtering { all, favourite, neverPlayed }

class GameListState extends State<GameList> {
  List<Game> games = [];
  Sorting sorting = Sorting.nameAsc;
  final _sortingKey = GlobalKey<PopupMenuButtonState>();

  void sort() {
    Fimber.i("Sorting game list: $sorting.");
    switch (sorting) {
      case Sorting.nameAsc:
        games.sort((a, b) => a.name.compareTo(b.name));
        break;
      case Sorting.nameDesc:
        games.sort((a, b) => b.name.compareTo(a.name));
        break;
      case Sorting.timeAsc:
        games.sort((a, b) => a.time.compareTo(b.time));
        break;
      case Sorting.timeDesc:
        games.sort((a, b) => b.time.compareTo(a.time));
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    loadGames();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void loadGames() {
    Fimber.i("Loading games.");
    setState(() {
      games = [];
      gamesFolder.listSync().forEach((f) {
        if (f is File) {
          try {
            games.add(Game(f.path));
          } on UpdateException catch (e) {
            Fimber.e("Failed to load ${f.path}: ${e.rootCause}");
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Fimber.i("Building GameList widget.");
    sort();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                  tooltip: "View homescreen",
                  splashRadius: Styles.splash,
                  padding: const EdgeInsets.all(1),
                  icon: const Icon(Icons.home),
                  onPressed: () {
                    navigatorKey.currentState!.pushReplacementNamed(
                      "/",
                    );
                  }),
              const Expanded(
                child: Center(
                  child: Text(
                    "Games",
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                ),
                child: PopupMenuButton(
                    key: _sortingKey,
                    tooltip: "Change sorting",
                    child: IconButton(
                      hoverColor: Theme.of(context).hoverColor,
                      splashColor: Theme.of(context).splashColor,
                      splashRadius: Styles.splash,
                      icon: const Icon(Icons.filter_list),
                      onPressed: () =>
                          _sortingKey.currentState!.showButtonMenu(),
                    ),
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<Sorting>>[
                          const PopupMenuItem<Sorting>(
                            value: Sorting.nameAsc,
                            child: Text("Name (A-Z)"),
                          ),
                          const PopupMenuItem<Sorting>(
                            value: Sorting.nameDesc,
                            child: Text("Name (Z-A)"),
                          ),
                          const PopupMenuItem<Sorting>(
                            value: Sorting.timeDesc,
                            child: Text("Most played"),
                          ),
                          const PopupMenuItem<Sorting>(
                            value: Sorting.timeAsc,
                            child: Text("Least played"),
                          ),
                        ],
                    onSelected: (Sorting s) {
                      setState(() {
                        sorting = s;
                      });
                    }),
              ),
            ],
          ),
        ),
        games.isNotEmpty
            ? Expanded(
                child: ListView.builder(
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    return GameButton(
                      game: games[index],
                      onTap: () {
                        games[index].update();
                        if (navigatorKey.currentState!.canPop()) {
                          navigatorKey.currentState!.pop();
                        }
                        navigatorKey.currentState!.pushReplacementNamed(
                          "/game",
                          arguments: games[index],
                        );
                      },
                    );
                  },
                ),
              )
            : Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text("It's empty here... ",
                            style: TextStyle(
                                fontSize: 24,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onBackground)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [Icon(Icons.arrow_forward, size: 40)],
                      ),
                    )
                  ],
                ),
              )
      ],
    );
  }
}
