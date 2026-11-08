import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Evaluation result for [ScientificCalculatorEngine].
class CalculationResult {
  final double? value;
  final String? errorMessage;
  final bool isError;

  const CalculationResult.success(this.value)
      : errorMessage = null,
        isError = false;

  const CalculationResult.error(this.errorMessage)
      : value = null,
        isError = true;

  String format() {
    if (isError) return errorMessage ?? 'Error';
    if (value == null) return '0';
    if (value!.isNaN) return 'Error: Undefined';
    if (value!.isInfinite) return value!.isNegative ? '-Infinity' : 'Infinity';

    // Format integer vs decimal cleanly
    if (value! == value!.truncateToDouble() && value!.abs() < 1e12) {
      return value!.toInt().toString();
    }
    // Scientific notation for very large or tiny numbers
    if (value!.abs() >= 1e10 || (value!.abs() < 1e-6 && value! != 0)) {
      return value!.toStringAsExponential(6);
    }
    // Clean trailing zeros
    String str = value!.toStringAsFixed(8);
    while (str.contains('.') && (str.endsWith('0') || str.endsWith('.'))) {
      str = str.substring(0, str.length - 1);
    }
    return str;
  }
}

/// Pure Dart recursive-descent math parser and evaluator for scientific operations.
class ScientificCalculatorEngine {
  static CalculationResult evaluate(String expression) {
    if (expression.trim().isEmpty) {
      return const CalculationResult.success(0.0);
    }
    try {
      final tokens = _tokenize(expression);
      if (tokens.isEmpty) return const CalculationResult.success(0.0);
      final parser = _Parser(tokens);
      final val = parser.parseExpression();
      if (!parser.isAtEnd) {
        return const CalculationResult.error('Error: Syntax');
      }
      if (val.isNaN) {
        return const CalculationResult.error('Error: Undefined real result');
      }
      if (val.isInfinite) {
        return const CalculationResult.error('Error: Non-finite / Overflow');
      }
      return CalculationResult.success(val);
    } on _CalcException catch (e) {
      return CalculationResult.error(e.message);
    } catch (_) {
      return const CalculationResult.error('Error: Invalid Expression');
    }
  }

  static List<_Token> _tokenize(String input) {
    final tokens = <_Token>[];
    int i = 0;
    final s = input.replaceAll(RegExp(r'\s+'), '');

    while (i < s.length) {
      final c = s[i];

      if (c == '+' || c == '-' || c == '*' || c == '/' || c == '^' || c == '(' || c == ')' || c == '!') {
        tokens.add(_Token(_TokenType.operator, c));
        i++;
      } else if (c == 'x' || c == 'X' || c == '×') {
        tokens.add(const _Token(_TokenType.operator, '*'));
        i++;
      } else if (c == '÷') {
        tokens.add(const _Token(_TokenType.operator, '/'));
        i++;
      } else if (_isDigit(c) || c == '.') {
        final start = i;
        while (i < s.length && (_isDigit(s[i]) || s[i] == '.')) {
          i++;
        }
        tokens.add(_Token(_TokenType.number, s.substring(start, i)));
      } else if (_isAlpha(c)) {
        final start = i;
        while (i < s.length && _isAlpha(s[i])) {
          i++;
        }
        tokens.add(_Token(_TokenType.identifier, s.substring(start, i).toLowerCase()));
      } else {
        throw _CalcException("Error: Unrecognized character '$c'");
      }
    }
    return tokens;
  }

  static bool _isDigit(String s) => s.codeUnitAt(0) >= 48 && s.codeUnitAt(0) <= 57;
  static bool _isAlpha(String s) {
    final c = s.codeUnitAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
  }
}

enum _TokenType { number, operator, identifier }

class _Token {
  final _TokenType type;
  final String text;
  const _Token(this.type, this.text);
}

class _CalcException implements Exception {
  final String message;
  _CalcException(this.message);
}

class _Parser {
  final List<_Token> tokens;
  int _pos = 0;

  _Parser(this.tokens);

  bool get isAtEnd => _pos >= tokens.length;
  _Token get current => isAtEnd ? const _Token(_TokenType.operator, '') : tokens[_pos];

  _Token advance() {
    final tok = current;
    _pos++;
    return tok;
  }

  bool match(String op) {
    if (!isAtEnd && current.text == op) {
      advance();
      return true;
    }
    return false;
  }

  double parseExpression() {
    double left = parseTerm();
    while (!isAtEnd) {
      if (match('+')) {
        left += parseTerm();
      } else if (match('-')) {
        left -= parseTerm();
      } else {
        break;
      }
    }
    return left;
  }

  double parseTerm() {
    double left = parseUnary();
    while (!isAtEnd) {
      if (match('*')) {
        left *= parseUnary();
      } else if (match('/')) {
        final right = parseUnary();
        if (right == 0.0) {
          throw _CalcException('Error: Division by zero');
        }
        left /= right;
      } else {
        break;
      }
    }
    return left;
  }

  double parseUnary() {
    if (match('-')) {
      return -parseUnary();
    }
    if (match('+')) {
      return parseUnary();
    }
    return parsePower();
  }

  double parsePower() {
    double base = parsePostfix();
    if (!isAtEnd && match('^')) {
      final exponent = parseUnary(); // right-associative power, supports signed exponent e.g. 2^-3
      final res = math.pow(base, exponent).toDouble();
      if (res.isNaN) {
        throw _CalcException('Error: Undefined real power');
      }
      return res;
    }
    return base;
  }

  double parsePostfix() {
    double val = parsePrimary();
    while (!isAtEnd && match('!')) {
      if (val < 0 || val != val.truncateToDouble()) {
        throw _CalcException('Error: Non-integer factorial');
      }
      if (val > 170) {
        throw _CalcException('Error: Factorial overflow');
      }
      int n = val.toInt();
      double result = 1.0;
      for (int i = 2; i <= n; i++) {
        result *= i;
      }
      val = result;
    }
    return val;
  }

  double parsePrimary() {
    if (isAtEnd) throw _CalcException('Error: Unexpected end');

    final tok = advance();
    if (tok.type == _TokenType.number) {
      final n = double.tryParse(tok.text);
      if (n == null) throw _CalcException('Error: Invalid number');
      return n;
    }

    if (tok.type == _TokenType.identifier) {
      final name = tok.text;
      if (name == 'pi') return math.pi;
      if (name == 'e') return math.e;

      if (!match('(')) {
        throw _CalcException('Error: Expected ( after $name');
      }
      final arg = parseExpression();
      if (!match(')')) {
        throw _CalcException('Error: Expected ) after argument');
      }

      switch (name) {
        case 'sqrt':
          if (arg < 0) throw _CalcException('Error: Negative radicand');
          return math.sqrt(arg);
        case 'log':
          if (arg <= 0) throw _CalcException('Error: Non-positive log');
          return math.log(arg) / math.ln10;
        case 'ln':
          if (arg <= 0) throw _CalcException('Error: Non-positive log');
          return math.log(arg);
        case 'exp':
          return math.exp(arg);
        case 'sin':
          return math.sin(arg);
        case 'cos':
          return math.cos(arg);
        case 'tan':
          return math.tan(arg);
        default:
          throw _CalcException('Error: Unknown function $name');
      }
    }

    if (tok.text == '(') {
      final val = parseExpression();
      if (!match(')')) {
        throw _CalcException('Error: Unmatched parenthesis');
      }
      return val;
    }

    throw _CalcException('Error: Unexpected token ${tok.text}');
  }
}

/// Accessible Scientific Calculator Widget substitute for the official CLEP TI-30XS MultiView.
class ScientificCalculatorWidget extends StatefulWidget {
  final VoidCallback? onClose;

  const ScientificCalculatorWidget({super.key, this.onClose});

  /// Presents the calculator within an accessible modal dialog.
  static Future<void> showAsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
          child: ScientificCalculatorWidget(
            onClose: () => Navigator.of(dialogCtx).pop(),
          ),
        ),
      ),
    );
  }

  @override
  State<ScientificCalculatorWidget> createState() => _ScientificCalculatorWidgetState();
}

class _ScientificCalculatorWidgetState extends State<ScientificCalculatorWidget> {
  String _expression = '';
  String _result = '0';
  bool _evaluated = false;

  void _onKeyPress(String text) {
    setState(() {
      if (_evaluated) {
        if ('+-×÷*/^'.contains(text)) {
          _expression = _result + text;
        } else {
          _expression = text;
        }
        _evaluated = false;
      } else {
        _expression += text;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_expression.isNotEmpty) {
        _expression = _expression.substring(0, _expression.length - 1);
      }
      _evaluated = false;
    });
  }

  void _onClearAll() {
    setState(() {
      _expression = '';
      _result = '0';
      _evaluated = false;
    });
  }

  void _onEvaluate() {
    setState(() {
      final res = ScientificCalculatorEngine.evaluate(_expression);
      _result = res.format();
      _evaluated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with TI-30XS Disclaimer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scientific Calculator',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Practice substitute for CLEP College Algebra',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close Calculator',
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // Mandatory Disclaimer Banner
          Container(
            color: colorScheme.errorContainer.withOpacity(0.35),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '⚠️ Practice substitute only. Not official TI-30XS software. College Board & TI are not affiliated.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Display Screen
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: colorScheme.surface,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      _expression.isEmpty ? ' ' : _expression,
                      key: const Key('calculator_expression_display'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Semantics(
                      liveRegion: true,
                      label: 'Calculation Result: $_result',
                      child: Text(
                        _result,
                        key: const Key('calculator_result_display'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _result.startsWith('Error') ? colorScheme.error : colorScheme.onSurface,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Keypad Matrix
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  _buildButtonRow([
                    _calcBtn('C', onPressed: _onClearAll, isSpecial: true, tooltip: 'Clear All'),
                    _calcBtn('⌫', onPressed: _onBackspace, isSpecial: true, tooltip: 'Backspace'),
                    _calcBtn('(', tooltip: 'Open Parenthesis'),
                    _calcBtn(')', tooltip: 'Close Parenthesis'),
                    _calcBtn('÷', tooltip: 'Division', isOp: true),
                  ]),
                  _buildButtonRow([
                    _calcBtn('√', label: 'sqrt(', tooltip: 'Square Root', isSpecial: true),
                    _calcBtn('x²', label: '^2', tooltip: 'Square', isSpecial: true),
                    _calcBtn('xʸ', label: '^', tooltip: 'Power', isSpecial: true),
                    _calcBtn('n!', label: '!', tooltip: 'Factorial', isSpecial: true),
                    _calcBtn('×', tooltip: 'Multiplication', isOp: true),
                  ]),
                  _buildButtonRow([
                    _calcBtn('log', label: 'log(', tooltip: 'Base 10 Logarithm', isSpecial: true),
                    _calcBtn('7'),
                    _calcBtn('8'),
                    _calcBtn('9'),
                    _calcBtn('-', tooltip: 'Subtraction', isOp: true),
                  ]),
                  _buildButtonRow([
                    _calcBtn('ln', label: 'ln(', tooltip: 'Natural Logarithm', isSpecial: true),
                    _calcBtn('4'),
                    _calcBtn('5'),
                    _calcBtn('6'),
                    _calcBtn('+', tooltip: 'Addition', isOp: true),
                  ]),
                  _buildButtonRow([
                    _calcBtn('π', label: 'pi', tooltip: 'Pi Constant', isSpecial: true),
                    _calcBtn('1'),
                    _calcBtn('2'),
                    _calcBtn('3'),
                    _calcBtn('=', onPressed: _onEvaluate, isEquals: true, tooltip: 'Calculate'),
                  ]),
                  _buildButtonRow([
                    _calcBtn('e', label: 'e', tooltip: 'Euler Constant', isSpecial: true),
                    _calcBtn('0'),
                    _calcBtn('.'),
                    _calcBtn('(-)', label: '-', tooltip: 'Negation'),
                    const SizedBox.shrink(), // Placeholder to align with 2-row tall equal or standard layout
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonRow(List<Widget> buttons) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons.map((btn) => Expanded(child: Padding(padding: const EdgeInsets.all(2.0), child: btn))).toList(),
      ),
    );
  }

  Widget _calcBtn(
    String display, {
    String? label,
    VoidCallback? onPressed,
    String? tooltip,
    bool isOp = false,
    bool isSpecial = false,
    bool isEquals = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final insertText = label ?? display;

    Color bgColor = colorScheme.surface;
    Color fgColor = colorScheme.onSurface;

    if (isEquals) {
      bgColor = colorScheme.primary;
      fgColor = colorScheme.onPrimary;
    } else if (isOp) {
      bgColor = colorScheme.primaryContainer;
      fgColor = colorScheme.onPrimaryContainer;
    } else if (isSpecial) {
      bgColor = colorScheme.secondaryContainer.withOpacity(0.6);
      fgColor = colorScheme.onSecondaryContainer;
    }

    return Semantics(
      button: true,
      label: tooltip ?? display,
      child: Tooltip(
        message: tooltip ?? display,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onPressed ?? () => _onKeyPress(insertText),
          child: Text(
            display,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isEquals || isOp ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
