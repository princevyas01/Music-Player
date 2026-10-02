import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Intelligent content-aware cropping service.
///
/// Analyzes image saliency (luminance gradients, color variance, edge energy)
/// and considers circular boundary clipping to ensure the focal subject
/// (faces, text, logos, artwork details) stays fully centered and visible
/// within circular album art containers.
class SmartCropService {
  /// Smartly crops the given image bytes or file to a square optimized for circular display.
  /// Returns the saved local file path of the cropped 512x512 image.
  static Future<String?> processAndSaveArtwork({
    required Uint8List imageBytes,
    required String trackId,
    String? outputDirectoryPath,
    String prefix = 'art_',
  }) async {
    String outDir;
    if (outputDirectoryPath != null && outputDirectoryPath.isNotEmpty) {
      outDir = outputDirectoryPath;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      outDir = '${appDir.path}/custom_artwork';
    }

    final savedPath = await compute(
      _smartCropTask,
      _SmartCropPayload(imageBytes, trackId, outDir, prefix),
    );

    if (savedPath != null) {
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}
    }

    return savedPath;
  }

  /// Top-level worker method for compute isolate
  static Future<String?> _smartCropTask(_SmartCropPayload payload) async {
    try {
      final decoded = img.decodeImage(payload.bytes);
      if (decoded == null) return null;

      final fitted = fitArtworkForCircle(decoded, canvasSize: 512);

      final encoded = img.encodeJpg(fitted, quality: 90);

      final artworkDir = Directory(payload.outDirPath);
      if (!await artworkDir.exists()) {
        await artworkDir.create(recursive: true);
      }

      final safeId = payload.trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      // Clean up previous custom or fitted artwork for this track to preserve storage
      try {
        if (artworkDir.existsSync()) {
          final entries = artworkDir.listSync();
          for (final entry in entries) {
            if (entry is File) {
              final filename = entry.path.split(Platform.pathSeparator).last;
              if (filename.startsWith('${payload.prefix}${safeId}_') ||
                  filename == '${payload.prefix}$safeId.jpg' ||
                  filename.startsWith('auto_${safeId}_') ||
                  filename == 'auto_$safeId.jpg' ||
                  filename.startsWith('fit_${safeId}_') ||
                  filename == 'fit_$safeId.jpg') {
                try {
                  entry.deleteSync();
                } catch (_) {}
              }
            }
          }
        }
      } catch (_) {}

      final targetFile = File('${artworkDir.path}/${payload.prefix}${safeId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await targetFile.writeAsBytes(encoded, flush: true);

      return targetFile.path;
    } catch (e) {
      debugPrint('SmartCropService error: $e');
      return null;
    }
  }

  /// Fits an artwork image into a circular canvas without cutting off landscape or portrait content.
  ///
  /// For landscape images (e.g. 16:9 YouTube thumbnails), it preserves the full uncropped
  /// rectangle, scaling it to span across the circle (~92% of circle diameter), and fills the
  /// top and bottom circular segments with a smooth ambient blurred extension of the artwork.
  ///
  /// For already-square images (e.g. standard 1:1 album covers), it resizes directly to [canvasSize]x[canvasSize].
  static img.Image fitArtworkForCircle(img.Image src, {int canvasSize = 512}) {
    if (src.width <= 0 || src.height <= 0) return src;

    final double aspect = src.width / src.height;

    // Already roughly square: standard album cover (0.92 .. 1.08)
    if (aspect >= 0.92 && aspect <= 1.08) {
      if (src.width == canvasSize && src.height == canvasSize) {
        return src;
      }
      return img.copyResize(
        src,
        width: canvasSize,
        height: canvasSize,
        interpolation: img.Interpolation.cubic,
      );
    }

    // Determine target dimensions for the sharp foreground image
    int targetW;
    int targetH;

    if (aspect > 1.0) {
      // Landscape (e.g. 16:9 YouTube thumbnail)
      // Allow corners to touch or slightly touch circular boundary (~5% radius margin)
      // while showing almost 100% of the entire landscape thumbnail width.
      final double maxRadius = (canvasSize / 2.0) * 1.05;
      final double calculatedW = (2.0 * maxRadius) / sqrt(1.0 + (1.0 / (aspect * aspect)));
      targetW = min((canvasSize * 0.92).round(), calculatedW.round());
      targetH = max(1, (targetW / aspect).round());
    } else {
      // Portrait (tall)
      final double maxRadius = (canvasSize / 2.0) * 1.05;
      final double calculatedH = (2.0 * maxRadius) / sqrt(1.0 + (aspect * aspect));
      targetH = min((canvasSize * 0.92).round(), calculatedH.round());
      targetW = max(1, (targetH * aspect).round());
    }

    // 1. Create ambient blurred background
    // Downscale for fast, butter-smooth Gaussian diffusion
    final bgSquare = smartCropToSquare(src);
    final bgThumb = img.copyResize(
      bgSquare,
      width: 96,
      height: 96,
      interpolation: img.Interpolation.linear,
    );

    // Darken ambient background slightly for high contrast vinyl aesthetics
    for (final pixel in bgThumb) {
      pixel.r = (pixel.r * 0.65).round();
      pixel.g = (pixel.g * 0.65).round();
      pixel.b = (pixel.b * 0.65).round();
    }

    final blurredThumb = img.gaussianBlur(bgThumb, radius: 10);
    final canvas = img.copyResize(
      blurredThumb,
      width: canvasSize,
      height: canvasSize,
      interpolation: img.Interpolation.linear,
    );

    // 2. Resize sharp foreground artwork preserving natural aspect ratio
    final fg = img.copyResize(
      src,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.cubic,
    );

    // 3. Composite foreground centered onto the ambient background
    final dstX = (canvasSize - targetW) ~/ 2;
    final dstY = (canvasSize - targetH) ~/ 2;
    img.compositeImage(canvas, fg, dstX: dstX, dstY: dstY);

    return canvas;
  }

  /// Core intelligent crop algorithm.
  /// Evaluates candidate square windows weighted by circular visibility
  /// (protecting features from being clipped in the 4 circular corners)
  /// and centers the most detailed/vibrant focal region.
  static img.Image smartCropToSquare(img.Image src) {
    if (src.width == src.height) {
      return src;
    }

    final int targetSize = min(src.width, src.height);
    if (targetSize <= 0) return src;

    // Downscale for fast saliency analysis (max 120px on largest dimension)
    const int maxDim = 120;
    final double scale = maxDim / max(src.width, src.height);
    final int thumbW = max(10, (src.width * scale).round());
    final int thumbH = max(10, (src.height * scale).round());

    final thumb = img.copyResize(
      src,
      width: thumbW,
      height: thumbH,
      interpolation: img.Interpolation.linear,
    );

    // Compute saliency energy grid
    final energy = List<List<double>>.generate(
      thumbH,
      (_) => List<double>.filled(thumbW, 0.0),
    );

    for (int y = 0; y < thumbH; y++) {
      for (int x = 0; x < thumbW; x++) {
        final p = thumb.getPixel(x, y);

        // Edge detection (horizontal & vertical luminance gradient)
        double dx = 0.0;
        double dy = 0.0;
        if (x > 0 && x < thumbW - 1) {
          dx = (thumb.getPixel(x + 1, y).luminance - thumb.getPixel(x - 1, y).luminance).abs().toDouble();
        }
        if (y > 0 && y < thumbH - 1) {
          dy = (thumb.getPixel(x, y + 1).luminance - thumb.getPixel(x, y - 1).luminance).abs().toDouble();
        }
        final edge = sqrt(dx * dx + dy * dy);

        // Color saturation / vibrancy (faces, album titles, focal objects stand out)
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        final maxC = max(r, max(g, b));
        final minC = min(r, min(g, b));
        final sat = maxC > 0 ? (maxC - minC) / 255.0 : 0.0;

        // Combined saliency
        energy[y][x] = edge * 0.75 + sat * 0.25;
      }
    }

    // Find optimal sliding window of size thumbCropSize
    final int thumbCropSize = min(thumbW, thumbH);
    double bestScore = -1.0;
    int bestThumbX = 0;
    int bestThumbY = 0;

    final double halfCrop = thumbCropSize / 2.0;

    if (thumbW > thumbH) {
      // Landscape: slide along X axis
      final int maxOffset = thumbW - thumbCropSize;
      final int step = max(1, maxOffset ~/ 50);

      for (int ox = 0; ox <= maxOffset; ox += step) {
        final score = _evaluateWindowScore(
          energy,
          winX: ox,
          winY: 0,
          cropSize: thumbCropSize,
          thumbW: thumbW,
          thumbH: thumbH,
          halfCrop: halfCrop,
        );

        if (score > bestScore) {
          bestScore = score;
          bestThumbX = ox;
        }
      }
    } else {
      // Portrait: slide along Y axis
      final int maxOffset = thumbH - thumbCropSize;
      final int step = max(1, maxOffset ~/ 50);

      for (int oy = 0; oy <= maxOffset; oy += step) {
        final score = _evaluateWindowScore(
          energy,
          winX: 0,
          winY: oy,
          cropSize: thumbCropSize,
          thumbW: thumbW,
          thumbH: thumbH,
          halfCrop: halfCrop,
        );

        if (score > bestScore) {
          bestScore = score;
          bestThumbY = oy;
        }
      }
    }

    // Map thumb crop offset back to full-resolution coordinates
    final int finalCropX = (bestThumbX / scale).round().clamp(0, src.width - targetSize);
    final int finalCropY = (bestThumbY / scale).round().clamp(0, src.height - targetSize);

    return img.copyCrop(
      src,
      x: finalCropX,
      y: finalCropY,
      width: targetSize,
      height: targetSize,
    );
  }

  /// Evaluates window energy with circular boundary weighting and center bias.
  static double _evaluateWindowScore(
    List<List<double>> energy, {
    required int winX,
    required int winY,
    required int cropSize,
    required int thumbW,
    required int thumbH,
    required double halfCrop,
  }) {
    double totalEnergy = 0.0;
    final double centerX = winX + halfCrop;
    final double centerY = winY + halfCrop;

    for (int y = winY; y < winY + cropSize; y++) {
      for (int x = winX; x < winX + cropSize; x++) {
        final e = energy[y][x];

        // Distance from center of the circle, normalized to 0.0 .. 1.0 (1.0 = circle radius)
        final double dist = sqrt(pow(x - centerX, 2) + pow(y - centerY, 2)) / halfCrop;

        // Weight based on circular visibility:
        // Inside circle (dist <= 0.85): full weight
        // Near edge (0.85 < dist <= 1.0): smooth falloff
        // Outside circle (corners that get clipped): heavily penalized
        double circleWeight;
        if (dist <= 0.85) {
          circleWeight = 1.0 - (dist * 0.15); // Slight bonus towards dead center
        } else if (dist <= 1.0) {
          circleWeight = (1.0 - dist) / 0.15 * 0.85;
        } else {
          // Clipped corner!
          circleWeight = 0.02;
        }

        totalEnergy += e * circleWeight;
      }
    }

    // Slight bias toward geometric center if energy is completely flat (e.g. uniform color)
    final double centerFraction = (thumbW > thumbH)
        ? 1.0 - ((winX + halfCrop - thumbW / 2.0).abs() / (thumbW / 2.0)) * 0.08
        : 1.0 - ((winY + halfCrop - thumbH / 2.0).abs() / (thumbH / 2.0)) * 0.08;

    return totalEnergy * centerFraction;
  }
}

class _SmartCropPayload {
  final Uint8List bytes;
  final String trackId;
  final String outDirPath;
  final String prefix;
  _SmartCropPayload(this.bytes, this.trackId, this.outDirPath, this.prefix);
}
