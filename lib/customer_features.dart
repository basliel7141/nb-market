
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _db = Supabase.instance.client;
const _orange = Color(0xFFFF7900);
const _card = Color(0xFF1D1D1D);

class CustomerFeaturesPage extends StatefulWidget {
  const CustomerFeaturesPage({super.key});

  @override
  State<CustomerFeaturesPage> createState() => _CustomerFeaturesPageState();
}

class _CustomerFeaturesPageState extends State<CustomerFeaturesPage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NB MARKET'),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async => _db.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: const [
          _CustomerHomePage(),
          _AddPostPage(),
          _MyRequestsPage(),
          _NewRequestPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            label: 'Add Post',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'My Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.post_add),
            label: 'New Request',
          ),
        ],
      ),
    );
  }
}

class _CustomerHomePage extends StatefulWidget {
  const _CustomerHomePage();

  @override
  State<_CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<_CustomerHomePage> {
  late Future<List<Map<String, dynamic>>> future;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    future = loadPosts();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> loadPosts() async {
    final rows = await _db
        .from('posts')
        .select('id,title,price,city,area,post_type,description,created_at')
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    final name = _db.auth.currentUser?.userMetadata?['full_name']?.toString() ?? 'User';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(child: Text('Could not load posts: ${snap.error}'));
        }

        final q = search.text.trim().toLowerCase();
        final rows = (snap.data ?? []).where((p) {
          return '${p['title']} ${p['city']} ${p['area']} ${p['description']}'
              .toLowerCase()
              .contains(q);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => future = loadPosts());
            await future;
          },
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
                style: TextStyle(color: _orange),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search products, city, area...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: _card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Latest Posts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No posts found.')),
                  ),
                ),
              ...rows.map(
                (p) => Card(
                  color: _card,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(
                      Icons.shopping_bag,
                      color: _orange,
                      size: 32,
                    ),
                    title: Text(p['title']?.toString() ?? ''),
                    subtitle: Text('${p['city'] ?? ''} • ${p['post_type'] ?? ''}'),
                    trailing: Text(
                      'ETB ${p['price'] ?? ''}',
                      style: const TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddPostPage extends StatefulWidget {
  const _AddPostPage();

  @override
  State<_AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<_AddPostPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final city = TextEditingController();
  final subCity = TextEditingController();
  final area = TextEditingController();
  final location = TextEditingController();

  List<Map<String, dynamic>> categories = [];
  String? categoryId;
  String postType = 'sale';
  List<XFile> photos = [];
  XFile? video;
  bool loadingCategories = true;
  bool saving = false;
  String? categoryError;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    price.dispose();
    city.dispose();
    subCity.dispose();
    area.dispose();
    location.dispose();
    super.dispose();
  }

  Future<void> loadCategories() async {
    try {
      final rows = await _db
          .from('categories')
          .select('id,name_en,name_am')
          .eq('active', true)
          .order('name_en');

      if (!mounted) return;

      setState(() {
        categories = List<Map<String, dynamic>>.from(rows);
        loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        categoryError = e.toString();
        loadingCategories = false;
      });
    }
  }

  Future<void> choosePhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);

    if (!mounted) return;

    setState(() => photos = picked.take(10).toList());

    if (picked.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 photos are allowed.')),
      );
    }
  }

  Future<void> chooseVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );

    if (picked == null) return;

    final player = VideoPlayerController.file(File(picked.path));

    try {
      await player.initialize();

      if (player.value.duration > const Duration(seconds: 60)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video must be 60 seconds or shorter.'),
            ),
          );
        }
        return;
      }

      if (mounted) setState(() => video = picked);
    } finally {
      await player.dispose();
    }
  }

  String extensionOf(String name) =>
      name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';

  String mimeOf(String ext) {
    if (ext == 'png') return 'image/png';
    if (ext == 'webp') return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> submitPost() async {
    if (!form.currentState!.validate()) return;

    if (categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a category.')),
      );
      return;
    }

    final user = _db.auth.currentUser;
    if (user == null) return;

    setState(() => saving = true);

    try {
      final post = await _db.from('posts').insert({
        'user_id': user.id,
        'category_id': categoryId,
        'post_type': postType,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'price': double.parse(price.text.trim()),
        'city': city.text.trim(),
        'sub_city': subCity.text.trim(),
        'area': area.text.trim(),
        'location_details': location.text.trim(),
        'contact_phone': null,
        'status': 'pending',
      }).select('id').single();

      final postId = post['id'].toString();
      final storage = _db.storage.from('post-media');

      for (var i = 0; i < photos.length; i++) {
        final file = photos[i];
        final ext = extensionOf(file.name);
        final path = '${user.id}/$postId/photo_$i.$ext';

        await storage.uploadBinary(
          path,
          await file.readAsBytes(),
          fileOptions: FileOptions(contentType: mimeOf(ext)),
        );

        await _db.from('post_media').insert({
          'post_id': postId,
          'media_type': 'image',
          'storage_path': path,
        });
      }

      if (video != null) {
        final path = '${user.id}/$postId/video.mp4';

        await storage.uploadBinary(
          path,
          await video!.readAsBytes(),
          fileOptions: const FileOptions(contentType: 'video/mp4'),
        );

        await _db.from('post_media').insert({
          'post_id': postId,
          'media_type': 'video',
          'storage_path': path,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post submitted. Waiting for Admin approval.'),
        ),
      );

      form.currentState!.reset();
      title.clear();
      description.clear();
      price.clear();
      city.clear();
      subCity.clear();
      area.clear();
      location.clear();

      setState(() {
        categoryId = null;
        postType = 'sale';
        photos = [];
        video = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(
    String label,
    TextEditingController controller, {
    int lines = 1,
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Add Post',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: postType,
            decoration: const InputDecoration(
              labelText: 'Post Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'sale', child: Text('For Sale')),
              DropdownMenuItem(value: 'rent', child: Text('For Rent')),
            ],
            onChanged: (v) => setState(() => postType = v ?? 'sale'),
          ),
          const SizedBox(height: 12),
          if (loadingCategories)
            const Center(child: CircularProgressIndicator())
          else if (categoryError != null)
            Text('Category error: $categoryError')
          else
            DropdownButtonFormField<String>(
              value: categoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c['id'].toString(),
                      child: Text('${c['name_en']} • ${c['name_am']}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => categoryId = v),
            ),
          const SizedBox(height: 12),
          field('Title', title),
          field('Description', description, lines: 4),
          field('Price (ETB)', price, numeric: true),
          field('City', city),
          field('Sub-city', subCity),
          field('Area', area),
          field('Additional location details', location),
          Card(
            color: _card,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Photos: ${photos.length}/10'),
                  OutlinedButton.icon(
                    onPressed: choosePhotos,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose up to 10 photos'),
                  ),
                  if (photos.isNotEmpty)
                    Text(
                      photos.map((f) => f.name).join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Divider(),
                  Text(
                    video == null
                        ? 'No video selected'
                        : 'Video: ${video!.name}',
                  ),
                  OutlinedButton.icon(
                    onPressed: chooseVideo,
                    icon: const Icon(Icons.video_library),
                    label: const Text('Choose one video (max 60 sec)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your post will be sent to Admin for approval. Contact phone is managed by Admin.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: saving || loadingCategories || categoryError != null
                  ? null
                  : submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
              ),
              child: saving
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('SUBMIT POST'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRequestsPage extends StatefulWidget {
  const _MyRequestsPage();

  @override
  State<_MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<_MyRequestsPage> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = loadRequests();
  }

  Future<List<Map<String, dynamic>>> loadRequests() async {
    final uid = _db.auth.currentUser!.id;

    final rows = await _db
        .from('user_requests')
        .select('id,title,details,city,area,status,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Text('Could not load requests: ${snap.error}'),
          );
        }

        final rows = snap.data ?? [];

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => future = loadRequests());
            await future;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'My Requests',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No requests yet.'),
                  ),
                ),
              ...rows.map(
                (r) => Card(
                  color: _card,
                  child: ListTile(
                    title: Text(r['title']?.toString() ?? ''),
                    subtitle: Text(
                      '${r['details'] ?? ''}\n${r['city'] ?? ''} • ${r['area'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      r['status']?.toString() ?? 'open',
                      style: const TextStyle(color: _orange),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NewRequestPage extends StatefulWidget {
  const _NewRequestPage();

  @override
  State<_NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends State<_NewRequestPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final details = TextEditingController();
  final city = TextEditingController();
  final area = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    title.dispose();
    details.dispose();
    city.dispose();
    area.dispose();
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController c, {
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: lines,
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> sendRequest() async {
    if (!form.currentState!.validate()) return;

    setState(() => saving = true);

    try {
      await _db.from('user_requests').insert({
        'user_id': _db.auth.currentUser!.id,
        'title': title.text.trim(),
        'details': details.text.trim(),
        'city': city.text.trim(),
        'area': area.text.trim(),
        'status': 'open',
      });

      if (!mounted) return;

      title.clear();
      details.clear();
      city.clear();
      area.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your request was sent to Admin.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'New Request',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell Admin which product or property you are looking for.',
          ),
          const SizedBox(height: 16),
          field('What are you looking for?', title),
          field('Details / description', details, lines: 4),
          field('City', city),
          field('Area', area),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: saving ? null : sendRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
              ),
              child: saving
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('SEND REQUEST'),
            ),
          ),
        ],
      ),
    );
  }
}

