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
