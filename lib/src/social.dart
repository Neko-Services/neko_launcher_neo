import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:fimber_io/fimber_io.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  List<String> friends;
  bool isFriend;
  List<NekoUser> friendProfiles = [];

  NekoUser(
      {required this.uid,
      required this.name,
      required this.activityType,
      required this.activity,
      required this.lastActivity,
      required this.friends,
      this.avatar = "https://neko.nil.services/neko64.png",
      this.isFriend = false}) {
    Fimber.i("Creating $name's profile. (UID: $uid)");
    pb.collection("profiles").subscribe(uid, (e) {
      name = e.record!.getStringValue("name");
      activityType = ActivityType.values[e.record!.getIntValue("activity_type")];
      activity = e.record!.getStringValue("activity_details");
      lastActivity = DateTime.tryParse(e.record!.getStringValue("activity_timestamp")) ?? DateTime.now();
      avatar = e.record!.getStringValue("avatar").isEmpty
      ? "https://neko.nil.services/neko64.png"
      : "https://neko.nil.services/api/files/profiles/$uid/${e.record!.getStringValue('avatar')}";
      friends = isFriend ? [] : e.record!.getListValue<String>("friends");
    });
    if (!isFriend) {
      pb.realtime.subscribe("heartbeat", (e) { });
      for (var friend in friends) {
        pb.collection("profiles").getFirstListItem("user.id = '$friend'").then((friendRow) {
          friendProfiles.add(NekoUser.fromRow(friendRow, isFriend: true));
        });
      }
    }
  }

  factory NekoUser.fromRow(RecordModel row, {bool isFriend = false}) {
    return NekoUser(
      uid: row.id,
      name: row.getStringValue("name"),
      activityType: ActivityType.values[row.getIntValue("activity_type")],
      activity: row.getStringValue("activity_details"),
      lastActivity: DateTime.tryParse(row.getStringValue("activity_timestamp")) ?? DateTime.now(),
      avatar: row.getStringValue("avatar").isEmpty
      ? "https://neko.nil.services/neko64.png"
      : "https://neko.nil.services/api/files/profiles/${row.id}/${row.getStringValue('avatar')}",
      friends: isFriend ? [] : row.getListValue<String>("friends"),
      isFriend: isFriend
    );
  }

  void updateActivity(ActivityType type, {String? details}) {
    pb.collection("profiles").update(uid, body: {
      "activity_type": type.index,
      "activity_details": details ?? "",
      "activity_timestamp": DateTime.now().toUtc().toIso8601String()
    });
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
      final response = await pb.collection("profiles").getFirstListItem("user.id = '${pb.authStore.model.id}'");
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
    List<TableRow> friendsList = [];
    for (var friend in userProfile!.friendProfiles) {
      friendsList.add(TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(radius:48, backgroundColor: Colors.transparent, foregroundImage: NetworkImage(friend.avatar)),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(friend.name, style: const TextStyle(fontSize: 20)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              friend.activityText(),
            ],
          ),
        ]
      ));
    }
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
                    pb.realtime.unsubscribe();
                    userProfile!.updateActivity(ActivityType.offline);
                    userProfile!.removeListener(refreshState);
                    userProfile = null;
                    pb.authStore.clear();
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
                                  FilePicker.platform.pickFiles(type: FileType.image).then((result) async {
                                    //* The image must be under 5MB in size
                                    if (result != null && result.files.single.size < 5000000) {
                                      final path = result.files.single.path!;
                                      pb.collection("profiles").update(userProfile!.uid, files: [
                                        await http.MultipartFile.fromPath("avatar", path)
                                      ]);
                                    } else {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Error"),
                                          content: const Text(
                                              "The image must be under 5MB in size."),
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
                                },
                              ),
                            ),
                            Text(
                              userProfile!.name,
                              style: const TextStyle(fontSize: 24),
                            ),
                            userProfile?.activityText() ?? const SizedBox.shrink(),
                            const Divider(),
                            const Text("Friends", style: Styles.cardHeader,),
                            SingleChildScrollView(
                              child: Table(
                                columnWidths: const {
                                  0: FixedColumnWidth(80),
                                  1: IntrinsicColumnWidth()
                                },
                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                children: friendsList,
                              ),
                            )
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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Image.asset(
                        "assets/discord.png",
                        height: 16,
                        isAntiAlias: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const Text("Sign in using Discord"),
                  ],
                ),
                onPressed: () {
                  pb.collection("users").authWithOAuth2("discord", (url) {
                    launchUrl(url);
                  }).then((authRecord) {
                    if (authRecord.record != null) {
                      pb.collection("profiles").getFullList(filter: "user.id = '${authRecord.record!.id}'").then((list) {
                        if (list.isEmpty) {
                          pb.collection("profiles").create(body: {
                            "user": authRecord.record!.id,
                            "name": authRecord.record!.getStringValue("username"),
                            "public": true
                          });
                        }
                        userProfile = NekoUser.fromRow(list[0]);
                        Navigator.of(context).pop();
                      });
                    }
                  });
                }
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Image.asset(
                        "assets/github.png",
                        height: 16,
                        isAntiAlias: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const Text("Sign in using Github"),
                  ],
                ),
                onPressed: () {
                  pb.collection("users").authWithOAuth2("github", (url) {
                    launchUrl(url);
                  }).then((authRecord) {
                    if (authRecord.record != null) {
                      pb.collection("profiles").getFullList(filter: "user.id = '${authRecord.record!.id}'").then((list) {
                        if (list.isEmpty) {
                          pb.collection("profiles").create(body: {
                            "user": authRecord.record!.id,
                            "name": authRecord.record!.getStringValue("username"),
                            "activity_type": 0,
                            "public": true
                          });
                        }
                        userProfile = NekoUser.fromRow(list[0]);
                        Navigator.of(context).pop();
                      });
                    }
                  });
                }
                ),
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
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter your e-mail.";
                                  } 
                                  return null;
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                key: _signinPasswordKey,
                                decoration:
                                    const InputDecoration(labelText: "Password"),
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter your password.";
                                  } 
                                  return null;
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                  child: const Text("Sign in"),
                                  onPressed: () async {
                                    if (_signinKey.currentState!.validate()) {
                                      pb.collection("users").authWithPassword(_signinEmailKey.currentState!.value, _signinPasswordKey.currentState!.value).then((authRecord) {
                                        if (authRecord.record != null) {
                                          pb.collection("profiles").getFirstListItem("user.id = '${authRecord.record!.id}'").then((record) {
                                            userProfile = NekoUser.fromRow(record);
                                            Navigator.of(context).pop();
                                          });
                                        }
                                      }, onError: (error) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text("Error"),
                                            content: Text(error.response["message"]),
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
                                      });
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
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                decoration:
                                    const InputDecoration(labelText: "Username"),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter your username.";
                                  }
                                  if (value.length < 3) {
                                    return "Username must be at least 3 characters.";
                                  }
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
                                    return "Please enter your e-mail.";
                                  }
                                  if (!RegExp(
                                          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                      .hasMatch(value)) {
                                    return "Please enter a valid e-mail.";
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
                                    return "Please enter your password.";
                                  }
                                  if (value.length < 8) {
                                    return "Password must be at least 8 characters long.";
                                  }
                                  if (!value.contains(RegExp(r"[0-9]"))) {
                                    return "Password must contain at least one number.";
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
                                    return "Please confirm your password.";
                                  }
                                  if (value !=
                                      _signupPasswordKey.currentState!.value) {
                                    return "Passwords do not match.";
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
                                      pb.collection("users").create(body: {
                                        "username": _signupUsernameKey.currentState!.value,
                                        "email": _signupEmailKey.currentState!.value,
                                        "password": _signupPasswordKey.currentState!.value,
                                        "passwordConfirm": _signupConfirmKey.currentState!.value
                                      }).then((authRecord) {
                                        pb.collection("users").authWithPassword(_signupUsernameKey.currentState!.value, _signupPasswordKey.currentState!.value).then((_) {
                                          pb.collection("profiles").create(body: {
                                          "user": authRecord.id,
                                          "name": _signupUsernameKey.currentState!.value,
                                          "public": true
                                        }).then((record) {
                                            userProfile = NekoUser.fromRow(record);
                                            Navigator.of(context).pop();
                                          });
                                        });
                                      }).catchError((error) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text("Error"),
                                            content: Text("${(error.response['data']['username'] != null) ? 'Username already in use.' : ''} ${(error.response['data']['email'] != null) ? 'E-mail already in use.' : ''}".trim()),
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
                                      });
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
