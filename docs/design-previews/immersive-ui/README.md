# Immersive root navigation review — 30 October 2026

Fictional, local test data only. These render the real application widgets through the test harness, not a prototype or production-account screenshot. Home at393px/light/100% and Groups at320px/dark/200% are representative samples. Full review generated nine Home/Groups/You combinations including900px/dark/200%. Header regression separately exercises Chats single title/create action and down/up behavior. Full conversations retain their own header/composer.

Reproduce with CIRCLE_CAPTURE_UI=true flutter test test/chrome_review_test.dart from mobile/. No Windows golden baseline regenerated. No physical-device acceptance inferred. Photos here are fictional test scenes; live server-photo failures remain unverified behind the execution proxy's CONNECT403. New retry evicts failed image cache and obtains a fresh scoped signed URL.
