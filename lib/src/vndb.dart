import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:neko_launcher_neo/src/stylesheet.dart';
import 'package:url_launcher/url_launcher.dart';

class VNDB extends ChangeNotifier {
  static Uri apiUrl = Uri.parse("https://api.vndb.org/kana/vn");

  String? id;
  String? title;
  double? rating;
  DateTime? released;
  String? description;

  VNDB(this.id);

  VNDB.fromTitle(this.title);

  Future<VNDB> getInfo() async {
    Map<String, dynamic> query = {
      "fields": "id, title, released, rating, description",
      "results": 1,
      "sort": "popularity",
      "reverse": true
    };
    if (id == null || id == "") {
      query["filters"] = ["search", "=", title];
    } else {
      query["filters"] = ["id", "=", "$id"];
    }

    await http.post(
      apiUrl,
      headers: {"Content-Type": "application/json"},
      body: json.encode(query)
    ).then((res) {
      var response = json.decode(res.body);
      id ??= response["results"][0]["id"];
      title = response["results"][0]["title"];
      rating ??= response["results"][0]["rating"] + 0.0;
      released ??= DateTime.parse(response["results"][0]["released"]);
      description ??= response["results"][0]["description"];
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
    return NekoCard(
      title: "VNDB",
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: widget.vndb.rating != null ? Color.lerp(Colors.red, Colors.green, (widget.vndb.rating ?? 0) / 100) : Colors.grey,
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vndb.title ?? "???",
                    style: const TextStyle(
                        fontSize: 20,
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  Text(
                    "(${widget.vndb.released?.year ?? 'Unknown release'})",
                    style: const TextStyle(
                          fontSize: 20,
                    ),
                  )
                ],
              ),
            ),
          )
        ]
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