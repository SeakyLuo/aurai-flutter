import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'recent_chats_page.dart';
import 'ai_contacts_page.dart';
import 'me_page.dart';
import 'discover_page.dart';
import 'home_tab_bar.dart';
import 'contacts_search_bar.dart';

final homeRouteObserver = RouteObserver<PageRoute<dynamic>>();

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  static final navigationKey = GlobalKey<_HomePageState>();

  static void showConversations() {
    final state = navigationKey.currentState!;
    state._pages.jumpToPage(0);
    state._pageChanged(0);
  }

  final ChatController controller;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final _recentKey = GlobalKey<RecentChatsPageState>();
  int _tab = 0;
  final _pages = PageController();
  final _contactSearch = TextEditingController();
  final _contactSearchFocus = FocusNode();
  bool _searchingContacts = false;
  bool _contactDetailOpen = false;

  void _contactDetailChanged(bool open) {
    setState(() => _contactDetailOpen = open);
  }

  void _toggleContactSearch() {
    _contactSearchFocus.unfocus();
    setState(() => _searchingContacts = !_searchingContacts);
  }

  late final List<Widget> _tabPages = [
    _HomeTabPage(
      child: RecentChatsPage(key: _recentKey, controller: widget.controller),
    ),
    _HomeTabPage(
      child: AiContactsPage(
        controller: widget.controller,
        root: true,
        searchController: _contactSearch,
        onToggleSearch: _toggleContactSearch,
        onDetailChanged: _contactDetailChanged,
      ),
    ),
    _HomeTabPage(child: DiscoverPage(controller: widget.controller)),
    _HomeTabPage(child: MePage(controller: widget.controller)),
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
    _contactSearch.dispose();
    _contactSearchFocus.dispose();
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
    setState(() {
      _tab = tab;
      if (tab != 1) _searchingContacts = false;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _tab == 0 && !_searchingContacts,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        if (_tab == 1 && _contactDetailOpen) return;
        if (_searchingContacts) {
          _toggleContactSearch();
        } else if (_tab != 0) {
          _select(0);
        }
      }
    },
    child: Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pages,
        onPageChanged: _pageChanged,
        children: _tabPages,
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: _searchingContacts
              ? MediaQuery.viewInsetsOf(context).bottom
              : 0,
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            IgnorePointer(
              ignoring: _searchingContacts,
              child: AnimatedSlide(
                offset: _searchingContacts ? const Offset(0, 1.5) : Offset.zero,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                child: ExcludeSemantics(
                  excluding: _searchingContacts,
                  child: HomeTabBar(
                    selected: _tab,
                    pages: _pages,
                    onSelected: _select,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_searchingContacts,
                child: ExcludeSemantics(
                  excluding: !_searchingContacts,
                  child: AnimatedSlide(
                    offset: _searchingContacts
                        ? Offset.zero
                        : const Offset(0, 1.5),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    onEnd: () {
                      if (_searchingContacts)
                        _contactSearchFocus.requestFocus();
                    },
                    child: ContactsSearchBar(
                      controller: _contactSearch,
                      focusNode: _contactSearchFocus,
                      onClose: _toggleContactSearch,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
