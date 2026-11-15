import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todow/core/providers/service_providers.dart';
import 'package:todow/domain/models/timetable_entry.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/timetable_import.dart';
import 'package:uuid/uuid.dart';

class TimetableNotifier extends AsyncNotifier<List<TimetableEntry>> {
  static const _uuid = Uuid();

  @override
  Future<List<TimetableEntry>> build() async {
    final repo = ref.watch(timetableRepositoryProvider);
    return repo.getAll();
  }

  Future<void> add({
    required String courseName,
    required String instructor,
    required Weekday weekday,
    required DateTime startTime,
    required DateTime endTime,
    TimetableKind scheduleKind = TimetableKind.university,
    String? room,
    DateTime? scheduledDate,
    bool repeatWeekly = true,
    String? taskId,
    String? category,
    int? colorValue,
  }) async {
    _validate(courseName, startTime, endTime);
    final entry = TimetableEntry(
      id: _uuid.v4(),
      courseName: courseName.trim(),
      instructor: instructor.trim(),
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
      scheduleKind: scheduleKind,
      room: room?.trim().isEmpty == true ? null : room?.trim(),
      scheduledDate: scheduledDate,
      repeatWeekly: repeatWeekly,
      taskId: taskId,
      category: category,
      colorValue: colorValue,
    );
    await ref.read(timetableRepositoryProvider).create(entry);

    if (state.hasValue) {
      state = AsyncData([...state.requireValue, entry]);
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> updateEntry(TimetableEntry entry) async {
    _validate(entry.courseName, entry.startTime, entry.endTime);
    await ref.read(timetableRepositoryProvider).update(entry);
    if (state.hasValue) {
      final list = state.requireValue.toList();
      final idx = list.indexWhere((e) => e.id == entry.id);
      if (idx != -1) {
        list[idx] = entry;
        state = AsyncData(list);
      } else {
        ref.invalidateSelf();
      }
    }
  }

  Future<void> delete(String id) async {
    await ref.read(timetableRepositoryProvider).delete(id);
    if (state.hasValue) {
      final list = state.requireValue.where((e) => e.id != id).toList();
      state = AsyncData(list);
    }
  }

  Future<void> importEntries(
      List<TimetableDraftEntry> draft, TimetableKind scheduleKind) async {
    if (draft.isEmpty) {
      throw Exception('Add at least one class to import.');
    }
    for (final row in draft) {
      if (row.validationError != null) throw Exception(row.validationError!);
    }
    final entries =
        draft.map((row) => row.toEntry(scheduleKind, _uuid.v4())).toList();
    await ref.read(timetableRepositoryProvider).createMany(entries);
    if (state.hasValue) {
      state = AsyncData([...state.requireValue, ...entries]);
    } else {
      ref.invalidateSelf();
    }
  }

  void _validate(String courseName, DateTime startTime, DateTime endTime) {
    if (courseName.trim().isEmpty) {
      throw Exception('Course name is required.');
    }
    if (!endTime.isAfter(startTime)) {
      throw Exception('End time must be after start time.');
    }
  }
}

final timetableProvider =
    AsyncNotifierProvider<TimetableNotifier, List<TimetableEntry>>(
        TimetableNotifier.new);

final personalTimetableProfileNameProvider =
    FutureProvider<String>((ref) async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getString('timetable_personal_profile_name') ?? 'Personal';
});

final timetableEntriesForKindProvider =
    Provider.family<List<TimetableEntry>, TimetableKind>((ref, kind) {
  final entries = ref.watch(timetableProvider).valueOrNull ?? [];
  return entries.where((e) => e.scheduleKind == kind).toList();
});

typedef TimetableFilter = ({Weekday day, TimetableKind kind});

final timetableForDayProvider =
    Provider.family<List<TimetableEntry>, TimetableFilter>((ref, filter) {
  final asyncEntries = ref.watch(timetableProvider);
  return asyncEntries.maybeWhen(
    data: (entries) {
      final filtered = entries
          .where(
              (e) => e.weekday == filter.day && e.scheduleKind == filter.kind)
          .toList();
      filtered.sort((a, b) => a.startTime.compareTo(b.startTime));
      return filtered;
    },
    orElse: () => [],
  );
});
