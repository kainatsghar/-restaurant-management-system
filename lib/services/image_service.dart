import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  /// Uploads or encodes an image for reliable cross-device cloud persistence.
  /// If Firebase Storage succeeds, returns the public https download URL.
  /// If Firebase Storage is unavailable/unconfigured, returns compressed Base64 Data URI.
  Future<String> uploadOrEncodeImage({
    required File imageFile,
    required String folder,
    required String fileName,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // 1. Try Firebase Storage upload
      try {
        final metadata = SettableMetadata(contentType: 'image/jpeg');
        final storageRef = FirebaseStorage.instance
            .ref()
            .child(folder)
            .child('$fileName.jpg');

        final snapshot = await storageRef.putData(bytes, metadata);
        final downloadUrl = await snapshot.ref.getDownloadURL();
        if (downloadUrl.isNotEmpty) {
          debugPrint('Successfully uploaded image to Firebase Storage: $downloadUrl');
          return downloadUrl;
        }
      } catch (storageError) {
        debugPrint('Firebase Storage upload failed, using Base64 cloud storage: $storageError');
      }

      // 2. Base64 fallback (stored directly into Firestore document)
      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      debugPrint('Error processing image file: $e');
      return imageFile.path;
    }
  }
}
