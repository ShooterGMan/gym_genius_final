import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/exercise_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/pr_tracker_provider.dart';
import '../providers/program_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tracker_provider.dart';
import '../services/data_export_service.dart';
import '../theme/app_theme.dart';

/// UI flows for exporting / backing up / restoring user data.
class DataActions {
  static void _snack(BuildContext context, String msg, {bool error = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg,
            style: TextStyle(color: error ? Colors.white : Colors.black)),
        backgroundColor: error ? Colors.redAccent : AppColors.accent,
      ));
  }

  static Future<T?> _withProgress<T>(
      BuildContext context, String label, Future<T> Function() task) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          content: Row(children: [
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.accent)),
            const SizedBox(width: 16),
            Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white70))),
          ]),
        ),
      ),
    );
    try {
      return await task();
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// Builds an .xlsx of the full training log and opens the share sheet.
  static Future<void> exportExcel(BuildContext context, WidgetRef ref) async {
    final tracker = ref.read(trackerProvider);
    if (tracker.history.isEmpty && tracker.metrics.isEmpty) {
      if (context.mounted) _snack(context, 'Log a workout first - there is nothing to export yet.',
          error: true);
      return;
    }
    try {
      final exercises = await ref.read(exercisesProvider.future);
      if (!context.mounted) return;
      final file = await _withProgress(
        context,
        'Building spreadsheet…',
        () => DataExportService.createExcelExport(
          history: tracker.history,
          exercises: exercises,
          metrics: tracker.metrics,
          prs: ref.read(prTrackerProvider),
          unit: ref.read(settingsProvider).weightUnit,
        ),
      );
      if (file == null || !context.mounted) return;
      await DataExportService.shareFile(
        context,
        file,
        subject: 'GymGenius training log',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      if (context.mounted) _snack(context, 'Export failed: $e', error: true);
    }
  }

  static Future<void> backup(BuildContext context) async {
    try {
      final file = await DataExportService.createBackupFile();
      if (!context.mounted) return;
      await DataExportService.shareFile(
        context,
        file,
        subject: 'GymGenius backup',
        text:
            'GymGenius backup. Keep this file safe - open GymGenius > Settings > Restore to bring your data back.',
        mimeType: 'application/json',
      );
    } catch (e) {
      if (context.mounted) _snack(context, 'Backup failed: $e', error: true);
    }
  }

  /// Picks a backup file, confirms, restores and reloads all providers.
  /// Returns true when data was restored.
  static Future<bool> restore(BuildContext context, WidgetRef ref) async {
    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(type: FileType.any);
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not open file picker: $e', error: true);
      return false;
    }
    if (picked == null || !context.mounted) return false;

    Map<String, dynamic> backup;
    try {
      // readAsBytes works for content:// URIs too (no file path on Android).
      final raw = utf8.decode(await picked.readAsBytes(), allowMalformed: true);
      backup = DataExportService.parseBackup(raw);
    } catch (e) {
      if (context.mounted) _snack(context, e is BackupException ? e.message : "Couldn't read that file.",
          error: true);
      return false;
    }
    if (!context.mounted) return false;

    final count = DataExportService.workoutCount(backup);
    final created = DateTime.tryParse(backup['createdAt']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Restore backup?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '${created != null ? 'Backup from ${created.day}/${created.month}/${created.year} with ' : 'This backup has '}'
          '$count workout${count == 1 ? '' : 's'}.\n\n'
          'Everything currently in the app will be replaced.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return false;

    try {
      await DataExportService.restoreBackup(backup);
    } catch (e) {
      if (context.mounted) _snack(context, 'Restore failed: $e', error: true);
      return false;
    }

    // Every notifier loads from storage in build(), so invalidating reloads.
    ref.invalidate(trackerProvider);
    ref.invalidate(programProvider);
    ref.invalidate(manualPRsProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(exercisesProvider);
    ref.invalidate(settingsProvider);

    if (context.mounted) _snack(context, 'Restored $count workout${count == 1 ? '' : 's'}.');
    return true;
  }
}
