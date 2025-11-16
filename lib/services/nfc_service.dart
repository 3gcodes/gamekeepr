import 'dart:async';
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  /// Check if NFC is available on the device
  Future<bool> isAvailable() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      print('📱 NFC availability check: $available');
      return available;
    } catch (e) {
      print('❌ NFC availability check error: $e');
      return false;
    }
  }

  /// Start NFC session to read a game ID from tag
  Future<int?> readGameId() async {
    final completer = Completer<int?>();

    try {
      print('📖 Starting NFC read session...');

      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        invalidateAfterFirstRead: false,
        onDiscovered: (NfcTag tag) async {
          try {
            print('📖 NFC tag discovered!');
            print('📖 Tag data: ${tag.data}');

            final ndef = Ndef.from(tag);
            if (ndef == null) {
              print('❌ Tag is not NDEF formatted');
              await NfcManager.instance.stopSession(errorMessage: 'Tag is not NDEF formatted');
              if (!completer.isCompleted) completer.complete(null);
              return;
            }

            print('📖 NDEF tag found, checking for cached message...');
            if (ndef.cachedMessage == null) {
              print('❌ Tag is empty');
              await NfcManager.instance.stopSession(errorMessage: 'Tag is empty');
              if (!completer.isCompleted) completer.complete(null);
              return;
            }

            // Read the first record
            final records = ndef.cachedMessage!.records;
            print('📖 Found ${records.length} records');

            if (records.isNotEmpty) {
              final payload = records.first.payload;
              print('📖 Payload length: ${payload.length}');

              // NDEF Text Record has language code in first bytes
              // For simplicity, we'll skip the first 3 bytes (language code)
              final text = utf8.decode(payload.length > 3 ? payload.sublist(3) : payload);
              print('📖 Decoded text: $text');

              // Try to parse as integer
              final gameId = int.tryParse(text);

              if (gameId != null) {
                print('✅ Read game ID from tag: $gameId');
                await NfcManager.instance.stopSession();
                if (!completer.isCompleted) completer.complete(gameId);
              } else {
                print('❌ Invalid game ID format: $text');
                await NfcManager.instance.stopSession(errorMessage: 'Invalid game ID format');
                if (!completer.isCompleted) completer.complete(null);
              }
            } else {
              await NfcManager.instance.stopSession(errorMessage: 'No data on tag');
              if (!completer.isCompleted) completer.complete(null);
            }
          } catch (e, stackTrace) {
            print('❌ Error reading NFC tag: $e');
            print('❌ Stack trace: $stackTrace');
            await NfcManager.instance.stopSession(errorMessage: 'Error reading tag');
            if (!completer.isCompleted) completer.complete(null);
          }
        },
        onError: (error) async {
          print('❌ NFC Session Error: $error');
          if (!completer.isCompleted) completer.complete(null);
        },
      );

      print('📖 NFC session started, waiting for tag scan...');

      // Wait for the tag to be scanned or timeout after 60 seconds
      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('⏱️ NFC read session timed out');
          NfcManager.instance.stopSession(errorMessage: 'Timeout');
          return null;
        },
      );
    } catch (e, stackTrace) {
      print('❌ Error starting NFC read session: $e');
      print('❌ Stack trace: $stackTrace');
      if (!completer.isCompleted) completer.complete(null);
      return null;
    }
  }

  /// Write a game ID to an NFC tag
  Future<bool> writeGameId(int gameId) async {
    final completer = Completer<bool>();
    var sessionActive = true;

    try {
      print('🏷️ Starting NFC write session for game ID: $gameId');
      print('🏷️ Please hold your iPhone to the NFC tag now...');

      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
        },
        onDiscovered: (NfcTag tag) async {
          print('🏷️ TAG DISCOVERED!!!');

          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              NfcManager.instance.stopSession(errorMessage: 'Tag not writable');
              if (!completer.isCompleted) completer.complete(false);
              sessionActive = false;
              return;
            }

            // Create NDEF message
            final message = NdefMessage([
              NdefRecord.createText(gameId.toString()),
            ]);

            print('🏷️ Writing...');

            // Write synchronously - this is critical
            try {
              await ndef.write(message);
              print('✅ Write successful!');
              NfcManager.instance.stopSession(alertMessage: 'Game ID written successfully!');
              if (!completer.isCompleted) completer.complete(true);
              sessionActive = false;
            } catch (writeError) {
              print('❌ Write error: $writeError');
              // If write fails, try one more time immediately
              print('🔄 Retrying write...');
              await Future.delayed(Duration(milliseconds: 100));
              await ndef.write(message);
              print('✅ Write successful on retry!');
              NfcManager.instance.stopSession(alertMessage: 'Game ID written successfully!');
              if (!completer.isCompleted) completer.complete(true);
              sessionActive = false;
            }
          } catch (e, stackTrace) {
            print('❌ Error: $e');
            NfcManager.instance.stopSession(errorMessage: 'Write failed');
            if (!completer.isCompleted) completer.complete(false);
            sessionActive = false;
          }
        },
        onError: (error) async {
          print('❌ NFC Session Error: $error');
          print('❌ Error type: ${error.type}');
          print('❌ Error message: ${error.message}');
          if (!completer.isCompleted) completer.complete(false);
          sessionActive = false;
        },
      );

      print('🏷️ NFC session started, waiting for tag scan...');
      print('🏷️ Session active: $sessionActive');

      // Wait for the tag to be scanned or timeout after 60 seconds
      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('⏱️ NFC write session timed out after 60 seconds');
          print('⏱️ Session was still active: $sessionActive');
          if (sessionActive) {
            NfcManager.instance.stopSession(errorMessage: 'Timeout - tag not detected');
          }
          return false;
        },
      );
    } catch (e, stackTrace) {
      print('❌ Error starting NFC write session: $e');
      print('❌ Stack trace: $stackTrace');
      if (!completer.isCompleted) completer.complete(false);
      return false;
    }
  }

  /// Stop any active NFC session
  Future<void> stopSession({String? errorMessage}) async {
    try {
      await NfcManager.instance.stopSession(errorMessage: errorMessage);
    } catch (e) {
      print('Error stopping NFC session: $e');
    }
  }
}
