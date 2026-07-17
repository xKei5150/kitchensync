import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kitchensync/app/design_tokens.dart';
import 'package:kitchensync/core/session/active_household_id_provider.dart';
import 'package:kitchensync/core/widgets/widgets.dart';
import 'package:kitchensync/features/shopping/domain/entities/shopping_plan.dart';
import 'package:kitchensync/features/shopping/presentation/providers/shopping_repository_providers.dart';

class ShoppingHistoryScreen extends ConsumerStatefulWidget {
  const ShoppingHistoryScreen({super.key});

  @override
  ConsumerState<ShoppingHistoryScreen> createState() =>
      _ShoppingHistoryScreenState();
}

class _ShoppingHistoryScreenState extends ConsumerState<ShoppingHistoryScreen> {
  var _records = const <ShoppingListRecord>[];
  String? _nextCursorId;
  Object? _error;
  var _isLoading = true;
  var _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadInitial);
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _records = const [];
      _nextCursorId = null;
    });
    await _loadPage();
  }

  Future<void> _loadPage() async {
    if (_isLoadingMore) return;
    final cursor = _nextCursorId;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ref
          .read(shoppingRepositoryProvider)
          .loadCompletedHistory(
            ref.read(activeHouseholdIdProvider),
            afterListId: cursor,
          );
      if (!mounted) return;
      setState(() {
        _records = List.unmodifiable([..._records, ...page.records]);
        _nextCursorId = page.nextCursorId;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: ks.surfaceBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KsTokens.space16,
            KsTokens.space8,
            KsTokens.space16,
            KsTokens.space24,
          ),
          children: [
            KsFolioHeader(
              eyebrow: 'The Shop',
              title: 'Completed shops',
              actions: [
                KsHeaderAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space16),
            if (_error != null) ...[
              KsErrorAlert(message: 'Could not load completed shops: $_error'),
              const SizedBox(height: KsTokens.space12),
              FilledButton(
                onPressed: _records.isEmpty ? _loadInitial : _loadPage,
                child: const Text('Retry'),
              ),
              const SizedBox(height: KsTokens.space16),
            ],
            if (_records.isEmpty && _error == null)
              const KsEmptyState(
                icon: Icons.history_rounded,
                title: 'No completed shops yet',
                subtitle: 'Finished shopping lists will appear here.',
              )
            else ...[
              for (final record in _records) ...[
                _CompletedShoppingTile(record: record),
                const SizedBox(height: KsTokens.space8),
              ],
              if (_nextCursorId != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoadingMore ? null : _loadPage,
                    child: _isLoadingMore
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Load more'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompletedShoppingTile extends StatelessWidget {
  const _CompletedShoppingTile({required this.record});

  final ShoppingListRecord record;

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    final completedAt = DateFormat(
      'd MMM y, h:mm a',
    ).format(record.completionTime);
    return Material(
      color: ks.surfaceRaised,
      borderRadius: BorderRadius.circular(KsTokens.radius12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('completed-history-${record.id}'),
        onTap: () => context.push('/shop/list/${record.id}'),
        child: Container(
          padding: const EdgeInsets.all(KsTokens.space12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KsTokens.radius12),
            border: Border.all(color: ks.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: KsTokens.fresh,
              ),
              const SizedBox(width: KsTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _historyTypeLabel(record.type),
                      style: KsTokens.shoppingHomeListTitle.copyWith(
                        color: ks.textPrimary,
                      ),
                    ),
                    const SizedBox(height: KsTokens.space2),
                    Text(
                      '$completedAt · ${record.items.length} '
                      '${record.items.length == 1 ? 'item' : 'items'}',
                      style: KsTokens.shoppingHomeListMetadata.copyWith(
                        color: ks.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ks.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

String _historyTypeLabel(ShoppingListType type) => switch (type) {
  ShoppingListType.scheduled => 'Scheduled shop',
  ShoppingListType.shopNow => 'Shop Now',
  ShoppingListType.suggested => 'Suggested shop',
  ShoppingListType.emergency => 'Emergency shop',
};
