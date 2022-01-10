import "dart:io";
import "package:flutter/material.dart";
import "package:file_picker/file_picker.dart";
import 'package:neko_launcher_neo/src/stylesheet.dart';
import "package:window_size/window_size.dart";

import "src/games.dart";
import "src/settings.dart";

final navigatorKey = GlobalKey<NavigatorState>();
final listKey = GlobalKey<GameListState>();

final gamesFolder =
    Directory(Platform.environment["APPDATA"]! + "\\neko-launcher\\games");

final launcherConfig = LauncherConfig(
    File(Platform.environment["APPDATA"]! + "\\neko-launcher\\config.json"));

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setWindowTitle("Neko Launcher");
  setWindowMinSize(const Size(1000, 563));
  if (!gamesFolder.existsSync()) {
    gamesFolder.createSync(recursive: true);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
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
            margin: EdgeInsets.all(24),
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
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.primary,
        label: const Text("Add game"),
        icon: const Icon(Icons.add),
        onPressed: () {
          FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ["exe"],
          ).then((result) {
            if (result != null) {
              Game.fromExe(
                result.files.single.path!,
              );
            }
          });
        },
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Opacity(
              opacity: 0.5,
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
              style: Theme.of(context).textTheme.headline4,
              textAlign: TextAlign.center,
            ),
            IconButton(
                tooltip: "Launcher settings",
                splashRadius: Styles.splash,
                onPressed: () => Navigator.of(context, rootNavigator: true)
                    .pushNamed("/settings"),
                icon: const Icon(Icons.settings)),
          ],
        ),
      ),
    );
  }
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
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
  bool _pendingChanges = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Neko Launcher Settings"),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                tooltip: "Open JSON in text editor",
                splashRadius: Styles.splash,
                icon: const Icon(Icons.edit),
                onPressed: () => {
                  Process.run(
                      "start", ['"edit"', launcherConfig.configFile.path],
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
                    TextFormField(
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
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value != null && !value.endsWith("LEProc.exe")) {
                          return "Path must point to LEProc.exe, LocaleEmulator's main executable.";
                        }
                        return null;
                      },
                      onSaved: (value) {
                        launcherConfig.lePath = value ?? launcherConfig.lePath;
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
