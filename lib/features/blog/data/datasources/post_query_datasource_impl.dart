import 'package:blog_app/core/constants/db_collections.dart';
import 'package:blog_app/core/error/exceptions.dart';
import 'package:blog_app/core/network/supabase/database_client.dart';
import 'package:blog_app/core/performance/performance_service.dart';
import 'package:blog_app/features/blog/data/datasources/post_query_datasource.dart';
import 'package:blog_app/features/blog/data/models/post_model.dart';

class PostQueryDataSourceImpl implements PostQueryDataSource {
  final DatabaseClient _databaseClient;
  final PerformanceService _performanceService;

  PostQueryDataSourceImpl(this._databaseClient, this._performanceService);

  @override
  Future<List<PostModel>> getPosts({int? limit, String? startAfterId, String? category}) async {
    try {
      // Home feed (all posts) and a category feed are separate traces, so each gets its own numbers in the console.
      final response = await _performanceService.measure(
        category == null ? 'load_home_feed' : 'load_category_feed',
        () => _databaseClient.select(
          DBCollection.posts,
          columns: '*, author:profiles!author_id(*)',
          limit: limit,
          startAfterId: startAfterId,
          orderBy: 'created_at',
          ascending: false,
          filters: category != null ? {'category': category} : null,
        ),
        attributes: {
          'page': startAfterId == null ? 'first' : 'next',
          if (category != null) 'category': category,
        },
      );

      return response.map((e) => PostModel.fromJson(e)).toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to get posts: ${e.toString()}');
    }
  }

  @override
  Future<List<PostModel>> getMyPosts({required String userId, String? category}) async {
    try {
      final filters = <String, dynamic>{'author_id': userId};
      if (category != null) {
        filters['category'] = category;
      }

      final response = await _databaseClient.select(
        DBCollection.posts,
        columns: '*, author:profiles!author_id(*)',
        orderBy: 'created_at',
        filters: filters,
        ascending: false,
      );

      return response.map((e) => PostModel.fromJson(e)).toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to get my posts: ${e.toString()}');
    }
  }

  @override
  Future<List<PostModel>> searchPosts({required String query}) async {
    try {
      final response = await _databaseClient.search(
        DBCollection.posts,
        column: 'title',
        query: query,
        columns: '*, author:profiles!author_id(*)',
      );
      return response.map((e) => PostModel.fromJson(e)).toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to search posts: ${e.toString()}');
    }
  }

  @override
  Stream<PostModel> watchNewPosts() {
    return _databaseClient
        .watchInserts(DBCollection.posts, columns: '*, author:profiles!author_id(*)')
        .map(PostModel.fromJson);
  }
}
