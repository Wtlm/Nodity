import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:Nodity/backend/service/conversation_service.dart';

import '../assets/colors/color_palette.dart';
import '../backend/model/message.dart';

class ChatScreen extends StatefulWidget {
  final String name;
  final String image;
  final String roomId;

  const ChatScreen({
    super.key,
    required this.name,
    required this.image,
    required this.roomId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ConversationService _messageService = ConversationService();
  final ScrollController _scrollController = ScrollController();
  final _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final ConversationService _conversationService = ConversationService();
  final TextEditingController _messageController = TextEditingController();

  List<Message> _messages = [];
  bool _isLoadingMore = false;
  QueryDocumentSnapshot? _lastDoc;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();

    // Listen to real-time stream
    _messageService.messageStream(widget.roomId).listen((snapshot) {
      final docs = snapshot.docs;

      if (docs.isNotEmpty) {
        setState(() {
          _lastDoc = docs.last;
          _messages =
              docs
                  .map(
                    (doc) =>
                        Message.fromMap(doc.data() as Map<String, dynamic>),
                  )
                  .toList();
          _hasMore =
              docs.length >= 20; // if less than 20, no more older messages
        });
      }
    });

    // Listen to scroll to detect scroll up near top for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <= 100 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMoreMessages();
      }
    });
  }

  Future<void> _loadMoreMessages() async {
    if (_lastDoc == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    final moreDocs = await _messageService.fetchMoreMessages(
      widget.roomId,
      _lastDoc!,
      limit: 20,
    );

    if (moreDocs.isNotEmpty) {
      setState(() {
        _lastDoc = moreDocs.last;
        _messages.addAll(
          moreDocs
              .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
              .toList(),
        );
      });
    } else {
      setState(() {
        _hasMore = false;
      });
    }

    setState(() {
      _isLoadingMore = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: EdgeInsets.only(
                  top: 50,
                  left: 20,
                  right: 20,
                  bottom: 30,
                ),
                decoration: BoxDecoration(
                  color: ColorPalette.darkGreen,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 210,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          CircleAvatar(
                            backgroundImage: NetworkImage(widget.image),
                          ),
                          Text(
                            widget.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // SizedBox(width: 20),
                    Container(
                      alignment: Alignment.centerRight,
                      width: 75,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          topLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.call, color: Colors.white),
                          Icon(Icons.video_call, color: Colors.white, size: 35),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              //
            ],
          ),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ColorPalette.darkGreen,
                borderRadius: BorderRadius.only(topRight: Radius.circular(40)),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child:
                    _messages.isEmpty
                        ? Center(child: Text("No messages yet"))
                        : ListView.builder(
                          reverse: true, // Newest at bottom
                          controller: _scrollController,
                          itemCount:
                              _messages.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return Center(child: CircularProgressIndicator());
                            }

                            final message = _messages[index];
                            bool isSender = message.senderId == _currentUserId;
                            return chatBubble(message.content, isSender);
                          },
                        ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(top: 15, bottom: 15),
            color: ColorPalette.lightGreen,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 300,
                  height: 50,
                  child: TextField(
                    controller: _messageController,
                    textAlignVertical: TextAlignVertical.bottom,
                    decoration: InputDecoration(
                      hintText: "Text message",
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: ColorPalette.darkGreen,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: ColorPalette.darkGreen,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  color: ColorPalette.darkGreen,
                  onPressed: () {
                    _conversationService.sendMessage(
                      widget.roomId,
                      _messageController.text.trim(),
                      _currentUserId,
                    );
                  },
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget chatBubble(String text, bool isSender) {
    return Align(
      alignment: isSender ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: isSender ? ColorPalette.darkGreen : ColorPalette.lightGreen,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: isSender ? Radius.circular(0) : Radius.circular(20),
            bottomRight: isSender ? Radius.circular(20) : Radius.circular(0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSender ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget fileBubble(String fileName, String fileSize) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: ColorPalette.darkGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: Colors.white),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  fileSize,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            SizedBox(width: 10),
            Icon(Icons.download, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
