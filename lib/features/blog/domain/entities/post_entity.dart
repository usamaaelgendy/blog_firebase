import 'package:blog_app/features/blog/domain/entities/profile_entity.dart';
import 'package:equatable/equatable.dart';

class PostEntity extends Equatable {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final String authorId;
  final ProfileEntity? author;
  final String? category;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PostEntity({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.authorId,
    this.author,
    this.category,
    this.viewCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, title, content, imageUrl, authorId, author, category, viewCount, createdAt, updatedAt];
}


//posts - Collection
// └── {postId} -> Document Id
//     ├── title: "Firestore in 7 minutes"
//     ├── content: "..."
//     ├── image_url: null
//     ├── category: "flutter"
//     ├── view_count: 0
//     ├── author_id: "<uid>"
//     ├── author: { name: "Usama", avatar_url: null }   ← نسخة من بيانات الكاتب
//     ├── created_at: timestamp
//     ├── updated_at: timestamp
//     └── comments
//         └── {commentId}
//             ├── content: "Great post"
//             ├── post_id: "<postId>"
//             ├── author_id: "<uid>"
//             ├── author: { name: "Usama", avatar_url: null }
//             └── created_at: timestamp