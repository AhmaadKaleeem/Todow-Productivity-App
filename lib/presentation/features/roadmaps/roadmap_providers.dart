import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:todow/core/providers/service_providers.dart';
import 'package:todow/domain/models/roadmap.dart';
import 'package:todow/domain/models/roadmap_import.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/reminder.dart';
import 'package:todow/domain/reminders/reminder_presets.dart';

class RoadmapNotifier extends AsyncNotifier<List<Roadmap>> {
  static const _uuid = Uuid();

  @override
  Future<List<Roadmap>> build() async {
    return ref.watch(roadmapRepositoryProvider).getAll();
  }

  Future<Roadmap> createRoadmap({required String title, String? description, int colorIndex = 0}) async {
    final now = DateTime.now();
    final r = Roadmap(
      id: _uuid.v4(),
      title: title,
      description: description,
      colorIndex: colorIndex,
      orderIndex: state.valueOrNull?.length ?? 0,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(roadmapRepositoryProvider).create(r);
    if (state.hasValue) {
      state = AsyncData([...state.value!, r]);
    } else {
      ref.invalidateSelf();
    }
    return r;
  }

  Future<void> updateRoadmap(Roadmap roadmap) async {
    await ref.read(roadmapRepositoryProvider).update(roadmap);
    if (state.hasValue) {
      state = AsyncData([
        for (final r in state.value!) r.id == roadmap.id ? roadmap : r
      ]);
    }
  }

  Future<void> deleteRoadmap(String id, {bool deleteTasks = false}) async {
    await ref.read(roadmapRepositoryProvider).delete(id, deleteTasks: deleteTasks);
    if (state.hasValue) {
      state = AsyncData(state.value!.where((r) => r.id != id).toList());
    }
  }

  Future<void> reorderRoadmaps(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    if (!state.hasValue) return;
    
    final reordered = [...state.value!];
    final roadmap = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, roadmap);
    await ref.read(roadmapRepositoryProvider).reorder(reordered);
    
    state = AsyncData([
      for (var i = 0; i < reordered.length; i++)
        reordered[i].copyWith(orderIndex: i)
    ]);
  }

  Future<List<Topic>> getTopics(String roadmapId) =>
      ref.read(topicRepositoryProvider).getByRoadmapId(roadmapId);
      
  Future<Topic?> getTopic(String id) => ref.read(topicRepositoryProvider).getById(id);
  
  Future<Roadmap?> getRoadmap(String id) => ref.read(roadmapRepositoryProvider).getById(id);

  Future<Topic> createTopic({
    required String roadmapId,
    required String title,
    String? description,
    required int orderIndex,
  }) async {
    final now = DateTime.now();
    final t = Topic(
      id: _uuid.v4(),
      roadmapId: roadmapId,
      title: title,
      description: description,
      orderIndex: orderIndex,
      status: TopicStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(topicRepositoryProvider).create(t);
    return t;
  }

  Future<void> updateTopic(Topic topic) => ref.read(topicRepositoryProvider).update(topic);
  
  Future<void> deleteTopic(String id) => ref.read(topicRepositoryProvider).delete(id);

  Future<List<Task>> getTasksByTopic(String topicId) =>
      ref.read(roadmapTaskRepositoryProvider).getByTopicId(topicId);
      
  Future<List<Task>> getTasksByRoadmap(String roadmapId, {DateTime? from, DateTime? to}) =>
      ref.read(roadmapTaskRepositoryProvider).getByRoadmapId(roadmapId, from: from, to: to);

  Future<Roadmap> importDraft(RoadmapImportDraft draft) async {
    final now = DateTime.now();
    final roadmap = Roadmap(
      id: _uuid.v4(),
      title: draft.title,
      description: draft.rows.first.roadmapDescription,
      colorIndex: 0,
      orderIndex: state.valueOrNull?.length ?? 0,
      createdAt: now,
      updatedAt: now,
    );
    
    final topicByKey = <String, Topic>{};
    for (final row in draft.rows) {
      final key = '${row.topicOrder}:${row.topicTitle}';
      topicByKey.putIfAbsent(
        key,
        () => Topic(
          id: _uuid.v4(),
          roadmapId: roadmap.id,
          title: row.topicTitle,
          description: row.topicDescription,
          orderIndex: row.topicOrder - 1,
          status: TopicStatus.values.byName(row.topicStatus),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    
    final tasks = [
      for (final row in draft.rows)
        Task(
          id: _uuid.v4(),
          title: row.taskTitle,
          description: row.taskDescription ?? '',
          status: TaskStatus.values.byName(row.taskStatus),
          priority: TaskPriority.values.byName(row.priority),
          createdAt: now,
          updatedAt: now,
          dueAt: _dueAt(row.dueDate, row.dueTime),
          topicId: topicByKey['${row.topicOrder}:${row.topicTitle}']!.id,
          reminderPlan: ReminderPlan(
            preset: _reminderPreset(row.reminder),
            offsets: row.reminder == 'none'
                ? const <ReminderOffset>[]
                : ReminderPresets.forPreset(_reminderPreset(row.reminder)),
            constantReminder: false,
          ),
          sourceType: TaskSourceType.local,
        ),
    ];
    
    await ref.read(roadmapImportRepositoryProvider).importAll(
      roadmap: roadmap, 
      topics: topicByKey.values.toList(), 
      tasks: tasks
    );
    
    if (state.hasValue) {
      state = AsyncData([...state.value!, roadmap]);
    } else {
      ref.invalidateSelf();
    }
    return roadmap;
  }

  DateTime? _dueAt(String? date, String? time) {
    if (date == null || date.isEmpty) return null;
    final selectedTime = time == null || time.isEmpty ? '00:00' : time;
    return DateTime.tryParse('${date}T$selectedTime');
  }

  ReminderPreset _reminderPreset(String reminder) => switch (reminder) {
        'assignment' => ReminderPreset.assignment,
        'critical' => ReminderPreset.critical,
        'none' => ReminderPreset.custom,
        _ => ReminderPreset.normal,
      };
}

final roadmapsProvider = AsyncNotifierProvider<RoadmapNotifier, List<Roadmap>>(
  RoadmapNotifier.new,
);
