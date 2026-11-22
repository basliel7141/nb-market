
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'customer_features.dart';
const supabaseUrl =
    'https://fvpxdjbevwuiqywegapf.supabase.co';

const supabaseKey =
    'sb_publishable_92a1et2DQsEz__A-D8MR0g_I3NUg-f1';

const authFunctionName = 'hyper-processor';

final supabase = Supabase.instance.client;

const orange = Color(0xFFFF7900);
const darkBackground = Color(0xFF101010);
const cardBackground = Color(0xFF1D1D1D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const NBMarketApp());
}

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
          seedColor: orange,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBackground,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: cardBackground,
          elevation: 0,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// --------------------------------------------------
// AUTH GATE
// --------------------------------------------------

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session == null) {
          return const LoginPage();
        }

        return RoleGate(
          key: ValueKey(session.user.id),
          userId: session.user.id,
        );
      },
    );
  }
}

// --------------------------------------------------
// ROLE VERIFICATION
// --------------------------------------------------

class RoleGate extends StatefulWidget {
  final String userId;

  const RoleGate({
    super.key,
    required this.userId,
  });

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late Future<String> roleFuture;

  @override
  void initState() {
    super.initState();
    roleFuture = loadRole();
  }

  Future<String> loadRole() async {
    final roleData = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', widget.userId)
        .maybeSingle();

    final adminData = await supabase
        .from('admins')
        .select('user_id')
        .eq('user_id', widget.userId)
        .maybeSingle();

    if (roleData == null) {
      throw Exception('Account role was not found.');
    }

    final role = roleData['role'];

    if (role == 'admin' && adminData != null) {
      return 'admin';
    }

    return 'customer';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const LoadingPage();
        }

        if (snapshot.hasError) {
          return ErrorPage(
            message: 'Account verification failed.',
            onRetry: () {
              setState(() {
                roleFuture = loadRole();
              });
            },
          );
        }

        if (snapshot.data == 'admin') {
          return const AdminDashboard();
        }

        return const CustomerFeaturesPage();
      },
    );
  }
}

// --------------------------------------------------
// LOADING PAGE
// --------------------------------------------------

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: orange,
        ),
      ),
    );
  }
}

// --------------------------------------------------
// ERROR PAGE
// --------------------------------------------------

class ErrorPage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorPage({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 15),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('RETRY'),
              ),
              TextButton(
                onPressed: () async {
                  await supabase.auth.signOut();
                },
                child: const Text('LOGOUT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------
// LOGIN AND REGISTER
// --------------------------------------------------

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
        throw Exception('Login token was not received');
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
            'Authentication service not found. Check the server.';
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.shopping_cart,
                    size: 75,
                    color: orange,
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
                    style: TextStyle(color: orange),
                  ),
                  const SizedBox(height: 35),
                  Text(
                    isRegister ? 'Create Account' : 'Welcome Back',
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
                      final phone = (value ?? '').replaceAll(
                        RegExp(r'\s+'),
                        '',
                      );

                      if (!RegExp(r'^\+?[0-9]{9,15}$')
                          .hasMatch(phone)) {
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
                      if (value == null || value.length < 8) {
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
                        if (value != _passwordController.text) {
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
                        child: const Text('Forgot Password?'),
                      ),
                    ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
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

// --------------------------------------------------
// ADMIN DASHBOARD
// --------------------------------------------------

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool loading = true;
  String? error;

  int totalUsers = 0;
  int totalPosts = 0;
  int activePosts = 0;
  int pendingPosts = 0;
  int totalViews = 0;

  List<Map<String, dynamic>> pendingList = [];

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final users = await supabase
          .from('profiles')
          .select('id');

      final posts = await supabase
          .from('posts')
          .select('id,status,views_count,title,price,city');

      final views = await supabase
          .from('post_views')
          .select('id');

      final allPosts =
          List<Map<String, dynamic>>.from(posts);

      totalUsers = users.length;
      totalPosts = allPosts.length;

      activePosts = allPosts
          .where((p) => p['status'] == 'active')
          .length;

      final pending = allPosts
          .where((p) => p['status'] == 'pending')
          .toList();

      pendingPosts = pending.length;
      totalViews = views.length;
      pendingList = pending;

    } catch (e) {
      error = e.toString();
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Widget statCard(
    String title,
    int value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: orange, size: 30),
            const SizedBox(height: 12),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NB MARKET ADMIN',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              await supabase.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loading
          ? const LoadingPage()
          : error != null
              ? ErrorPage(
                  message: 'Could not load admin data.\n$error',
                  onRetry: loadDashboard,
                )
              : RefreshIndicator(
                  onRefresh: loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Manage NB MARKET',
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 20),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.35,
                        children: [
                          statCard(
                            'Total Users',
                            totalUsers,
                            Icons.people,
                          ),
                          statCard(
                            'Total Posts',
                            totalPosts,
                            Icons.shopping_bag,
                          ),
                          statCard(
                            'Active Posts',
                            activePosts,
                            Icons.check_circle,
                          ),
                          statCard(
                            'Pending Posts',
                            pendingPosts,
                            Icons.pending_actions,
                          ),
                        ],
                      ),

                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.visibility,
                            color: orange,
                          ),
                          title: const Text('Total Views'),
                          trailing: Text(
                            totalViews.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Pending Posts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (pendingList.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No pending posts.'),
                          ),
                        ),

                      ...pendingList.map((post) {
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.inventory_2,
                              color: orange,
                            ),
                            title: Text(
                              post['title']?.toString() ?? 'Untitled',
                            ),
                            subtitle: Text(
                              '${post['city'] ?? ''} • ETB ${post['price'] ?? 0}',
                            ),
                            trailing: const Icon(Icons.pending),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

// --------------------------------------------------
// CUSTOMER DASHBOARD
// --------------------------------------------------

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() =>
      _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final searchController = TextEditingController();

  bool loading = true;
  String? error;

  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> posts = [];

  String selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    loadCustomerData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadCustomerData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final categoryData = await supabase
          .from('categories')
          .select('id,name_en,name_am,active')
          .eq('active', true)
          .order('name_en');

      final postData = await supabase
          .from('posts')
          .select(
            'id,user_id,category_id,title,description,price,city,area,post_type,created_at',
          )
          .eq('status', 'active')
          .order('created_at', ascending: false);

      categories =
          List<Map<String, dynamic>>.from(categoryData);

      posts = List<Map<String, dynamic>>.from(postData);

    } catch (e) {
      error = e.toString();
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get filteredPosts {
    final query = searchController.text.trim().toLowerCase();

    return posts.where((post) {
      final title =
          (post['title'] ?? '').toString().toLowerCase();

      final city =
          (post['city'] ?? '').toString().toLowerCase();

      final area =
          (post['area'] ?? '').toString().toLowerCase();

      final description =
          (post['description'] ?? '').toString().toLowerCase();

      final matchesSearch = query.isEmpty ||
          title.contains(query) ||
          city.contains(query) ||
          area.contains(query) ||
          description.contains(query);

      final matchesCategory = selectedCategory == 'All' ||
          post['category_id'].toString() == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  Widget categoryButton(
    String title,
    String value,
  ) {
    final selected = selectedCategory == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(title),
        selected: selected,
        selectedColor: orange,
        onSelected: (_) {
          setState(() {
            selectedCategory = value;
          });
        },
      ),
    );
  }

  Widget postCard(Map<String, dynamic> post) {
    final price = post['price'] ?? 0;
    final title = post['title'] ?? 'Untitled';
    final city = post['city'] ?? '';
    final area = post['area'] ?? '';
    final type = post['post_type'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shopping_bag,
                  color: orange,
                  size: 35,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title.toString(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'ETB $price',
              style: const TextStyle(
                color: orange,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text('$city ${area.toString().isEmpty ? '' : '• $area'}'),
            const SizedBox(height: 6),
            Text(
              type.toString().toUpperCase(),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final name =
        user?.userMetadata?['full_name']?.toString() ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NB MARKET',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: loadCustomerData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              await supabase.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loading
          ? const LoadingPage()
          : error != null
              ? ErrorPage(
                  message: 'Could not load marketplace.\n$error',
                  onRetry: loadCustomerData,
                )
              : RefreshIndicator(
                  onRefresh: loadCustomerData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Hello, $name!',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Buy • Sell • Shop Easy',
                        style: TextStyle(color: orange),
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search products, city, area...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        height: 45,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            categoryButton('All', 'All'),
                            ...categories.map((category) {
                              return categoryButton(
                                category['name_en']?.toString() ?? '',
                                category['id'].toString(),
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Latest Posts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (filteredPosts.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No posts found.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      ...filteredPosts.map(postCard),
                    ],
                  ),
                ),
    );
  }
}
