import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadAnimalPhoto({
    required String farmId,
    required String animalId,
    required File imageFile,
  }) async {
    final ref = _storage.ref('farms/$farmId/animals/$animalId.jpg');
    await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<void> deleteAnimalPhoto({
    required String farmId,
    required String animalId,
  }) async {
    try {
      await _storage.ref('farms/$farmId/animals/$animalId.jpg').delete();
    } catch (_) {}
  }

  Future<({String url, String name})> uploadDocument({
    required String farmId,
    required String docId,
    required File file,
    required String fileName,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    final contentType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
    final ref = _storage.ref('farms/$farmId/documents/$docId.$ext');
    await ref.putFile(file, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    return (url: url, name: fileName);
  }

  Future<void> deleteDocument({
    required String farmId,
    required String docId,
    required String fileName,
  }) async {
    try {
      final ext = fileName.split('.').last.toLowerCase();
      await _storage.ref('farms/$farmId/documents/$docId.$ext').delete();
    } catch (_) {}
  }
}

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
