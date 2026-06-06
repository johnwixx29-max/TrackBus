import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'bus_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  await UserSession.load();
  runApp(const TrackBusApp());
}

class TrackBusApp extends StatelessWidget {
  const TrackBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackBus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A3A5C)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ─── SESSION ─────────────────────────────────────────────────────────────────

class UserSession {
  static const _historyKey = 'trackbus_travel_history_v1';
  static List<Map<String, dynamic>> travelHistory = [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      travelHistory = list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final cv = m['colorValue'];
        if (cv is int) m['color'] = Color(cv);
        return m;
      }).toList();
    } catch (_) {
      travelHistory = [];
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(travelHistory));
  }

  static void addTrip(Map<String, dynamic> bus, String destination, {String? from}) {
    final exists = travelHistory
        .any((t) => t['busNo'] == bus['busNo'] && t['to'] == destination);
    if (!exists) {
      final color = bus['color'] as Color;
      travelHistory.insert(0, {
        ...bus,
        'colorValue': color.toARGB32(),
        'to': destination,
        if (from != null) 'from': from,
        'lastTravelled': 'Today',
      });
      travelHistory[0].remove('color');
      travelHistory[0].remove('stops');
      if (travelHistory.length > 20) {
        travelHistory = travelHistory.sublist(0, 20);
      }
      _save();
    }
  }
}

// ─── AUTH (Local Storage) ───────────────────────────────────────────────

class AuthUser {
  final String name;
  final String mobile;
  final String email;
  final String password;
  final String? photoPath;

  const AuthUser({
    required this.name,
    required this.mobile,
    required this.email,
    required this.password,
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'mobile': mobile,
        'email': email,
        'password': password,
        'photoPath': photoPath,
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        name: json['name'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        email: json['email'] as String? ?? '',
        password: json['password'] as String? ?? '',
        photoPath: json['photoPath'] as String?,
      );
}

class AuthService {
  static const _usersKey = 'trackbus_users_v1';
  static const _sessionKey = 'trackbus_session_email_v1';

  static List<AuthUser> _users = [];
  static AuthUser? currentUser;

  static bool get isLoggedIn => currentUser != null;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final rawUsers = prefs.getString(_usersKey);
    if (rawUsers != null && rawUsers.isNotEmpty) {
      final decoded = jsonDecode(rawUsers) as List<dynamic>;
      _users = decoded
          .map((e) => AuthUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    final sessionEmail = prefs.getString(_sessionKey);
    if (sessionEmail != null) {
      for (final u in _users) {
        if (u.email.toLowerCase() == sessionEmail.toLowerCase()) {
          currentUser = u;
          break;
        }
      }
    }
  }

  static Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _usersKey,
      jsonEncode(_users.map((u) => u.toJson()).toList()),
    );
  }

  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w.\-]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(email.trim());
  }

  static bool _isValidMobile(String mobile) {
    return RegExp(r'^\d{10}$').hasMatch(mobile.trim());
  }

  static Future<String?> register(AuthUser user) async {
    if (_users.any((u) => u.email.toLowerCase() == user.email.toLowerCase())) {
      return 'An account with this email already exists';
    }
    _users.add(user);
    await _saveUsers();
    return null;
  }

  static Future<String?> login(String email, String password) async {
    final match = _users.where(
      (u) => u.email.toLowerCase() == email.trim().toLowerCase() && u.password == password,
    );
    if (match.isEmpty) return 'Invalid email or password';

    currentUser = match.first;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, currentUser!.email);
    return null;
  }

  static String? _oldEmailOtp;
  static String? _newEmailOtp;
  static String? _pendingNewEmail;

  static String _generateOtp() =>
      (100000 + Random().nextInt(900000)).toString();

  /// Demo OTP delivery — returns the code so the UI can show it in a snackbar.
  static Future<String> sendOldEmailOtp() async {
    final existing = currentUser;
    if (existing == null) throw StateError('Not logged in');
    _oldEmailOtp = _generateOtp();
    return _oldEmailOtp!;
  }

  static bool verifyOldEmailOtp(String code) {
    return code.trim() == _oldEmailOtp;
  }

  static Future<String> sendNewEmailOtp(String newEmail) async {
    if (!_isValidEmail(newEmail)) throw ArgumentError('Invalid email');
    if (_users.any((u) => u.email.toLowerCase() == newEmail.trim().toLowerCase())) {
      throw StateError('Email already registered');
    }
    _pendingNewEmail = newEmail.trim();
    _newEmailOtp = _generateOtp();
    return _newEmailOtp!;
  }

  static bool verifyNewEmailOtp(String code) {
    return code.trim() == _newEmailOtp;
  }

  static Future<String?> commitEmailChange() async {
    final existing = currentUser;
    final newEmail = _pendingNewEmail;
    if (existing == null || newEmail == null) return 'Complete email verification first';
    if (_newEmailOtp == null) return 'Verify OTP sent to new email';

    final idx = _users.indexWhere((u) => u.email.toLowerCase() == existing.email.toLowerCase());
    if (idx == -1) return 'User not found';

    final updated = AuthUser(
      name: existing.name,
      mobile: existing.mobile,
      email: newEmail,
      password: existing.password,
      photoPath: existing.photoPath,
    );
    _users[idx] = updated;
    currentUser = updated;
    _oldEmailOtp = null;
    _newEmailOtp = null;
    _pendingNewEmail = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, newEmail);
    await _saveUsers();
    return null;
  }

  static void cancelEmailChange() {
    _oldEmailOtp = null;
    _newEmailOtp = null;
    _pendingNewEmail = null;
  }

  static Future<String?> updateProfile({
    required String name,
    required String mobile,
    required String? photoPath,
  }) async {
    final existing = currentUser;
    if (existing == null) return 'Please login again';

    if (name.trim().isEmpty) return 'Name is required';
    if (!_isValidMobile(mobile)) return 'Enter a valid 10-digit mobile number';

    final idx = _users.indexWhere((u) => u.email.toLowerCase() == existing.email.toLowerCase());
    if (idx == -1) return 'User not found';

    final updated = AuthUser(
      name: name.trim(),
      mobile: mobile.trim(),
      email: existing.email,
      password: existing.password,
      photoPath: photoPath,
    );

    _users[idx] = updated;
    currentUser = updated;
    await _saveUsers();
    return null;
  }

  static Future<void> logout() async {
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final int? maxLength;
  final Widget? suffixIcon;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A3A5C))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF1A3A5C), size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8F9FF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFF1A3A5C), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1A3A5C)),
    );
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (name.isEmpty || mobile.isEmpty || email.isEmpty || password.isEmpty) {
      _snack('Please fill all fields');
      return;
    }
    if (!AuthService._isValidMobile(mobile)) {
      _snack('Enter a valid 10-digit mobile number');
      return;
    }
    if (!AuthService._isValidEmail(email)) {
      _snack('Enter a valid email address');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters');
      return;
    }

    setState(() => _loading = true);
    final err = await AuthService.register(AuthUser(name: name, mobile: mobile, email: email, password: password));
    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      _snack(err);
      return;
    }

    _snack('Registered successfully. Please login.');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        title: const Text('Register'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text('Create your TrackBus account', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),
              _AuthField(controller: _nameCtrl, label: 'Name', hint: 'Your name', icon: Icons.person_outline),
              const SizedBox(height: 16),
              _AuthField(
                controller: _mobileCtrl,
                label: 'Mobile Number',
                hint: '10-digit number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 16),
              _AuthField(
                controller: _emailCtrl,
                label: 'Email ID',
                hint: 'you@email.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _AuthField(
                controller: _passCtrl,
                label: 'Password',
                hint: 'Min. 6 characters',
                icon: Icons.lock_outline,
                obscureText: _hidePassword,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('Login', style: TextStyle(color: Color(0xFFF4A024), fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1A3A5C)),
    );
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _snack('Enter email and password');
      return;
    }
    if (!AuthService._isValidEmail(email)) {
      _snack('Enter a valid email address');
      return;
    }

    setState(() => _loading = true);
    final err = await AuthService.login(email, password);
    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      _snack(err);
      return;
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text('Login to continue to TrackBus dashboard', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),
              _AuthField(
                controller: _emailCtrl,
                label: 'Email ID',
                hint: 'you@email.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _AuthField(
                controller: _passCtrl,
                label: 'Password',
                hint: 'Enter password',
                icon: Icons.lock_outline,
                obscureText: _hidePassword,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('New here? ', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('Register', style: TextStyle(color: Color(0xFFF4A024), fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _oldOtpCtrl;
  late final TextEditingController _newOtpCtrl;
  String? _photoPath;
  bool _saving = false;
  bool _changingEmail = false;
  int _emailStep = 0; // 0=none, 1=old OTP, 2=new email, 3=new OTP
  String? _originalEmail;

  @override
  void initState() {
    super.initState();
    final u = AuthService.currentUser;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _mobileCtrl = TextEditingController(text: u?.mobile ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _oldOtpCtrl = TextEditingController();
    _newOtpCtrl = TextEditingController();
    _originalEmail = u?.email;
    _photoPath = u?.photoPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _oldOtpCtrl.dispose();
    _newOtpCtrl.dispose();
    AuthService.cancelEmailChange();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1A3A5C)),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _photoPath = file.path);
  }

  Future<void> _deletePhoto() async {
    final path = _photoPath;
    if (path != null && !kIsWeb) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
        // Ignore delete failure; still clear UI and persisted value.
      }
    }
    setState(() => _photoPath = null);
  }

  Future<void> _startEmailChange() async {
    final u = AuthService.currentUser;
    if (u == null) return;
    setState(() {
      _changingEmail = true;
      _emailStep = 1;
      _emailCtrl.text = u.email;
    });
    try {
      final otp = await AuthService.sendOldEmailOtp();
      _snack('OTP sent to ${u.email} (demo: $otp)');
    } catch (e) {
      _snack(e.toString());
      setState(() {
        _changingEmail = false;
        _emailStep = 0;
      });
    }
  }

  Future<void> _verifyOldOtp() async {
    if (!AuthService.verifyOldEmailOtp(_oldOtpCtrl.text.trim())) {
      _snack('Invalid OTP for current email');
      return;
    }
    setState(() {
      _emailStep = 2;
      _emailCtrl.clear();
    });
    _snack('Enter your new email address');
  }

  Future<void> _sendNewEmailOtp() async {
    final newEmail = _emailCtrl.text.trim();
    try {
      final otp = await AuthService.sendNewEmailOtp(newEmail);
      setState(() => _emailStep = 3);
      _snack('OTP sent to $newEmail (demo: $otp)');
    } catch (e) {
      _snack(e.toString().contains('registered') ? 'This email is already in use' : 'Enter a valid email');
    }
  }

  Future<void> _verifyNewOtpAndFinishEmail() async {
    if (!AuthService.verifyNewEmailOtp(_newOtpCtrl.text.trim())) {
      _snack('Invalid OTP for new email');
      return;
    }
    final err = await AuthService.commitEmailChange();
    if (err != null) {
      _snack(err);
      return;
    }
    setState(() {
      _changingEmail = false;
      _emailStep = 0;
      _originalEmail = AuthService.currentUser?.email;
    });
    _snack('Email updated successfully');
  }

  void _cancelEmailChange() {
    AuthService.cancelEmailChange();
    setState(() {
      _changingEmail = false;
      _emailStep = 0;
      _emailCtrl.text = _originalEmail ?? '';
      _oldOtpCtrl.clear();
      _newOtpCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (_changingEmail && _emailStep > 0) {
      _snack('Finish or cancel email change first');
      return;
    }

    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();

    setState(() => _saving = true);
    final err = await AuthService.updateProfile(name: name, mobile: mobile, photoPath: _photoPath);
    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      _snack(err);
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoPath != null && !kIsWeb && File(_photoPath!).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        title: const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: hasPhoto
                              ? ClipOval(child: Image.file(File(_photoPath!), fit: BoxFit.cover))
                              : const Icon(Icons.person, size: 52, color: Color(0xFF1A3A5C)),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(color: Color(0xFFF4A024), shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.upload),
                          label: const Text('Upload Photo'),
                        ),
                        if (hasPhoto)
                          OutlinedButton.icon(
                            onPressed: _deletePhoto,
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
                            label: const Text('Delete', style: TextStyle(color: Color(0xFFC62828))),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _AuthField(
                controller: _nameCtrl,
                label: 'Name',
                hint: 'Your name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _AuthField(
                controller: _mobileCtrl,
                label: 'Mobile Number',
                hint: '10-digit number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 12),
              if (!_changingEmail) ...[
                _AuthField(
                  controller: _emailCtrl,
                  label: 'Email ID',
                  hint: _originalEmail ?? 'you@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _startEmailChange,
                    child: const Text('Change Email (OTP verification)', style: TextStyle(color: Color(0xFF1A3A5C), fontWeight: FontWeight.w600)),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _emailStep == 1
                            ? 'Step 1: Verify current email'
                            : _emailStep == 2
                                ? 'Step 2: Enter new email'
                                : 'Step 3: Verify new email',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A3A5C)),
                      ),
                      const SizedBox(height: 10),
                      if (_emailStep == 1) ...[
                        Text('OTP sent to $_originalEmail', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        _AuthField(controller: _oldOtpCtrl, label: 'OTP', hint: '6-digit code', icon: Icons.lock_outline, keyboardType: TextInputType.number, maxLength: 6),
                        const SizedBox(height: 10),
                        ElevatedButton(onPressed: _verifyOldOtp, style: _otpBtnStyle(), child: const Text('Verify & Continue')),
                      ] else if (_emailStep == 2) ...[
                        _AuthField(controller: _emailCtrl, label: 'New Email', hint: 'new@email.com', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 10),
                        ElevatedButton(onPressed: _sendNewEmailOtp, style: _otpBtnStyle(), child: const Text('Send OTP to New Email')),
                      ] else ...[
                        _AuthField(controller: _newOtpCtrl, label: 'OTP', hint: '6-digit code', icon: Icons.lock_outline, keyboardType: TextInputType.number, maxLength: 6),
                        const SizedBox(height: 10),
                        ElevatedButton(onPressed: _verifyNewOtpAndFinishEmail, style: _otpBtnStyle(), child: const Text('Confirm New Email')),
                      ],
                      TextButton(
                        onPressed: _cancelEmailChange,
                        child: const Text('Cancel email change', style: TextStyle(color: Color(0xFFC62828))),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _otpBtnStyle() => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}

// ─── SPLASH ──────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final next = AuthService.isLoggedIn ? const MainShell() : const RegisterScreen();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2137),
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4A024),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: const Color(0xFFF4A024).withOpacity(0.4), blurRadius: 24, spreadRadius: 4)],
                ),
                child: const Icon(Icons.directions_bus, color: Colors.white, size: 52),
              ),
              const SizedBox(height: 24),
              const Text('TrackBus', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 6),
              const Text('Belagavi Rural Bus Tracker', style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 40),
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Color(0xFFF4A024), strokeWidth: 2.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MAIN SHELL ──────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final List<Widget> _screens = const [HomeScreen(), SearchScreen(), SavedRoutesScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1A3A5C),
        unselectedItemColor: Colors.grey,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved Routes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D2137), Color(0xFF1A3A5C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF4A024), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.directions_bus, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TrackBus', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                            Text('Belagavi Rural', style: TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Row(
                        children: [
                          Icon(Icons.location_on, color: Color(0xFFF4A024), size: 18),
                          SizedBox(width: 8),
                          Text('My Current Location — CBT', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: const _RecentlyTravelledSection(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentlyTravelledSection extends StatelessWidget {
  const _RecentlyTravelledSection();

  BusData? _findBus(String busNo) {
    for (final b in allBuses) {
      if (b.busNo == busNo) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final history = UserSession.travelHistory;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const Row(
          children: [
            Icon(Icons.history, color: Color(0xFF1A3A5C), size: 18),
            SizedBox(width: 8),
            Text('Recently Travelled Buses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          history.isEmpty ? 'Your recent trips will appear here' : '${history.length} recent trip${history.length == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.directions_bus_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No trips yet', style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text('Search a bus route to start tracking', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ],
            ),
          )
        else
          ...history.map((t) {
            final color = t['color'] as Color;
            final bus = _findBus(t['busNo'] as String);
            final fromLabel = t['from'] as String?;
            return GestureDetector(
              onTap: () {
                if (bus != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => BusDetailScreen(bus: bus)));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.directions_bus, color: color, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['busNo'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                          Text(t['route'] as String? ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(
                            fromLabel != null ? '$fromLabel → ${t['to']}' : 'To ${t['to']}',
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                          ),
                          if (t['busType'] != null)
                            Text('${t['busType']} • ${t['departureTime'] ?? ''}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(t['lastTravelled'] as String? ?? 'Recent', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        const SizedBox(height: 6),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ─── SEARCH SCREEN ───────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl   = TextEditingController();
  String _from = '';
  String _to   = '';
  List<BusData> _results = [];
  bool _searched = false;

  bool _showFromSug = false;
  bool _showToSug   = false;

  List<String> _filter(String q) {
    final lower = q.toLowerCase();
    return allStops.where((s) {
      final sl = s.toLowerCase();
      if (sl.contains(lower)) return true;
      if (lower == 'cbt' && s == 'CBT') return true;
      if (lower.contains('cbt') && s == 'CBT') return true;
      return false;
    }).toList();
  }

  void _search() {
    setState(() {
      _results = searchBuses(_from, _to);
      _searched = true;
      _showFromSug = false;
      _showToSug   = false;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() { _fromCtrl.dispose(); _toCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // ── Search card header ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0D2137), Color(0xFF1A3A5C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(children: [
                      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: const Color(0xFFF4A024), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.directions_bus, color: Colors.white, size: 18)),
                      const SizedBox(width: 10),
                      const Text('Find My Bus', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 16),
                    // FROM box
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                      child: Column(
                        children: [
                          // FROM
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                            child: Row(children: [
                              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF4A024), shape: BoxShape.circle)),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('FROM', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                                TextField(
                                  controller: _fromCtrl,
                                  onChanged: (v) => setState(() { _from = v; _showFromSug = v.isNotEmpty; _showToSug = false; }),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                                  decoration: const InputDecoration(hintText: 'Your current stop...', hintStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                ),
                              ])),
                              if (_from.isNotEmpty) GestureDetector(onTap: () => setState(() { _from = ''; _fromCtrl.clear(); _showFromSug = false; }), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                            ]),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Divider(height: 1, color: Colors.grey.shade200)),
                          // TO
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                            child: Row(children: [
                              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF1A3A5C), shape: BoxShape.circle)),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('TO', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                                TextField(
                                  controller: _toCtrl,
                                  onChanged: (v) => setState(() { _to = v; _showToSug = v.isNotEmpty; _showFromSug = false; }),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                                  decoration: const InputDecoration(hintText: 'Where do you want to go?', hintStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                ),
                              ])),
                              if (_to.isNotEmpty) GestureDetector(onTap: () => setState(() { _to = ''; _toCtrl.clear(); _showToSug = false; }), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    // Suggestions
                    if (_showFromSug && _filter(_from).isNotEmpty)
                      _SuggestionBox(items: _filter(_from), onTap: (s) => setState(() { _from = s; _fromCtrl.text = s; _showFromSug = false; })),
                    if (_showToSug && _filter(_to).isNotEmpty)
                      _SuggestionBox(items: _filter(_to), onTap: (s) => setState(() { _to = s; _toCtrl.text = s; _showToSug = false; })),
                    const SizedBox(height: 12),
                    // Search button
                    GestureDetector(
                      onTap: _search,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFFF4A024), borderRadius: BorderRadius.circular(12)),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.search, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('SEARCH BUSES', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Results ──
          Expanded(
            child: !_searched
                ? _searchHint()
                : _results.isEmpty
                    ? _noResult()
                    : ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          Text(
                            normalizeStopName(_to) == 'cbt'
                                ? '${_results.length} bus${_results.length > 1 ? 'es' : ''} to CBT from $_from'
                                : '${_results.length} bus${_results.length > 1 ? 'es' : ''} found from $_from to $_to',
                            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          ..._results.map((bus) => _ResultTile(bus: bus, destination: _to, from: _from)).toList(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _searchHint() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
    Icon(Icons.directions_bus_outlined, size: 60, color: Colors.grey),
    SizedBox(height: 12),
    Text('Enter your stop and destination', style: TextStyle(fontSize: 14, color: Colors.grey)),
  ]));

  Widget _noResult() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.sentiment_dissatisfied, size: 60, color: Colors.grey),
    const SizedBox(height: 12),
    Text('No direct bus from $_from to $_to', style: const TextStyle(fontSize: 14, color: Colors.grey)),
    const SizedBox(height: 6),
    const Text('Try a nearby stop or route via CBT', style: TextStyle(fontSize: 12, color: Colors.grey)),
  ]));
}

class _SuggestionBox extends StatelessWidget {
  final List<String> items;
  final void Function(String) onTap;
  const _SuggestionBox({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 140),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: items.map((s) => ListTile(
          dense: true,
          leading: const Icon(Icons.location_on_outlined, color: Color(0xFF1A3A5C), size: 16),
          title: Text(s, style: const TextStyle(fontSize: 13)),
          onTap: () => onTap(s),
        )).toList(),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final BusData bus;
  final String destination;
  final String from;
  const _ResultTile({required this.bus, required this.destination, required this.from});

  String? _arrivalAtFrom() {
    final idx = bus.stops.indexWhere((s) => stopMatches(s.name, from));
    if (idx == -1) return null;
    return bus.stops[idx].time;
  }

  @override
  Widget build(BuildContext context) {
    final level = bus.crowdLevel;
    Color crowdColor = level < 0.4 ? const Color(0xFF2E7D32) : level < 0.7 ? const Color(0xFFF57C00) : const Color(0xFFC62828);
    final arrival = _arrivalAtFrom();
    return GestureDetector(
      onTap: () {
        UserSession.addTrip(bus.toMap(), destination, from: from);
        Navigator.push(context, MaterialPageRoute(builder: (_) => BusDetailScreen(bus: bus)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: bus.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.directions_bus, color: bus.color, size: 26)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bus.busNo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                Text(bus.route, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${bus.busType} • Departs ${bus.departureTime}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: bus.eta <= 5 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20)),
                child: Text(bus.eta <= 1 ? 'Now!' : '${bus.eta} min', style: TextStyle(color: bus.eta <= 5 ? const Color(0xFF2E7D32) : const Color(0xFFE65100), fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchDetailRow(icon: Icons.person_outline, label: 'Driver', value: bus.driverName),
                _SearchDetailRow(icon: Icons.confirmation_number_outlined, label: 'Conductor', value: bus.conductorName),
                if (arrival != null)
                  _SearchDetailRow(icon: Icons.schedule, label: 'At your stop ($from)', value: arrival),
                _SearchDetailRow(icon: Icons.place_outlined, label: 'Stops on route', value: '${bus.stops.length} stops'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(children: [
              Icon(Icons.people, size: 13, color: crowdColor),
              const SizedBox(width: 4),
              Text('${bus.crowd}  •  ${(level * 100).toInt()}% full', style: TextStyle(fontSize: 12, color: crowdColor, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: level, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(crowdColor), minHeight: 6))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: ElevatedButton.icon(
              onPressed: () {
                UserSession.addTrip(bus.toMap(), destination, from: from);
                Navigator.push(context, MaterialPageRoute(builder: (_) => BusDetailScreen(bus: bus)));
              },
              icon: const Icon(Icons.location_searching, size: 16),
              label: const Text('View Bus Details'),
              style: ElevatedButton.styleFrom(backgroundColor: bus.color, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SearchDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SearchDetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1A3A5C)),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// ─── BUS DETAIL SCREEN ───────────────────────────────────────────────────────

class BusDetailScreen extends StatefulWidget {
  final BusData bus;
  const BusDetailScreen({super.key, required this.bus});
  @override
  State<BusDetailScreen> createState() => _BusDetailScreenState();
}

class _BusDetailScreenState extends State<BusDetailScreen> {
  late int _eta;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _eta = widget.bus.eta;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() { if (_eta > 0) _eta--; });
    });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  Color get _crowdColor => widget.bus.crowdLevel < 0.4 ? const Color(0xFF2E7D32) : widget.bus.crowdLevel < 0.7 ? const Color(0xFFF57C00) : const Color(0xFFC62828);

  IconData get _crowdIcon => widget.bus.crowdLevel < 0.4 ? Icons.sentiment_very_satisfied : widget.bus.crowdLevel < 0.7 ? Icons.sentiment_neutral : Icons.sentiment_very_dissatisfied;

  @override
  Widget build(BuildContext context) {
    final bus   = widget.bus;
    final color = bus.color;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero header ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Back + title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.arrow_back, color: Colors.white, size: 20)),
                        ),
                        const SizedBox(width: 12),
                        const Text('Bus Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: const Row(children: [Icon(Icons.circle, color: Colors.greenAccent, size: 8), SizedBox(width: 4), Text('Live', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))])),
                      ]),
                    ),
                    // TrackBus logo + bus number
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.directions_bus, color: Colors.white, size: 32)),
                        const SizedBox(width: 14),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('TrackBus', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1)),
                          Text(bus.busNo, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                          Text('${bus.route} • ${bus.busType}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                      ]),
                    ),
                  ],
                ),
              ),
            ),

            // ── Driver & Conductor ──
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Text('Staff Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700, letterSpacing: 0.3)),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _StaffRow(icon: Icons.drive_eta, label: 'Driver', name: bus.driverName, phone: bus.driverPhone, color: color),
                  Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                  _StaffRow(icon: Icons.confirmation_number, label: 'Conductor', name: bus.conductorName, phone: bus.conductorPhone, color: color),
                ],
              ),
            ),

            // ── 3 info boxes ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                // ETA
                Expanded(child: _InfoBox(
                  color: color,
                  icon: Icons.access_time_filled,
                  label: 'Arrival Time',
                  value: _eta <= 0 ? 'Here!' : '$_eta min',
                  sub: _eta <= 0 ? 'Bus arrived' : 'away from you',
                )),
                const SizedBox(width: 10),
                // Distance
                Expanded(child: _InfoBox(
                  color: const Color(0xFF1565C0),
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: bus.distance,
                  sub: 'from your stop',
                )),
                const SizedBox(width: 10),
                // Crowd
                Expanded(child: _InfoBox(
                  color: _crowdColor,
                  icon: _crowdIcon,
                  label: 'Crowd',
                  value: bus.crowd,
                  sub: '${(bus.crowdLevel * 100).toInt()}% full',
                  progress: bus.crowdLevel,
                )),
              ]),
            ),

            // ── Route Timeline ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(children: [
                      Icon(Icons.route, color: color, size: 18),
                      const SizedBox(width: 6),
                      Text('Route & Live Position', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                    ]),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: bus.stops.asMap().entries.map((entry) {
                        final i    = entry.key;
                        final stop = entry.value;
                        final isLast = i == bus.stops.length - 1;
                        return _StopTimelineTile(stop: stop, color: color, isLast: isLast);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  final IconData icon;
  final String label, name, phone;
  final Color color;
  const _StaffRow({required this.icon, required this.label, required this.name, required this.phone, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [const Icon(Icons.phone, size: 12, color: Color(0xFF2E7D32)), const SizedBox(width: 4), Text(phone, style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600))]),
        ),
      ]),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label, value, sub;
  final double? progress;
  const _InfoBox({required this.color, required this.icon, required this.label, required this.value, required this.sub, this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        if (progress != null) ...[
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 4)),
        ],
      ]),
    );
  }
}

class _StopTimelineTile extends StatelessWidget {
  final BusStop stop;
  final Color color;
  final bool isLast;
  const _StopTimelineTile({required this.stop, required this.color, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isPassed  = stop.status == 'passed';
    final isCurrent = stop.status == 'current';

    Color dotColor = isCurrent ? color : isPassed ? Colors.grey.shade400 : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(
              width: isCurrent ? 18 : 12,
              height: isCurrent ? 18 : 12,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: isCurrent ? Border.all(color: color.withOpacity(0.3), width: 3) : null,
                boxShadow: isCurrent ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)] : null,
              ),
            ),
            if (!isLast) Container(width: 2, height: 44, color: isPassed ? Colors.grey.shade300 : Colors.grey.shade200),
          ]),
        ),
        const SizedBox(width: 12),
        // Stop info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(stop.name, style: TextStyle(fontSize: 14, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500, color: isPassed ? Colors.grey : const Color(0xFF1A1A2E)))),
                    Text(stop.time, style: TextStyle(fontSize: 12, color: isPassed ? Colors.grey : const Color(0xFF1A3A5C), fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal)),
                  ],
                ),
                if (isCurrent) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.directions_bus, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text('Bus is here now', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

}

// ─── SAVED ROUTES SCREEN ────────────────────────────────────────────────────

class SavedRoutesScreen extends StatelessWidget {
  const SavedRoutesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final history = UserSession.travelHistory;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        title: const Text('Saved Routes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: history.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.bookmark_outline, size: 60, color: Colors.grey),
              SizedBox(height: 16),
              Text('No saved routes yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey)),
              SizedBox(height: 8),
              Text('Travel on a bus to save routes here', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ]))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                const Text('YOUR TRAVELLED ROUTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                ...history.map((t) {
                  final color = t['color'] as Color;
                  return GestureDetector(
                    onTap: () {
                      final bus = allBuses.firstWhere((b) => b.busNo == t['busNo'], orElse: () => allBuses.first);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BusDetailScreen(bus: bus)));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.directions_bus, color: color, size: 24)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t['busNo'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                            Text(t['route'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text('To ${t['to']}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                            const SizedBox(height: 6),
                            Text(t['lastTravelled'] as String, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                          ]),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }
}

// ─── PROFILE SCREEN ──────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _editProfile() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RegisterScreen()), (_) => false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1A3A5C)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.currentUser;
    final hasPhoto = u?.photoPath != null && !kIsWeb && File(u!.photoPath!).existsSync();

    if (u == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A3A5C)),
            child: const Text('Login / Register'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D2137), Color(0xFF1A3A5C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF4A024), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.directions_bus, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text('TrackBus', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _editProfile,
                  child: Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                          border: Border.all(color: const Color(0xFF1A3A5C).withOpacity(0.2), width: 2),
                        ),
                        child: hasPhoto
                            ? ClipOval(child: Image.file(File(u.photoPath!), fit: BoxFit.cover))
                            : const Icon(Icons.person, color: Color(0xFF1A3A5C), size: 48),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(color: Color(0xFFF4A024), shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(child: Text(u.email, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(u.mobile, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _editProfile,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Profile'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1A3A5C),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── White bottom with options ──
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('ACCOUNT OPTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  _ProfileOption(
                    icon: Icons.edit,
                    label: 'Edit Profile',
                    sub: 'Update name, mobile, photo & email (OTP)',
                    color: const Color(0xFF1A3A5C),
                    onTap: _editProfile,
                  ),
                  _ProfileOption(icon: Icons.school, label: 'Student Registration', sub: 'Register for student bus pass', color: const Color(0xFF2E7D32),
                    onTap: () => _showSnack('Student Registration coming soon!')),
                  _ProfileOption(icon: Icons.bookmark, label: 'Edit Saved Routes', sub: 'Manage your saved bus routes', color: const Color(0xFF6A1B9A),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedRoutesScreen()))),
                  _ProfileOption(icon: Icons.notifications_outlined, label: 'Notifications', sub: 'Manage bus arrival alerts', color: const Color(0xFFF57C00),
                    onTap: () => _showSnack('Notifications coming soon!')),
                  const SizedBox(height: 8),
                  const Text('MORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  _ProfileOption(icon: Icons.help_outline, label: 'Help & Support', sub: 'FAQs and contact us', color: Colors.grey,
                    onTap: () => _showSnack('Help coming soon!')),
                  _ProfileOption(icon: Icons.logout, label: 'Logout', sub: 'Sign out of your account', color: const Color(0xFFC62828),
                    onTap: _logout),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;

  const _ProfileOption({required this.icon, required this.label, required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
            Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}