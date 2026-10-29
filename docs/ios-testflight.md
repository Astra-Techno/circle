# Build CIRCLE for iPhone without a Mac

GitHub Actions provides the Mac. The owner needs a paid Apple Developer membership and browser access to Apple Developer, App Store Connect and GitHub. Never paste passwords, P12 files, P8 private keys or base64 private keys into chat/issues/source control.

## What is ready

[Run iOS build and TestFlight](https://github.com/Astra-Techno/circle/actions/workflows/ios.yml) → **Run workflow** → branch **main**.

- **validate** compiles the production iPhone app without Apple credentials. Its artifact is explicitly **UNSIGNED-NOT-INSTALLABLE**. It cannot be installed by tapping a website link.
- **testflight** first validates, then signs, verifies and uploads an App Store IPA using secrets in the **ios-testflight** GitHub environment. Apple processes it before testers can install it. Upload success is not TestFlight processing/review or device acceptance.
- The API is `https://circle.cloudkart24.com/api/v1`; preview is off. Android APK23 and the Android signing identity are unchanged.
- **iOS push notifications are currently disabled**, because the native notification-display/tap bridge supports Android only. Firebase/APNs and iOS bridge work is a separate task. Android-only contact/share tools also remain gated; ordinary in-app messaging and the copy-invite-link path remain available. Native iPhone behavior requires testing.

## One-time Apple setup (no Mac required)

1. In [Apple Developer](https://developer.apple.com/account/resources/identifiers/list), register an explicit App ID **com.circlecommunity.mobile**. If already owned elsewhere, stop and choose a new unique ID with the developer; the project, profile and verification checks must change together. Note the 10-character **Team ID** from Membership.
2. Generate a private RSA key and certificate signing request (CSR) using OpenSSL on a trusted Linux/Windows machine, or privately in this cloud environment. This does not require macOS. Example, in a private directory outside the repository:

   ```sh
   umask 077
   openssl req -new -newkey rsa:2048 -nodes \
     -keyout circle-ios-distribution.key \
     -out circle-ios-distribution.csr \
     -subj '/CN=CIRCLE iOS Distribution'
   ```

   Upload **only the CSR** to Apple's Certificates → **Apple Distribution**. Download the issued `.cer`. Retain the matching private key privately; do not generate a new identity every run (Apple limits active certificates).

3. Combine the downloaded certificate and original key into an encrypted P12, using a strong password at the prompt:

   ```sh
   openssl x509 -inform DER -in distribution.cer -out distribution.pem
   openssl pkcs12 -export -inkey circle-ios-distribution.key \
     -in distribution.pem -name 'CIRCLE Apple Distribution' \
     -out circle-ios-distribution.p12
   ```

4. In Profiles, create an **App Store Connect distribution** profile for this exact App ID and distribution certificate. Download the `.mobileprovision`. No iPhone UDID is needed for TestFlight.
5. In [App Store Connect](https://appstoreconnect.apple.com/), create the iOS app record for that bundle ID. Choose its name, primary language and an internal SKU such as `CIRCLE-IOS`. Complete agreements when requested.
6. In Users and Access → Integrations → App Store Connect API, create a **team API key** with an appropriate upload role (App Manager is suitable). Download the `.p8` once; note its **Key ID** and **Issuer ID**. An Account Holder/Admin may need to request API access. An APNs push key is different and cannot replace this upload key.

## Store credentials in GitHub, not in the repository

Repository Settings → Environments → create **ios-testflight**, restrict deployments to **main** and preferably require owner review. Add these environment secrets:

| Secret | Value |
|---|---|
| `IOS_TEAM_ID` | Apple Developer Team ID |
| `IOS_CERTIFICATE_BASE64` | Base64 of encrypted `.p12` containing certificate **and private key** |
| `IOS_CERTIFICATE_PASSWORD` | P12 export password |
| `IOS_PROFILE_BASE64` | Base64 of matching App Store `.mobileprovision` |
| `ASC_KEY_ID` | App Store Connect team API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_PRIVATE_KEY_BASE64` | Base64 of the `.p8` API private key |

Base64 is encoding, not encryption. Encode files privately into local files, then put those values directly into GitHub's secret UI or use `gh secret set --env ios-testflight NAME < encoded-file`. Do not print them into shared logs. `python3 -c 'import base64,pathlib; pathlib.Path("encoded.txt").write_bytes(base64.b64encode(pathlib.Path("your-file.p12").read_bytes()))'` creates a base64 file without displaying it. Delete temporary encoded files after the secret is saved; retain an encrypted/offline backup of the actual identity.

This environment's GitHub integration can read workflows but currently gets **403** when listing repository Actions secrets. That is a token permission limit, not evidence that secrets are absent. The owner may need to add secrets through GitHub's website.

## Build and install

1. Run the workflow from **main** with target **testflight**. Approve the environment deployment if you configured owner review. Missing credentials produce a list of missing secret names before signing.
2. The workflow uses Flutter3.44.8 and the newest stable Xcode installed on the macOS15 runner; their actual versions appear in logs. CocoaPods supports native dependencies that do not yet use Swift Package Manager.
3. iOS build numbers use `1000 + workflow run number`, followed by the rerun attempt: e.g. `1001.1`. Each new run/rerun increases the number; the marketing version comes from `mobile/pubspec.yaml`. If this app already has a higher build, change the offset before uploading. Review the sequence before its first component reaches10000.
4. It validates profile team/App ID/type/expiry, P12 membership and valid private signing identity. It signs in an ephemeral keychain and verifies the exported IPA signature, bundle/build and embedded profile. Signing material is removed in an always-run cleanup step. Only the IPA/checksum are uploaded as signed artifacts, retained7 days; credentials and keychains are not artifacts.
5. After Apple finishes processing, open App Store Connect → app → TestFlight. Resolve export-compliance questions truthfully; the workflow does not invent a legal encryption declaration. Add your own App Store Connect user as an **internal tester** and assign the build. External testers may require Beta App Review and additional metadata.
6. Install Apple's **TestFlight** app on the iPhone and accept the testing invitation. This first upload does not release CIRCLE publicly on the App Store. TestFlight builds normally expire after90 days.

Opening an App Store-signed IPA from a website does not install it. Use TestFlight. An App Store Connect upload can still be rejected for metadata, icon, SDK, privacy declarations or account requirements; inspect Apple's specific error before changing settings. Review the existing iOS icon/launch assets and App Privacy disclosures before inviting other testers or public release.

## Validation limits

Linux can lint workflow/configuration and test signing/profile validation helpers; it cannot run Xcode or prove an iPhone install. Record the actual GitHub macOS run outcome separately. No signing credentials are currently supplied here, so there is no signed IPA, TestFlight upload or phone/push verification from this setup alone.
