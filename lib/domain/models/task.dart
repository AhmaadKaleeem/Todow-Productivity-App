import 'dart:convert';

import 'package:todow/domain/models/attachment.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/reminder.dart';
import 'package:todow/domain/models/subtask.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.startAt,
    this.dueAt,
    this.category,
    this.subject,
    this.topicId,
    this.tags = const [],
    this.subtasks = const [],
    this.attachments = const [],
    this.reminderPlan = const ReminderPlan(
      preset: ReminderPreset.normal,
      offsets: [],
      constantReminder: false,
    ),
    this.sourceType = TaskSourceType.local,
    this.sourceId,
    this.sortOrder = 0,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startAt;
  final DateTime? dueAt;
  final String? category;
  final String? subject;
  final String? topicId;
  final List<String> tags;
  final List<Subtask> subtasks;
  final List<Attachment> attachments;
  final ReminderPlan reminderPlan;
  final TaskSourceType sourceType;
  final String? sourceId;
  final int sortOrder;
  final bool isPinned;

  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasConstantReminder => reminderPlan.constantReminder;
  bool get isCompleted => status == TaskStatus.completed;
  bool get isArchived => status == TaskStatus.archived;
  bool get isInbox => status == TaskStatus.inbox;

  bool get isOverdue {
    if (dueAt == null || isCompleted || isArchived) return false;
    return dueAt!.isBefore(DateTime.now());
  }

  bool get isDueToday {
    if (dueAt == null) return false;
    final now = DateTime.now();
    final localDue = dueAt!.toLocal();
    return localDue.year == now.year &&
        localDue.month == now.month &&
        localDue.day == now.day;
  }

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? updatedAt,
    DateTime? startAt,
    DateTime? dueAt,
    bool clearStartAt = false,
    bool clearDueAt = false,
    String? category,
    bool clearCategory = false,
    String? subject,
    bool clearSubject = false,
    String? topicId,
    bool clearTopicId = false,
    List<String>? tags,
    List<Subtask>? subtasks,
    List<Attachment>? attachments,
    ReminderPlan? reminderPlan,
    TaskSourceType? sourceType,
    String? sourceId,
    int? sortOrder,
    bool? isPinned,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      category: clearCategory ? null : (category ?? this.category),
      subject: clearSubject ? null : (subject ?? this.subject),
      topicId: clearTopicId ? null : (topicId ?? this.topicId),
      tags: tags ?? this.tags,
      subtasks: subtasks ?? this.subtasks,
      attachments: attachments ?? this.attachments,
      reminderPlan: reminderPlan ?? this.reminderPlan,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      sortOrder: sortOrder ?? this.sortOrder,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status.name,
        'priority': priority.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'start_at': startAt?.toIso8601String(),
        'due_at': dueAt?.toIso8601String(),
        'category': category,
        'subject': subject,
        'topic_id': topicId,
        'tags': jsonEncode(tags),
        'reminder_plan': jsonEncode(reminderPlan.toJson()),
        'source_type': sourceType.name,
        'source_id': sourceId,
        'sort_order': sortOrder,
        'is_pinned': isPinned ? 1 : 0,
      };

  factory Task.fromMap(
    Map<String, Object?> map, {
    List<Subtask> subtasks = const [],
    List<Attachment> attachments = const [],
  }) {
    return Task(
      id: map['id']! as String,
      title: map['title']! as String,
      description: map['description']! as String,
      status: TaskStatus.values.byName(map['status']! as String),
      priority: TaskPriority.values.byName(map['priority']! as String),
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      startAt: map['start_at'] != null
          ? DateTime.parse(map['start_at']! as String)
          : null,
      dueAt: map['due_at'] != null
          ? DateTime.parse(map['due_at']! as String)
          : null,
      category: map['category'] as String?,
      subject: map['subject'] as String?,
      topicId: map['topic_id'] as String?,
      tags: List<String>.from(jsonDecode(map['tags']! as String) as List),
      subtasks: subtasks,
      attachments: attachments,
      reminderPlan: ReminderPlan.fromJson(
        Map<String, Object?>.from(
          jsonDecode(map['reminder_plan']! as String) as Map,
        ),
      ),
      sourceType: TaskSourceType.values.byName(map['source_type']! as String),
      sourceId: map['source_id'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
    );
  }
}
