import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Service for handling encryption and decryption of note data
class EncryptionService {
  static const String _keyStorageKey = 'encryption_master_key';
  static const String _ivStorageKey = 'encryption_iv';
  
  final FlutterSecureStorage _secureStorage;
  final Logger _logger;
  
  encrypt.Key? _masterKey;
  encrypt.IV? _iv;
  bool _isInitialized = false;

  EncryptionService({
    FlutterSecureStorage? secureStorage,
    Logger? logger,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _logger = logger ?? Logger();

  /// Initialize encryption service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('Initializing encryption service...');
      
      // Try to load existing keys
      final keyStr = await _secureStorage.read(key: _keyStorageKey);
      final ivStr = await _secureStorage.read(key: _ivStorageKey);

      if (keyStr != null && ivStr != null) {
        _masterKey = encrypt.Key.fromBase64(keyStr);
        _iv = encrypt.IV.fromBase64(ivStr);
        _logger.i('Loaded existing encryption keys');
      } else {
        // Generate new keys
        await _generateNewKeys();
        _logger.i('Generated new encryption keys');
      }

      _isInitialized = true;
    } catch (e) {
      _logger.e('Failed to initialize encryption service: $e');
      rethrow;
    }
  }

  /// Generate new encryption keys
  Future<void> _generateNewKeys() async {
    _masterKey = encrypt.Key.fromSecureRandom(32); // AES-256
    _iv = encrypt.IV.fromSecureRandom(16);

    // Store keys securely
    await _secureStorage.write(
      key: _keyStorageKey,
      value: _masterKey!.base64,
    );
    await _secureStorage.write(
      key: _ivStorageKey,
      value: _iv!.base64,
    );
  }

  /// Encrypt text data
  Future<Uint8List> encryptText(String plainText) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final encrypter = encrypt.Encrypter(
        encrypt.AES(_masterKey!, mode: encrypt.AESMode.gcm),
      );

      final encrypted = encrypter.encrypt(plainText, iv: _iv!);
      return encrypted.bytes;
    } catch (e) {
      _logger.e('Encryption failed: $e');
      rethrow;
    }
  }

  /// Decrypt binary data to text
  Future<String> decryptData(Uint8List encryptedData) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final encrypter = encrypt.Encrypter(
        encrypt.AES(_masterKey!, mode: encrypt.AESMode.gcm),
      );

      final encrypted = encrypt.Encrypted(encryptedData);
      return encrypter.decrypt(encrypted, iv: _iv!);
    } catch (e) {
      _logger.e('Decryption failed: $e');
      rethrow;
    }
  }

  /// Generate password hash for authentication
  String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Derive key from password using PBKDF2
  Future<encrypt.Key> deriveKeyFromPassword(
    String password,
    String salt, {
    int iterations = 10000,
  }) async {
    // In production, use a proper PBKDF2 implementation
    // This is a simplified version
    final bytes = utf8.encode(password + salt);
    var hash = bytes;
    
    for (int i = 0; i < iterations; i++) {
      final hashBytes = sha256.convert(hash).bytes;
      hash = Uint8List.fromList(hashBytes);
    }
    
    return encrypt.Key(Uint8List.fromList(hash.take(32).toList()));
  }

  /// Change encryption key (for password change)
  Future<void> changeEncryptionKey(String newPassword, String salt) async {
    try {
      _logger.i('Changing encryption key...');
      
      // Derive new key from password
      final newKey = await deriveKeyFromPassword(newPassword, salt);
      
      // Store new key
      await _secureStorage.write(
        key: _keyStorageKey,
        value: newKey.base64,
      );
      
      _masterKey = newKey;
      
      _logger.i('Encryption key changed successfully');
    } catch (e) {
      _logger.e('Failed to change encryption key: $e');
      rethrow;
    }
  }

  /// Check if encryption is set up
  Future<bool> isSetup() async {
    final keyStr = await _secureStorage.read(key: _keyStorageKey);
    return keyStr != null;
  }

  /// Reset encryption (clear all keys) - WARNING: This will make encrypted data unrecoverable
  Future<void> reset() async {
    _logger.w('Resetting encryption - all encrypted data will be lost!');
    
    await _secureStorage.delete(key: _keyStorageKey);
    await _secureStorage.delete(key: _ivStorageKey);
    
    _masterKey = null;
    _iv = null;
    _isInitialized = false;
  }

  /// Export encryption key (for backup)
  Future<String?> exportKey() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _masterKey?.base64;
  }

  /// Import encryption key (from backup)
  Future<void> importKey(String keyBase64) async {
    try {
      final key = encrypt.Key.fromBase64(keyBase64);
      
      await _secureStorage.write(
        key: _keyStorageKey,
        value: key.base64,
      );
      
      _masterKey = key;
      _isInitialized = true;
      
      _logger.i('Imported encryption key successfully');
    } catch (e) {
      _logger.e('Failed to import encryption key: $e');
      rethrow;
    }
  }
}
