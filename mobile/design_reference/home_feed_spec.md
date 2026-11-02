# Home Feed Design Specification

Extracted from: `design_reference/home_feed.png`

## Reference Image

- Source pixel dimensions: ~390x844 (estimated iPhone 14/15 Pro logical viewport at 3x)
- Target logical viewport: 393x852 (iPhone 15 Pro)
- Assumed device pixel ratio: 3.0
- Safe area top: ~59px (dynamic island), bottom: ~34px (home indicator)

## Scale Factor

The reference appears rendered at 3x on a ~390pt-wide viewport.
All pixel measurements below are in **logical points** (divide reference px by 3 if measuring raw pixels).

## Layout

### Background
- Primary background: white (`#FFFFFF`) — NOT the current lavender-grey `accents.recessed`
- Cards: white surface (`colorScheme.surface`) with subtle spacing
- Card separation: `Space.sm` (8pt) padding around each card

### Header (SliverAppBar, floating)
- Height: ~64pt (Space.hero * 2 = 64)
- Logo: 32x32 rounded square, left-aligned
- Title: "Circle" — headlineSmall (20pt/w600)
- Tagline: "My Circle. Billion Memories." — bodySmall (13pt/w400, caption color)
- Actions: Search, Notifications (bell with dot), Chat icons — 24pt icons
- Horizontal padding: Space.section (24pt)

### Composer Row
- Top padding: Space.md (16pt)
- Avatar: CircleAvatarSize.medium (~40pt diameter)
- Gap: Space.sm (8pt) between avatar and pill
- Pill: full capsule (borderRadius = height/2), background `accents.recessed`
- Pill text: "Share a memory with your Circle..." — bodyLarge (16pt), caption color
- Pill vertical padding: ~12pt
- Pill horizontal padding: Space.section (24pt)

### Quick Actions (4 tiles)
- Layout: Row with 4 Expanded tiles, Space.sm (8pt) gaps
- Each tile: rounded rectangle with pastel background (10% opacity of icon color)
- Tile height: NOT square — shorter, approximately 64pt tall
- Icon: centered, ~28pt (Space.hero = 32)
- **Label visible below icon**: "Photo", "Video", "Event", "Poll"
- Label: ~11pt (labelSmall/bodySmall), same color as icon
- Corner radius: CircleRadius.card (16pt)
- Colors: purple (Photo), red (Video), green (Event), amber (Poll)

### Memory Card
- Container: white surface, rounded corners (CircleRadius.card = 16pt)
- Vertical padding: Space.md (16pt)
- Author row: avatar (medium) + name (titleMedium/w600) + " shared a memory" (bodyLarge) + "..." menu
- Sub-line: "Circle Name · time" — bodySmall, caption color
- Caption text: bodyLarge (16pt), horizontal padding Space.section (24pt)
- Photo grid: horizontal padding Space.md (16pt), 16:10 single / 4:3 multi aspect
- Reaction summary: heart icon + count, comment icon + count
- Divider: hairline, Space.md indent
- Action row: 4 icon buttons (love, comment, share, bookmark) — spaceAround

### Floating Bottom Navigation (CRITICAL DIFFERENCE)
- **Must be a floating capsule** — NOT edge-to-edge
- Horizontal margin: ~Space.md (16pt) from each edge
- Bottom margin: above safe area (~8pt above home indicator)
- Height: ~64pt capsule
- Corner radius: CircleRadius.sheet (24pt)
- Background: white surface
- Border: hairline
- Shadow: soft, 8pt blur
- 5 destinations: Home, Circles, Create (raised purple circle), Events, Profile
- Selected: purple color, unselected: caption grey
- Labels visible below icons
- Create button: 48pt purple filled circle, raised above the bar

## Color Tokens (Light Mode)
- Surface/cards: `#FFFFFF`
- Background: `#FFFFFF` (NOT `#F5F5F8`)
- Primary: `#4930A7`
- Caption: `#6B6878`
- Hairline: `#ECECF2`
- Recessed: `#F5F5F8`
- Heart: `#FF4054`
- Video: `#E05252`
- Sage: `#3F7A68`
- Amber: `#D68F00`

## Typography (Roboto)
- headlineSmall: 20pt/w600 (title)
- titleMedium: 16pt/w600 (author name)
- bodyLarge: 16pt/w400 (body text, caption placeholder)
- bodySmall: 13pt/w400 (sub-lines, timestamps)
- labelSmall: 13pt/w400 (tile labels, tab labels)

## Known Differences (Estimate vs Measured)
- Quick action tile height: estimated ~64pt, not measured precisely
- Dock floating margin: estimated ~16pt, could be 12-20pt
- Dock shadow parameters: estimated from visual appearance
- Tab icon sizes: estimated 24pt
