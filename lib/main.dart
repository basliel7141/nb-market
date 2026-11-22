
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl =
    'https://fvpxdjbevwuiqywegapf.supabase.co';

const supabaseKey =
    'sb_publishable_92a1et2DQsEz__A-D8MR0g_I3NUg-f1';

// Supabase Edge Function endpoint
const authFunctionName = 'hyper-processor';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const NBMarketApp());
}

final supabase = Supabase.instance.client;

class NBMarketApp extends StatelessWidget {
  const NBMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NB MARKET',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7900),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor:
            const Color(0xFF101010),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101010),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (supabase.auth.currentSession != null) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool isRegister = false;
  bool hidePassword = true;
  bool loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<Map<String, dynamic>> callAuth(
    Map<String, dynamic> body,
  ) async {
    final response = await supabase.functions.invoke(
      authFunctionName,
      body: body,
    );

    final data = response.data;

    if (data is Map) {
      final result = Map<String, dynamic>.from(data);

      if (response.status >= 400 ||
          result['error'] != null) {
        throw Exception(
          result['error'] ?? 'Something went wrong',
        );
      }

      return result;
    }

    throw Exception('Invalid server response');
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final phone = _phoneController.text.trim();
      final password = _passwordController.text;

      if (isRegister) {
        await callAuth({
          'action': 'register',
          'full_name': _nameController.text.trim(),
          'phone': phone,
          'password': password,
        });
      }

      final result = await callAuth({
        'action': 'login',
        'phone': phone,
        'password': password,
      });

      final refreshToken = result['refresh_token'];

      if (refreshToken == null ||
          refreshToken.toString().isEmpty) {
        throw Exception(
          'Login token was not received',
        );
      }

      await supabase.auth.setSession(
        refreshToken.toString(),
      );

      if (!mounted) return;

      showMessage(
        isRegister
            ? 'Account created successfully!'
            : 'Login successful!',
      );
    } catch (error) {
      if (!mounted) return;

      String message = error
          .toString()
          .replaceFirst('Exception: ', '');

      if (message.contains('404') ||
          message.contains('NOT_FOUND')) {
        message =
            'Authentication service not found. Please check the server endpoint.';
      }

      showMessage(message);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Widget inputField({
    required String label,
    required TextEditingController controller,
    bool password = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: password && hidePassword,
        keyboardType: label == 'Phone Number'
            ? TextInputType.phone
            : TextInputType.text,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: password
              ? IconButton(
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      hidePassword = !hidePassword;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.shopping_cart,
                    size: 75,
                    color: Color(0xFFFF7900),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'NB MARKET',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Buy • Sell • Shop Easy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 35),
                  Text(
                    isRegister
                        ? 'Create Account'
                        : 'Welcome Back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 25),

                  if (isRegister)
                    inputField(
                      label: 'Full Name',
                      controller: _nameController,
                      validator: (value) {
                        if (value == null ||
                            value.trim().length < 2) {
                          return 'Enter your full name';
                        }
                        return null;
                      },
                    ),

                  inputField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    validator: (value) {
                      final phone =
                          (value ?? '').replaceAll(
                        RegExp(r'\s+'),
                        '',
                      );

                      if (!RegExp(
                        r'^\+?[0-9]{9,15}$',
                      ).hasMatch(phone)) {
                        return 'Enter a valid phone number';
                      }

                      return null;
                    },
                  ),

                  inputField(
                    label: 'Password',
                    controller: _passwordController,
                    password: true,
                    validator: (value) {
                      if (value == null ||
                          value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }

                      return null;
                    },
                  ),

                  if (isRegister)
                    inputField(
                      label: 'Confirm Password',
                      controller: _confirmController,
                      password: true,
                      validator: (value) {
                        if (value !=
                            _passwordController.text) {
                          return 'Passwords do not match';
                        }

                        return null;
                      },
                    ),

                  if (!isRegister)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          showMessage(
                            'Password reset will be added next.',
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFFF7900),
                        foregroundColor: Colors.black,
                      ),
                      child: loading
                          ? const CircularProgressIndicator(
                              color: Colors.black,
                            )
                          : Text(
                              isRegister
                                  ? 'CREATE ACCOUNT'
                                  : 'LOGIN',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            setState(() {
                              isRegister = !isRegister;
                            });
                          },
                    child: Text(
                      isRegister
                          ? 'Already have an account? Login'
                          : "Don't have an account? Register",
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    final name =
        user?.userMetadata?['full_name'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NB MARKET',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag,
              size: 75,
              color: Color(0xFFFF7900),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome, $name!',
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text('NB MARKET'),
            const SizedBox(height: 8),
            const Text(
              'Your account is connected.',
              style: TextStyle(
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
