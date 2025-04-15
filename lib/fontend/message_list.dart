import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pre_thesis_app/assets/colors/color_palette.dart';

import 'message_detail.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  _MessagesScreenState createState() => _MessagesScreenState();

}

class _MessagesScreenState extends State<MessagesScreen> {
  final List<Map<String, dynamic>> messages = [
    {
      'name': 'Shane Martinez',
      'message': 'On my way home but I needed to stop by the book store to...',
      'time': '5 min',
      'unread': 1,
      'image': 'https://via.placeholder.com/150',
      'online': true,
    },
    {
      'name': 'Katie Keller',
      'message': "I'm watching Friends. What are you doing?",
      'time': '15 min',
      'unread': 0,
      'image': 'https://via.placeholder.com/150',
      'online': false,
    },
    {
      'name': 'Stephen Mann',
      'message': "I'm working now. I'm making a deposit for our company.",
      'time': '1 hour',
      'unread': 0,
      'image': 'https://via.placeholder.com/150',
      'online': true,
    },
    {
      'name': 'Shane Martinez',
      'message': 'I really find the subject very interesting. I’m enjoying all my...',
      'time': '5 hour',
      'unread': 0,
      'image': 'https://via.placeholder.com/150',
      'online': false,
    },
    {
      'name': 'Melvin Pratt',
      'message': "Great seeing you. I have to go now. I'll talk to you later.",
      'time': '6 hour',
      'unread': 0,
      'image': 'https://via.placeholder.com/150',
      'online': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Messages', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(10),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return ListTile(
            onTap: (){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(name: message['name'], image: message['image']),
                ),
              );
            },
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: NetworkImage(message['image']),
                ),
                if (message['online'])
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              message['name'],
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (message['unread'] > 0)
                      ?ColorPalette.darkGreen
                      :Colors.black45),
            ),
            subtitle: Text(
              message['message'],
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: (message['unread'] > 0)
                  ?Colors.black
                  :Colors.black26),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  message['time'],
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
                if (message['unread'] > 0)
                  Container(
                    margin: EdgeInsets.only(top: 5),
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ColorPalette.lightGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      message['unread'].toString(),
                      style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: ColorPalette.lightGreen,
        child: Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
