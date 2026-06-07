// ════════════════════════════════════════════════════════════════════
//  onboarding.dart  –  TrackBus  |  Rapido-style onboarding flow
//
//  SCREENS:
//    1. PhoneEntryScreen   → user types phone number (+91 prefix)
//    2. OtpScreen          → 6-box animated OTP input
//    3. ProfileSetupScreen → name (required), gender chips, email (optional)
//    4. LocationScreen     → animated location-permission ask
//
//  HOW TO PLUG IN:
//    • Add this file to lib/ (same folder as main.dart).
//    • In main.dart, inside SplashScreen._SplashScreenState.initState(),
//      replace the lines that navigate to RegisterScreen / LoginScreen with:
//
//          final next = AuthService.isLoggedIn
//              ? const MainShell()
//              : const PhoneEntryScreen();
//          Navigator.pushReplacement(
//              context, MaterialPageRoute(builder: (_) => next));
//
//    • Also in main.dart → AuthUser: add the `gender` field (optional String?)
//      and update toJson / fromJson accordingly (see bottom of this file).
//
//  PACKAGES NEEDED  (already in your pubspec if you use shared_prefs + supabase):
//    shared_preferences, supabase_flutter
//
//  OPTIONAL (location permission UI — add to pubspec if not already there):
//    permission_handler: ^11.3.0
//    geolocator: ^12.0.0
//  (If you don't add them, the LocationScreen shows the UI but skips the
//   actual permission call — harmless.)
// ════════════════════════════════════════════════════════════════════
import 'main.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Import these from your main.dart via the same library ──
// AuthService, AuthUser, MainShell, supabase  (all in main.dart)
// Because this file lives in the same lib/ folder, no extra import needed
// when both files are part of the same Flutter app.

// ═══════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════
const _navy = Color(0xFF0D1F35);
const _blue = Color(0xFF1A3A5C);
const _accent = Color(0xFFF4A024);
const _accentDark = Color(0xFFD98A18);
const _bg = Color(0xFFF5F7FA);
const _surface = Colors.white;
const _textMain = Color(0xFF0D1F35);
const _textSub = Color(0xFF6B7280);

// ═══════════════════════════════════════════════════════════
//  1. PHONE ENTRY SCREEN
// ═══════════════════════════════════════════════════════════
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});
  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen>
    with TickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  late AnimationController _busCtrl;
  late Animation<double> _busSlide;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _busCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _busSlide = Tween<double>(begin: -120, end: 0)
        .animate(CurvedAnimation(parent: _busCtrl, curve: Curves.easeOutBack));
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _busCtrl.forward().then((_) => _fadeCtrl.forward());
  }

  @override
  void dispose() {
    _busCtrl.dispose();
    _fadeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _phoneCtrl.text.trim().length == 10;

  Future<void> _sendOtp() async {
    if (!_valid) return;
    setState(() => _loading = true);

    // ── In production: call your SMS OTP API here ──
    // For demo we generate a random 6-digit code stored in SharedPreferences
    final otp = (100000 + Random().nextInt(900000)).toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trackbus_demo_otp', otp);
    await prefs.setString('trackbus_pending_phone', _phoneCtrl.text.trim());

    if (!mounted) return;
    setState(() => _loading = false);

    // Show demo OTP in snackbar (remove in production)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Demo OTP: $otp  (sent to +91 ${_phoneCtrl.text.trim()})'),
      backgroundColor: _blue,
      duration: const Duration(seconds: 5),
    ));

    Navigator.push(
        context, _slideRoute(OtpScreen(phone: _phoneCtrl.text.trim())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top hero ──
            Container(
              width: double.infinity,
              height: 280,
              decoration: const BoxDecoration(
                color: _navy,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: Stack(
                children: [
                  // animated dots / city silhouette
                  ..._buildDots(),
                  // animated bus
                  AnimatedBuilder(
                    animation: _busSlide,
                    builder: (_, __) => Positioned(
                      bottom: 48,
                      left: _busSlide.value + 28,
                      child: _BusIllustration(),
                    ),
                  ),
                  // road strip
                  Positioned(
                    bottom: 36,
                    left: 0,
                    right: 0,
                    child: Container(height: 4, color: _accent.withOpacity(.5)),
                  ),
                  // logo
                  Positioned(
                    top: 24,
                    left: 24,
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.directions_bus,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Text('TrackBus',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ]),
                  ),
                ],
              ),
            ),

            // ── Form area ──
            Expanded(
              child: FadeTransition(
                opacity: _fade,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Enter your\nphone number',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _textMain,
                              height: 1.2)),
                      const SizedBox(height: 8),
                      const Text(
                          "We'll send a one-time password to verify it's you.",
                          style: TextStyle(color: _textSub, fontSize: 14)),
                      const SizedBox(height: 32),
                      // Phone field
                      Container(
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          children: [
                            // Country code prefix
                            Container(
                              width: 70,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(children: [
                                Text('🇮🇳',
                                    style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 4),
                                const Text('+91',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: _textMain)),
                              ]),
                            ),
                            Container(
                                width: 1,
                                height: 32,
                                color: const Color(0xFFE5E7EB)),
                            Expanded(
                              child: TextField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                onChanged: (_) => setState(() {}),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2),
                                decoration: const InputDecoration(
                                  hintText: '98765 43210',
                                  hintStyle: TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.w400),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 18),
                                  counterText: '',
                                ),
                              ),
                            ),
                            if (_valid)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.check,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                          'By continuing you agree to our Terms & Privacy Policy.',
                          style: TextStyle(fontSize: 11, color: _textSub)),
                      const SizedBox(height: 32),
                      // CTA button
                      _BigButton(
                        label: 'Send OTP',
                        enabled: _valid && !_loading,
                        loading: _loading,
                        onTap: _sendOtp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDots() {
    final positions = [
      [40.0, 120.0],
      [180.0, 80.0],
      [300.0, 100.0],
      [120.0, 160.0],
      [260.0, 140.0],
    ];
    return positions
        .map((p) => Positioned(
              left: p[0],
              top: p[1],
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle),
              ),
            ))
        .toList();
  }
}

// ═══════════════════════════════════════════════════════════
//  2. OTP SCREEN
// ═══════════════════════════════════════════════════════════
class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = 30;
  Timer? _timer;
  bool _loading = false;
  bool _shaking = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _nodes[0].requestFocus());
  }

  void _startTimer() {
    _secondsLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();
  bool get _filled => _otp.length == 6;

  void _onBoxChanged(int idx, String val) {
    if (val.length == 1 && idx < 5) {
      _nodes[idx + 1].requestFocus();
    } else if (val.isEmpty && idx > 0) {
      _nodes[idx - 1].requestFocus();
    }
    // Handle paste: if first box receives 6 chars
    if (val.length == 6) {
      for (int i = 0; i < 6; i++) {
        _ctrls[i].text = val[i];
      }
      _nodes[5].requestFocus();
    }
    setState(() {});
  }

  Future<void> _verify() async {
    if (!_filled) return;
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('trackbus_demo_otp') ?? '';

    if (_otp != stored) {
      // Wrong OTP – shake
      setState(() => _loading = false);
      _shakeCtrl.forward(from: 0);
      for (final c in _ctrls) c.clear();
      _nodes[0].requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Incorrect OTP. Please try again.'),
          backgroundColor: Colors.red));
      return;
    }

    await prefs.remove('trackbus_demo_otp');
    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.pushReplacement(
        context, _slideRoute(ProfileSetupScreen(phone: widget.phone)));
  }

  Future<void> _resend() async {
    final newOtp = (100000 + Random().nextInt(900000)).toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trackbus_demo_otp', newOtp);
    _startTimer();
    for (final c in _ctrls) c.clear();
    _nodes[0].requestFocus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('New Demo OTP: $newOtp'),
      backgroundColor: _blue,
      duration: const Duration(seconds: 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _textMain,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text('Verify OTP',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _textMain)),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: _textSub, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Code sent to '),
                    TextSpan(
                        text: '+91 ${widget.phone}',
                        style: const TextStyle(
                            color: _textMain, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // OTP boxes with shake animation
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                      sin(_shakeAnim.value * pi * 6) *
                          8 *
                          (1 - _shakeAnim.value),
                      0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, _buildBox),
                ),
              ),
              const SizedBox(height: 32),

              // Resend
              Center(
                child: _secondsLeft > 0
                    ? RichText(
                        text: TextSpan(
                          style: const TextStyle(color: _textSub, fontSize: 14),
                          children: [
                            const TextSpan(text: 'Resend OTP in '),
                            TextSpan(
                                text: '${_secondsLeft}s',
                                style: const TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: _resend,
                        child: const Text('Resend OTP',
                            style: TextStyle(
                                color: _accent,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline)),
                      ),
              ),

              const Spacer(),

              _BigButton(
                label: 'Verify & Continue',
                enabled: _filled && !_loading,
                loading: _loading,
                onTap: _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBox(int i) {
    final isFocused = _nodes[i].hasFocus;
    final isFilled = _ctrls[i].text.isNotEmpty;
    return SizedBox(
      width: 48,
      height: 58,
      child: TextField(
        controller: _ctrls[i],
        focusNode: _nodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: _textMain),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: isFilled ? _accent.withOpacity(0.12) : _surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: isFocused ? _accent : const Color(0xFFE5E7EB),
                  width: isFocused ? 2 : 1)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: isFilled ? _accent : const Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _accent, width: 2)),
        ),
        onChanged: (v) => _onBoxChanged(i, v),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  3. PROFILE SETUP SCREEN
// ═══════════════════════════════════════════════════════════
class ProfileSetupScreen extends StatefulWidget {
  final String phone;
  const ProfileSetupScreen({super.key, required this.phone});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _gender; // 'Male' | 'Female' | 'Other'
  bool _saving = false;

  late AnimationController _avatarCtrl;
  late Animation<double> _avatarScale;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _genderEmoji = ['👨', '👩', '🧑'];

  @override
  void initState() {
    super.initState();
    _avatarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _avatarScale =
        CurvedAnimation(parent: _avatarCtrl, curve: Curves.elasticOut);
    _avatarCtrl.forward();
  }

  @override
  void dispose() {
    _avatarCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed => _nameCtrl.text.trim().length >= 2;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    // Persist profile to shared prefs (and optionally Supabase)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trackbus_user_name', name);
    await prefs.setString('trackbus_user_phone', widget.phone);
    if (_emailCtrl.text.trim().isNotEmpty) {
      await prefs.setString('trackbus_user_email', _emailCtrl.text.trim());
    }
    if (_gender != null) {
      await prefs.setString('trackbus_user_gender', _gender!);
    }
    await prefs.setBool('trackbus_onboarding_done', false); // location not yet
    await prefs.setBool('trackbus_profile_done', true);

    if (!mounted) return;
    setState(() => _saving = false);

    Navigator.pushReplacement(
        context, _slideRoute(const LocationPermissionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Compact top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                BackButton(
                  onPressed: () => Navigator.pop(context),
                  color: _textMain,
                ),
                const Expanded(
                  child: Text('Your Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textMain)),
                ),
                const SizedBox(width: 40),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: ScaleTransition(
                        scale: _avatarScale,
                        child: Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                    colors: [_blue, _navy],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                                boxShadow: [
                                  BoxShadow(
                                      color: _blue.withOpacity(0.3),
                                      blurRadius: 18,
                                      spreadRadius: 2)
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _gender == 'Female'
                                      ? '👩'
                                      : _gender == 'Other'
                                          ? '🧑'
                                          : '👨',
                                  style: const TextStyle(fontSize: 42),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text('+91 ${widget.phone}',
                          style: const TextStyle(
                              color: _textSub,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 32),

                    // Name
                    _Label('Full Name *'),
                    const SizedBox(height: 8),
                    _OBField(
                      controller: _nameCtrl,
                      hint: 'Your full name',
                      icon: Icons.person_outline,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 22),

                    // Gender chips
                    _Label('Gender'),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(_genders.length, (i) {
                        final g = _genders[i];
                        final selected = _gender == g;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _gender = g),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _accent.withOpacity(0.12)
                                    : _surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? _accent
                                      : const Color(0xFFE5E7EB),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Column(children: [
                                Text(_genderEmoji[i],
                                    style: const TextStyle(fontSize: 22)),
                                const SizedBox(height: 4),
                                Text(g,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            selected ? _accentDark : _textSub)),
                              ]),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),

                    // Email (optional)
                    Row(children: [
                      _Label('Email ID'),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('Optional',
                            style: TextStyle(
                                fontSize: 10,
                                color: _textSub,
                                fontWeight: FontWeight.w500)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _OBField(
                      controller: _emailCtrl,
                      hint: 'you@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 40),

                    _BigButton(
                      label: "Let's Go  →",
                      enabled: _canProceed && !_saving,
                      loading: _saving,
                      onTap: _save,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text('You can update these anytime from Profile',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  4. LOCATION PERMISSION SCREEN
// ═══════════════════════════════════════════════════════════
class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});
  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late AnimationController _pingCtrl;
  late Animation<double> _pingAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
        lowerBound: 0.95,
        upperBound: 1.05)
      ..repeat(reverse: true);
    _pulse = _pulseCtrl;

    _pingCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _pingAnim = CurvedAnimation(parent: _pingCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pingCtrl.dispose();
    super.dispose();
  }

  Future<void> _allowLocation() async {
    // ── If you have geolocator / permission_handler, call it here ──
    // Example (uncomment if package is added):
    //   final status = await Permission.location.request();
    //   if (status.isDenied) { ... }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trackbus_onboarding_done', true);

    if (!mounted) return;
    _goHome();
  }

  void _skipLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trackbus_onboarding_done', true);
    if (!mounted) return;
    _goHome();
  }

  void _goHome() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // ── Location illustration ──
            SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ping rings
                  AnimatedBuilder(
                    animation: _pingAnim,
                    builder: (_, __) => Opacity(
                      opacity: (1 - _pingAnim.value).clamp(0, 1),
                      child: Transform.scale(
                        scale: 1 + _pingAnim.value * 1.6,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _accent.withOpacity(0.6), width: 2)),
                        ),
                      ),
                    ),
                  ),
                  // Inner glow
                  ScaleTransition(
                    scale: _pulse,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withOpacity(0.18),
                      ),
                    ),
                  ),
                  // Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent,
                        boxShadow: [
                          BoxShadow(
                              color: _accent.withOpacity(0.5),
                              blurRadius: 24,
                              spreadRadius: 4)
                        ]),
                    child: const Icon(Icons.my_location,
                        color: Colors.white, size: 34),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Enable Location\nfor Better Experience',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.25),
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'TrackBus uses your location to show nearby buses, estimate arrival times, and make your commute smoother.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: 10),
            // Feature chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(icon: Icons.directions_bus, label: 'Nearest Buses'),
                  _Chip(icon: Icons.access_time, label: 'Live ETAs'),
                  _Chip(icon: Icons.route, label: 'Nearby Stops'),
                ],
              ),
            ),
            const Spacer(),
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  _BigButton(
                    label: 'Turn On Location',
                    enabled: true,
                    loading: false,
                    onTap: _allowLocation,
                    color: _accent,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _skipLocation,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Skip for now',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════

class _BigButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;

  const _BigButton({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onTap,
    this.color = _accent,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6))
                  ]
                : [],
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: textColor))
                : Text(label,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3)),
          ),
        ),
      ),
    );
  }
}

class _OBField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _OBField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: _textMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFFD1D5DB), fontWeight: FontWeight.w400),
          prefixIcon: Icon(icon, color: _blue, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textMain,
            letterSpacing: 0.2));
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _accent, size: 15),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _BusIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Bus body
        Container(
          width: 120,
          height: 60,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: _accent.withOpacity(0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Stack(
            children: [
              // Windows
              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: List.generate(
                    3,
                    (i) => Container(
                      width: 22,
                      height: 18,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              // Headlight
              Positioned(
                right: 8,
                top: 18,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
        // Wheels
        Positioned(
          bottom: -4,
          left: 14,
          child: _Wheel(),
        ),
        Positioned(
          bottom: -4,
          right: 14,
          child: _Wheel(),
        ),
      ],
    );
  }
}

class _Wheel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
          color: _navy,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 3)),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ROUTE HELPER
// ═══════════════════════════════════════════════════════════
PageRouteBuilder _slideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, animation, __) => page,
    transitionsBuilder: (_, animation, __, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
  );
}

// ════════════════════════════════════════════════════════════════════════
//  INTEGRATION NOTE FOR main.dart
//  ──────────────────────────────
//  1. In SplashScreen initState, change:
//       final next = AuthService.isLoggedIn ? const MainShell() : const RegisterScreen();
//     to:
//       final next = AuthService.isLoggedIn ? const MainShell() : const PhoneEntryScreen();
//
//  2. After LocationPermissionScreen calls _goHome(), replace the
//     pushNamedAndRemoveUntil line with:
//       Navigator.pushReplacement(
//           context, MaterialPageRoute(builder: (_) => const MainShell()));
//     (uncomment the block already written in _goHome())
//
//  3. In AuthUser, optionally add:
//       final String? gender;
//     and update toJson/fromJson to persist it.
//
//  4. Add to pubspec.yaml if not present (for real location permission):
//       permission_handler: ^11.3.0
//       geolocator: ^12.0.0
// ════════════════════════════════════════════════════════════════════════
