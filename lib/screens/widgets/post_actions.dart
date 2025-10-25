// import 'package:flutter/material.dart';
// import '../../models/post_model.dart';

// class PostActions extends StatelessWidget {
//   final Post post;
//   final VoidCallback onLike;
//   final VoidCallback onComment;
//   final VoidCallback onShare;

//   const PostActions({
//     super.key,
//     required this.post,
//     required this.onLike,
//     required this.onComment,
//     required this.onShare,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8),
//       child: Row(
//         children: [
//           // Like button
//           Material(
//             color: Colors.transparent,
//             child: InkWell(
//               borderRadius: BorderRadius.circular(20),
//               onTap: onLike,
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       post.isLiked ? Icons.favorite : Icons.favorite_border,
//                       color: post.isLiked ? Colors.red : Colors.grey[600],
//                       size: 20,
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       '${post.likes.length}',
//                       style: TextStyle(
//                         color: Colors.grey[600],
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
          
//           // Comment button
//           Material(
//             color: Colors.transparent,
//             child: InkWell(
//               borderRadius: BorderRadius.circular(20),
//               onTap: onComment,
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       Icons.comment_outlined,
//                       color: Colors.grey[600],
//                       size: 20,
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       '${post.comments.length}',
//                       style: TextStyle(
//                         color: Colors.grey[600],
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
          
//           // Share button
//           Material(
//             color: Colors.transparent,
//             child: InkWell(
//               borderRadius: BorderRadius.circular(20),
//               onTap: onShare,
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       Icons.share_outlined,
//                       color: Colors.grey[600],
//                       size: 20,
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       '${post.shareCount}',
//                       style: TextStyle(
//                         color: Colors.grey[600],
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
          
//           const Spacer(),
          
//           // Save button
//           Material(
//             color: Colors.transparent,
//             child: InkWell(
//               borderRadius: BorderRadius.circular(20),
//               onTap: () {
//                 // TODO: Implement save functionality
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Post saved')),
//                 );
//               },
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 child: Icon(
//                   Icons.bookmark_border,
//                   color: Colors.grey[600],
//                   size: 20,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }  