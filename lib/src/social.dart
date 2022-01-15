import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neko_launcher_neo/main.dart';

class Social extends StatefulWidget {
  const Social({Key? key}) : super(key: key);

  @override
  State<Social> createState() => _SocialState();
}

class _SocialState extends State<Social> {
  bool _isLoading = true;

  void _load() {
    supabase.client
        .from("profiles")
        .select()
        .eq("id", supabase.client.auth.currentUser!.id)
        .execute()
        .then((response) {
      setState(() {
        userProfile = response.data[0];
        _isLoading = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    if (userProfile == null) {
      _load();
    } else {
      _isLoading = false;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            appBar: AppBar(
              title: Text("${userProfile?["username"]}'s Social"),
              actions: [
                IconButton(
                  tooltip: "Log out",
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: () {
                    supabase.client.auth.signOut();
                    Navigator.pushReplacementNamed(
                      context,
                      "/",
                    );
                  },
                ),
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
          child: Row(
            children: [
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Form(
                  key: _signinKey,
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
                            onPressed: () {
                              if (_signinKey.currentState!.validate()) {
                                supabase.client.auth
                                    .signIn(
                                        email:
                                            _signinEmailKey.currentState!.value,
                                        password: _signinPasswordKey
                                            .currentState!.value)
                                    .then((response) {
                                  if (supabase.client.auth.currentSession !=
                                      null) {
                                    Navigator.of(context).pop();
                                  }
                                });
                              }
                            }),
                      )
                    ],
                  ),
                ),
              )),
              const VerticalDivider(),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Form(
                  key: _signupKey,
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
                            supabase.client
                                .from("profiles")
                                .select()
                                .eq("username", value)
                                .execute()
                                .then((response) {
                              if (response.data.length > 0) {
                                return "Username already taken";
                              }
                            });
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
                          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                              return "Password must be at least 8 characters";
                            }
                            if (!value.contains(RegExp(r"[0-9]"))) {
                              return "Password must contain at least one number";
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                            child: const Text("Sign up"),
                            onPressed: () {
                              if (_signinKey.currentState!.validate()) {
                                supabase.client.auth
                                    .signUp(_signupEmailKey.currentState!.value,
                                        _signupPasswordKey.currentState!.value)
                                    .then((value) {
                                  if (supabase.client.auth.currentSession !=
                                      null) {
                                    supabase.client
                                        .from("profiles")
                                        .insert({
                                          "id": supabase
                                              .client.auth.currentUser!.id,
                                          "username": _signupUsernameKey
                                              .currentState!.value
                                        })
                                        .execute()
                                        .then((response) {
                                          if (response.hasError) {
                                            stdout.writeln(
                                                response.error?.message);
                                          } else {
                                            userProfile = response.data;
                                            Navigator.of(context).pop();
                                          }
                                        }, onError: (error) {
                                          stdout.writeln(error);
                                        });
                                  }
                                });
                              }
                            }),
                      )
                    ],
                  ),
                ),
              ))
            ],
          ),
        ));
  }
}
