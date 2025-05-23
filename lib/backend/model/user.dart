import 'dart:ffi';

class Users {
  final String userId;
  final String name;
  final String? email;
  final String? phone ;
  final String certId;
  final bool online;
  final String photoUrl;

  Users({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.certId,
    this.online = false,
    this.photoUrl = "",
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'certId': certId,
      'online': online,
      'photoUrl': photoUrl,
    };
  }

  factory Users.fromMap(Map<String, dynamic> map) {
    final String userId = map['userId'] ?? '';

    return Users(
      userId: map['userId'],
      name: map['name'] ?? userId.substring(0, 10),
      email: map['email'],
      phone: map['phone'],
      certId: map['certId'],
      online: map['online'],
      photoUrl: map['photoUrl'],  

    );
  }
}