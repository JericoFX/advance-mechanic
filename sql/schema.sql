-- ==========================================
-- ADVANCE-MECHANIC DATABASE SCHEMA
-- Auto-generated unique IDs for shops
-- ==========================================

-- Main mechanic shops table
CREATE TABLE IF NOT EXISTS `mechanic_shops` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `price` INT(11) NOT NULL DEFAULT 100000,
    `owner` VARCHAR(50) DEFAULT NULL,
    `zones` LONGTEXT NOT NULL,
    `lifts` LONGTEXT NOT NULL,
    `vehicleSpawns` LONGTEXT NOT NULL,
    `storage` LONGTEXT DEFAULT NULL,
    `payrollEnabled` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_name` (`name`),
    KEY `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Employee assignments table (links employees to specific shops)
CREATE TABLE IF NOT EXISTS `mechanic_employees` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) UNSIGNED NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) DEFAULT NULL,
    `grade` INT(11) NOT NULL DEFAULT 0,
    `wage` DECIMAL(10,2) NOT NULL DEFAULT 15.00,
    `hired_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `on_duty` TINYINT(1) NOT NULL DEFAULT 0,
    `last_clock_in` TIMESTAMP NULL DEFAULT NULL,
    `total_hours` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_shop_employee` (`shop_id`, `citizenid`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_shop_id` (`shop_id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Shop funds/business account
CREATE TABLE IF NOT EXISTS `mechanic_shop_funds` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) UNSIGNED NOT NULL,
    `balance` INT(11) DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_shop_funds` (`shop_id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Transaction history for shop funds
CREATE TABLE IF NOT EXISTS `mechanic_transactions` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) UNSIGNED NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `type` ENUM('deposit', 'withdrawal', 'restock', 'sale') NOT NULL,
    `amount` INT(11) NOT NULL,
    `description` VARCHAR(255),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_shop_transactions` (`shop_id`),
    KEY `idx_citizenid` (`citizenid`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Employee work schedules
CREATE TABLE IF NOT EXISTS `mechanic_schedules` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `employee_id` INT(11) UNSIGNED NOT NULL,
    `day_of_week` INT(11) NOT NULL, -- 0=Sunday, 6=Saturday
    `start_time` TIME NOT NULL,
    `end_time` TIME NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_employee_id` (`employee_id`),
    FOREIGN KEY (`employee_id`) REFERENCES `mechanic_employees`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Payroll records
CREATE TABLE IF NOT EXISTS `mechanic_payroll` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) UNSIGNED NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `hours_worked` DECIMAL(5,2) DEFAULT 0,
    `wage_paid` INT(6) DEFAULT 0,
    `period_start` DATE,
    `period_end` DATE,
    `paid_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_shop_payroll` (`shop_id`),
    KEY `idx_citizenid_payroll` (`citizenid`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Maintenance history for vehicles
CREATE TABLE IF NOT EXISTS `mechanic_maintenance_history` (
    `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) UNSIGNED NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL, -- mechanic who performed service
    `plate` VARCHAR(15) NOT NULL,
    `service_type` VARCHAR(50),
    `cost` INT(6),
    `notes` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_shop_history` (`shop_id`),
    KEY `idx_plate_history` (`plate`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ==========================================
-- DEFAULT DATA
-- ==========================================

-- Insert default shop funds record trigger
DELIMITER //
CREATE TRIGGER IF NOT EXISTS `trg_create_shop_funds`
AFTER INSERT ON `mechanic_shops`
FOR EACH ROW
BEGIN
    INSERT INTO `mechanic_shop_funds` (`shop_id`, `balance`)
    VALUES (NEW.id, 0);
END//
DELIMITER ;

CREATE TABLE IF NOT EXISTS `wrap_catalog` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `primary_color` INT(3) NOT NULL,
    `secondary_color` INT(3) NOT NULL,
    `paint_type` TINYINT(1) DEFAULT 0,
    `pearlescent_color` INT(3) DEFAULT NULL,
    `price` INT(11) NOT NULL DEFAULT 2000,
    `shop_id` INT(11) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_shop_id` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
