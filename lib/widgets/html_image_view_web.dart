import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class HtmlImageView extends StatefulWidget {
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
  State<HtmlImageView> createState() => _HtmlImageViewState();
}

class _HtmlImageViewState extends State<HtmlImageView> {
  static int _nextId = 0;

  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'answerly-html-image-${_nextId++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final image = web.HTMLImageElement()
        ..src = widget.imageUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.objectFit = _objectFit(widget.fit);
      return image;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child = SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: _viewType),
    );
    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }

  String _objectFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitHeight:
        return 'scale-down';
      case BoxFit.fitWidth:
        return 'scale-down';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
      case BoxFit.cover:
        return 'cover';
    }
  }
}
