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
  static const cardPadding = EdgeInsets.all(24.0);
  static const cardHeader =
      TextStyle(fontSize: 36, fontWeight: FontWeight.bold);
  static const splash = 20.0;
  static const duration = Duration(milliseconds: 200);
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
  State<NekoBackground> createState() => _NekoBackgroundState();
}

class _NekoBackgroundState extends State<NekoBackground> {
  Widget background = const SizedBox.shrink();
  String link = "";

  @override
  void initState() {
    super.initState();
    changeBackground();
  }

  void changeBackground() {
    Fimber.i("Sending request to Gelbooru...");
    http
        .get(Uri.parse(
            'https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1&limit=1&tags=${launcherConfig.gelbooruTags.trim().replaceAll(" ", "+")}+-webm+-mp4+sort:random'))
        .then((response) {
      var json = jsonDecode(response.body);
      Fimber.i("Received and decoded response from Gelbooru.");
      var post = json["post"][0];
      var img = post["file_url"];
      var id = post["id"];
      // var ratio = post["height"] / post["width"];
      setState(() {
        link = "https://gelbooru.com/index.php?page=post&s=view&id=$id";
        background = FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: img,
          fit: BoxFit.cover,
          // alignment: ratio >= 1.2 ? Alignment.topCenter : Alignment.center,
          alignment: Alignment.center,
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
                            launch(link);
                          },
                    icon: const Icon(Icons.open_in_browser))
              ],
            ),
          ],
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
    http
        .get(Uri.parse(
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
                launch(releaseLink);
              }
            : null);
  }
}
