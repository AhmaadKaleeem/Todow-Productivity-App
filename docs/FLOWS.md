# Application Flows

## Task reminders

```mermaid
sequenceDiagram
    actor User
    participant UI as Task editor
    participant Controller as TaskController
    participant Tasks as TaskRepository
    participant Scheduler as ReminderSchedulerImpl
    participant Calculator as ReminderCalculator
    participant Notifications as NotificationService
    participant OS as Android alarms and notifications

    User->>UI: Save task and reminder settings
    UI->>Controller: Create or update task
    Controller->>Tasks: Persist task
    Controller->>Scheduler: Sync task reminders
    Scheduler->>Tasks: Read existing scheduled reminders
    Scheduler->>Calculator: Build schedule from task and timetable
    Calculator-->>Scheduler: Scheduled reminder times
    Scheduler->>Notifications: Schedule or cancel alerts
    Notifications->>OS: Register or cancel system alerts
```

Completing, archiving, or deleting a task cancels its pending reminders. Snoozing changes the scheduled wake-up time for that reminder.

## Timetable import

```mermaid
flowchart TD
    SOURCE[CSV, Excel, camera, or gallery] --> PARSE[Parse file or scan image]
    PARSE --> DRAFT[Create editable draft]
    DRAFT --> REVIEW[Review and edit entries]
    REVIEW -->|Cancel| DISCARD[Discard draft]
    REVIEW -->|Confirm| VALIDATE[Validate all entries]
    VALIDATE --> SAVE[Save entries in one SQLite transaction]
```

The selected schedule remains visible during import. Imported entries are not saved until confirmation. If validation or persistence fails, the import does not leave a partial set of entries.

## Timetable schedule rules

- University entries repeat weekly.
- Personal entries can repeat weekly or use one selected date.
- Copying entries creates independent entries in the destination schedule.
- Personal entries can link to tasks.
