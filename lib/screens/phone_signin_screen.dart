import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/backend/bukii_backend.dart';
import '../data/models/user_profile.dart';
import '../theme/app_theme.dart';
import 'verify_phone_signin_screen.dart';

class PhoneSigninScreen extends StatefulWidget {
  const PhoneSigninScreen({super.key, required this.audience});

  final String audience;

  /// Creates the state that owns and validates the phone number.
  @override
  State<PhoneSigninScreen> createState() => _PhoneSigninScreenState();
}

class _PhoneSigninScreenState extends State<PhoneSigninScreen> {
  final _phoneController = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    // Release the phone field controller when the screen closes.
    _phoneController.dispose();
    super.dispose();
  }

  /// Validates the number, sends the SMS code, then opens the code screen.
  Future<void> _continueToVerification() async {
    var nationalNumber = _phoneController.text.replaceAll(' ', '');
    if (nationalNumber.startsWith('0')) {
      nationalNumber = nationalNumber.substring(1);
    }
    if (nationalNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a 10-digit phone number.')),
      );
      return;
    }

    final phoneNumber = '+234 ${_phoneController.text}';
    setState(() => _sending = true);
    try {
      await BukiiBackend.instance.sendOtp(
        phone: '+234$nationalNumber',
        role: UserRole.fromAudience(widget.audience),
      );
    } on BackendException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerifyPhoneSigninScreen(
          phoneNumber: phoneNumber,
          audience: widget.audience,
        ),
      ),
    );
  }

  /// Builds the phone sign-in form styled after the supplied reference.
  @override
  Widget build(BuildContext context) {
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
                    // SizedBox(height: constraints.maxHeight * 0.12),
                    const Text(
                      'GOOD SERVICE, RIGHT AROUND YOU',
                      style: TextStyle(
                        color: AppColors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Your time,\nwell spent.',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 31,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                        letterSpacing: -1.4,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Book the people you trust. No calls, no waiting around.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),

                    const Spacer(),

                    const Text(
                      'Phone number',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      height: 66,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F5F1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '+234',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(width: 16),
                          Container(width: 1, height: 30, color: Colors.black),

                          const SizedBox(width: 14),

                          Expanded(
                            child: TextField(
                              key: const ValueKey('phone-number-field'),
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              inputFormatters: const [
                                _NigerianPhoneNumberFormatter(),
                              ],
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              decoration: const InputDecoration(
                                hintText: '80 2345 6789',
                                hintStyle: TextStyle(color: Color(0xFF898680)),
                                border: InputBorder.none,
                                counterText: '',
                              ),
                              onSubmitted: (_) => _continueToVerification(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'We’ll send you a one-time verification code.',
                      style: TextStyle(color: Color(0xFF99948E), fontSize: 14),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('phone-continue'),
                        onPressed: _sending ? null : _continueToVerification,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),

                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        child: Text(_sending ? 'Sending code...' : 'Continue'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF99948E),
                          fontSize: 13,
                        ),
                        children: [
                          const TextSpan(
                            text: 'By continuing, you agree to our ',
                          ),

                          TextSpan(
                            text: 'Terms',
                            style: const TextStyle(color: AppColors.orange),
                          ),

                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(color: AppColors.orange),
                          ),

                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
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

/// Keeps phone input numeric, limits it to 10 digits, and formats it 3-3-4.
class _NigerianPhoneNumberFormatter extends TextInputFormatter {
  const _NigerianPhoneNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    final digitsBeforeCursor = newValue.selection.isValid
        ? newValue.text
              .substring(
                0,
                newValue.selection.extentOffset.clamp(0, newValue.text.length),
              )
              .replaceAll(RegExp(r'\D'), '')
              .length
              .clamp(0, digits.length)
        : digits.length;
    final formatted = _formatDigits(digits);
    final cursorOffset = _cursorOffsetForDigitCount(
      formatted,
      digitsBeforeCursor,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  /// Inserts spaces after the third and sixth digits when those groups exist.
  String _formatDigits(String digits) {
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 3)} ${digits.substring(3)}';
    }
    return '${digits.substring(0, 3)} '
        '${digits.substring(3, 6)} '
        '${digits.substring(6)}';
  }

  /// Maps a digit-based cursor position to the formatted text offset.
  int _cursorOffsetForDigitCount(String formatted, int digitCount) {
    if (digitCount == 0) return 0;

    var foundDigits = 0;
    for (var index = 0; index < formatted.length; index++) {
      if (RegExp(r'\d').hasMatch(formatted[index])) {
        foundDigits++;
        if (foundDigits == digitCount) return index + 1;
      }
    }
    return formatted.length;
  }
}
