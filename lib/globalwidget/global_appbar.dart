import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;

  const CommonAppBar({super.key, required this.titleText});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xffF3F6FA),
      elevation: 0,
      scrolledUnderElevation: 0.0,
      automaticallyImplyLeading: false,
      centerTitle: false,
      
      // leadingWidth: ,
      title: Text(
        titleText,
        style: GoogleFonts.signika(
          color: const Color(0XFF14549B),
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      leadingWidth: 62,
      leading: Padding(
        padding:   EdgeInsets.all(10.0),
        child: Padding(
          padding:   EdgeInsets.only(left: 5),
          child: IconButton(
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.all(0.0)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              backgroundColor:
                  MaterialStateProperty.all(Colors.blue.withOpacity(0.1)),
            ),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xff1F3C88),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
