import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/session_setup/profile_catalog.dart';
import '../../../state/session_setup/session_setup_provider.dart';
import '../../../theme/app_theme.dart';
import 'profile_search_screen.dart';

class ProfileSelectionField extends ConsumerWidget {
  const ProfileSelectionField({super.key, required this.type});
  final ProfileCatalogType type;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(sessionInputProvider);
    final multiple = type == ProfileCatalogType.certification;
    final selected = multiple
        ? input.certificationNames
        : input.school.isEmpty
        ? <String>[]
        : <String>[input.school];
    void apply(List<String> names) {
      final notifier = ref.read(sessionInputProvider.notifier);
      if (multiple) {
        notifier.setCertificationNames(names);
      } else {
        notifier.setSchool(names.firstOrNull ?? '');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          multiple ? '자격증 (선택)' : '학교 (선택)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in selected)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Tooltip(
                    message: name,
                    child: InputChip(
                      label: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () =>
                          apply(selected.where((e) => e != name).toList()),
                      deleteButtonTooltipMessage: '$name 삭제',
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (selected.isNotEmpty) const SizedBox(height: 10),
        OutlinedButton.icon(
          key: ValueKey(multiple ? 'search-certifications' : 'search-school'),
          onPressed: () async {
            final names = await Navigator.push<List<String>>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProfileSearchScreen(type: type, selected: selected),
              ),
            );
            if (names != null && context.mounted) apply(names);
          },
          icon: const Icon(Icons.search),
          label: Text(multiple ? '자격증 검색·추가' : '학교 검색·추가'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
