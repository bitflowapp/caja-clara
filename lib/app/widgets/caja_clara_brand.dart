import 'package:flutter/material.dart';

class CajaClaraBrand {
  static const String logoAsset = 'assets/branding/caja_clara_logo.png';
  static const String symbolAsset = 'assets/branding/caja_clara_symbol.png';
  static const String smallMarkAsset =
      'assets/branding/caja_clara_mark_small.png';
}

class CajaClaraLogo extends StatelessWidget {
  const CajaClaraLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      CajaClaraBrand.logoAsset,
      width: width,
      height: height,
      fit: fit,
      isAntiAlias: true,
      filterQuality: FilterQuality.high,
    );
  }
}

class CajaClaraSymbol extends StatelessWidget {
  const CajaClaraSymbol({super.key, this.size = 28, this.fit = BoxFit.contain});

  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      CajaClaraBrand.symbolAsset,
      width: size,
      height: size,
      fit: fit,
      isAntiAlias: true,
      filterQuality: FilterQuality.high,
    );
  }
}

class CajaClaraSmallMark extends StatelessWidget {
  const CajaClaraSmallMark({
    super.key,
    this.size = 28,
    this.fit = BoxFit.contain,
  });

  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      CajaClaraBrand.smallMarkAsset,
      width: size,
      height: size,
      fit: fit,
      isAntiAlias: true,
      filterQuality: FilterQuality.high,
    );
  }
}
