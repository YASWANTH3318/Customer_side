import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blog_post.dart';
import '../models/reel.dart';
import '../models/blogger.dart';

class BlogService {
  static final _firestore = FirebaseFirestore.instance;
  static final _bloggersCollection = _firestore.collection('bloggers');
  static final _postsCollection = _firestore.collection('blog_posts');
  static final _reelsCollection = _firestore.collection('reels');

  // Blogger operations
  static Future<List<Blogger>> getPopularBloggers() async {
    final snapshot = await _bloggersCollection
        .orderBy('stats.followers', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          // Ensure arrays are never null
          if (data['followers'] == null) data['followers'] = [];
          if (data['following'] == null) data['following'] = [];
          if (data['specialties'] == null) data['specialties'] = [];
          if (data['stats'] == null) data['stats'] = {};
          if (data['metadata'] == null) data['metadata'] = {};
          
          return Blogger.fromMap({'id': doc.id, ...data});
        })
        .toList();
  }

  static Future<Blogger?> getBlogger(String id) async {
    final doc = await _bloggersCollection.doc(id).get();
    if (!doc.exists) return null;
    
    final data = doc.data();
    if (data == null) return null;
    
    // Ensure arrays are never null
    if (data['followers'] == null) data['followers'] = [];
    if (data['following'] == null) data['following'] = [];
    if (data['specialties'] == null) data['specialties'] = [];
    if (data['stats'] == null) data['stats'] = {};
    if (data['metadata'] == null) data['metadata'] = {};
    
    return Blogger.fromMap({'id': doc.id, ...data});
  }

  static Future<void> followBlogger(String bloggerId, String userId) async {
    try {
      // Check if blogger document exists
      final bloggerDoc = await _bloggersCollection.doc(bloggerId).get();
      
      if (!bloggerDoc.exists) {
        // Create blogger document if it doesn't exist
        await _bloggersCollection.doc(bloggerId).set({
          'followers': [userId],
          'following': [],
          'specialties': [],
          'stats': {
            'posts': 0,
            'reels': 0,
            'reviews': 0,
            'followers': 1,
          },
          'metadata': {
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        });
      } else {
        // Update existing document
        await _bloggersCollection.doc(bloggerId).update({
          'followers': FieldValue.arrayUnion([userId]),
          'stats.followers': FieldValue.increment(1),
          'metadata.updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error following blogger: $e');
      rethrow;
    }
  }

  static Future<void> unfollowBlogger(String bloggerId, String userId) async {
    try {
      final bloggerDoc = await _bloggersCollection.doc(bloggerId).get();
      
      if (bloggerDoc.exists) {
        await _bloggersCollection.doc(bloggerId).update({
          'followers': FieldValue.arrayRemove([userId]),
          'stats.followers': FieldValue.increment(-1),
          'metadata.updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error unfollowing blogger: $e');
      rethrow;
    }
  }

  // Blog post operations
  static Future<List<BlogPost>> getFeedPosts(String userId) async {
    final userDoc = await _bloggersCollection.doc(userId).get();
    if (!userDoc.exists) return [];

    final userData = userDoc.data();
    if (userData == null) return [];
    
    // Ensure following is not null
    if (userData['following'] == null) {
      userData['following'] = [];
    }
    
    final following = List<String>.from(userData['following'] as List);
    if (following.isEmpty) return [];

    final snapshot = await _postsCollection
        .where('userId', whereIn: following)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          // Ensure arrays are never null
          if (data['likes'] == null) data['likes'] = [];
          if (data['comments'] == null) data['comments'] = [];
          if (data['tags'] == null) data['tags'] = [];
          
          return BlogPost.fromMap({'id': doc.id, ...data});
        })
        .toList();
  }

  // Get all recent posts for customer view (regardless of following)
  static Future<List<BlogPost>> getAllRecentPosts() async {
    try {
      final snapshot = await _postsCollection
          .where('status', isEqualTo: 'published') // Only published posts
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Ensure arrays are never null
            if (data['likes'] == null) data['likes'] = [];
            if (data['tags'] == null) data['tags'] = [];
            if (data['metadata'] == null) data['metadata'] = {};
            
            return BlogPost.fromMap({'id': doc.id, ...data});
          })
          .toList();
    } catch (e) {
      print('Error fetching recent posts: $e');
      return [];
    }
  }

  // Get posts by tag for customer exploration
  static Future<List<BlogPost>> getPostsByTag(String tag) async {
    try {
      final snapshot = await _postsCollection
          .where('tags', arrayContains: tag)
          .where('status', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Ensure arrays are never null
            if (data['likes'] == null) data['likes'] = [];
            if (data['tags'] == null) data['tags'] = [];
            if (data['metadata'] == null) data['metadata'] = {};
            
            return BlogPost.fromMap({'id': doc.id, ...data});
          })
          .toList();
    } catch (e) {
      print('Error fetching posts by tag: $e');
      if (e.toString().contains('indexes?create')) {
        // Fallback to client-side filtering if index isn't ready
        final snapshot = await _postsCollection
            .where('status', isEqualTo: 'published')
            .get();
            
        final allPosts = snapshot.docs.map((doc) {
          final data = doc.data();
          if (data['likes'] == null) data['likes'] = [];
          if (data['tags'] == null) data['tags'] = [];
          if (data['metadata'] == null) data['metadata'] = {};
          
          return BlogPost.fromMap({'id': doc.id, ...data});
        }).toList();
        
        // Filter posts that contain the tag
        return allPosts.where((post) => post.tags.contains(tag)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      return [];
    }
  }

  // Get popular posts based on likes and views
  static Future<List<BlogPost>> getPopularPosts() async {
    try {
      // For simplicity, we'll just get recent posts and sort by likes count
      final snapshot = await _postsCollection
          .where('status', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .limit(50) // Get more posts to sort
          .get();

      final posts = snapshot.docs
          .map((doc) {
            final data = doc.data();
            if (data['likes'] == null) data['likes'] = [];
            if (data['tags'] == null) data['tags'] = [];
            if (data['metadata'] == null) data['metadata'] = {};
            
            return BlogPost.fromMap({'id': doc.id, ...data});
          })
          .toList();
      
      // Sort by likes count (most likes first)
      posts.sort((a, b) => b.likes.length.compareTo(a.likes.length));
      
      // Return top 20
      return posts.take(20).toList();
    } catch (e) {
      print('Error fetching popular posts: $e');
      return [];
    }
  }

  static Future<List<BlogPost>> getBloggerPosts(String bloggerId) async {
    try {
      final snapshot = await _postsCollection
          .where('userId', isEqualTo: bloggerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Ensure arrays are never null
            if (data['likes'] == null) data['likes'] = [];
            if (data['comments'] == null) data['comments'] = [];
            if (data['tags'] == null) data['tags'] = [];
            
            return BlogPost.fromMap({'id': doc.id, ...data});
          })
          .toList();
    } catch (e) {
      if (e.toString().contains('indexes?create')) {
        print('Index not ready for blogger posts. Falling back to unordered query.');
        // Fallback to unordered query
        final snapshot = await _postsCollection
            .where('userId', isEqualTo: bloggerId)
            .get();

        final posts = snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Ensure arrays are never null
              if (data['likes'] == null) data['likes'] = [];
              if (data['comments'] == null) data['comments'] = [];
              if (data['tags'] == null) data['tags'] = [];
              
              return BlogPost.fromMap({'id': doc.id, ...data});
            })
            .toList();
        
        // Sort in memory
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return posts;
      }
      rethrow;
    }
  }

  static Future<void> createPost(BlogPost post) async {
    await _postsCollection.add(post.toMap());
  }

  static Future<void> likePost(String postId, String userId) async {
    await _postsCollection.doc(postId).update({
      'likes': FieldValue.arrayUnion([userId])
    });
  }

  static Future<void> unlikePost(String postId, String userId) async {
    await _postsCollection.doc(postId).update({
      'likes': FieldValue.arrayRemove([userId])
    });
  }

  // Reel operations
  static Future<List<Reel>> getReels() async {
    final snapshot = await _reelsCollection
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          // Ensure 'likes' and 'tags' are properly handled even if null
          if (data['likes'] == null) data['likes'] = [];
          if (data['tags'] == null) data['tags'] = [];
          
          return Reel.fromMap({'id': doc.id, ...data});
        })
        .toList();
  }

  static Future<List<Reel>> getBloggerReels(String bloggerId) async {
    try {
      final snapshot = await _reelsCollection
          .where('userId', isEqualTo: bloggerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Ensure 'likes' and 'tags' are properly handled even if null
            if (data['likes'] == null) data['likes'] = [];
            if (data['tags'] == null) data['tags'] = [];
            
            return Reel.fromMap({'id': doc.id, ...data});
          })
          .toList();
    } catch (e) {
      if (e.toString().contains('indexes?create')) {
        print('Index not ready for blogger reels. Falling back to unordered query.');
        // Fallback to unordered query
        final snapshot = await _reelsCollection
            .where('userId', isEqualTo: bloggerId)
            .get();

        final reels = snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Ensure 'likes' and 'tags' are properly handled even if null
              if (data['likes'] == null) data['likes'] = [];
              if (data['tags'] == null) data['tags'] = [];
              
              return Reel.fromMap({'id': doc.id, ...data});
            })
            .toList();
        
        // Sort in memory
        reels.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return reels;
      }
      rethrow;
    }
  }

  static Future<void> createReel(Reel reel) async {
    await _reelsCollection.add(reel.toMap());
  }

  static Future<void> likeReel(String reelId, String userId) async {
    await _reelsCollection.doc(reelId).update({
      'likes': FieldValue.arrayUnion([userId])
    });
  }

  static Future<void> unlikeReel(String reelId, String userId) async {
    await _reelsCollection.doc(reelId).update({
      'likes': FieldValue.arrayRemove([userId])
    });
  }

  // Add sample data for testing
  static Future<void> addSampleData() async {
    try {
      // Check if data already exists
      final bloggersSnapshot = await _bloggersCollection.limit(1).get();
      if (bloggersSnapshot.docs.isNotEmpty) {
        print('Sample data already exists');
        return;
      }

      // Create sample bloggers
      final sampleBloggers = [
        {
          'name': 'Food Explorer',
          'username': 'foodexplorer',
          'bio': 'Exploring the best food spots in town',
          'profileImageUrl': 'https://picsum.photos/200',
          'coverImageUrl': 'https://picsum.photos/800/400',
          'followers': <String>[],
          'following': <String>[],
          'specialties': ['Italian', 'Japanese', 'Street Food'],
          'stats': {
            'posts': 0,
            'reels': 0,
            'reviews': 0,
            'followers': 0,
          },
          'metadata': {
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
        {
          'name': 'Culinary Adventures',
          'username': 'culinaryadventures',
          'bio': 'Sharing my culinary journey around the world',
          'profileImageUrl': 'https://picsum.photos/201',
          'coverImageUrl': 'https://picsum.photos/801/400',
          'followers': <String>[],
          'following': <String>[],
          'specialties': ['French', 'Indian', 'Desserts'],
          'stats': {
            'posts': 0,
            'reels': 0,
            'reviews': 0,
            'followers': 0,
          },
          'metadata': {
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
      ];

      // Add bloggers to Firestore
      for (final bloggerData in sampleBloggers) {
        final bloggerDoc = await _bloggersCollection.add(bloggerData);
        final bloggerId = bloggerDoc.id;

        // Add sample blog posts
        await _postsCollection.add({
          'userId': bloggerId,
          'userName': bloggerData['name'],
          'userImage': bloggerData['profileImageUrl'],
          'content': 'Check out this amazing dish I discovered!',
          'imageUrl': 'https://picsum.photos/400/300',
          'createdAt': FieldValue.serverTimestamp(),
          'likes': <String>[],
          'tags': ['food', 'foodie', 'delicious'],
          'metadata': {
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'post',
          },
        });

        // Add sample reels
        await _reelsCollection.add({
          'userId': bloggerId,
          'userName': bloggerData['name'],
          'userImage': bloggerData['profileImageUrl'],
          'videoUrl': 'https://example.com/sample-video.mp4',
          'thumbnailUrl': 'https://picsum.photos/300/400',
          'description': 'Making the perfect pasta!',
          'createdAt': FieldValue.serverTimestamp(),
          'likes': <String>[],
          'tags': ['cooking', 'pasta', 'italian'],
          'metadata': {
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'reel',
          },
        });

        // Update blogger stats
        await _bloggersCollection.doc(bloggerId).update({
          'stats.posts': FieldValue.increment(1),
          'stats.reels': FieldValue.increment(1),
        });
      }

      print('Sample data added successfully');
    } catch (e) {
      print('Error adding sample data: $e');
      rethrow;
    }
  }
} 