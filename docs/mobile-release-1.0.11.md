# Android 1.0.11 build 12 — contact-first invitations

27 October 2026. Main was pulled through ad0578d before continuation. Incoming build11/design samples were preserved; invitation routes were merged with the incoming push diagnostic route. The older diagnostic PHP page was corrected to use display_name and the current string PushResult status; its route was made analyzer-clean. No diagnostic send was invoked during verification.

This release adds single-contact invitations, explicit recipient acceptance/decline, persistent inbox and invitation push handling. Registered eligible contacts receive a CIRCLE invitation; unregistered/inactive contacts can receive an external WhatsApp/SMS link. Copy invite link works without selecting a contact. Parent/ban/removal/approval rules remain server-enforced. See [implementation and privacy](contact-invite-sharing.md).

Build: production HTTPS API, CIRCLE_PREVIEW=false, CIRCLE_PUSH_ENABLED=true. Source retains optional explicit push opt-in; settings permission/preferences still apply. Original application id and beta signing identity are required. No broad contacts or automatic SMS permission is added.

Validation: dedicated circle_test184 tests /3,087 assertions; PHPStan, Composer validation and PHP syntax checks clean. OpenAPI0.3.7 has333 resolved internal references. Flutter full613 passed /1 skipped /13 existing Windows-baseline golden failures on Linux; final invite/push/design subset48 passed. Dart formatting/analysis clean. Four invite-screen phone/tablet light/dark200% renders inspected. Approved goldens untouched. Native installation/contacts/composers and actual OS push delivery remain owner acceptance; no device is connected.

Artifact and hosted integrity results will be recorded after packaging/deployment. Keep all earlier immutable APKs. This batch includes source password-change API foundation but does not add its pending mobile form or turn preview chat/events into live services.

Packaged: 65,015,086 bytes; SHA256 `8c1047e10c97c9e73914ab97fdaf88728a1b79d156bdc0359fd03e600976b59e`. APK reports com.circlecommunity.mobile, versionName1.0.11/versionCode12, minSdk24/targetSdk36. Original certificate verified; no READ_CONTACTS/WRITE_CONTACTS/SEND_SMS. Build140.4s. Stable/immutable APKs match release.json and both site buttons. Earlier immutable artifacts preserved. Deployment not yet verified.
