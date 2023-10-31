import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fimber_io/fimber_io.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:neko_launcher_neo/src/games.dart';
import 'package:neko_launcher_neo/src/stylesheet.dart';
import 'package:neko_launcher_neo/src/settings.dart';
import 'package:neko_launcher_neo/src/social.dart';
import 'package:neko_launcher_neo/src/daemon.dart';
import 'package:window_size/window_size.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final listKey = GlobalKey<GameListState>();
final bgKey = GlobalKey<NekoBackgroundState>();

final gamesFolder = Platform.isLinux
    ? Directory("${Platform.environment["HOME"]!}/.local/share/neko-launcher/games")
    : Directory("${Platform.environment["APPDATA"]!}\\neko-launcher\\games");

final logsFolder = Platform.isLinux
    ? Directory("${Platform.environment["HOME"]!}/.local/share/neko-launcher/logs")
    : Directory("${Platform.environment["APPDATA"]!}\\neko-launcher\\logs");

final launcherConfig = LauncherConfig(Platform.isLinux
    ? File("${Platform.environment["HOME"]!}/.config/neko-launcher.json")
    : File("${Platform.environment["APPDATA"]!}\\neko-launcher\\config.json"));

//! Update before publishing
const launcherVersion = "v0.5.0-alpha";

late final PocketBase pb;
final GameDaemon gameDaemon = GameDaemon();
NekoUser? userProfile;

void main() async {
  if (!logsFolder.existsSync()) {
    logsFolder.createSync(recursive: true);
  }
  Fimber.plantTree(TimedRollingFileTree(
      filenamePrefix: "${logsFolder.path}${Platform.pathSeparator}log_"));
  Fimber.i("Initializing PocketBase connection.");
  final prefs = await SharedPreferences.getInstance();
  final store = AsyncAuthStore(
    save: (String data) async => prefs.setString("pb_auth", data),
    initial: prefs.getString("pb_auth")
  );
  pb = PocketBase("https://neko.nil.services/", authStore: store);
  Fimber.i("Starting Neko Launcher...");
  Fimber.i("Ensuring game folder exists at ${gamesFolder.absolute.path}.");
  if (!gamesFolder.existsSync()) {
    gamesFolder.createSync(recursive: true);
  }
  WidgetsFlutterBinding.ensureInitialized();
  Fimber.i("Setting minimum window size.");
  setWindowMinSize(const Size(920, 600));
  Fimber.i("Starting Neko Launcher Neo.");
  if (pb.authStore.isValid) {
    Fimber.i("User is logged in.");
    final profileData = await pb.collection("profiles").getFirstListItem("user.id = '${pb.authStore.model.id}'");
    userProfile = NekoUser.fromRow(profileData);
  } else {
    Fimber.i("User is not logged in.");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    Fimber.i("Building the top level app widget.");
    return MaterialApp(
      title: 'Neko Launcher',
      theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xff161616),
          brightness: Brightness.dark,
          primarySwatch: Colors.pink,
          snackBarTheme: SnackBarThemeData(
              backgroundColor: Colors.grey.shade900,
              contentTextStyle: const TextStyle(color: Colors.white)),
          cardTheme: const CardTheme(
            color: Color(0xff161616),
            margin: EdgeInsets.all(16),
          ),
          iconTheme: IconThemeData(color: Colors.grey.shade200),
          switchTheme: SwitchThemeData(
            thumbColor: MaterialStateColor.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.pink;
              }
              return Colors.grey.shade700;
            }),
            trackColor: MaterialStateColor.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.pink.withOpacity(0.5);
              }
              return Colors.grey.shade700.withOpacity(0.5);
            }),
          ),
          tooltipTheme: TooltipThemeData(
            decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8)),
            textStyle: TextStyle(color: Colors.grey.shade300),
          ),
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Colors.grey.shade200,
                displayColor: Colors.grey.shade200,
              ),
          colorScheme: ColorScheme(
              background: const Color(0xff161616),
              primary: Colors.pink,
              onBackground: Colors.grey.shade200,
              onPrimary: Colors.white,
              secondary: Colors.redAccent,
              onSecondary: Colors.white,
              error: Colors.redAccent,
              onError: Colors.white,
              surface: Colors.grey.shade900,
              onSurface: Colors.grey.shade200,
              brightness: Brightness.dark)),
      home: const MainScreen(title: 'Neko Launcher'),
      routes: <String, WidgetBuilder>{
        "/settings": (BuildContext context) => const SettingsScreen(),
        "/login": (BuildContext context) => const SignIn(),
        "/error": (BuildContext context) => const ErrorScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Fimber.i("Building the Home screen widget.");
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.primary,
        label: const Text("Add game"),
        icon: const Icon(Icons.add),
        onPressed: () {
          FilePicker.platform
              .pickFiles(
            type: FileType.custom,
            allowedExtensions: Platform.isLinux ? ["exe", "sh", ""] : ["exe"],
          )
              .then((result) {
            if (result != null) {
              Game.fromExe(
                result.files.single.path!,
              );
            }
          });
        },
      ),
      body: NekoBackground(
        key: bgKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const ColorFiltered(
              colorFilter: ColorFilter.matrix(<double>[
                0.8,
                0,
                0,
                0,
                0,
                0,
                0.8,
                0,
                0,
                0,
                0,
                0,
                0.8,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: Image(
                image: AssetImage("assets/neko64.png"),
                height: 64,
                width: 64,
                fit: BoxFit.contain,
                isAntiAlias: false,
              ),
            ),
            Text(
              'Neko Launcher ネオ',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    tooltip: "Launcher settings",
                    splashRadius: Styles.splash,
                    onPressed: () => Navigator.of(context, rootNavigator: true)
                        .pushNamed("/settings"),
                    icon: const Icon(Icons.settings)),
                IconButton(
                    tooltip: "Social",
                    splashRadius: Styles.splash,
                    onPressed: () {
                          listKey.currentState!.enableHome();
                          if (pb.authStore.isValid)
                            {
                              navigatorKey.currentState!
                                  .pushReplacementNamed("/social");
                            }
                          else
                            {
                              Navigator.of(context, rootNavigator: true)
                                  .pushNamed("/login");
                            }
                        },
                    icon: const Icon(Icons.person)),
              ],
            ),
            const UpdateChecker(),
          ],
        ),
      ),
    );
  }
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    Fimber.i("Building the MainScreen (layout) widget.");
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 250,
            child: GameList(key: listKey),
          ),
          Expanded(
              child: Navigator(
            key: navigatorKey,
            initialRoute: "/",
            onGenerateRoute: (RouteSettings settings) {
              WidgetBuilder builder;
              switch (settings.name) {
                case "/":
                  builder = (BuildContext context) => const Home();
                  break;
                case "/game":
                  builder = (BuildContext context) => GameDetails(
                        game: settings.arguments as Game,
                      );
                  break;
                case "/config":
                  builder = (BuildContext context) => GameConfig(
                        game: settings.arguments as Game,
                      );
                  break;
                case "/social":
                  builder = (BuildContext context) => const Social();
                  break;
                case "/error":
                  builder = (BuildContext context) => const ErrorScreen();
                  break;
                default:
                  throw Exception('Invalid route: ${settings.name}');
              }
              return MaterialPageRoute<void>(
                  builder: builder, settings: settings);
            },
          )),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _leKey = GlobalKey<FormFieldState>();
  final _gelKey = GlobalKey<FormFieldState>();
  String _logsInfo = "Calculating...";
  bool _pendingChanges = false;

  static const Map<String, String> titleHelperText = {
    "default": "The launcher will use romanized Japanese titles where possible.",
    "english": "The launcher will use translated English titles where possible.",
    "original": "The launcher will use original Japanese titles where possible."
  };

  void highlightSave() {
    setState(() {
      _pendingChanges = true;
    });
  }

  void unhighlightSave() {
    setState(() {
      _pendingChanges = false;
    });
  }

  void updateLogsSize() async {
    int fileNum = 0;
    int totalSize = 0;

    if (logsFolder.existsSync()) {
      final files = logsFolder.listSync(recursive: true);
      fileNum = files.length;
      for (final file in files) {
        if (file is File) {
          totalSize += file.lengthSync();
        }
      }
      setState(() {
        _logsInfo = "$fileNum files, ${totalSize ~/ 1024} KB";
      });
    } else {
      setState(() {
        _logsInfo = "Logs folder not found";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    updateLogsSize();
    Fimber.i("Building the Settings screen widget.");
    return Scaffold(
        appBar: AppBar(
          title: const Text("Neko Launcher Settings"),
          actions: [
            // Padding(
            //   padding: const EdgeInsets.all(8.0),
            //   child: IconButton(
            //     tooltip: "Sync from cloud",
            //     splashRadius: Styles.splash,
            //     icon: const Icon(Icons.cloud_download),
            //     onPressed: () => {},
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.all(8.0),
            //   child: IconButton(
            //     tooltip: "Save to cloud",
            //     splashRadius: Styles.splash,
            //     icon: const Icon(Icons.cloud_upload),
            //     onPressed: () => {},
            //   ),
            // ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                tooltip: "Open JSON in text editor",
                splashRadius: Styles.splash,
                icon: const Icon(Icons.edit),
                onPressed: () => {
                  if (Platform.isWindows)
                    {
                      Process.run(
                          "start", ['"edit"', launcherConfig.configFile.path],
                          runInShell: true)
                    }
                  else
                    {
                      Process.run("xdg-open", [launcherConfig.configFile.path],
                          runInShell: true)
                    }
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
                onPressed: !_pendingChanges
                    ? null
                    : () => {
                          _formKey.currentState!.save(),
                          launcherConfig.save(),
                          Navigator.pop(context),
                        },
              ),
            ),
          ],
        ),
        body: Form(
            key: _formKey,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView(
                  children: [
                    Platform.isLinux
                        ? const SizedBox.shrink()
                        : TextFormField(
                            key: _leKey,
                            decoration: InputDecoration(
                                labelText: "LocaleEmulator executable path",
                                hintText: "Path",
                                suffixIcon: NekoPathSuffix(
                                  fieldKey: _leKey,
                                  type: FileType.custom,
                                  extensions: const ["exe"],
                                )),
                            initialValue: launcherConfig.lePath,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (value) {
                              if (value != null &&
                                  value != "" &&
                                  !value.endsWith("LEProc.exe")) {
                                return "Path must point to LEProc.exe, LocaleEmulator's main executable.";
                              }
                              return null;
                            },
                            onSaved: (value) {
                              launcherConfig.lePath =
                                  value ?? launcherConfig.lePath;
                            },
                          ),
                    FormField(
                      initialValue: launcherConfig.blurNsfw,
                      onSaved: (bool? newValue) => launcherConfig.blurNsfw =
                          newValue ?? launcherConfig.blurNsfw,
                      builder: (FormFieldState<bool> field) {
                        return Row(
                          children: [
                            const Text("Blur NSFW"),
                            Switch(
                              value: field.value ?? false,
                              onChanged: (bool value) => field.didChange(value),
                            ),
                          ],
                        );
                      },
                    ),
                    FormField(
                      initialValue: launcherConfig.hideNsfw,
                      onSaved: (bool? newValue) => launcherConfig.hideNsfw =
                          newValue ?? launcherConfig.hideNsfw,
                      builder: (FormFieldState<bool> field) {
                        return Row(
                          children: [
                            const Text("Hide NSFW"),
                            Switch(
                              value: field.value ?? false,
                              onChanged: (bool value) => field.didChange(value),
                            ),
                          ],
                        );
                      },
                    ),
                    TextFormField(
                      key: _gelKey,
                      decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                                splashRadius: Styles.splash,
                                tooltip: "Restore default",
                                onPressed: () {
                                  _gelKey.currentState!.didChange(
                                      launcherConfig.defaults["gelbooruTags"]);
                                },
                                icon: const Icon(Icons.refresh)),
                          ),
                          suffixText: "-video sort:random",
                          labelText: "Home screen background tags",
                          hintText: "Gelbooru tags",
                          helperText:
                              "The home screen background finds images using Gelbooru. If you don't know what you're doing, leave as is or refer to their wiki (howto:search, howto:cheatsheet).",
                          helperStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500
                          ),
                        ),
                      initialValue: launcherConfig.gelbooruTags,
                      onSaved: (value) {
                        launcherConfig.gelbooruTags =
                            value ?? launcherConfig.gelbooruTags;
                      },
                    ),
                    FormField(
                      initialValue: launcherConfig.vndbTitles,
                      onSaved: (String? value) {
                        launcherConfig.vndbTitles = value ?? launcherConfig.vndbTitles;
                      },
                      builder: (FormFieldState<String> field) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text("Preferred VNDB titles: "),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Radio<String>(
                                            value: "default",
                                            groupValue: field.value,
                                            activeColor: Colors.pink,
                                            onChanged: (String? newValue) => field.didChange(newValue)
                                          ),
                                          const Text("Romanized")
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Radio<String>(
                                            value: "english",
                                            groupValue: field.value,
                                            activeColor: Colors.pink,
                                            onChanged: (String? newValue) => field.didChange(newValue)
                                          ),
                                          const Text("English")
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Radio<String>(
                                            value: "original",
                                            groupValue: field.value,
                                            activeColor: Colors.pink,
                                            onChanged: (String? newValue) => field.didChange(newValue)
                                          ),
                                          const Text("Original")
                                        ],
                                      ),
                                    ),
                                  const Expanded(
                                    flex: 6,
                                    child: SizedBox(),
                                  )
                                ],
                              ),
                              Text(
                                titleHelperText[field.value] ?? "",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                    Row(
                      children: [
                        const Text("Default search includes: "),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: FormField(
                            initialValue: launcherConfig.searchTitles,
                            onSaved: (bool? newValue) => launcherConfig.searchTitles =
                                newValue ?? launcherConfig.searchTitles,
                            builder: (FormFieldState<bool> field) {
                              return Row(
                                children: [
                                  Checkbox(
                                    value: field.value ?? false,
                                    onChanged: (bool? value) => field.didChange(value),
                                  ),
                                  const Text("Titles"),
                                ],
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: FormField(
                            initialValue: launcherConfig.searchTags,
                            onSaved: (bool? newValue) => launcherConfig.searchTags =
                                newValue ?? launcherConfig.searchTags,
                            builder: (FormFieldState<bool> field) {
                              return Row(
                                children: [
                                  Checkbox(
                                    value: field.value ?? false,
                                    onChanged: (bool? value) => field.didChange(value),
                                  ),
                                  const Text("Tags"),
                                ],
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: FormField(
                            initialValue: launcherConfig.searchDescs,
                            onSaved: (bool? newValue) => launcherConfig.searchDescs =
                                newValue ?? launcherConfig.searchDescs,
                            builder: (FormFieldState<bool> field) {
                              return Row(
                                children: [
                                  Checkbox(
                                    value: field.value ?? false,
                                    onChanged: (bool? value) => field.didChange(value),
                                  ),
                                  const Text("Descriptions"),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox.fromSize(size: const Size(0, 50)),
                    RichText(
                      text: TextSpan(
                          style: const TextStyle(color: Colors.grey),
                          children: [
                            const TextSpan(
                                style: Styles.bold, text: "About:\n"),
                            const TextSpan(text: "Author: Circl3s\n"),
                            const TextSpan(
                                text: "Launcher version: $launcherVersion\n"),
                            TextSpan(
                              text: "Logs: $_logsInfo",
                            )
                          ]),
                    ),
                    ButtonBar(
                      alignment: MainAxisAlignment.start,
                      children: [ElevatedButton(
                        onPressed: () => {
                          launchUrl(Uri.file(logsFolder.path))
                        },
                        child: const Text("Open logs folder"),
                      ),
                      ElevatedButton(
                        onPressed: () => {
                          launchUrl(Uri.parse("https://github.com/Neko-Services/neko_launcher_neo/wiki"))
                        },
                        child: const Text("Open wiki"),
                      )],
                    )
                  ],
                ),
              ),
            ),
            onChanged: () {
              _formKey.currentState!.validate()
                  ? highlightSave()
                  : unhighlightSave();
            }));
  }
}
