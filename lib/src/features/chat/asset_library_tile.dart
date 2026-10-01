import 'package:flutter/material.dart';
import '../../domain/library_asset.dart';
import '../../platform/svg_image.dart';
import 'file_type_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'unavailable_image.dart';

class AssetLibraryTile extends StatelessWidget {
  const AssetLibraryTile({
    super.key,
    required this.asset,
    required this.onTap,
    required this.onMore,
    required this.onSelect,
    this.selectionMode = false,
    this.selected = false,
    this.grid = false,
  });
  final LibraryAsset asset;
  final VoidCallback onTap, onSelect;
  final ValueChanged<BuildContext> onMore;
  final bool selectionMode, selected, grid;

  Widget _thumbnail() => asset.isImage
      ? Image(
          image: ResizeImage(
            localImageProvider(asset.path),
            width: grid ? 480 : 144,
          ),
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => const UnavailableImage(),
        )
      : Center(child: FileTypeIcon(file: asset.file));

  @override
  Widget build(BuildContext context) => Material(
    color: settingsFieldColor(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: selected && selectionMode
          ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
          : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: Builder(
      builder: (tileContext) => InkWell(
        onTap: selectionMode ? onSelect : onTap,
        onLongPress: () => onMore(tileContext),
        child: grid && asset.isImage
            ? Semantics(
                label: asset.name,
                selected: selectionMode ? selected : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _thumbnail(),
                    if (selectionMode)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _selectionIndicator(context),
                      ),
                  ],
                ),
              )
            : grid
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _thumbnail()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
                    child: _labels(context),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox.square(
                        dimension: 56,
                        child: _thumbnail(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _labels(context)),
                  ],
                ),
              ),
      ),
    ),
  );

  Widget _selectionIndicator(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      checked: selected,
      button: true,
      label: selected ? '取消选择' : '选择资产',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? colors.primary
                  : colors.surface.withValues(alpha: .9),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: 1.5,
              ),
            ),
            child: selected
                ? Padding(
                    padding: const EdgeInsets.all(3),
                    child: FittedBox(
                      child: SettingsIcon(
                        type: SettingsIconType.check,
                        color: colors.onPrimary,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _labels(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              asset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              '${asset.source.label} · ${asset.sizeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      if (selectionMode)
        _selectionIndicator(context)
      else
        Builder(
          builder: (context) => IconButton(
            tooltip: '资产操作',
            icon: const SettingsIcon(type: SettingsIconType.more),
            onPressed: () => onMore(context),
          ),
        ),
    ],
  );
}
