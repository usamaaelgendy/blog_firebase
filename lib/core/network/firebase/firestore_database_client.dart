import 'package:blog_app/core/constants/db_collections.dart';
import 'package:blog_app/core/error/exceptions.dart';
import 'package:blog_app/core/network/auth_client.dart';
import 'package:blog_app/core/network/supabase/database_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore implementation of [DatabaseClient].
///
/// Keeps the Supabase-shaped contract so the datasources stay unchanged:
/// - Subcollections (e.g. `posts/{postId}/comments`) are described in [_subCollections].
/// - `author` is a copy of the current user stored inside each document,
///   so the `columns` joins (`author:profiles!author_id(*)`) are not needed and are ignored.
/// - Timestamps are returned as ISO strings because the models use `DateTime.parse`.
class FirestoreDatabaseClient implements DatabaseClient {
  final FirebaseFirestore _firestore;
  final AuthClient _authClient;

  /// Subcollections: `collection -> (parent collection, field in the data that holds the parent id)`.
  /// e.g. `comments` live in `posts/{post_id}/comments`.
  static const _subCollections =
      <String, ({String parent, String parentIdField})>{
        DBCollection.comments: (
          parent: DBCollection.posts,
          parentIdField: 'post_id',
        ),
      };

  // Return a local estimate for `serverTimestamp()` fields that are still pending.
  static const _getOptions = GetOptions(
    serverTimestampBehavior: ServerTimestampBehavior.estimate,
  );

  FirestoreDatabaseClient(this._firestore, this._authClient);

  @override
  Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> data) {
    return _guard(() async {
      final user = _authClient.currentUser;
      if (user == null) throw AuthException('User not authenticated');

      final subCollection = _subCollections[table];
      final ref =
          await _collection(
            table,
            parentId: data[subCollection?.parentIdField] as String?,
          ).add({
            ...data,
            'author': {
              'id': user.id,
              'name': user.displayName,
              'avatar_url': user.photoUrl,
              'created_at': user.createdAt.toIso8601String(),
            },
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

      print(ref.id);

      // Subcollection docs are found by `id` through a collection group query.
      if (subCollection != null) await ref.update({'id': ref.id});

      return _toMap(await ref.get(_getOptions));
    });
  }

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    String columns = '*',
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = false,
    int? limit,
    String? startAfterId,
  }) {
    return _guard(() async {
      var query = _filteredQuery(table, filters);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: !ascending);
      }

      // Cursor pagination: continue after the last doc of the previous page,
      // so only the docs of this page are read (an offset would re-read every skipped doc).
      if (startAfterId != null) {
        final cursor = await (await _docRef(table, startAfterId)).get(_getOptions);
        query = query.startAfterDocument(cursor);
      }
      if (limit != null) query = query.limit(limit);

      final snapshot = await query.get(_getOptions);
      print(snapshot.docs.length);
      return snapshot.docs.map(_toMap).toList();
    });
  }

  @override
  Future<Map<String, dynamic>> selectById(
    String table,
    String id, {
    String columns = '*',
  }) {
    return _guard(
      () async => _toMap(await (await _docRef(table, id)).get(_getOptions)),
    );
  }

  @override
  Future<Map<String, dynamic>> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) {
    return _guard(() async {
      final ref = await _docRef(table, id);
      await ref.update({...data, 'updated_at': FieldValue.serverTimestamp()});
      return _toMap(await ref.get(_getOptions));
    });
  }

  @override
  Future<void> delete(String table, String id) {
    return _guard(() async {
      final ref = await _docRef(table, id);

      // Firestore does not delete subcollections with their parent document.
      final batch = _firestore.batch();
      for (final MapEntry(key: child, value: subCollection)
          in _subCollections.entries) {
        if (subCollection.parent != table) continue;
        final children = await ref.collection(child).get(_getOptions);
        for (final doc in children.docs) {
          batch.delete(doc.reference);
        }
      }
      batch.delete(ref);
      await batch.commit();
    });
  }

  @override
  Future<List<Map<String, dynamic>>> search(
    String table, {
    required String column,
    required String query,
    String columns = '*',
  }) {
    // Firestore has no `ilike`, so filter by "contains" on the client.
    return _guard(() async {
      final snapshot = await _collection(
        table,
      ).orderBy('created_at', descending: true).get(_getOptions);
      final needle = query.toLowerCase();

      return snapshot.docs
          .map(_toMap)
          .where(
            (doc) =>
                (doc[column] as String? ?? '').toLowerCase().contains(needle),
          )
          .toList();
    });
  }

  @override
  Stream<Map<String, dynamic>> watchInserts(
    String table, {
    String columns = '*',
    Map<String, dynamic>? filters,
  }) {
    // Only docs created after the listener starts, so the first snapshot is empty
    // and old docs are never read. A pending `serverTimestamp()` doesn't match this filter,
    // so a new doc shows up once the server has written its `created_at`.
    final startedAt = Timestamp.now();
    final query = _filteredQuery(
      table,
      filters,
    ).where('created_at', isGreaterThan: startedAt);

    return _guardStream(
      query.snapshots().expand(
        (snapshot) => snapshot.docChanges
            .where((change) => change.type == DocumentChangeType.added)
            .map((change) => _toMap(change.doc)),
      ),
    );
  }

  @override
  Stream<String> watchDeletes(String table, {Map<String, dynamic>? filters}) {
    // Deletes must cover docs created before the listener started, so no `created_at` filter.
    // The first snapshot is the current state (only `added` changes), later `removed` changes are deletes.
    return _guardStream(
      _filteredQuery(table, filters).snapshots().expand(
        (snapshot) => snapshot.docChanges
            .where((change) => change.type == DocumentChangeType.removed)
            .map((change) => change.doc.id),
      ),
    );
  }

  /// Builds a query on [table] with `isEqualTo` [filters]; the parent id filter picks the subcollection.
  Query<Map<String, dynamic>> _filteredQuery(
    String table,
    Map<String, dynamic>? filters,
  ) {
    final where = Map<String, dynamic>.of(filters ?? {});
    final parentId =
        where.remove(_subCollections[table]?.parentIdField) as String?;

    Query<Map<String, dynamic>> query = _collection(table, parentId: parentId);
    where.forEach((key, value) {
      query = query.where(key, isEqualTo: value);
    });
    return query;
  }

  CollectionReference<Map<String, dynamic>> _collection(
    String table, {
    String? parentId,
  }) {
    final subCollection = _subCollections[table];
    if (subCollection == null) return _firestore.collection(table);

    if (parentId == null)
      throw ServerException(
        '${subCollection.parentIdField} is required for $table',
      );
    return _firestore
        .collection(subCollection.parent)
        .doc(parentId)
        .collection(table);
  }

  Future<DocumentReference<Map<String, dynamic>>> _docRef(
    String table,
    String id,
  ) async {
    if (!_subCollections.containsKey(table))
      return _firestore.collection(table).doc(id);

    // posts/{postId}/comments/{commentsId}
    // Subcollection docs are found by their `id` field across all parents.
    final snapshot = await _firestore
        .collectionGroup(table)
        .where('id', isEqualTo: id)
        .limit(1)
        .get(_getOptions);
    if (snapshot.docs.isEmpty)
      throw ServerException('Document not found', 'not-found');
    return snapshot.docs.first.reference;
  }

  Map<String, dynamic> _toMap(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) throw ServerException('Document not found', 'not-found');
    return {
      ...data.map((key, value) => MapEntry(key, _fromFirestore(value))),
      'id': doc.id,
    };
  }

  dynamic _fromFirestore(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map)
      return value.map((key, v) => MapEntry(key as String, _fromFirestore(v)));
    if (value is List) return value.map(_fromFirestore).toList();
    return value;
  }

  /// Converts Firestore errors into the app's [ServerException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Database request failed', e.code);
    }
  }

  /// Converts Firestore stream errors into the app's [ServerException].
  Stream<T> _guardStream<T>(Stream<T> stream) {
    return stream.handleError((Object e) {
      throw ServerException(
        (e as FirebaseException).message ?? 'Database stream failed',
        e.code,
      );
    }, test: (e) => e is FirebaseException);
  }
}
