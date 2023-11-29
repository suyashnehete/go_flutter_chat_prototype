// main.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ChatScreenWithSocket(),
    );
  }
}

class ChatScreenWithSocket extends StatefulWidget {
  const ChatScreenWithSocket({super.key});

  @override
  State createState() => ChatScreenWithSocketState();
}

class ChatScreenWithSocketState extends State<ChatScreenWithSocket> {
  final TextEditingController _controller = TextEditingController();
  final IOWebSocketChannel _channel = IOWebSocketChannel.connect('ws://localhost:8080/ws?username=user1');

  @override
  void initState() {
    super.initState();
  }

  List<String> messages = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebSocket Chat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder(
                stream: _channel.stream,
                builder: (context, snapshot) {
                  print(snapshot.data);
                  if (snapshot.hasData) {
                    Map<String, dynamic> data = jsonDecode(snapshot.data);
                    messages.add("${data['from']}: ${data['message']}");
                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (cxt, idx) => Text(messages[idx]),
                    );
                  } else {
                    return Text('No messages yet.');
                  }
                },
              ),
            ),
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Send a message'),
              onChanged: (val){
                _sendMessage(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(String text) {
    Map<String, dynamic> message = {
      'from': 'user1',
      'to': 'user2',
      'message': text,
    };
    _channel.sink.add(jsonEncode(message));
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}

class ChatScreenWithoutSocket extends StatefulWidget {
  @override
  State createState() => ChatScreenWithoutSocketState();
}

class ChatScreenWithoutSocketState extends State<ChatScreenWithoutSocket> {
  final TextEditingController _controller = TextEditingController();
  String _message = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Long Polling Chat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Text('Received Message: $_message'),
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Send a message'),
            ),
            ElevatedButton(
              onPressed: _sendMessage,
              child: Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    String username = 'user1'; // Replace with the appropriate username
    String message = _controller.text;

    try {
      await http.post(
        Uri.parse('http://localhost:8080/send/$username'),
        headers: {'Content-Type': 'application/json'},
        body: '{"message": "$message"}',
      );

      // Reset the input field
      _controller.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  void _startLongPolling() async {
    String username = 'user1'; // Replace with the appropriate username

    Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        var response = await http.get(Uri.parse('http://localhost:8080/poll/$username'));

        if (response.statusCode == 200) {
          var data = response.body.isEmpty ? '' : response.body;
          setState(() {
            _message = data;
          });
        } else {
          print('Error getting message: ${response.statusCode}');
        }
      } catch (e) {
        print('Error getting message: $e');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startLongPolling();
  }
}
