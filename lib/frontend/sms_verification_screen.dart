import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../assets/colors/color_palette.dart';
import '../backend/service/sms_service.dart';
import '../backend/model/signed_sms.dart';

class SmsVerificationScreen extends StatefulWidget {
  const SmsVerificationScreen({super.key});

  @override
  State<SmsVerificationScreen> createState() => _SmsVerificationScreenState();
}

class _SmsVerificationScreenState extends State<SmsVerificationScreen>
    with SingleTickerProviderStateMixin {
  final SmsService _smsService = SmsService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  
  bool _hasPermissions = false;
  bool _isMonitoring = false;
  bool _isLoading = true;
  String? _userPhoneNumber;
  
  List<SmsMessage> _inboxMessages = [];
  List<SmsMessage> _sentMessages = [];
  Map<String, SmsVerificationResult> _verificationResults = {};
  
  late TabController _tabController;
  StreamSubscription? _incomingSmsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _checkPermissions();
    await _loadUserPhoneNumber();
    await _smsService.initialize();
    
    // Listen for incoming SMS
    _incomingSmsSubscription = _smsService.incomingSmsStream.listen((sms) {
      setState(() {
        _inboxMessages.insert(0, sms);
      });
      // Auto-verify incoming SMS
      _verifySms(sms);
    });
    
    if (_hasPermissions) {
      await _loadMessages();
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadUserPhoneNumber() async {
    if (_currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _userPhoneNumber = userDoc.data()?['phone'];
        });
      }
    }
  }

  Future<void> _checkPermissions() async {
    final hasPerms = await _smsService.hasPermissions();
    setState(() {
      _hasPermissions = hasPerms;
    });
  }

  Future<void> _requestPermissions() async {
    final granted = await _smsService.requestPermissions();
    if (granted) {
      // Wait a bit for permission dialog
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
      if (_hasPermissions) {
        await _loadMessages();
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });
    
    final inbox = await _smsService.readInboxMessages(limit: 30);
    final sent = await _smsService.readSentMessages(limit: 30);
    
    setState(() {
      _inboxMessages = inbox;
      _sentMessages = sent;
      _isLoading = false;
    });
  }

  Future<void> _verifySms(SmsMessage sms) async {
    final key = '${sms.address}_${sms.body.hashCode}';
    
    final result = await _smsService.verifyReceivedSms(
      senderPhoneNumber: sms.address,
      messageContent: sms.body,
    );
    
    setState(() {
      _verificationResults[key] = result;
    });
  }

  Future<void> _signAndStoreSms(SmsMessage sms) async {
    if (_currentUser == null || _userPhoneNumber == null) {
      _showSnackBar('Please ensure you are logged in and have a phone number set');
      return;
    }

    final result = await _smsService.signAndStoreSms(
      senderId: _currentUser.uid,
      senderPhoneNumber: _userPhoneNumber!,
      receiverPhoneNumber: sms.address,
      messageContent: sms.body,
    );

    if (result != null) {
      _showSnackBar('SMS signed and stored successfully!', isSuccess: true);
    } else {
      _showSnackBar('Failed to sign SMS');
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? ColorPalette.darkGreen : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _startMonitoring() {
    if (_currentUser != null && _userPhoneNumber != null) {
      _smsService.monitorOutgoingSms(
        userId: _currentUser.uid,
        userPhoneNumber: _userPhoneNumber!,
      );
      setState(() {
        _isMonitoring = true;
      });
      _showSnackBar('SMS monitoring started', isSuccess: true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _incomingSmsSubscription?.cancel();
    _smsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'SMS Verification',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: ColorPalette.lightGreen,
        elevation: 0,
        bottom: _hasPermissions
            ? TabBar(
                controller: _tabController,
                labelColor: ColorPalette.darkGreen,
                unselectedLabelColor: Colors.black45,
                indicatorColor: ColorPalette.darkGreen,
                tabs: const [
                  Tab(icon: Icon(Icons.inbox), text: 'Inbox'),
                  Tab(icon: Icon(Icons.send), text: 'Sent'),
                  Tab(icon: Icon(Icons.history), text: 'History'),
                ],
              )
            : null,
        actions: [
          if (_hasPermissions)
            IconButton(
              icon: Icon(
                _isMonitoring ? Icons.stop_circle : Icons.play_circle,
                color: _isMonitoring ? Colors.red : ColorPalette.darkGreen,
              ),
              onPressed: _isMonitoring ? null : _startMonitoring,
              tooltip: _isMonitoring ? 'Monitoring active' : 'Start auto-sign',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _hasPermissions ? _loadMessages : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermissions
              ? _buildPermissionRequest()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInboxTab(),
                    _buildSentTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ColorPalette.lightGreen.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sms_outlined,
                size: 64,
                color: ColorPalette.darkGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SMS Permission Required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ColorPalette.darkGreen,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'To verify SMS authenticity, we need permission to read your messages. Your messages are processed locally and only signatures are stored.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.lock_open),
              label: const Text('Grant Permission'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorPalette.darkGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxTab() {
    if (_inboxMessages.isEmpty) {
      return _buildEmptyState('No inbox messages', Icons.inbox_outlined);
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      color: ColorPalette.darkGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _inboxMessages.length,
        itemBuilder: (context, index) {
          final sms = _inboxMessages[index];
          final key = '${sms.address}_${sms.body.hashCode}';
          final verification = _verificationResults[key];

          return _buildSmsCard(
            sms: sms,
            verification: verification,
            showVerifyButton: true,
            onVerify: () => _verifySms(sms),
          );
        },
      ),
    );
  }

  Widget _buildSentTab() {
    if (_sentMessages.isEmpty) {
      return _buildEmptyState('No sent messages', Icons.send_outlined);
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      color: ColorPalette.darkGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _sentMessages.length,
        itemBuilder: (context, index) {
          final sms = _sentMessages[index];

          return _buildSmsCard(
            sms: sms,
            showSignButton: true,
            onSign: () => _signAndStoreSms(sms),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_currentUser == null) {
      return _buildEmptyState('Please log in', Icons.person_outline);
    }

    return FutureBuilder<List<SignedSms>>(
      future: _smsService.getSignedSmsHistory(_currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = snapshot.data ?? [];
        
        if (history.isEmpty) {
          return _buildEmptyState('No signed SMS history', Icons.history_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final record = history[index];
            return _buildHistoryCard(record);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsCard({
    required SmsMessage sms,
    SmsVerificationResult? verification,
    bool showVerifyButton = false,
    bool showSignButton = false,
    VoidCallback? onVerify,
    VoidCallback? onSign,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: verification?.isVerified == true
              ? ColorPalette.darkGreen.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: ColorPalette.lightGreen,
                  child: Icon(
                    sms.type == SmsType.inbox ? Icons.call_received : Icons.call_made,
                    color: ColorPalette.darkGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sms.address,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(sms.timestamp),
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (verification != null) _buildVerificationBadge(verification),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sms.body,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            if (showVerifyButton || showSignButton) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (showVerifyButton)
                    TextButton.icon(
                      onPressed: onVerify,
                      icon: const Icon(Icons.verified_user, size: 18),
                      label: const Text('Verify'),
                      style: TextButton.styleFrom(
                        foregroundColor: ColorPalette.darkGreen,
                      ),
                    ),
                  if (showSignButton)
                    ElevatedButton.icon(
                      onPressed: onSign,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Sign & Store'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorPalette.darkGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(SmsVerificationResult verification) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (verification.status) {
      case 'Valid':
        bgColor = ColorPalette.lightGreen;
        textColor = ColorPalette.darkGreen;
        icon = Icons.verified;
        break;
      case 'Not Found':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.help_outline;
        break;
      default:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        icon = Icons.warning_amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            verification.status,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(SignedSms record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: ColorPalette.lightGreen,
          child: const Icon(Icons.verified_user, color: ColorPalette.darkGreen),
        ),
        title: Text(
          'To: ${record.receiverPhoneNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Hash: ${record.messageHash.substring(0, 20)}...',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            Text(
              _formatDate(record.timestamp),
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
        trailing: record.expiresAt != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    DateTime.now().isBefore(record.expiresAt!)
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: DateTime.now().isBefore(record.expiresAt!)
                        ? ColorPalette.darkGreen
                        : Colors.red,
                  ),
                  Text(
                    DateTime.now().isBefore(record.expiresAt!) ? 'Active' : 'Expired',
                    style: TextStyle(
                      fontSize: 10,
                      color: DateTime.now().isBefore(record.expiresAt!)
                          ? ColorPalette.darkGreen
                          : Colors.red,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

