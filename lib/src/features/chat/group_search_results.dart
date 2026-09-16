import 'package:flutter/material.dart';
import '../../storage/group_message_search.dart';
import '../../html_games/html_game_store.dart';
import 'group_search_message_tile.dart';
import 'attachment_action_icon.dart';
import 'file_attachments.dart';
import 'image_attachments.dart';
import 'member_avatar.dart';
import 'message_preview_text.dart';
import 'message_content_preview.dart';

class GroupSearchResults extends StatelessWidget {
  const GroupSearchResults({
    super.key,
    required this.results,
    required this.type,
    required this.query,
    required this.scroll,
    required this.loading,
    required this.onLocate,
    required this.onOpenProfile,
    required this.conversationId,
    required this.htmlGames,
  });
  final String conversationId;
  final HtmlGameStore htmlGames;
  final List<GroupMessageSearchResult> results;
  final GroupSearchType type;
  final String query;
  final ScrollController scroll;
  final bool loading;
  final ValueChanged<GroupMessageSearchResult> onLocate;
  final ValueChanged<GroupMessageSearchResult> onOpenProfile;

  Widget _avatar(GroupMessageSearchResult result, double size) => Semantics(
    button: true,
    label: '查看${result.sender.name}的资料',
    child: InkWell(
      onTap: () => onOpenProfile(result),
      borderRadius: BorderRadius.circular(size / 2),
      child: MemberAvatar(sender: result.sender, size: size),
    ),
  );

  String _month(DateTime date) => '${date.year}年${date.month}月';
  String _date(DateTime date) =>
      '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  TextSpan _highlight(
    BuildContext context,
    String source, {
    bool snippet = false,
    bool literal = false,
  }) => MessagePreviewText.span(
    context,
    source,
    query: query,
    snippet: snippet,
    literal: literal,
  );
  Widget _monthTitle(BuildContext context, String value) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
    child: Text(
      value,
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  Widget _locate(GroupMessageSearchResult result) => IconButton(
    tooltip: '定位原消息',
    onPressed: () => onLocate(result),
    icon: const AttachmentActionIcon(type: AttachmentActionIconType.locate),
  );
  Widget _meta(
    BuildContext context,
    GroupMessageSearchResult result, {
    bool action = false,
  }) => Row(
    children: [
      _avatar(result, 24),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          result.sender.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      ),
      Text(
        _date(result.createdAt),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      if (action) _locate(result),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final gallery = [for (final r in results) ...r.images];
    final months = <String, List<GroupMessageSearchResult>>{};
    for (final r in results) {
      months.putIfAbsent(_month(r.createdAt), () => []).add(r);
    }
    final slivers = <Widget>[];
    for (final entry in months.entries) {
      slivers.add(SliverToBoxAdapter(child: _monthTitle(context, entry.key)));
      if (type == GroupSearchType.image) {
        final images = [
          for (final r in entry.value)
            for (final image in r.images) (message: r, image: image),
        ];
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final item = images[i];
                return LayoutBuilder(
                  builder: (context, size) => ImageAttachment(
                    image: item.image,
                    gallery: gallery,
                    size: size.maxWidth,
                    borderRadius: 10,
                    sourceMessageId: item.message.id,
                  ),
                );
              }, childCount: images.length),
            ),
          ),
        );
      } else {
        slivers.add(
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final r = entry.value[index];
              if (type == GroupSearchType.file)
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      _meta(context, r, action: true),
                      for (final file in r.files)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: FileAttachmentCard(
                            file: file,
                            title: _highlight(
                              context,
                              file.name,
                              literal: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              if (r.html != null || r.interactive != null)
                return GroupSearchMessageTile(
                  key: ValueKey(r.id),
                  result: r,
                  conversationId: conversationId,
                  htmlGames: htmlGames,
                  time: _date(r.createdAt),
                  onLocate: () => onLocate(r),
                  onOpenProfile: () => onOpenProfile(r),
                );
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onLocate(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _avatar(r, 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.sender.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                  Text(
                                    _date(r.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              MessageContentPreview(
                                text: r.text,
                                images: r.images,
                                files: r.files,
                                htmlTitle: r.html?.title,
                                htmlPreview: r.html?.preview,
                                interactiveTitle: r.interactive?.title,
                                query: query,
                                gallery: gallery,
                                sourceMessageId: r.id,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }, childCount: entry.value.length),
          ),
        );
      }
    }
    if (loading)
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    return CustomScrollView(
      controller: scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 24),
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ],
    );
  }
}
