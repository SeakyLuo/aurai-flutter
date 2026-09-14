import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'recent_chats_page.dart';
import 'home_drawer.dart';
import 'drawer_drag_region.dart';

final homeRouteObserver = RouteObserver<PageRoute<dynamic>>();

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  final ChatController controller;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final _recentKey = GlobalKey<RecentChatsPageState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    homeRouteObserver.subscribe(
      this,
      ModalRoute.of(context)! as PageRoute<dynamic>,
    );
  }

  @override
  void didPopNext() {
    _recentKey.currentState?.reload();
  }

  @override
  void dispose() {
    homeRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    drawer: HomeDrawer(controller: widget.controller),
    onDrawerChanged: (opened) async {
      if (!opened) return;
      try {
        await widget.controller.refreshConversations();
      } on Object {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('会话加载失败，请重试')));
      }
    },
    body: DrawerDragRegion(
      onOpen: () => _scaffoldKey.currentState!.openDrawer(),
      builder: (_) => RecentChatsPage(
        key: _recentKey,
        controller: widget.controller,
        onOpenMenu: () => _scaffoldKey.currentState!.openDrawer(),
      ),
    ),
  );
}
