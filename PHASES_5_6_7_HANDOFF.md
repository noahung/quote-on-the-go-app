# Mobile Parity Handoff — Phases 5, 6, 7

## Context

This project is the Flutter mobile companion app for **Quote On The Go** (a Next.js 15 multi-tenant SaaS). The goal is to close the feature gap between the web app and the Flutter app.

Phases 1–4 are already implemented and merged into the codebase. The remaining work is Phases 5, 6, and 7.

## Architecture constraints

- **Flutter + Firebase** (Firestore, Cloud Functions, FCM, Auth)
- **State management:** Riverpod (`@riverpod` / code generation)
- **Repository pattern:** Firebase calls live in repositories, not in widgets
- **Multi-tenancy:** every Firestore query for company-scoped data must include `.where('companyId', isEqualTo: currentCompanyId)`. Every created record must include `companyId`.
- **Theme:** Material 3 with `ColorScheme.fromSeed` and custom `SemanticColors` extension. Shared UI components are in `lib/components/` (`CurvedHeader`, `MeshBackground`, `GlassCard`).
- **Routing:** GoRouter (`lib/router/app_router.dart`).
- **Icons:** `lucide_icons_flutter` (check names against existing usage before using). Do **not** guess icon names — use ones already confirmed in the codebase (e.g., `checkCircle`, `xCircle`, `messageSquare`, `messageCircle`, `send`, `eye`, `arrowRight`, `creditCard`, `activity`, `trendingUp`, `download`, `calendar`, `clock`).

## What was completed in Phases 1–4

### Phase 1 — Client Response Hub

- **New files:**
  - `lib/providers/portal_activity_provider.dart`
  - `lib/screens/client_responses/client_responses_screen.dart`
  - `lib/screens/client_responses/client_activity_card.dart`
- **Changes:**
  - `lib/providers/providers.dart` — exported `portal_activity_provider.dart`
  - `lib/router/app_router.dart` — added route `/client-responses`
  - `lib/screens/dashboard/dashboard_screen.dart` — inbox icon with unread badge in app bar
  - `lib/screens/settings/settings_screen.dart` — added "Client Responses" tile under Collaboration
- **How it works:** The web client portal writes customer events to the same `activity_timeline` and `internal_comments` collections that mobile already reads. A staff reply written as `internal_comments` with `isPrivate: false` appears in the customer portal. The inbox shows company-wide customer activity, supports filters (All / Comments / Accepted / Declined / Viewed / Paid), and lets the user reply publicly from a bottom sheet.

### Phase 2 — Quote/Invoice Detail Parity

- Added `ClientActivityCard` to:
  - `lib/screens/quotations/quotation_detail_screen.dart`
  - `lib/screens/invoices/invoice_detail_screen.dart`
- The card reuses `documentTimelineProvider` from `lib/providers/collaboration_provider.dart` and the shared `ClientReplySheet` from Phase 1. It shows customer activity for that specific document and provides a quick reply button.

### Phase 3 — Notifications Deep-Linking

- Updated `lib/screens/notifications/notifications_screen.dart`:
  - Added `comment_added` / `comment` type to icon, color, and fallback navigation maps
  - Comment fallback navigates to `/client-responses`
  - Existing web links (`/quotations/{id}`, `/invoices/{id}`) still take priority
- The FCM service (`lib/services/notification_service.dart`) already maps `message.data['link']` to pending routes.

### Phase 4 — Analytics Parity

- Updated `lib/screens/analytics/analytics_screen.dart`:
  - Added a 5th tab: **Trends**
  - Trends tab shows 12-month paid revenue, peak/slowest months, and a 3-month moving-average forecast
  - Added an **Export** header action that builds a CSV and uses `share_plus` to share it
  - Made the TabBar scrollable to fit the extra tab

## Remaining work — Phases 5, 6, 7

### Phase 5 — Workflow Depth

**Goal:** Match the web workflow builder's depth without recreating a desktop drag-and-drop UI.

**Current state:**

- Model is in `lib/providers/workflow_provider.dart` (or `lib/models/workflow_execution.dart`).
- UI is in `lib/screens/workflows/create_workflow_screen.dart` and `lib/screens/workflows/workflows_screen.dart`.
- Execution log is in `lib/screens/workflows/workflow_execution_log_screen.dart`.
- Current mobile flow builder supports: `send_email`, `send_sms`, `wait` (days only), limited triggers.

**What to implement:**

1. **More delay units for the `wait` step**
   - Currently supports `days` only.
   - Add `hours`, `calendarDays`, `businessDays`.
   - In `WorkflowStep` / `WorkflowAction`, add a `waitUnit` field.
   - In the execution logic (likely a Cloud Function or local repository), interpret `businessDays` by skipping weekends.
   - Update the create-workflow UI to show a dropdown for unit when the `wait` step type is selected.

2. **More trigger types**
   - Add triggers: `quotation_created`, `quotation_sent`, `quotation_accepted`, `quotation_declined`, `invoice_created`, `invoice_sent`, `invoice_paid`, `job_status_changed`, `customer_created`.
   - The web `trigger` field in workflow templates already contains these; make the mobile UI list them and persist the selected value.

3. **Retry / failure handling**
   - Add fields to the workflow model: `maxRetries`, `retryDelaySeconds`, `onFailureAction` (`none` | `notify_owner` | `stop`).
   - In the execution log, record failed attempts and a final status (`success`, `failed`, `cancelled`).
   - Update `WorkflowExecutionLogScreen` to show failure states and retry counts.

4. **Better trigger conditions**
   - Add simple condition groups: `amount_threshold`, `status`, `document_type`, `customer_tag`.
   - In the UI, let the user add/remove condition rows.

**Suggested approach:**

- Extend `lib/models/workflow_execution.dart` with the new fields.
- Extend the workflow provider/repository to read/write these fields.
- Update the create-workflow UI with mobile-native cards (reorderable step list, bottom-sheet step editor, dropdown for units, conditions section).
- Add a `WorkflowExecutionRepository` if one does not exist.

### Phase 6 — Collaboration Polish

**Goal:** Close the advanced collaboration gap while merging customer portal comments into the same thread surface.

**Current state:**

- `lib/providers/collaboration_provider.dart` has `InternalComment`, `DocumentVersion`, `ActivityTimelineItem`, `ApprovalWorkflow`, `ApprovalRule`.
- `lib/screens/collaboration/collaboration_screen.dart` shows comments, versions, timeline, approvals.
- `lib/screens/settings/collaboration_overview_screen.dart` shows company-wide collaboration state.

**What to implement:**

1. **Unified internal + customer thread**
   - Combine `internal_comments` (including `isPrivate: false` customer comments) with `activity_timeline` for a single chronological view.
   - Add a source badge (`Internal`, `Customer`, `System`) to each item.
   - Reuse the `PortalActivityRepository` or extend `CollaborationRepository`.
   - The web has `internal_comments` with `isPrivate` and `activity_timeline`; mobile should render them as one merged timeline.

2. **Version comparison**
   - Add a "Compare" action in `CollaborationScreen` that shows a diff summary between two selected versions (from `document_versions` collection).
   - Show changed fields (customer, items, totals, notes, status) in a simple list.

3. **Lock / conflict indicator**
   - Add a `lockedBy` / `lockedAt` field to the `quotations` / `invoices` document (or a `document_locks` collection).
   - In the detail screen, show a banner when the document is currently being edited by another user.
   - Prevent destructive edits while locked (or warn before proceeding).

4. **Approval polish**
   - Allow users to approve/reject from `CollaborationScreen` with a comment.
   - Show approval progress inline in quotation/invoice detail screens.
   - Reuse existing `approval_workflows` collection.

**Suggested approach:**

- Merge logic in a new provider: `unifiedDocumentActivityProvider` that combines comments + timeline + versions, sorted by time.
- Add a `DocumentLockRepository` and `documentLockProvider`.
- Add a `VersionDiffHelper` for comparing version snapshots.

### Phase 7 — Job Detail Final Parity

**Goal:** Match the remaining job-detail features from the web: bookings, add-to-calendar, and any missing cross-links.

**Current state:**

- `lib/screens/schedule/job_detail_screen.dart` already has tabs: Overview, Quotes, Invoices, Expenses, Materials, Signature, Media, Notes.
- `lib/screens/schedule/create_job_screen.dart` creates jobs.
- Web job detail has a `Bookings` tab and an **Add to Calendar** button.

**What to implement:**

1. **Add-to-calendar**
   - In `job_detail_screen.dart`, add a quick action that generates an `.ics` file or a calendar event via `url_launcher`.
   - Alternative: build a `device_calendar` style data URI that opens the native calendar app.
   - Use `url_launcher` to open a Google Calendar / Outlook URL with the job title, time, and address pre-filled.

2. **Bookings tab**
   - Determine if the web `Bookings` tab is just a different view of linked quotes/invoices or a separate collection.
   - If it is a separate collection (`bookings` or `appointment_requests`), add a repository, provider, and a `Bookings` tab in the job detail screen.
   - If it is just a summary of schedule-related activity, add a simple view that aggregates upcoming/recent events linked to this job.

3. **Map / address in mobile overview**
   - The web job detail shows a map for the site address.
   - Mobile job detail already shows the address but not a map.
   - Add a map preview or "Open in Maps" action using `url_launcher`.

**Suggested approach:**

- Add `add_to_calendar` helper in `lib/utils/`.
- Wire it as a button in the job detail app bar or Overview tab.
- Research the `bookings` collection first; if it exists, mirror the web schema.
- For maps, `url_launcher` with a `geo:` query is sufficient for MVP.

## How to continue

1. **Start with Phase 5** because it is the most isolated and the workflow code already has a clear provider + UI structure.
2. **Then Phase 6** — it builds on the `collaboration_provider` and the new `portal_activity_provider`.
3. **Finish with Phase 7** — it is mostly UI/utility work around the schedule screens.

## Verification

After each phase, run:

```bash
flutter analyze
```

and test on the connected Android device:

```bash
flutter run -d RFCW21NW34L
```

## Files the next agent should know

- `lib/providers/providers.dart` — central export barrel
- `lib/router/app_router.dart` — route registry
- `lib/providers/portal_activity_provider.dart` — new Phase 1 provider
- `lib/screens/client_responses/client_responses_screen.dart` — new Phase 1 screen
- `lib/screens/client_responses/client_activity_card.dart` — reusable Phase 2 card
- `lib/screens/quotations/quotation_detail_screen.dart`
- `lib/screens/invoices/invoice_detail_screen.dart`
- `lib/screens/notifications/notifications_screen.dart`
- `lib/screens/analytics/analytics_screen.dart`
- `lib/providers/collaboration_provider.dart`
- `lib/screens/collaboration/collaboration_screen.dart`
- `lib/screens/schedule/job_detail_screen.dart`
- `lib/screens/workflows/create_workflow_screen.dart`
- `lib/screens/workflows/workflows_screen.dart`

## Questions to resolve first

1. Does the web app have a `bookings` collection, or is the Bookings tab just a view of `events`/` quotations`? Search the web project for `bookings` and `collection('bookings')`.
2. Where are workflow executions handled? In a Cloud Function or in the Flutter app? Check `functions/` in the web project and `lib/providers/workflow_*` in the mobile app.
3. Does the web already set `document_locks` or `lockedBy` fields? Search web for `lock` or `conflict`.

## Done definition

Phases 5–7 are complete when a business user can:

- Build workflows with hours, calendar days, business days, more triggers, and failure retry logic
- See a unified document thread with internal comments, customer portal comments, and system activity
- Compare document versions and see lock/conflict warnings
- Add a job to their device calendar and see any booking-related data linked to the job

