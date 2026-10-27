class StudentMetrics {
  final double total;
  final double average;
  final double weighted;

  StudentMetrics({
    required this.total,
    required this.average,
    required this.weighted,
  });

  factory StudentMetrics.calculate({
    required double classWork,
    required double examNote,
    required double coefficient,
    required bool isHigherEd,
  }) {
    if (isHigherEd) {
      final weighted = examNote * coefficient;
      return StudentMetrics(
        total: examNote,
        average: examNote,
        weighted: weighted,
      );
    } else {
      final total = classWork + examNote;
      final average = total / 2;
      final weighted = average * coefficient;
      return StudentMetrics(
        total: total,
        average: average,
        weighted: weighted,
      );
    }
  }
}

String getAppreciation(double average, List<Map<String, dynamic>> scale) {
  if (scale.isNotEmpty) {
    final sortedScale = List<Map<String, dynamic>>.from(scale);
    sortedScale.sort((a, b) {
      final aScore = (a['base_score'] as num?)?.toDouble() ?? 0.0;
      final bScore = (b['base_score'] as num?)?.toDouble() ?? 0.0;
      return bScore.compareTo(aScore);
    });

    for (var item in sortedScale) {
      final baseScore = (item['base_score'] as num?)?.toDouble() ?? 0.0;
      if (average >= baseScore) {
        final name = item['name']?.toString() ?? item['appreciation']?.toString();
        if (name != null && name.isNotEmpty && name.toLowerCase() != 'nul' && name.toLowerCase() != 'null') {
          return name;
        }
      }
    }
  }

  // Standard fallback scales matching French system
  if (average >= 16) return "Excellent";
  if (average >= 14) return "Très Bien";
  if (average >= 12) return "Bien";
  if (average >= 10) return "Passable";
  if (average >= 8) return "Insuffisant";
  return "Médiocre";
}

Map<int, int> calculateRanks(List<Map<String, dynamic>> studentsList) {
  final sorted = List<Map<String, dynamic>>.from(studentsList);
  sorted.sort((a, b) {
    final aWeighted = (a['weighted_score'] as num?)?.toDouble() ?? 0.0;
    final bWeighted = (b['weighted_score'] as num?)?.toDouble() ?? 0.0;
    return bWeighted.compareTo(aWeighted);
  });

  final Map<int, int> ranks = {};
  int currentRank = 0;
  double lastVal = -1.0;

  for (int i = 0; i < sorted.length; i++) {
    final item = sorted[i];
    final weighted = (item['weighted_score'] as num?)?.toDouble() ?? 0.0;
    final studentId = item['student_id'] as int;

    if (weighted != lastVal) {
      currentRank = i + 1;
    }
    ranks[studentId] = currentRank;
    lastVal = weighted;
  }

  return ranks;
}

String formatRank(int rank) {
  if (rank <= 0) return "-";
  if (rank == 1) return "1er";
  return "$rankème";
}
