# Invitation entry

Android and iOS register `circle://invite/<token>` with Flutter deep linking.
Router normalization preserves token case and converts only safe tokens into
`/invite/<token>`. Signed-out users resume the invitation after authentication;
opening a link never joins a group without the existing invitation consent flow.
Clipboard entry remains available when a browser does not launch custom schemes.

The router also understands `https://<configured-api-host>/i/<token>` when passed
an incoming URI. This does not configure verified Android App Links or iOS
Universal Links: those require hosting association documents, a stable Android
signing certificate and the actual Apple team identifier. No such verification
or physical-device cold/warm-start validation is claimed by widget tests.

Live navigation shows Home, Groups and You. Chats and Events remain in the
fictional preview; direct routes still show the capability gate on live builds.
