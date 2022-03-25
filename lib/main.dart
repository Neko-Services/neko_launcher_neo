import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_size/window_size.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fimber_io/fimber_io.dart';

import 'package:neko_launcher_neo/src/games.dart';
import 'package:neko_launcher_neo/src/stylesheet.dart';
import 'package:neko_launcher_neo/src/settings.dart';
import 'package:neko_launcher_neo/src/social.dart';
import 'package:neko_launcher_neo/src/daemon.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final listKey = GlobalKey<GameListState>();

final gamesFolder = Platform.isLinux
    ? Directory(
        Platform.environment["HOME"]! + "/.local/share/neko-launcher/games")
    : Directory(Platform.environment["APPDATA"]! + "\\neko-launcher\\games");

final launcherConfig = LauncherConfig(Platform.isLinux
    ? File(Platform.environment["HOME"]! + "/.config/neko-launcher.json")
    : File(Platform.environment["APPDATA"]! + "\\neko-launcher\\config.json"));

//! Update before publishing
const launcherVersion = "v0.2.1-alpha";

late final Supabase supabase;
final GameDaemon gameDaemon = GameDaemon();
NekoUser? userProfile;

void main() async {
  Fimber.plantTree(TimedRollingFileTree(
      filenamePrefix: "logs" + Platform.pathSeparator + "log_"));
  Fimber.i("Starting Neko Launcher...");
  Fimber.i("Ensuring game folder exists at ${gamesFolder.absolute}.");
  if (!gamesFolder.existsSync()) {
    gamesFolder.createSync(recursive: true);
  }
  WidgetsFlutterBinding.ensureInitialized();
  Fimber.i("Setting window title.");
  setWindowTitle("Neko Launcher");
  Fimber.i("Setting minimum window size.");
  setWindowMinSize(const Size(1000, 563));
  Fimber.i("Initializing Supabase connection.");
  await Supabase.initialize(
      url: "https://byxhhsabmioakiwfrcud.supabase.co",
      anonKey:
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQyMjA1NDE5LCJleHAiOjE5NTc3ODE0MTl9.DLp4O4UnN0-2JkjCArdCXt87AYd4dvaRbf_mPRBOLIo");
  supabase = Supabase.instance;
  Fimber.i("Starting Neko Launcher Neo.");
  if (supabase.client.auth.currentSession != null) {
    Fimber.i("User is logged in.");
    supabase.client
        .from("profiles")
        .select()
        .eq("id", supabase.client.auth.currentUser!.id)
        .execute()
        .then((response) {
      userProfile = NekoUser.fromRow(response.data[0]);
    });
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
          FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: Platform.isLinux ? ["exe", "sh", ""] : ["exe"],
          ).then((result) {
            if (result != null) {
              Game.fromExe(
                result.files.single.path!,
              );
            }
          });
        },
      ),
      body: NekoBackground(
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
              style: Theme.of(context).textTheme.headline4,
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
                    onPressed: () => {
                          if (supabase.client.auth.currentUser != null)
                            {
                              navigatorKey.currentState!
                                  .pushReplacementNamed("/social")
                            }
                          else
                            {
                              Navigator.of(context, rootNavigator: true)
                                  .pushNamed("/login")
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
    Fimber.i("Building the Settings screen widget.");
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
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value != null &&
                            value != "" &&
                            !value.endsWith("LEProc.exe")) {
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
                          suffixText: "-mp4 -webm sort:random",
                          labelText: "Home screen background tags",
                          hintText: "Gelbooru tags",
                          helperText:
                              "The home screen background finds images using Gelbooru. If you don't know what you're doing, leave as is or refer to their wiki (howto:search, howto:cheatsheet)."),
                      initialValue: launcherConfig.gelbooruTags,
                      onSaved: (value) {
                        launcherConfig.gelbooruTags =
                            value ?? launcherConfig.gelbooruTags;
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
