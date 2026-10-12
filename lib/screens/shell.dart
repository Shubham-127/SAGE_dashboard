import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/enums.dart';
import '../state/sage_state.dart';
import '../widgets/pill.dart';
import 'architecture_page.dart';
import 'incidents_page.dart';
import 'knowledge_page.dart';
import 'overview_page.dart';

/// The frame around every page after login:
///   left sidebar (navigation)  +  top bar (title, role)  +  the page you picked.
/// It is a StatefulWidget because it REMEMBERS which page is selected.
class Shell extends StatefulWidget {
  Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int page = 0; // 0 = Overview, 1 = Incidents, 2 = Knowledge base, 3 = Architecture

  static const labels = ['Overview', 'Incidents', 'Knowledge base', 'Architecture'];
  static const titles = [
    'Control room overview',
    'Incident history',
    'Knowledge base (past incidents)',
    'Architecture and build progress',
  ];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.warning_amber_rounded,
    Icons.menu_book_outlined,
    Icons.account_tree_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900; // laptop vs phone-width

    // Pick the page. NOTE: no "const" on purpose, otherwise Flutter would not
    // redraw these pages when the data changes.
    Widget body;
    switch (page) {
      case 0:
        body = OverviewPage();
        break;
      case 1:
        body = IncidentsPage();
        break;
      case 2:
        body = KnowledgePage();
        break;
      default:
        body = ArchitecturePage();
    }

    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          _sidebar(wide),
          Expanded(
            child: Column(children: [
              _topBar(wide),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(wide ? 24 : 14),
                  child: body,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ---------- left sidebar ----------
  Widget _sidebar(bool wide) {
    return Container(
      width: wide ? 230 : 72, // on narrow screens show icons only
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
          child: Row(
              mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.accent, size: 26),
                if (wide) ...[
                  const SizedBox(width: 10),
                  const Text('SAGE',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          color: AppColors.text)),
                ],
              ]),
        ),
        for (var i = 0; i < labels.length; i++) _navItem(i, wide),
        const Spacer(),
        InkWell(
          onTap: sage.logout,
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(12),
            child: Row(
                mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, size: 20, color: AppColors.muted),
                  if (wide) ...[
                    const SizedBox(width: 12),
                    const Text('Sign out', style: TextStyle(color: AppColors.muted)),
                  ],
                ]),
          ),
        ),
      ]),
    );
  }

  Widget _navItem(int i, bool wide) {
    final selected = page == i;
    return InkWell(
      onTap: () => setState(() => page = i), // setState = "redraw me with the new page"
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
            mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(icons[i], size: 20, color: selected ? AppColors.accent : AppColors.muted),
              if (wide) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(labels[i],
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: selected ? AppColors.text : AppColors.muted,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                ),
              ],
            ]),
      ),
    );
  }

  // ---------- top bar ----------
  Widget _topBar(bool wide) {
    final isAdmin = sage.role == Role.admin;
    final showSim = MediaQuery.of(context).size.width >= 760;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 14, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Expanded(
          child: Text(titles[page],
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
        ),
        // if (showSim) ...[
        //   const Pill('Simulated data, no live backend', AppColors.warn, icon: Icons.science_outlined),
        //   const SizedBox(width: 10),
        // ],
        Pill(isAdmin ? 'Admin' : 'Viewer (read-only)', AppColors.accent, icon: Icons.lock_outline),
      ]),
    );
  }
}
