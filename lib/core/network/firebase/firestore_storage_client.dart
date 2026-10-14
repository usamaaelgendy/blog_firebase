import 'dart:typed_data';

import 'package:blog_app/core/network/supabase/storage_client.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage implementation of [StorageClient].
///
/// Firebase has one bucket per project, so the Supabase `bucket` becomes
/// the top-level folder: `avatars/{userId}/avatar.png`.
class FirestoreStorageClient implements StorageClient {
  final FirebaseStorage _storage;

  FirestoreStorageClient(this._storage);

  Reference _ref(String bucket, String path) => _storage.ref('$bucket/$path');

  @override
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required Uint8List fileBytes,
    String? contentType,
  }) async {
    final ref = _ref(bucket, path);
    await ref.putData(fileBytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  @override
  Future<void> deleteFile({required String bucket, required String path}) async {
    await _ref(bucket, path).delete();
  }
}
