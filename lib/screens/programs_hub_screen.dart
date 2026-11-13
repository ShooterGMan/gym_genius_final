import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'discover_screen.dart';
import 'programs_screen.dart';

/// "Programs" tab: the user's own programs and the pre-built catalogue,
/// behind one segmented switcher (replaces the separate Discover tab).
class ProgramsHubScreen extends StatefulWidget {
  /// 0 = My programs, 1 = Discover.
  final int initialTab;

  const ProgramsHubScreen({super.key, this.initialTab = 0});

  @override
  State<ProgramsHubScreen> createState() => _ProgramsHubScreenState();
}

class _ProgramsHubScreenState extends State<ProgramsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 1),
  );

  @override
  void didUpdateWidget(covariant ProgramsHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // e.g. context.go('/programs?tab=discover') while already on this tab.
    if (oldWidget.initialTab != widget.initialTab) {
      _tabs.animateTo(widget.initialTab.clamp(0, 1));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                height: 40,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.black,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.5),
                  tabs: const [
                    Tab(text: 'MY PROGRAMS'),
                    Tab(text: 'DISCOVER'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: TabBarView(
                  controller: _tabs,
                  children: const [
                    ProgramsScreen(),
                    DiscoverScreen(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
