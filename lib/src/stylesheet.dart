import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fimber_io/fimber_io.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'package:neko_launcher_neo/main.dart';

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
]);

abstract class Styles {
  static const bold = TextStyle(fontWeight: FontWeight.bold);
  static const summary = TextStyle(fontSize: 24);
  static const cardPadding = EdgeInsets.all(24.0);
  static const cardHeader =
      TextStyle(fontSize: 36, fontWeight: FontWeight.bold);
  static const splash = 20.0;
  static const duration = Duration(milliseconds: 200);

  static Map<String, String> prettyTime(time) {
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
      text = d == 1 ? "$d day" : "${((d * 100) ~/ 10) / 10} days";
    }

    var sentenceTime =
        d >= 1 ? "${((h * 100) ~/ 10) / 10} hours" : "$m minutes";

    var anecdote = "";

    if (s < 600) {
      anecdote = "You couldn't really have done anything in that time.";
    } else if (s >= 600 && s < 1440) {
      var times = s ~/ 600;
      anecdote = times == 1
          ? "In this time you could've watched an average YouTube video."
          : "In this time you could've watched, like, $times average YouTube videos.";
    } else if (s >= 1440 && s < 7200) {
      var times = s ~/ 1440;
      anecdote = times == 1
          ? "In this time you could've watched one whole anime episode."
          : "In this time you could've watched, like, $times anime episodes.";
    } else if (s >= 7200 && s < 17280) {
      var times1 = s ~/ 5400;
      var times2 = s ~/ 7200;
      anecdote = times2 == 1
          ? "In this time you could've watched at least one whole movie."
          : times1 == times2
              ? "In this time you could've watched, like, $times1 movies."
              : "In this time you could've watched, like, somewhere between $times2 and $times1 movies.";
    } else if (s >= 17280 && s < 28800) {
      anecdote =
          "In that time you could've watched one whole one-cour anime series.";
    } else if (s >= 28800 && s < 34560) {
      anecdote = "In that time you could've gotten a healthy amount of sleep.";
    } else if (s >= 34560 && s < 6912000) {
      if (s >= 86400 && s < 100000) {
        anecdote =
            "They say Rome wasn't built in a day; have you at least finished playing this game in that amount of time?";
      } else if (s >= 259200 && s < 275000) {
        anecdote =
            "Jesus managed to die and get reborn in 3 days. What did you accomplish in that time?";
      } else if (s >= 396000 && s < 420000) {
        anecdote =
            "In that time you probably could've walked on foot from Kraków to Gdańsk, about 600km.";
      } else if (s >= 527040 && s < 552240) {
        anecdote = "In that time you could've watched Bleach in its entirety.";
      } else if (s >= 552240 && s < 580000) {
        anecdote =
            "In that time you could've watched Bleach in its entirety, movies and specials included.";
      } else {
        var times1 = s ~/ 34560;
        var times2 = s ~/ 17280;
        anecdote = times2 == 2
            ? "In that time you could've watched one whole two-cour anime series."
            : times1 == 1
                ? "In that time you could've watched one whole two-cour anime series or $times2 one-cour anime series."
                : "In that time you could've watched $times1 two-cour anime series or $times2 one-cour anime series.";
      }
    } else {
      anecdote =
          "In that time you could've probably traveled around the world in a fucking hot air balloon, and God knows what else.";
    }

    return {
      "text": text,
      "sentence": sentenceTime,
      "anecdote": anecdote,
    };
  }
}

class NekoCard extends Card {
  final String? title;
  final Widget body;
  final Widget? actions;

  NekoCard(
      {Key? key, this.title, this.body = const SizedBox.shrink(), this.actions})
      : super(
            key: key,
            child: Padding(
              padding: Styles.cardPadding,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title != null
                        ? Text(title, style: Styles.cardHeader)
                        : const SizedBox.shrink(),
                    const SizedBox(
                      height: 8,
                    ),
                    body,
                    if (actions != null) const Divider(),
                    if (actions != null) actions
                  ]),
            ));
}

class NekoPathSuffix extends StatelessWidget {
  final GlobalKey<FormFieldState> fieldKey;
  final FileType type;
  final List<String>? extensions;

  const NekoPathSuffix(
      {Key? key, required this.fieldKey, required this.type, this.extensions})
      : super(
          key: key,
        );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: IconButton(
          splashRadius: Styles.splash,
          icon: const Icon(Icons.create_new_folder),
          onPressed: () {
            FilePicker.platform
                .pickFiles(type: type, allowedExtensions: extensions)
                .then((result) {
              if (result != null) {
                fieldKey.currentState!.didChange(result.files.single.path);
              }
            });
          }),
    );
  }
}

class NekoBackground extends StatefulWidget {
  final Widget child;

  const NekoBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<NekoBackground> createState() => NekoBackgroundState();
}

class NekoBackgroundState extends State<NekoBackground> {
  Widget background = const SizedBox.shrink();
  String link = "";
  int games = 0;
  int time = 0;

  @override
  void initState() {
    super.initState();
    changeBackground();
    updateSummary();
  }

  void updateSummary() {
    var newGames = listKey.currentState?.games.length ?? 0;
    var newTime = listKey.currentState?.games.map((game) => game.time).reduce((value, element) => value + element) ?? 0;

    setState(() {
      time = newTime;
      games = newGames;
    });
  }

  void changeBackground() {
    Fimber.i("Sending request to Gelbooru...");
    http
        .get(Uri.parse(
            'https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1&limit=1&tags=${launcherConfig.gelbooruTags.trim().replaceAll(" ", "+")}+-video+sort:random'))
        .then((response) {
      var json = jsonDecode(response.body);
      Fimber.i("Received and decoded response from Gelbooru.");
      var post = json["post"][0];
      var img = post["file_url"];
      var id = post["id"];
      var ratio = post["height"] / post["width"];
      var safe = post["rating"] == "safe";
      setState(() {
        link = "https://gelbooru.com/index.php?page=post&s=view&id=$id";
        background = FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: img,
          fit: BoxFit.cover,
          alignment:
              (ratio >= 1.2 && safe) ? Alignment.topCenter : Alignment.center,
          // alignment: Alignment.center,
        );
      });
      Fimber.i("Successfully set background to $img.");
    });
  }

  @override
  Widget build(BuildContext context) {
    Fimber.i("Building the NekoBackground widget.");
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        Opacity(
          opacity: 0.2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: background),
            ],
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    tooltip: "Change background",
                    splashRadius: Styles.splash,
                    onPressed: changeBackground,
                    icon: const Icon(Icons.refresh)),
                IconButton(
                    tooltip: "Open background on Gelbooru",
                    splashRadius: Styles.splash,
                    onPressed: link == ""
                        ? null
                        : () {
                            launchUrl(Uri.parse(link));
                          },
                    icon: const Icon(Icons.open_in_browser))
              ],
            ),
          ],
        ),
        Opacity(
          opacity: 0.6,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "$games games",
                  style: Styles.summary,
                ),
                Text(
                  "${Styles.prettyTime(time)['text']} spent gaming",
                  style: Styles.summary
                ),
              ],
            ),
          ),
        ),
        widget.child
      ],
    );
  }
}

class UpdateChecker extends StatefulWidget {
  const UpdateChecker({Key? key}) : super(key: key);

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  String newestVersion = "";
  String releaseLink = "";
  bool updateAvailable = false;

  @override
  void initState() {
    super.initState();
    Fimber.i("Checking for updates...");
    http.get(Uri.parse(
            "https://api.github.com/repos/Neko-Services/neko_launcher_neo/releases"))
        .then((response) {
      var json = jsonDecode(response.body);
      Fimber.i("Received and decoded response from GitHub.");
      setState(() {
        newestVersion = json[0]["tag_name"];
        releaseLink = json[0]["html_url"];
        updateAvailable = newestVersion != launcherVersion;
      });
      Fimber.i("Successfully set newest version to $newestVersion.");
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
        icon: Icon(newestVersion == launcherVersion
            ? Icons.check
            : newestVersion == ""
                ? Icons.help
                : Icons.warning),
        label: Text(newestVersion == launcherVersion
            ? "Up to date"
            : newestVersion == ""
                ? "Update status unknown"
                : "New version available!"),
        onPressed: updateAvailable
            ? () {
                launchUrl(Uri.parse(releaseLink));
              }
            : null);
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final error = ModalRoute.of(context)!.settings.arguments;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "An error occurred! :(",
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.arrow_left),
              label: const Text("Back"),
              onPressed: () {
                Navigator.of(context).pushReplacementNamed("/");
              },
            ),
          ],
        ),
      ),
    );
  }
}
