import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../../domain/library_asset.dart';
import '../../platform/svg_image.dart';

Future<double> assetImageRatio(LibraryAsset asset) async {
  final image = await readVisionImage(File(asset.path), asset.mimeType);
  final buffer = await ui.ImmutableBuffer.fromUint8List(image.bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return descriptor.width / descriptor.height;
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

/// Independent columns retain each image's original proportions.
class AssetLibraryGridDelegate extends SliverGridDelegate {
  const AssetLibraryGridDelegate(this.ratios, {required this.columns});
  final List<double> ratios;
  final int columns;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    const gap = 14.0;
    final width = (constraints.crossAxisExtent - gap * (columns - 1)) / columns;
    final heights = List.filled(columns, 0.0);
    final geometries = <SliverGridGeometry>[];
    for (final ratio in ratios) {
      var column = 0;
      for (var i = 1; i < columns; i++) {
        if (heights[i] < heights[column]) column = i;
      }
      final height = width / ratio;
      final visualColumn = constraints.crossAxisDirection == AxisDirection.left
          ? columns - 1 - column
          : column;
      geometries.add(
        SliverGridGeometry(
          scrollOffset: heights[column],
          crossAxisOffset: visualColumn * (width + gap),
          mainAxisExtent: height,
          crossAxisExtent: width,
        ),
      );
      heights[column] += height + gap;
    }
    return _AssetGridLayout(geometries);
  }

  @override
  bool shouldRelayout(AssetLibraryGridDelegate oldDelegate) => true;
}

class _AssetGridLayout extends SliverGridLayout {
  const _AssetGridLayout(this.tiles);
  final List<SliverGridGeometry> tiles;

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i].trailingScrollOffset >= scrollOffset) return i;
    }
    return tiles.length - 1;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    for (var i = tiles.length - 1; i >= 0; i--) {
      if (tiles[i].scrollOffset <= scrollOffset) return i;
    }
    return 0;
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) => tiles[index];

  @override
  double computeMaxScrollOffset(int childCount) => tiles
      .take(childCount)
      .fold(
        0.0,
        (extent, tile) => extent > tile.trailingScrollOffset
            ? extent
            : tile.trailingScrollOffset,
      );
}
