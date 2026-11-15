# Product Specification

Todow helps people organize tasks around deadlines, weekly schedules, and focused work. It is local-first and supports study, work, and personal planning without an account.

## Product principles

- Core planning works offline and stores user data on the device.
- Users control task dates, reminders, and focus activity settings.
- Imported content is editable and reviewed before it is saved.
- Tasks remain usable across the home list, timetable, roadmaps, and focus sessions.

## Current behavior

### Tasks

Users can create, edit, complete, reopen, archive, duplicate, and delete tasks. Tasks support descriptions, dates, priorities, categories, tags, subtasks, attachments, and reminders. The task list supports search, filters, sorting, manual ordering, and task insertion.

### Reminders and alarms

Each task can have multiple reminder times. Users can choose a preset, add custom times, repeat a reminder daily, and configure alert behavior. Reminders are off until enabled. Completing or deleting a task cancels its pending reminders.

The available presets are:

- Normal: one day before and at the deadline
- Assignment: two days before, one day before, three hours before, and thirty minutes before
- Critical: three days, two days, one day, three hours, one hour, thirty minutes before, and at the deadline

On Android, alarm mode can show a full-screen alarm with the current time and task details. Users can dismiss it, snooze for ten minutes, or open Todow. Exact alarms and full-screen display depend on Android permissions and settings.

### Home and schedules

Home summarizes overdue and upcoming tasks, reminders, focus sessions, and today's schedule. The timetable keeps the primary weekly schedule separate from a second schedule for personal plans or other commitments. Entries can repeat weekly or use a single date, and can link to tasks.

Users can add timetable entries manually or import a CSV, spreadsheet, or schedule image. Imports remain editable drafts until the user confirms them. Confirmed rows are saved together so a failed import does not leave a partial schedule.

### Focus sessions

Users choose a focus activity, set a duration, and can link a task. Sessions can be paused, resumed, or ended. Custom activities and their optional groups and default durations are stored locally. The full-screen timer shows the remaining time and an exit control.

### Roadmaps

Roadmaps organize larger goals into ordered topics with tasks and progress. Tasks keep their own schedules. Roadmaps can be imported from or exported to CSV and Excel files. Imported rows are checked before they are saved.

### Local data

Task data, schedules, reminders, focus sessions, roadmaps, custom focus activities, and attachment metadata are stored locally. Attachment files are stored on the device. Core planning features do not require an account or network connection.

## Data formats

Timetable imports accept `name`, `instructor`, `day`, `start_time`, `end_time`, and `room`. Legacy entry-name headers `course`, `course_name`, and `class` are also accepted.

Roadmap imports accept `roadmap_title`, `roadmap_description`, `topic_title`, `topic_description`, `topic_order`, `topic_status`, `task_title`, `task_description`, `due_date`, `due_time`, `priority`, `task_status`, and `reminder`.

## Quality requirements

- Reminder schedules can be rebuilt from persisted task and reminder state after app startup.
- Completing or deleting a task does not leave an active reminder behind.
- Imported timetable and roadmap data is validated before persistence.
- Confirmed timetable imports are saved atomically.
- Domain rules remain testable without Flutter widgets.

Future product work is tracked in [the roadmap](ROADMAP.md).
