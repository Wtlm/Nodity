import 'package:flutter/services.dart';

/// Service for getting phone number from SIM card
/// Uses platform channels to communicate with native Android code
class PhoneService {
  static const MethodChannel _channel = MethodChannel('com.nodity/phone');

  /// Check if phone permission is granted
  static Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPhonePermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking phone permission: ${e.message}');
      return false;
    }
  }

  /// Request phone permission from the user
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPhonePermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error requesting phone permission: ${e.message}');
      return false;
    }
  }

  /// Get phone number from SIM card
  /// Returns a PhoneNumberResult with the phone number or error message
  static Future<PhoneNumberResult> getPhoneNumber() async {
    try {
      // First check/request permission
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          return PhoneNumberResult(
            phoneNumber: null,
            error: 'Permission denied. Please grant phone permission.',
            source: null,
          );
        }
      }

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getPhoneNumber');
      
      if (result == null) {
        return PhoneNumberResult(
          phoneNumber: null,
          error: 'Failed to get phone number',
          source: null,
        );
      }

      return PhoneNumberResult(
        phoneNumber: result['phoneNumber'] as String?,
        error: result['error'] as String?,
        source: result['source'] as String?,
      );
    } on PlatformException catch (e) {
      return PhoneNumberResult(
        phoneNumber: null,
        error: 'Platform error: ${e.message}',
        source: null,
      );
    }
  }

  /// Get detailed SIM card information
  static Future<SimInfo> getSimInfo() async {
    try {
      if (!await hasPermission()) {
        await requestPermission();
      }

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSimInfo');
      
      if (result == null) {
        return SimInfo(
          hasSimCard: false,
          simState: 'unknown',
          carrierName: null,
          countryCode: null,
          phoneNumbers: [],
        );
      }

      return SimInfo(
        hasSimCard: result['hasSimCard'] as bool? ?? false,
        simState: result['simState'] as String? ?? 'unknown',
        carrierName: result['carrierName'] as String?,
        countryCode: result['countryCode'] as String?,
        phoneNumbers: (result['phoneNumbers'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
      );
    } on PlatformException catch (e) {
      print('Error getting SIM info: ${e.message}');
      return SimInfo(
        hasSimCard: false,
        simState: 'error',
        carrierName: null,
        countryCode: null,
        phoneNumbers: [],
      );
    }
  }

  /// Try to get phone number, with fallback options
  /// Returns the phone number string or null if not available
  static Future<String?> tryGetPhoneNumber() async {
    final result = await getPhoneNumber();
    if (result.phoneNumber != null) {
      return result.phoneNumber;
    }

    // Fallback: try getting from SIM info
    final simInfo = await getSimInfo();
    if (simInfo.phoneNumbers.isNotEmpty) {
      return simInfo.phoneNumbers.first;
    }

    return null;
  }
}

/// Result of phone number retrieval
class PhoneNumberResult {
  final String? phoneNumber;
  final String? error;
  final String? source; // "TelephonyManager" or "SubscriptionManager"

  PhoneNumberResult({
    required this.phoneNumber,
    required this.error,
    required this.source,
  });

  bool get isSuccess => phoneNumber != null && phoneNumber!.isNotEmpty;
  
  @override
  String toString() => 'PhoneNumberResult(phone: $phoneNumber, source: $source, error: $error)';
}

/// SIM card information
class SimInfo {
  final bool hasSimCard;
  final String simState;
  final String? carrierName;
  final String? countryCode;
  final List<String> phoneNumbers;

  SimInfo({
    required this.hasSimCard,
    required this.simState,
    required this.carrierName,
    required this.countryCode,
    required this.phoneNumbers,
  });

  @override
  String toString() => 'SimInfo(hasSimCard: $hasSimCard, state: $simState, carrier: $carrierName, country: $countryCode, phones: $phoneNumbers)';
}

