// import 'package:Estudent_School_managment_teacher_parent/constants/constants.dart';
// import 'package:Estudent_School_managment_teacher_parent/globalWidgets/text_widget.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:loading_icon_button/loading_icon_button.dart';
import 'package:ixes.app/globalwidget/global_text.dart';
// import 'package:ixes.app/lib/globalwidget/global_text.dart';
import 'package:sizer/sizer.dart';

import '../constants/constants.dart';
import '../responsive.dart';
// import '../screens/responsive.dart';
// import '../responsive.dart';
// import 'constants/constants.dart';

class Button extends StatelessWidget {
  const Button({
    Key? key,
    this.color,
    this.bottonText,
    this.onTap,
    this.borderSide,
    this.width,
    this.height,
    this.textcolor,
  }) : super(key: key);
  final color;
  final String? bottonText;
  final onTap;
  final borderSide;
  final textcolor;
  final width;
  final height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        decoration: ShapeDecoration(
           color: tPrimaryColor,
         shadows: [tTabButton],

         // gradient: tGradient,
          // shadows: [tButtonBoxShadow],
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: isTab(context) ? 10 : 15,
              cornerSmoothing: 1.0,
            ),
          ),
        ),
        child: ArgonButton(
          height: height ??
              (isDesktop(context)
                  ? 6.h
                  : isTab(context)
                  ? 4.h
                  : 5.5.h),
          width: width ??
              (isDesktop(context)
                  ? 12.w
                  : isTab(context)
                  ? 100.w
                  : 76.w),
          color: color,

          borderRadius: 20.0, // iOS-style rounded corners

          curve: Curves.fastOutSlowIn,

          loader: Container(
            padding: EdgeInsets.all(10),
            child: SpinKitRotatingCircle(
              color: Colors.white,
              // size: loaderWidth ,
            ),
          ),
          onTap: onTap,

          child: TextWidget(
              text: bottonText!,
              color: textcolor,
              fontWeight: FontWeight.w600,
              fontSize: isDesktop(context)
                  ? 3.5.sp
                  : isTab(context)
                  ? 10.sp
                  : 12.sp),
        ),
      ),
    );
  }
}

class GlobalButton extends StatefulWidget {
  GlobalButton({
    required this.buttonWidth,
    required this.buttonHeight,
    required this.onTap,
    required this.title,
    this.btnType = 'default',
    this.disableButton,
  });
  final double buttonWidth;
  final double buttonHeight;
  String btnType;
  final onTap;
  final title;
  final disableButton;
  @override
  State<GlobalButton> createState() => _GlobalButtonState();
}

class _GlobalButtonState extends State<GlobalButton> {
  @override
  Widget build(BuildContext context) {
    var isBtnTypeDefault = widget.btnType == 'default';
    return Container(
      decoration: BoxDecoration(
        // boxShadow: [
        //   BoxShadow(
        //     color: Color(0x99FF7A30),
        //     blurRadius: 10,
        //     offset: Offset(1, 3),
        //     spreadRadius: 0,
        //   ),
        // ],
      ),
      child: ArgonButton(
        width: widget.buttonWidth,
        height: widget.buttonHeight,
        borderRadius: 20.0,
        elevation: 0,
        color: widget.disableButton == 'yes'
            ? Color.fromARGB(213, 179, 133, 180)
            : Color.fromARGB(215, 134, 37, 135), // Set color to transparent
        onTap: widget.onTap,
        loader: Container(
          padding: EdgeInsets.all(10),
          child: SpinKitRotatingCircle(
            color: tWhite,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.disableButton == 'yes' ? null : tGradient,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                widget.title,
                style: TextStyle(
                  color: tWhite,
                  fontSize: isTab(context) ? 8.sp : 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
