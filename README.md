# Advanced Mechanic System

A comprehensive mechanic job system for FiveM with ox_lib integration.

## Features

- **Mechanic Shop Management**: Create and manage mechanic shops with multiple zones
- **Vehicle Inspection**: Detailed vehicle damage and parts inspection with realistic degradation
- **Advanced Diagnostic Tablet**: Colorful ox_lib context menus for comprehensive vehicle analysis
- **Vehicle Maintenance**: Perform various maintenance tasks with fluid level management
- **Complete Tuning System**: Performance upgrades, visual modifications, and nitro installation
- **Advanced Billing System**: Create detailed invoices with labor and parts breakdown
- **Parts Inventory Management**: Shop stock management with supplier ordering
- **Realistic Damage System**: Dynamic damage detection with wheel misalignment using ox_lib cache system
- **Towing System**: Multiple tow vehicle types with realistic physics
- **Mission System**: Dynamic repair missions for extra income
- **Lift System**: Synchronized vehicle lifts with smooth animations
- **Multi-shop Support**: Multiple shops with individual ownership and management
- **Maintenance History**: Track all repairs and services performed on vehicles
- **Performance Analysis**: Detailed vehicle performance metrics and upgrades
- **Fluid Management**: Oil, coolant, brake fluid, and more with visual indicators
- **Smart Vehicle Monitoring**: Uses ox_lib cache for efficient vehicle and seat detection
- **Advanced Fluid Effects System**: Realistic vehicle performance degradation with:
  - **Brake Fluid**: Below 50% reduces braking to 60%, below 30% to 30% power
  - **Engine Oil**: Below 30% causes continuous engine damage and 30% speed reduction
  - **Coolant**: Below 30% causes overheating, critical temperature shuts down engine
  - **Power Steering**: Below 50% makes steering heavy, below 30% very difficult
  - **Automatic Degradation**: Fluids degrade based on speed, engine health, and time
  - **Real-time Sync**: Database synchronization every 5 minutes
  - **Memory Management**: Automatic cleanup of unused vehicle data
  - **Anti-cheat Protection**: Server-side validation of fluid levels

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_target](https://github.com/overextended/ox_target)
- QBCore or ESX framework

## Installation

1. Download and extract the resource to your resources folder
2. Add `ensure advanced-mechanic` to your server.cfg
3. Import the SQL file to your database
4. Import `fluid_data_migration.sql` to add fluid data columns
5. Configure the resource in `config.lua`
6. Restart your server

## Database Setup

Execute the following SQL in your database:

```sql
CREATE TABLE IF NOT EXISTS `mechanic_shops` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `owner` varchar(50) DEFAULT NULL,
  `price` int(11) NOT NULL DEFAULT 0,
  `zones` longtext DEFAULT NULL,
  `employees` longtext DEFAULT '[]',
  `storage` longtext DEFAULT '{}',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Run fluid_data_migration.sql to add fluid support:
ALTER TABLE player_vehicles ADD COLUMN IF NOT EXISTS fluid_data LONGTEXT DEFAULT NULL;
```

## Commands

### Admin Commands
- `/setmechanic [playerid] [grade]` - Set a player as mechanic (Admin only)
- `/createshop` - Start the shop creation process (Admin only)

### Mechanic Commands
- `/mechanicmenu` - Open the mechanic menu (Mechanic only)

## Configuration

Edit `config.lua` to customize:

- Mechanic job name and grades
- Vehicle service prices
- Mission rewards
- Part prices and requirements
- Tow vehicle models
- Service vehicle spawns

## Usage

### For Admins
1. Use `/createshop` to start creating a new mechanic shop
2. Follow the on-screen instructions to place zones:
   - Management zone
   - Parts shop zone
   - Garage zone
   - Lift positions (up to 4 per shop)
   - Vehicle spawn points

### For Mechanics
1. Use `/mechanicmenu` to access mechanic functions:
   - **Inspect Vehicle**: Check vehicle damage and parts status
     - In shop: Direct inspection when vehicle is on lift
     - Outside shop: Requires toolbox item
   - **Perform Maintenance**: Service vehicles (requires tools)
   - **Paint Vehicle**: Customize vehicle colors (vehicle must be on lift)
   - **Start Mission**: Begin repair missions for extra income
   - **Tow Vehicle**: Attach/detach vehicles for towing

### Shop Owners
Shop owners have additional access to:
- Spawn service vehicles
- Manage shop employees
- Access shop storage
- Control vehicle lifts

## Items Required

Add these items to your inventory system:

- `toolbox` - Required for vehicle inspection outside mechanic shops
- `diagnostic_tool` - Advanced diagnostic equipment
- `toolkit` - Basic mechanic toolkit
- `engine_oil` - For engine maintenance
- `brake_fluid` - For brake maintenance
- `transmission_fluid` - For transmission maintenance
- `suspension_parts` - For suspension maintenance
- `engine_part` - Engine replacement part
- `brake_part` - Brake replacement part
- `transmission_part` - Transmission replacement part
- `suspension_part` - Suspension replacement part
- `coolant` - Engine coolant for refilling
- `power_steering_fluid` - Power steering fluid

## Shop Zones

Each shop includes:
- **Management Zone**: Shop settings and employee management
- **Parts Shop**: Purchase mechanic supplies and parts
- **Garage Zone**: Store and retrieve service vehicles
- **Lift Controls**: Operate vehicle lifts

## Lift System

The lift system allows mechanics to:
- Automatic vehicle detection when positioned on lift
- Raise and lower vehicles with smooth animation
- Lock vehicles in place for work
- Inspect vehicles directly from lift menu
- Support multiple lifts per shop
- Statebag synchronization for multiplayer

## Permissions

- Only admins can create shops and set mechanic jobs
- Only mechanics can access the mechanic menu
- Only shop owners can manage their shops
- Lift usage is restricted to one player at a time

## Fluid System Details

The fluid effects system provides realistic vehicle behavior:

### Degradation Factors
- **Base Rate**: 0.1% oil/coolant, 0.05% brake/steering per 30 seconds
- **Damaged Engine** (<900 health): 2x oil, 1.5x coolant degradation
- **High Speed** (>120 km/h): 1.5x oil, 2x coolant/brake degradation

### Performance Effects
- **Brake Fluid**: Directly modifies vehicle brake force
- **Engine Oil**: Causes engine damage (0.5 HP/s) and speed reduction
- **Coolant**: Increases engine temperature, auto-shutdown at 120°C
- **Power Steering**: Modifies steering lock angle

### Technical Features
- Caches original vehicle handling for proper restoration
- Uses Entity state bags for multiplayer synchronization
- Implements warning system to prevent notification spam
- Automatic memory cleanup every 10 minutes
- Server validation prevents cheating

## Support

For issues or questions, please create an issue on the repository.
