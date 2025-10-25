// import 'dart:developer';
// import 'dart:io';
// import 'package:file_picker/file_picker.dart';
 
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// // import 'package:image_cropper/image_cropper.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../constants/constants.dart';
// import 'package:intl/intl.dart';
// // import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// class Estu {
//   bool isLoading = true;

//   late String username;
//   late String sessionId;
//   late String deviceToken;
//   late String authCode;

  
 
 
// }
//   // void verifyOtpCode(
//   //     BuildContext context, startLoading, stopLoading, String otp) async {
//   //   startLoading;
//   //   _firebaseMessaging.getToken().then((token) async {
//       // GetStorage getStorage = GetStorage();
//       // username = getStorage.read('username');
//       // sessionId = getStorage.read('sessionId');
//       // print(username);
//       // print(sessionId);

//       // var res =
//       //     await UserAPI().verifyOtp(context,username, sessionId, otp, token!, '1');
//       // print(res);
//       // if (res['status'] == 'OK') {
//       //   //initializing storge
//       //   GetStorage getStorage = GetStorage();
//       //   getStorage.write("authCode", res['auth_code']);
//       //   authCode = getStorage.read('authCode');
//       //   print('AAuthCode');
//       //   print(authCode);
//       //   if (getStorage.read('authCode') != null) {
//       //     authCode = (res['auth_code']);
//       //     // print('AuthCode');
//       //     // print(authCode);
//       //     var check = await UserAPI().checkApi(context,authCode);
//       //     print(check);
//       //     if (check != null && check['status'] == 'OK') {
//       //       getStorage.write(
//       //           "contact_no", check['detail']['contact_no'].toString());
//       //       getStorage.write("userId", check['detail']['id'].toString());
//       //       getStorage.write(
//       //           "username", check['detail']['username'].toString());
//       //       if (check['detail']['email'] != null) {
//       //         getStorage.write("email", check['detail']['email'].toString());
//       //         startLoading;
//       //         navigateTo(context, BottomNavigation());
//       //         //here comes the Main Screen
//       //       } else {
//       //         startLoading;
//       //         navigateTo(context, BottomNavigation());
//       //         // Get.to(() => SignupPage(), binding: SignupBinding());
//       //       }
//       //     } else {
//       //       stopLoading;

//       //       createAlert(context, 'Error', res['error']);
//       //     }
//       //   } else {
//       //     stopLoading;
//       //     createAlert(context, 'Error', "No authcode found");
//       //   }
//       // } else {
//       //   stopLoading;
//       //   createAlert(context, '', "User Number is already exist in the vendor");
//       // }
//   //   });
//   // }

//   // FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
//   // notificationPermission() async {
//   //   // ignore: unused_local_variable
//   //   NotificationSettings settings = await _firebaseMessaging.requestPermission(
//   //     alert: true,
//   //     announcement: false,
//   //     badge: true,
//   //     carPlay: false,
//   //     criticalAlert: false,
//   //     provisional: false,
//   //     sound: true,
//   //   );
//   // }

//   // Future<void> _firebaseMessagingBackgroundHandler(
//   //     RemoteMessage message) async {
//   //   // If you're going to use other Firebase services in the background, such as Firestore,
//   //   // make sure you call `initializeApp` before using other Firebase services.
//   //   await Firebase.initializeApp();
//   //   print('Handling a background message ${message.notification}');
//   // }

  
//   late File? _image;
//   late String url;
//   final picker = ImagePicker();
//   var pickedFile;
 

//   // static getImage(String type) async {
//   //   late File? _image;

//   //   late String url;
//   //   final picker = ImagePicker();
//   //   var pickedFile;
//   //   if (type == 'camera') {
//   //     pickedFile =
//   //         await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
//   //   } else if (type == 'gallery') {
//   //     pickedFile =
//   //         await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
//   //   }
//   //   CroppedFile? croppedFile = await ImageCropper().cropImage(
//   //       sourcePath: pickedFile.path,
//   //       aspectRatio:
//   //           CropAspectRatio(ratioX: 1.0, ratioY: 1.0), // Set aspect ratio
//   //       uiSettings: [
//   //         AndroidUiSettings(
//   //             toolbarTitle: 'Crop Image',
//   //             toolbarColor: tPrimaryColor,
//   //             toolbarWidgetColor: tWhite,
//   //             initAspectRatio: CropAspectRatioPreset.ratio16x9,
//   //             lockAspectRatio: true),
//   //         IOSUiSettings(minimumAspectRatio: 1.0)
//   //       ]);

//   //   // setState(() {
//   //   if (croppedFile != null) {
//   //     File _file = File(croppedFile.path);
//   //     print(_file.lengthSync());
//   //     if (_file.lengthSync() < 20000000) {
//   //       _image = File(croppedFile.path);
//   //       print("_image");
//   //       print(_image);
//   //       return _image;
//   //     } else {}
//   //   } else {
//   //     print('No image selected.');
//   //   }
//   //   // });

//   //   if (croppedFile != null) {
//   //     File _file = File(croppedFile.path);
//   //     print(_file.lengthSync());
//   //     // ignore: non_constant_identifier_names
//   //     String ImageName = 'store-image-update';
//   //     print("13" + ImageName);
//   //     // ignore: unused_local_variable
//   //     // String url;
//   //     // Upload file
//   //     FirebaseStorage storage = FirebaseStorage.instance;
//   //     Reference ref =
//   //         storage.ref().child("$ImageName" + DateTime.now().toString());
//   //     print(ref);

//   //     UploadTask uploadTask = ref.putFile(_file);
//   //     print(uploadTask);

//   //     // setState(() => isLoading = true);
//   //     uploadTask.then((resp) async {
//   //       url = await resp.ref.getDownloadURL();
//   //       print('Image url');
//   //       print(url);
//   //       return url;
//   //       // setState(() {
//   //       //   _loading = false;
//   //       //   storeimage = url;
//   //       //   print('storeimage');
//   //       //   print(storeimage);
//   //       //   _loading = true;
//   //       // });
//   //     });
//   //   }
//   // }
// //getImage end

//   static createAlert(BuildContext context, error, errormsg) async {
//     showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             backgroundColor: tWhite,
//             title: Text(error),
//             content: Text(errormsg ?? ' '),
//           );
//         });
//   }

//   static willpopAlert(BuildContext context) {
//     showDialog(
//       context: context,
//       barrierDismissible: false, // user must tap button!
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: tWhite,
//           title: const Text('Are you sure you want to exit?'),
//           // content: SingleChildScrollView(
//           //   child: ListBody(
//           //     children: const <Widget>[
//           //       Text('This is a demo alert dialog.'),
//           //       Text('Would you like to approve of this message?'),
//           //     ],
//           //   ),
//           // ),
//           actions: <Widget>[
//             Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 GestureDetector(
//                   onTap: () {
//                     navigateBack(context);
//                   },
//                   child: Container(
//                     alignment: Alignment.center,
//                     padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
//                     decoration: BoxDecoration(
//                         // gradient: tPrimaryGradientColor,
//                         border: Border.all(width: 1, color: tPrimaryColor),
//                         borderRadius: BorderRadius.circular(6)),
//                     child: Text(
//                       'Cancel',
//                       style: TextStyle(color: tPrimaryColor),
//                     ),
//                   ),
//                 ),
//                 SizedBox(
//                   width: 30,
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     SystemChannels.platform.invokeMethod('SystemNavigator.pop');
//                   },
//                   child: Container(
//                     alignment: Alignment.center,
//                     padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
//                     decoration: BoxDecoration(
//                         // gradient: tPrimaryGradientColor,
//                         border: Border.all(width: 1, color: tPrimaryColor),
//                         borderRadius: BorderRadius.circular(6)),
//                     child: Text(
//                       'Ok',
//                       style: TextStyle(
//                           color: tPrimaryColor, fontWeight: FontWeight.w500),
//                     ),
//                   ),
//                 )
//               ],
//             )
//           ],
//         );
//       },
//     );
//   }

//   // static navigateTo(BuildContext context, page) async {
//   //   Navigator.push(
//   //     context,
//   //     MaterialPageRoute(builder: (context) => page),
//   //   );
//   // }

//   //with fad in transation
//   static navigateTo(BuildContext context, Widget page) async {
//     Navigator.of(context).push(
//       PageRouteBuilder(
//         pageBuilder: (context, animation, secondaryAnimation) => page,
//         transitionsBuilder: (context, animation, secondaryAnimation, child) {
//           return FadeTransition(
//             opacity: animation,
//             child: child,
//           );
//         },
//       ),
//     );
//   }

//   // lunch url in webview
//   static launchURL(String url) async {
//     if (await canLaunch(url)) {
//       await launch(
//         url,
//         forceSafariVC: true,
//         forceWebView: true,
//         enableJavaScript: true,
//       );
//     } else {
//       print('Could not launch $url');
//     }
//   }

//   static navigateBack(BuildContext context) async {
//     Navigator.pop(context);
//   }

//   static forceNavigateTo(BuildContext context, page) async {
//     Navigator.pushReplacement(context,
//         new MaterialPageRoute(builder: (BuildContext context) => page));
//   }

//   static dateFormate(now) {
//     final DateFormat formatter = DateFormat("yyyy-MM-dd");
//     final String formatted = formatter.format(now);
//     return formatted;
//   }

//   static dateTime(now) {
//     final DateFormat formatter = DateFormat('yyyy-MM-dd hh:mm aa');

//     final String formatted = formatter.format(DateTime.parse(now.toString()));
//     return formatted;
//   }

//   static errorHandler(BuildContext context, errorRes) async {
//     switch (errorRes) {
//       case 301:
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Moved Permanently'),
//         ));
//         break;
//       case 302:
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Found'),
//         ));
//         break;
//       case 401:
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Unauthorized'),
//         ));
//         break;
//       case 403:
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Forbidden'),
//         ));

//         break;
//       case 404:
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Not Found'),
//         ));
//         break;
//       case 500:
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Internal Server Error'),
//         ));
//         break;
//       case 502:
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Bad Gateway'),
//         ));
//         break;
//       case 503:
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Service Unavailable'),
//         ));

//         break;
//       case 504:
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Gateway Timeout'),
//         ));
//         break;
//       default:
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Oops!...'),
//         ));
//     }
//   }

//   static timeFormater(tim) {
//     String formattedTime = DateFormat.jm().format(tim);
//     print(formattedTime);
//     return formattedTime;
//   }

//   formatDate(inputDate) {
//     DateTime date = DateTime.parse(inputDate.toString());
//     String formattedDate = DateFormat("dd MMMM yyyy").format(date);
//     return formattedDate;
//   }

//   static dateFormate1(now) {
//     final DateFormat formatter = DateFormat('yyyy-MM-dd');

//     final String formatted = formatter.format(DateTime.parse(now.toString()));
//     return formatted;
//   }

//   static timeFormate(now) {
//     final DateFormat formatter = DateFormat('kk:mm');

//     final String formatted = formatter.format(DateTime.parse(now.toString()));
//     return formatted;
//   }

//   monthDateFormat(inputDate) {
//     DateTime date = DateTime.parse(inputDate);
//     String formattedDate = DateFormat("dd MMM").format(date);
//     return formattedDate;
//   }

//   String formatTime(String timeString) {
//     DateTime now = DateTime.now();
//     String nowMonth = now.month < 10 ? '0${now.month}' : "${now.month}";
//     String nowDay = now.day < 10 ? '0${now.day}' : "${now.day}";
//     final format = DateFormat('h:mm a');
//     final time = TimeOfDay.fromDateTime(
//         DateTime.parse("${now.year}-$nowMonth-$nowDay $timeString"));
//     return format.format(DateTime(now.year, int.parse(nowMonth),
//         int.parse(nowDay), time.hour, time.minute));
//   }

//   String fullDateTimeFormatTo12Hour(String dateTimeStr) {
//     // Parse the input date string to a DateTime object
//     DateTime dateTime = DateTime.parse(dateTimeStr);

//     // Format the DateTime object to the desired format
//     String formattedTime = DateFormat.jm().format(dateTime);

//     return formattedTime;
//   }

//   getFileUrl() async {
//     String imageUrl = '';
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       allowedExtensions: ['pdf'],
//       type: FileType.custom,
//     );
//     if (result != null) {
//       print(result);
//       log('image >>>>.');
//       // Do something with the image file like upload to Firebase Storage
//       imageUrl = await uploadFileToFirebase(result.files.single.path!);
//       return imageUrl;
//     }
//   }

//   getGalleryImageUrl() async {
//     final picker = ImagePicker();
//     String imageUrl = '';
//     final pickedFile = await picker.pickImage(source: ImageSource.gallery);

//     if (pickedFile != null) {
//       log('image >>>>.');
//       // Do something with the image file like upload to Firebase Storage
//       imageUrl = await uploadImageToFirebase(pickedFile.path);
//       return imageUrl;
//     } else {
//       return imageUrl;
//     }
//   }

 

  
 
 
 

  


 

