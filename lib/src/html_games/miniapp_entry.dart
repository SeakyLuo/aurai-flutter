import '../domain/message_sender.dart';

enum MiniappKind { draft, published, installed }

class MiniappEntry {
  const MiniappEntry({
    required this.id,
    required this.title,
    required this.publisher,
    this.publisherProfile,
    this.iconPath,
    this.iconAsset,
    this.description = '',
    this.publishedTitle,
    this.asset,
    this.bundleVersion,
    this.updatedAt,
    this.kind = MiniappKind.published,
    this.sourceId,
    this.installedId,
    this.installedRevision,
    this.revision = 0,
    this.metadataRevision = 0,
    this.listed = false,
  });
  final String id, title, publisher, description;
  final MessageSender? publisherProfile;
  final String? iconPath, iconAsset;
  final String? asset,
      bundleVersion,
      sourceId,
      installedId,
      installedRevision,
      publishedTitle;
  final int? updatedAt;
  final MiniappKind kind;
  final int revision, metadataRevision;
  bool get canEditMetadata =>
      draft ||
      bundled ||
      (kind == MiniappKind.published && publisherProfile?.id == 'user:local');

  MiniappEntry withMetadata(
    String name,
    String summary,
    int revision, {
    String? iconPath,
    bool replaceIcon = false,
  }) => MiniappEntry(
    id: id,
    title: name,
    description: summary,
    publisher: publisher,
    publisherProfile: publisherProfile,
    iconAsset: iconAsset,
    iconPath: replaceIcon ? iconPath : this.iconPath,
    publishedTitle: name,
    asset: asset,
    bundleVersion: bundleVersion,
    updatedAt: updatedAt,
    kind: kind,
    sourceId: sourceId,
    installedId: installedId,
    installedRevision: installedRevision,
    revision: this.revision,
    metadataRevision: revision,
    listed: listed,
  );
  final bool listed;
  bool get bundled => asset != null;
  bool get draft => kind == MiniappKind.draft;
  String get releaseKey => bundled ? bundleVersion! : '$revision';
  String get publicationId => sourceId ?? id;
  String get runtimeId => installedId ?? id;
  bool get hasUpdate =>
      !draft &&
      listed &&
      installedId != null &&
      installedRevision != releaseKey;
  String get status => draft
      ? (listed ? '已发布 · 第 $revision 版' : '未发布')
      : kind == MiniappKind.installed || installedId != null
      ? '已添加'
      : '已发布';
}
