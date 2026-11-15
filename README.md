# Todow

Todow is a local-first planner for study, work, and personal tasks. Create tasks, set deadlines and reminders, and manage schedules in one app. University timetables are supported today; the task planner can also be used for work and personal projects.

<p align="center">
  <img src="screenshots/dashboard.png" width="320" alt="Todow dashboard screen" />
  <br />
  &#8595;
  <br />
  <img src="screenshots/create-task.png" width="320" alt="Todow task editor screen" />
</p>

## Features

- **Tasks** Create, edit, complete, reopen, archive, and delete tasks. Add priorities, dates, tags, descriptions, and subtasks. Search, filter, sort, reorder, duplicate, and insert tasks from the list.
- **Task reminders** Set multiple reminders before a deadline or at the due time. Choose Normal, Assignment, or Critical presets, set custom reminder times, or schedule a daily reminder. Optional settings include repeat reminders, flexible timing around classes, quiet hours, and alarm sounds.
- **Android full-screen alarms** Show the task name and current time when an alarm rings. Stop it, snooze for 10 minutes, or open Todow. Exact alarms and full-screen display require the matching Android permissions.
- **Attachments** Add and open images, PDFs, and other local files on a task.
- **Today dashboard** View overdue and upcoming tasks, active reminders, focus sessions, and today's classes.
- **Roadmaps** Organize work into ordered Topics with tasks and progress. Import and export roadmaps as CSV or Excel files.
- **Timetable** Add weekly university classes and personal plans. Import schedules from CSV or Excel, or scan a schedule image into an editable draft.
- **Focus mode** Run a task-linked timer with pause, resume, and end controls. Focus sessions save their state between app launches.

### In Progress
- **Rest-Time Ambient Music** Built-in restorative audio soundscapes and rest music during the 10-minute break interval, selectable by the user to optimize cognitive recovery.

### Future Roadmap
- **Google Accounts** Multiple accounts, Gmail to tasks, and Google Calendar sync.
- **Academic Tools** Import Google Classroom assignments, attach Google Drive files, and pull timetable data.
- **Sync & Backup** Sync across devices, automatic backups, and offline changes supported.
- **Focus Improvements** Android app blocking, allowed apps during study, and focus history.
- **Advanced Planning** Recurring tasks, weekly/monthly planning, goal tracking, milestone dependencies, and flexible reminder rules.
- **Profession and work categories** Choose a built-in category or enter a custom profession or work type. A future shared cloud catalog can make new categories available for other users to select.

Tasks, reminders, and schedules are stored on your device. Todow's core features work offline.

## Setup

```bash
flutter pub get
flutter run
```

Run tests:

```bash
flutter test
flutter analyze
```

## Docs

- [Product spec](docs/PRODUCT.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Design spec](docs/DESIGN_SPEC.md)
- [User flows](docs/FLOWS.md)
- [Roadmap](docs/ROADMAP.md)
