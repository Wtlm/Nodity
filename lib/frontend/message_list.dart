import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../assets/colors/color_palette.dart';
import '../backend/service/conversation_service.dart';
// import '../backend/model/conversation.dart';
import 'message_detail.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ConversationService _chatroom = ConversationService();
  List<Map<String, dynamic>> messageList = [];
  final _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _chatroom.chatRoomsStream(_currentUserId).listen((rooms) {
      if (!mounted) return;
      setState(() {
        messageList =
            rooms.map((room) {
              final participants = room['participants'] as List<dynamic>?;
              
              // Handle unreadCount - could be Map or null
              int unreadValue = 0;
              final unreadCountRaw = room['unreadCount'];
              if (unreadCountRaw is Map) {
                unreadValue = (unreadCountRaw[_currentUserId] as int?) ?? 0;
              }
              
              // Handle lastMessage - could be String, Map, or null
              String lastMessageText = '';
              final lastMessageRaw = room['lastMessage'];
              if (lastMessageRaw is String) {
                lastMessageText = lastMessageRaw;
              } else if (lastMessageRaw is Map) {
                lastMessageText = (lastMessageRaw['content'] as String?) ?? '';
              }
              
              return {
                'name': participants?.firstWhere(
                  (id) => id != _currentUserId,
                  orElse: () => 'Unknown',
                ) ?? 'Unknown', // Get the other user's name
                'image': room['image'] ?? '', // Placeholder for user image
                'roomId': room['roomId'],
                'lastMessage': lastMessageText,
                'time':
                    room['updatedAt'] != null
                        ? DateTime.parse(room['updatedAt']).toLocal().toString()
                        : '',
                'unread': unreadValue,
                'online':
                    room['online'] ?? false, // Placeholder for online status
              };
            }).toList();
      });
    });
  }

  // final List<Map<String, dynamic>> messages = [
  //   {
  //     'name': 'Shane Martinez',
  //     'message': 'On my way home but I needed to stop by the book store to...',
  //     'time': '5 min',
  //     'unread': 1,
  //     'image': 'https://via.placeholder.com/150',
  //     'online': true,
  //   },
  //   {
  //     'name': 'Katie Keller',
  //     'message': "I'm watching Friends. What are you doing?",
  //     'time': '15 min',
  //     'unread': 0,
  //     'image': 'https://via.placeholder.com/150',
  //     'online': false,
  //   },
  //   {
  //     'name': 'Stephen Mann',
  //     'message': "I'm working now. I'm making a deposit for our company.",
  //     'time': '1 hour',
  //     'unread': 0,
  //     'image': 'https://via.placeholder.com/150',
  //     'online': true,
  //   },
  //   {
  //     'name': 'Shane Martinez',
  //     'message': 'I really find the subject very interesting. I’m enjoying all my...',
  //     'time': '5 hour',
  //     'unread': 0,
  //     'image': 'https://via.placeholder.com/150',
  //     'online': false,
  //   },
  //   {
  //     'name': 'Melvin Pratt',
  //     'message': "Great seeing you. I have to go now. I'll talk to you later.",
  //     'time': '6 hour',
  //     'unread': 0,
  //     'image': 'https://via.placeholder.com/150',
  //     'online': false,
  //   },
  // ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: ColorPalette.lightGreen,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatroom.chatRoomsStream(_currentUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final messageList = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.all(10),
            itemCount: messageList.length,
            itemBuilder: (context, index) {
              final room = messageList[index];
              return ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ChatScreen(
                            name: room['name'],
                            image: room['image'],
                            roomId: room['roomId'],
                          ),
                    ),
                  );
                },
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage:
                          (room['image'] != null && room['image'].isNotEmpty)
                              ? NetworkImage(room['image'])
                              : AssetImage('lib/assets/images/avatar.png')
                                  as ImageProvider,
                    ),
                    if (room['online'])
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
                  room['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        (room['unread'] > 0 ||
                                (room['lastMessage'] == null) || (room['lastMessage'].isEmpty))
                            ? ColorPalette.darkGreen
                            : Colors.black45,
                  ),
                ),
                subtitle: Text(
                  (room['lastMessage'] ?? '').isNotEmpty
                      ? room['lastMessage']
                      : 'Tap to start chatting',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color:
                        (room['unread'] > 0 ||
                                (room['lastMessage'] == null) || (room['lastMessage'].isEmpty))
                            ? Colors.black
                            : Colors.black26,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ((room['lastMessage'] == null) || (room['lastMessage'].isEmpty))
                          ? ''
                          : room['time'],
                      style: TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                    if (room['unread'] > 0)
                      Container(
                        margin: EdgeInsets.only(top: 5),
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: ColorPalette.lightGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          room['unread'].toString(),
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
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
