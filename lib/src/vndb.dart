import 'dart:convert';

import 'package:fimber_io/fimber_io.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:neko_launcher_neo/src/stylesheet.dart';
import 'package:neko_launcher_neo/main.dart';
import 'package:url_launcher/url_launcher.dart';

class VNDB extends ChangeNotifier {
  static Uri apiUrl = Uri.parse("https://api.vndb.org/kana/vn");

  String? id;
  String? title;
  double? rating;
  DateTime? released;
  String? description;
  double? length;
  String displayTitle = "???";

  VNDB(this.id);

  VNDB.fromTitle(this.title);

  Future<VNDB> getInfo() async {
    Map<String, dynamic> query = {
      "fields": "id, title, titles{title, latin, official, main, lang}, released, rating, description, length_minutes",
      "results": 1,
      "sort": "popularity",
      "reverse": true
    };
    if (id == null || id == "") {
      Fimber.i("Getting VNDB info of $title");
      query["filters"] = ["search", "=", title];
    } else {
      Fimber.i("Getting VNDB info of $id");
      query["filters"] = ["id", "=", id];
    }

    await http.post(
      apiUrl,
      headers: {"Content-Type": "application/json"},
      body: json.encode(query)
    ).then((res) {
      var response = json.decode(res.body);
      var titleList = response["results"][0]["titles"] as List<dynamic>;
      var defaultTitle = response["results"][0]["title"];
      var originalTitle = titleList.singleWhere((title) => title["main"])["title"];
      // ignore: avoid_init_to_null
      var englishTitle = null;
      try {
        englishTitle = titleList.singleWhere((title) => title["lang"] == "en")["title"];
      } catch (e) {
        //
      }
      id = response["results"][0]["id"];
      switch (launcherConfig.vndbTitles) {
        case "original":
          displayTitle = originalTitle ?? defaultTitle;
          break;
        case "english":
          displayTitle = englishTitle ?? defaultTitle;
          break;
        default:
          displayTitle = defaultTitle;
      }
      rating ??= response["results"][0]["rating"] + 0.0;
      released ??= DateTime.parse(response["results"][0]["released"]);
      description ??= response["results"][0]["description"];
      length ??= response["results"][0]["length_minutes"] / 60.0;
      Fimber.i("Successfully processed response from VNDB");
      notifyListeners();
      return this;
    });
    return this;
  }
}

class VNDBCard extends StatefulWidget {
  final VNDB vndb;
  
  const VNDBCard({Key? key, required this.vndb}) : super(key: key);

  @override
  VNDBCardState createState() => VNDBCardState();
}

class VNDBCardState extends State<VNDBCard> {
  void refreshState() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.vndb.addListener(refreshState);
  }

  @override
  void dispose() {
    super.dispose();
    widget.vndb.removeListener(refreshState);
  }

  @override
  Widget build(BuildContext context) {
    Fimber.i("(VNDB: ${widget.vndb.id}) Building VNDBCard widget.");
    return NekoCard(
      title: "VNDB",
      body: Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.vndb.rating != null ? Color.lerp(Colors.red, Colors.green, ((widget.vndb.rating ?? 0) * 1.6 - 40) / 100) : Colors.grey,
                  borderRadius: BorderRadius.circular(8)
                ),
                child: SizedBox.square(
                  dimension: 80,
                  child: Center(
                    child: Text(
                      "${widget.vndb.rating?.round() ?? '?'}",
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vndb.displayTitle,
                      style: const TextStyle(
                          fontSize: 24,
                      ),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    Text(
                      "(${widget.vndb.released?.year ?? 'Unknown release'})",
                      style: const TextStyle(
                            fontSize: 16,
                      ),
                    ),
                    Text(
                      "Average play time: ${widget.vndb.length?.toStringAsFixed(1) ?? '?'} hours",
                      style: const TextStyle(
                          fontSize: 16,
                      ),
                      overflow: TextOverflow.fade,
                      softWrap: false,
                    ),
                  ],
                ),
              ),
            )
          ]
        ),
      ),
      actions: ButtonBar(
        alignment: MainAxisAlignment.start,
        children: [
          TextButton(
            onPressed: widget.vndb.id != null ? 
              () => launchUrl(Uri.parse("https://vndb.org/${widget.vndb.id}"))
              : null,
            child: const Text("View on VNDB")
          )
        ],
      ),
    );
  }
}