import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fimber_io/fimber_io.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:neko_launcher_neo/main.dart';
import 'package:neko_launcher_neo/src/stylesheet.dart';
import 'package:url_launcher/url_launcher.dart';

enum ActivityType { offline, online, game }

class NekoUser extends ChangeNotifier {
  String uid;
  String name;
  ActivityType activityType;
  String? activity;
  DateTime? lastActivity;
  String avatar;

  NekoUser(
      {required this.uid,
      required this.name,
      required this.activityType,
      required this.activity,
      required this.lastActivity,
      this.avatar =
          "https://byxhhsabmioakiwfrcud.supabase.in/storage/v1/object/public/avatars/neko64.png"}) {
    Fimber.i("Creating $name's profile. (UID: $uid)");
    //TODO: Profile subscription
  }

  factory NekoUser.fromRow(RecordModel row) {
    return NekoUser(
      uid: row.getStringValue("id"),
      name: row.getStringValue("name"),
      activityType: ActivityType.values[row.getIntValue("activity_type")],
      activity: row.getStringValue("activity_details"),
      lastActivity: row.getDataValue<DateTime>("activity_timestamp"),
      avatar: row.getStringValue("avatar"),
    );
  }

  void updateActivity(ActivityType type, {String? details}) {
    stdout.writeln("Updating activity");
    //TODO: Implement activity update
  }

  Widget activityText() {
    Duration duration =
        lastActivity?.difference(DateTime.now()).abs() ?? const Duration();
    switch (activityType) {
      case ActivityType.offline:
        return const Text.rich(
          TextSpan(text: "Offline"),
          style: TextStyle(color: Colors.grey),
        );
      case ActivityType.online:
        return const Text.rich(
          TextSpan(text: "Online"),
          style: TextStyle(color: Colors.blue),
        );
      case ActivityType.game:
        return Text.rich(
          TextSpan(children: [
            const TextSpan(text: "Playing "),
            TextSpan(text: activity, style: Styles.bold),
            const TextSpan(text: " for "),
            TextSpan(
                text:
                    "${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}",
                style: Styles.bold),
          ]),
          style: const TextStyle(color: Colors.green),
        );
    }
  }
}

class Social extends StatefulWidget {
  const Social({Key? key}) : super(key: key);

  @override
  State<Social> createState() => _SocialState();
}

class _SocialState extends State<Social> {
  bool _isLoading = true;
  late Timer _timer;

  void refreshState() {
    setState(() {});
  }

  Future<void> _load() async {
    try {
      final response = await pb.collection("profiles").getFirstListItem("user.id = '${pb.authStore.model.getStringValue('id')}'");
      userProfile = NekoUser.fromRow(response);
    } catch (e) {
      Fimber.e("Error loading user profile: $e");
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, "/error", arguments: e);
    }
  }

  @override
  void initState() {
    super.initState();
    if (userProfile == null) {
      _load().then((_) {
        if (userProfile != null) {
          setState(() {
            _isLoading = false;
            userProfile!.addListener(refreshState);
          });
        }
      });
    } else {
      _isLoading = false;
      userProfile!.addListener(refreshState);
    }
    _timer =
        Timer.periodic(const Duration(seconds: 1), (timer) => refreshState());
  }

  @override
  void dispose() {
    userProfile?.removeListener(refreshState);
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : Scaffold(
            appBar: AppBar(
              title: Text("${userProfile!.name}'s Social"),
              actions: [
                IconButton(
                  tooltip: "Log out",
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: () {
                    pb.authStore.clear();
                    userProfile!.removeListener(refreshState);
                    userProfile = null;
                    Navigator.pushReplacementNamed(
                      context,
                      "/",
                    );
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 64,
                              backgroundColor: Colors.transparent,
                              backgroundImage:
                                  NetworkImage(userProfile!.avatar),
                              child: IconButton(
                                splashRadius: 64,
                                color: Colors.transparent,
                                tooltip: "Change avatar",
                                constraints: const BoxConstraints(
                                    minHeight: 128, minWidth: 128),
                                icon: const Icon(Icons.camera_alt),
                                onPressed: () {
                                  {
                                    FilePicker.platform
                                        .pickFiles(
                                      type: FileType.image,
                                    )
                                        .then((result) {
                                      //* The image must be under 5MB in size
                                      if (result != null &&
                                          result.files.single.size < 5000000) {
                                        //TODO: Implement avatar change
                                      } else {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text("Error"),
                                            content: const Text(
                                                "The image must be under 2MB in size."),
                                            actions: [
                                              TextButton(
                                                child: const Text("OK"),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              )
                                            ],
                                          ),
                                        );
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            Text(
                              userProfile!.name,
                              style: const TextStyle(fontSize: 24),
                            ),
                            userProfile?.activityText() ??
                                const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
  }
}

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final _signinKey = GlobalKey<FormState>();
  final _signupKey = GlobalKey<FormState>();

  final _signinEmailKey = GlobalKey<FormFieldState>();
  final _signinPasswordKey = GlobalKey<FormFieldState>();

  final _signupUsernameKey = GlobalKey<FormFieldState>();
  final _signupEmailKey = GlobalKey<FormFieldState>();
  final _signupPasswordKey = GlobalKey<FormFieldState>();
  final _signupConfirmKey = GlobalKey<FormFieldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Sign in or sign up"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              ElevatedButton(child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Image.network(
                      "https://assets-global.website-files.com/6257adef93867e50d84d30e2/636e0a6cc3c481a15a141738_icon_clyde_white_RGB.png",
                      height: 16,
                      isAntiAlias: true,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const Text("Login using Discord"),
                ],
              ),
              onPressed: () {
                pb.collection("users").authWithOAuth2("discord", (url) {
                  launchUrl(url);
                });
              }
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Form(
                      key: _signinKey,
                      child: FocusTraversalGroup(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Sign in",
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                key: _signinEmailKey,
                                decoration:
                                    const InputDecoration(labelText: "E-mail"),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                key: _signinPasswordKey,
                                decoration:
                                    const InputDecoration(labelText: "Password"),
                                obscureText: true,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                  child: const Text("Sign in"),
                                  onPressed: () async {
                                    if (_signinKey.currentState!.validate()) {
                                      //TODO: Implement Login
                                    }
                                  }),
                            )
                          ],
                        ),
                      ),
                    ),
                  )),
                  const VerticalDivider(),
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Form(
                      key: _signupKey,
                      child: FocusTraversalGroup(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Create new account",
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                key: _signupUsernameKey,
                                decoration:
                                    const InputDecoration(labelText: "Username"),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter your username";
                                  }
                                  if (value.length < 3) {
                                    return "Username must be at least 3 characters";
                                  }
                                  //TODO: Implement username checking
                                  return null;
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                key: _signupEmailKey,
                                decoration:
                                    const InputDecoration(labelText: "E-mail"),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter your e-mail";
                                  }
                                  if (!RegExp(
                                          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                      .hasMatch(value)) {
                                    return "Please enter a valid e-mail";
                                  }
                                  return null;
                                },
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                key: _signupPasswordKey,
                                decoration:
                                    const InputDecoration(labelText: "Password"),
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter your password";
                                  }
                                  if (value.length < 8) {
                                    return "Password must be at least 8 characters long";
                                  }
                                  if (!value.contains(RegExp(r"[0-9]"))) {
                                    return "Password must contain at least one number";
                                  }
                                  return null;
                                },
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                key: _signupConfirmKey,
                                decoration: const InputDecoration(
                                    labelText: "Confirm password"),
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please confirm your password";
                                  }
                                  if (value !=
                                      _signupPasswordKey.currentState!.value) {
                                    return "Passwords do not match";
                                  }
                                  return null;
                                },
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                  child: const Text("Sign up"),
                                  onPressed: () {
                                    if (_signupKey.currentState!.validate()) {
                                      //TODO: Implement Signup
                                    }
                                  }),
                            )
                          ],
                        ),
                      ),
                    ),
                  ))
                ],
              ),
            ],
          ),
        ));
  }
}
