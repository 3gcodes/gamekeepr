import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/s3_service.dart';
import '../providers/settings_providers.dart';

/// A widget that displays collectible images from either S3 or local storage
/// Automatically detects the source and handles signed URL generation for S3
class CollectibleImage extends ConsumerWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const CollectibleImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if this is an S3 path
    if (S3Service.isS3Path(imagePath)) {
      return _buildS3Image(context, ref);
    } else {
      return _buildLocalImage(context);
    }
  }

  Widget _buildS3Image(BuildContext context, WidgetRef ref) {
    final s3ServiceAsync = ref.watch(s3ServiceProvider);

    return s3ServiceAsync.when(
      data: (s3Service) {
        if (s3Service == null) {
          // S3 is disabled but path is s3://, show error
          return _buildError(context, 'S3 is not configured');
        }

        // Generate signed URL
        final s3Key = S3Service.extractS3Key(imagePath);
        final signedUrl = s3Service.generateSignedUrl(s3Key);

        // Use CachedNetworkImage for S3 images (like BGG images)
        return CachedNetworkImage(
          imageUrl: signedUrl,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) =>
              errorBuilder?.call(context, error, null) ??
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.category,
                  size: 32,
                  color: Colors.grey[400],
                ),
              ),
        );
      },
      loading: () => Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stack) => _buildError(context, 'Error loading S3 config'),
    );
  }

  Widget _buildLocalImage(BuildContext context) {
    return Image.file(
      File(imagePath),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder ??
          (context, error, stackTrace) => Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.category,
                  size: 32,
                  color: Colors.grey[400],
                ),
              ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 32,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
