import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import 'package:clean_streak/features/data/local/hive_tracker_repository.dart';
import 'package:clean_streak/features/data/local/tracker_codec.dart';
import 'package:clean_streak/features/models/tracker.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clean_streak_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<HiveTrackerRepository> openRepository() async {
    final Box<Map> box = await Hive.openBox<Map>(
      HiveTrackerRepository.boxName,
    );
    return HiveTrackerRepository(box: box);
  }

  Tracker tracker(String id, {String? name, TimerGlyphId? glyph}) {
    return Tracker(
      id: id,
      name: name,
      glyph: glyph,
      scene: HeroScene.peaks,
      startAt: DateTime(2026, 10, 20, 15, 30),
      disabledMilestones: const {'2d'},
      celebratedMilestones: const {'1d'},
    );
  }

  test('saved trackers survive a full restart, in tab order', () async {
    final HiveTrackerRepository repository = await openRepository();
    await repository.saveTracker(tracker('a', name: 'Alcohol'));
    await repository.saveTracker(
      tracker('b', glyph: TimerGlyphId.cigarette),
    );
    await repository.saveTracker(tracker('c', name: 'Sugar'));

    // Simulated app restart: close everything, re-init, re-open.
    await Hive.close();
    Hive.init(tempDir.path);
    final HiveTrackerRepository reloaded = await openRepository();
    final List<Tracker> loaded = await reloaded.loadTrackers();

    expect(loaded, hasLength(3));
    expect(loaded.map((Tracker t) => t.id), ['a', 'b', 'c']);
    expect(loaded[0].name, 'Alcohol');
    expect(loaded[0].glyph, isNull);
    expect(loaded[1].glyph, TimerGlyphId.cigarette);
    expect(loaded[2].disabledMilestones, {'2d'});
    expect(loaded[2].celebratedMilestones, {'1d'});
  });

  test('saving an edited tracker overwrites in place and keeps order',
      () async {
    final HiveTrackerRepository repository = await openRepository();
    await repository.saveTracker(tracker('a', name: 'Alcohol'));
    await repository.saveTracker(tracker('b'));
    await repository.saveTracker(tracker('a', name: 'Beer'));

    final List<Tracker> loaded = await repository.loadTrackers();

    expect(loaded, hasLength(2));
    expect(loaded.map((Tracker t) => t.id), ['a', 'b']);
    expect(loaded[0].name, 'Beer');
  });

  test('deleteTracker removes the record', () async {
    final HiveTrackerRepository repository = await openRepository();
    await repository.saveTracker(tracker('a'));
    await repository.saveTracker(tracker('b'));

    await repository.deleteTracker('a');
    final List<Tracker> loaded = await repository.loadTrackers();

    expect(loaded.map((Tracker t) => t.id), ['b']);
  });

  test('malformed records are skipped, valid ones still load', () async {
    final Box<Map> box = await Hive.openBox<Map>(
      HiveTrackerRepository.boxName,
    );
    await box.put('broken1', <String, dynamic>{'id': 'x'});
    await box.put('broken2', <String, dynamic>{
      'id': 'y',
      'scene': 'unknown',
      'startAt': '2026-10-20T15:30:00',
    });

    final HiveTrackerRepository repository = HiveTrackerRepository(box: box);
    await repository.saveTracker(tracker('good'));

    final List<Tracker> loaded = await repository.loadTrackers();
    expect(loaded.map((Tracker t) => t.id), ['good']);
  });

  test('codec round-trips a minimal tracker without name or glyph', () {
    final Tracker minimal = Tracker(
      id: 't1',
      scene: HeroScene.aurora,
      startAt: DateTime(2026, 1, 2, 3, 4, 5, 678),
    );

    final Tracker? decoded = trackerFromMap(trackerToMap(minimal));

    expect(decoded, isNotNull);
    expect(decoded!.id, 't1');
    expect(decoded.name, isNull);
    expect(decoded.glyph, isNull);
    expect(decoded.scene, HeroScene.aurora);
    expect(decoded.startAt, DateTime(2026, 1, 2, 3, 4, 5, 678));
    expect(decoded.disabledMilestones, isEmpty);
    expect(decoded.celebratedMilestones, isEmpty);
  });

  test('codec reads records saved before the celebration step', () {
    // Old records have no 'celebratedMilestones' key: they load
    // with an empty set (silent migration).
    final Tracker? decoded = trackerFromMap(<String, dynamic>{
      'id': 't3',
      'scene': 'peaks',
      'startAt': '2026-10-20T15:30:00',
    });

    expect(decoded, isNotNull);
    expect(decoded!.celebratedMilestones, isEmpty);
    expect(decoded.disabledMilestones, isEmpty);
  });

  test('codec degrades an unknown glyph name to no glyph', () {
    final Tracker? decoded = trackerFromMap(<String, dynamic>{
      'id': 't2',
      'glyph': 'rocketship',
      'scene': 'peaks',
      'startAt': '2026-10-20T15:30:00',
    });

    expect(decoded, isNotNull);
    expect(decoded!.glyph, isNull);
  });

  test('codec returns null for records missing required fields', () {
    expect(trackerFromMap(<String, dynamic>{'scene': 'peaks'}), isNull);
    expect(
      trackerFromMap(<String, dynamic>{'id': 'x', 'scene': 'peaks'}),
      isNull,
    );
  });
}
