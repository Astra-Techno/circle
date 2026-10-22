# CIRCLE access design brief

Owner direction: anyone registers with mobile number + password; OTP later. Private circles for people who know each other, across family, friends, work, school and clubs. Registration and group membership are separate.

## Original design proposal

Warm paper, evergreen actions, generous whitespace, overlapping circular group illustrations, rounded cards and clear typography. Reuse CircleRoboto, semantic ColorScheme and Space tokens. No remote images, real people, generic college imagery, permissions on launch or forced optional profile setup. One primary action per screen; secondary text actions support existing users.

Screens: welcome; registration (optional display name, international mobile, password); login (international mobile, password); clearly labeled preview completion explaining create/join/accept-invitation paths. Password visibility and validation work; input is cleared after successful preview validation. The preview is deliberately separate from the earlier college fixture app and cannot grant access to it.

Run: `cd mobile`, then `flutter run -t lib/auth_design_preview.dart -d <device-id>` (or `-d chrome` for web-only review). No backend or account is created. Existing app entry point is unchanged while current uncommitted work is preserved.

## Design MCP status

Figma is registered and was authenticated in local Codex. No Figma/Product Design tools are exposed to this running conversation. Both integrations were discovered and offered for enabling. This proposal is original Flutter work, **not MCP-generated or derived from an approved Figma reference**. An MCP design review remains pending until one integration is enabled in this conversation; no inaccessible design file is assumed.

## QA

Fixed-font goldens for welcome, registration, login and dark registration at 393x852. Layout tests at 360x800, 393x852 and 900x1100, with 2x text and keyboard insets. Check tap targets, semantic labels, contrast, password visibility, empty/invalid input and input disposal. Native Android/iOS screenshots and human task tests remain separate requirements.
