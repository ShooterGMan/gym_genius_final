import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CachedImage extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const CachedImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return placeholder ??
            Container(
              color: AppColors.surface,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.white24,
                  size: 32,
                ),
              ),
            );
      },
    );
  }
}
