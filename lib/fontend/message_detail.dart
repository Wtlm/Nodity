import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../assets/colors/color_palette.dart';

class ChatScreen extends StatefulWidget {
  final String name;
  final String image;

  const ChatScreen({
    super.key,
    required this.name,
    required this.image});
  
  @override
  _ChatScreenState createState() => _ChatScreenState();

}
class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [

          Stack(
            children: [
              Container(
                padding: EdgeInsets.only(top:50, left: 20, right: 20, bottom: 30),
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
                          children:[
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          CircleAvatar(
                            backgroundImage: NetworkImage(widget.image),
                          ),
                          Text(widget.name, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ]
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
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(40),
                ),
              ),
              child:
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: ListView(
                    children: [
                      chatBubble("Hey 👋", true),
                      chatBubble("Are you available for a new UI project?", true),
                      chatBubble("Hello!", false),
                      chatBubble("Yes, have some space for the new task", false),
                      chatBubble("Cool, should I share the details now?", true),
                      chatBubble("Yes Sure, please", false),
                      chatBubble("Great, here is the SOW of the Project", true),
                      fileBubble("UI Brief.docx", "269.18 KB"),
                    ],
                  ),
                ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(top:15, bottom: 15),
            color: ColorPalette.lightGreen,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 300,
                  height: 50,
                  child: TextField(
                    textAlignVertical: TextAlignVertical.bottom,
                    decoration: InputDecoration(
                      hintText: "Ok. Let me check",
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: ColorPalette.darkGreen, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: ColorPalette.darkGreen, width: 1.5),
                      ),
                    ),
                  ),
                ),
                Icon(Icons.send, color: ColorPalette.darkGreen),

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
          style: TextStyle(color: isSender ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
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
                Text(fileName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                Text(fileSize, style: TextStyle(color: Colors.white70, fontSize: 12)),
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