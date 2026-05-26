# PitWall iOS — Docs

This repo holds the **iOS/Mac UI** for a PitWall Mobile Command. The Mobile Command itself (state, sync, AMS2-mcp integration) lives server-side as a Docker container in the `m1cr-pitwall` backend.

## Primary design document

The authoritative product design is in the backend repo:

→ **`m1cr-pitwall/docs/PRD-mobile-command-v2.md`** — forest-of-orgs vision, Mobile Command as container, themed lobby board, Race Postings, Phase 1 vs Phase 2 scope.

Where the older spec (`m1cr-pitwall/docs/SPEC-native-app.md`) disagrees with the PRD, the PRD wins.

## Related repos

- `m1cr-pitwall` — the backend (Cloudflare Pages → migrating to VPS-hosted Docker per the PRD). PRD, ADRs, and D1 schema live here.
- `m1cr-site` — the marketing site (`m1circuit.com`) plus admin login. Outside the PitWall game/console scope.

## This repo

| Path | What |
|---|---|
| `PitWall/Package.swift` | Swift Package definition (library + tests; the iOS/Mac app target is generated via XcodeGen). |
| `PitWall/Sources/PitWall/` | All app source (App, Models, Services, ViewModels, Views, Design). |
| `PitWall/Sources/PitWallTests/` | XCTest suite. |
| `project.yml` | XcodeGen project definition. Generates `PitWall.xcodeproj` with iOS + macOS targets. |
| `PitWall.xcodeproj` | Generated; regenerate with `xcodegen generate` after editing `project.yml` or adding source files. |
