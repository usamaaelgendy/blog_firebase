import 'dart:async';

import 'package:blog_app/core/performance/performance_service.dart';
import 'package:blog_app/features/blog/domain/entities/post_entity.dart';
import 'package:blog_app/features/blog/domain/repositories/post_query_repository.dart';
import 'package:blog_app/features/blog/presentation/bloc/post_query/post_query_event.dart';
import 'package:blog_app/features/blog/presentation/bloc/post_query/post_query_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PostQueryBloc extends Bloc<PostQueryEvent, PostQueryState> {
  final PostQueryRepository postQueryRepository;
  final PerformanceService performanceService;

  static const int _pageSize = 10;
  List<PostEntity> _allPosts = [];
  String? _currentCategory;

  StreamSubscription? _newPost;
  bool _isLoadingMore = false;

  PostQueryBloc({required this.postQueryRepository, required this.performanceService}) : super(PostQueryInitial()) {
    on<GetPostsEvent>(_onGetPosts);
    on<LoadMorePostsEvent>(_onLoadMorePosts);
    on<GetMyPostsEvent>(_onGetMyPosts);
    on<SearchPostsEvent>(_onSearchPosts);
    on<RefreshPostsEvent>(_onRefreshPosts);
    on<NewPostReceivedEvent>(_onNewPostReceived);
  }

  Future<void> _onGetPosts(GetPostsEvent event, Emitter<PostQueryState> emit) async {
    emit(PostQueryLoading());
    _allPosts = [];
    _currentCategory = event.category;
    // Home feed (all posts) and a category feed are separate traces, so each gets its own numbers in the console.
    final result = await performanceService.measure(
      _currentCategory == null ? 'load_home_feed' : 'load_category_feed',
      () => postQueryRepository.getPosts(limit: _pageSize, category: _currentCategory),
      attributes: {if (_currentCategory != null) 'category': _currentCategory!},
    );
    result.fold((failure) => emit(PostQueryError(failure.message)), (posts) {
      _allPosts = posts;
      emit(PostsLoaded(posts: _allPosts, hasMore: posts.length >= _pageSize));
      _startLiveFeed();
    });
  }

  Future<void> _onLoadMorePosts(LoadMorePostsEvent event, Emitter<PostQueryState> emit) async {
    if (_isLoadingMore || _allPosts.isEmpty) return;
    // Cursor = the last loaded post, so posts added by the live feed don't shift the next page.
    _isLoadingMore = true;
    final result = await postQueryRepository.getPosts(
      limit: _pageSize,
      startAfterId: _allPosts.last.id,
      category: _currentCategory,
    );
    _isLoadingMore = false;
    result.fold((failure) => emit(PostQueryError(failure.message)), (posts) {
      _allPosts = [..._allPosts, ...posts];
      emit(PostsLoaded(posts: _allPosts, hasMore: posts.length >= _pageSize));
    });
  }

  Future<void> _onGetMyPosts(GetMyPostsEvent event, Emitter<PostQueryState> emit) async {
    emit(PostQueryLoading());
    final result = await postQueryRepository.getMyPosts(userId: event.userId, category: event.category);
    result.fold(
      (failure) => emit(PostQueryError(failure.message)),
      (posts) => emit(PostsLoaded(posts: posts, hasMore: false)),
    );
  }

  Future<void> _onSearchPosts(SearchPostsEvent event, Emitter<PostQueryState> emit) async {
    if (event.query.isEmpty) {
      add(const GetPostsEvent());
      return;
    }
    emit(PostQueryLoading());
    final result = await postQueryRepository.searchPosts(query: event.query);
    result.fold(
      (failure) => emit(PostQueryError(failure.message)),
      (posts) => emit(PostsLoaded(posts: posts, hasMore: false)),
    );
  }

  Future<void> _onRefreshPosts(RefreshPostsEvent event, Emitter<PostQueryState> emit) async {
    _allPosts = [];
    final result = await postQueryRepository.getPosts(limit: _pageSize, category: _currentCategory);
    result.fold((failure) => emit(PostQueryError(failure.message)), (posts) {
      _allPosts = posts;
      emit(PostsLoaded(posts: _allPosts, hasMore: posts.length >= _pageSize));
    });
  }

  void _startLiveFeed() {
    _newPost?.cancel();
    _newPost = postQueryRepository.watchNewPosts().listen((either) {
      either.fold((_) => null, (right) {
        add(NewPostReceivedEvent(right));
      });
    });
  }

  void _onNewPostReceived(NewPostReceivedEvent event, Emitter<PostQueryState> emit) {
    if (state is! PostsLoaded) return;

    final alreadyThere = _allPosts.any((post) => post.id == event.post.id);
    if (alreadyThere) return;

    _allPosts = [event.post, ..._allPosts];
    emit(PostsLoaded(posts: _allPosts));
  }

  @override
  Future<void> close() {
    _newPost?.cancel();
    return super.close();
  }

}
