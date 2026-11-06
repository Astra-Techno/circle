# Google Stitch MCP setup status — 6 November 2026

Owner requested a Google Stitch connection and supplied https://davideast.github.io/stitch-mcp/. This is the third-party davideast/stitch-mcp adapter, not an installed Google Stitch ChatGPT plugin. Plugin Management searches for Stitch returned no matching plugin; the directory result is not exhaustive.

The documentation site returned403 under the managed network policy. Official repository README, setup guide and Codex connection guide were read through the allowed GitHub source: https://github.com/davideast/stitch-mcp. No denied destination was accessed through a bypass.

## Prepared locally

- Adapter `@_davideast/stitch-mcp@0.9.0` installed outside Circle with npm install scripts disabled. Published npm integrity: `sha512-C2kdemWCn9x9DgR8dmq/dggzCGeTxuLnXrF3rgOpyBE/q+BDne9Emna/T2l/gXaJjwsJqSEZNlu+pgI47VGP1Q==`.
- CLI --help and --version passed, reporting0.9.0. Local wrapper `/workspace/toolchain/bin/stitch-mcp`; dependencies `/tmp/circle-stitch-mcp`; working directory `/workspace/toolchain/stitch-mcp` prevents loading Circle's environment files.
- A credential-free Codex configuration example is at `/workspace/toolchain/stitch-mcp/codex-config.example.toml`. It invokes the proxy and forwards STITCH_API_KEY from the client environment. It has **not** been registered in this chat's MCP tool list. A client configuration file or installed CLI alone is not a verified connection.

## Required before connection

1. Supply `STITCH_API_KEY` as a secure execution-environment/client secret. It is currently absent. Do not paste it into chat or commit it. API-key mode is documented to skip gcloud, OAuth and Cloud-project setup; none were started or changed.
2. Permit HTTPS access to `stitch.googleapis.com` through the supported environment configuration. The MCP endpoint is `https://stitch.googleapis.com/mcp`; this host is absent from the currently enforced allowed-host list. Do not bypass the proxy or disable TLS.
3. For a separate Codex client, merge the example into that client's MCP configuration, preserve its existing servers and reload the client. The active ChatGPT tool list cannot be extended merely by changing a workspace CLI config. Once secure credentials/network access are available, the installed adapter CLI can also perform the equivalent Stitch calls from this workspace.
4. Verify an authenticated read-only operation, such as `stitch-mcp tool list_projects`, before claiming access. No project was listed, created, uploaded or edited; no successful Google connection is claimed.

Circle source, dependencies, app artifacts and Android signing files are unchanged. Temporary local tooling must be restored after replacing this execution environment.
