[English](./README.md) | [简体中文](./README_zh_CN.md)

# LocalAuth

LocalAuth is a local-first iOS authenticator focused on layered protection for one-time passwords. It combines on-device token storage, hardware-key-assisted unlock flows, nearby encrypted transfer, and an optional self-hosted Travel Vault flow for temporary off-device backup and restore.

## Highlights

- Local token storage backed by Keychain, Secure Enclave wrapping, and biometric unlock flows.
- Multiple import paths: QR scanning, screenshot OCR, manual Base32 entry, and encrypted nearby transfer.
- Hardware-key support for YubiKey challenge-response and generic CTAP2 `hmac-secret` based unlock flows.
- Optional Travel Vault backup and restore with end-to-end encrypted payloads.
- SwiftUI interface, SwiftData persistence, multilingual strings, and alternate app icons.

## Open-Source Snapshot Notes

This repository has been cleaned up for public release:

- Private bundle identifiers, team identifiers, support mailboxes, hosted endpoint URLs, and product cross-promo links were replaced with public-safe examples.
- Travel Vault is intentionally not wired to a production backend in this snapshot. You need to deploy and configure your own endpoint before using it.
- Placeholder project links and maintainer contact information live in [`localauth/OpenSourceProjectInfo.swift`](./localauth/OpenSourceProjectInfo.swift).

## Requirements

- Xcode 16 or newer
- iOS 18.0+
- A real iPhone is required for NFC, biometrics, App Attest, and hardware-key testing

## Getting Started

1. Open [`localauth.xcodeproj`](./localauth.xcodeproj) in Xcode.
2. Replace the placeholder bundle identifier `com.example.localauth` with your own App ID.
3. Set your Apple development team and signing configuration.
4. Review and update [`localauth/OpenSourceProjectInfo.swift`](./localauth/OpenSourceProjectInfo.swift) for repository URLs, public contact info, and optional Travel Vault endpoints.
5. If you plan to enable Travel Vault, also verify App Attest, the remote verifier, and the endpoint paths in [`localauth/Services/TravelVaultRemoteConfig.swift`](./localauth/Services/TravelVaultRemoteConfig.swift).

## Main Technologies

- SwiftUI
- SwiftData
- LocalAuthentication / Secure Enclave / Keychain
- Vision OCR
- AVFoundation QR scanning
- MultipeerConnectivity
- YubiKit via Swift Package Manager

## Project Structure

- [`localauth/Views`](./localauth/Views): SwiftUI screens and onboarding flow
- [`localauth/Services`](./localauth/Services): crypto, OCR, sync, Travel Vault, CTAP2, and hardware-key integrations
- [`localauth/Models`](./localauth/Models): persisted token models and demo data
- [`localauth/ViewModels`](./localauth/ViewModels): token store and import/export orchestration

## Travel Vault

Travel Vault in this public snapshot is an optional, self-hosted capability.

- No production endpoint is bundled here.
- The app-side configuration defaults to empty URLs.
- You should treat App Attest, backup retention, endpoint auth, and abuse controls as part of your own deployment responsibility.

## License

The source code in this repository is provided under Apache-2.0. See [`LICENSE`](./LICENSE).

Brand identifiers, the application name, icons, and App Store marketing materials are excluded from that license scope. See [`BRANDING.md`](./BRANDING.md).

## Why Simplified Chinese Appears In Source Strings

This project did not begin as a polished public SDK. It started as a small internal experiment within the team, and then grew much faster than expected into a real product.

It was during that period of internal exploration and rapid iteration that LocalAuth’s core ideas took shape: placing accounts of different value behind different trust boundaries, while remaining local-first and openly verifiable. The Simplified Chinese strings that still remain in the codebase reflect that early stage of the project’s evolution, and we chose to leave those traces visible as part of the software’s real development history.
