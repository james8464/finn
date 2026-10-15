# Changelog

## **0.5.8** - 2026-10-13

### Fixed
- Fix symbol conflict between Spark's `Environment` and `SwiftUI.Environment`.

## **0.5.7** - 2026-10-06

### Added
- [OpeningFlow] Add `OpeningFlowView` API to run app-defined steps before the app content is displayed.
- [Tracking] Integrate TrackingKit. SDK now reports device_info.
- [Tracking] Send App Transaction data to SparkAPI endpoint.
- [Privacy] Add a privacy manifest declaring the SDK's required-reason API usage and collected data types.

### Removed
- [Configuration] `Configuration` no longer expects `gcpId`.

## **0.5.6** - 2026-07-22

### Changed
- `appToken` and `mwmAppId` now default to empty strings

## **0.5.5** - 2026-07-21

### Fixed
- Fix SDK compilation in Xcode 27

### Changed
- [Ledger] Update transaction validation URL

## **0.5.0** - 2026-05-04

### Added
- [MXMetrics] Send received Apple MXMetrics to MWM backend.
