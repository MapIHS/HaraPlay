import 'package:flutter/material.dart';

import '../../../core/theme/hara_colors.dart';
import '../../../core/theme/hara_tokens.dart';

/// Settings › About › Privacy: the privacy policy, in the app itself (it
/// can't open a web page: HaraPlay has no internet permission). Keep in
/// step with PRIVACY.md in the repository.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const updated = '7 November 2026';

  static const _sections = <(String, List<String>)>[
    (
      'The short version',
      [
        'HaraPlay collects no data, shares no data and sends nothing '
            'anywhere. It has no internet permission, so it cannot connect '
            'to the internet at all. There are no accounts, ads, analytics, '
            'crash reporting or tracking.',
      ],
    ),
    (
      'What HaraPlay uses on your phone, and why',
      [
        'Your music files: to list and play your songs and to read their '
            'tags, cover art and lyrics. Files are only read, never changed '
            'or uploaded.',
        'Notifications: to show the playback controls while music plays.',
        'Foreground service and wake lock: to keep playing in the '
            'background and with the screen off.',
        'Network state: added by Android\'s media player library. It can '
            'only tell whether a network exists; without the internet '
            'permission it gives no internet access, and HaraPlay doesn\'t '
            'use it.',
      ],
    ),
    (
      'What HaraPlay stores',
      [
        'Your likes, playlists, play history, settings and a cache of cover '
            'art are stored only in HaraPlay\'s own storage on your phone, '
            'until you clear the app\'s data or uninstall it.',
      ],
    ),
    (
      'Backups',
      [
        'HaraPlay\'s backup (Settings › Back up) creates a file only when you '
            'ask for it, in a place you choose. HaraPlay never sends it '
            'anywhere.',
        'Android\'s automatic cloud backup is turned off for HaraPlay, so '
            'its data isn\'t copied to your Google account. When you set up '
            'a new phone by connecting it to the old one, Android 12 and '
            'newer can still copy it directly between the two phones.',
      ],
    ),
    (
      'Children',
      ['HaraPlay collects no data from anyone, including children.'],
    ),
    (
      'Changes and contact',
      [
        'If this policy changes, the new version comes with an app update '
            'and is published at github.com/MapIHS/HaraPlay (PRIVACY.md, '
            'also in Bahasa Indonesia). Questions: open an issue there.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = HaraColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HaraSpacing.gutter,
          HaraSpacing.sm,
          HaraSpacing.gutter,
          HaraSpacing.xxxl,
        ),
        children: [
          Text(
            'Last updated: $updated',
            style: textTheme.bodySmall!.copyWith(color: colors.mutedForeground),
          ),
          for (final (title, paragraphs) in _sections) ...[
            const SizedBox(height: HaraSpacing.lg),
            Text(title, style: textTheme.titleMedium),
            for (final paragraph in paragraphs)
              Padding(
                padding: const EdgeInsets.only(top: HaraSpacing.sm),
                child: Text(paragraph, style: textTheme.bodyMedium),
              ),
          ],
        ],
      ),
    );
  }
}
