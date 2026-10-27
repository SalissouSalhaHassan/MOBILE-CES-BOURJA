import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/library_repository.dart';

class ELibraryScreen extends StatefulWidget {
  const ELibraryScreen({super.key});

  @override
  State<ELibraryScreen> createState() => _ELibraryScreenState();
}

class _ELibraryScreenState extends State<ELibraryScreen> with SingleTickerProviderStateMixin {
  final LibraryRepository _repo = locator<LibraryRepository>();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  int? _studentId;

  // Selected format filter: 'all' | 'digital' | 'physical' | 'loans'
  String _selectedFormat = 'all';

  // Selected category filter
  String _selectedCategory = "Tous";
  List<String> _categories = [
    "Tous",
    "Informatique & IA",
    "Mathématiques",
    "Sciences",
    "Littérature & Français",
    "Histoire & Sociologie",
    "Économie & Gestion",
    "Médecine & Santé",
    "Sciences Juridiques",
  ];

  List<dynamic> _books = [];
  List<Map<String, dynamic>> _loans = [];
  final Set<int> _downloadedBookIds = {};

  @override
  void initState() {
    super.initState();
    _initUserAndCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initUserAndCatalog() async {
    try {
      final session = locator<SessionManager>();
      final sIdStr = await session.getStudentId();
      _studentId = int.tryParse(sIdStr ?? '');
    } catch (_) {}

    await _loadCatalog();
    if (_studentId != null) {
      _loadLoans();
    }
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);

    final apiFormat = (_selectedFormat == 'loans')
        ? 'all'
        : _selectedFormat;

    final data = await _repo.getCatalog(
      category: _selectedCategory == "Tous" ? null : _selectedCategory,
      query: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      format: apiFormat == 'all' ? null : apiFormat,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null) {
          _books = (data['books'] as List<dynamic>?) ?? [];
          if (data['categories'] != null) {
            final catList = List<String>.from(data['categories']);
            for (final c in catList) {
              if (!_categories.contains(c)) {
                _categories.add(c);
              }
            }
          }
        }
      });
    }
  }

  Future<void> _loadLoans() async {
    if (_studentId == null) return;
    try {
      final list = await _repo.getIssues(studentId: _studentId);
      if (mounted) {
        setState(() {
          _loans = list;
        });
      }
    } catch (_) {}
  }

  // --- Category Color Gradient Helper ---
  LinearGradient _getCategoryGradient(String? category) {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('informatique') || cat.contains('ia') || cat.contains('algorithme')) {
      return const LinearGradient(
        colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (cat.contains('math')) {
      return const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (cat.contains('science') || cat.contains('physique') || cat.contains('chimie') || cat.contains('svt')) {
      return const LinearGradient(
        colors: [Color(0xFF064E3B), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (cat.contains('littérature') || cat.contains('français') || cat.contains('langue')) {
      return const LinearGradient(
        colors: [Color(0xFF78350F), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (cat.contains('histoire') || cat.contains('sociologie') || cat.contains('géo')) {
      return const LinearGradient(
        colors: [Color(0xFF881337), Color(0xFFE11D48)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (cat.contains('éco') || cat.contains('gestion') || cat.contains('finance')) {
      return const LinearGradient(
        colors: [Color(0xFF0E7490), Color(0xFF0284C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (cat.contains('santé') || cat.contains('médecine')) {
      return const LinearGradient(
        colors: [Color(0xFF134E4A), Color(0xFF0D9488)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (cat.contains('juridique') || cat.contains('droit')) {
      return const LinearGradient(
        colors: [Color(0xFF1E293B), Color(0xFF334155)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  void _downloadBook(Map<String, dynamic> book) async {
    final bookId = book['id'] is int ? book['id'] as int : int.tryParse(book['id']?.toString() ?? '0') ?? 0;
    final title = book['title']?.toString() ?? 'Livre';

    setState(() {
      _downloadedBookIds.add(bookId);
    });
    await _repo.markBookDownloaded(bookId, 'local/books/$bookId.pdf');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📥 "$title" mis en cache hors-ligne avec succès !'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openDigitalDocument(Map<String, dynamic> book) async {
    final fileUrl = book['fileUrl']?.toString();
    if (fileUrl != null && fileUrl.isNotEmpty) {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      _showReaderDialog(book);
    }
  }

  void _showReaderDialog(Map<String, dynamic> book) {
    final title = book['title']?.toString() ?? 'Document Numérique';
    final author = book['author']?.toString() ?? 'Auteur inconnu';
    final description = book['description']?.toString() ?? 'Aucun résumé disponible pour ce document.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chrome_reader_mode_rounded, color: Color(0xFF2563EB), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Auteur : $author', style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                description,
                style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.lock_clock_rounded, size: 16, color: Color(0xFF059669)),
                SizedBox(width: 6),
                Text('Accès instantané & sécurisé', style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📖 Visualisation du flux de lecture sécurisé activée.'),
                  backgroundColor: Color(0xFF2563EB),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.book_online_rounded, size: 18),
            label: const Text('Consulter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Document Details & QR Code Shelf Locator Modal ---
  void _openBookDetailsModal(Map<String, dynamic> book) {
    final title = book['title']?.toString() ?? 'Ouvrage';
    final author = book['author']?.toString() ?? 'Auteur inconnu';
    final category = book['category']?.toString() ?? 'Général';
    final description = book['description']?.toString() ?? 'Aucune description disponible pour cet ouvrage.';
    final isbn = book['isbn']?.toString() ?? 'N/A';
    final shelfLocation = book['shelfLocation']?.toString() ?? 'Rayon Central';
    final isDigital = book['isDigital'] == 'true' || book['isDigital'] == true || book['fileUrl'] != null;
    final totalQty = book['totalQuantity'] is int ? book['totalQuantity'] as int : int.tryParse(book['totalQuantity']?.toString() ?? '1') ?? 1;
    final availQty = book['availableQuantity'] is int ? book['availableQuantity'] as int : int.tryParse(book['availableQuantity']?.toString() ?? '1') ?? 1;
    final isAvailable = isDigital || availQty > 0;
    final bookId = book['id'] is int ? book['id'] as int : int.tryParse(book['id']?.toString() ?? '0') ?? 0;
    final qrData = 'EDUT-DOC-$bookId-$isbn';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header Row with 3D Book Spine Cover
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: _getCategoryGradient(category),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(2, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 6,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 3,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        Center(
                          child: Icon(
                            isDigital ? Icons.menu_book_rounded : Icons.local_library_rounded,
                            color: Colors.amber.shade300,
                            size: 38,
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDigital ? const Color(0xFFEDE9FE) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDigital ? Icons.devices_rounded : Icons.menu_book_rounded,
                                    size: 13,
                                    color: isDigital ? const Color(0xFF6D28D9) : const Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDigital ? 'Numérique (PDF)' : 'Fonds Physique',
                                    style: TextStyle(
                                      color: isDigital ? const Color(0xFF6D28D9) : const Color(0xFFB45309),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isDigital
                                    ? 'Accès Illimité'
                                    : (isAvailable ? '$availQty / $totalQty dispo' : 'Épuisé'),
                                style: TextStyle(
                                  color: isAvailable ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, height: 1.2),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          author,
                          style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Shelf & Physical Location Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDigital ? Icons.cloud_done_rounded : Icons.meeting_room_rounded,
                        color: isDigital ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDigital ? 'Stockage Électronique' : 'Emplacement & Rayonnage',
                            style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shelfLocation,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        'ISBN: $isbn',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Resumé
              const Text(
                'Résumé & Notice Documentaire :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  description,
                  style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),

              // QR Code Card for Shelf finding / Counter borrowing
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 90.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF2563EB)),
                              SizedBox(width: 6),
                              Text(
                                'Fiche QR Code & Rayon',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Présentez ce code aux guichets de la bibliothèque pour validation de prêt ou scan d\'inventaire.',
                            style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            qrData,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (isDigital) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openDigitalDocument(book);
                  },
                  icon: const Icon(Icons.chrome_reader_mode_rounded),
                  label: const Text('Ouvrir & Lire en ligne', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadBook(book);
                  },
                  icon: const Icon(Icons.download_for_offline_outlined, color: Color(0xFF2563EB)),
                  label: const Text('Enregistrer pour lecture hors-ligne', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: isAvailable
                      ? () {
                          Navigator.pop(ctx);
                          _reservePhysicalBook(book);
                        }
                      : null,
                  icon: const Icon(Icons.bookmark_add_rounded),
                  label: Text(
                    isAvailable ? 'Réserver cet exemplaire (3 jours)' : 'Exemplaire actuellement indisponible',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAvailable ? const Color(0xFF059669) : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reservePhysicalBook(Map<String, dynamic> book) async {
    final bookId = book['id'] is int ? book['id'] as int : int.tryParse(book['id']?.toString() ?? '0') ?? 0;
    final title = book['title']?.toString() ?? 'Livre';

    if (_studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter avec un profil élève ou personnel pour réserver.'),
          backgroundColor: Color(0xFFB45309),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final success = await _repo.reserveBook(bookId: bookId, studentId: _studentId!);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Réservation validée pour "$title" ! Retirez-le sous 72h.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadCatalog();
        _loadLoans();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demande de réservation enregistrée pour "$title".'),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final digitalCount = _books.where((b) => b['isDigital'] == 'true' || b['isDigital'] == true || b['fileUrl'] != null).length;
    final physicalCount = _books.where((b) => b['isDigital'] == 'false' || b['isDigital'] == false || (b['fileUrl'] == null && b['isDigital'] != 'true')).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bibliothèque & Centre Doc.',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const Text(
              'Fonds physiques & E-books numériques',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Annales & Épreuves d\'Examens',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_rounded, color: Color(0xFF2563EB), size: 20),
            ),
            onPressed: () => context.push('/library/past-exams'),
          ),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () {
              _loadCatalog();
              _loadLoans();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header Container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              children: [
                // Live Search Box
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadCatalog(),
                  decoration: InputDecoration(
                    hintText: 'Rechercher titre, auteur, ISBN, rayon...',
                    hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadCatalog();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Format Selector Segment Tabs (Tous, Numériques, Physiques, Mes Emprunts)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFormatTab('all', '📚 Tous', _books.length.toString()),
                      const SizedBox(width: 8),
                      _buildFormatTab('digital', '💻 Numériques', digitalCount.toString()),
                      const SizedBox(width: 8),
                      _buildFormatTab('physical', '📖 Fonds Physiques', physicalCount.toString()),
                      const SizedBox(width: 8),
                      _buildFormatTab('loans', '⏳ Mes Emprunts', _loans.length.toString()),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Category Filter Chips (visible for all catalog formats)
                if (_selectedFormat != 'loans')
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = cat == _selectedCategory;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = cat);
                            _loadCatalog();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          // Main View: Catalog List OR Loans List
          Expanded(
            child: _selectedFormat == 'loans'
                ? _buildLoansView()
                : _buildCatalogView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatTab(String key, String label, String count) {
    final isSelected = _selectedFormat == key;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFormat = key);
        if (key != 'loans') {
          _loadCatalog();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Catalog List View ---
  Widget _buildCatalogView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    if (_books.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadCatalog,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.menu_book_rounded, size: 54, color: Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Aucun ouvrage trouvé',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Modifiez vos termes de recherche ou sélectionnez une autre catégorie pour explorer le centre documentaire.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCatalog,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          final book = _books[index];
          final bookId = book['id'] is int ? book['id'] as int : int.tryParse(book['id']?.toString() ?? '0') ?? 0;
          final title = book['title']?.toString() ?? 'Manuel scolaire';
          final author = book['author']?.toString() ?? 'Auteur inconnu';
          final category = book['category']?.toString() ?? 'Général';
          final shelfLocation = book['shelfLocation']?.toString() ?? 'Rayon Central';
          final isDigital = book['isDigital'] == 'true' || book['isDigital'] == true || book['fileUrl'] != null;
          final isDownloaded = _downloadedBookIds.contains(bookId);
          final availQty = book['availableQuantity'] is int ? book['availableQuantity'] as int : int.tryParse(book['availableQuantity']?.toString() ?? '1') ?? 1;
          final totalQty = book['totalQuantity'] is int ? book['totalQuantity'] as int : int.tryParse(book['totalQuantity']?.toString() ?? '1') ?? 1;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3D Book Cover Badge
                GestureDetector(
                  onTap: () => _openBookDetailsModal(book),
                  child: Container(
                    width: 60,
                    height: 86,
                    decoration: BoxDecoration(
                      gradient: _getCategoryGradient(category),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 8,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 4,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2.5,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        Center(
                          child: Icon(
                            isDigital ? Icons.menu_book_rounded : Icons.local_library_rounded,
                            color: Colors.amber.shade300,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDigital ? const Color(0xFFEDE9FE) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isDigital ? Icons.devices_rounded : Icons.menu_book_rounded,
                                  size: 11,
                                  color: isDigital ? const Color(0xFF6D28D9) : const Color(0xFFB45309),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isDigital ? 'Numérique' : 'Rayon Physique',
                                  style: TextStyle(
                                    color: isDigital ? const Color(0xFF6D28D9) : const Color(0xFFB45309),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              category,
                              style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          if (isDownloaded)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7EE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 12),
                                  SizedBox(width: 3),
                                  Text(
                                    'Hors-ligne',
                                    style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.25),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Author & Rayon
                      Text(
                        author,
                        style: const TextStyle(color: Colors.black54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Shelf / Availability Line
                      Row(
                        children: [
                          Icon(
                            isDigital ? Icons.cloud_done_rounded : Icons.location_on_outlined,
                            size: 13,
                            color: isDigital ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isDigital ? 'Accès Immédiat' : shelfLocation,
                              style: TextStyle(
                                color: isDigital ? const Color(0xFF2563EB) : const Color(0xFF475569),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isDigital)
                            Text(
                              '$availQty/$totalQty dispo',
                              style: TextStyle(
                                color: availQty > 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Action Buttons
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _openBookDetailsModal(book),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isDigital ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDigital ? Icons.visibility_rounded : Icons.info_outline_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDigital ? 'Consulter' : 'Fiche & Rayon',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isDigital) ...[
                            if (!isDownloaded)
                              IconButton(
                                icon: const Icon(Icons.download_for_offline_outlined, color: Colors.black54, size: 20),
                                tooltip: 'Télécharger pour lecture hors-ligne',
                                onPressed: () => _downloadBook(book),
                              ),
                          ] else ...[
                            if (availQty > 0)
                              InkWell(
                                onTap: () => _reservePhysicalBook(book),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bookmark_add_outlined, color: Color(0xFF059669), size: 13),
                                      SizedBox(width: 4),
                                      Text(
                                        'Réserver',
                                        style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Loans & Reservations View ---
  Widget _buildLoansView() {
    if (_loans.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadLoans();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bookmark_added_rounded, size: 54, color: Color(0xFFD97706)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucun prêt ou réservation en cours',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Consultez les fonds physiques du catalogue et réservez des manuels scolaires à retirer au centre documentaire.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _selectedFormat = 'physical');
                  _loadCatalog();
                },
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Explorer les fonds physiques'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadLoans();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _loans.length,
        itemBuilder: (context, index) {
          final loan = _loans[index];
          final bookInfo = loan['library_books'] as Map<String, dynamic>?;
          final title = bookInfo?['title']?.toString() ?? loan['title']?.toString() ?? 'Ouvrage emprunté';
          final author = bookInfo?['author']?.toString() ?? loan['author']?.toString() ?? 'Auteur inconnu';
          final issueDate = loan['issue_date']?.toString().split('T').first ?? 'Date inconnue';
          final dueDate = loan['due_date']?.toString().split('T').first ?? 'Non définie';
          final status = (loan['status']?.toString() ?? 'Emprunté').trim();

          Color statusColor = const Color(0xFF2563EB);
          Color statusBg = const Color(0xFFEFF6FF);
          if (status.toLowerCase().contains('retour') || status.toLowerCase() == 'returned') {
            statusColor = const Color(0xFF059669);
            statusBg = const Color(0xFFECFDF5);
          } else if (status.toLowerCase().contains('retard') || status.toLowerCase() == 'overdue') {
            statusColor = const Color(0xFFDC2626);
            statusBg = const Color(0xFFFEF2F2);
          } else if (status.toLowerCase().contains('reserv') || status.toLowerCase() == 'reservation') {
            statusColor = const Color(0xFFD97706);
            statusBg = const Color(0xFFFFFBEB);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.date_range_rounded, size: 14, color: Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      'Prêté le: $issueDate',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  author,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.alarm_on_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Text(
                      'Date limite de retour : $dueDate',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
