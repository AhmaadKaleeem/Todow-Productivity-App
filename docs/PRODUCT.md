# Student Productivity App - MVP 0.1

## Core Product Loop
CAPTURE → ORGANIZE → SCHEDULE → REMIND → FOCUS → COMPLETE

## Product Principles
- **Personal-first**: Useful to one student without requiring an account, server, or cloud service.
- **Local-first**: Core functionality works offline.
- **Reminder reliability**: Reminders are a core product capability, not an optional notification layer.
- **Human control**: Imported/extracted info must be reviewable and editable before saving.
- **Simple first**: Solve the core student workflow without unrelated integrations.
- **Extendable architecture**: Support future integrations via adapters.

## Requirements

### FR-01 Task Management
Create, edit, complete, reopen, delete, archive. Title, description, priority, start date/time, due date/time, tags/categories, subtasks. Search, filter, sort.
Quick duplicate. Clone complex recurring tasks instantly so you spend less time retyping and more time executing.

#### FR-01.v2 Advanced Task Interactions (Shipped)
Managing your workload should feel fluid and instant. We built three tactile interactions into the active task list so you can organize your day without opening a single menu.

Drag to reorder
Grab any task row and move it to the exact spot you want. The app writes the new order directly to the database so your plan survives a restart. You spend zero time manually numbering priorities and more time actually working.

Swipe to act
Swipe a row left to reveal solid floating buttons for Complete and Delete. One smooth gesture takes care of the action without annoying confirmation popups. You clear out finished work faster and keep the list clean.

Double tap to insert
Double tap the space between any two tasks to drop a text field exactly there. Type a title and hit Enter to create the next step right where you need it. This keeps your flow unbroken when you remember a missing step.

Splash screen skip
Returning users see a personalized greeting and can tap a single button to skip the animation. You get straight to your task list without waiting. New users get a smooth introduction that asks for their name right away so they feel at home.

Navigation drawer
Swipe right to open the cream navigation drawer and jump to Home, Tasks, Focus, Timetable, or Roadmaps. Each compact rounded pill keeps its own color identity, with a soft destination gradient on the selected section. A small Azure wave draws in below the menu, followed by the Todow in-app wordmark and version.



### FR-02 Attachments
Support local attachments (images, PDFs, local files). Attach, open, remove. SQLite stores metadata, local storage holds files.

### FR-03 & FR-04 Reminders & Presets
Multiple reminders per task (absolute or relative). Snooze, reschedule. Completing task cancels pending reminders.
On Android, reminders use exact alarms to notify at their scheduled time while Todow is in the background. Alarm mode can ring over the lock screen when Android's alarm and full-screen notification permissions are enabled.
On first launch, Todow explains that notification access is used for task reminders before opening the operating-system permission prompt. The full-screen prompt can be skipped, and the explanation is shown once.
Presets:
- NORMAL: 1 day before + deadline
- ASSIGNMENT: 2 days before + 1 day before + 3 hours before + 30 minutes before
- CRITICAL: 3 days, 2 days, 1 day, 3h, 1h, 30m, deadline

### FR-05 Constant Reminder
When enabled, continues reminding according to repeat policy until completed, snoozed, or explicitly stopped.

### FR-07 Today
Aggregates overdue, today's, upcoming, active reminders, timetable entries, and active focus. Not an analytics dashboard.
Home highlights the two categories with the most tasks and shows completed and total counts. Create a task in Daily Tasks or another category and its card appears automatically, so the home overview reflects the work you actually have. Personal Notes and Study fill empty slots when fewer than two task categories have tasks; Inbox and roadmap tasks are excluded.
The Home screen keeps its three summary cards at the top, then brings today's due tasks and classes into view. Due tasks are ordered by time and can be completed from the list. Today's classes follow the weekly timetable in time order, with the current or next class called out. The class list stays compact when the day is busy, and View timetable opens the full weekly schedule. When there are no classes, a short empty state takes the place of the list.

### FR-08 Focus Mode
Task-linked sessions, timer, pause/resume/end, presets, basic distraction controls.

### FR-09, FR-10, FR-11 Timetable
Keep University classes and Personal plans separate. University entries repeat weekly by default. Personal is an independent planner for weekly activities and one-time dated events; users can copy university classes into it, then edit or delete those copies without changing the University schedule. Personal items can link to existing tasks, tasks (including roadmap tasks) can be placed on the personal timetable, and activities can create linked tasks. Switch between a full week and one day, return to today, and edit or remove entries. In the one-day view, a live timer tracks the current class. Finished classes are struck through like completed tasks. When all classes for the day end, the view shifts to show the next day's schedule. The current or next class is always highlighted, updating instantly if the timetable is edited. Today's Home view highlights the current or next University class.
Add classes by hand or import CSV and Excel. Check and edit every imported row before confirming; Todow saves the confirmed set in one local transaction. Scan an image from the camera or gallery to create an editable draft. Course, day, and time are read from the image when clear; review the instructor and room as well before saving. If three scans cannot read it, switch to CSV or Excel, or copy a prompt to ask an external AI assistant to format the image. That optional step stays outside Todow, and the resulting file is still reviewed here before it is saved.

### FR-12 & FR-13 Roadmaps
Roadmaps turn long-term work into a clear route through ordered Topics. Alternating stage cards connect along a visible path, with completed work settled, the current stage emphasized, and upcoming Topics easy to scan. Each stage shows task progress at a glance. Expand tasks in one Topic at a time to keep the route focused, or switch to By date to browse today's, this week's, upcoming, all scheduled work, a custom date range, or selected days grouped under their Topic. Edit a Roadmap from its card options or its detail menu; rename a Topic from its options. Tasks keep their own schedules while belonging to one Topic; complete or reopen a task from its circle, open it to edit, add a task directly to a stage, or delete it from the stage. Delete a Topic from its options; its tasks remain safely in Todow, detached but intact. Create a Roadmap by hand or import or export it as CSV or Excel. The import screen provides a downloadable CSV sample with multiple Topics and tasks. Replace its example rows or omit optional columns such as descriptions, due dates, priority, status, and reminders. Todow checks every imported row before a single SQLite transaction, so a bad file never leaves behind a half-imported plan. Reorder Roadmaps with the drag handle or move controls. Delete a Roadmap from its options menu; its tasks remain safely in Todow, detached but intact. Everything is saved locally in SQLite, so each plan remains available offline.

### FR-14 Smart Flexible Reminders
Reminders that adapt to the schedule, not just the clock. When enabled for a task, Todow defers the reminder if the student is in a scheduled university class, waiting for a suitable time window within their preferred availability hours before the task deadline. Includes smart snooze and strict deadline protection (reminders are never deferred beyond the deadline). Regular fixed-time reminders remain available and are the default; flexible reminders are an additional explicit opt-in.

## CSV Specification
**Timetable CSV and Excel Columns**: `course,instructor,day,start_time,end_time,room`. Use one row per class and a weekday name or abbreviation.
**Roadmap CSV and Excel Columns**: `roadmap_title,roadmap_description,topic_title,topic_description,topic_order,topic_status,task_title,task_description,due_date,due_time,priority,task_status,reminder`

## Non-Functional Requirements
- **NFR-01 Offline**: Core works without internet.
- **NFR-02 Reliability**: Reminder scheduling must be deterministic and recoverable after restart.
- **NFR-03 Data Integrity**: Completed tasks don't produce pending reminders.
- **NFR-04 Testability**: Domain rules testable without Flutter widgets.

## Acceptance Criteria
- Tasks survive app restart, can be edited/completed. Subtasks work independently.
- Multiple reminders calculate timestamps correctly. Completing task cancels pending. Snoozing/Constant Reminder persist state.
- Focus sessions persist state.
- Timetable CSV/Excel/OCR produces an editable draft. Nothing is persisted before confirmation, and confirmed rows are saved in one SQLite transaction.
- Roadmaps, topics, and task assignments remain available after restart.
