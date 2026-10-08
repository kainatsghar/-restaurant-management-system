import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/social_icons.dart';
import 'home_menu_screen.dart';
import 'restaurant_register_screen.dart';

class RestaurantLoginScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const RestaurantLoginScreen({
    super.key,
    this.initialIsSignUp = false,
  });

  @override
  State<RestaurantLoginScreen> createState() => _RestaurantLoginScreenState();
}

class _RestaurantLoginScreenState extends State<RestaurantLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  late bool _isSignUp;

  // Controllers for Sign In & Sign Up
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Additional controllers for Restaurant Sign Up
  final TextEditingController _restaurantNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _restaurantNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Handle Restaurant Sign In
  Future<void> _handleRestaurantLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signInRestaurant(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      _showSuccessSnackBar('Welcome back to your restaurant dashboard!');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeMenuScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Handle Restaurant Sign Up
  Future<void> _handleRestaurantSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signUpRestaurant(
        restaurantName: _restaurantNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      _showSuccessSnackBar('Restaurant account created successfully!');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeMenuScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Handle Google Sign In for Restaurant
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final credential = await _authService.signInRestaurantWithGoogle();

      if (credential != null && mounted) {
        _showSuccessSnackBar('Signed in with Google successfully!');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeMenuScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFFFA4468).withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          backgroundColor: const Color(0xFF1A1B20),
          title: const Text(
            'Reset Password',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your restaurant email address to receive password reset instructions.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  hintStyle: const TextStyle(color: Color(0xFF7A828E), fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF141518),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2E313C)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2E313C)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFFA4468), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final email = resetEmailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        _showErrorSnackBar('Please enter a valid email address.');
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        await _authService.sendPasswordResetEmail(email);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        _showSuccessSnackBar(
                          'Password reset email sent to $email.',
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        _showErrorSnackBar(
                          e.toString().replaceAll('Exception: ', ''),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA4468),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Section: Black + Dark Rose Header with Pink Accents
            _buildTopHeader(),

            // Floating Black + Pink Card overlapping the header
            Transform.translate(
              offset: const Offset(0, -60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildMainCard(),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF381420),
            Color(0xFF261822),
            Color(0xFF141518),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with Back Button and Restaurant Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1F24),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFA4468).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFA4468).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFA4468).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          color: Color(0xFFFA4468),
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Restaurant Portal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Large White Title
              Text(
                _isSignUp ? 'Register your\nRestaurant' : 'Sign in to your\nAccount',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                _isSignUp
                    ? 'Create a restaurant account to manage your menu'
                    : 'Enter your email and password to log in',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFA0AAB5),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1B20),
            Color(0xFF261822),
            Color(0xFF381420),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFA4468).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFA4468).withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Continue with Google Button
            _buildGoogleButton(),
            const SizedBox(height: 20),

            // Or login with Divider
            Row(
              children: [
                const Expanded(
                  child: Divider(color: Color(0xFF2E313C), thickness: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    _isSignUp ? 'Or register with' : 'Or login with',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFA0AAB5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(color: Color(0xFF2E313C), thickness: 1),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Form Fields based on Sign In vs Sign Up
            if (_isSignUp) ...[
              // Restaurant Name
              _buildLabel('Restaurant Name'),
              _buildTextField(
                controller: _restaurantNameController,
                hintText: 'e.g. Royal Spice Grill',
                icon: Icons.storefront_outlined,
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Enter restaurant name' : null,
              ),
              const SizedBox(height: 14),

              // Owner / Manager Name
              _buildLabel('Owner / Manager Name'),
              _buildTextField(
                controller: _ownerNameController,
                hintText: 'e.g. Shoban Haider',
                icon: Icons.person_outline_rounded,
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Enter owner name' : null,
              ),
              const SizedBox(height: 14),

              // Phone Number
              _buildLabel('Phone Number'),
              _buildTextField(
                controller: _phoneController,
                hintText: 'e.g. 0300 - 1234567',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Enter phone number' : null,
              ),
              const SizedBox(height: 14),
            ],

            // Email Address
            _buildLabel('Email Address'),
            _buildTextField(
              controller: _emailController,
              hintText: 'loginaccount@gmail.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Enter email address';
                if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password
            _buildLabel('Password'),
            _buildTextField(
              controller: _passwordController,
              hintText: '••••••••',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              isPasswordVisible: _isPasswordVisible,
              onTogglePassword: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter password';
                if (val.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Remember me and Forgot Password row (only in Sign In mode)
            if (!_isSignUp)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Remember me
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (val) =>
                                setState(() => _rememberMe = val ?? false),
                            activeColor: const Color(0xFFFA4468),
                            side: const BorderSide(
                              color: Color(0xFF5E6573),
                              width: 1.4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Remember me',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Forgot Password ?
                  GestureDetector(
                    onTap: _showForgotPasswordDialog,
                    child: const Text(
                      'Forgot Password ?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFA4468),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 22),

            // Primary Action Button (Log In / Register Restaurant)
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFA4468), Color(0xFFFF6584)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFA4468).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_isSignUp
                        ? _handleRestaurantSignUp
                        : _handleRestaurantLogin),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Text(
                        _isSignUp ? 'Register Restaurant' : 'Log In',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 22),

            // Bottom Switch Row: "Don't have an account? Sign Up"
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have a restaurant account? ",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFA0AAB5),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RestaurantRegisterScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFA4468),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Link to go back to regular user login
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: Color(0xFFA0AAB5),
                ),
                label: const Text(
                  'Switch to Customer / User Login',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFA4468),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return InkWell(
      onTap: _isLoading ? null : _handleGoogleSignIn,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1F24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2E313C),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SocialIcons.google(size: 20),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 14,
          color: Color(0xFF7A828E),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(
          icon,
          size: 19,
          color: const Color(0xFFA0AAB5),
        ),
        suffixIcon: isPassword
            ? IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 19,
                  color: const Color(0xFFA0AAB5),
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF141518),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E313C), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E313C), width: 1.2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFFA4468), width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }
}
