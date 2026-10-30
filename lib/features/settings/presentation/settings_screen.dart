import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/icons/hara_icons.dart';
import '../../../core/theme/hara_tokens.dart';
import '../../../core/widgets/section_header.dart';
import 'settings_tile.dart';
import 'theme_mode_picker.dart';

/// Settings, opened from Home's app bar above the tab shell.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: HaraSpacing.xxxl),
        children: [
          const SectionHeader(title: 'Appearance'),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              HaraSpacing.gutter,
              HaraSpacing.sm,
              HaraSpacing.gutter,
              HaraSpacing.lg,
            ),
            child: ThemeModePicker(),
          ),
          const SectionHeader(title: 'About'),
          SettingsTile(
            icon: HaraIcons.info,
            title: 'Open-source licenses',
            subtitle: 'Fonts, icons and libraries used by HaraPlay',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'HaraPlay',
              applicationLegalese: 'MIT License\n© 2026 The HaraPlay Authors',
            ),
          ),
          if (kDebugMode) ...[
            const SectionHeader(title: 'Developer'),
            SettingsTile(
              icon: HaraIcons.slidersHorizontal,
              title: 'Design gallery',
              subtitle: 'Debug builds only',
              onTap: () => context.push(AppRoutes.designGallery),
            ),
            SettingsTile(
              icon: HaraIcons.folder,
              title: 'MediaStore inspector',
              subtitle: 'Every song and tag the library scan reads',
              onTap: () => context.push(AppRoutes.mediaStoreDebug),
            ),
          ],
        ],
      ),
    );
  }
}
