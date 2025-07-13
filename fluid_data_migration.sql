-- Add fluid data column to player_vehicles table
ALTER TABLE `player_vehicles` 
  ADD COLUMN IF NOT EXISTS `fluid_data` longtext DEFAULT NULL;
