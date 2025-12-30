# Advanced Mechanic System

i Dont know if is working so good luck!

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
- **Enhanced Component Degradation System**:
  - **Tire Wear**: Progressive wear based on speed, surface type, and mileage
    - High speed driving increases wear rate significantly
    - Different surfaces (sand, rock) cause accelerated wear
    - Critical wear levels cause tire blowouts and reduced traction
  - **Battery System**: Realistic battery drain and electrical effects
    - Drains faster with damaged engine or during idle
    - Low battery causes dimmed lights and random engine shutdowns
    - Critical levels prevent vehicle startup
  - **Transmission/Gearbox**: Complex transmission wear simulation
    - High speed and body damage accelerate wear
    - Worn gearbox causes sluggish gear changes
    - Critical damage results in random gear shifts
  - **Collision Impact**: Vehicle collisions damage multiple components
    - Battery, gearbox, and tire wear increase with impact severity
    - Realistic damage distribution based on collision force

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_target](https://github.com/overextended/ox_target)
- QBCore or ESX framework

## Installation

1. Download and extract the resource to your resources folder
2. Add `ensure advance-mechanic` to your server.cfg
3. Import `install.sql` to your database
4. Configure the resource in `config.lua`
5. Restart your server

## Recent Updates

- **Enhanced Shop Creation**: Interactive raycast-based point placement with visual markers
- **ox_lib Integration**: Replaced legacy exports with modern ox_lib points system
- **Vehicle Cache System**: Implemented `lib.onCache` for efficient vehicle state monitoring
- **Security Improvements**: All admin commands now execute server-side with proper validation
- **Property Management**: Fixed vehicle property handling using correct ox_lib syntax
- **Localization**: Complete localization support with ox_lib locale system
- **Zone Management**: Improved zone creation and management with proper cleanup

## Database Setup

Import `install.sql` to create all required tables and columns.

## Commands

### Admin Commands
- `/setmechanic [playerid] [grade]` - Set a player as mechanic (Admin only)
- `/createshop` - Start the shop creation process (Admin only)

### Mechanic Commands
- `/mechanicmenu` - Open the mechanic menu (Mechanic only)

## Configuration

Edit `config.lua` to customize:

- Mechanic job name and grades
- Vehicle service prices, including dynamic adjustments based on vehicle condition
- Mission rewards structured with tiered objectives
- Part prices and regulations as per supplier settings
- Tow vehicle models configured for compatibility
- Service vehicle spawns managed by zone and availability
- Diagnostic menu settings using ox_lib for enhanced UI
## Usage

### Shop Creation Process (Admin Only)

#### Starting Shop Creation
1. Use `/createshop` to start creating a new mechanic shop
2. Enable freecam mode automatically activates for precise placement
3. The system uses an interactive raycast-based point placement with visual markers

#### Zone Placement Steps
The creation process follows this specific order:

1. **Shop Name Input**
   - Enter a unique name for the mechanic shop
   - Names must be 3-50 characters long

2. **Management Zone**
   - Press `E` to place the management point
   - Visual marker shows exact placement location
   - This zone handles: employee management, shop settings, financial overview

3. **Parts Shop Zone**
   - Navigate to desired location and press `E`
   - Access point for purchasing parts and supplies
   - Inventory management and supplier orders

4. **Garage Zone**
   - Place the garage access point
   - Service vehicle storage and retrieval
   - Company vehicle management

5. **Lift Positions** (1-4 lifts per shop)
   - Place each lift position carefully
   - Consider vehicle access and workspace
   - Each lift operates independently

6. **Vehicle Spawn Points**
   - Set multiple spawn locations for serviced vehicles
   - Ensure clear path from lifts to spawn points
   - System automatically finds available spots

#### Visual Indicators During Creation
- **Green Marker**: Valid placement location
- **Red Marker**: Invalid or obstructed location
- **Yellow Circle**: Current zone radius
- **Blue Line**: Direction indicator for spawn points

### For Admins
1. Use `/createshop` to start creating a new mechanic shop
2. Follow the on-screen instructions to place zones. The system provides a raycast-based interface with visual markers to assist in placing zones accurately:
   - Management zone: For shop settings and employee management.
   - Parts Shop zone: For purchasing parts and supplies.
   - Garage zone: For storing and retrieving service vehicles.
   - Lift positions: Place up to 4 per shop for vehicle maintenance.
   - Vehicle spawn points: Designate spots for newly serviced vehicles to appear.

### For Mechanics

#### Mechanic Menu System
Access the main menu with `/mechanicmenu` - this opens an ox_lib context menu with color-coded options:

##### 1. **Vehicle Inspection** 🔍
- **Inside Shop**: Direct inspection when vehicle is on lift
  - Displays comprehensive damage report
  - Shows all fluid levels with color indicators:
    - 🟢 Green: 70-100% (Good)
    - 🟡 Yellow: 30-69% (Warning)
    - 🔴 Red: 0-29% (Critical)
  - Component wear status (tires, battery, transmission)
  - Estimated repair costs and time
  
- **Outside Shop**: Portable inspection (requires `toolbox` item)
  - Limited to visual damage assessment
  - Basic fluid level checks
  - Cannot perform repairs without shop equipment

##### 2. **Perform Maintenance** 🔧
Available services when vehicle is on lift:
- **Oil Change**: Restores engine oil to 100%
  - Requires: `engine_oil` item
  - Duration: 10 seconds
  - Prevents engine damage
  
- **Brake Service**: Refills brake fluid
  - Requires: `brake_fluid` item
  - Duration: 15 seconds
  - Restores full braking power
  
- **Coolant Service**: Tops up cooling system
  - Requires: `coolant` item
  - Duration: 8 seconds
  - Prevents overheating
  
- **Transmission Service**: Services gearbox
  - Requires: `transmission_fluid` item
  - Duration: 20 seconds
  - Fixes gear shifting issues
  
- **Full Service**: Complete maintenance package
  - Requires all fluid items
  - Duration: 45 seconds
  - Restores all systems to 100%

##### 3. **Vehicle Customization** 🎨
- **Paint Jobs**: Full color customization
  - Primary, secondary, and pearl colors
  - Custom RGB color picker
  - Live preview before applying
  
- **Performance Tuning**: Engine and handling upgrades
  - Engine (Level 0-4)
  - Brakes (Level 0-3)
  - Transmission (Level 0-3)
  - Suspension (Level 0-4)
  - Turbo installation
  
- **Visual Modifications**: Aesthetic upgrades
  - Body kits and spoilers
  - Wheels and tires
  - Window tint
  - Neon kits
  - Custom plates

##### 4. **Repair Missions** 📋
Dynamic missions for extra income:
- **Emergency Repairs**: Time-critical fixes
  - Higher pay for faster completion
  - Random vehicle types and damage
  
- **Scheduled Maintenance**: Regular service appointments
  - Fixed pay rate
  - Predictable work
  
- **Custom Orders**: Special modification requests
  - Complex requirements
  - Premium payments

##### 5. **Towing Operations** 🚛
- Compatible tow vehicles automatically detected
- Attach/detach with simple controls
- Physics-based towing system
- Damage prevention during transport

#### Menu Navigation
- Use ⬆️⬇️ arrows or mouse to navigate
- Press `Enter` or click to select
- Press `Backspace` or `ESC` to go back
- All menus use ox_lib's context system with:
  - Icons for visual clarity
  - Color coding for status
  - Descriptive tooltips
  - Progress bars for actions

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

## Technical Implementation

### Point System (ox_lib)
The resource uses ox_lib's point system for zone management:

```lua
-- Example of management zone creation
local point = lib.points.new({
    coords = vec3(x, y, z),
    distance = 5,
    onEnter = function()
        -- Show interaction prompt
        lib.showTextUI('[E] - Access Management')
    end,
    onExit = function()
        -- Hide prompt
        lib.hideTextUI()
    end,
    nearby = function(self)
        -- Check for key press
        if IsControlJustPressed(0, 38) then -- E key
            openManagementMenu(shopId)
        end
    end
})
```

### Zone Types and Properties

#### Management Zone
- **Radius**: 2.5 meters
- **Interaction**: Press E to open menu
- **Functions**: Employee management, shop settings, financial overview
- **Permissions**: Shop owner only

#### Parts Shop Zone
- **Radius**: 3.0 meters
- **Interaction**: Automatic menu on approach
- **Functions**: Purchase parts, view stock, order supplies
- **Permissions**: All mechanics

#### Garage Zone
- **Radius**: 5.0 meters
- **Interaction**: Vehicle detection + menu
- **Functions**: Store/retrieve service vehicles
- **Permissions**: Shop employees

#### Lift Zones
- **Radius**: 4.0 meters (detection), 2.0 meters (control)
- **Interaction**: Automatic vehicle detection
- **Functions**: Raise/lower lift, lock vehicle
- **Permissions**: One mechanic at a time

### Shop Creation Workflow

```lua
-- Simplified creation flow
1. Admin command triggers server event
2. Server validates admin permissions
3. Client enters creation mode:
   - Enables freecam
   - Starts raycast loop
   - Shows placement markers
4. Each zone placement:
   - Raycast to ground
   - Validate position
   - Store coordinates
5. Final creation:
   - Send all data to server
   - Server creates database entry
   - Spawn zones for all players
```

### Data Storage Structure

```json
{
  "zones": {
    "management": {
      "coords": {"x": 100.0, "y": 200.0, "z": 30.0},
      "heading": 180.0
    },
    "parts": {
      "coords": {"x": 105.0, "y": 205.0, "z": 30.0},
      "heading": 90.0
    },
    "garage": {
      "coords": {"x": 110.0, "y": 210.0, "z": 30.0},
      "heading": 270.0
    },
    "lifts": [
      {
        "coords": {"x": 115.0, "y": 215.0, "z": 30.0},
        "heading": 0.0
      }
    ],
    "spawns": [
      {
        "coords": {"x": 120.0, "y": 220.0, "z": 30.0},
        "heading": 180.0
      }
    ]
  }
}
```

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
