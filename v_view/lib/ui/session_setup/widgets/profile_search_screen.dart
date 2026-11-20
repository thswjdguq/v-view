import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/session_setup/profile_catalog.dart';
import '../../../state/session_setup/profile_catalog_provider.dart';
import '../../../theme/app_theme.dart';

class ProfileSearchScreen extends ConsumerStatefulWidget {
  const ProfileSearchScreen({
    super.key,
    required this.type,
    this.selected = const [],
  });
  final ProfileCatalogType type;
  final List<String> selected;
  @override
  ConsumerState<ProfileSearchScreen> createState() =>
      _ProfileSearchScreenState();
}

class _ProfileSearchScreenState extends ConsumerState<ProfileSearchScreen> {
  final _query = TextEditingController();
  late final List<String> _selected = List.of(widget.selected);
  bool get _multiple => widget.type == ProfileCatalogType.certification;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _select(ProfileCatalogEntry entry) {
    if (!_multiple) {
      Navigator.pop(context, <String>[entry.name]);
      return;
    }
    setState(() {
      if (_selected.any(entry.hasExactName)) {
        _selected.removeWhere(entry.hasExactName);
      } else {
        _selected.add(entry.name);
      }
    });
  }

  void _addCustom() {
    final name = _query.text.trim();
    if (name.isEmpty) return;
    if (!_multiple) {
      Navigator.pop(context, <String>[name]);
      return;
    }
    setState(() {
      if (!_selected.any(
        (e) => normalizeProfileName(e) == normalizeProfileName(name),
      )) {
        _selected.add(name);
      }
      _query.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(profileCatalogProvider(widget.type));
    final entries = catalog.valueOrNull ?? const <ProfileCatalogEntry>[];
    final results = searchProfileCatalog(entries, _query.text);
    final custom =
        _query.text.trim().isNotEmpty &&
        !entries.any((e) => e.hasExactName(_query.text)) &&
        !_selected.any(
          (e) => normalizeProfileName(e) == normalizeProfileName(_query.text),
        );
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      appBar: AppBar(title: Text(_multiple ? '자격증 검색' : '학교 검색')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: TextField(
                        key: const ValueKey('profile-search-query'),
                        controller: _query,
                        autofocus: true,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: _multiple ? '자격증 이름' : '학교 이름',
                          hintText: _multiple
                              ? '예) 정보, 정처기, SQLD'
                              : '예) 충남, 서울대',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: '검색어 지우기',
                            onPressed: () {
                              _query.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _multiple
                            ? '여러 개 선택할 수 있어요. 과거 명칭도 포함되어 있으니 증서의 정확한 이름을 골라 주세요.'
                            : '대학·전문대학·대학원 이름으로 검색해요. 없는 학교는 직접 추가해 주세요.',
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ),
                  if (_multiple && _selected.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: LayoutBuilder(
                          builder: (context, constraints) => Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final name in _selected)
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  child: InputChip(
                                    label: Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onDeleted: () =>
                                        setState(() => _selected.remove(name)),
                                    deleteButtonTooltipMessage: '선택에서 $name 삭제',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (custom)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: OutlinedButton.icon(
                          onPressed: _addCustom,
                          icon: const Icon(Icons.add),
                          label: Text(
                            '“${_query.text.trim()}” 직접 추가',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  if (catalog.hasError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              '검색 목록을 불러오지 못했어요. 직접 추가하거나 다시 불러올 수 있어요.',
                            ),
                            TextButton(
                              onPressed: () => ref.invalidate(
                                profileCatalogProvider(widget.type),
                              ),
                              child: const Text('목록 다시 불러오기'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (catalog.isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (results.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            _query.text.trim().isEmpty
                                ? '이름을 입력해 검색해 주세요.'
                                : '일치하는 항목이 없어요. 위에서 직접 추가할 수 있어요.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final entry = results[index];
                        final selected = _selected.any(entry.hasExactName);
                        return ListTile(
                          key: ValueKey('option-${entry.name}'),
                          title: Text(entry.name),
                          subtitle: entry.detail.isEmpty
                              ? null
                              : Text(entry.detail),
                          leading: _multiple
                              ? Checkbox(
                                  value: selected,
                                  onChanged: (_) => _select(entry),
                                )
                              : Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.school_outlined,
                                  color: AppColors.primary,
                                ),
                          onTap: () => _select(entry),
                        );
                      }, childCount: results.length),
                    ),
                ],
              ),
            ),
            if (_multiple)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, List<String>.of(_selected)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: Text('선택 완료 (${_selected.length}개)'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
