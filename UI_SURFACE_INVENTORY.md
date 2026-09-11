# Mobile screen and overlay inventory

Generated from the current router and every Dart source under screens, components and widgets. This is a coverage checklist, not proof of visual or functional completion. Source matches identify call sites; some screens are embedded rather than routed.

## Routes

- `/invite/:id`
- `/splash`
- `/login`
- `/register`
- `/reset-password`
- `/`
- `/quotations`
- `/invoices`
- `/customers`
- `/schedule`
- `/workflows`
- `/analytics`
- `/pricing`
- `/settings`
- `/settings/preferences`
- `/web-preview`
- `/pdf-preview/:type/:id`
- `/pipeline`
- `/workflows/executions`
- `/workflows/:id/executions`
- `/quotations/new`
- `/quotations/:id`
- `/quotations/:id/portal`
- `/quotations/:id/edit`
- `/invoices/new`
- `/invoices/:id`
- `/invoices/:id/portal`
- `/invoices/:id/edit`
- `/invoices/recurring/new`
- `/invoices/recurring/:id/edit`
- `/customers/new`
- `/customers/:id`
- `/customers/:id/edit`
- `/schedule/new`
- `/schedule/:id`
- `/schedule/:id/edit`
- `/collaboration/:type/:id`
- `/settings/reminders`
- `/settings/saves`
- `/integrations`
- `/collaboration`
- `/client-responses`
- `/checklist-templates`
- `/settings/templates`
- `/settings/templates/add-edit`
- `/sign-in-methods`
- `/expenses`
- `/expenses/new`
- `/expenses/:id`
- `/referral`
- `/billing`
- `/services`
- `/services/new`
- `/services/:id`
- `/profile`
- `/profile/edit`
- `/notifications`
- `/team`
- `/company-branding`
- `/onboarding`
- `/verify-email`
- `/account-pending-deletion`

## Screens, components and widgets

| Source | Overlay call sites | Verification |
|---|---|---|
| lib/components/analytics_metric.dart | — | Pending complete rendered/state review |
| lib/components/animated_celebration_icon.dart | — | Pending complete rendered/state review |
| lib/components/auth_page.dart | — | Pending complete rendered/state review |
| lib/components/brand_mark.dart | — | Pending complete rendered/state review |
| lib/components/curved_header.dart | — | Pending complete rendered/state review |
| lib/components/custom_date_time_picker.dart | showTimePicker:138 | Pending complete rendered/state review |
| lib/components/custom_email_send_bottom_sheet.dart | showModalBottomSheet:772 | Pending complete rendered/state review |
| lib/components/document_discount_field.dart | — | Pending complete rendered/state review |
| lib/components/document_email_preview.dart | — | Pending complete rendered/state review |
| lib/components/draft_status_banner.dart | showDialog:60 | Pending complete rendered/state review |
| lib/components/flash_message.dart | — | Pending complete rendered/state review |
| lib/components/glass_card.dart | — | Pending complete rendered/state review |
| lib/components/mesh_background.dart | — | Pending complete rendered/state review |
| lib/components/pdf_preview_panel.dart | — | Pending complete rendered/state review |
| lib/components/pill_button.dart | — | Pending complete rendered/state review |
| lib/components/preview_status_panel.dart | — | Pending complete rendered/state review |
| lib/components/settings_action_row.dart | — | Pending complete rendered/state review |
| lib/components/success_bottom_sheet.dart | showModalBottomSheet:33 | Pending complete rendered/state review |
| lib/components/success_celebration_screen.dart | showDialog:42 | Pending complete rendered/state review |
| lib/screens/analytics/analytics_screen.dart | — | Pending complete rendered/state review |
| lib/screens/analytics/document_trends.dart | — | Pending complete rendered/state review |
| lib/screens/auth/account_pending_deletion_screen.dart | — | Representative light/dark renders inspected; see ledger for state coverage |
| lib/screens/auth/auth_credentials_screen.dart | — | Pending complete rendered/state review |
| lib/screens/auth/email_verification_screen.dart | — | Pending complete rendered/state review |
| lib/screens/auth/invitation_screen.dart | — | Pending complete rendered/state review |
| lib/screens/auth/login_screen.dart | — | Representative light/dark renders inspected; see ledger for state coverage |
| lib/screens/auth/onboarding_screen.dart | — | Representative light/dark renders inspected; see ledger for state coverage |
| lib/screens/auth/register_screen.dart | — | Representative light/dark renders inspected; see ledger for state coverage |
| lib/screens/auth/reset_password_screen.dart | — | Representative light/dark renders inspected; see ledger for state coverage |
| lib/screens/auth/splash_screen.dart | — | Pending complete rendered/state review |
| lib/screens/client_responses/client_activity_card.dart | showModalBottomSheet:122 | Pending complete rendered/state review |
| lib/screens/client_responses/client_responses_screen.dart | showModalBottomSheet:360 | Pending complete rendered/state review |
| lib/screens/collaboration/collaboration_screen.dart | showDialog:106, showModalBottomSheet:438, showDialog:760, showDialog:847 | Pending complete rendered/state review |
| lib/screens/customers/add_edit_customer_screen.dart | — | Pending complete rendered/state review |
| lib/screens/customers/customer_detail_screen.dart | showModalBottomSheet:58, showModalBottomSheet:161, showModalBottomSheet:277, PopupMenuButton:551 | Pending complete rendered/state review |
| lib/screens/customers/customers_screen.dart | PopupMenuButton:234 | Pending complete rendered/state review |
| lib/screens/dashboard/dashboard_screen.dart | — | Representative light/dark renders inspected; see ledger for state coverage |
| lib/screens/expenses/expense_detail_screen.dart | showDialog:142, showDatePicker:168 | Pending complete rendered/state review |
| lib/screens/expenses/expenses_screen.dart | — | Pending complete rendered/state review |
| lib/screens/expenses/log_expense_screen.dart | showDatePicker:92, showModalBottomSheet:102 | Pending complete rendered/state review |
| lib/screens/invoices/add_edit_recurring_invoice_screen.dart | showDatePicker:193, PopupMenuButton:759, showModalBottomSheet:810, showModalBottomSheet:829, showDialog:1588 | Pending complete rendered/state review |
| lib/screens/invoices/create_invoice_screen.dart | showDialog:614, showDatePicker:850, PopupMenuButton:974, showModalBottomSheet:1036, showModalBottomSheet:1052, showDialog:1821 | Pending complete rendered/state review |
| lib/screens/invoices/invoice_detail_screen.dart | showDialog:117, showModalBottomSheet:152, showDialog:278, showDialog:350, showDialog:381, PopupMenuButton:487 | Pending complete rendered/state review |
| lib/screens/invoices/invoice_portal_screen.dart | — | Pending complete rendered/state review |
| lib/screens/invoices/invoices_screen.dart | showDialog:130, PopupMenuButton:928, showDialog:959, showDialog:975, showDialog:1004 | Pending complete rendered/state review |
| lib/screens/notifications/notifications_screen.dart | PopupMenuButton:99 | Pending complete rendered/state review |
| lib/screens/pricing/smart_pricing_screen.dart | — | Pending complete rendered/state review |
| lib/screens/profile/edit_profile_screen.dart | — | Pending complete rendered/state review |
| lib/screens/profile/profile_menu_screen.dart | showDialog:25, showDialog:158 | Representative light/dark renders inspected; see ledger for state coverage |
| lib/screens/quotations/create_quotation_screen.dart | showDialog:466, showDatePicker:702, PopupMenuButton:826, showModalBottomSheet:887, showModalBottomSheet:910, showDialog:1657 | Pending complete rendered/state review |
| lib/screens/quotations/kanban_board_screen.dart | PopupMenuButton:416 | Pending complete rendered/state review |
| lib/screens/quotations/quotation_detail_screen.dart | showModalBottomSheet:124, showDialog:155, showDialog:287, showDialog:376, showDialog:407, PopupMenuButton:516 | Pending complete rendered/state review |
| lib/screens/quotations/quotation_portal_screen.dart | — | Pending complete rendered/state review |
| lib/screens/quotations/quotations_screen.dart | showDialog:116 | Pending complete rendered/state review |
| lib/screens/schedule/create_event_screen.dart | showModalBottomSheet:82 | Pending complete rendered/state review |
| lib/screens/schedule/create_job_screen.dart | showModalBottomSheet:135, showModalBottomSheet:164 | Pending complete rendered/state review |
| lib/screens/schedule/job_detail_screen.dart | showModalBottomSheet:142, showDialog:160, PopupMenuButton:271, showDialog:535, showDialog:562, showModalBottomSheet:596, showModalBottomSheet:673, showModalBottomSheet:2162, showDialog:2231, showModalBottomSheet:2358, showDialog:2458, showModalBottomSheet:2556, showDialog:2793, showModalBottomSheet:2821 | Pending complete rendered/state review |
| lib/screens/schedule/job_edit_screen.dart | — | Pending complete rendered/state review |
| lib/screens/schedule/monthly_schedule_screen.dart | — | Pending complete rendered/state review |
| lib/screens/schedule/schedule_screen.dart | — | Pending complete rendered/state review |
| lib/screens/services/create_service_screen.dart | — | Pending complete rendered/state review |
| lib/screens/services/service_detail_screen.dart | PopupMenuButton:65, showModalBottomSheet:233, showDialog:326 | Pending complete rendered/state review |
| lib/screens/services/services_screen.dart | — | Pending complete rendered/state review |
| lib/screens/settings/add_edit_document_template_screen.dart | showModalBottomSheet:148, PopupMenuButton:363 | Pending complete rendered/state review |
| lib/screens/settings/billing_screen.dart | — | Pending complete rendered/state review |
| lib/screens/settings/checklist_templates_screen.dart | showDialog:140 | Pending complete rendered/state review |
| lib/screens/settings/collaboration_overview_screen.dart | — | Pending complete rendered/state review |
| lib/screens/settings/company_branding_screen.dart | showDialog:259 | Pending complete rendered/state review |
| lib/screens/settings/document_saves_screen.dart | showDialog:143 | Representative light/dark renders inspected; see ledger for state coverage |
| lib/screens/settings/integrations_screen.dart | showDialog:33, showDialog:89, showDialog:202, showDialog:270, showModalBottomSheet:327, showDialog:505 | Pending complete rendered/state review |
| lib/screens/settings/referral_screen.dart | — | Pending complete rendered/state review |
| lib/screens/settings/reminder_settings_screen.dart | — | Representative light/dark renders inspected; see ledger for state coverage |
| lib/screens/settings/settings_screen.dart | showModalBottomSheet:81 | Representative light/dark renders inspected; see ledger for state coverage |
| lib/screens/settings/sign_in_methods_screen.dart | showDialog:176, showDialog:283, showDialog:407, showDialog:456 | Pending complete rendered/state review |
| lib/screens/settings/templates_screen.dart | showDialog:43, PopupMenuButton:277 | Pending complete rendered/state review |
| lib/screens/shared/document_edit_screen.dart | — | Pending complete rendered/state review |
| lib/screens/shared/document_snapshot_view.dart | — | Pending complete rendered/state review |
| lib/screens/shared/in_app_web_view_screen.dart | — | Pending complete rendered/state review |
| lib/screens/shared/local_draft_mixin.dart | showDialog:160 | Pending complete rendered/state review |
| lib/screens/shared/pdf_preview_screen.dart | — | Pending complete rendered/state review |
| lib/screens/shell_scaffold.dart | showModalBottomSheet:22 | Pending complete rendered/state review |
| lib/screens/team/team_management_screen.dart | showDialog:316, showModalBottomSheet:357, showDialog:452, showDialog:605, PopupMenuButton:846 | Pending complete rendered/state review |
| lib/screens/workflows/create_workflow_screen.dart | — | Pending complete rendered/state review |
| lib/screens/workflows/workflow_execution_log_screen.dart | showDialog:469, showModalBottomSheet:509 | Pending complete rendered/state review |
| lib/screens/workflows/workflows_screen.dart | — | Pending complete rendered/state review |
| lib/widgets/account_deletion_card.dart | showDialog:25 | Pending complete rendered/state review |
| lib/widgets/app_empty_state.dart | — | Pending complete rendered/state review |
| lib/widgets/document_preview.dart | — | Pending complete rendered/state review |
| lib/widgets/job_profitability_card.dart | — | Pending complete rendered/state review |
| lib/widgets/premium_empty_state.dart | — | Pending complete rendered/state review |
| lib/widgets/status_chip.dart | — | Pending complete rendered/state review |
| lib/widgets/widgets.dart | — | Pending complete rendered/state review |
