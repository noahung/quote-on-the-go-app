# Discovery Notes — High-Priority Missing Features

Findings from the parallel (sequential) codebase exploration of `qotg-mobile` and `quote-on-the-go-master` web app.

## Phase 1 — Integrations

### Mobile current state
- `lib/screens/settings/integrations_screen.dart` shows QuickBooks, Monday.com, Google Calendar status.
- All actions (`onConnect`, `onDisconnect`, `onSync`) only open the web app in an external browser via `_launchWebApp`.
- No mobile-side API calls or OAuth deep-link handling.
- Models already have integration fields: `Company` has `quickbooksEnabled`, `mondayEnabled`, `googleCalendarEnabled`, `quickbooksLastSyncAt`, `mondayLastSyncAt`, etc. `Quotation`, `Invoice`, `Service`, `Customer` already have `mondayItemId`, `mondayBoardId`, `mondaySyncStatus`, `mondaySyncError`, `quickbooksCustomerId`, `quickbooksItemId` fields.

### Web API already available
- QuickBooks: `/api/quickbooks/connect` (POST `{companyId}` → `{authUrl}`), `/api/quickbooks/callback`, `/api/quickbooks/disconnect` (POST `{companyId}`). Server actions in `src/app/actions/quickbooksActions.ts` provide sync/import for customer, invoice, service, import all.
- Monday.com: `/api/monday/connect` (POST with Bearer token → `{authUrl}`), `/api/monday/callback`, `/api/monday/disconnect`, `/api/monday/boards`. Server actions in `src/app/actions/mondayActions.ts` provide sync/unsync for quotation, invoice, customer, service and sync-all.
- Google Calendar: `/api/google-calendar/callback`, server actions in `src/app/actions/googleCalendarActions.ts` for connect/disconnect/create/update event. There is also `/api/calendar/feed/[companyId]`.

### Gap
Mobile needs to call the existing endpoints, handle OAuth deep links back to the app, and add per-entity sync actions in detail screens.

## Phase 2 — Workflow Execution

### Mobile current state
- `lib/screens/workflows/workflows_screen.dart` lists templates and has a "Template Library" tab.
- `lib/screens/workflows/create_workflow_screen.dart` creates workflows directly in Firestore.
- `lib/providers/workflow_provider.dart` provides a stream of `WorkflowTemplate` and `create/update/delete/toggle` methods.
- `lib/models/workflow.dart` defines `WorkflowTemplate` and `WorkflowStep`.
- No `WorkflowExecution`, `startWorkflowExecution`, execution log, or trigger document picker.

### Web current state
- `src/app/actions/workflowActions.ts` contains:
  - `createWorkflowTemplate`, `getWorkflowTemplates`, `updateWorkflowTemplate`, `deleteWorkflowTemplate`, `toggleWorkflowActive`
  - `startWorkflowExecution(templateId, targetDocumentId, targetType, companyId)`
  - `getWorkflowExecutions(companyId)`
  - `getDocumentsForWorkflowTrigger(companyId)`
  - `processPendingWorkflows()` and `processWorkflowStep`
- Firestore collections: `workflow_templates` and `workflow_executions`.
- `src/lib/workflow-types.ts` defines `WorkflowExecution`, `ExecutionLogEntry`, etc.
- Web UI in `src/components/workflow/WorkflowManager.tsx` shows templates, active executions, history, and a "Trigger Test Run" document picker.

### Gap
Mobile needs to add `WorkflowExecution` model/repository, an execution log screen, and a "Run now" / test-run document picker. No web API routes exist yet; mobile can either call the server actions via a new API wrapper or use a Firebase Callable Function.

## Phase 3 — Collaboration Governance

### Mobile current state
- `lib/screens/collaboration/collaboration_screen.dart` has two tabs: Versions and Team Comments.
- `lib/providers/collaboration_provider.dart` defines `InternalComment`, `DocumentVersion`, streams from `internal_comments` and `document_versions`, and `addComment` / `createVersion` methods.
- `lib/screens/settings/collaboration_overview_screen.dart` shows a read-only overview of pending approvals, recent comments, and activity timeline. It has local models for `ApprovalWorkflow`, `InternalComment`, and `ActivityTimeline` but only reads from Firestore.
- Missing in the collaboration screen: comment resolution, version restore, approval workflow initiation/approval, document timeline, mentions.

### Web current state
- `src/app/actions/collaborationActions.ts` has full governance:
  - `addInternalComment`, `getDocumentComments`, `resolveComment`
  - `createDocumentVersion`, `getDocumentVersions`, `restoreDocumentVersion`
  - `initiateApprovalWorkflow`, `processApprovalDecision`, `getActiveApprovalWorkflow`
  - `getDocumentTimeline`
  - Helper `logActivity` writes to `activity_timeline`, `createMentionNotifications` writes to `user_notifications`.
- `src/lib/collaboration-types.ts` defines `DocumentVersion`, `InternalComment`, `ApprovalWorkflow`, `ActivityTimeline`, `CommentAttachment`.
- Web UI in `src/components/collaboration/CollaborationDrawer.tsx` shows tabs: Versions, Comments, Activity, Approvals.
- Firestore collections: `internal_comments`, `document_versions`, `approval_workflows`, `approval_rules`, `activity_timeline`, `user_notifications`.

### Gap
Mobile needs to add `resolveComment`, `restoreDocumentVersion`, `initiateApprovalWorkflow`, `processApprovalDecision`, and `getDocumentTimeline` to the repository, and extend the collaboration screen with Activity/Approvals tabs. Approval workflow write operations are currently web-only; they need a mobile-safe API wrapper.

## Phase 4 — AI / Smart Pricing

### Mobile current state
- `lib/screens/pricing/smart_pricing_screen.dart` exists with tabs for “Price Optimizer” and “Service Bundles”.
- The optimizer is a hardcoded 12% increase + static reasoning; bundles are generated from simple local heuristics (combo discounts for 1–3 services). No server-side data is used for the reasoning.
- `lib/services/ai_service.dart` calls a Cloud Function `https://us-central1-adverto-invoice.cloudfunctions.net/generateLineItems` to generate `LineItem`s from a prompt.
- `lib/providers/ai_provider.dart` exposes `aiServiceProvider` and `aiGenerationStateProvider`.
- `lib/screens/quotations/create_quotation_screen.dart` and `lib/screens/invoices/create_invoice_screen.dart` both have an AI line-item generator bottom sheet that calls the same provider.
- `lib/providers/ai_provider.dart` has an `isPremiumProvider` check based on `company.tier == 'premium'`.
- There is no mobile receipt analysis, discount recommendation, or AI-driven pricing suggestions based on historical data.

### Web current state
- `src/app/actions/aiActions.ts` uses GenKit (`googleai/gemini-2.0-flash`) for:
  - `generateQuoteItemsAction(prompt)` — returns `{items: [{description, itemDetails, quantity, unitPrice}]}`.
  - `analyzeReceiptAction(imageBase64)` — extracts merchant, date, amount, currency, description, category.
- `src/app/actions/pricingActions.ts` provides server-side analytics for:
  - `generatePricingSuggestions(companyId, serviceId?)` — uses historical quotes/invoices and acceptance rate to compute a suggested price, confidence, factors, and revenue impact.
  - `generateServiceBundles(companyId)` — finds frequently combined services from real quotes and recommends bundles with discount and acceptance rate.
  - `generateDiscountRecommendation(quotationId, companyId)` — generates win-back, loyalty, or volume discounts with projected win probability.
- `src/lib/pricing-types.ts` defines `PricingSuggestion`, `ServiceBundle`, `DiscountRecommendation`, `MarketAnalysis`, etc.

### Gap
Mobile smart pricing is almost entirely fake. It needs to call the real web server actions (or a new HTTP wrapper) for `generatePricingSuggestions`, `generateServiceBundles`, and `generateDiscountRecommendation`. The receipt-analysis feature exists on the web and is not exposed on mobile at all. The AI line-item generator should probably move from the Cloud Function to the GenKit server action for consistency.

## Phase 6 — Team Lifecycle

### Mobile current state
- `lib/screens/team/team_management_screen.dart` lists team members and pending invitations.
- Owners/admins can:
  - invite a new member via `https://app.quoteonthego.co.uk/api/invite-team-member` (POST `{companyId, email, role, inviterName}`),
  - cancel pending invitations by updating the `invitations` doc status to `cancelled`,
  - change a member’s role directly in Firestore.
- Remove member is shown as “Member removed — coming soon” (no actual implementation).
- There is no `acceptInvitation` / `validateInvitation` flow, no email lookup, no duplicate checks, and no expiry handling. The invitee simply signs up via the web link.
- `lib/models/user_profile.dart` has `uid`, `email`, `companyId`, `role`, `displayName`, `fcmToken`, etc.
- `lib/providers/providers.dart` does not export a dedicated team/invitations provider.

### Web current state
- `src/app/actions/teamActions.ts` contains the full lifecycle:
  - `canUserInviteMembers(userId)` — role check.
  - `sendTeamInvitation(companyId, email, role, inviterUid)` — checks existing auth user, duplicate pending invites, creates an `invitations` doc with 7-day expiry, sends Brevo email with signup link.
  - `getPendingInvitations(companyId)`, `getInvitationDetails(invitationId)`, `validateInvitation(invitationId)`.
  - `cancelInvitation(invitationId, companyId, cancellerUid)` — deletes the invitation doc.
  - `changeTeamMemberRole(userId, newRole, currentUserUid, companyId)` — only owner or admin-downgrade-to-member allowed.
  - `removeTeamMember(userId, currentUserUid, companyId)` — owner-only, removes companyId/role and writes `removedAt`.
  - `acceptInvitation(invitationId, userId)` — marks invitation accepted.
  - `cleanupExpiredInvitations()` — batch-deletes expired pending invites.
- `src/app/api/invite-team-member/route.ts` is the wrapper the mobile app already calls.
- `src/app/api/invitations/[id]/route.ts` returns invitation details.

### Gap
Mobile team management is mostly read-only or partial. The biggest gaps are: real `removeTeamMember` implementation, secure role-change rules (mobile currently bypasses server security), an in-app invitation validation/acceptance flow, and a mobile signup deep link that consumes the invite. The invitation creation endpoint is already used, so the mobile app is partly connected, but it should include the Firebase ID token for authentication instead of relying solely on the companyId in the body.

