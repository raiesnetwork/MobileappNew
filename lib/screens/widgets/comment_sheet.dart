// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:intl/intl.dart';
// import '../../models/post_model.dart';
// import '../../providers/post_provider.dart';

// class CommentSheet extends StatefulWidget {
//   final Post post;

//   const CommentSheet({super.key, required this.post});

//   @override
//   State<CommentSheet> createState() => _CommentSheetState();
// }

// class _CommentSheetState extends State<CommentSheet> {
//   final _commentController = TextEditingController();
//   final _scrollController = ScrollController();

//   @override
//   void dispose() {
//     _commentController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

   

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.75,
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       child: Column(
//         children: [
//           // Handle bar
//           Container(
//             width: 40,
//             height: 4,
//             margin: const EdgeInsets.symmetric(vertical: 12),
//             decoration: BoxDecoration(
//               color: Colors.grey[300],
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),
          
//           // Header
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             child: Row(
//               children: [
//                 const Text(
//                   'Comments',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const Spacer(),
//                 Consumer<PostProvider>(
//                   builder: (context, postProvider, child) {
//                     final updatedPost = postProvider.posts
//                         .firstWhere((p) => p.id == widget.post.id, orElse: () => widget.post);
//                     return Text(
//                       '${updatedPost.comments.length}',
//                       style: TextStyle(
//                         fontSize: 16,
//                         color: Colors.grey[600],
//                       ),
//                     );
//                   },
//                 ),
//               ],
//             ),
//           ),
          
//           const Divider(),
          
//           // Comments list
//           Expanded(
//             child: Consumer<PostProvider>(
//               builder: (context, postProvider, child) {
//                 final updatedPost = postProvider.posts
//                     .firstWhere((p) => p.id == widget.post.id, orElse: () => widget.post);
                    
//                 if (updatedPost.comments.isEmpty) {
//                   return const Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.comment_outlined,
//                           size: 60,
//                           color: Colors.grey,
//                         ),
//                         SizedBox(height: 16),
//                         Text(
//                           'No comments yet',
//                           style: TextStyle(
//                             fontSize: 16,
//                             color: Colors.grey,
//                           ),
//                         ),
//                         Text(
//                           'Be the first to comment!',
//                           style: TextStyle(
//                             color: Colors.grey,
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 }
                
//                 return ListView.builder(
//                   controller: _scrollController,
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   itemCount: updatedPost.comments.length,
//                   itemBuilder: (context, index) {
//                     final comment = updatedPost.comments[index];
//                     return _buildCommentItem(comment);
//                   },
//                 );
//               },
//             ),
//           ),
          
//           const Divider(height: 1),
          
//           // Comment input
//           Container(
//             padding: const EdgeInsets.all(16),
//             child: Row(
//               children: [
//                 const CircleAvatar(
//                   radius: 16,
//                   child: Icon(Icons.person, size: 20),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: TextField(
//                     controller: _commentController,
//                     decoration: InputDecoration(
//                       hintText: 'Add a comment...',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(20),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey[100],
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 8,
//                       ),
//                     ),
//                     maxLines: null,
//                     textInputAction: TextInputAction.send,
//                     onSubmitted: (_) { }
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Container(
//                   decoration: const BoxDecoration(
//                     color: Color(0xFF2196F3),
//                     shape: BoxShape.circle,
//                   ),
//                   child: IconButton(
//                     icon: const Icon(Icons.send, color: Colors.white),
//                     onPressed: (){
                      
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCommentItem(Comment comment) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           CircleAvatar(
//             radius: 16,
//             backgroundImage: comment.userAvatar != null
//                 ? CachedNetworkImageProvider(comment.userAvatar!)
//                 : null,
//             child: comment.userAvatar == null
//                 ? Text(
//                     comment.username.isNotEmpty ? comment.username[0].toUpperCase() : 'U',
//                     style: const TextStyle(fontSize: 12),
//                   )
//                 : null,
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.grey[100],
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         comment.username,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         comment.commentContent,
//                         style: const TextStyle(fontSize: 14),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Padding(
//                   padding: const EdgeInsets.only(left: 12),
//                   child: Text(
//                     DateFormat('MMM dd, hh:mm a').format(comment.createdAt),
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }