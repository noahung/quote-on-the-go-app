# Quote On The Go Mobile — Missing Feature Implementation Plan

This plan closes the gaps between the web app (`C:\repos\quote-on-the-go-master\quote-on-the-go-master`) and the Flutter mobile app (`c:\repos\quote-on-the-go-master\qotg-mobile`).

## Strategy

- **Consume existing web API routes** where they already exist (e.g. `/api/quickbooks/connect`, `/api/monday/connect`, `/api/send-quotation`, `/api/send-invoice`).
- **Add new mobile-safe API routes** in the Next.js web app for server actions that are currently component-only (e.g. workflow execution, approval workflows, AI pricing, CSV export, document timeline).
- **Keep all Firebase/Firestore calls behind repository classes** in the mobile app, and ensure every query is `companyId` scoped per the project rules.
- **Use the existing Stitch UI screens** (project `4652255808431416448`) as the visual reference for the new mobile screens.

## Phase 0 — Discovery & Architecture

- [ ] Inventory all web API routes under `src/app/api` and map each to the mobile feature that needs it.
- [ ] Identify server actions that still need API wrappers (workflow, collaboration, pricing, CSV).
- [ ] Create a shared `ApiClient` / `ApiService` base class in `lib/services/` so every HTTP call to the web app uses the same auth token, base URL, and error handling.
- [ ] Update `lib/models/` if new fields are needed (e.g. `workflow_execution`, `approval_workflow`, `public_comment`).
- [ ] Add a `feature_flags`/`isPremium` check helper so premium-only features are gated consistently.

**Deliverable:** a feature matrix and an `ApiClient` skeleton that the rest of the work can reuse.

## Phase 1 — Integrations (QuickBooks, Monday.com, Google Calendar)

Web API routes already exist:

- `@C:\repos\quote-on-the-go-master\quote-on-the-go-master\src\app\api\quickbooks\connect\route.ts:1-3`
- `@C:\repos\quote-on-the-go-master\quote-on-the-go-master\src\app\api\quickbooks\disconnect\route.ts:1-3`
- `@C:\repos\quote-on-the-go-master\quote-on-the-go-master\src\app\api\monday\connect\route.ts:1-3`
- `@C:\repos\quote-on-the-go-master\quote-on-the-go-master\src\app\api\monday\disconnect\route.ts:1-3`
- `@C:\repos\quote-on-the-go-master\quote-on-the-go-master\src\app\api\monday\boards\route.ts:1-3`
- `@C:\repos\quote-on-the-go-master\quote-on-the-go-master\src\app\api\google-calendar\callback\route.ts:1-3`
- `@C:\repos\quote-on-the-go-master\quote-on-the-go-master\src\app\api\calendar\feed\[companyId]\route.ts:1-3`

Mobile work:

- [ ] Replace the “open web app” placeholders in `lib/screens/settings/integrations_screen.dart` with real API calls.
- [ ] Implement OAuth callback handling (deep link) so the mobile app catches the provider redirect and marks the company as connected.
- [ ] Add per-entity sync buttons on service/quote/invoice/customer detail screens (sync to QuickBooks / Monday.com).
- [ ] Add a Google Calendar sync toggle in the schedule flow and sync events both ways.

## Phase 2 — Workflow Execution

Current mobile has templates only (`lib/screens/workflows/` and `lib/providers/workflow_provider.dart`). Web actions include `startWorkflowExecution`, `getWorkflowExecutions`, etc.

- [ ] Add new web API routes: `/api/workflows/[id]/start`, `/api/workflows/executions`.
- [ ] Create `WorkflowExecution` model and repository in `lib/models/` and `lib/providers/`.
- [ ] Build the **Execution Log** screen referenced in Stitch.
- [ ] Add a “Run now” / trigger-document picker UI to the workflow template list.
- [ ] Wire `getDocumentsForWorkflowTrigger` so users can preview which quotes/invoices will enter a workflow.

## Phase 3 — Collaboration Governance

Mobile has comments and manual versions (`lib/screens/collaboration/collaboration_screen.dart`). Missing from the web actions:

- `resolveComment`
- `restoreDocumentVersion`
- approval workflow (`initiateApprovalWorkflow`, `processApprovalDecision`, `getActiveApprovalWorkflow`)
- `getDocumentTimeline`

- [ ] Add new web API routes for the missing collaboration actions.
- [ ] Extend `CollaborationRepository` in `lib/providers/collaboration_provider.dart` with resolve/restore/approval/timeline methods.
- [ ] Add an **Approval workflow** section to the collaboration screen.
- [ ] Add a **Timeline** tab next to Comments and Versions.
- [ ] Add mention/tag support to comments.

## Phase 4 — AI / Smart Pricing

Mobile currently has a local-only `SmartPricingScreen` and an older Cloud Function `generateLineItems`. The web uses GenKit actions:

- `generatePricingSuggestions`
- `generateServiceBundles`
- `generateDiscountRecommendation`
- `analyzeReceiptAction`

- [ ] Add new web API routes: `/api/pricing/suggestions`, `/api/pricing/bundles`, `/api/pricing/discount`, `/api/ai/analyze-receipt`.
- [ ] Replace local pricing math in `SmartPricingScreen` with real GenKit suggestions.
- [ ] Add receipt capture + analysis to the expense detail/edit flow.
- [ ] Reuse the AI line-item generator in the create-quotation screen.

## Phase 5 — Reporting & Document Delivery

- [ ] Add `/api/export/quotations` and `/api/export/invoices` CSV endpoints (or call existing server actions if already exposed).
- [ ] Add CSV export buttons to the quotation and invoice list screens.
- [ ] Add **Cancel scheduled send** support in the quote/invoice detail overflow menus.
- [ ] Add **Invoice reminder email** action.
- [ ] Optionally add native PDF generation (e.g. `pdf` package) so PDFs can be shared without opening the browser.

## Phase 6 — Team Lifecycle

Mobile supports invites, pending list, and role change, but not remove/accept/validate/cleanup.

- [ ] Implement remove member (delete the `users` doc and clean up company association).
- [ ] Add an invitation acceptance flow for new users who open the app from an invitation link.
- [ ] Add invitation validation and expiration cleanup.
- [ ] Add `canUserInviteMembers` permission checks before showing invite UI.

## Phase 7 — Client Portal Enhancements

Mobile has a simple client view for one quote/invoice. The web has a full client portal.

- [ ] Reuse `/api/client-portal/dashboard` to build a customer dashboard screen.
- [ ] Add public comments and public timeline to the quote/invoice portal views.
- [ ] Add quote comparison if multiple quotes exist for the same customer.

## Phase 8 — Auth & Transactional Emails

Web API routes exist:

- `@C:\repos\quote-on-the-go-master\quote-on-the-go-master\src\app\api\auth\send-verification-code\route.ts:1-3`
- `@C:\repos\quote-on-the-go-master\quote-on-the-go-master\src\app\api\auth\verify-code\route.ts:1-3`

- [ ] Optionally replace the Firebase-only verification flow with the branded six-digit code flow.
- [ ] Trigger welcome / account-activated emails from the onboarding completion screen.

## Phase 9 — QA & Regression

- [ ] Run `flutter pub run build_runner build --delete-conflicting-outputs` after every model/provider change.
- [ ] Run `flutter analyze` and fix all new lint issues.
- [ ] Verify every new Firestore query is `companyId` scoped.
- [ ] Run the app on Android and iOS simulators and smoke-test the new flows.

## Parallel Workstreams

Phases 1, 2, 3, 4, and 6 can be worked in parallel because they touch different collections and screens. Phases 5, 7, and 8 depend mainly on the API route infrastructure built in Phase 0, so they can start once the `ApiClient` and base patterns are in place.

## Suggested Start

Start with **Phase 0** (the feature matrix and shared `ApiClient`). Once that is done, tackle **Phase 1 (Integrations)** and **Phase 3 (Collaboration)** in parallel — both deliver high value and have the most existing web endpoints ready to consume.
