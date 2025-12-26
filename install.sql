-- Advanced Mechanic System Database Setup

-- Add new columns to player_vehicles if they don't exist
ALTER TABLE `player_vehicles` 
  ADD COLUMN IF NOT EXISTS `maintenance_history` longtext DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `damage_data` longtext DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `last_diagnostic` longtext DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `mileage` int(11) DEFAULT 0;
-- Version 1.0

-- Create mechanic shops table
CREATE TABLE IF NOT EXISTS `mechanic_shops` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `owner` varchar(50) DEFAULT NULL,
  `price` int(11) NOT NULL DEFAULT 100000,
  `zones` longtext DEFAULT NULL,
  `lifts` longtext DEFAULT NULL,
  `vehicleSpawns` longtext DEFAULT NULL,
  `employees` longtext DEFAULT '[]',
  `storage` longtext DEFAULT '{}',
  `payrollEnabled` tinyint(1) DEFAULT 0,
  `payment_frequency` varchar(20) DEFAULT 'weekly',
  `payment_day` varchar(20) DEFAULT 'friday',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  INDEX `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create mechanic lifts table
CREATE TABLE IF NOT EXISTS `mechanic_lifts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `position` longtext NOT NULL,
  `height` float NOT NULL DEFAULT 0,
  `vehicle` varchar(50) DEFAULT NULL,
  `in_use` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `shop_id` (`shop_id`),
  CONSTRAINT `mechanic_lifts_ibfk_1` FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add mechanic job if using QBCore
-- Note: This is for QBCore, adjust for your framework
INSERT INTO `jobs` (`name`, `label`, `type`) VALUES 
('mechanic', 'Mechanic', 'mechanic')
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

-- Add job grades for QBCore
INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
('mechanic', 0, 'recruit', 'Recruit', 50, '{}', '{}'),
('mechanic', 1, 'novice', 'Novice', 75, '{}', '{}'),
('mechanic', 2, 'experienced', 'Experienced', 100, '{}', '{}'),
('mechanic', 3, 'advanced', 'Advanced', 125, '{}', '{}'),
('mechanic', 4, 'chief', 'Chief Mechanic', 150, '{}', '{}')
ON DUPLICATE KEY UPDATE 
    `name` = VALUES(`name`),
    `label` = VALUES(`label`),
    `salary` = VALUES(`salary`);

-- Create mechanic employees table
CREATE TABLE IF NOT EXISTS `mechanic_employees` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `grade` int(11) NOT NULL DEFAULT 0,
  `wage` decimal(10,2) NOT NULL DEFAULT 15.00,
  `hired_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `on_duty` tinyint(1) NOT NULL DEFAULT 0,
  `last_clock_in` timestamp NULL DEFAULT NULL,
  `total_hours` decimal(10,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_employee_shop` (`shop_id`, `citizenid`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_shop_id` (`shop_id`),
  CONSTRAINT `mechanic_employees_ibfk_1` FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create employee schedules table
CREATE TABLE IF NOT EXISTS `mechanic_schedules` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `employee_id` int(11) NOT NULL,
  `day_of_week` int(11) NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_employee_id` (`employee_id`),
  CONSTRAINT `mechanic_schedules_ibfk_1` FOREIGN KEY (`employee_id`) REFERENCES `mechanic_employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add payroll settings to mechanic shops
ALTER TABLE `mechanic_shops` 
  ADD COLUMN IF NOT EXISTS `payrollEnabled` tinyint(1) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `payment_frequency` varchar(20) DEFAULT 'weekly',
  ADD COLUMN IF NOT EXISTS `payment_day` varchar(20) DEFAULT 'friday';

-- Ensure shop layout columns exist
ALTER TABLE `mechanic_shops`
  ADD COLUMN IF NOT EXISTS `lifts` longtext DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `vehicleSpawns` longtext DEFAULT NULL;
