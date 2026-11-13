import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../providers/active_workout_provider.dart';
import '../providers/pr_tracker_provider.dart';
import '../providers/tracker_provider.dart';
import 'workout_stats.dart';
import 'xlsx_writer.dart';

class BackupException implements Exception {
  final String message;
  BackupException(this.message);
  @override
  String toString() => message;
}

/// Backup / restore of all user data, and spreadsheet export.
class DataExportService {
  static const String backupFormat = 'gymgenius-backup';
  static const int backupVersion = 1;

  /// Keys that must never be restored onto another device/session.
  static const Set<String> _excludedKeys = {
    'active_workout_session_v2',
  };

  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  static Future<File> _writeTemp(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // -------------------------------------------------------------- backup

  /// Serialises every SharedPreferences value the app owns into one file.
  static Future<File> createBackupFile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_excludedKeys.contains(key)) continue;
      final v = prefs.get(key);
      if (v is String) {
        data[key] = {'t': 's', 'v': v};
      } else if (v is bool) {
        data[key] = {'t': 'b', 'v': v};
      } else if (v is int) {
        data[key] = {'t': 'i', 'v': v};
      } else if (v is double) {
        data[key] = {'t': 'd', 'v': v};
      } else if (v is List) {
        data[key] = {'t': 'l', 'v': v.map((e) => e.toString()).toList()};
      }
    }
    final payload = {
      'format': backupFormat,
      'version': backupVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'data': data,
    };
    return _writeTemp('GymGenius_backup_${_stamp()}.json',
        utf8.encode(const JsonEncoder.withIndent(' ').convert(payload)));
  }

  /// Validates and summarises a backup file without applying it.
  static Map<String, dynamic> parseBackup(String raw) {
    final dynamic decoded;
    try {
      decoded = json.decode(raw);
    } catch (_) {
      throw BackupException("That file isn't a GymGenius backup.");
    }
    if (decoded is! Map ||
        decoded['format'] != backupFormat ||
        decoded['data'] is! Map) {
      throw BackupException("That file isn't a GymGenius backup.");
    }
    final version = decoded['version'];
    if (version is! int || version > backupVersion) {
      throw BackupException(
          'This backup was made by a newer version of GymGenius. Update the app and try again.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// Number of workouts contained in a parsed backup (for the confirm dialog).
  static int workoutCount(Map<String, dynamic> backup) {
    try {
      final h = (backup['data'] as Map)['gym_history_v1'];
      if (h is Map && h['v'] is String) {
        return (json.decode(h['v']) as List).length;
      }
    } catch (_) {}
    return 0;
  }

  /// Replaces all app data with the backup's contents.
  static Future<void> restoreBackup(Map<String, dynamic> backup) async {
    final prefs = await SharedPreferences.getInstance();
    final data = Map<String, dynamic>.from(backup['data'] as Map);

    // Remove current data first so nothing stale survives the restore.
    for (final key in prefs.getKeys().toList()) {
      if (_excludedKeys.contains(key)) continue;
      await prefs.remove(key);
    }
    for (final entry in data.entries) {
      if (_excludedKeys.contains(entry.key)) continue;
      final m = entry.value;
      if (m is! Map) continue;
      final v = m['v'];
      switch (m['t']) {
        case 's':
          if (v is String) await prefs.setString(entry.key, v);
          break;
        case 'b':
          if (v is bool) await prefs.setBool(entry.key, v);
          break;
        case 'i':
          if (v is num) await prefs.setInt(entry.key, v.toInt());
          break;
        case 'd':
          if (v is num) await prefs.setDouble(entry.key, v.toDouble());
          break;
        case 'l':
          if (v is List) {
            await prefs.setStringList(
                entry.key, v.map((e) => e.toString()).toList());
          }
          break;
      }
    }
    // A restored device has, by definition, been set up.
    await prefs.setBool('onboarding_done', true);
  }

  // ---------------------------------------------------------- excel export

  static Future<File> createExcelExport({
    required List<CompletedWorkout> history,
    required List<Exercise> exercises,
    required List<BodyMetric> metrics,
    required PRState prs,
    required String unit,
  }) async {
    final byId = {for (final e in exercises) e.id: e};
    String nameOf(String id) => byId[id]?.name ?? id.replaceAll('_', ' ');
    String muscleOf(String id) {
      final e = byId[id];
      if (e == null || e.primaryMuscles.isEmpty) return '';
      return e.primaryMuscles.first;
    }

    String modeLabel(LogMode m) {
      switch (m) {
        case LogMode.weightAndReps:
          return 'Weight & reps';
        case LogMode.repsOnly:
          return 'Reps only';
        case LogMode.timeAndReps:
          return 'Time & reps';
        case LogMode.timeAndDistance:
          return 'Time & distance';
      }
    }

    final sorted = [...history]..sort((a, b) => a.date.compareTo(b.date));

    // ---- Sheet 1: Workouts
    final workoutRows = <List<Object?>>[];
    for (final w in sorted) {
      final sets = w.routine.fold<int>(
          0, (s, ex) => s + ex.sets.where((x) => x.isCompleted).length);
      final working = w.routine.fold<int>(
          0,
          (s, ex) =>
              s + ex.sets.where((x) => x.isCompleted && x.isWorking).length);
      final rpes = [
        for (final ex in w.routine)
          for (final s in ex.sets)
            if (s.rpe != null) s.rpe!
      ];
      workoutRows.add([
        w.date,
        w.name ?? '',
        (w.durationSeconds / 60).round(),
        w.routine.length,
        sets,
        working,
        double.parse(w.totalVolume.toStringAsFixed(1)),
        rpes.isEmpty
            ? null
            : double.parse(
                (rpes.reduce((a, b) => a + b) / rpes.length).toStringAsFixed(1)),
      ]);
    }

    // ---- Sheet 2: Sets (one row per set - the "raw data" sheet)
    final setRows = <List<Object?>>[];
    for (final w in sorted) {
      final groupLetters = <String, String>{};
      for (var i = 0; i < w.routine.length; i++) {
        final ex = w.routine[i];
        if (ex.supersetId != null && !groupLetters.containsKey(ex.supersetId)) {
          groupLetters[ex.supersetId!] =
              String.fromCharCode(65 + groupLetters.length % 26);
        }
        var setNo = 0;
        for (final s in ex.sets.where((x) => x.isCompleted)) {
          setNo++;
          final weight = ex.logMode == LogMode.weightAndReps
              ? (double.tryParse(s.weight.replaceAll(',', '.')))
              : null;
          final repsText = ex.logMode == LogMode.repsOnly && s.reps.isEmpty
              ? s.weight
              : s.reps;
          final reps = int.tryParse(repsText.trim());
          final isTime = ex.logMode == LogMode.timeAndReps ||
              ex.logMode == LogMode.timeAndDistance;
          final e1rm = weight != null && reps != null && s.isWorking
              ? estimate1RM(weight, reps)
              : 0.0;
          setRows.add([
            w.date,
            w.name ?? '',
            i + 1,
            nameOf(ex.exerciseId),
            muscleOf(ex.exerciseId),
            ex.supersetId == null ? '' : groupLetters[ex.supersetId],
            setNo,
            s.type.label,
            weight,
            ex.logMode == LogMode.timeAndDistance ? null : reps,
            s.rpe,
            isTime ? s.weight : '',
            ex.logMode == LogMode.timeAndDistance
                ? double.tryParse(s.reps.replaceAll(',', '.'))
                : null,
            weight != null && reps != null && s.isWorking
                ? double.parse((weight * reps).toStringAsFixed(1))
                : null,
            e1rm > 0 ? double.parse(e1rm.toStringAsFixed(1)) : null,
            modeLabel(ex.logMode),
          ]);
        }
      }
    }

    // ---- Sheet 3: Exercise summary
    final exerciseIds = <String>{
      for (final w in history)
        for (final ex in w.routine) ex.exerciseId
    };
    final summaryRows = <List<Object?>>[];
    for (final id in exerciseIds) {
      final sessions = exerciseSessions(history, id);
      if (sessions.isEmpty) continue;
      final totalSets = sessions.fold<int>(0, (s, x) => s + x.working.length);
      final volume = sessions.fold<double>(0, (s, x) => s + x.volume);
      final topWeight =
          sessions.fold<double>(0, (m, x) => x.topWeight > m ? x.topWeight : m);
      final bestE1 =
          sessions.fold<double>(0, (m, x) => x.bestE1RM > m ? x.bestE1RM : m);
      final maxReps = sessions.fold<int>(0, (m, x) => x.maxReps > m ? x.maxReps : m);
      summaryRows.add([
        nameOf(id),
        muscleOf(id),
        sessions.length,
        totalSets,
        double.parse(volume.toStringAsFixed(1)),
        topWeight > 0 ? topWeight : null,
        bestE1 > 0 ? double.parse(bestE1.toStringAsFixed(1)) : null,
        maxReps > 0 ? maxReps : null,
        sessions.last.date,
        sessions.first.date,
      ]);
    }
    summaryRows.sort((a, b) => (b[2] as int).compareTo(a[2] as int));

    // ---- Sheet 4: Personal records
    final prRows = <List<Object?>>[];
    void addPrs(Map<String, PersonalRecord> m, String kind) {
      for (final pr in m.values) {
        prRows.add([
          pr.exerciseName.isNotEmpty ? pr.exerciseName : nameOf(pr.exerciseId),
          kind,
          pr.weight > 0 ? pr.weight : null,
          pr.reps > 0 ? pr.reps : null,
          pr.weight > 0 && pr.reps > 0
              ? double.parse(estimate1RM(pr.weight, pr.reps).toStringAsFixed(1))
              : null,
          pr.date,
        ]);
      }
    }

    addPrs(prs.heaviestWeight, 'Heaviest weight');
    addPrs(prs.mostReps, 'Most reps');
    addPrs(prs.highestVolume, 'Best set volume');
    prRows.sort((a, b) => (a[0] as String).compareTo(b[0] as String));

    // ---- Sheet 5: Body metrics
    final metricRows = [
      for (final m in [...metrics]..sort((a, b) => a.date.compareTo(b.date)))
        [
          m.date,
          double.tryParse(m.weight),
          m.bodyFat.isEmpty ? null : double.tryParse(m.bodyFat),
        ]
    ];

    final u = unit;
    final bytes = XlsxWriter.build([
      XlsxSheet(
        name: 'Workouts',
        headers: [
          'Date', 'Workout', 'Duration (min)', 'Exercises', 'Sets',
          'Working sets', 'Volume ($u)', 'Avg RPE'
        ],
        rows: workoutRows,
      ),
      XlsxSheet(
        name: 'Sets',
        headers: [
          'Date', 'Workout', 'Exercise #', 'Exercise', 'Muscle', 'Superset',
          'Set #', 'Set type', 'Weight ($u)', 'Reps', 'RPE', 'Time',
          'Distance (km)', 'Volume ($u)', 'Est. 1RM ($u)', 'Log mode'
        ],
        rows: setRows,
      ),
      XlsxSheet(
        name: 'Exercise summary',
        headers: [
          'Exercise', 'Muscle', 'Sessions', 'Working sets', 'Total volume ($u)',
          'Heaviest ($u)', 'Best est. 1RM ($u)', 'Max reps', 'First done',
          'Last done'
        ],
        rows: summaryRows,
      ),
      XlsxSheet(
        name: 'Personal records',
        headers: ['Exercise', 'Record', 'Weight ($u)', 'Reps', 'Est. 1RM ($u)', 'Date'],
        rows: prRows,
      ),
      XlsxSheet(
        name: 'Body metrics',
        headers: ['Date', 'Body weight ($u)', 'Body fat (%)'],
        rows: metricRows,
      ),
    ]);

    return _writeTemp('GymGenius_export_${_stamp()}.xlsx', bytes);
  }

  // ---------------------------------------------------------------- share

  /// Opens the system share sheet for [file]. [context] is used to anchor
  /// the popover on iPad.
  static Future<void> shareFile(BuildContext context, File file,
      {String? text, String? subject, String? mimeType}) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      text: text,
      subject: subject,
      sharePositionOrigin: origin,
    ));
  }
}
