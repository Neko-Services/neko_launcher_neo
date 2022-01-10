import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
