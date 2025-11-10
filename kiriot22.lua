-- || Enhanced ESP Library - Fork with Dynamic Names & Existing Object Detection ||
-- || Based on Kiriot22's ESP library with Sense ESP features ||
-- || NEW: Dynamic name updates via NameDynamic callback ||
-- || NEW: AddObjectListener now processes existing objects ||

--Services--
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

-- Constants
local NAME_OFFSET, DISTANCE_OFFSET, WEAPON_OFFSET = Vector2.new(0, 2), Vector2.new(0, 2), Vector2.new(0, 2)

--Settings--
local ESP = {
    -- Global Settings
    Enabled = false,
    TeamColor = true,
    Thickness = 2,
    TeamMates = true,
    Players = true,
    Color = Color3.fromRGB(255, 170, 0),

    -- Per-Type Settings
    Player = {
        Boxes = true,
        Boxes3D = false,
        Names = true,
        Distance = true,
        HealthBars = true,
        HealthText = true,
        Weapon = false,
        Tracers = false,
        Highlights = true,
        OffScreenArrows = true,
    },
    Instance = {
        Boxes = true,
        Boxes3D = false,
        Names = true,
        Distance = true,
        Highlights = false,
        Tracers = false,
        OffScreenArrows = false,
    },

    -- Global Visual Modifiers
    BoxShift = CFrame.new(0, -1.5, 0),
    BoxSize = Vector3.new(4, 6, 0),
    FaceCamera = false,
    AttachShift = 1,
    OffScreenArrowSize = 15,
    OffScreenArrowRadius = 150,
    HighlightDistance = 100,
    HighlightBudget = 31,
    HighlightFillColor = nil,
    HighlightOutlineColor = Color3.new(0,0,0),
    HighlightFillTransparency = 0.5,
    HighlightOutlineTransparency = 0,
    HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,

    -- System Tables
    Objects = setmetatable({}, { __mode = "kv" }),
    Overrides = { GetTeam = nil, GetWeapon = nil }
}

--Declarations--
local cam = Workspace.CurrentCamera
local plr = Players.LocalPlayer

-- Highlight Pool Manager
local highlightContainer = Instance.new("Folder", CoreGui)
highlightContainer.Name = "ESPHighlightContainer"
local highlightPool = {}
for i = 1, 31 do
    local h = Instance.new("Highlight")
    h.Enabled = false
    h.Parent = highlightContainer
    table.insert(highlightPool, h)
end

--Functions--
local function Draw(obj, props)
    local new = Drawing.new(obj)
    props = props or {}
    for i, v in pairs(props) do
        new[i] = v
    end
    return new
end

--region Helper Functions
local function rotateVector(vector, radians)
	local x, y = vector.X, vector.Y;
	local c, s = math.cos(radians), math.sin(radians);
	return Vector2.new(x*c - y*s, x*s + y*c)
end

local function getBoundingBox(parts)
    local min, max
    for i = 1, #parts do
        local part = parts[i]
        if part:IsA("BasePart") then
            local cframe, size = part.CFrame, part.Size
            local pos = cframe.Position
            min = min and pos:Min(min) or pos
            max = max and pos:Max(max) or pos
            min = min and (cframe - size / 2).Position:Min(min) or (cframe - size / 2).Position
            max = max and (cframe + size / 2).Position:Max(max) or (cframe + size / 2).Position
        end
    end
    if not min or not max then return end
    local center = (min + max) * 0.5
    return CFrame.new(center), max - min
end

local VERTICES = { Vector3.new(-1,-1,-1), Vector3.new(1,-1,-1), Vector3.new(1,1,-1), Vector3.new(-1,1,-1), Vector3.new(-1,-1,1), Vector3.new(1,-1,1), Vector3.new(1,1,1), Vector3.new(-1,1,1) }
local CUBE_EDGES = { 1,2, 2,3, 3,4, 4,1, 5,6, 6,7, 7,8, 8,5, 1,5, 2,6, 3,7, 4,8 }

local function calculateCorners(cframe, size)
    if not cframe or not size then return nil end
    local worldVertices, screenVertices = {}, {}
    for i = 1, #VERTICES do
        worldVertices[i] = (cframe * CFrame.new(size * VERTICES[i] / 2)).Position
    end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local allOnScreen = true
    for i, worldPos in ipairs(worldVertices) do
        local screenPos, onScreen = cam:WorldToViewportPoint(worldPos)
        if not onScreen then allOnScreen = false end
        local posVec2 = Vector2.new(screenPos.X, screenPos.Y)
        screenVertices[i] = posVec2
        minX = math.min(minX, posVec2.X); minY = math.min(minY, posVec2.Y)
        maxX = math.max(maxX, posVec2.X); maxY = math.max(maxY, posVec2.Y)
    end
    return { onScreen = allOnScreen, vertices = screenVertices, topLeft = Vector2.new(minX, minY), bottomRight = Vector2.new(maxX, maxY) }
end
--endregion

function ESP:GetTeam(p)
    if self.Overrides.GetTeam then return self.Overrides.GetTeam(p) end
    return p and p.Team
end

function ESP:IsTeamMate(p)
    local ov = self.Overrides.IsTeamMate
    if ov then return ov(p) end
    return (self:GetTeam(p) == self:GetTeam(plr)) or (plr.Neutral)
end

function ESP:GetColor(obj)
    local ov = self.Overrides.GetColor
    if ov then return ov(obj) end
    local p = self:GetPlrFromChar(obj)
    return p and self.TeamColor and p.Team and p.Team.TeamColor.Color or self.Color
end

function ESP:GetPlrFromChar(char)
    local ov = self.Overrides.GetPlrFromChar
    if ov then return ov(char) end
    return Players:GetPlayerFromCharacter(char)
end

function ESP:Toggle(bool)
    self.Enabled = bool
    if not bool then
        for i, v in pairs(self.Objects) do
            if v.Type == "Box" then
                if v.Temporary then
                    v:Remove()
                else
                    for i, v in pairs(v.Components) do v.Visible = false end
                end
            end
        end
    end
end

function ESP:GetBox(obj)
    return self.Objects[obj]
end

function ESP:AddObjectListener(parent, options)
    local function NewListener(c)
        if (type(options.Type) == "string" and c:IsA(options.Type) or options.Type == nil) then
            if (type(options.Name) == "string" and c.Name == options.Name or options.Name == nil) then
                if (not options.Validator or options.Validator(c)) then
                    local box = ESP:Add(c, {
                        PrimaryPart = type(options.PrimaryPart) == "string" and c:WaitForChild(options.PrimaryPart) or type(options.PrimaryPart) == "function" and options.PrimaryPart(c),
                        Color = type(options.Color) == "function" and options.Color(c) or options.Color,
                        ColorDynamic = options.ColorDynamic,
                        Name = type(options.CustomName) == "function" and options.CustomName(c) or options.CustomName,
                        NameDynamic = options.NameDynamic, -- NEW: Dynamic name callback
                        IsEnabled = options.IsEnabled,
                        RenderInNil = options.RenderInNil
                    })
                    if options.OnAdded then
                        coroutine.wrap(options.OnAdded)(box)
                    end
                end
            end
        end
    end
    
    -- NEW: Process existing objects first
    if options.Recursive then
        for i, v in pairs(parent:GetDescendants()) do
            coroutine.wrap(NewListener)(v)
        end
        parent.DescendantAdded:Connect(NewListener)
    else
        for i, v in pairs(parent:GetChildren()) do
            coroutine.wrap(NewListener)(v)
        end
        parent.ChildAdded:Connect(NewListener)
    end
end

local boxBase = {}; boxBase.__index = boxBase
function boxBase:Remove()
    ESP.Objects[self.Object] = nil
    for i, v in pairs(self.Components) do
        if type(v) == "table" then
            for _, line in ipairs(v) do line:Remove() end
        else
            v:Remove()
        end
    end
    table.clear(self.Components)
end

function boxBase:Update()
    if not self.PrimaryPart or not self.PrimaryPart.Parent then return self:Remove() end

    local settings = self.Player and ESP.Player or ESP.Instance
    local color = self.Color or (self.ColorDynamic and self:ColorDynamic()) or ESP:GetColor(self.Object) or ESP.Color
    
    -- NEW: Update dynamic name if callback exists
    if self.NameDynamic then
        local newName = self:NameDynamic()
        if newName then
            self.Name = newName
        end
    end
    
    local allow = true
    if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then allow = false end
    if self.Player and not ESP.TeamMates and ESP:IsTeamMate(self.Player) then allow = false end
    if self.Player and not ESP.Players then allow = false end
    if self.IsEnabled and (type(self.IsEnabled) == "string" and not ESP[self.IsEnabled] or type(self.IsEnabled) == "function" and not self:IsEnabled()) then allow = false end
    if not Workspace:IsAncestorOf(self.PrimaryPart) and not self.RenderInNil then allow = false end
    
    self.isRenderable = allow and settings.Highlights
    self.current_color = color
    if allow then
        self.distance = (cam.CFrame.Position - self.PrimaryPart.CFrame.Position).Magnitude
    else
        self.distance = math.huge
    end

    if not allow then
        for _, comp in pairs(self.Components) do
            if type(comp) == "table" then
                for _, item in ipairs(comp) do item.Visible = false end
            else
                comp.Visible = false
            end
        end
        return
    end

    local allParts = self.Object:IsA("Model") and self.Object:GetChildren() or { self.Object }
    local cframe, size = getBoundingBox(allParts)
    local screenPos, onScreen = cam:WorldToViewportPoint(cframe.p)
    if screenPos.Z < 0 then onScreen = false end

    local showArrows = settings.OffScreenArrows and not onScreen
    self.Components.Arrow.Visible = showArrows
    self.Components.ArrowOutline.Visible = showArrows
    if showArrows then
        local direction = (Vector2.new(screenPos.X, screenPos.Y) - cam.ViewportSize / 2).Unit
        local radius = math.min(cam.ViewportSize.X, cam.ViewportSize.Y) / 2 * (ESP.OffScreenArrowRadius / 150)
        local center = cam.ViewportSize / 2
        local arrow = self.Components.Arrow
        arrow.PointA = center + direction * radius
        arrow.PointB = arrow.PointA - rotateVector(direction, 0.45) * ESP.OffScreenArrowSize
        arrow.PointC = arrow.PointA - rotateVector(direction, -0.45) * ESP.OffScreenArrowSize
        arrow.Color = color
        local arrowOutline = self.Components.ArrowOutline
        arrowOutline.PointA, arrowOutline.PointB, arrowOutline.PointC = arrow.PointA, arrow.PointB, arrow.PointC
        arrowOutline.Color = Color3.new(0, 0, 0)
        
        for name, comp in pairs(self.Components) do
            if name ~= "Arrow" and name ~= "ArrowOutline" then
                if type(comp) == "table" then
                    for _, c in ipairs(comp) do c.Visible = false end
                else
                    comp.Visible = false
                end
            end
        end
        return
    end

    local corners = calculateCorners(cframe, size)
    if not corners then
        for _, comp in pairs(self.Components) do
            if type(comp) == "table" then
                for _, item in ipairs(comp) do item.Visible = false end
            else
                comp.Visible = false
            end
        end
        return
    end

    local topLeft, bottomRight = corners.topLeft, corners.bottomRight
    local topRight = Vector2.new(bottomRight.X, topLeft.Y)
    local bottomLeft = Vector2.new(topLeft.X, bottomRight.Y)

    local show3DBox = settings.Boxes3D and corners.onScreen
    for i, line in ipairs(self.Components.Box3D) do
        line.Visible = show3DBox
        if show3DBox then
            line.Color = color
            local edgeStart, edgeEnd = CUBE_EDGES[i * 2 - 1], CUBE_EDGES[i * 2]
            line.From = corners.vertices[edgeStart]
            line.To = corners.vertices[edgeEnd]
        end
    end

    local show2DBox = settings.Boxes and not show3DBox and corners.onScreen
    self.Components.Quad.Visible = show2DBox
    if show2DBox then
        self.Components.Quad.PointA = topRight; self.Components.Quad.PointB = topLeft; self.Components.Quad.PointC = bottomLeft; self.Components.Quad.PointD = bottomRight
        self.Components.Quad.Color = color
    end

    local humanoid = self.Object and self.Object:FindFirstChildOfClass("Humanoid")
    local showHealth = not not (settings.HealthBars and humanoid and corners.onScreen)
    self.Components.HealthBar.Visible, self.Components.HealthBarOutline.Visible = showHealth, showHealth
    self.Components.HealthText.Visible = showHealth and settings.HealthText
    if showHealth then
        local health, maxHealth = humanoid.Health, humanoid.MaxHealth
        local healthPercent = math.clamp(health / maxHealth, 0, 1)
        local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
        local barTop, barBottom = topLeft - HEALTH_BAR_OFFSET, bottomLeft - HEALTH_BAR_OFFSET
        self.Components.HealthBarOutline.From = barTop - Vector2.new(0, 1); self.Components.HealthBarOutline.To = barBottom + Vector2.new(0, 1)
        self.Components.HealthBar.To = barBottom; self.Components.HealthBar.From = barBottom:Lerp(barTop, healthPercent)
        self.Components.HealthBar.Color = Color3.fromHSV(0.33 * healthPercent, 1, 1)
        if settings.HealthText then
            local healthText = self.Components.HealthText
            healthText.Text = math.floor(health) .. " HP"
            healthText.Position = self.Components.HealthBar.From - Vector2.new(healthText.TextBounds.X + 3, healthText.TextBounds.Y / 2)
            healthText.Color = color
        end
    end

    local nameText = self.Components.Name; nameText.Visible = settings.Names and corners.onScreen
    if nameText.Visible then
        nameText.Position = (topLeft + topRight) / 2 - Vector2.new(0, nameText.TextBounds.Y) - NAME_OFFSET
        nameText.Text = self.Name; nameText.Color = color
    end

    local distText = self.Components.Distance; distText.Visible = settings.Distance and corners.onScreen
    if distText.Visible then
        distText.Position = (bottomLeft + bottomRight) / 2 + DISTANCE_OFFSET
        distText.Text = math.floor((cam.CFrame.p - cframe.p).magnitude) .. "m"
        distText.Color = color
    end

    local weaponText = self.Components.Weapon
    local weaponName = self.Player and ESP.Overrides.GetWeapon and ESP.Overrides.GetWeapon(self.Player)
    weaponText.Visible = not not (settings.Weapon and weaponName and corners.onScreen)
    if weaponText.Visible then
        local yOffset = settings.Distance and distText.TextBounds.Y or 0
        weaponText.Position = (bottomLeft + bottomRight) / 2 + DISTANCE_OFFSET + Vector2.new(0, yOffset) + WEAPON_OFFSET
        weaponText.Text = weaponName; weaponText.Color = color
    end

    if settings.Tracers then
        local TorsoPos, Vis6 = cam:WorldToViewportPoint(cframe.p)
        if Vis6 then
            self.Components.Tracer.Visible = true; self.Components.Tracer.From = Vector2.new(TorsoPos.X, TorsoPos.Y); self.Components.Tracer.To = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / ESP.AttachShift); self.Components.Tracer.Color = color
        else
            self.Components.Tracer.Visible = false
        end
    else
        self.Components.Tracer.Visible = false
    end
end

function ESP:Add(obj, options)
    if self:GetBox(obj) then self:GetBox(obj):Remove() end
    local box = setmetatable({ 
        Name = options.Name or obj.Name, 
        Type = "Box", 
        Color = options.Color, 
        Size = options.Size or ESP.BoxSize, 
        Object = obj, 
        Player = options.Player or Players:GetPlayerFromCharacter(obj), 
        PrimaryPart = options.PrimaryPart or obj.ClassName == "Model" and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj:IsA("BasePart") and obj, 
        Components = {}, 
        IsEnabled = options.IsEnabled, 
        Temporary = options.Temporary, 
        ColorDynamic = options.ColorDynamic,
        NameDynamic = options.NameDynamic, -- NEW: Store dynamic name callback
        RenderInNil = options.RenderInNil 
    }, boxBase)
    
    box.Components["Quad"] = Draw("Quad", { Thickness = ESP.Thickness, Transparency = 1, Filled = false })
    box.Components["Name"] = Draw("Text", { Center = true, Outline = true, Size = 19 })
    box.Components["Distance"] = Draw("Text", { Center = true, Outline = true, Size = 19 })
    box.Components["Tracer"] = Draw("Line", { Thickness = ESP.Thickness, Transparency = 1 })
    box.Components["Weapon"] = Draw("Text", {Center = true, Outline = true, Size = 19})
    box.Components["HealthBarOutline"] = Draw("Line", { Thickness = 5, Color = Color3.new(0,0,0), ZIndex = 1 })
    box.Components["HealthBar"] = Draw("Line", { Thickness = 3, ZIndex = 2 })
    box.Components["HealthText"] = Draw("Text", { Outline = true, Size = 16 })
    box.Components["Box3D"] = {}
    for i = 1, 12 do table.insert(box.Components.Box3D, Draw("Line", { Thickness = ESP.Thickness })) end
    box.Components["Arrow"] = Draw("Triangle", {Filled = true})
    box.Components["ArrowOutline"] = Draw("Triangle", {Thickness = 3, Filled = false})

    self.Objects[obj] = box
    obj.AncestryChanged:Connect(function(_, parent) if parent == nil and ESP.AutoRemove ~= false then box:Remove() end end)
    local hum = obj:FindFirstChildOfClass("Humanoid"); if hum then hum.Died:Connect(function() if ESP.AutoRemove ~= false then box:Remove() end end) end
    return box
end

local function CharAdded(char)
    local p = Players:GetPlayerFromCharacter(char)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end
    ESP:Add(char, { Name = p.Name, Player = p, PrimaryPart = hrp })
end
local function PlayerAdded(p)
    p.CharacterAdded:Connect(CharAdded)
    if p.Character then
        coroutine.wrap(CharAdded)(p.Character)
    end
end
Players.PlayerAdded:Connect(PlayerAdded)
for i, v in pairs(Players:GetPlayers()) do
    if v ~= plr then PlayerAdded(v) end
end

-- Main Render Loop
RunService.RenderStepped:Connect(function()
    cam = Workspace.CurrentCamera
    for _, v in (ESP.Enabled and pairs or ipairs)(ESP.Objects) do
        if v.Update then
            pcall(v.Update, v)
        end
    end

    if ESP.Enabled then
        local renderableTargets = {}
        for _, espBox in pairs(ESP.Objects) do
            local settings = espBox.Player and ESP.Player or ESP.Instance
            if espBox.isRenderable and settings.Highlights and espBox.distance <= ESP.HighlightDistance then
                table.insert(renderableTargets, espBox)
            end
        end
        table.sort(renderableTargets, function(a,b) return a.distance < b.distance end)
        
        for i = 1, #highlightPool do
            local h = highlightPool[i]
            local t = renderableTargets[i]
            if t and i <= ESP.HighlightBudget then
                h.Enabled = true
                h.Adornee = t.Object
                h.FillColor = ESP.HighlightFillColor or t.current_color
                h.FillTransparency = ESP.HighlightFillTransparency
                h.OutlineColor = ESP.HighlightOutlineColor
                h.OutlineTransparency = ESP.HighlightOutlineTransparency
                h.DepthMode = ESP.HighlightDepthMode
            else
                h.Enabled = false
                h.Adornee = nil
            end
        end
    else
        for _, h in ipairs(highlightPool) do
            h.Enabled = false
            h.Adornee = nil
        end
    end
end)

return ESP
