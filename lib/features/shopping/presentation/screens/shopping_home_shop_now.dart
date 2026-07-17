part of 'shopping_screen.dart';

/// The Shop Now setup — "how far ahead?" — a bottom sheet that pulls future
/// lists forward; only what you actually buy is paid down.
class _ShopNowSheet extends ConsumerStatefulWidget {
  const _ShopNowSheet();

  @override
  ConsumerState<_ShopNowSheet> createState() => _ShopNowSheetState();
}

class _ShopNowSheetState extends ConsumerState<_ShopNowSheet> {
  static const _presets = [1, 3, 7, 14];
  late final DateTime _today;
  late DateTime _endDate;
  ShoppingListPlan? _preview;
  Object? _error;
  var _loading = false;
  var _generating = false;
  var _generationFailed = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _today = DateTime(now.year, now.month, now.day);
    _endDate = _today;
    _loadPreview();
  }

  int get _daysInclusive => _endDate.difference(_today).inDays + 1;

  bool get _hasItemsToGenerate => _preview?.items.isNotEmpty ?? false;

  String get _rangeSummary =>
      '${_formatDate(_today)} to ${_formatDate(_endDate)} '
      '($_daysInclusive ${_daysInclusive == 1 ? 'day' : 'days'})';

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
      _generationFailed = false;
    });
    try {
      final preview = await ref
          .read(shoppingPlanningControllerProvider)
          .previewShopNowList(startDate: _today, endDate: _endDate);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    final preview = _preview;
    if (preview == null || _generating) return;
    setState(() {
      _generating = true;
      _error = null;
      _generationFailed = false;
    });
    try {
      final record = await ref
          .read(shoppingPlanningControllerProvider)
          .persistShopNowPreview(preview);
      if (mounted) Navigator.of(context).pop(record.id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _generationFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KsTokens.space20,
          KsTokens.space12,
          KsTokens.space20,
          KsTokens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: KsTokens.space16),
                decoration: BoxDecoration(
                  color: ks.borderStrong,
                  borderRadius: BorderRadius.circular(KsTokens.radiusFull),
                ),
              ),
            ),
            Text(
              'Shop how far ahead?',
              style: KsTokens.displaySmall.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 21,
                height: 1.15,
              ),
            ),
            if (!_loading) ...[
              const SizedBox(height: KsTokens.space6),
              Text(
                'Pull future lists forward — only what you actually buy '
                'is paid '
                'down.',
                style: KsTokens.bodySmall.copyWith(
                  color: ks.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: KsTokens.space16),
            ],
            if (!_loading) ...[
              Text(
                _rangeSummary,
                style: KsTokens.titleSmall.copyWith(color: ks.textPrimary),
              ),
              const SizedBox(height: KsTokens.space12),
              Wrap(
                spacing: KsTokens.space8,
                runSpacing: KsTokens.space8,
                children: [
                  for (final days in _presets)
                    ChoiceChip(
                      label: Text('$days ${days == 1 ? 'day' : 'days'}'),
                      selected: _daysInclusive == days,
                      onSelected: _generating
                          ? null
                          : (_) => _selectEndDate(
                              _today.add(Duration(days: days - 1)),
                            ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _generating ? null : _pickEndDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: const Text('Custom end date'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: KsTokens.space12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _ShopNowPreviewError(
                error: _error!,
                onRetry: _generationFailed ? _generate : _loadPreview,
                message: _generationFailed
                    ? 'Could not generate this list: $_error'
                    : 'Could not preview this range: $_error',
              )
            else
              _ShopNowPreviewSummary(preview: _preview),
            const SizedBox(height: KsTokens.space16),
            FilledButton(
              onPressed: _loading || _generating || !_hasItemsToGenerate
                  ? null
                  : _generate,
              child: Text(_generating ? 'Generating...' : 'Generate list'),
            ),
          ],
        ),
      ),
    );
  }

  void _selectEndDate(DateTime date) {
    setState(() => _endDate = date);
    _loadPreview();
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 27)),
    );
    if (selected != null && mounted) _selectEndDate(selected);
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
