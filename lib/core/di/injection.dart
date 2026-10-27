import 'package:get_it/get_it.dart';
import '../api/supabase_client.dart';
import '../api/mobile_api_client.dart';
import '../api/offline_store_manager.dart';
import '../api/offline_queue_manager.dart';
import '../api/sync_engine.dart';
import '../auth/session_manager.dart';
import '../services/permission_service.dart';
import '../permissions/permission_service.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/attendance/data/attendance_repository.dart';
import '../../features/academics/data/academics_repository.dart';
import '../../features/family/data/family_repository.dart';
import '../../features/finance/data/finance_repository.dart';
import '../../features/exams/data/exams_repository.dart';
import '../../features/students/data/students_repository.dart';
import '../../features/hostel/data/hostel_repository.dart';
import '../../features/hr/data/hr_repository.dart';
import '../../features/hr/data/director_repository.dart';
import '../../features/owner/data/owner_repository.dart';
import '../../features/messaging/data/messaging_repository.dart';
import '../../features/dashboard/data/dashboard_stats_repository.dart';
import '../../features/ministry/data/ministry_repository.dart';
import '../../features/ai/data/ai_repository.dart';
import '../../features/teacher/data/teacher_repository.dart';
import '../../features/pedagogie/data/pedagogie_repository.dart';
import '../../features/pedagogie/data/planification_repository.dart';
import '../../features/health/data/health_repository.dart';
import '../../features/discipline/data/discipline_repository.dart';
import '../../features/admissions/data/admissions_repository.dart';
import '../../features/transport/data/transport_repository.dart';
import '../../features/canteen/data/canteen_repository.dart';
import '../../features/security/data/gate_security_repository.dart';
import '../../features/library/data/library_repository.dart';
import '../services/push_notification_service.dart';
import '../services/inactivity_lock_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/media_queue_service.dart';

final locator = GetIt.instance;
final getIt = locator;

Future<void> setupLocator() async {
  // Register BiometricAuthService
  locator.registerLazySingleton<BiometricAuthService>(() => BiometricAuthService());

  // Register Supabase client manager
  final supabaseManager = SupabaseClientManager();
  await supabaseManager.init();
  locator.registerSingleton<SupabaseClientManager>(supabaseManager);

  locator.registerLazySingleton<MobileApiClient>(
    () => MobileApiClient(supabaseClient: supabaseManager.client),
  );

  // Register OfflineStoreManager
  final offlineStore = OfflineStoreManager();
  await offlineStore.init();
  locator.registerSingleton<OfflineStoreManager>(offlineStore);

  // Register OfflineQueueManager
  final offlineQueue = OfflineQueueManager();
  await offlineQueue.init();
  locator.registerSingleton<OfflineQueueManager>(offlineQueue);

  // Register MediaQueueService
  final mediaQueue = MediaQueueService();
  await mediaQueue.init();
  locator.registerSingleton<MediaQueueService>(mediaQueue);

  // Register SyncEngine
  locator.registerLazySingleton<SyncEngine>(
    () =>
        SyncEngine(client: supabaseManager.client, queueManager: offlineQueue),
  );

  // Register SessionManager
  locator.registerLazySingleton<SessionManager>(() => SessionManager());

  // Register device permission service
  locator.registerLazySingleton<DevicePermissionService>(
    () => DevicePermissionService(),
  );

  // Register app permission service
  locator.registerLazySingleton<PermissionService>(
    () => PermissionService(sessionManager: locator<SessionManager>()),
  );

  // Register AuthRepository
  locator.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      client: supabaseManager.client,
      sessionManager: locator<SessionManager>(),
      mobileApiClient: locator<MobileApiClient>(),
    ),
  );

  // Register AttendanceRepository
  locator.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepository(client: supabaseManager.client),
  );

  // Register AcademicsRepository
  locator.registerLazySingleton<AcademicsRepository>(
    () => AcademicsRepository(client: supabaseManager.client),
  );

  locator.registerLazySingleton<FamilyRepository>(
    () => FamilyRepository(client: supabaseManager.client),
  );

  locator.registerLazySingleton<StudentsRepository>(
    () => StudentsRepository(client: supabaseManager.client),
  );

  locator.registerLazySingleton<ExamsRepository>(
    () => ExamsRepository(apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<HostelRepository>(
    () => HostelRepository(client: supabaseManager.client, apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<HrRepository>(
    () => HrRepository(client: supabaseManager.client),
  );

  locator.registerLazySingleton<OwnerRepository>(
    () => OwnerRepository(client: supabaseManager.client),
  );

  locator.registerLazySingleton<MessagingRepository>(
    () => MessagingRepository(apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<DashboardStatsRepository>(
    () => DashboardStatsRepository(apiClient: locator<MobileApiClient>()),
  );

  // Register FinanceRepository
  locator.registerLazySingleton<FinanceRepository>(
    () => FinanceRepository(client: supabaseManager.client),
  );

  locator.registerLazySingleton<MinistryRepository>(
    () => MinistryRepository(apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<AiRepository>(
    () => AiRepository(apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<TeacherRepository>(
    () => TeacherRepository(apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<DirectorRepository>(
    () => DirectorRepository(apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<PedagogieRepository>(
    () => PedagogieRepository(client: supabaseManager.client, apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<PlanificationRepository>(
    () => PlanificationRepository(client: supabaseManager.client, apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<HealthRepository>(
    () => HealthRepository(apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<DisciplineRepository>(
    () => DisciplineRepository(apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<AdmissionsRepository>(
    () => AdmissionsRepository(apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<TransportRepository>(
    () => TransportRepository(client: supabaseManager.client, apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<CanteenRepository>(
    () => CanteenRepository(client: supabaseManager.client, apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<MobilePushNotificationService>(
    () => MobilePushNotificationService(repository: locator<MessagingRepository>()),
  );

  locator.registerLazySingleton<InactivityLockService>(
    () => InactivityLockService(),
  );

  locator.registerLazySingleton<GateSecurityRepository>(
    () => GateSecurityRepository(apiClient: locator<MobileApiClient>()),
  );

  locator.registerLazySingleton<LibraryRepository>(
    () => LibraryRepository(apiClient: locator<MobileApiClient>()),
  );
}
