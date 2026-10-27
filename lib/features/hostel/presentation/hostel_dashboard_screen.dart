import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/hostel_repository.dart';

class HostelDashboardScreen extends StatefulWidget {
  const HostelDashboardScreen({super.key});

  @override
  State<HostelDashboardScreen> createState() => _HostelDashboardScreenState();
}

class _HostelDashboardScreenState extends State<HostelDashboardScreen>
    with SingleTickerProviderStateMixin {
  final HostelRepository _repository = locator<HostelRepository>();
  final TextEditingController _residentSearchController =
      TextEditingController();
  final TextEditingController _roomSearchController = TextEditingController();

  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _canManageHostel = false;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _allocations = [];
  List<Map<String, dynamic>> _filteredAllocations = [];
  List<Map<String, dynamic>> _filteredRooms = [];
  String _residentStatusFilter = 'Tous';
  String _roomTypeFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _residentSearchController.dispose();
    _roomSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await locator<PermissionService>().getCurrentProfile();
    setState(() => _isLoading = true);
    final rooms = await _repository.getRooms();
    final allocations = await _repository.getAllocations();

    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _allocations = allocations;
      _canManageHostel =
          profile.permissions.contains(AppPermissions.hostelManage);
      _isLoading = false;
    });
    _applyResidentSearch();
    _applyRoomFilters();
  }

  void _applyResidentSearch() {
    final query = _residentSearchController.text.trim().toLowerCase();
    final filtered = _allocations.where((allocation) {
      final student = allocation['students'] as Map<String, dynamic>?;
      final room = allocation['hostel_rooms'] as Map<String, dynamic>?;
      final name = (student?['nom_etudiant'] ?? '').toString().toLowerCase();
      final matricule =
          (student?['num_admission'] ?? '').toString().toLowerCase();
      final roomNumber =
          (room?['room_number'] ?? '').toString().toLowerCase();
      return query.isEmpty ||
          name.contains(query) ||
          matricule.contains(query) ||
          roomNumber.contains(query);
    }).where((allocation) {
      final status = (allocation['status'] ?? '').toString().toLowerCase();
      return _residentStatusFilter == 'Tous' ||
          (_residentStatusFilter == 'Occupes' && status.contains('occup')) ||
          (_residentStatusFilter == 'Liberes' && status.contains('lib'));
    }).toList();

    setState(() => _filteredAllocations = filtered);
  }

  void _applyRoomFilters() {
    final query = _roomSearchController.text.trim().toLowerCase();
    final filtered = _rooms.where((room) {
      final roomNumber = (room['room_number'] ?? '').toString().toLowerCase();
      final building = (room['building_name'] ?? '').toString().toLowerCase();
      final type = (room['room_type'] ?? '').toString().toLowerCase();
      final matchesQuery =
          query.isEmpty || roomNumber.contains(query) || building.contains(query);
      final matchesType = _roomTypeFilter == 'Tous' ||
          type == _roomTypeFilter.toLowerCase();
      return matchesQuery && matchesType;
    }).toList();

    setState(() => _filteredRooms = filtered);
  }

  int get _totalCapacity => _rooms.fold<int>(
        0,
        (sum, room) => sum + ((room['capacity'] as num?)?.toInt() ?? 0),
      );

  int get _occupiedBeds => _rooms.fold<int>(
        0,
        (sum, room) => sum + ((room['occupied_beds'] as num?)?.toInt() ?? 0),
      );

  int get _availableBeds => _totalCapacity - _occupiedBeds;

  Future<void> _openRoomForm([Map<String, dynamic>? room]) async {
    final roomNumberController =
        TextEditingController(text: room?['room_number']?.toString() ?? '');
    final buildingController =
        TextEditingController(text: room?['building_name']?.toString() ?? '');
    final capacityController = TextEditingController(
      text: ((room?['capacity'] as num?)?.toInt() ?? '').toString(),
    );
    var roomType = (room?['room_type'] ?? 'Mixte').toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room == null ? 'Ajouter une chambre' : 'Modifier la chambre',
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 16),
                      _textField('Numero de chambre', roomNumberController),
                      const SizedBox(height: 10),
                      _textField('Batiment', buildingController),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: roomType,
                        items: const ['Mixte', 'Garcons', 'Filles', 'Staff']
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() => roomType = value ?? 'Mixte');
                        },
                        decoration: _inputDecoration('Type de chambre'),
                      ),
                      const SizedBox(height: 10),
                      _textField(
                        'Capacite',
                        capacityController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  setState(() => _isSaving = true);
                                  final result = await _repository.saveRoom(
                                    roomId: room?['id'] as int?,
                                    payload: {
                                      'room_number': roomNumberController.text.trim(),
                                      'building_name': buildingController.text.trim(),
                                      'room_type': roomType,
                                      'capacity': int.tryParse(
                                            capacityController.text.trim(),
                                          ) ??
                                          0,
                                      if (room == null) 'occupied_beds': 0,
                                    },
                                  );
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  _showMessage(
                                    result['success'] == true
                                        ? 'Chambre enregistree.'
                                        : (result['error']?.toString() ??
                                            'Erreur enregistrement'),
                                  );
                                  if (result['success'] == true) {
                                    await _load();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            _isSaving ? 'Enregistrement...' : 'Enregistrer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAllocationForm() async {
    final students = await _repository.getAvailableStudents();
    if (!mounted) return;
    if (students.isEmpty || _rooms.isEmpty) {
      _showMessage('Aucun eleve disponible ou aucune chambre disponible.');
      return;
    }

    int? selectedStudentId = students.first['id'] as int?;
    int? selectedRoomId = _rooms.isNotEmpty ? _rooms.first['id'] as int? : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loger un eleve', style: AppTextStyles.heading2),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: selectedStudentId,
                      items: students
                          .map(
                            (student) => DropdownMenuItem<int>(
                              value: student['id'] as int,
                              child: Text(
                                '${student['nom_etudiant']} - ${student['classe'] ?? '-'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() => selectedStudentId = value);
                      },
                      decoration: _inputDecoration('Eleve'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: selectedRoomId,
                      items: _rooms
                          .where(
                            (room) =>
                                ((room['occupied_beds'] as num?)?.toInt() ?? 0) <
                                ((room['capacity'] as num?)?.toInt() ?? 0),
                          )
                          .map(
                            (room) => DropdownMenuItem<int>(
                              value: room['id'] as int,
                              child: Text(
                                'Chambre ${room['room_number']} - ${room['building_name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() => selectedRoomId = value);
                      },
                      decoration: _inputDecoration('Chambre'),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                if (selectedStudentId == null ||
                                    selectedRoomId == null) {
                                  _showMessage('Selection incomplete.');
                                  return;
                                }
                                setState(() => _isSaving = true);
                                final result = await _repository.allocateStudent(
                                  studentId: selectedStudentId!,
                                  roomId: selectedRoomId!,
                                );
                                if (!mounted) return;
                                setState(() => _isSaving = false);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                                _showMessage(
                                  result['success'] == true
                                      ? 'Affectation reussie.'
                                      : (result['error']?.toString() ??
                                          'Erreur affectation'),
                                );
                                if (result['success'] == true) {
                                  await _load();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(_isSaving ? 'Traitement...' : 'Confirmer'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _vacateAllocation(int allocationId) async {
    final result = await _repository.vacateAllocation(allocationId);
    if (!mounted) return;
    _showMessage(
      result['success'] == true
          ? 'Affectation liberee.'
          : (result['error']?.toString() ?? 'Erreur liberation'),
    );
    if (result['success'] == true) {
      await _load();
    }
  }

  Future<void> _deleteRoom(int roomId) async {
    final result = await _repository.deleteRoom(roomId);
    if (!mounted) return;
    _showMessage(
      result['success'] == true
          ? 'Chambre supprimee.'
          : (result['error']?.toString() ?? 'Erreur suppression'),
    );
    if (result['success'] == true) {
      await _load();
    }
  }

  void _showRoomDetails(Map<String, dynamic> room) {
    final roomId = room['id'] as int?;
    final roomResidents = roomId == null
        ? <Map<String, dynamic>>[]
        : _allocations.where((allocation) {
            final linkedRoom = allocation['hostel_rooms'] as Map<String, dynamic>?;
            return linkedRoom?['id'] == roomId;
          }).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chambre ${room['room_number'] ?? '-'}',
                        style: AppTextStyles.heading2,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  '${room['building_name'] ?? '-'} • ${room['room_type'] ?? 'Mixte'}',
                  style: AppTextStyles.body.copyWith(color: AppColors.slate500),
                ),
                const SizedBox(height: 12),
                Text(
                  'Occupation: ${(room['occupied_beds'] ?? 0)} / ${(room['capacity'] ?? 0)}',
                  style: AppTextStyles.bodyBold,
                ),
                const SizedBox(height: 16),
                Text('Residents', style: AppTextStyles.heading3),
                const SizedBox(height: 10),
                if (roomResidents.isEmpty)
                  Text(
                    'Aucun resident dans cette chambre.',
                    style: AppTextStyles.body,
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: roomResidents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final allocation = roomResidents[index];
                        final student = allocation['students'] as Map<String, dynamic>?;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFEBF0F5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (student?['nom_etudiant'] ?? 'Eleve').toString(),
                                      style: AppTextStyles.bodyBold,
                                    ),
                                    Text(
                                      '${student?['num_admission'] ?? '-'} - ${student?['classe'] ?? '-'}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                if (_canManageHostel)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _openRoomForm(room);
                          },
                          child: const Text('Modifier'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: roomResidents.isNotEmpty
                              ? null
                              : () async {
                                  Navigator.of(context).pop();
                                  await _deleteRoom(room['id'] as int);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Supprimer'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        title: const Text('Internat & Dortoirs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Residents'),
            Tab(text: 'Chambres'),
          ],
        ),
      ),
      floatingActionButton: _canManageHostel
          ? FloatingActionButton.extended(
              onPressed: () {
                if (_tabController.index == 0) {
                  _openAllocationForm();
                } else {
                  _openRoomForm();
                }
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: Icon(
                _tabController.index == 0
                    ? Icons.person_add_alt
                    : Icons.add_home_work,
              ),
              label: Text(_tabController.index == 0 ? 'Loger' : 'Chambre'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      children: [
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.1,
                          children: [
                            _statCard('Chambres', '${_rooms.length}', Icons.apartment),
                            _statCard('Capacite', '$_totalCapacity', Icons.bed_rounded),
                            _statCard('Disponibles', '$_availableBeds', Icons.door_sliding),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _residentSearchController,
                          onChanged: (_) => _applyResidentSearch(),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un resident ou une chambre',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFFEBF0F5),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFFEBF0F5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            children: ['Tous', 'Occupes', 'Liberes']
                                .map(
                                  (filter) => ChoiceChip(
                                    label: Text(filter),
                                    selected: _residentStatusFilter == filter,
                                    onSelected: (_) {
                                      setState(
                                        () => _residentStatusFilter = filter,
                                      );
                                      _applyResidentSearch();
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildResidentsTab(),
                        _buildRoomsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildResidentsTab() {
    if (_filteredAllocations.isEmpty) {
      return _emptyState('Aucun resident trouve.');
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _filteredAllocations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final allocation = _filteredAllocations[index];
        final student = allocation['students'] as Map<String, dynamic>?;
        final room = allocation['hostel_rooms'] as Map<String, dynamic>?;
        final isOccupied = (allocation['status'] ?? '')
            .toString()
            .toLowerCase()
            .contains('occup');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEBF0F5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (student?['nom_etudiant'] ?? 'Eleve').toString(),
                          style: AppTextStyles.bodyBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${student?['num_admission'] ?? '-'} - ${student?['classe'] ?? '-'}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  _statusChip(isOccupied ? 'Occupe' : 'Libere', isOccupied),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Chambre ${room?['room_number'] ?? '-'} - ${room?['building_name'] ?? '-'}',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 6),
              Text(
                'Entree: ${_formatDate(allocation['join_date'])}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 12),
              if (isOccupied && _canManageHostel)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _vacateAllocation(allocation['id'] as int),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Liberer'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoomsTab() {
    if (_filteredRooms.isEmpty) {
      return _emptyState('Aucune chambre enregistree.');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            children: [
              TextField(
                controller: _roomSearchController,
                onChanged: (_) => _applyRoomFilters(),
                decoration: InputDecoration(
                  hintText: 'Rechercher une chambre ou un batiment',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: ['Tous', 'Mixte', 'Garcons', 'Filles', 'Staff']
                      .map(
                        (filter) => ChoiceChip(
                          label: Text(filter),
                          selected: _roomTypeFilter == filter,
                          onSelected: (_) {
                            setState(() => _roomTypeFilter = filter);
                            _applyRoomFilters();
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisSpacing: 14,
              childAspectRatio: 1.45,
            ),
            itemCount: _filteredRooms.length,
            itemBuilder: (context, index) {
              final room = _filteredRooms[index];
              final occupied = (room['occupied_beds'] as num?)?.toInt() ?? 0;
              final capacity = (room['capacity'] as num?)?.toInt() ?? 0;
              final ratio = capacity == 0 ? 0.0 : occupied / capacity;

              return InkWell(
                onTap: () => _showRoomDetails(room),
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFEBF0F5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chambre ${room['room_number'] ?? '-'}',
                                  style: AppTextStyles.heading3,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (room['building_name'] ?? '-').toString(),
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          _typeChip((room['room_type'] ?? 'Mixte').toString()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Occupation: $occupied / $capacity',
                        style: AppTextStyles.bodyBold,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFEEF2FF),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ratio >= 1 ? AppColors.danger : AppColors.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Disponibles: ${capacity - occupied < 0 ? 0 : capacity - occupied} lits',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showRoomDetails(room),
                            child: const Text('Details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.heading3),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_work_outlined, size: 48, color: AppColors.slate400),
            const SizedBox(height: 14),
            Text(message, style: AppTextStyles.heading3, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, bool occupied) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: occupied ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: occupied ? const Color(0xFF059669) : AppColors.slate500,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _typeChip(String text) {
    final lower = text.toLowerCase();
    final color = lower.contains('fille')
        ? const Color(0xFFDB2777)
        : lower.contains('gar')
            ? const Color(0xFF2563EB)
            : const Color(0xFF7C3AED);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEBF0F5)),
      ),
    );
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }
}
