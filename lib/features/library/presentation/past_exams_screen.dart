import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PastExamsScreen extends StatefulWidget {
  const PastExamsScreen({super.key});

  @override
  State<PastExamsScreen> createState() => _PastExamsScreenState();
}

class _PastExamsScreenState extends State<PastExamsScreen> {
  final MobileApiClient _apiClient = locator<MobileApiClient>();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _selectedCategory = "all";
  String _selectedSubject = "Toutes";
  String _selectedExamType = "Tous";

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'Tout', 'icon': '📚'},
    {'id': 'exams', 'label': 'Annales BEPC/BAC', 'icon': '📑'},
    {'id': 'books', 'label': 'Livres & Manuels', 'icon': '📖'},
    {'id': 'videos', 'label': 'Vidéos de Cours', 'icon': '🎥'},
    {'id': 'courses', 'label': 'Fiches & Polycopiés', 'icon': '📝'},
  ];

  List<String> _subjects = ["Toutes", "Mathématiques", "Physique-Chimie", "SVT", "Français", "Philosophie", "Histoire-Géo", "Anglais"];
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiClient.getJson(
        '/api/mobile/e-library/resources?category=$_selectedCategory&subject=$_selectedSubject',
      );
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _resources = List<Map<String, dynamic>>.from(data['resources'] ?? []);
          _filtered = _resources;
          _isLoading = false;
        });
      } else {
        // Fallback to past-exams endpoint
        final legacyRes = await _apiClient.getJson(
          '/api/mobile/e-library/past-exams?examType=$_selectedExamType&subject=$_selectedSubject',
        );
        if (legacyRes['success'] == true && legacyRes['data'] != null) {
          final data = legacyRes['data'];
          setState(() {
            _resources = List<Map<String, dynamic>>.from(data['exams'] ?? []);
            _filtered = _resources;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _resources;
      } else {
        _filtered = _resources.where((e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Médiathèque & E-Learning", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Manuels, vidéos explicatives & annales d'examens", style: TextStyle(fontSize: 11, color: AppColors.slate500)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: _filterSearch,
                  decoration: InputDecoration(
                    hintText: "Rechercher un livre, cours, vidéo ou examen...",
                    hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate400, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Category selector
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
                              _loadResources();
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.menu_book_rounded, color: AppColors.slate400, size: 44),
                            const SizedBox(height: 12),
                            Text("Aucune ressource trouvée pour ces critères.", style: AppTextStyles.caption),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          return _buildResourceCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(Map<String, dynamic> item) {
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
                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11.5),
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
                      Text('Corrigé type', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 10.5)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.slate900)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.slate600, height: 1.35)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Source : $author',
                style: const TextStyle(fontSize: 11, color: AppColors.slate400, fontWeight: FontWeight.w500),
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
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
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
}

