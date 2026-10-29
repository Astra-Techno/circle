# Build CIRCLE for iPhone without a Mac

GitHub Actions provides the Mac. The owner needs a paid Apple Developer membership and browser access to Apple Developer, App Store Connect and GitHub. Never paste passwords, P12 files, P8 private keys or base64 private keys into chat/issues/source control.

## What is ready

[Run iOS build and TestFlight](https://github.com/Astra-Techno/circle/actions/workflows/ios.yml) → **Run workflow** → branch **main**.

- **validate** compiles the production iPhone app without Apple credentials. Its artifact is explicitly **UNSIGNED-NOT-INSTALLABLE**. It cannot be installed by tapping a website link.
- **testflight** first validates, then signs, verifies and uploads an App Store IPA using secrets in the **ios-testflight** GitHub environment. Apple processes it before testers can install it. Upload success is not TestFlight processing/review or device acceptance.
- The API is `https://circle.cloudkart24.com/api/v1`; preview is off. Android APK23 and the Android signing identity are unchanged. All three Runner configurations use an app-scoped Keychain entitlement for secure login storage; signed phone persistence still needs testing.
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

## Recorded validation — 29 October 2026

- [GitHub macOS run40804532410](https://github.com/Astra-Techno/circle/actions/runs/40804532410), source `dd66dfa`, succeeded: dependencies, analysis, platform-independent guard tests, unsigned iPhone release compilation, packaging and artifact upload. TestFlight job correctly skipped for target `validate`.
- Artifact `ios-unsigned-validation-1` exists (11,683,213 bytes according to GitHub metadata); it is not an installable IPA. This environment could read run status but its network rejected the separate logs/artifact download hosts with403, so the artifact bytes were not inspected locally. Download through GitHub if needed.
- `actionlint` clean; five portable signing/profile tests pass. All three native Runner configurations now reference an app-scoped Keychain entitlement as a follow-up, per the installed secure-storage plugin’s setup instructions. This signing-specific configuration has not been tested with a signed build.
- Apple secrets remain unsupplied; no TestFlight upload, native session-persistence check or physical iPhone/push verification is claimed.

## Existing CSR download

The cloud workspace generated a matching signing key/CSR on29 October2026. [Download the public CSR ZIP](https://raw.githubusercontent.com/Astra-Techno/circle/main/downloads/circle-ios-csr.zip), extract it in Files and upload the `.csr` to Apple Distribution certificate creation. It contains no private key. Reuse this CSR with the retained matching private key; generating another key would not match a certificate issued for this CSR. The private backup remains outside Git as `/workspace/circle-ios-signing-private-backup.zip`; workspace links may not download in every client. Retain that backup securely outside the temporary environment when private download access is available.

## Download-free signing transfer (when private ZIP links fail)

Use the manual **iOS signing setup (no downloads)** workflow. No signing key, password, P12 or profile needs to be pasted into chat or downloaded from this client. Existing signing inputs remain private outside Git.

One-time owner setup:

1. Open [fine-grained token creation](https://github.com/settings/personal-access-tokens/new). Name it `CIRCLE iOS setup`, use a short expiration (one day), choose the owner of `Astra-Techno/circle`, and grant access to **Only select repositories → circle**. Under Repository permissions, set **Environments → Read and write**. No Contents/Actions/Secrets scope is needed beyond automatic metadata access.
2. Copy the generated token directly into [a new repository Actions secret](https://github.com/Astra-Techno/circle/settings/secrets/actions/new) named **IOS_SIGNING_SETUP_TOKEN**. Do not send the token in chat, a workflow input or a source file.
3. Tell the assistant the secret is ready, without its value. The assistant can run `prepare`, verify the exact reviewed workflow commit/run through GitHub's authenticated API, seal the existing four inputs to that environment's public encryption key, and run `import` with ciphertext only.
4. After successful import, remove the setup secret and revoke its one-time token. The four resulting environment secrets remain available to the signed build. The App Store Connect API credentials and app record are still required for TestFlight upload.

The setup workflow creates the environment only if missing and restricts that new environment to main. It preserves existing environment protections. All jobs are main-only; only the four named signing secrets are accepted. The public encryption key is published as job metadata so the assistant can fetch it through the Jobs API even when separate log/artifact hosts are blocked. It is not an Apple private key.

The local sealer (`scripts/ios/seal_for_github.py`, dependency pinned in `requirements-sealing.txt`) checks the workflow path, repository, branch, successful run and exact reviewed commit **before reading private inputs**. Never obtain the encryption key from an arbitrary repository file or user-supplied URL. GitHub's environment private key alone can decrypt the sealed transfer. Workflow inputs contain only ciphertext; plaintext signing data is never committed, printed or uploaded as an artifact. Key rotation/mismatch is rejected before import. Partial API failures are reported without values; a retry of the same matching bundle is idempotent.

Verification: actionlint clean;13 portable tests pass in the sealing virtual environment, including rejection of changed keys/unapproved secret names, preservation of existing environment protections, main-only new environments and sealed-box round trips that reject a different private key. Actual GitHub import remains pending the owner's one-time setup secret; the existing integration's environment-creation request returned403. No new APK or signed iOS build was made for this setup helper.

## Signing transfer completed — 29 October2026

The owner added the one-time setup token directly in GitHub. [Prepare40815281819](https://github.com/Astra-Techno/circle/actions/runs/40815281819) succeeded at reviewed source `128a56456ace4970688b1bccba454ee5fca1afe7`; the local sealer verified that exact run/repository/branch/workflow before reading inputs. [Import40815386432](https://github.com/Astra-Techno/circle/actions/runs/40815386432) succeeded: all four environment-secret PUT operations completed for IOS_TEAM_ID, IOS_CERTIFICATE_BASE64, IOS_CERTIFICATE_PASSWORD and IOS_PROFILE_BASE64. No plaintext signing material was committed, printed or uploaded as an artifact. The new ios-testflight environment is restricted to main.

The temporary local encrypted dispatch file was removed; original private identity/profile remain outside Git. Current integration still gets403 when listing environment secrets, so the successful importer job is the verification evidence, not a local readback of secrets. The owner must remove IOS_SIGNING_SETUP_TOKEN from repository secrets and revoke the one-time PAT. App Store Connect API credentials/app record and an actual signed macOS build/TestFlight upload remain separate pending steps.
