import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppFontFamily {
  manrope,
  mavenPro,
  wixMadeforDisplay,
  signika,
}

class TextWidget extends StatelessWidget {
  const TextWidget({
    Key? key,
    required this.text,
     required this.fontSize,
    this.color,
    this.fontWeight,
    this.letterSpacing,
    this.height,
    this.textAlign,
    this.lineSpacing,
    this.decoration,
    this.maxLines,
    this.overflow,
    this.fontFamily = AppFontFamily.manrope,
  }) : super(key: key);

  final String text;
  final double fontSize;
  final Color? color;
  final FontWeight? fontWeight;
  final double? letterSpacing;
  final double? height;
  final TextAlign? textAlign;
  final double? lineSpacing;
  final TextDecoration? decoration;
  final int? maxLines;
  final TextOverflow? overflow;
  final AppFontFamily fontFamily;

  @override
  Widget build(BuildContext context) {
    TextStyle baseStyle;

    switch (fontFamily) {
      case AppFontFamily.manrope:
        baseStyle = GoogleFonts.manrope();
        break;
      case AppFontFamily.mavenPro:
        baseStyle = GoogleFonts.mavenPro();
        break;
      case AppFontFamily.wixMadeforDisplay:
        baseStyle = GoogleFonts.wixMadeforDisplay();
        break;
      case AppFontFamily.signika:
        baseStyle = GoogleFonts.signika();
        break;
    }

    return Text(
      text,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      style: baseStyle.copyWith(
        color: color ?? Colors.black,
        fontSize: fontSize ,
        fontWeight: fontWeight?? null,
        decoration: decoration,
        letterSpacing: letterSpacing,
        height: height,
      ),
    );
  }
}