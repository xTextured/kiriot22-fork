# Kiriot22 Fork Library Documentation

## Overview

A comprehensive ESP (Extra Sensory Perception) library for Roblox that provides visual overlays for players and objects. Features include 2D/3D boxes, health bars, distance indicators, tracers, highlights, and off-screen arrows.

# THIS DOCUMENTATION WAS MADE BY AI (CLAUDE) 
## Table of Contents

1. [Installation](#installation)
2. [Basic Usage](#basic-usage)
3. [Configuration](#configuration)
4. [API Reference](#api-reference)
5. [Advanced Features](#advanced-features)
6. [Examples](#examples)

---

## Installation

```lua
local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/xTextured/kiriot22-fork/refs/heads/main/kiriot22.lua"))()
```

Or if you have the file locally:
```lua
local ESP = require(path.to.esplib)
```

---

## Basic Usage

### Enable ESP
```lua
ESP:Toggle(true)
```

### Disable ESP
```lua
ESP:Toggle(false)
```

### Add Custom Object Tracking
```lua
ESP:Add(workspace.SomeModel, {
    Name = "Custom Object",
    Color = Color3.fromRGB(255, 0, 0)
})
```

---

## Configuration

### Global Settings

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Enabled` | boolean | `false` | Master enable/disable switch |
| `TeamColor` | boolean | `true` | Use team colors for players |
| `Thickness` | number | `2` | Line thickness for boxes/tracers |
| `TeamMates` | boolean | `true` | Show teammates |
| `Players` | boolean | `true` | Show player ESP |
| `Color` | Color3 | `Color3.fromRGB(255, 170, 0)` | Default ESP color |

### Player-Specific Settings

Access via `ESP.Player`:

```lua
ESP.Player.Boxes = true              -- 2D bounding boxes
ESP.Player.Boxes3D = false           -- 3D wireframe boxes
ESP.Player.Names = true              -- Display names
ESP.Player.Distance = true           -- Show distance in meters
ESP.Player.HealthBars = true         -- Health bar display
ESP.Player.HealthText = true         -- Numeric health text
ESP.Player.Weapon = false            -- Show equipped weapon
ESP.Player.Tracers = false           -- Lines from screen center
ESP.Player.Highlights = true         -- Roblox Highlight effect
ESP.Player.OffScreenArrows = true    -- Arrows for off-screen targets
```

### Instance-Specific Settings

Access via `ESP.Instance`:

```lua
ESP.Instance.Boxes = true
ESP.Instance.Boxes3D = false
ESP.Instance.Names = true
ESP.Instance.Distance = true
ESP.Instance.Highlights = false
ESP.Instance.Tracers = false
ESP.Instance.OffScreenArrows = false
```

### Visual Modifiers

```lua
-- Box positioning and sizing
ESP.BoxShift = CFrame.new(0, -1.5, 0)
ESP.BoxSize = Vector3.new(4, 6, 0)
ESP.FaceCamera = false

-- Tracer attachment point (1 = bottom, 2 = center, 3 = top)
ESP.AttachShift = 1

-- Off-screen arrow settings
ESP.OffScreenArrowSize = 15
ESP.OffScreenArrowRadius = 150

-- Highlight settings
ESP.HighlightDistance = 100                              -- Max distance for highlights
ESP.HighlightBudget = 31                                 -- Max simultaneous highlights
ESP.HighlightFillColor = nil                             -- nil = use ESP color
ESP.HighlightOutlineColor = Color3.new(0, 0, 0)
ESP.HighlightFillTransparency = 0.5
ESP.HighlightOutlineTransparency = 0
ESP.HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop
```

---

## API Reference

### Core Functions

#### `ESP:Toggle(bool)`
Enable or disable the entire ESP system.

```lua
ESP:Toggle(true)   -- Enable
ESP:Toggle(false)  -- Disable
```

#### `ESP:Add(object, options)`
Add an object to ESP tracking.

**Parameters:**
- `object` (Instance): The object to track
- `options` (table): Configuration options

**Options Table:**
| Key | Type | Description |
|-----|------|-------------|
| `Name` | string | Display name (default: object.Name) |
| `Color` | Color3 | Custom color |
| `PrimaryPart` | BasePart | Part to use for positioning |
| `Player` | Player | Associated player object |
| `IsEnabled` | string/function | Conditional visibility |
| `Temporary` | boolean | Auto-remove when ESP disabled |
| `ColorDynamic` | function | Dynamic color function |
| `RenderInNil` | boolean | Render even if not in workspace |

**Returns:** Box object

**Example:**
```lua
local box = ESP:Add(workspace.Chest, {
    Name = "Treasure",
    Color = Color3.fromRGB(255, 215, 0),
    PrimaryPart = workspace.Chest.Main
})
```

#### `ESP:GetBox(object)`
Retrieve the ESP box for an object.

```lua
local box = ESP:GetBox(workspace.SomeModel)
if box then
    print("Box exists for object")
end
```

#### `ESP:AddObjectListener(parent, options)`
Automatically add ESP to objects as they're created.

**Parameters:**
- `parent` (Instance): Parent to monitor
- `options` (table): Listener configuration

**Options:**
| Key | Type | Description |
|-----|------|-------------|
| `Type` | string | ClassName filter (e.g., "Model") |
| `Name` | string | Name filter |
| `Validator` | function | Custom validation function |
| `Recursive` | boolean | Monitor descendants vs children |
| `PrimaryPart` | string/function | Part selection |
| `Color` | Color3/function | Color selection |
| `ColorDynamic` | function | Dynamic color |
| `CustomName` | string/function | Display name |
| `IsEnabled` | string/function | Conditional visibility |
| `RenderInNil` | boolean | Render in nil |
| `OnAdded` | function | Callback when added |

**Example:**
```lua
ESP:AddObjectListener(workspace.Coins, {
    Type = "Part",
    Recursive = true,
    Color = Color3.fromRGB(255, 215, 0),
    CustomName = "Coin",
    Validator = function(obj)
        return obj.Name == "Coin" and obj.Transparency < 1
    end
})
```

### Box Methods

Once you have a box object from `ESP:Add()` or `ESP:GetBox()`:

#### `box:Remove()`
Remove the ESP box and clean up all components.

```lua
local box = ESP:GetBox(someObject)
box:Remove()
```

#### `box:Update()`
Manually update the box (called automatically each frame).

```lua
box:Update()
```

### Override Functions

Customize ESP behavior by setting override functions:

#### `ESP.Overrides.GetTeam`
```lua
ESP.Overrides.GetTeam = function(player)
    return player.Team
end
```

#### `ESP.Overrides.IsTeamMate`
```lua
ESP.Overrides.IsTeamMate = function(player)
    return player.Team == game.Players.LocalPlayer.Team
end
```

#### `ESP.Overrides.GetColor`
```lua
ESP.Overrides.GetColor = function(object)
    local player = ESP:GetPlrFromChar(object)
    if player and player.Team then
        return player.Team.TeamColor.Color
    end
    return Color3.fromRGB(255, 255, 255)
end
```

#### `ESP.Overrides.GetPlrFromChar`
```lua
ESP.Overrides.GetPlrFromChar = function(character)
    return game.Players:GetPlayerFromCharacter(character)
end
```

#### `ESP.Overrides.GetWeapon`
```lua
ESP.Overrides.GetWeapon = function(player)
    local character = player.Character
    if character then
        local tool = character:FindFirstChildOfClass("Tool")
        return tool and tool.Name
    end
    return nil
end
```

#### `ESP.Overrides.UpdateAllow`
```lua
ESP.Overrides.UpdateAllow = function(box)
    -- Return false to hide this box
    return box.distance < 500
end
```

### Helper Functions

#### `ESP:GetTeam(player)`
Get a player's team (uses override if set).

#### `ESP:IsTeamMate(player)`
Check if player is on same team as local player.

#### `ESP:GetColor(object)`
Get the color for an object (uses override if set).

#### `ESP:GetPlrFromChar(character)`
Get player from character model (uses override if set).

---

## Advanced Features

### Highlight System

The library uses a pooled highlight system for performance:

- **Budget Control**: Only the closest `ESP.HighlightBudget` targets get highlights
- **Distance Limiting**: Only targets within `ESP.HighlightDistance` are considered
- **Automatic Sorting**: Targets are sorted by distance each frame
- **Object Pooling**: 31 Highlight instances are pre-created and reused

**Configuration:**
```lua
ESP.HighlightDistance = 150        -- Max distance (studs)
ESP.HighlightBudget = 20           -- Max simultaneous highlights
ESP.HighlightFillColor = nil       -- nil = use target's color
ESP.HighlightFillTransparency = 0.5
ESP.HighlightOutlineColor = Color3.new(1, 1, 1)
ESP.HighlightOutlineTransparency = 0
```

### Off-Screen Arrows

When targets move off-screen, arrows point to their direction:

```lua
ESP.Player.OffScreenArrows = true
ESP.OffScreenArrowSize = 15        -- Arrow size
ESP.OffScreenArrowRadius = 150     -- Distance from screen center
```

### Conditional Rendering

Use `IsEnabled` to conditionally show ESP:

```lua
-- Using a global flag
ESP:Add(object, {
    IsEnabled = "ShowChests"  -- Checks ESP.ShowChests
})

-- Using a function
ESP:Add(object, {
    IsEnabled = function(box)
        return box.distance < 200
    end
})
```

### Dynamic Colors

Use `ColorDynamic` for colors that change over time:

```lua
ESP:Add(object, {
    ColorDynamic = function(box)
        if box.distance < 50 then
            return Color3.fromRGB(255, 0, 0)  -- Red when close
        else
            return Color3.fromRGB(0, 255, 0)  -- Green when far
        end
    end
})
```

---

## Examples

### Example 1: Basic Player ESP

```lua
local ESP = loadstring(game:HttpGet("..."))()

-- Enable ESP with default settings
ESP:Toggle(true)

-- Customize player ESP
ESP.Player.Boxes = true
ESP.Player.Names = true
ESP.Player.Distance = true
ESP.Player.HealthBars = true
ESP.Player.Tracers = false

-- Use team colors
ESP.TeamColor = true

-- Don't show teammates
ESP.TeamMates = false
```

### Example 2: Item ESP with Listener

```lua
-- Track all parts named "Coin" in workspace
ESP:AddObjectListener(workspace, {
    Type = "Part",
    Name = "Coin",
    Recursive = true,
    Color = Color3.fromRGB(255, 215, 0),
    CustomName = "Coin",
    IsEnabled = function(box)
        return box.distance < 300
    end
})

ESP:Toggle(true)
```

### Example 3: Custom Object ESP

```lua
-- Add ESP to a specific model
local box = ESP:Add(workspace.ImportantChest, {
    Name = "Legendary Chest",
    Color = Color3.fromRGB(138, 43, 226),
    PrimaryPart = workspace.ImportantChest.Main
})

-- Later, remove it
box:Remove()
```

### Example 4: Vehicle ESP

```lua
ESP:AddObjectListener(workspace.Vehicles, {
    Type = "Model",
    Recursive = false,
    PrimaryPart = function(vehicle)
        return vehicle:FindFirstChild("VehicleSeat")
    end,
    CustomName = function(vehicle)
        return vehicle.Name .. " (Vehicle)"
    end,
    Color = Color3.fromRGB(100, 150, 255),
    Validator = function(vehicle)
        return vehicle:FindFirstChild("VehicleSeat") ~= nil
    end
})
```

### Example 5: Weapon Display

```lua
-- Enable weapon display
ESP.Player.Weapon = true

-- Set weapon getter
ESP.Overrides.GetWeapon = function(player)
    if player.Character then
        local tool = player.Character:FindFirstChildOfClass("Tool")
        if tool then
            return tool.Name
        end
    end
    return nil
end

ESP:Toggle(true)
```

### Example 6: Distance-Based Highlights

```lua
-- Only highlight very close targets
ESP.HighlightDistance = 50
ESP.HighlightBudget = 10

-- Make highlights more visible when close
ESP.HighlightFillTransparency = 0.3
ESP.HighlightOutlineTransparency = 0

ESP.Player.Highlights = true
ESP:Toggle(true)
```

### Example 7: Custom Team Detection

```lua
-- Custom team system
ESP.Overrides.GetTeam = function(player)
    -- Your custom team logic
    return player:GetAttribute("CustomTeam")
end

ESP.Overrides.IsTeamMate = function(player)
    local localPlayer = game.Players.LocalPlayer
    return player:GetAttribute("CustomTeam") == localPlayer:GetAttribute("CustomTeam")
end

ESP.TeamColor = true
ESP.TeamMates = false
ESP:Toggle(true)
```

---

## Performance Tips

1. **Limit Highlight Budget**: Keep `HighlightBudget` at 31 or lower for best performance
2. **Use Distance Filtering**: Set reasonable `HighlightDistance` values
3. **Disable Unused Features**: Turn off tracers, 3D boxes, etc. if not needed
4. **Use Validators**: Filter objects in `AddObjectListener` to avoid tracking unnecessary items
5. **Conditional Rendering**: Use `IsEnabled` to hide distant or irrelevant objects

---

## Troubleshooting

### ESP not showing
- Check `ESP.Enabled` is `true`
- Verify objects have valid `PrimaryPart`
- Ensure objects are descendants of `Workspace`
- Check that the Drawing library is available

### Colors not working
- Verify `ESP.TeamColor` setting
- Check if custom colors are set in `Add()` options
- Review `GetColor` override if set

### Performance issues
- Reduce `HighlightBudget`
- Disable 3D boxes and tracers
- Use distance-based filtering with `IsEnabled`
- Limit the number of tracked objects

### Highlights not appearing
- Check `ESP.Player.Highlights` or `ESP.Instance.Highlights` is `true`
- Verify `HighlightDistance` is sufficient
- Ensure objects are within the budget limit
- Check that objects are renderable (in workspace)

---

## Notes

- This library requires the Drawing API, typically only available in exploit environments
- Player ESP is automatically set up for all players in the game
- Objects are automatically cleaned up when removed from the game (if `AutoRemove` is not false)
- The library uses object pooling for highlights to maintain performance
- All drawing operations occur on `RenderStepped` for smooth updates
