---
name: Quote on the Go
description: Warm, clear business tools for the next job.
colors:
  primary: "#F4781F"
  ink: "#24251F"
  canvas: "#FBF8F2"
  cream: "#F0EBDD"
  muted: "#67675E"
  outline: "#858477"
  divider: "#D9D4C7"
  dark-canvas: "#1D1E19"
  dark-panel: "#2B2D25"
  dark-muted: "#C1C2B5"
typography:
  headline:
    fontFamily: "DM Sans, sans-serif"
    fontSize: "36px"
    fontWeight: 800
    lineHeight: 1.12
    letterSpacing: "-1.2px"
  section:
    fontFamily: "DM Sans, sans-serif"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.25
  title:
    fontFamily: "DM Sans, sans-serif"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1.3
  body:
    fontFamily: "DM Sans, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.45
  supporting:
    fontFamily: "DM Sans, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
rounded:
  field: "16px"
  row: "20px"
  panel: "24px"
  pill: "999px"
spacing:
  small: "8px"
  medium: "16px"
  panel: "20px"
  page: "24px"
  section: "32px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "16px 24px"
    height: "56px"
  panel:
    backgroundColor: "{colors.cream}"
    textColor: "{colors.ink}"
    rounded: "{rounded.panel}"
    padding: "20px"
  field:
    backgroundColor: "{colors.cream}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    padding: "18px"
---

# Design System: Quote on the Go

## Overview

**Creative North Star: "Ready for the next job"**

A UK trader checks the app in daylight between appointments, looking for the next useful action. The interface should feel dependable, friendly and warm. Use a restrained orange accent, generous space, clear headings and practical language. Retain the user's dark-mode preference for evening work.

The user approved orange with cream surfaces on 9 September 2026. The supplied Marshmallow screenshots inform the large personal greeting, simple tonal panels, generous rounded controls and clear grouping. Ragged Edge's [Marshmallow case study](https://raggededge.com/partnerships/marshmallow) describes an empathetic identity, confident voice and distinctive headline typography applied across app, web and communications. Our adaptation takes the hierarchy and clarity; it retains Quote on the Go's identity and does not reuse Marshmallow's proprietary typeface, mascots or artwork. The [official Android listing](https://play.google.com/store/apps/details?id=com.marshmallow.marshmallow) groups useful policy, document and support tasks; the corresponding business tasks here are documents, payments and jobs. These are design observations and product adaptations, not a claim that the two products should share features.

**Key characteristics:**

- One clear primary action in each task area.
- Flat panels for related information, open rows for individual actions.
- Honest loading, failure and empty states, with recoverable actions.
- Native Material 3 interaction semantics with the same visual system on Android and iOS.
- Bounded content width (640 logical pixels) and wrapping text on narrow screens.

This specification describes the implemented mobile home, shared theme, buttons, panels and navigation. Older screens still contain local styling overrides; migrate them incrementally. The older PRODUCT.md font/palette paragraph records the previous web brief. This file supersedes that paragraph for the new direction: mobile already used DM Sans, so it is retained and bundled locally under its [SIL Open Font License](https://github.com/google/fonts/tree/main/ofl/dmsans). Web adoption is prepared below; the web UI has not been restyled in this change.

## Colors

The YAML values are the sRGB source of truth used by Flutter's Color constants. The JSON sidecar supplies equivalent OKLCH metadata for design tooling.

### Primary

**Orange** is a primary-action fill and selected-control accent. Put ink labels on orange: the pair passes 4.5:1 contrast. Do not put small orange text on cream, or white text on orange. Native focus and pressed overlays must remain visible.

### Neutral

**Canvas** is the warm page background. **Cream** groups related document information. **Ink** carries headings and primary copy. **Muted** carries supporting copy and passes 4.5:1 on cream. **Outline** identifies fields; **divider** separates rows within a group.

Dark mode uses dark canvas, dark panel, cream foreground and dark muted supporting text. Semantic success, warning and error retain their distinct meanings through the existing SemanticColors extension. Always accompany status color with words or an icon and an accessible label.

**The action-color rule.** Use orange to identify what the user can do, not to decorate every number or heading.

## Typography

**Display and body:** locally bundled DM Sans. Native units are scalable logical pixels; web equivalents use rem. Use system sans-serif only as an explicit fallback.

- Headline: personal greeting or screen introduction; allow wrapping.
- Section: business, attention and schedule grouping.
- Title: document destination or job name.
- Body: instructions and form content.
- Supporting: document references and secondary details.
- Navigation: 12px, weight 600. Do not use this size for main task content.

Use sentence case and plain verbs: “Create quote”, “Create invoice”, “Review and save expense”. No all-caps paragraphs or invented dashboard jargon. Keep reading text to 65–75 characters per line on web. Never disable the platform text scaler to make a layout fit.

## Elevation

Panels are flat at rest. Tone and spacing establish grouping; shadows and background blur do not establish importance. The shared GlassCard name is retained for compatibility, but its implementation is an opaque Material surface with visible InkWell feedback. MeshBackground now paints a plain themed canvas rather than a gradient.

Use native elevation only for temporary menus, sheets and other surfaces whose position actually changes. No decorative glows, floating shadows around every card, or nested tonal cards.

## Components

### Home composition

Order: utility controls, greeting and date, business summary, primary create action, real attention items, today's schedule, then client responses and Analytics. Search expands inline from a labelled toolbar action. Attention items are capped at three with an inline “Show all” control. Overdue tasks use invoice due dates; accepted quotes already linked to invoices are excluded when the invoice is in the loaded dataset. Jobs use local calendar dates.

The old duplicated KPI chips, insight carousel, revenue summary and status overview have been consolidated into document lists and Analytics. The revenue and quote charts remain available in Analytics under “Six-month trends”. Recent documents remain accessible in the quote and invoice lists. Job actions remain on the job detail screen. Billing remains in settings/navigation; it no longer occupies permanent home navigation space.

### Buttons

Primary: orange fill, ink label, pill shape, minimum 56px height and 24px horizontal padding. One primary button for the main task. Secondary: outlined neutral control. Tertiary: native text button. Disabled and loading controls cannot submit again. Keep keyboard focus, pressed states and screen-reader semantics. The existing PillButton compatibility component has a 52px minimum and expands for text; new screens use the 56px theme default.

### Panels and action rows

Panels: cream or dark panel, 24px corners, 20px padding, no default border or shadow. HomeActionRow: 26px leading icon, 16px gap, flexible title/subtitle, 20px chevron and 20px vertical padding. The entire row opens the destination. Text wraps; do not force a fixed row height. Show details on the next screen rather than squeezing multiple small buttons into the row.

### Inputs and feedback

Fields: filled tonal surface, 16px corners, persistent labels, 18px padding, visible one-pixel outline and two-pixel ink focus outline. Use explicit validation messages near invalid fields. Financial forms must preserve discounts, tax defaults, document links and PDF options across edits.

Loading must not display an empty-business claim. A failed business or schedule stream shows “Try again”; it must not claim there are no jobs or no payments due. Refresh includes quotations, invoices and schedule. Receipt extraction opens an editable review form and retains the selected image. Foreign receipt currencies must not silently become GBP.

### Navigation and responsive behavior

Use an opaque native NavigationBar with Home, Schedule, Customers and Settings. The main home create action replaces the duplicate floating plus button on Home; other shell screens retain a labelled create control. Secondary tools remain in the drawer. Toolbar icons have tooltips and at least 48px tap targets.

The Settings tab is the account hub: profile summary, account/app settings, notifications, team, workflows, support and billing. The dashboard no longer repeats the profile icon. Detailed preferences use the same separate cream action rows and plain ink icons as the hub. Settings and Analytics do not carry an unrelated floating document-create button.

### Authentication and date selection

Authentication pages share the existing QOTG brand mark, a left-aligned headline, warm filled fields with persistent labels and one orange primary button. Forms scroll and cap at 560 logical pixels. Passwords preserve spaces exactly. Keep autofill, show/hide password, keyboard submission and inline recoverable errors. Verification uses one pasteable six-digit field. Splash branding must not impose an artificial wait after initialization.

Date/time sheets scroll as a whole and show all calendar weeks. Preserve the exact initial time until the user edits it. Selecting a delivery date returns to the composer; sending or scheduling requires the composer's explicit primary action.

Phone pages have 24px side padding. The home column is capped at 640px on tablets. Content scrolls under large text rather than clipping. Respect safe areas and reduced-motion preferences; do not add entrance choreography. Native interaction transitions should be short (roughly 150–250ms). Decorative motion is unnecessary here.

### Web adoption

Map these primitives to the web theme before restyling screens. Use the same information order and language, but retain desktop navigation and appropriate wide tables. Do not stretch the mobile panel into a full-screen desktop card. Document forms can use two columns above 960px, with tab order matching the visual order, and collapse to one column below that width.

```css
:root {
  --qotg-primary: #f4781f;
  --qotg-ink: #24251f;
  --qotg-canvas: #fbf8f2;
  --qotg-panel: #f0ebdd;
  --qotg-muted: #67675e;
  --qotg-outline: #858477;
  --qotg-panel-radius: 1.5rem;
  --qotg-page-space: 1.5rem;
  --qotg-font: 'DM Sans', sans-serif;
}
[data-theme='dark'] {
  --qotg-canvas: #1d1e19;
  --qotg-panel: #2b2d25;
  --qotg-ink: #fbf8f2;
  --qotg-muted: #c1c2b5;
}
```

Primary button labels stay dark ink in both themes; do not use the inverted body ink variable for that label. Native components are authoritative in lib/theme/app_theme.dart, lib/theme/design_tokens.dart and lib/screens/dashboard/dashboard_screen.dart. DESIGN.json provides framework-free web component previews, not a replacement for accessible native controls.

## Forms, recovery and customer communication

### Profile and settings rows (approved mobile reference)

The user's latest Marshmallow reference refines the mobile component style while retaining Quote on the Go's existing content and actions. Settings remains the bottom-navigation account hub; retain the real profile identity, permission-based destinations and all detailed preferences.

- Separate destinations into individual flat cream panels, with 24px corners, a 72px minimum height, 20px horizontal / 18px vertical padding and 12px gaps. Rows grow with wrapped labels and descriptions.
- Use plain 26px ink icons without a second icon tile; use muted 26px chevrons. Whole rows are tappable. Labels use DM Sans 18px medium; optional descriptions use muted 14px text.
- Use bold 32px section headings, 18px space below and 28px above subsequent sections. Keep 24px page gutters. Preserve the account avatar's restrained orange tint.
- Sign out uses the same destination row and retains its confirmation. Appearance opens a scrollable, themed single-choice sheet; persist System, Light and Dark correctly.
- Dark mode uses the existing dark canvas/panel tokens. Do not import the reference app's insurance labels, passkey features or version number.

Implemented in SettingsActionRow, SettingsSectionHeading, ProfileMenuScreen and SettingsScreen. Four light/dark hub/preferences renders were inspected; large-text coverage includes opening and selecting the appearance sheet.

### Shared interaction rules

- Onboarding navigation uses vertically arranged controls with minimum rather than fixed heights. Pair fields only when enough width remains at the user's text size. Template names wrap; colour swatches have named tooltips, selected state and 48px hit targets. Show an honest review step before saving, and preserve every field the form collects.
- Document thumbnails are labelled as sample styles; their print-scale typography does not dictate interface text size. PDF preview loading stays visible until the renderer reports completion. Error and retry panels scroll within short viewports and do not claim a percentage the app cannot measure.

- Quotes and invoices keep a local draft scoped to the signed-in user, company and document context. Show explicit Restore draft / Start fresh choices. Never label local persistence as server sync. Keep write failures visible and provide a deliberate way to leave or discard an unreadable copy.
- Settings is the bottom-navigation account hub. Detailed preferences use the same wrapping action rows. Account setup, invitations and deletion recovery use the shared AuthPage or matching brand header, restrained progress indicators and native themed controls.
- Analytics content grows vertically at large text sizes. Recorded margin means paid invoice totals minus eligible recorded GBP expenses, using document dates. Label tax inclusion, unavailable expense data and excluded currencies. Keep forecasts visibly labelled as estimates.
- Web and mobile reporting periods use complete UTC dates, including today, for 30/90/180/365-day selections. Exports state the same basis as the screen. Missing cost attribution or performance telemetry is unavailable, not a made-up percentage. Closed documents do not contribute to open pipeline value.
- Immediate sends, scheduled sends and email previews use composeDocumentEmail. Mobile opens the read-only server HTML in a JavaScript-disabled preview; web uses a sandboxed iframe. Email clients may adjust fonts/colours, so preview is a rendering of the HTML rather than a guarantee of identical pixels in every inbox.
- Customer email uses cream canvas, a rounded company header, readable text, an orange action with dark ink and a quiet footer. Use broadly supported system fonts in email. Preserve actual company identity, amounts, dates, bank details and portal links. Escape all entered text and replace merge tags once, including in subjects.
- Automatic reminders share the email presentation but describe a portal link rather than a nonexistent PDF attachment. Opening the user's own email app shares plain text and a link; it is not the same HTML delivery path.
- Native integration actions show busy, result and partial-failure states. OAuth returns use the integration route and a fixed success/error code; account credentials never belong in a return URL.

The implementation/verification ledger is UI_ALIGNMENT_PROGRESS.md. These rules are reusable by the web app; they do not imply every existing screen has already been visually verified.

## Do's and Don'ts

### Do

- Do make the next action obvious with one orange primary control.
- Do use a 24px page gutter and 32px section spacing on home.
- Do keep dates, amounts and workflow status honest and recoverable.
- Do support keyboard, screen reader, dark mode and 200% text.
- Do test empty, loading, error, long-name, overdue and multi-job states.

### Don't

- Don't recreate the messy dashboard with repeated metrics and multiple equally loud CTAs.
- Don't add unnecessary visual noise and decoration; preserve PRODUCT.md's “Clean, minimal, and distraction-free” direction.
- Don't use glassmorphism, decorative gradients, nested cards or colored side-stripe borders.
- Don't replace clear labels with unexplained icons or tiny text.
- Don't label an assumed profit margin as measured profit.
- Don't copy Marshmallow's mascots or treat this spec as proof of complete web/mobile functional parity.

## Reminder settings and previews

- Both apps preview the server's composeReminderEmail output. Settings previews use explicitly labelled sample customer/invoice/date data and the signed-in company's real branding. Previewing is read-only; unsaved text can be reviewed without sending or changing settings.
- A reminder message is the full body, not an appended note. Blank text selects the common server default. Preserve user-authored templates. Automatic reminders contain a portal link; manual reminders attach the PDF as well. Use “View invoice” without promising a payment method that may not be configured.
- The mobile reminder form uses warm panels, bold section headings, wrapping controls and a collapsible placeholder reference. Keep enabled and disabled schedule rules when saving. Both clients and server accept up to 12 distinct days from 1 to 365 and messages up to 10,000 characters.
- Load errors expose a retry before editing is available; save errors preserve changes. Preview metadata scrolls instead of squeezing the email viewport at large text sizes. Sample email HTML is shared across web and mobile; native WebView/device rendering still needs runtime verification.

## Offline document saves

- Quote and invoice editors distinguish automatic local recovery from an explicit queued save. Save draft and Save & preview first persist an immutable request on this device. The server-confirmed state is the only state labelled saved to your company.
- Saved requests is available from Settings and from a navigation notice when work is pending. Use cream panels, wrapping status copy, Retry save, Open current document and View saved changes. The saved-changes dialog scrolls and supports text selection. Keep server errors visible beside the affected request.
- Connection failures retry about every 30 seconds while the app is open. Signing into the same account restores its queue; a different account or company cannot inherit it. The app does not promise background delivery after it is closed.
- Every request retains its document/request identity across retries and restarts. A server receipt, the document and any required approval/notifications are committed together. A repeated request must never reset a later payment or approval. An older approval must not approve a newer document revision.
- Editing retains the server version that the draft originally came from. If another device changes it, keep the saved copy and ask the user to review the current document. Do not silently overwrite newer work. The current conflict UI supports reviewing/copying saved changes; guided merging remains a follow-up.
- Primary save controls use the theme's dark ink on orange and grow with text. Stack Save & preview and Save draft on phones. Preview opens after server confirmation; it does not send email.


### Document copies and conversions

- Duplicate invoice, duplicate quotation and quotation-to-invoice actions use the same Saved requests destination as editor saves. Do not announce server success until the queue has a server acknowledgement.
- While an action is pending or failed, repeating it reopens the same immutable request, including after an app restart. A new deliberate action after a confirmed save may create another draft. Copies retain customer/job links, discounts, notes, title and template choices; payment, approval and external integration state is not copied.
- Starring, archiving through metadata, and lock metadata do not restart approval. Content changes by a member still request review.
