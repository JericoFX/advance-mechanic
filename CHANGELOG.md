# Changelog

## [Unreleased]
### Changed
- Split the fluid simulation into dedicated modules for effects, degradation, and state management to improve readability and ox_lib-driven performance.
- Updated the fluid effects controller to use cache-driven start/stop logic and reduce idle processing while the player is not driving.
- Clarified the `player_vehicles` migration comment to mention the inspection_data and props columns.
### Fixed
- Restored the billing menu part selector by sourcing maintenance and part pricing from configuration data, allowing invoices to include all service items without errors.
- Renamed the server-side vehicle property sync event to `mechanic:server:syncVehicleProperties` so it no longer intercepts the client handler and continues forwarding updates with `TriggerClientEvent`.
