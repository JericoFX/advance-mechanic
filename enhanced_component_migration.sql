-- Enhanced Component Migration for Advanced Mechanic System
-- This migration adds support for tire wear, battery, and gearbox degradation

-- Ensure fluid_data column exists (may already exist from previous migrations)
ALTER TABLE `player_vehicles` 
ADD COLUMN IF NOT EXISTS `fluid_data` LONGTEXT DEFAULT NULL;

-- Add enhanced component tracking columns if they don't exist
ALTER TABLE `player_vehicles` 
ADD COLUMN IF NOT EXISTS `component_data` LONGTEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS `mileage` INT(11) DEFAULT 0,
ADD COLUMN IF NOT EXISTS `last_service` TIMESTAMP NULL DEFAULT NULL;

-- Update existing vehicles with default component data
UPDATE `player_vehicles` 
SET `fluid_data` = JSON_OBJECT(
    'oilLevel', 100,
    'coolantLevel', 100,
    'brakeFluidLevel', 100,
    'transmissionFluidLevel', 100,
    'powerSteeringLevel', 100,
    'tireWear', 0,
    'batteryLevel', 100,
    'gearBoxHealth', 100,
    'lastUpdate', UNIX_TIMESTAMP()
)
WHERE `fluid_data` IS NULL;

-- Create maintenance history table
CREATE TABLE IF NOT EXISTS `vehicle_maintenance_history` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `plate` varchar(8) NOT NULL,
    `component` varchar(50) NOT NULL,
    `action` varchar(100) NOT NULL,
    `mechanic_id` varchar(50) NOT NULL,
    `cost` decimal(10,2) DEFAULT 0.00,
    `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `plate` (`plate`),
    KEY `timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create component wear tracking table for detailed analytics
CREATE TABLE IF NOT EXISTS `vehicle_component_analytics` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `plate` varchar(8) NOT NULL,
    `tire_wear_total` decimal(5,2) DEFAULT 0.00,
    `battery_cycles` int(11) DEFAULT 0,
    `gearbox_shifts` int(11) DEFAULT 0,
    `total_distance` decimal(10,2) DEFAULT 0.00,
    `avg_speed` decimal(5,2) DEFAULT 0.00,
    `harsh_braking_events` int(11) DEFAULT 0,
    `collision_count` int(11) DEFAULT 0,
    `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert default analytics data for existing vehicles
INSERT IGNORE INTO `vehicle_component_analytics` (`plate`)
SELECT `plate` FROM `player_vehicles`;

COMMIT;
