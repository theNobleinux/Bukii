import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'explore_screen.dart';

class VerifyPhoneSigninScreen extends StatefulWidget {
  const VerifyPhoneSigninScreen({
    super.key,
    required this.phoneNumber,
    required this.audience,
  });

  final String phoneNumber;
  final String audience;

  /// Creates the state used to collect and verify the six code digits.
  @override
  State<VerifyPhoneSigninScreen> createState() =>
      _VerifyPhoneSigninScreenState();
}

class _VerifyPhoneSigninScreenState extends State<VerifyPhoneSigninScreen> {
  static const _codeLength = 6;

  late final List<TextEditingController> _codeControllers;
  late final List<FocusNode> _codeFocusNodes;

  @override
  void initState() {
    super.initState();
    // Create one input and focus target for each digit of the verification code.
    _codeControllers = List.generate(
      _codeLength,
      (_) => TextEditingController(),
    );
    _codeFocusNodes = List.generate(_codeLength, (_) => FocusNode());
  }

  @override
  void dispose() {
    // Dispose each digit field controller and focus node with the screen.
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final focusNode in _codeFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  /// Moves focus to the next digit box after a digit is entered.
  void _handleDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _codeLength - 1) {
      _codeFocusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  /// Opens Explore once six digits are present.
  ///
  /// This prototype checks that the code is complete only; connect an SMS
  /// verification provider here before treating the phone number as verified.
  void _verifyCode() {
    final code = _codeControllers.map((controller) => controller.text).join();
    if (code.length != _codeLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the complete 6-digit code.')),
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => ExploreScreen(phoneNumber: widget.phoneNumber),
      ),
      (route) => false,
    );
  }

  /// Replaces the current code with an empty set of digit fields.
  void _resendCode() {
    for (final controller in _codeControllers) {
      controller.clear();
    }
    _codeFocusNodes.first.requestFocus();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A new verification code has been sent.')),
    );
  }

  /// Returns to phone sign-in so the user can correct their number.
  void _changeNumber() {
    Navigator.of(context).pop();
  }

  /// Builds the six-digit verification screen from the supplied reference.
  @override
  Widget build(BuildContext context) {
    final codeComplete = _codeControllers.every(
      (controller) => controller.text.isNotEmpty,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 46,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter the code',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 31,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        letterSpacing: -1.2,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'We sent a 6-digit code to ${widget.phoneNumber}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 30),

                    Row(
                      children: List.generate(_codeLength, (index) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == _codeLength - 1 ? 0 : 5,
                            ),
                            child: SizedBox(
                              height: 48,
                              child: TextField(
                                key: ValueKey('verification-digit-$index'),
                                controller: _codeControllers[index],
                                focusNode: _codeFocusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                textAlignVertical: TextAlignVertical.center,
                                maxLength: 1,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1),
                                ],
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: EdgeInsets.zero,
                                  filled: true,
                                  fillColor: const Color(0xFFF7F5F1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.orange,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onChanged: (value) =>
                                    _handleDigitChanged(index, value),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 36),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          key: const ValueKey('resend-code'),
                          onPressed: _resendCode,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('Resend code'),
                        ),
                        TextButton(
                          key: const ValueKey('change-phone-number'),
                          onPressed: _changeNumber,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.orange,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('Change number'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('verify-continue'),
                        onPressed: codeComplete ? _verifyCode : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          disabledBackgroundColor: AppColors.orange.withValues(
                            alpha: 0.45,
                          ),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
