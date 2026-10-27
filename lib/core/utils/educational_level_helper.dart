enum EducationalStage {
  maternelle,
  primaire,
  college,
  lycee,
  universite,
}

class EducationalLevelHelper {
  static const Map<String, List<String>> levelGroups = {
    'maternelle': [
      'maternelle',
      'creche',
      'prescolaire',
      'petite',
      'moyenne',
      'grande',
      'garderie'
    ],
    'primaire': [
      'primaire',
      'elementaire',
      'ci',
      'cp',
      'ce1',
      'ce2',
      'cm1',
      'cm2',
      'sil'
    ],
    'college': [
      'college',
      'moyen',
      'cem',
      '6eme',
      '5eme',
      '4eme',
      '3eme',
      '6e',
      '5e',
      '4e',
      '3e',
      'brevet',
      'bepc',
      'premier cycle'
    ],
    'lycee': [
      'lycee',
      'secondaire',
      '2nde',
      'seconde',
      '1ere',
      'premiere',
      'tle',
      'terminale',
      'bac',
      'scientifique',
      'litteraire',
      'technique',
      'second cycle'
    ],
    'universite': [
      'university',
      'universite',
      'superieur',
      'licence',
      'master',
      'doctorat',
      'lmd',
      'l1',
      'l2',
      'l3',
      'm1',
      'm2',
      'faculte',
      'institut',
      'bts',
      'dut'
    ],
  };

  /// Normalizes level string by removing accents, lowercasing, and trimming
  static String normalizeLevel(String? val) {
    if (val == null) return '';
    var text = val.toLowerCase().trim();
    const withDiacritics = 'àáâãäåèéêëìíîïòóôõöùúûüýñç';
    const withoutDiacritics = 'aaaaaaeeeeiiiiooooouuuuync';
    for (int i = 0; i < withDiacritics.length; i++) {
      text = text.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return text;
  }

  /// Robustly infers canonical educational stage from any combination of
  /// educationalLevel, class name, section name, and filière.
  static EducationalStage inferEducationalStage({
    String? educationalLevel,
    String? className,
    String? sectionName,
    String? filiere,
    EducationalStage defaultStage = EducationalStage.college,
  }) {
    final normLvl = normalizeLevel(educationalLevel);
    final normCls = normalizeLevel(className);
    final normSec = normalizeLevel(sectionName);
    final normFil = normalizeLevel(filiere);
    final fullText = '$normLvl $normCls $normSec $normFil'.trim();

    // 1. University / Supérieur / LMD check
    final univPattern = RegExp(
      r'\b(l[1-3]|m[1-2]|d[1-3]|licence|master|doctorat|bts|dut|deug|faculte|institut|superieur|universite|lmd)\b',
      caseSensitive: false,
    );
    if (univPattern.hasMatch(fullText) ||
        normLvl.contains('universit') ||
        normLvl.contains('superieur') ||
        normLvl.contains('licence') ||
        normLvl.contains('master') ||
        normLvl.contains('doctorat') ||
        normCls.startsWith('l1') ||
        normCls.startsWith('l2') ||
        normCls.startsWith('l3') ||
        normCls.startsWith('m1') ||
        normCls.startsWith('m2')) {
      return EducationalStage.universite;
    }

    // 2. Collège (Middle School: 6ème, 5ème, 4ème, 3ème, BEPC, etc.)
    final collegePattern = RegExp(
      r'\b(6[eè]me?|5[eè]me?|4[eè]me?|3[eè]me?|6e|5e|4e|3e|college|coll[eè]ge|bepc|brevet|cem|moyen)\b',
      caseSensitive: false,
    );
    if (collegePattern.hasMatch(normCls) ||
        collegePattern.hasMatch(normSec) ||
        normLvl.contains('coll') ||
        normLvl.contains('moyen') ||
        normLvl.contains('cem') ||
        normLvl.contains('premier cycle')) {
      return EducationalStage.college;
    }

    // 3. Lycée (High School: 2nde, 1ère, Terminale, BAC, etc.)
    final lyceePattern = RegExp(
      r'\b(2nde?|seconde|1[eè]re?|premiere|premi[eè]re|tle|terminale|lycee|lyc[eè]e|bac)\b',
      caseSensitive: false,
    );
    if (lyceePattern.hasMatch(normCls) ||
        lyceePattern.hasMatch(normSec) ||
        normLvl.contains('lyc') ||
        normLvl.contains('secondaire') ||
        normLvl.contains('second cycle')) {
      return EducationalStage.lycee;
    }

    // 4. Primaire (Elementary: CI, CP, CE1, CE2, CM1, CM2, SIL)
    final primairePattern = RegExp(
      r'\b(ci|cp|cp1|cp2|ce1|ce2|cm1|cm2|sil|cours\s+d.initiation|cours\s+preparatoire|cours\s+elementaire|cours\s+moyen)\b',
      caseSensitive: false,
    );
    final primaireShortPattern = RegExp(
      r'\b(ci|cp|ce1|ce2|cm1|cm2)[a-z0-9]?\b',
      caseSensitive: false,
    );
    if (primairePattern.hasMatch(normCls) ||
        primaireShortPattern.hasMatch(normCls) ||
        primairePattern.hasMatch(normSec) ||
        normLvl.contains('prim') ||
        normLvl.contains('elem')) {
      return EducationalStage.primaire;
    }

    // 5. Maternelle (Preschool / Kindergarten)
    final matPattern = RegExp(
      r'\b(maternelle|creche|prescolaire|garderie|petite\s+section|moyenne\s+section|grande\s+section|ps|ms|gs)\b',
      caseSensitive: false,
    );
    if (matPattern.hasMatch(fullText) ||
        normLvl.contains('mat') ||
        normLvl.contains('creche')) {
      return EducationalStage.maternelle;
    }

    // Fallback checks on educationalLevel
    if (normLvl.isNotEmpty) {
      if (normLvl.contains('coll')) return EducationalStage.college;
      if (normLvl.contains('lyc') || normLvl.contains('sec')) return EducationalStage.lycee;
      if (normLvl.contains('prim')) return EducationalStage.primaire;
      if (normLvl.contains('mat')) return EducationalStage.maternelle;
      if (normLvl.contains('univ')) return EducationalStage.universite;
    }

    return defaultStage;
  }

  /// Whether the stage is higher education
  static bool isHigherEducation(EducationalStage stage) {
    return stage == EducationalStage.universite;
  }

  /// Whether a string level or class corresponds to higher education
  static bool isHigherEducationLevel(String? levelOrClass) {
    if (levelOrClass == null || levelOrClass.trim().isEmpty) return false;
    final stage = inferEducationalStage(
      educationalLevel: levelOrClass,
      className: levelOrClass,
    );
    return isHigherEducation(stage);
  }

  /// Checks if candidate level string matches target level string
  static bool isLevelMatching(String candidateLevel, String targetLevel) {
    final normCandidate = normalizeLevel(candidateLevel);
    final normTarget = normalizeLevel(targetLevel);

    if (normCandidate.isEmpty || normTarget.isEmpty) return false;
    if (normCandidate == normTarget) return true;
    if (normCandidate == 'tous' || normTarget == 'tous') return true;

    final stageCandidate = inferEducationalStage(
      educationalLevel: candidateLevel,
      className: candidateLevel,
    );
    final stageTarget = inferEducationalStage(
      educationalLevel: targetLevel,
      className: targetLevel,
    );

    if (stageCandidate == stageTarget && stageCandidate != EducationalStage.lycee) {
      return true;
    }
    if (stageCandidate == stageTarget &&
        (normCandidate.contains('lyc') || normTarget.contains('lyc'))) {
      return true;
    }

    if (normCandidate.contains(normTarget) || normTarget.contains(normCandidate)) {
      return true;
    }

    for (final aliases in levelGroups.values) {
      final candidateInGroup =
          aliases.any((a) => normCandidate.contains(a) || a.contains(normCandidate));
      final targetInGroup =
          aliases.any((a) => normTarget.contains(a) || a.contains(normTarget));
      if (candidateInGroup && targetInGroup) return true;
    }

    return false;
  }

  /// Checks if a given educational level string represents a global / all-levels view.
  static bool hasAllEducationalLevels(String? level) {
    if (level == null || level.trim().isEmpty) return true;
    final norm = normalizeLevel(level);
    const globalTerms = [
      'tous',
      'all',
      'tous les niveaux',
      'toutes les etapes',
      'tous les cycles',
      'administration generale',
      'administration',
      'gestion scolaire',
      'الكل',
      'كل',
      'جميع',
      'جميع المستويات',
      'الإدارة العامة',
      'ادارة عامة',
      'الإدارة',
      'ادارة'
    ];
    return globalTerms.contains(norm);
  }

  /// Robust check if a student or class belongs to the given active educational level.
  /// Checks educationalLevel, className, filiere, and sectionName.
  static bool isStudentInEducationalLevel({
    String? educationalLevel,
    String? className,
    String? sectionName,
    String? filiere,
    String? activeLevel,
  }) {
    if (activeLevel == null || activeLevel.isEmpty || hasAllEducationalLevels(activeLevel)) {
      return true;
    }

    final targetStage = inferEducationalStage(
      educationalLevel: activeLevel,
      className: activeLevel,
    );

    // 1. Direct match on educationalLevel if set and specific
    if (educationalLevel != null &&
        educationalLevel.isNotEmpty &&
        !hasAllEducationalLevels(educationalLevel)) {
      final studentStage = inferEducationalStage(educationalLevel: educationalLevel);
      if (studentStage == targetStage) {
        return true;
      }
    }

    // 2. Class name, section, filiere inspection
    final classText = '$className $filiere $sectionName'.trim();
    if (classText.isNotEmpty) {
      final normText = normalizeLevel(classText);

      final isUnivClass = RegExp(
        r'\b(l[1-3]|m[1-2]|d[1-3]|licence|master|doctorat|bts|dut|deug|faculte|institut|superieur|universite|lmd)\b',
        caseSensitive: false,
      ).hasMatch(normText) ||
          normText.contains('universit') ||
          normText.contains('superieur') ||
          normText.contains('licence') ||
          normText.contains('master') ||
          normText.contains('doctorat');

      final isCollegeClass = RegExp(
        r'\b(6[eè]me?|5[eè]me?|4[eè]me?|3[eè]me?|6e|5e|4e|3e|college|coll[eè]ge|bepc|brevet|cem|moyen)\b',
        caseSensitive: false,
      ).hasMatch(normText) ||
          normText.contains('coll') ||
          normText.contains('moyen') ||
          normText.contains('cem');

      final isLyceeClass = RegExp(
        r'\b(2nde?|seconde|1[eè]re?|premiere|premi[eè]re|tle|terminale|lycee|lyc[eè]e|bac)\b',
        caseSensitive: false,
      ).hasMatch(normText) ||
          normText.contains('lyc') ||
          normText.contains('secondaire');

      final isPrimaryClass = RegExp(
        r'\b(ci|cp|cp1|cp2|ce1|ce2|cm1|cm2|sil|cours\s+d.initiation|cours\s+preparatoire|cours\s+elementaire|cours\s+moyen)\b',
        caseSensitive: false,
      ).hasMatch(normText) ||
          RegExp(r'\b(ci|cp|ce1|ce2|cm1|cm2)[a-z0-9]?\b', caseSensitive: false).hasMatch(normText) ||
          normText.contains('prim') ||
          normText.contains('elem');

      final isMaternelleClass = RegExp(
        r'\b(maternelle|creche|prescolaire|garderie|petite\s+section|moyenne\s+section|grande\s+section|ps|ms|gs)\b',
        caseSensitive: false,
      ).hasMatch(normText) ||
          normText.contains('mat') ||
          normText.contains('creche');

      if (targetStage == EducationalStage.universite) {
        return isUnivClass && !isPrimaryClass && !isCollegeClass && !isLyceeClass;
      }
      if (targetStage == EducationalStage.college) {
        return isCollegeClass && !isUnivClass && !isPrimaryClass;
      }
      if (targetStage == EducationalStage.lycee) {
        return isLyceeClass && !isUnivClass && !isCollegeClass;
      }
      if (targetStage == EducationalStage.primaire) {
        return (isPrimaryClass || isMaternelleClass) && !isUnivClass && !isCollegeClass && !isLyceeClass;
      }
      if (targetStage == EducationalStage.maternelle) {
        return isMaternelleClass && !isUnivClass && !isCollegeClass && !isLyceeClass;
      }
    }

    return false;
  }

  /// Resolves the specific header config for a given campus/branch and educational level.
  /// Exactly mirrors web's getActiveLevelHeaderConfig.
  static Map<String, dynamic> getActiveLevelHeaderConfig(
    Map<String, dynamic>? baseConfig, {
    String? targetLevel,
    int? targetBranchId,
  }) {
    if (baseConfig == null) return {};
    final safeBase = Map<String, dynamic>.from(baseConfig);
    final dynamic rawProfiles = safeBase['levelProfiles'];

    if (rawProfiles is! List || rawProfiles.isEmpty) {
      return safeBase;
    }

    final profiles = rawProfiles.whereType<Map<String, dynamic>>().toList();

    // 1. Check profile matching BOTH branch and level
    Map<String, dynamic>? matchedProfile;
    if (targetBranchId != null) {
      matchedProfile = profiles.firstWhere(
        (profile) {
          final pBranchId = int.tryParse(profile['branchId']?.toString() ?? '');
          if (pBranchId != targetBranchId) return false;
          if (targetLevel != null && profile['applicableLevels'] is List) {
            final appLevels = List<String>.from(
                (profile['applicableLevels'] as List).map((e) => e.toString()));
            return appLevels.any((lvl) => isLevelMatching(lvl, targetLevel));
          }
          return true;
        },
        orElse: () => {},
      );
      if (matchedProfile.isEmpty) matchedProfile = null;
    }

    // 2. If targetLevel is provided, match by educational level across all profiles FIRST!
    if (matchedProfile == null && targetLevel != null) {
      matchedProfile = profiles.firstWhere(
        (profile) {
          if (profile['applicableLevels'] is List) {
            final appLevels = List<String>.from(
                (profile['applicableLevels'] as List).map((e) => e.toString()));
            if (appLevels.any((lvl) => isLevelMatching(lvl, targetLevel))) {
              return true;
            }
          }
          final name = profile['name']?.toString() ?? '';
          if (name.isNotEmpty && isLevelMatching(name, targetLevel)) {
            return true;
          }
          return false;
        },
        orElse: () => {},
      );
      if (matchedProfile.isEmpty) matchedProfile = null;
    }

    // 3. Fallback: match by branchId specifically, but ONLY if not in conflict with targetLevel!
    if (matchedProfile == null && targetBranchId != null) {
      matchedProfile = profiles.firstWhere(
        (profile) {
          final pBranchId = int.tryParse(profile['branchId']?.toString() ?? '');
          if (pBranchId != targetBranchId) return false;
          if (targetLevel != null) {
            final isTargetHigher = isHigherEducationLevel(targetLevel);
            final appLevels = profile['applicableLevels'] is List
                ? List<String>.from(
                    (profile['applicableLevels'] as List).map((e) => e.toString()))
                : <String>[];
            final pName = (profile['name']?.toString() ?? '').toLowerCase();
            final isProfileHigher = appLevels.any((lvl) => isHigherEducationLevel(lvl)) ||
                pName.contains('univ');
            if (isTargetHigher != isProfileHigher) {
              return false; // Conflicting stage
            }
          }
          return true;
        },
        orElse: () => {},
      );
      if (matchedProfile.isEmpty) matchedProfile = null;
    }

    if (matchedProfile == null || matchedProfile['headerConfig'] is! Map) {
      return safeBase;
    }

    final overrides = Map<String, dynamic>.from(matchedProfile['headerConfig'] as Map);

    final resolvedSchoolName = overrides['schoolName'] ??
        matchedProfile['branchName'] ??
        (matchedProfile['name']?.toString() ?? '')
            .replaceAll(RegExp(r'^En-tête\s+', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*\(.*\)$'), '')
            .trim();

    var resolvedService = overrides['service'] ?? safeBase['service'];
    final isTargetK12 = targetLevel != null ? !isHigherEducationLevel(targetLevel) : false;
    if (isTargetK12 &&
        resolvedService != null &&
        (resolvedService.toString().toLowerCase().contains('facult') ||
            resolvedService.toString().toLowerCase().contains('lmd'))) {
      resolvedService = 'Service de la Scolarité';
    }

    var resolvedStyle = overrides['style'] ?? safeBase['style'];
    if (isTargetK12 && resolvedStyle == 'university_formal') {
      resolvedStyle = 'classic_dual_logo';
    }

    final result = Map<String, dynamic>.from(safeBase);
    result.addAll(overrides);
    if (resolvedSchoolName != null && resolvedSchoolName.toString().isNotEmpty) {
      result['schoolName'] = resolvedSchoolName;
    }
    if (resolvedService != null) {
      result['service'] = resolvedService;
    }
    result['style'] = resolvedStyle;
    result['leftLogo'] = matchedProfile['leftLogo'] ??
        matchedProfile['customLogo'] ??
        overrides['leftLogo'] ??
        safeBase['leftLogo'];
    result['centerLogo'] = matchedProfile['centerLogo'] ??
        overrides['centerLogo'] ??
        safeBase['centerLogo'];
    result['rightLogo'] = matchedProfile['rightLogo'] ??
        overrides['rightLogo'] ??
        safeBase['rightLogo'];
    result['activeLevelProfileId'] = matchedProfile['id'];

    return result;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STAGE-SPECIFIC FINANCE LABELS & TITLES
  // ───────────────────────────────────────────────────────────────────────────

  static String getReceiptTitle(EducationalStage stage) {
    return stage == EducationalStage.universite
        ? 'REÇU DE PAIEMENT UNIVERSITAIRE'
        : 'REÇU DE PAIEMENT SCOLAIRE';
  }

  static String getReceiptSubtitle(EducationalStage stage) {
    return stage == EducationalStage.universite
        ? 'Preuve officielle de paiement des droits universitaires & académiques'
        : 'Preuve officielle de paiement des frais scolaires';
  }

  static String getReceiptStudentSectionTitle(EducationalStage stage) {
    return stage == EducationalStage.universite
        ? 'INFORMATIONS ÉTUDIANT'
        : 'INFORMATIONS ÉLÈVE';
  }

  static String getReceiptClassLabel(EducationalStage stage) {
    return stage == EducationalStage.universite ? 'Filière / Niveau' : 'Classe';
  }

  static String getReceiptYearLabel(EducationalStage stage) {
    return stage == EducationalStage.universite ? 'Année Académique' : 'Année Scolaire';
  }

  static String getReceiptExpectedFeeLabel(EducationalStage stage) {
    return stage == EducationalStage.universite
        ? 'Total Attendu (Droits académiques)'
        : 'Total Attendu (Frais annuels)';
  }

  static String getDefaultMinistry(EducationalStage stage, {bool isArabic = false}) {
    if (stage == EducationalStage.universite) {
      return isArabic
          ? 'وزارة التعليم العالي والبحث العلمي'
          : 'MINISTÈRE DE L\'ENSEIGNEMENT SUPÉRIEUR ET DE LA RECHERCHE';
    }
    return isArabic
        ? 'وزارة التربية الوطنية'
        : 'MINISTÈRE DE L\'ÉDUCATION NATIONALE';
  }

  static String getDefaultService(EducationalStage stage, {bool isArabic = false}) {
    if (stage == EducationalStage.universite) {
      return isArabic
          ? 'الوكالة المحاسبية الجامعية'
          : 'Agence Comptable Universitaire';
    }
    return isArabic
        ? 'مصلحة شؤون الطلاب والمالية'
        : 'Intendance & Scolarité';
  }

  static String getReceiptStampText(EducationalStage stage, String schoolName) {
    final cleanSchool = schoolName.toUpperCase().trim();
    if (stage == EducationalStage.universite) {
      return '★ $cleanSchool ★\nAGENCE COMPTABLE';
    }
    return '★ $cleanSchool ★\nSERVICE SCOLARITÉ & INTENDANCE';
  }

  static String getReceiptCertificationText(EducationalStage stage) {
    if (stage == EducationalStage.universite) {
      return 'Nous certifions que le montant indiqué ci-dessus a été perçu de l\'étudiant(e) mentionné(e).';
    }
    return 'Nous certifions que le montant indiqué ci-dessus a été reçu de l\'élève mentionné.';
  }
}
