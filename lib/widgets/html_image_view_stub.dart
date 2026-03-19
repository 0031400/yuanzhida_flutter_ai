import 'package:flutter/material.dart';

class HtmlImageView extends StatelessWidget {
  const HtmlImageView({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorText = '图片加载失败',
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    Widget child = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) =>
          _ImageErrorBox(width: width, height: height, errorText: errorText),
    );
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}

class _ImageErrorBox extends StatelessWidget {
  const _ImageErrorBox({
    required this.width,
    required this.height,
    required this.errorText,
  });

  final double? width;
  final double? height;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 120,
      color: Theme.of(context).colorScheme.surfaceContainer,
      alignment: Alignment.center,
      child: Text(errorText),
    );
  }
}
