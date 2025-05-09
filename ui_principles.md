# Choice App - UI/UX Principles & Guidelines

## 1. Introduction

This document outlines the UI/UX principles and guidelines for the Choice App. Its purpose is to ensure a cohesive, intuitive, and visually consistent user experience across all screens and features for both user-facing and producer-facing interfaces. This guide should be used by developers and designers to inform new development and to refactor existing components for better consistency.

## 2. General UI Philosophy

*   **Material Design Foundation:** The app should generally adhere to Material Design principles as a baseline, leveraging Flutter's built-in capabilities while allowing for a unique brand identity.
*   **Clarity & Intuitiveness:** Interfaces should be clear, easy to understand, and predictable. Users should be able to navigate the app and accomplish tasks with minimal cognitive load.
*   **Consistency:** Similar elements should look and behave similarly throughout the app. This applies to layout, typography, color, iconography, and interaction patterns.
*   **Accessibility:** Design with accessibility in mind, considering sufficient color contrast, touch target sizes, and support for screen readers where feasible.
*   **Modern & Engaging Aesthetic:** Aim for a clean, modern look and feel that is engaging and trustworthy, appropriate for a social discovery and B2B platform.
*   **Performance-Aware Design:** UI choices should consider performance implications to ensure a smooth and responsive experience.

## 3. Core Visual & Styling Guidelines

### 3.1. Color Palette

*   **Primary Color(s):** [Developer to define - e.g., #BrandBlue] - Used for main actions, AppBars, active states.
*   **Secondary Color(s):** [Developer to define - e.g., #BrandAccent] - Used for accents, secondary actions, highlights.
*   **Accent Color(s):** [Developer to define - e.g., #SpecialHighlight] - Used sparingly for calls to action or important highlights.
*   **Background Colors:**
    *   Light Theme: [Developer to define - e.g., #FFFFFF or #F5F5F5]
    *   Dark Theme: [Developer to define - e.g., #121212 or #1E1E1E]
*   **Text Colors:**
    *   Primary Text: [Developer to define - e.g., #212121 on light, #FFFFFF on dark]
    *   Secondary Text: [Developer to define - e.g., #757575 on light, #BDBDBD on dark]
    *   Error/Alert Text: [Developer to define - e.g., #D32F2F]
*   **Neutrals/Greys:** [Developer to define a range for borders, dividers, disabled states]

### 3.2. Typography

A consistent typographic scale should be defined and applied. (Consider using Material Design type scale names like `headlineSmall`, `titleLarge`, `bodyMedium`, `labelSmall`).

*   **Primary Font Family:** [Developer to define - e.g., 'Roboto' or a custom font]
*   **Font Sizes & Weights (Examples):**
    *   Screen Titles (AppBar): e.g., 20sp, Medium weight
    *   Card Titles: e.g., 16sp, Medium weight
    *   Body Text: e.g., 14sp, Regular weight
    *   Captions/Subtitles: e.g., 12sp, Regular weight
    *   Button Text: e.g., 14sp, Medium weight
*   *Action:* Define and implement these styles in `ThemeData`.

### 3.3. Layout & Spacing

*   **Grid System:** Consider using an 8dp grid system for consistent spacing and alignment.
*   **Margins & Paddings:** Establish standard values for screen margins, component padding, and spacing between elements (e.g., 4dp, 8dp, 12dp, 16dp, 24dp).
*   *Action:* Document these standard spacing values and encourage their consistent use.

### 3.4. Iconography

*   **Icon Set:** Primarily use Material Icons (available with Flutter). If custom icons are needed, ensure they match the Material style in terms of weight and simplicity.
*   **Sizing:** Use consistent icon sizes for similar contexts (e.g., 24dp for navigation icons, 16dp for inline text icons).
*   *Action:* Define standard icon sizes for different use cases.

### 3.5. Imagery & Media

*   **Aspect Ratios:** Define standard aspect ratios for images in feeds, profiles, and cards.
*   **Placeholders:** Use consistent, visually appealing placeholders for loading images/videos.
*   **Loading Indicators:** Use `CircularProgressIndicator` or `LinearProgressIndicator` consistently.

## 4. Recurrent UI Components & Styling Guidelines

### 4.1. Buttons

*   **`ElevatedButton`:** For primary, high-emphasis actions.
    *   *Style:* Consistent corner radius (e.g., 8dp or rounded), padding (e.g., `EdgeInsets.symmetric(horizontal: 16, vertical: 12)`), text style. Use primary color as background.
*   **`TextButton` / `OutlinedButton`:** For secondary or less prominent actions.
    *   *Style:* Consistent text styling. `OutlinedButton` should have consistent border thickness and corner radius.
*   **`FloatingActionButton (FAB)`:** For a single, primary screen action (e.g., "Create Choice," "New Message").
    *   *Style:* Consistent background color (usually accent or secondary), icon size.
*   **Icon Buttons:**
    *   *Style:* Ensure sufficient touch target size (at least 48x48dp including padding).
*   *Action:* Define styles for each button type in `ThemeData` and custom widgets if needed.

### 4.2. Cards

Used for: Feed items (Choices, Interests, Posts), producer summaries, map info windows, list items.
*   *Style:*
    *   Consistent corner radius (e.g., 8dp or 12dp).
    *   Consistent elevation or border for definition.
    *   Standardized internal padding.
    *   Clear visual hierarchy for content within cards (e.g., image, title, subtitle, actions).
*   *Action:* Create a base `ChoiceCard` widget or similar reusable card components.

### 4.3. Navigation

*   **Bottom Navigation Bar (`BottomNavigationBar`):**
    *   *Style:* Consistent icon style and size. Clear indication of active vs. inactive tabs (e.g., color change, label visibility).
*   **AppBars (`AppBar`):**
    *   *Style:* Consistent title alignment (e.g., `centerTitle: false`), text style. Consistent styling and placement for action icons.
*   **Tabs (`TabBar`):**
    *   *Style:* Consistent indicator style, label styling.

### 4.4. Input Fields (`TextField`)

*   *Style:*
    *   Use `InputDecoration` consistently (e.g., `OutlineInputBorder` or `UnderlineInputBorder`).
    *   Consistent corner radius if outlined.
    *   Clear label and hint text presentation.
    *   Standardized error message display and styling.
*   *Action:* Define a default `InputDecorationTheme` in `ThemeData`.

### 4.5. Dialogs & Modals (`AlertDialog`, `SimpleDialog`, `BottomSheet`)

*   *Style:*
    *   Consistent corner radius.
    *   Standardized padding.
    *   Consistent button placement (e.g., confirming actions on the right).
    *   Clear title and content styling.
*   *Action:* Style these through `DialogTheme`, `BottomSheetThemeData`.

### 4.6. List Items

Used in search results, message lists, settings screens, etc.
*   *Style:*
    *   Consistent vertical and horizontal padding.
    *   Consistent use of dividers (`Divider`) if needed.
    *   Alignment of leading/trailing widgets (e.g., icons, avatars, switches).
    *   Clear differentiation between interactive and non-interactive list items.
*   *Action:* Create reusable `ListTile` based widgets if customization beyond standard `ListTile` is frequent.

### 4.7. Avatars / Profile Images

*   *Style:* Consistent shape (e.g., circular). Consistent default placeholder image or initials. Standardized sizes for different contexts (e.g., small in comments, medium in lists, large on profile screens).
*   *Action:* Create a `UserAvatar` widget.

### 4.8. Rating Displays (Stars, etc.)

*   *Style:* Consistent star icon (filled, half, empty). Consistent color for active/inactive stars. Consistent size in different contexts.
*   *Action:* Create a `RatingWidget`.

## 5. Potential Inconsistencies to Review & Address

This list is based on common development patterns and should be verified by a visual audit of the app:

*   **Button Usage:**
    *   Are `ElevatedButton`, `OutlinedButton`, and `TextButton` used consistently for actions of similar hierarchical importance?
    *   Do all buttons of the same type share the same padding, corner radius, and text style?
*   **Corner Radii & Borders:**
    *   Are corner radii consistent across cards, buttons, input fields, dialogs?
    *   Is border thickness and color consistent where used (e.g., `OutlinedButton`, `Card` with border)?
*   **Spacing & Padding:**
    *   Is there consistent spacing between elements on screens? (e.g., between a title and content below it).
    *   Is padding within components (like cards, list items) uniform?
*   **Typography Application:**
    *   Is the defined typographic scale (e.g., `headlineSmall`, `bodyMedium`) consistently applied to semantically similar text elements across all screens?
*   **Card Design Variations:**
    *   Do cards representing "Choices," "Interests," producer posts, and other listable items share a common base design language, or do they vary significantly without clear reason?
*   **Iconography Details:**
    *   Are all icons from the same family (preferably Material Icons)?
    *   Is icon sizing consistent for their context (e.g., icons in AppBars vs. icons next to text)?
*   **Theme (Light/Dark Mode):**
    *   Do all custom widgets and screens correctly adapt to theme changes?
    *   Are text and background color contrasts sufficient in both themes?
*   **Empty States & Loading Indicators:**
    *   When a list is empty or data is loading, is the visual feedback (e.g., message, spinner) presented consistently across different screens?
*   **Interactive Feedback:**
    *   Is ripple effect or other touch feedback consistent for all interactive elements?

## 6. Recommendations for Developer / Action Plan

1.  **Visual Audit:** Conduct a thorough visual review of all screens in the application on a device/emulator, specifically looking for the potential inconsistencies listed above. Take screenshots.
2.  **Define Specifics:** Fill in the bracketed placeholders in Section 3 (Colors, Typography, etc.) with the chosen design tokens.
3.  **Theme Implementation:** Centralize all common styles (colors, typography, button styles, input decorations, dialog themes) in the app's main `ThemeData` objects (`lib/theme/theme.dart` or similar).
4.  **Reusable Component Library:**
    *   Identify frequently used UI patterns that are not covered by standard Flutter widgets (e.g., specific card layouts, `UserAvatar`, `RatingWidget`).
    *   Develop a library of these custom reusable widgets that encapsulate consistent styling and behavior.
5.  **Refactor Existing Screens:** Incrementally refactor existing screens and widgets to adopt the defined theme styles and use the reusable components.
6.  **Documentation & Style Guide:**
    *   Consider using a tool like Widgetbook or Storybook for Flutter to visually document reusable widgets and their variations.
    *   Maintain this `ui_principles.md` document as the source of truth for UI/UX decisions.
7.  **Pull Request Reviews:** Incorporate UI/UX consistency checks into the PR review process.

By following these guidelines and actively working to resolve inconsistencies, the Choice App can achieve a more polished, professional, and user-friendly experience. 