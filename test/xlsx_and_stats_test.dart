import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:GYMGenius/providers/active_workout_provider.dart';
import 'package:GYMGenius/providers/tracker_provider.dart';
import 'package:GYMGenius/services/workout_stats.dart';
import 'package:GYMGenius/services/xlsx_writer.dart';

LiveSet s(String w, String r, {SetType type = SetType.normal}) =>
    LiveSet(id: '$w-$r-${type.name}', weight: w, reps: r, isCompleted: true, type: type);

CompletedWorkout workout(String id, DateTime date, List<LiveSet> sets,
        {String ex = 'Bench', LogMode mode = LogMode.weightAndReps}) =>
    CompletedWorkout(
      id: id,
      date: date,
      durationSeconds: 3600,
      totalVolume: 0,
      routine: [
        WorkoutExerciseLive(id: 'x$id', exerciseId: ex, sets: sets, logMode: mode)
      ],
    );

void main() {
  group('XlsxWriter', () {
    test('column names', () {
      expect(XlsxWriter.colName(0), 'A');
      expect(XlsxWriter.colName(25), 'Z');
      expect(XlsxWriter.colName(26), 'AA');
      expect(XlsxWriter.colName(701), 'ZZ');
      expect(XlsxWriter.colName(702), 'AAA');
    });

    test('excel date serial', () {
      expect(XlsxWriter.excelDate(DateTime(2024, 1, 1, 12)), 45292.5);
    });

    test('builds a valid zip with all parts', () {
      final bytes = XlsxWriter.build([
        XlsxSheet(
          name: 'Sets',
          headers: ['Date', 'Exercise', 'Weight', 'Reps', 'Note'],
          rows: [
            [DateTime(2026, 11, 12, 18, 30), 'Bench <Press> & "co"', 82.5, 8, null],
            [DateTime(2026, 11, 14), 'Squat', 100, 5, 'felt\x01 good'],
          ],
        ),
        XlsxSheet(name: 'Sets', headers: ['dup name'], rows: []),
        XlsxSheet(name: 'a/b*c?[d]:e', headers: ['x'], rows: [[true]]),
      ]);
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
        'xl/worksheets/sheet2.xml',
        'xl/worksheets/sheet3.xml',
      ]));
      final wb = String.fromCharCodes(
          archive.findFile('xl/workbook.xml')!.content as List<int>);
      expect(wb, contains('name="Sets (2)"'));
      expect(wb, isNot(contains('a/b')));

      // Leave a copy for external validation (e.g. openpyxl).
      final out = Directory('build/test_output')..createSync(recursive: true);
      File('${out.path}/sample.xlsx').writeAsBytesSync(bytes);
    });
  });

  group('workout stats', () {
    test('estimate1RM', () {
      expect(estimate1RM(100, 1), 100);
      expect(estimate1RM(100, 10), closeTo(133.33, 0.01));
      expect(estimate1RM(100, 20), estimate1RM(100, 12)); // capped
      expect(estimate1RM(0, 5), 0);
    });

    test('warm-ups ignored for volume and best set', () {
      final session = ExerciseSession(
        workoutId: 'w',
        date: DateTime(2026),
        mode: LogMode.weightAndReps,
        sets: [s('140', '1', type: SetType.warmup), s('100', '5')],
      );
      expect(session.volume, 500);
      expect(session.topWeight, 100);
      expect(session.bestSet!.weight, '100');
    });

    test('PR detection compares against earlier workouts only', () {
      final w1 = workout('1', DateTime(2026, 1, 1), [s('100', '5')]);
      final w2 = workout('2', DateTime(2026, 1, 8), [s('105', '5')]);
      final w3 = workout('3', DateTime(2026, 1, 15), [s('100', '8')]);
      final history = [w3, w2, w1];

      expect(prsInWorkout(w1, history), isEmpty, reason: 'first time = baseline');
      final p2 = prsInWorkout(w2, history);
      expect(p2.single.kind, 'weight');
      final p3 = prsInWorkout(w3, history);
      expect(p3.single.kind, 'e1rm', reason: '100x8 beats 105x5 on e1RM');
    });

    test('formatSet', () {
      expect(formatSet(s('60', '8'), LogMode.weightAndReps), '60×8');
      expect(formatSet(s('', '12'), LogMode.repsOnly), '12 reps');
      expect(formatSet(s('12', ''), LogMode.repsOnly), '12 reps'); // legacy
    });
  });

  test('history round-trips set type, RPE and superset', () {
    final w = CompletedWorkout(
      id: 'w',
      date: DateTime(2026, 2, 2),
      durationSeconds: 60,
      totalVolume: 0,
      name: 'Push',
      routine: [
        WorkoutExerciseLive(
          id: 'a',
          exerciseId: 'Bench',
          supersetId: 'g1',
          sets: [
            LiveSet(id: '1', weight: '60', reps: '10', isCompleted: true, type: SetType.warmup),
            LiveSet(id: '2', weight: '100', reps: '5', isCompleted: true, rpe: 8.5),
          ],
        ),
      ],
    );
    final back = CompletedWorkout.fromMap(w.toMap());
    expect(back.name, 'Push');
    expect(back.routine.single.supersetId, 'g1');
    expect(back.routine.single.sets[0].type, SetType.warmup);
    expect(back.routine.single.sets[1].rpe, 8.5);
  });
}
