part of 'calendar_screen.dart';

class _CalendarDefaultsInput {
  const _CalendarDefaultsInput({
    required this.dateRangeStart,
    required this.dateRangeEnd,
    required this.defaultServingSize,
    required this.mealsPerDay,
    required this.dishesPerMeal,
    required this.mealModeName,
  });

  final DateTime dateRangeStart;
  final DateTime dateRangeEnd;
  final int defaultServingSize;
  final int mealsPerDay;
  final int dishesPerMeal;
  final String mealModeName;
}

class _CalendarDefaultsSheet extends StatefulWidget {
  const _CalendarDefaultsSheet({
    required this.existing,
    required this.initialStart,
    required this.initialEnd,
  });

  final CalendarDaySettings? existing;
  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<_CalendarDefaultsSheet> createState() => _CalendarDefaultsSheetState();
}

class _CalendarDefaultsSheetState extends State<_CalendarDefaultsSheet> {
  late final TextEditingController _servingsController;
  late final TextEditingController _mealsController;
  late final TextEditingController _dishesController;
  late final TextEditingController _modeController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _servingsController = TextEditingController(
      text: '${existing?.defaultServingSize ?? 4}',
    );
    _mealsController = TextEditingController(
      text: '${existing?.mealsPerDay ?? 3}',
    );
    _dishesController = TextEditingController(
      text: '${existing?.dishesPerMeal ?? 1}',
    );
    _modeController = TextEditingController(
      text: existing?.mealModeName ?? 'Standard',
    );
    _startController = TextEditingController(
      text: _datePath(existing?.dateRangeStart ?? widget.initialStart),
    );
    _endController = TextEditingController(
      text: _datePath(existing?.dateRangeEnd ?? widget.initialEnd),
    );
  }

  @override
  void dispose() {
    _servingsController.dispose();
    _mealsController.dispose();
    _dishesController.dispose();
    _modeController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _save() {
    final servings = int.tryParse(_servingsController.text.trim());
    final meals = int.tryParse(_mealsController.text.trim());
    final dishes = int.tryParse(_dishesController.text.trim());
    final start = _parseDate(_startController.text.trim());
    final end = _parseDate(_endController.text.trim());
    if (servings == null || servings <= 0) {
      setState(() => _error = 'Default serving size must be positive.');
      return;
    }
    if (meals == null || meals <= 0) {
      setState(() => _error = 'Meals per day must be positive.');
      return;
    }
    if (dishes == null || dishes <= 0) {
      setState(() => _error = 'Dishes per meal must be positive.');
      return;
    }
    if (start == null || end == null || end.isBefore(start)) {
      setState(() => _error = 'Use a valid date range.');
      return;
    }
    Navigator.of(context).pop(
      _CalendarDefaultsInput(
        dateRangeStart: start,
        dateRangeEnd: end,
        defaultServingSize: servings,
        mealsPerDay: meals,
        dishesPerMeal: dishes,
        mealModeName: _modeController.text.trim(),
      ),
    );
  }

  DateTime? _parseDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return _datePath(parsed) == value
        ? DateTime(parsed.year, parsed.month, parsed.day)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final ks = context.ksColors;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KsTokens.space20,
          KsTokens.space12,
          KsTokens.space20,
          KsTokens.space20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ks.borderStrong,
                  borderRadius: BorderRadius.circular(KsTokens.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: KsTokens.space16),
            Text(
              'Calendar defaults',
              style: KsTokens.displaySmall.copyWith(
                color: ks.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: KsTokens.space12),
            _CalendarDefaultsTextField(
              controller: _startController,
              label: 'Start date',
            ),
            const SizedBox(height: KsTokens.space8),
            _CalendarDefaultsTextField(
              controller: _endController,
              label: 'End date',
            ),
            const SizedBox(height: KsTokens.space8),
            Row(
              children: [
                Expanded(
                  child: _CalendarDefaultsTextField(
                    controller: _servingsController,
                    label: 'Default serving size',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: KsTokens.space8),
                Expanded(
                  child: _CalendarDefaultsTextField(
                    controller: _mealsController,
                    label: 'Meals per day',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KsTokens.space8),
            Row(
              children: [
                Expanded(
                  child: _CalendarDefaultsTextField(
                    controller: _dishesController,
                    label: 'Dishes per meal',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: KsTokens.space8),
                Expanded(
                  child: _CalendarDefaultsTextField(
                    controller: _modeController,
                    label: 'Meal mode',
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: KsTokens.space10),
              KsErrorAlert(message: _error!),
            ],
            const SizedBox(height: KsTokens.space12),
            FilledButton(onPressed: _save, child: const Text('Save defaults')),
          ],
        ),
      ),
    );
  }
}
