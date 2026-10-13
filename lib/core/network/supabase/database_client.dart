abstract class DatabaseClient {
  Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> data);

  Future<List<Map<String, dynamic>>> select(
    String table, {
    String columns = '*',
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = false,
    int? limit,
    String? startAfterId,
  });

  Future<Map<String, dynamic>> selectById(String table, String id, {String columns = '*'});

  Future<Map<String, dynamic>> update(String table, String id, Map<String, dynamic> data);

  Future<void> delete(String table, String id);

  Future<List<Map<String, dynamic>>> search(
    String table, {
    required String column,
    required String query,
    String columns = '*',
  });

  /// Emits every row/document inserted into [table] after the listener starts.
  Stream<Map<String, dynamic>> watchInserts(
    String table, {
    String columns = '*',
    Map<String, dynamic>? filters,
  });

  /// Emits the id of every row/document deleted from [table] after the listener starts.
  Stream<String> watchDeletes(String table, {Map<String, dynamic>? filters});
}
