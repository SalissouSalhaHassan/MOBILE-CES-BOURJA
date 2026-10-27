import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/api/mobile_api_client.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/offline_queue_manager.dart';
import '../../../core/api/sync_engine.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';

class PedagogieRepository {
  final SupabaseClient _client;
  final MobileApiClient _apiClient;

  PedagogieRepository({SupabaseClient? client, MobileApiClient? apiClient})
      : _client = client ?? SupabaseClientManager().client,
        _apiClient = apiClient ?? locator<MobileApiClient>();

  static const _selectFields =
      'id, class_id, subject_id, employee_id, session_date, heure_debut, heure_fin, '
      'titre_lecon, objectifs, contenu_realise, supports_utilises, devoir_donne, '
      'observation, statut, valide_par_id, valide_at, annee_scolaire, created_at, updated_at, '
      'school_classes(class_name), school_subjects(subject_name)';

  // ─── Fetch séances (cahier de textes) ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSeances({
    int? classId,
    int? subjectId,
    String? statut,
    String? dateDebut,
    String? dateFin,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "cahier_textes_${classId}_${subjectId}_$statut";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching cahier de textes from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
    }

    // 1. Try Backend API
    try {
      final queryParams = <String>[];
      if (classId != null) queryParams.add('classId=$classId');
      if (subjectId != null) queryParams.add('subjectId=$subjectId');
      if (statut != null && statut.isNotEmpty) queryParams.add('statut=$statut');

      final url = '/api/mobile/pedagogie/cahier-textes${queryParams.isNotEmpty ? '?${queryParams.join('&')}' : ''}';
      final res = await _apiClient.getJson(url);
      if (res['success'] == true && res['data'] != null) {
        final list = List<Map<String, dynamic>>.from(res['data']);
        await cacheManager.saveDataList(
          boxName: OfflineStoreManager.boxStudents,
          key: cacheKey,
          data: list,
        );
        return list;
      }
    } catch (e) {
      debugPrint('API getSeances failed, falling back to Supabase: $e');
    }

    // 2. Supabase fallback
    try {
      final session = locator<SessionManager>();
      final employeeIdStr = await session.getEmployeeId();
      final role = (await session.getRole() ?? 'staff').toLowerCase();
      final isTeacher = role.contains('teacher') ||
          role.contains('enseignant') ||
          role.contains('professeur');

      var q = _client.from('cahier_textes').select(_selectFields);

      List<dynamic> result;

      if (isTeacher) {
        final employeeId = int.tryParse(employeeIdStr ?? '');
        if (employeeId != null) {
          var filtered = q.eq('employee_id', employeeId);
          if (classId != null) filtered = filtered.eq('class_id', classId);
          if (subjectId != null) filtered = filtered.eq('subject_id', subjectId);
          if (statut != null && statut.isNotEmpty) {
            filtered = filtered.eq('statut', statut);
          }
          if (dateDebut != null && dateDebut.isNotEmpty) {
            filtered = filtered.gte('session_date', dateDebut);
          }
          if (dateFin != null && dateFin.isNotEmpty) {
            filtered = filtered.lte('session_date', dateFin);
          }
          result = await filtered.order('session_date', ascending: false);
        } else {
          result = await q.order('session_date', ascending: false);
        }
      } else {
        var filtered = q;
        if (classId != null) filtered = filtered.eq('class_id', classId);
        if (subjectId != null) filtered = filtered.eq('subject_id', subjectId);
        if (statut != null && statut.isNotEmpty) {
          filtered = filtered.eq('statut', statut);
        }
        if (dateDebut != null && dateDebut.isNotEmpty) {
          filtered = filtered.gte('session_date', dateDebut);
        }
        if (dateFin != null && dateFin.isNotEmpty) {
          filtered = filtered.lte('session_date', dateFin);
        }
        result = await filtered.order('session_date', ascending: false);
      }

      final list = List<Map<String, dynamic>>.from(result);
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: list,
      );
      return list;
    } catch (e) {
      debugPrint('PedagogieRepository.getSeances error, loading cache: $e');
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
    }
  }

  // ─── Fetch classes & subjects for current teacher / director ─────────────
  Future<List<Map<String, dynamic>>> getTeacherClassesAndSubjects() async {
    final cacheManager = locator<OfflineStoreManager>();
    const cacheKey = "teacher_classes_and_subjects";

    try {
      final session = locator<SessionManager>();
      final employeeIdStr = await session.getEmployeeId();
      final employeeId = int.tryParse(employeeIdStr ?? '');

      String endpoint = '/api/mobile/academics?action=getTeacherClassesAndSubjects';
      if (employeeId != null && employeeId > 0) {
        endpoint += '&employeeId=$employeeId';
      }

      try {
        final res = await _apiClient.getJson(endpoint);
        final list = (res['data'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        if (list.isNotEmpty) {
          await cacheManager.saveDataList(
            boxName: OfflineStoreManager.boxStudents,
            key: cacheKey,
            data: list,
          );
          return list;
        }
      } catch (_) {}

      // Fallback: fetch all classes & subjects
      try {
        final allRes = await _apiClient.getJson('/api/mobile/academics?action=getAllClassesAndSubjects');
        final list = (allRes['data'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        if (list.isNotEmpty) {
          await cacheManager.saveDataList(
            boxName: OfflineStoreManager.boxStudents,
            key: cacheKey,
            data: list,
          );
          return list;
        }
      } catch (_) {}

      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
    } catch (e) {
      debugPrint('PedagogieRepository.getTeacherClassesAndSubjects error: $e');
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
    }
  }

  // ─── CREATE séance ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createSeance({
    required int classId,
    required int subjectId,
    required int employeeId,
    required String sessionDate,
    required String titreLecon,
    String? heureDebut,
    String? heureFin,
    String? objectifs,
    String? contenuRealise,
    String? supportsUtilises,
    String? devoirDonne,
    String? observation,
    String? anneeScolaire,
  }) async {
    final payload = <String, dynamic>{
      'classId': classId,
      'subjectId': subjectId,
      'employeeId': employeeId,
      'sessionDate': sessionDate,
      'titreLecon': titreLecon,
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'objectifs': objectifs,
      'contenuRealise': contenuRealise,
      'supportsUtilises': supportsUtilises,
      'devoirDonne': devoirDonne,
      'observation': observation,
      'statut': 'Brouillon',
      'anneeScolaire': anneeScolaire ?? '2025-2026',
    };

    final syncEngine = locator<SyncEngine>();
    final queueManager = locator<OfflineQueueManager>();

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Enqueuing createSeance locally.");
      await queueManager.enqueue(
        table: 'cahier_textes',
        action: 'create_seance',
        data: payload,
      );
      return {
        'id': DateTime.now().millisecondsSinceEpoch,
        ...payload,
        'created_at': DateTime.now().toIso8601String(),
        '_isOffline': true,
      };
    }

    // 1. Try Backend API (Bypasses Postgres Client RLS)
    try {
      final res = await _apiClient.postJson(
        '/api/mobile/pedagogie/cahier-textes',
        payload,
      );
      if (res['success'] == true && res['data'] != null) {
        return Map<String, dynamic>.from(res['data']);
      }
    } catch (e) {
      debugPrint('API createSeance failed, falling back to Supabase: $e');
    }

    // 2. Supabase fallback
    try {
      final session = locator<SessionManager>();
      final schoolIdStr = await session.getSchoolId();
      final schoolId = int.tryParse(schoolIdStr ?? '');

      final data = <String, dynamic>{
        'class_id': classId,
        'subject_id': subjectId,
        'employee_id': employeeId,
        'session_date': sessionDate,
        'titre_lecon': titreLecon,
        'statut': 'Brouillon',
      };

      if (schoolId != null) data['school_id'] = schoolId;
      if (heureDebut != null && heureDebut.isNotEmpty) data['heure_debut'] = heureDebut;
      if (heureFin != null && heureFin.isNotEmpty) data['heure_fin'] = heureFin;
      if (objectifs != null && objectifs.isNotEmpty) data['objectifs'] = objectifs;
      if (contenuRealise != null && contenuRealise.isNotEmpty) data['contenu_realise'] = contenuRealise;
      if (supportsUtilises != null && supportsUtilises.isNotEmpty) data['supports_utilises'] = supportsUtilises;
      if (devoirDonne != null && devoirDonne.isNotEmpty) data['devoir_donne'] = devoirDonne;
      if (observation != null && observation.isNotEmpty) data['observation'] = observation;
      if (anneeScolaire != null && anneeScolaire.isNotEmpty) data['annee_scolaire'] = anneeScolaire;

      final List<dynamic> response =
          await _client.from('cahier_textes').insert(data).select();

      return Map<String, dynamic>.from(response.first as Map);
    } catch (e) {
      debugPrint('PedagogieRepository.createSeance error -> Enqueueing offline: $e');
      await queueManager.enqueue(
        table: 'cahier_textes',
        action: 'create_seance',
        data: payload,
      );
      return {
        'id': DateTime.now().millisecondsSinceEpoch,
        ...payload,
        'created_at': DateTime.now().toIso8601String(),
        '_isOffline': true,
      };
    }
  }

  // ─── UPDATE séance ─────────────────────────────────────────────────────────
  Future<void> updateSeance(
    int id, {
    String? titreLecon,
    String? sessionDate,
    String? heureDebut,
    String? heureFin,
    String? objectifs,
    String? contenuRealise,
    String? supportsUtilises,
    String? devoirDonne,
    String? observation,
    String? statut,
  }) async {
    final payload = <String, dynamic>{
      'id': id,
      if (titreLecon != null) 'titreLecon': titreLecon,
      if (sessionDate != null) 'sessionDate': sessionDate,
      if (heureDebut != null) 'heureDebut': heureDebut,
      if (heureFin != null) 'heureFin': heureFin,
      if (objectifs != null) 'objectifs': objectifs,
      if (contenuRealise != null) 'contenuRealise': contenuRealise,
      if (supportsUtilises != null) 'supportsUtilises': supportsUtilises,
      if (devoirDonne != null) 'devoirDonne': devoirDonne,
      if (observation != null) 'observation': observation,
      if (statut != null) 'statut': statut,
    };

    final syncEngine = locator<SyncEngine>();
    final queueManager = locator<OfflineQueueManager>();

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Enqueuing updateSeance locally.");
      await queueManager.enqueue(
        table: 'cahier_textes',
        action: 'update_seance',
        data: payload,
      );
      return;
    }

    // 1. Try Backend API
    try {
      final res = await _apiClient.putJson(
        '/api/mobile/pedagogie/cahier-textes',
        payload,
      );
      if (res['success'] == true) return;
    } catch (e) {
      debugPrint('API updateSeance failed, falling back to Supabase: $e');
    }

    // 2. Supabase fallback
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (titreLecon != null) data['titre_lecon'] = titreLecon;
      if (sessionDate != null) data['session_date'] = sessionDate;
      if (heureDebut != null) data['heure_debut'] = heureDebut;
      if (heureFin != null) data['heure_fin'] = heureFin;
      if (objectifs != null) data['objectifs'] = objectifs;
      if (contenuRealise != null) data['contenu_realise'] = contenuRealise;
      if (supportsUtilises != null) data['supports_utilises'] = supportsUtilises;
      if (devoirDonne != null) data['devoir_donne'] = devoirDonne;
      if (observation != null) data['observation'] = observation;
      if (statut != null) data['statut'] = statut;

      await _client.from('cahier_textes').update(data).eq('id', id);
    } catch (e) {
      debugPrint('PedagogieRepository.updateSeance error -> Enqueueing offline: $e');
      await queueManager.enqueue(
        table: 'cahier_textes',
        action: 'update_seance',
        data: payload,
      );
    }
  }

  // ─── SUBMIT séance (Brouillon → Soumis) ───────────────────────────────────
  Future<void> submitSeance(int id) async {
    await updateSeance(id, statut: 'Soumis');
  }

  // ─── DELETE séance ─────────────────────────────────────────────────────────
  Future<void> deleteSeance(int id) async {
    // 1. Try Backend API
    try {
      final res = await _apiClient.deleteJson('/api/mobile/pedagogie/cahier-textes?id=$id');
      if (res['success'] == true) return;
    } catch (e) {
      debugPrint('API deleteSeance failed, falling back to Supabase: $e');
    }

    // 2. Supabase fallback
    try {
      await _client.from('cahier_textes').delete().eq('id', id);
    } catch (e) {
      debugPrint('PedagogieRepository.deleteSeance error: $e');
      rethrow;
    }
  }
}
