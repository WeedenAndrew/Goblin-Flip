part of '../goblin_flip_app.dart';

@immutable
class _WagerRequest {
  const _WagerRequest({required this.amount, required this.guess});

  final int amount;
  final WagerSide guess;
}

class _WagerSheet extends StatefulWidget {
  const _WagerSheet({required this.balance, this.initialAmount});

  final int balance;
  final int? initialAmount;

  @override
  State<_WagerSheet> createState() => _WagerSheetState();
}

class _WagerSheetState extends State<_WagerSheet> {
  late final TextEditingController _amountController;
  WagerSide _guess = WagerSide.heads;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: (widget.initialAmount ?? math.min(10, widget.balance))
          .clamp(1, widget.balance)
          .toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setAmount(int amount) {
    _amountController.text = amount.clamp(1, widget.balance).toString();
    setState(() {
      _validationMessage = null;
    });
  }

  void _submit() {
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0 || amount > widget.balance) {
      setState(() {
        _validationMessage = 'Enter between 1 and ${widget.balance} flips.';
      });
      return;
    }

    Navigator.of(context).pop(_WagerRequest(amount: amount, guess: _guess));
  }

  @override
  Widget build(BuildContext context) {
    const skin = _GameVisualSkins.wagerScroll;
    final quarterBalance = math.max(1, widget.balance * 25 ~/ 100).toInt();
    final halfBalance = math.max(1, widget.balance * 50 ~/ 100).toInt();
    final threeQuarterBalance = math.max(1, widget.balance * 75 ~/ 100).toInt();
    final selectedAmount = int.tryParse(_amountController.text);

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _OpenScrollPanel(
              key: const Key('wager-scroll'),
              style: _OpenScrollStyle.wager,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'The Goblin\'s Wager',
                            style: _GameFonts.cinzelDecorative(
                              color: skin.primaryTextColor,
                              fontSize: skin.titleFontSize,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('close-wager'),
                          onPressed: () => Navigator.of(context).pop(),
                          color: const Color(0xFF4A2E19),
                          tooltip: 'Close wager',
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Text(
                      'Balance: ${widget.balance} flips',
                      style: _GameFonts.cinzel(
                        color: skin.secondaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose your side',
                      style: _GameFonts.cinzel(
                        color: skin.primaryTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _WagerSideButton(
                            key: const Key('wager-heads'),
                            label: 'Heads',
                            selected: _guess == WagerSide.heads,
                            onPressed: () {
                              setState(() {
                                _guess = WagerSide.heads;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _WagerSideButton(
                            key: const Key('wager-tails'),
                            label: 'Tails',
                            selected: _guess == WagerSide.tails,
                            onPressed: () {
                              setState(() {
                                _guess = WagerSide.tails;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('wager-amount'),
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: _GameFonts.cinzel(
                        color: const Color(0xFF2D1D10),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Flips to wager',
                        errorText: _validationMessage,
                        labelStyle: _GameFonts.cinzel(
                          color: const Color(0xFF3F2918),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                        filled: true,
                        fillColor: const Color(0x99FFF2C7),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF78522E),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF3C5A2A),
                            width: 2,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Win: 2×  •  Loss: +0%',
                      textAlign: TextAlign.center,
                      style: _GameFonts.cinzel(
                        color: skin.secondaryTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickBetButton(
                            key: const Key('wager-25-percent'),
                            label: '25%',
                            selected: selectedAmount == quarterBalance,
                            onPressed: () => _setAmount(quarterBalance),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _QuickBetButton(
                            key: const Key('wager-50-percent'),
                            label: '50%',
                            selected: selectedAmount == halfBalance,
                            onPressed: () => _setAmount(halfBalance),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _QuickBetButton(
                            key: const Key('wager-75-percent'),
                            label: '75%',
                            selected: selectedAmount == threeQuarterBalance,
                            onPressed: () => _setAmount(threeQuarterBalance),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _QuickBetButton(
                            key: const Key('wager-all-in'),
                            label: 'All in',
                            selected: selectedAmount == widget.balance,
                            onPressed: () => _setAmount(widget.balance),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('confirm-wager'),
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3D582A),
                          foregroundColor: const Color(0xFFF3E5B9),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: _GameFonts.cinzel(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        child: const Text('Wager'),
                      ),
                    ),
                  ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickBetButton extends StatelessWidget {
  const _QuickBetButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // '25%' alone tells a screen reader nothing about what it wagers. The label
    // and the selected flag go on the node the button merges, so the name and
    // the selection are announced together.
    final semanticLabel = label == 'All in'
        ? 'Wager the entire balance'
        : 'Wager $label of the balance';
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xFF3D582A)
            : const Color(0x997A6038),
        foregroundColor: selected
            ? const Color(0xFFF3E5B9)
            : const Color(0xFF342012),
        side: BorderSide(
          color: selected ? const Color(0xFF263B1A) : const Color(0xFF78522E),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        visualDensity: VisualDensity.compact,
        textStyle: _GameFonts.cinzel(
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Semantics(
        label: semanticLabel,
        selected: selected,
        excludeSemantics: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
      ),
    );
  }
}

class _WagerSideButton extends StatelessWidget {
  const _WagerSideButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xFF3D582A)
            : const Color(0x997A6038),
        foregroundColor: selected
            ? const Color(0xFFF3E5B9)
            : const Color(0xFF342012),
        side: BorderSide(
          color: selected ? const Color(0xFF263B1A) : const Color(0xFF78522E),
          width: selected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        textStyle: _GameFonts.cinzel(
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Semantics(
        label: 'Wager on $label',
        selected: selected,
        excludeSemantics: true,
        child: Text(label),
      ),
    );
  }
}
