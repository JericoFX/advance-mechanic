# Changelog

## [Unreleased]
### Changed
- Split the fluid simulation into dedicated modules for effects, degradation, and state management to improve readability and ox_lib-driven performance.
- Updated the fluid effects controller to use cache-driven start/stop logic and reduce idle processing while the player is not driving.
### Fixed
- Restored the billing menu part selector by sourcing maintenance and part pricing from configuration data, allowing invoices to include all service items without errors.
