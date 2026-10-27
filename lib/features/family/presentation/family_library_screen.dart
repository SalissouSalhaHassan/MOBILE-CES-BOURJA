import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/family_repository.dart';

class FamilyLibraryScreen extends StatefulWidget {
  const FamilyLibraryScreen({super.key});

  @override
  State<FamilyLibraryScreen> createState() => _FamilyLibraryScreenState();
}

class _FamilyLibraryScreenState extends State<FamilyLibraryScreen>
    with SingleTickerProviderStateMixin {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final FamilyRepository _repository = locator<FamilyRepository>();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  bool _isLoading = true;
  int? _studentId;

  // Digital Resources State
  String _selectedCategory = "all";
  String _selectedSubject = "Toutes";
  final List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'Tout le contenu', 'icon': '📚'},
    {'id': 'books', 'label': 'Livres & Manuels', 'icon': '📖'},
    {'id': 'courses', 'label': 'Fiches & Cours', 'icon': '📝'},
    {'id': 'videos', 'label': 'Vidéos de Cours', 'icon': '🎥'},
    {'id': 'exams', 'label': 'Annales BEPC / BAC', 'icon': '📑'},
  ];
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _filteredResources = [];

  // Physical Library State
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _issues = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final session = locator<SessionManager>();
      final sIdStr = await session.getStudentId();
      _studentId = int.tryParse(sIdStr ?? '');

      await Future.wait([
        _loadDigitalResources(),
        _loadPhysicalLibrary(),
      ]);
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDigitalResources() async {
    try {
      final res = await _apiClient.getJson(
        '/api/mobile/e-library/resources?category=$_selectedCategory&subject=$_selectedSubject',
      );
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _resources = List<Map<String, dynamic>>.from(data['resources'] ?? []);
          _filteredResources = _resources;
        });
      } else {
        // Fallback to past-exams endpoint
        final legacyRes = await _apiClient.getJson(
          '/api/mobile/e-library/past-exams?examType=Tous&subject=Toutes',
        );
        if (legacyRes['success'] == true && legacyRes['data'] != null) {
          final data = legacyRes['data'];
          setState(() {
            _resources = List<Map<String, dynamic>>.from(data['exams'] ?? []);
            _filteredResources = _resources;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPhysicalLibrary() async {
    try {
      _books = await _repository.getLibraryBooks();
      if (_studentId != null) {
        _issues = await _repository.getStudentLibraryIssues(studentId: _studentId!);
      }
    } catch (_) {}
  }

  void _filterSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredResources = _resources;
      } else {
        _filteredResources = _resources.where((e) {
          final t = (e['title'] ?? '').toString().toLowerCase();
          final s = (e['subject'] ?? '').toString().toLowerCase();
          final d = (e['description'] ?? '').toString().toLowerCase();
          return t.contains(q) || s.contains(q) || d.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _openResource(Map<String, dynamic> item) async {
    final videoUrl = item['videoUrl']?.toString();
    final fileUrl = item['fileUrl']?.toString();
    final url = videoUrl?.isNotEmpty == true ? videoUrl : fileUrl;

    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ouverture du document : ${item['title']}'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    }
  }

  Future<void> _reserveBook(Map<String, dynamic> book) async {
    if (_studentId == null) return;
    final result = await _repository.reserveBook(
      bookId: (book['id'] as num).toInt(),
      studentId: _studentId!,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Réservation enregistrée avec succès.'
              : 'Réservation impossible : ${result['error']}',
        ),
        backgroundColor: result['success'] == true ? AppColors.success : AppColors.danger,
      ),
    );
    if (result['success'] == true) {
      _loadPhysicalLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Médiathèque & E-Learning',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Livres, cours PDF, vidéos & annales BEPC/BAC',
              style: TextStyle(fontSize: 11, color: AppColors.slate500),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: AppColors.slate500,
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.cloud_download_rounded, size: 18),
              text: "E-Learning & Digital",
            ),
            Tab(
              icon: Icon(Icons.local_library_rounded, size: 18),
              text: "Emprunts Physiques",
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDigitalTab(),
                _buildPhysicalTab(),
              ],
            ),
    );
  }

  Widget _buildDigitalTab() {
    return Column(
      children: [
        // Search & Filter header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search input
              TextField(
                controller: _searchController,
                onChanged: _filterSearch,
                decoration: InputDecoration(
                  hintText: "Rechercher un livre, cours, vidéo ou annale...",
                  hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate400, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSel = cat['id'] == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Text(cat['icon']!, style: const TextStyle(fontSize: 13)),
                        label: Text(cat['label']!),
                        selected: isSel,
                        onSelected: (sel) {
                          if (sel) {
                            setState(() => _selectedCategory = cat['id']!);
                            _loadDigitalResources();
                          }
                        },
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? Colors.white : AppColors.slate700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Resources list
        Expanded(
          child: _filteredResources.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.menu_book_rounded, color: AppColors.slate400, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        "Aucune ressource trouvée pour cette catégorie.",
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDigitalResources,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredResources.length,
                    itemBuilder: (context, index) {
                      final item = _filteredResources[index];
                      return _buildDigitalResourceCard(item);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDigitalResourceCard(Map<String, dynamic> item) {
    final title = item['title'] ?? 'Ressource pédagogique';
    final subject = item['subject'] ?? 'Matière';
    final level = item['level'] ?? 'Secondaire';
    final category = item['category'] ?? 'courses';
    final isVideo = category == 'videos' || item['type'] == 'Vidéo';
    final isExam = category == 'exams';
    final desc = item['description'] ?? '';
    final author = item['author'] ?? 'Edut Pro';

    final Color badgeColor = isVideo
        ? const Color(0xFFDC2626)
        : isExam
            ? const Color(0xFF2563EB)
            : const Color(0xFF059669);

    final Color badgeBg = isVideo
        ? const Color(0xFFFEF2F2)
        : isExam
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFECFDF5);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVideo
                          ? Icons.play_circle_fill_rounded
                          : isExam
                              ? Icons.assignment_turned_in_rounded
                              : Icons.menu_book_rounded,
                      color: badgeColor,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$subject • $level',
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (item['hasCorrection'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Corrigé type inclus',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
              color: AppColors.slate900,
            ),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.slate600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Source : $author',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.slate400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openResource(item),
                    icon: Icon(
                      isVideo ? Icons.play_arrow_rounded : Icons.visibility_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    label: Text(
                      isVideo ? 'Regarder' : 'Consulter',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: badgeColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalTab() {
    return RefreshIndicator(
      onRefresh: _loadPhysicalLibrary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Livres physiques disponibles',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_books.length} titres',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_books.isEmpty)
            _emptyCard('Aucun livre physique répertorié dans la bibliothèque pour le moment.')
          else
            ..._books.map(_buildPhysicalBookCard),
          const SizedBox(height: 24),
          const Text(
            'Mes emprunts & retours en cours',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
          ),
          const SizedBox(height: 12),
          if (_issues.isEmpty)
            _emptyCard('Aucun emprunt actif ou historique de prêt pour cet élève.')
          else
            ..._issues.map(_buildIssueCard),
        ],
      ),
    );
  }

  Widget _buildPhysicalBookCard(Map<String, dynamic> book) {
    final available = (book['available_quantity'] as num?)?.toInt() ?? 0;
    final total = (book['total_quantity'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book['title']?.toString() ?? 'Livre',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
          ),
          const SizedBox(height: 4),
          Text(
            '${book['author'] ?? 'Auteur inconnu'} • ${book['category'] ?? 'Général'}',
            style: const TextStyle(fontSize: 12, color: AppColors.slate600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rayon : ${book['shelf_location'] ?? '-'}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
              ),
              Text(
                'Disponibles : $available / $total',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: available > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: available > 0 ? () => _reserveBook(book) : null,
              icon: const Icon(Icons.bookmark_add_rounded, size: 15, color: Colors.white),
              label: const Text(
                'Réserver le livre',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    final book = issue['library_books'] as Map<String, dynamic>? ?? {};
    final status = issue['status']?.toString() ?? 'En cours';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book['title']?.toString() ?? 'Livre',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Statut : $status', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(
                'Échéance : ${issue['due_date']?.toString().split('T').first ?? '-'}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate500, fontSize: 12.5)),
      ),
    );
  }
}
