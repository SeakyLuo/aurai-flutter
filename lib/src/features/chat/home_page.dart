import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'recent_chats_page.dart';
import 'ai_contacts_page.dart';
import 'settings_page.dart';
import 'home_tab_bar.dart';

final homeRouteObserver = RouteObserver<PageRoute<dynamic>>();

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  final ChatController controller;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final _recentKey = GlobalKey<RecentChatsPageState>();
  int _tab = 0;
  final _pages = PageController();

  late final List<Widget> _tabPages = [
    _HomeTabPage(
      child: RecentChatsPage(key: _recentKey, controller: widget.controller),
    ),
    _HomeTabPage(
      child: AiContactsPage(controller: widget.controller, root: true),
    ),
    _HomeTabPage(
      child: SettingsPage(
        controller: widget.controller,
        preparingGoal: () => false,
        root: true,
      ),
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    homeRouteObserver.subscribe(
      this,
      ModalRoute.of(context)! as PageRoute<dynamic>,
    );
  }

  @override
  void didPopNext() => _recentKey.currentState?.reload();

  @override
  void dispose() {
    _pages.dispose();
    homeRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _select(int tab) {
    if (_tab == tab) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _pages.animateToPage(
      tab,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  void _pageChanged(int tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _tab == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _tab != 0) _select(0);
    },
    child: Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pages,
        onPageChanged: _pageChanged,
        children: _tabPages,
      ),
      bottomNavigationBar: HomeTabBar(
        selected: _tab,
        pages: _pages,
        onSelected: _select,
      ),
    ),
  );
}

class _HomeTabPage extends StatefulWidget {
  const _HomeTabPage({required this.child});
  final Widget child;

  @override
  State<_HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<_HomeTabPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}
