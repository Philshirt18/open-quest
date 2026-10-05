---
doc: design
status: approved
---

# Open Quest — Design

## References
- [Arc docs](https://docs.arc.io/): modern, minimal, light headings, blue accents, lots of whitespace, native dark mode. Used as inspiration for the feel, not copied. [proposed, accepted by user]

## Feel
Calm, clear, trustworthy, a little playful. A newcomer should always know the one next thing to do.

## Typography
- Headings and body: Space Grotesk (Google Fonts). Headings light (300), body regular (400), buttons medium (500). [proposed, accepted]
- Mono (addresses, transaction hashes, code example): system monospace stack. [proposed, accepted]
- Scale: 14 / 16 / 20 / 28 / 40 px. [proposed]

## Color
Light (default): [proposed, accepted]
- Background `#FFFFFF`, surface `#F5F7FA`, text `#0F172A`, muted text `#5A6A80` (darkened from `#64748B` in the build to reach WCAG AA on the grey surface)
- Primary `#4D8EE9`, accent `#5FBFFF`
- Success `#15803D` (darkened from `#16A34A` in the build to reach WCAG AA), warning `#B45309` (darkened from `#D97706` for text contrast), error `#DC2626`. Buttons and the active number use a darker blue `#2F6FCF` for contrast; `#4D8EE9` stays the main brand blue for borders and hover.

Dark (follows system setting): background `#0B1020`, surface `#141B2D`, text `#E6EAF2`, muted `#94A3B8`, same primary and accent, status colors lightened if needed for contrast. [proposed, accepted]

## Spacing, Shape, and Density
- 8px spacing grid, wide padding around cards, airy layout. [proposed, accepted]
- Corner radius 16px on cards, 10px on buttons. 1px border, almost no shadow. [proposed, accepted]

## Components and Motion
- Quest card: large, with a number, a title, one plain sentence and one button. Active: blue border and the only bright button. Locked: greyed out with a short reason. Done: green check, fee in dollars, explorer link.
- Banner for network switch, subtle and clearly actionable.
- Badge display: simple, centered, with the level shown clearly.
- Motion: about 150 ms, such as the check mark appearing and button press. Nothing flashy. Respect reduced-motion settings.

## Responsive and Accessibility
- Mobile-first, single column; wider screens center the content at a readable width (about 720px).
- Touch targets at least 44px; text contrast at least WCAG AA; visible keyboard focus; status never by color alone (icons and text too).

## Voice and Tone
Short, friendly, plain words. "Network fee" instead of "gas". Say what happens next ("Confirm in your wallet"). Errors say what went wrong and what to do.

## Output Format
Not applicable (no CLI or agent).

## Must Not Look Like
A neon crypto dashboard, a purple-gradient AI landing page, or a cluttered page with many badges and numbers.
