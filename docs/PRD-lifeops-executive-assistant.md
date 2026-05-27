# PRD: LifeOps Executive Assistant

**Date:** 2026-05-27
**Owner:** Blake Crane
**Agent partner:** Daneel
**Product surface:** AgentBoard macOS + AgentBoardMobile iOS
**Status:** Draft for implementation handoff

## 1. Summary

Build a LifeOps layer inside AgentBoard that lets Daneel act as Blake's executive-function assistant outside coding. The system captures obligations from email, calendar, messaging, manual chat, and job-search activity; converts them into structured tasks; assigns urgency; displays them in a macOS dashboard and iOS companion; and lets Blake delegate work back to Daneel.

This is primarily Blake's personal operating system, but it must also support family coordination with Sarah. Daneel should be able to add shared family calendar items and accept task requests from Sarah through iMessage, while keeping ownership, consent, and visibility clear.

## 2. Problem

Blake has ADHD and needs external executive-function support for:

- Email triage and follow-up
- Calendar awareness and prep
- Job-search structure
- Family logistics
- Message follow-through
- Remembering loose obligations
- Delegating small admin actions to Daneel

The current setup is fragmented across email, calendar, messaging apps, Apple Reminders, GitHub/project systems, and memory. This causes dropped balls, stale job leads, appointment prep gaps, and mental overhead.

## 3. Goals

### Product goals

1. Create one trusted task surface for non-coding life/admin/job-search work.
2. Keep Blake oriented with short, realistic daily views instead of giant backlogs.
3. Give Daneel structured objects to act on: tasks, approvals, calendar items, job leads, waiting-on items.
4. Support family coordination with Sarah via shared family calendar/task intake.
5. Ship useful app scaffolding quickly in the existing macOS and iOS AgentBoard apps.

### ADHD-support goals

1. Externalize working memory.
2. Minimize capture friction.
3. Prioritize by time/consequence, not vague productivity vibes.
4. Provide gentle recovery from drift instead of shame.
5. Make the next action obvious.
6. Keep notification volume low and meaningful.

## 4. Non-goals for v1

- No autonomous sending of email/iMessage without explicit approval.
- No full replacement for Apple Calendar/Reminders on day one.
- No medical/therapeutic claims.
- No ML-heavy priority optimizer before we have real usage data.
- No multi-user family task platform beyond Sarah intake/shared calendar support.
- No app-store-polished UI before core workflow is proven.

## 5. Users and roles

### Blake

Primary user. Owns the task system, approval queue, job-search pipeline, and daily planning views.

### Daneel

Agent operator. Reads authorized sources, creates tasks, drafts replies/actions, prioritizes, nudges, and performs delegated work after approval.

### Sarah

Family collaborator. Can request family tasks through iMessage and can receive shared calendar items. Sarah does not need full access to Blake's private task system unless explicitly enabled later.

## 6. Core concepts

### Life task

A structured obligation/opportunity with source, priority, status, next action, owner, and assignee.

Required fields:

- `id`
- `title`
- `summary`
- `category`
- `status`
- `priority` (`P0`, `P1`, `P2`, `P3`)
- `urgencyScore` 0-100
- `importanceScore` 0-100
- `dueAt`
- `snoozedUntil`
- `estimatedMinutes`
- `nextAction`
- `owner` (`blake`, `sarah`, `family`, `daneel`)
- `assignee` (`blake`, `daneel`, `sarah`, `external`)
- `sourceType`
- `sourceID`
- `sourceURL`
- `confidence`
- `createdAt`
- `updatedAt`

### Task categories

- `email`
- `calendar`
- `messages`
- `jobSearch`
- `family`
- `admin`
- `personal`
- `finance`
- `health`
- `project`
- `waitingOn`
- `approval`

### Statuses

- `inbox` — captured but not reviewed
- `needsBlake` — Blake must act/decide
- `assignedToDaneel` — Daneel has work to do
- `waitingOnExternal` — blocked by someone else
- `scheduled` — tied to calendar/time block
- `snoozed` — intentionally hidden until later
- `done`
- `blocked`
- `cancelled`

### Priority

- `P0` — urgent, time-sensitive, high consequence, interrupt-worthy
- `P1` — should be handled today
- `P2` — this week / important but not burning
- `P3` — backlog / someday / low pressure

## 7. Main workflows

### 7.1 Daily briefing

Every morning, Daneel reviews authorized sources and produces a concise LifeOps briefing:

- P0/P1 tasks
- Today's calendar
- Meeting prep gaps
- Job-search follow-ups due
- Waiting-on items
- Suggested first action
- Items Daneel can handle if approved

The app should show the same briefing in the dashboard.

### 7.2 Email-to-task triage

Daneel scans new email and classifies each item:

- No action
- Reply needed
- Waiting on someone
- Scheduling/calendar
- Bill/admin
- Job-search lead
- Family/personal
- FYI/archive

For actionable items, Daneel creates LifeTasks with a source link and next action. If a reply is needed, Daneel can create a draft action that Blake approves before sending.

### 7.3 Calendar defense

Calendar items create prep and logistics tasks:

- Meeting without agenda: create prep task
- Interview: create prep checklist
- Travel/logistics: flag timing
- Back-to-back meetings: warn
- Family event: optionally add/share with Sarah

### 7.4 Job-search pipeline

Track opportunities as structured records:

- Company
- Role
- URL
- Contact
- Stage
- Last touch
- Next follow-up
- Resume/cover letter version
- Notes
- Associated tasks

Pipeline stages:

- `target`
- `saved`
- `applied`
- `recruiterContact`
- `screenScheduled`
- `interviewing`
- `followUpDue`
- `offer`
- `rejected`
- `closed`

### 7.5 Sarah / family task intake

Sarah can send an iMessage request to Daneel, such as:

- "Can you remind Blake to call the vet tomorrow?"
- "Please add soccer pickup Friday at 4."
- "Can you put dinner with my parents on the family calendar?"

Daneel should:

1. Parse the request.
2. Decide whether it is a task, calendar item, or question.
3. Create a LifeTask with owner `family` or `sarah` as appropriate.
4. Add shared family calendar events when the request is unambiguous and permitted.
5. Confirm back to Sarah over iMessage.
6. Surface the item to Blake in the family section or daily briefing.

Approval rule: Sarah can add family tasks/calendar events, but cannot send messages as Blake, access private job-search/email details, or approve actions on Blake's behalf unless Blake explicitly grants that later.

### 7.6 Delegation to Daneel

Blake can assign tasks to Daneel from chat, desktop, or iOS:

- Draft a reply
- Summarize a thread
- Find job leads
- Prepare interview notes
- Schedule options
- Research a purchase/admin decision

The task moves to `assignedToDaneel`; output appears in an approval queue if it has external side effects.

## 8. App surfaces

### macOS dashboard

Primary orientation surface.

Sections:

1. Now — 1 to 3 recommended actions
2. Today — realistic daily list
3. Inbox — captured but untriaged items
4. Needs approval — drafts/actions waiting for Blake
5. Waiting on — people/systems Blake is waiting for
6. Job search — pipeline and follow-ups
7. Family — Sarah/family calendar/tasks
8. Calendar — today/tomorrow agenda and prep gaps
9. Chat — talk to Daneel in context

### iOS companion

Mobile should be action-oriented, not a dense dashboard.

Tabs/sections:

1. Today
2. Capture
3. Approvals
4. Job Search
5. Family
6. Chat

Required v1 mobile actions:

- Mark done
- Snooze
- Add quick task
- Ask Daneel
- Approve/reject draft action
- View today's calendar/prep tasks

## 9. Notification rules

Default notifications must be conservative.

Interrupt immediately only for:

- P0 tasks
- Appointment starting soon
- Hard deadline today
- Interview/call prep missing
- Approved family-critical reminders

Daily briefing handles P1/P2.
P3 stays quiet unless requested.

## 10. Safety and permissions

### Daneel can do without approval

- Read authorized sources
- Summarize
- Create local tasks
- Draft replies/actions
- Suggest priorities
- Move/snooze tasks
- Add non-sensitive family tasks from Sarah

### Daneel needs approval before

- Sending email/messages as Blake
- Applying to jobs
- Sharing files
- Creating/modifying non-family calendar events
- Deleting/archiving email
- Spending money
- Contacting third parties

### Sarah can do in v1

- Send iMessage task requests
- Request shared family calendar events
- Ask Daneel to add a family task to Blake's system

### Sarah cannot do in v1

- See Blake's private tasks by default
- Approve external actions as Blake
- Access Blake's private email/job-search details
- Send messages as Blake

## 11. MVP acceptance criteria

### Data/model layer

- LifeTask model exists in AgentBoardCore.
- JobOpportunity model exists in AgentBoardCore.
- ApprovalAction model exists in AgentBoardCore.
- FamilyRequest model exists in AgentBoardCore.
- LifeOpsStore can load seeded/demo data and perform create/update/status/snooze/done actions.

### macOS UI

- AgentBoard has a LifeOps section/screen.
- Screen shows Now, Today, Inbox, Approvals, Job Search, Family, Waiting On.
- User can create a quick task.
- User can mark tasks done/snoozed.
- User can open chat with Daneel from the LifeOps context.

### iOS UI

- AgentBoardMobile exposes LifeOps tab/section.
- Today list, quick capture, approvals, and family tasks are visible.
- User can mark done/snooze/create quick task.

### Agent integration scaffold

- App has clear service protocols for future ingestion:
  - Email triage service
  - Calendar service
  - Message intake service
  - Job pipeline service
  - Daneel action service
- v1 may use mock/local implementations, but protocols and models must make real integration straightforward.

### Tests

- Model tests cover priority/status/category encoding.
- Store tests cover create/update/snooze/done/filtering.
- UI/semantics tests cover key LifeOps views and accessibility identifiers.

## 12. Metrics for success

- Blake checks the Today/Now view daily.
- Fewer forgotten replies/follow-ups.
- Job-search follow-ups are visible and dated.
- Sarah can add family tasks without turning Blake into a relay server.
- P0/P1 list stays small enough to trust.
- Daneel can answer: "what should I do next?" from structured state.

## 13. Implementation strategy

Build this as a LifeOps module inside AgentBoard first rather than a separate app. AgentBoard already has:

- macOS and iOS targets
- shared SwiftUI architecture
- Hermes chat integration
- task-board concepts
- companion service patterns
- local persistence patterns

Do not block on real email/calendar/iMessage integrations. Start with models, store, dashboard UI, iOS UI, and mock ingestion/service protocols. Then connect real sources incrementally.

## 14. Open questions

1. Which calendar is canonical for shared family events: Apple Calendar, Google Calendar, or both?
2. Should LifeOps tasks sync to Apple Reminders, and if so, only P0/P1 or all tasks?
3. Should Sarah get a lightweight view later, or remain iMessage-only in v1?
4. Should personal LifeOps data live in `~/.hermes/kanban.db`, SwiftData, or a new LifeOps SQLite store?

Recommendation for v1: use app-local store/protocols with seeded data, then decide canonical persistence after Blake uses the UI for a few days.
