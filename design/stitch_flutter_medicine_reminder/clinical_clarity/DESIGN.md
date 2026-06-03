---
name: Clinical Clarity
colors:
  surface: '#f8fafa'
  surface-dim: '#d8dada'
  surface-bright: '#f8fafa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f4'
  surface-container: '#eceeee'
  surface-container-high: '#e6e8e8'
  surface-container-highest: '#e1e3e3'
  on-surface: '#191c1d'
  on-surface-variant: '#3e4946'
  inverse-surface: '#2e3131'
  inverse-on-surface: '#eff1f1'
  outline: '#6e7a76'
  outline-variant: '#bdc9c5'
  surface-tint: '#006b5e'
  primary: '#005e53'
  on-primary: '#ffffff'
  primary-container: '#00796b'
  on-primary-container: '#a1feec'
  inverse-primary: '#7ad7c6'
  secondary: '#632ce5'
  on-secondary: '#ffffff'
  secondary-container: '#7c4dff'
  on-secondary-container: '#fcf6ff'
  tertiary: '#9a2a00'
  on-tertiary: '#ffffff'
  tertiary-container: '#bd4117'
  on-tertiary-container: '#ffe8e2'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#97f3e2'
  primary-fixed-dim: '#7ad7c6'
  on-primary-fixed: '#00201b'
  on-primary-fixed-variant: '#005047'
  secondary-fixed: '#e8deff'
  secondary-fixed-dim: '#cdbdff'
  on-secondary-fixed: '#20005f'
  on-secondary-fixed-variant: '#4f00d0'
  tertiary-fixed: '#ffdbd0'
  tertiary-fixed-dim: '#ffb59f'
  on-tertiary-fixed: '#3a0a00'
  on-tertiary-fixed-variant: '#852300'
  background: '#f8fafa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e3'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
  container-margin: 20px
  gutter: 16px
---

## Brand & Style
The brand personality focuses on **calm reliability, medical precision, and human warmth**. This design system is tailored for patients and caregivers who require a stress-free interface for managing health routines. 

The aesthetic follows a **Corporate / Modern** style with a focus on high legibility and soft interaction points. It utilizes generous whitespace to reduce cognitive load, ensuring the user feels in control rather than overwhelmed by clinical data. The visual tone is approachable yet authoritative, establishing immediate trust through systematic alignment and a soothing color palette.

## Colors
The palette is anchored by **Deep Teal (#00796B)**, chosen for its psychological association with health, stability, and professional care. 

- **Primary (Teal):** Used for branding, primary navigation, and "safe" status indicators.
- **Secondary (Amethyst):** A soft, specialized purple used for "Take Action" events, such as logging a dose, to distinguish medication events from general navigation.
- **Tertiary (Coral):** Reserved specifically for urgent alerts, missed doses, or critical health warnings.
- **Neutrals:** A range of cool grays (starting at #F5F7F7) provides a clean backdrop that feels sterile but not cold.

**Dark Mode Strategy:** Transitions to a deep charcoal-teal base (#121212) to reduce eye strain for nighttime dose logging. Surfaces use a slightly lighter tint (#1E2928) to maintain depth.

## Typography
This design system utilizes **Inter** for its exceptional legibility and neutral, systematic appearance. 

- **Hierarchy:** High contrast between headlines and body text ensures that medication names (Headlines) are immediately distinguishable from instructions (Body).
- **Accessibility:** Minimum body size is set to 16px to accommodate users with varying visual acuity. 
- **Labels:** Uppercase or semi-bold labels are used for metadata like "Dosage" or "Time" to facilitate quick scanning of medical schedules.

## Layout & Spacing
The layout follows a **Fluid Grid** model optimized for mobile-first interactions. It employs an 8pt spacing system to maintain mathematical harmony.

- **Mobile:** A 4-column grid with 20px side margins. 
- **Touch Targets:** All interactive elements (buttons, checkboxes) must maintain a minimum height of 48px to ensure accessibility for users with limited dexterity.
- **Rhythm:** Generous vertical padding (24px+) is used between medication cards to prevent "clinical clutter" and help users focus on one task at a time.

## Elevation & Depth
Depth is created through **Tonal Layers** rather than heavy shadows to keep the interface looking clean and modern.

- **Level 0 (Background):** The base neutral color.
- **Level 1 (Cards):** Use a very subtle, highly diffused shadow (0px 4px 20px, 4% opacity black) and a 1px soft border (#E0E6E6) to define pill and schedule cards.
- **Level 2 (Active States/Modals):** Increased shadow spread (0px 8px 30px, 8% opacity) to signify focus.
- **Interactions:** When a user taps a "Take" button, the element should visually depress (lower elevation) to provide tactile feedback.

## Shapes
The shape language is **Rounded**, conveying a sense of safety and approachability. 

- **Standard Elements:** Buttons and input fields use a 0.5rem (8px) radius.
- **Cards:** Medication cards use a larger 1rem (16px) radius to feel like distinct, friendly containers.
- **Progress Indicators:** Use fully rounded (pill-shaped) ends for progress bars and status chips to mimic the physical shape of many medications.

## Components
- **Action Buttons:** The primary "Take Dose" button should be a high-contrast Amethyst (#7C4DFF) with white text. Use a large, full-width "floating" style for the most critical daily action.
- **Medication Cards:** Feature a large icon slot on the left, the medication name in `headline-sm`, and the timing in a `label-md` badge.
- **Progress Indicators:** Circular rings for daily completion percentages; linear bars for prescription refills.
- **Chips:** Small, rounded indicators for status (e.g., "Taken", "Skipped", "Upcoming"). "Taken" uses a Teal background, "Skipped" uses a soft Grey.
- **Input Fields:** Underlined or lightly boxed with 8px corner radius. Labels should always be visible above the field to prevent confusion during data entry.
- **Iconography:** Use a 24px bounding box for all icons. Stroke weights should be 1.5px or 2px (matching Inter’s medium weight) to ensure they feel part of the typographic system.