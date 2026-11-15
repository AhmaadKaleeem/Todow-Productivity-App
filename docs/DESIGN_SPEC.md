# Design Spec

Todow uses a warm, quiet visual style for planning and focused work. Screens should make the next action clear and keep task details readable on small phones.

## Visual language

- Use the cream background with white content surfaces and dark, high-contrast text.
- Use blue for primary actions and selection. Reserve amber for attention and red for overdue or destructive states.
- Keep decoration secondary to content. Avoid gratuitous dots, badges, gradients, shadows, and motion.
- Use gradients only where the current interface uses them to distinguish selected navigation or home summary cards. Do not use gradient page backgrounds.
- Keep typography direct and sentence case. Prefer labels that name the action or status over slogans or abstract encouragement.

## Color tokens

Use `AppColors` from `lib/core/theme/app_colors.dart` rather than introducing screen-specific colors for common roles.

| Role | Token | Value |
| --- | --- | --- |
| Page background | `background` | `#F5F1EA` |
| Main surface | `surface` | `#FFFFFF` |
| Raised or grouped surface | `surfaceElevated` | `#FAF7F2` |
| Main text | `textPrimary` | `#1A1D24` |
| Supporting text | `textSecondary` | `#78716C` |
| Action and selection | `action` | `#0EA5E9` |
| Attention | `attention` | `#F59E0B` |
| Alert and destructive action | `alert` | `#EF4444` |
| Divider | `divider` | `#E8E3DA` |

## Layout and components

- Group related controls within a clear surface. Use dividers only when they help distinguish adjacent rows or sections.
- Keep primary actions visible and easy to reach. In long forms, preserve the save action while the content scrolls.
- Use consistent corner radii, spacing, and type styles from neighboring components before adding new values.
- Keep task names, dates, and times readable without clipping. Allow longer user-provided titles to wrap where the screen can support it.
- Empty states should say what is missing and offer the next useful action.
- Use the app drawer for its five main destinations: Home, Tasks, Focus, Timetable, and Roadmaps.

## Interaction and motion

- Animate changes only when the motion explains a state change or helps the user follow an action.
- Keep focus sessions calm and legible. The running time is the main element; keep session controls easy to find.
- Alarm screens prioritize the current time, task title, snooze, and dismiss actions. Keep text within the safe area on narrow screens.
- Respect system accessibility settings and use standard Flutter controls when they meet the need.

## Product copy

- Use plain, specific language that reflects the actual control or app behavior.
- Give each message one job. Name the current state, then offer an action when one is available.
- Avoid pressure, shame, generic motivational slogans, and claims the app cannot guarantee.
