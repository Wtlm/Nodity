import 'package:cloud_firestore/cloud_firestore.dart';

class Cert {
  final String certId;
  final String ownerId;
  final Map<String, dynamic> certData;
  final DateTime issuedAt;
  final DateTime expiresAt;

  Cert({
    required this.certId,
    required this.ownerId,
    required this.certData,
    required this.issuedAt,
    required this.expiresAt,
  });

  factory Cert.fromJson(String certId, Map<String, dynamic> data) => Cert(
    certId: certId,
    ownerId: data['ownerId'],
    certData: data['certData'],
    issuedAt: (data['issuedAt'] as Timestamp).toDate(),
    expiresAt: (data['expiresAt'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'certId': certId,
    'ownerId': ownerId,
    'certData': certData,
    'issuedAt': Timestamp.fromDate(issuedAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
  };
}
