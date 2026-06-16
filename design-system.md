# Unplug — Design System

## Spacing Scale

All spacing values (margins, padding, gaps) must come from this scale. No arbitrary values.

```
4  8  12  16  24  32  48  64
```

Base unit: **16px**. The scale is non-linear — tight at small values where a few pixels matter, wider at large values where small differences are invisible.

### Usage Guidelines

- **Within a group** (e.g., icon + label): 4 or 8
- **Between related elements** (e.g., label and its input): 8 or 12
- **Between sections**: 16 or 24
- **Major separations** (e.g., content area to pinned buttons): 32 or 48
- **Screen-edge horizontal padding**: 16 (standard iOS inset)

### Grouping Rule

Space within a group must always be less than space between groups. If a label is 8px from its input, the gap between that input group and the next section must be at least 16px.

## Typography

Using system fonts. Scale:

```
12 (caption) · 14 (footnote) · 16 (body) · 18 · 20 (title3) · 24 (title2) · 34 (largeTitle)
```

## Colors

Defined in `Style.swift`:

- **Primary**: `rgb(105, 87, 232)` — purple, used for buttons and accents
- **Error**: `rgb(248, 106, 106)` — red, used for error toasts
- **Font**: `rgb(240, 244, 248)` — light, used on dark backgrounds
- **Background**: `rgb(94, 208, 250)` — light blue (currently unused in main UI)

## Button Styles

- **Primary action**: gradient fill (primaryColor → purple), white text, 12px vertical / 32px horizontal internal padding, 12px corner radius
- **Secondary action**: solid fill (primaryColor or .secondary when disabled), same dimensions
- **Between stacked buttons**: 8px gap
- **Button stack pinned to bottom** with 16px bottom padding

---
*Based on spacing system from Refactoring UI by Adam Wathan & Steve Schoger*
