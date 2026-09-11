import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_surface.dart';
import 'compose_icon.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  const ChatHeader({super.key, required this.onMenu, required this.onNew});
  final VoidCallback onMenu;
  final VoidCallback onNew;
  @override
  Size get preferredSize => const Size.fromHeight(76);
  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    forceMaterialTransparency: true,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    flexibleSpace: Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: MediaQuery.paddingOf(context).top + 18,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xf2ffffff), Color(0x00ffffff)],
            stops: [0, 0.65, 1],
          ),
        ),
      ),
    ),
    toolbarHeight: 76,
    titleSpacing: 18,
    title: Row(
      children: [
        GlassSurface(
          radius: 28,
          child: RoundAction(
            icon: Icons.menu_rounded,
            label: '会话菜单',
            onPressed: onMenu,
          ),
        ),
        const Spacer(),
        GlassSurface(
          radius: 28,
          child: RoundAction(
            icon: Icons.edit_square,
            iconWidget: const ComposeIcon(),
            label: '新建会话',
            onPressed: onNew,
          ),
        ),
      ],
    ),
  );
}
