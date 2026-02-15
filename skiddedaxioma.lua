local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua'))()
local ThemeManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua'))()


local Toggles, Options = Toggles, Options
local workspace = workspace
local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local ESP_Cache = {}

local HitSounds = {
    ["Skeet"] = "5633695679",
    ["Neverlose"] = "6534948092",
    ["Bameware"] = "3124332331"
}


local originalFireRates = {}
local originalAuto = {}
local originalValues = {}
local originalSpreads = {}
local originalBullets = {}
local originalPenetration = {}
local infAmmoEnabled = false
local WeaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
local maxPenetrationDepth = math.huge
local lastAutoFireTime = 0
local lastJitterTime = 0


local spinBotEnabled = false
local spinBotSpeed = 10
local backwardAAEnabled = false
local jitterEnabled = false
local jitterFromAngle = -45
local jitterToAngle = 45
local jitterSpeed = 5
local jitterCurrentAngle = -45
local jitterToggleState = false
local customYawEnabled = false
local customYawAngle = 0
local pitchChangerEnabled = false
local currentPitchValue = 0
local desyncEnabled = false
local desyncMode = "Void"
local desyncOldPosition = nil
local desyncTeleportPosition = nil
local desyncSetback = nil


local predictionHistory = {} 
local MAX_HISTORY = 10
local advancedPrediction = true


local controlTurnEvent = nil
task.spawn(function()
    local events = ReplicatedStorage:FindFirstChild("Events")
    if events then
        controlTurnEvent = events:FindFirstChild("ControlTurn")
    end
end)


local math_floor = math.floor
local math_huge = math.huge
local math_random = math.random
local math_rad = math.rad
local math_cos = math.cos
local math_sin = math.sin
local math_abs = math.abs
local math_sqrt = math.sqrt
local tick = tick
local Vector2_new = Vector2.new
local Vector3_new = Vector3.new
local Color3_new = Color3.new
local Color3_fromRGB = Color3.fromRGB
local CFrame_lookAt = CFrame.lookAt
local CFrame_new = CFrame.new
local CFrame_Angles = CFrame.Angles
local table_insert = table.insert
local table_remove = table.remove

local SkeletonConnections = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}, {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"Head", "Torso"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}
}


local function GetAdvancedPrediction(player, targetPart, basePrediction)
    local char = player.Character
    if not char then return targetPart.Position end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return targetPart.Position end
    

    if not predictionHistory[player] then
        predictionHistory[player] = {
            velocities = {},
            positions = {},
            lastUpdate = tick()
        }
    end
    
    local history = predictionHistory[player]
    local currentTime = tick()
    local deltaTime = currentTime - history.lastUpdate
    

    if deltaTime >= 0.016 then 
        local currentVel = hrp.Velocity
        local currentPos = hrp.Position
        
        table_insert(history.velocities, 1, currentVel)
        table_insert(history.positions, 1, currentPos)
        
  
        if #history.velocities > MAX_HISTORY then
            table_remove(history.velocities)
            table_remove(history.positions)
        end
        
        history.lastUpdate = currentTime
    end
    

    if #history.velocities < 3 then
        
        return targetPart.Position + (hrp.Velocity * basePrediction)
    end
    
   
    local avgVel = Vector3_new(0, 0, 0)
    for i = 1, math.min(5, #history.velocities) do
        avgVel = avgVel + history.velocities[i]
    end
    avgVel = avgVel / math.min(5, #history.velocities)
    
  
    local acceleration = Vector3_new(0, 0, 0)
    if #history.velocities >= 2 then
        local velDiff = history.velocities[1] - history.velocities[2]
        acceleration = velDiff / deltaTime
    end
    
  
    local isStrafing = false
    local strafeDirection = Vector3_new(0, 0, 0)
    
    if #history.velocities >= 4 then
        local vel1 = history.velocities[1]
        local vel2 = history.velocities[2]
        local vel3 = history.velocities[3]
        local vel4 = history.velocities[4]
        
        
        local dir1 = (vel1 - vel2).Unit
        local dir2 = (vel3 - vel4).Unit
        
       
        if dir1:Dot(dir2) < -0.5 then
            isStrafing = true
            strafeDirection = vel1.Unit
        end
    end
    
   
    local predictedPos = targetPart.Position
    
    if isStrafing then
        
        local strafePrediction = basePrediction * 0.7 
        predictedPos = predictedPos + (avgVel * strafePrediction)
        
       
        predictedPos = predictedPos + (strafeDirection * 2)
    else
        
        local predTime = basePrediction
        
        
        predictedPos = predictedPos + (hrp.Velocity * predTime) + (acceleration * 0.5 * predTime * predTime)
        
        
        local speed = hrp.Velocity.Magnitude
        if speed > 50 then
            local speedMultiplier = 1 + ((speed - 50) / 100) * 0.3
            predictedPos = predictedPos + (hrp.Velocity.Unit * speedMultiplier)
        end
    end
    
    return predictedPos
end


local function canShootThroughWalls(targetChar)
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end

    local origin = Camera.CFrame.Position
    local targetPos = targetRoot.Position
    local direction = targetPos - origin
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, targetChar}
    
    local currentOrigin = origin
    local remainingDepth = maxPenetrationDepth
    
    for i = 1, 4 do
        local result = workspace:Raycast(currentOrigin, direction, params)
        if not result then return true end
        
        if result.Instance:IsDescendantOf(targetChar) then return true end
        
        
        local mat = result.Material
        if mat == Enum.Material.Glass or mat == Enum.Material.Wood or 
           mat == Enum.Material.WoodPlanks or mat == Enum.Material.Plastic or 
           result.Instance.Transparency > 0.5 then
            remainingDepth = remainingDepth - ((result.Position - currentOrigin).Magnitude * 0.15)
        else
            remainingDepth = remainingDepth - ((result.Position - currentOrigin).Magnitude * 0.8)
        end
        
        if remainingDepth <= 0 then return false end
        
        currentOrigin = result.Position + direction.Unit * 0.1
        direction = targetPos - currentOrigin
    end
    
    return false
end


local function GetClosestTarget()
    local closestTarget = nil
    local closestPredictedPos = nil
    local maxDist = Options.silent_fov.Value
    local mousePos = UserInputService:GetMouseLocation()
    local targetPartName = Options.silent_target.Value == "Head" and "Head" or "UpperTorso"
    local disablers = Options.silent_disablers.Value

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChild("Humanoid")
            
            if hum and hum.Health > 0 then
                local root = char:FindFirstChild("HumanoidRootPart")
                
                if root then
                    local targetPart = char:FindFirstChild(targetPartName) or root
                    
                   
                    local passDisablers = true
                    if disablers["Teammates"] and player.Team == LocalPlayer.Team then
                        passDisablers = false
                    end
                    if passDisablers and disablers["ForceField"] and char:FindFirstChildOfClass("ForceField") then
                        passDisablers = false
                    end
                    
                    if passDisablers then
                        
                        local predictedPos = GetAdvancedPrediction(player, targetPart, Options.silent_pred.Value)
                        local screenPos, onScreen = Camera:WorldToViewportPoint(predictedPos)
                        
                        if onScreen then
                            
                            local passWallCheck = true
                            if disablers["Wall"] then
                                local parts = Camera:GetPartsObscuringTarget({LocalPlayer.Character, char}, {targetPart.Position})
                                if #parts > 0 then
                                    passWallCheck = false
                                end
                            end
                            
                            if passWallCheck then
                                local dist = (Vector2_new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                                if dist < maxDist then
                                    maxDist = dist
                                    closestTarget = targetPart
                                    closestPredictedPos = predictedPos
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestTarget, closestPredictedPos
end


local lastTracerState = nil
local function UpdateTracers()
    local enabled = Toggles.bullet_tracers.Value
    if lastTracerState == enabled then return end
    lastTracerState = enabled
    
    local rs = ReplicatedStorage
    local visModule = rs:FindFirstChild("VisualizeModule")
    if not visModule then return end
    
    local trailObj = visModule:FindFirstChild("Trail")
    if trailObj then
        trailObj.Transparency = enabled and NumberSequence.new(0) or NumberSequence.new(1)
        trailObj.Lifetime = Options.tracer_lifetime.Value
        trailObj.Color = ColorSequence.new(Options.tracer_col.Value)
        trailObj.MaxLength = enabled and 10000000 or 45
    end
    
    if enabled and WeaponsFolder then
        for _, gun in ipairs(WeaponsFolder:GetChildren()) do
            local bpt = gun:FindFirstChild("BulletPerTrail")
            if bpt and (bpt:IsA("IntValue") or bpt:IsA("NumberValue")) then
                bpt.Value = 1
            end
        end
    end
end


local function UpdateArmsChams()
    if not Toggles.arms_chams.Value then return end
    
    local color = Options.arms_chams_col.Value
    
    for _, model in ipairs(Camera:GetChildren()) do
        if model:IsA("Model") and (model.Name == "Arms" or model.Name == "ViewModel") then
            local highlight = model:FindFirstChild("ArmsHighlight")
            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name = "ArmsHighlight"
                highlight.Parent = model
            end
            
            highlight.Enabled = true
            highlight.FillColor = color
            highlight.OutlineColor = color
            highlight.FillTransparency = 0
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Material = Enum.Material.Plastic
                end
            end
        end
    end
end

local function IsEnemy(player)
    if not Toggles.team_check.Value then return true end
    if not player.Team then return true end
    return player.Team ~= LocalPlayer.Team
end


local function UpdateLocalChams()
    local char = LocalPlayer.Character
    if not char then return end

    local h = char:FindFirstChild("AxiomaLocalChams")
    if not h then
        h = Instance.new("Highlight")
        h.Name = "AxiomaLocalChams"
        h.Parent = char
    end
    
    if not Toggles.local_chams.Value then
        h.Enabled = false
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then 
                part.Material = Enum.Material.Plastic
            end
        end
        return
    end

    h.Enabled = true
    h.FillColor = Options.local_chams_col.Value
    h.OutlineTransparency = 1
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    local mat = Options.local_mat.Value
    local targetMaterial = mat == "Neon" and Enum.Material.Neon or Enum.Material.ForceField
    local color = Options.local_chams_col.Value
    
    h.FillTransparency = mat == "Neon" and 0 or 1
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then 
            part.Material = targetMaterial
            part.Color = color
        end
    end
end

local function UpdateWorld()
    if Toggles.world_enable.Value then
        Lighting.Ambient = Options.amb_col.Value
        Lighting.OutdoorAmbient = Options.amb_out_col.Value
        Lighting.ClockTime = Options.world_time.Value
    end
    if Toggles.fog_custom.Value then
        Lighting.FogColor = Options.fog_col.Value
        Lighting.FogStart = Options.fog_start.Value
        Lighting.FogEnd = Options.fog_end.Value
    end
end

local function ApplyChamsToPlayer(player)
    local function apply(char)
        if not char then return end
        
        local h = char:FindFirstChild("AxiomaChams")
        if not h then
            h = Instance.new("Highlight")
            h.Name = "AxiomaChams"
            h.Parent = char
        end
        
        local isEnemy = IsEnemy(player)
        h.Enabled = Toggles.chams_enable.Value and isEnemy
        h.FillColor = Options.chams_col.Value
        h.FillTransparency = (100 - Options.chams_trans.Value) / 100
        h.OutlineTransparency = 1 
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    end
    
    if player.Character then apply(player.Character) end
    player.CharacterAdded:Connect(apply)
end

local function UpdateEnemyChams()
    if not Toggles.chams_enable.Value then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local isEnemy = IsEnemy(player)
            
            if isEnemy then
                local h = player.Character:FindFirstChild("AxiomaChams")
                if h then
                    h.Enabled = true
                    h.FillColor = Options.chams_col.Value
                    h.FillTransparency = (100 - Options.chams_trans.Value) / 100
                else
                    ApplyChamsToPlayer(player)
                end
            end
        end
    end
end


local function Draw(type, properties)
    local drawing = Drawing.new(type)
    for k, v in pairs(properties) do drawing[k] = v end
    return drawing
end

local function createESP(player)
    if player == LocalPlayer then return end

    local objects = {
        BoxFill = Draw("Square", {Thickness = 0, Filled = true, ZIndex = 0, Visible = false}),
        BoxOutline = Draw("Square", {Thickness = 2, Color = Color3_new(0,0,0), ZIndex = 1, Visible = false}),
        Box = Draw("Square", {Thickness = 1, ZIndex = 2, Visible = false}),
        Corners = {}, 
        CornerOutlines = {},
        Name = Draw("Text", {Size = 13, Center = true, ZIndex = 3, Font = 2, Visible = false}),
        Dist = Draw("Text", {Size = 12, Center = true, ZIndex = 3, Font = 2, Visible = false}),
        HealthOutline = Draw("Line", {Thickness = 3, Color = Color3_new(0,0,0), ZIndex = 1, Visible = false}),
        HealthBar = Draw("Line", {Thickness = 1, ZIndex = 2, Visible = false}),
        SkeletonLines = {}
    }

    for i = 1, 8 do
        objects.CornerOutlines[i] = Draw("Line", {Thickness = 3, Color = Color3_new(0,0,0), ZIndex = 1, Visible = false})
        objects.Corners[i] = Draw("Line", {Thickness = 1, ZIndex = 2, Visible = false})
    end
    
    for i = 1, 20 do 
        objects.SkeletonLines[i] = Draw("Line", {Thickness = 1, ZIndex = 2, Visible = false}) 
    end
    
    ESP_Cache[player] = objects
    ApplyChamsToPlayer(player)
end


local Window = Library:CreateWindow({ Title = 'Skidded By Marcos @ycyberx22| .gg/25ms by ycyberx22', Center = true, AutoShow = true })
local CombatTab = Window:AddTab('Combat')
local AntiAimTab = Window:AddTab('Anti Aim')
local VisualsTab = Window:AddTab('Visuals')
local MiscTab = Window:AddTab('Misc')
local SettingsTab = Window:AddTab('Settings')

local ESPGroup = VisualsTab:AddLeftGroupbox('ESP Settings')
local FillGroup = VisualsTab:AddLeftGroupbox('Box Fill')
local OutlinesGroup = VisualsTab:AddLeftGroupbox('Outlines Settings')
local CameraGroup = VisualsTab:AddLeftGroupbox('Camera')

local WorldGroup = VisualsTab:AddRightGroupbox('World & Fog')
local ChamsGroup = VisualsTab:AddRightGroupbox('Enemy Chams')
local LocalChamsGroup = VisualsTab:AddRightGroupbox('Local Chams')
local ArmsGroup = VisualsTab:AddRightGroupbox('Arms / Guns Chams')
local TracersGroup = VisualsTab:AddRightGroupbox('Bullet Tracers')
local HitSoundGroup = VisualsTab:AddRightGroupbox('Hit Sound')
local SilentGroup = CombatTab:AddLeftGroupbox('Silent Aim')
local GunModsGroup = CombatTab:AddRightGroupbox('Gun Modifications')
local AutoFireGroup = CombatTab:AddRightGroupbox('Auto Fire')


local AngleGroup = AntiAimTab:AddLeftGroupbox('Angle Anti-Aim')
local DesyncGroup = AntiAimTab:AddRightGroupbox('Desync')
local PitchGroup = AntiAimTab:AddRightGroupbox('Pitch Changer')

local MovementGroup = MiscTab:AddLeftGroupbox('Movement')
local MiscGroup = MiscTab:AddRightGroupbox('Miscellaneous')

ESPGroup:AddToggle('team_check', { Text = 'Team Check', Default = false }) 
ESPGroup:AddToggle('esp_box', { Text = 'Enable Box', Default = false }):AddColorPicker('box_col', { Default = Color3_new(1,1,1) })
ESPGroup:AddDropdown('box_style', { Values = {'Full', 'Corner'}, Default = 1, Text = 'Box Style' })
ESPGroup:AddToggle('esp_name', { Text = 'Names', Default = false }):AddColorPicker('name_col', { Default = Color3_new(1,1,1) })
ESPGroup:AddToggle('esp_dist', { Text = 'Distance', Default = false }):AddColorPicker('dist_col', { Default = Color3_new(1,1,1) })
ESPGroup:AddToggle('esp_hp', { Text = 'Health Bar', Default = false }):AddColorPicker('hp_col', { Default = Color3_fromRGB(0, 255, 0) })
ESPGroup:AddToggle('esp_skel', { Text = 'Skeleton', Default = false }):AddColorPicker('skel_col', { Default = Color3_new(1,1,1) })

FillGroup:AddToggle('esp_fill', { Text = 'Enable Fill', Default = false }):AddColorPicker('fill_col', { Default = Color3_new(0,0,0) })
FillGroup:AddSlider('fill_trans', { Text = 'Fill Transparency', Default = 50, Min = 0, Max = 100, Rounding = 0 })

OutlinesGroup:AddToggle('esp_box_outline', { Text = 'Box Outline', Default = true })
OutlinesGroup:AddToggle('esp_name_outline', { Text = 'Name Outline', Default = true })
OutlinesGroup:AddToggle('esp_dist_outline', { Text = 'Distance Outline', Default = true })
OutlinesGroup:AddToggle('esp_hp_outline', { Text = 'Health Outline', Default = true })

CameraGroup:AddToggle('third_person', { Text = 'Third Person', Default = false })
CameraGroup:AddSlider('tp_dist', { Text = 'Distance', Default = 15, Min = 0, Max = 50, Rounding = 1 })

ChamsGroup:AddToggle('chams_enable', { Text = 'Enable Enemy Chams', Default = false }):AddColorPicker('chams_col', { Default = Color3_fromRGB(255, 0, 0) })
ChamsGroup:AddSlider('chams_trans', { Text = 'Transparency', Default = 50, Min = 0, Max = 100, Rounding = 0 })

LocalChamsGroup:AddToggle('local_chams', { Text = 'Enable Local Chams', Default = false }):AddColorPicker('local_chams_col', { Default = Color3_new(0, 1, 1) })
LocalChamsGroup:AddDropdown('local_mat', { Values = {'Neon', 'ForceField'}, Default = 1, Text = 'Material' })

WorldGroup:AddToggle('world_enable', { Text = 'World Mod', Default = false })
WorldGroup:AddSlider('world_time', { Text = 'Time', Default = 12, Min = 0, Max = 24, Rounding = 1 })
WorldGroup:AddLabel('Ambient'):AddColorPicker('amb_col', { Default = Color3_fromRGB(127, 127, 127) })
WorldGroup:AddLabel('Outdoor'):AddColorPicker('amb_out_col', { Default = Color3_fromRGB(127, 127, 127) })
WorldGroup:AddToggle('fog_custom', { Text = 'Custom Fog', Default = false })
WorldGroup:AddLabel('Fog Color'):AddColorPicker('fog_col', { Default = Color3_fromRGB(192, 192, 192) })
WorldGroup:AddSlider('fog_start', { Text = 'Fog Start', Default = 0, Min = 0, Max = 1000, Rounding = 0 })
WorldGroup:AddSlider('fog_end', { Text = 'Fog End', Default = 10000, Min = 0, Max = 100000, Rounding = 0 })

ArmsGroup:AddToggle('arms_chams', { Text = 'Enable Arms Chams', Default = false }):AddColorPicker('arms_chams_col', { Default = Color3_fromRGB(200, 200, 200) })

TracersGroup:AddToggle('bullet_tracers', { Text = 'Enable Tracers', Default = false })
TracersGroup:AddSlider('tracer_lifetime', { Text = 'Tracer Lifetime', Default = 1, Min = 0.1, Max = 10, Rounding = 1 })
TracersGroup:AddLabel('Tracer Color'):AddColorPicker('tracer_col', { Default = Color3_fromRGB(255, 0, 255) })

SilentGroup:AddToggle('silent_enabled', { Text = 'Enable Silent Aim', Default = false })
SilentGroup:AddToggle('show_fov', { Text = 'Show FOV', Default = false }):AddColorPicker('fov_col', { Default = Color3_fromRGB(255, 255, 255) })
SilentGroup:AddSlider('silent_fov', { Text = 'FOV Radius', Default = 100, Min = 10, Max = 1500, Rounding = 0 })
SilentGroup:AddSlider('silent_pred', { Text = 'Base Prediction', Default = 0.12, Min = 0, Max = 0.5, Rounding = 3 })
SilentGroup:AddToggle('advanced_pred', { Text = 'Advanced Prediction (HvH)', Default = true })
SilentGroup:AddDropdown('silent_disablers', { Values = { 'Wall', 'ForceField', 'Teammates' }, Default = { 'Teammates' }, Multi = true, Text = 'Disablers' })
SilentGroup:AddDropdown('silent_target', { Values = { 'Head', 'Torso' }, Default = 1, Multi = false, Text = 'Aim Part' })

GunModsGroup:AddToggle('rapid_fire', { Text = 'Rapid Fire', Default = false })
GunModsGroup:AddToggle('inf_ammo', { Text = 'Infinite Ammo', Default = false })
GunModsGroup:AddToggle('no_spread', { Text = 'No Spread', Default = false })
GunModsGroup:AddToggle('double_tap', { Text = 'Double Tap', Default = false })

AutoFireGroup:AddToggle('auto_fire', { Text = 'Enable Auto Fire', Default = false })
AutoFireGroup:AddToggle('wallbang', { Text = 'Wallbang', Default = false })
AutoFireGroup:AddSlider('auto_fire_delay', { Text = 'Fire Delay (ms)', Default = 75, Min = 50, Max = 500, Rounding = 0 })

MovementGroup:AddToggle('bhop', { Text = 'Bunny Hop', Default = false })
MovementGroup:AddSlider('bhop_speed', { Text = 'Bhop Speed', Default = 30, Min = 10, Max = 100, Rounding = 0 })
MovementGroup:AddSlider('bhop_smooth', { Text = 'Bhop Smoothing', Default = 0.3, Min = 0.1, Max = 1, Rounding = 2 })
MovementGroup:AddToggle('jump_bug', { Text = 'Jump Bug', Default = false })


AngleGroup:AddToggle('spinbot_enabled', { Text = 'Spin Bot', Default = false })
AngleGroup:AddSlider('spinbot_speed', { Text = 'Spin Speed', Default = 10, Min = 1, Max = 50, Rounding = 0 })
AngleGroup:AddDivider()

AngleGroup:AddToggle('jitter_enabled', { Text = 'Jitter', Default = false })
AngleGroup:AddSlider('jitter_from', { Text = 'Jitter From Angle', Default = -45, Min = -180, Max = 180, Rounding = 0 })
AngleGroup:AddSlider('jitter_to', { Text = 'Jitter To Angle', Default = 45, Min = -180, Max = 180, Rounding = 0 })
AngleGroup:AddSlider('jitter_speed', { Text = 'Jitter Speed', Default = 5, Min = 1, Max = 20, Rounding = 0 })
AngleGroup:AddDivider()

AngleGroup:AddToggle('backward_aa', { Text = 'Backward', Default = false })
AngleGroup:AddDivider()

AngleGroup:AddToggle('custom_yaw', { Text = 'Custom Yaw', Default = false })
AngleGroup:AddSlider('custom_yaw_angle', { Text = 'Yaw Angle', Default = 0, Min = -180, Max = 180, Rounding = 0 })


DesyncGroup:AddToggle('desync_enabled', { Text = 'Enable Desync', Default = false })
DesyncGroup:AddDropdown('desync_mode', { 
    Values = { 'Destroy Cheaters', 'Underground', 'Void Spam', 'Void', 'Rotation' }, 
    Default = 4, 
    Text = 'Desync Mode' 
})


PitchGroup:AddToggle('pitch_changer', { Text = 'Enable Pitch Changer', Default = false })
PitchGroup:AddDropdown('pitch_mode', { 
    Values = { 'Down', 'Up', 'Custom', 'Half Up', 'Half Down' }, 
    Default = 1, 
    Text = 'Pitch Mode' 
})
PitchGroup:AddSlider('pitch_custom', { Text = 'Custom Pitch', Default = 0, Min = -89, Max = 89, Rounding = 0 })

MiscGroup:AddToggle('no_fall_damage', { Text = 'No Fall Damage', Default = false })

HitSoundGroup:AddToggle('hitsound_enabled', { Text = 'Enable Hit Sound', Default = false })
HitSoundGroup:AddDropdown('hitsound_select', { Values = { 'Skeet', 'Neverlose', 'Bameware' }, Default = 1, Text = 'Sound' })
HitSoundGroup:AddSlider('hitsound_volume', { Text = 'Volume', Default = 3, Min = 0.1, Max = 10, Rounding = 1 })


Toggles.chams_enable:OnChanged(UpdateEnemyChams)
Toggles.team_check:OnChanged(UpdateEnemyChams)
Options.chams_col:OnChanged(UpdateEnemyChams)
Options.chams_trans:OnChanged(UpdateEnemyChams)

Toggles.local_chams:OnChanged(UpdateLocalChams)
Options.local_chams_col:OnChanged(UpdateLocalChams)
Options.local_mat:OnChanged(UpdateLocalChams)

Toggles.third_person:OnChanged(function()
    if not Toggles.third_person.Value then
        LocalPlayer.CameraMaxZoomDistance = 128
        LocalPlayer.CameraMinZoomDistance = 0.5
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
    end
end)

Toggles.advanced_pred:OnChanged(function(V)
    advancedPrediction = V
end)


Toggles.rapid_fire:OnChanged(function(V)
    if not WeaponsFolder then return end
    for _, w in ipairs(WeaponsFolder:GetChildren()) do
        local fr = w:FindFirstChild("FireRate")
        if fr and (fr:IsA("NumberValue") or fr:IsA("IntValue")) then
            if V then 
                if not originalFireRates[fr] then originalFireRates[fr] = fr.Value end 
                fr.Value = 0.03
            elseif originalFireRates[fr] then 
                fr.Value = originalFireRates[fr] 
            end
        end
        local auto = w:FindFirstChild("Auto")
        if auto and auto:IsA("BoolValue") then
            if V then 
                if originalAuto[auto] == nil then originalAuto[auto] = auto.Value end 
                auto.Value = true
            elseif originalAuto[auto] ~= nil then 
                auto.Value = originalAuto[auto] 
            end
        end
    end
end)


Toggles.inf_ammo:OnChanged(function(V)
    infAmmoEnabled = V
    if not WeaponsFolder then return end

    if infAmmoEnabled then
        
        for _, w in ipairs(WeaponsFolder:GetChildren()) do
            local ammo = w:FindFirstChild("Ammo")
            local stored = w:FindFirstChild("StoredAmmo")
            
            if ammo then
                if originalValues[ammo] == nil then originalValues[ammo] = ammo.Value end
                ammo.Value = 999999
            end
            if stored then
                if originalValues[stored] == nil then originalValues[stored] = stored.Value end
                stored.Value = 999999
            end
        end
        
        
        task.spawn(function()
            while infAmmoEnabled do
                for _, w in ipairs(WeaponsFolder:GetChildren()) do
                    local ammo = w:FindFirstChild("Ammo")
                    local stored = w:FindFirstChild("StoredAmmo")
                    
                    if ammo and ammo.Value < 999999 then
                        ammo.Value = 999999
                    end
                    if stored and stored.Value < 999999 then
                        stored.Value = 999999
                    end
                end
                task.wait(1) 
            end
        end)
    else
        for obj, originalValue in pairs(originalValues) do
            if obj and obj.Parent then obj.Value = originalValue end
        end
        originalValues = {} 
    end
end)

Toggles.no_spread:OnChanged(function(V)
    if not WeaponsFolder then return end
    for _, w in ipairs(WeaponsFolder:GetChildren()) do
        local s = w:FindFirstChild("Spread")
        if s then 
            for _, v in ipairs(s:GetDescendants()) do
                if v:IsA("NumberValue") then
                    if V then 
                        originalSpreads[v] = v.Value 
                        v.Value = 0
                    elseif originalSpreads[v] then 
                        v.Value = originalSpreads[v] 
                    end
                end
            end 
        end
    end
end)

Toggles.double_tap:OnChanged(function(V)
    if not WeaponsFolder then return end
    for _, w in ipairs(WeaponsFolder:GetChildren()) do
        local b = w:FindFirstChild("Bullets")
        if b and (b:IsA("IntValue") or b:IsA("NumberValue")) then
            if V then 
                if not originalBullets[b] then originalBullets[b] = b.Value end 
                b.Value = 2
            elseif originalBullets[b] then 
                b.Value = originalBullets[b]
            end
        end
    end
end)

Toggles.wallbang:OnChanged(function(V)
    if not WeaponsFolder then return end
    for _, w in ipairs(WeaponsFolder:GetChildren()) do
        local p = w:FindFirstChild("Penetration")
        if p and (p:IsA("NumberValue") or p:IsA("IntValue")) then
            if V then 
                if not originalPenetration[p] then originalPenetration[p] = p.Value end 
                p.Value = 999999999
            elseif originalPenetration[p] then 
                p.Value = originalPenetration[p] 
            end
        end
    end
end)

Toggles.no_fall_damage:OnChanged(function(V)
    local EventsFolder = ReplicatedStorage:FindFirstChild("Events")
    if not EventsFolder then return end
    
    local HiddenStorage = ReplicatedStorage:FindFirstChild("HiddenStorage")
    if not HiddenStorage then
        HiddenStorage = Instance.new("Folder")
        HiddenStorage.Name = "HiddenStorage"
        HiddenStorage.Parent = ReplicatedStorage
    end
    
    local FallDamageEvent = EventsFolder:FindFirstChild("FallDamage")
    if FallDamageEvent then 
        FallDamageEvent.Parent = V and HiddenStorage or EventsFolder 
    end
end)


Toggles.spinbot_enabled:OnChanged(function(V)
    spinBotEnabled = V
    if not V and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then humanoid.AutoRotate = true end
    end
end)

Options.spinbot_speed:OnChanged(function(V) spinBotSpeed = V end)

Toggles.jitter_enabled:OnChanged(function(V)
    jitterEnabled = V
    if V then
        jitterCurrentAngle = jitterFromAngle
        jitterToggleState = false
    end
    if not V and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then humanoid.AutoRotate = true end
    end
end)

Options.jitter_from:OnChanged(function(V) jitterFromAngle = V end)
Options.jitter_to:OnChanged(function(V) jitterToAngle = V end)
Options.jitter_speed:OnChanged(function(V) jitterSpeed = V end)

Toggles.backward_aa:OnChanged(function(V)
    backwardAAEnabled = V
    if not V and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then humanoid.AutoRotate = true end
    end
end)

Toggles.custom_yaw:OnChanged(function(V)
    customYawEnabled = V
    if not V and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then humanoid.AutoRotate = true end
    end
end)

Options.custom_yaw_angle:OnChanged(function(V) customYawAngle = V end)

Toggles.pitch_changer:OnChanged(function(V) pitchChangerEnabled = V end)

Options.pitch_mode:OnChanged(function(V)
    if V == "Down" then currentPitchValue = -89
    elseif V == "Up" then currentPitchValue = 89
    elseif V == "Half Up" then currentPitchValue = 45
    elseif V == "Half Down" then currentPitchValue = -45
    elseif V == "Custom" then currentPitchValue = Options.pitch_custom.Value
    end
end)

Options.pitch_custom:OnChanged(function(V)
    if Options.pitch_mode.Value == "Custom" then currentPitchValue = V end
end)

Toggles.desync_enabled:OnChanged(function(V) desyncEnabled = V end)
Options.desync_mode:OnChanged(function(V) desyncMode = V end)


task.spawn(function()
    desyncSetback = Instance.new("Part")
    desyncSetback.Name = "DesyncSetback"
    desyncSetback.Anchored = true
    desyncSetback.CanCollide = false
    desyncSetback.Transparency = 1
    desyncSetback.Size = Vector3_new(0.1, 0.1, 0.1)
    desyncSetback.Parent = workspace
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    UpdateLocalChams()
end)


local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 100
FOVCircle.Filled = false
FOVCircle.Transparency = 1


task.spawn(function()
    local Additionals = LocalPlayer:WaitForChild("Additionals", 15)
    if not Additionals then return end
    
    local TotalDamage = Additionals:WaitForChild("TotalDamage", 15)
    if not TotalDamage then return end
    
    TotalDamage.Changed:Connect(function(Value)
        if not Toggles.hitsound_enabled.Value or Value == 0 then return end
        
        local soundName = Options.hitsound_select.Value
        local soundID = HitSounds[soundName]
        
        local HitSound = Instance.new("Sound")
        HitSound.Parent = SoundService
        HitSound.SoundId = "rbxassetid://" .. soundID
        HitSound.Volume = Options.hitsound_volume.Value
        HitSound:Play()
        game:GetService("Debris"):AddItem(HitSound, 2)
    end)
end)


task.spawn(function()
    while task.wait() do
        if pitchChangerEnabled and controlTurnEvent then
            local pitchToSend = currentPitchValue / 10
            pcall(function()
                controlTurnEvent:FireServer(pitchToSend, false)
            end)
        end
    end
end)


local lastESPUpdate = 0
local ESP_UPDATE_RATE = 1/60 

RunService.RenderStepped:Connect(function()
    
    UpdateWorld()
    UpdateArmsChams()
    UpdateTracers()

    
    FOVCircle.Visible = Toggles.show_fov.Value
    if FOVCircle.Visible then
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Radius = Options.silent_fov.Value
        FOVCircle.Color = Options.fov_col.Value
    end

    
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        
        if hrp and humanoid then
            
            if spinBotEnabled then
                humanoid.AutoRotate = false
                hrp.CFrame = hrp.CFrame * CFrame_Angles(0, math_rad(spinBotSpeed), 0)
            elseif jitterEnabled then
                humanoid.AutoRotate = false
                local currentTime = tick()
                local switchDelay = 1 / jitterSpeed
                
                if currentTime - lastJitterTime >= switchDelay then
                    jitterToggleState = not jitterToggleState
                    jitterCurrentAngle = jitterToggleState and jitterToAngle or jitterFromAngle
                    lastJitterTime = currentTime
                end
                
                local camLook = Camera.CFrame.LookVector
                local yawAngle = math_rad(jitterCurrentAngle)
                local rotatedLook = Vector3_new(
                    camLook.X * math_cos(yawAngle) - camLook.Z * math_sin(yawAngle),
                    0,
                    camLook.X * math_sin(yawAngle) + camLook.Z * math_cos(yawAngle)
                )
                hrp.CFrame = CFrame_lookAt(hrp.Position, hrp.Position + rotatedLook)
            elseif backwardAAEnabled then
                humanoid.AutoRotate = false
                local camPos = Camera.CFrame.Position
                local targetPos = Vector3_new(camPos.X, hrp.Position.Y, camPos.Z)
                hrp.CFrame = CFrame_lookAt(hrp.Position, targetPos)
            elseif customYawEnabled then
                humanoid.AutoRotate = false
                local camLook = Camera.CFrame.LookVector
                local yawAngle = math_rad(customYawAngle)
                local rotatedLook = Vector3_new(
                    camLook.X * math_cos(yawAngle) - camLook.Z * math_sin(yawAngle),
                    0,
                    camLook.X * math_sin(yawAngle) + camLook.Z * math_cos(yawAngle)
                )
                hrp.CFrame = CFrame_lookAt(hrp.Position, hrp.Position + rotatedLook)
            else
                if not (spinBotEnabled or jitterEnabled or backwardAAEnabled or customYawEnabled) then
                    humanoid.AutoRotate = true
                end
            end
            
           
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                if Toggles.jump_bug.Value and humanoid.FloorMaterial ~= Enum.Material.Air then 
                    hrp.Velocity = Vector3_new(hrp.Velocity.X, 18, hrp.Velocity.Z) 
                end
                
                if Toggles.bhop.Value then
                    humanoid.Jump = true
                    local dir = Camera.CFrame.LookVector * Vector3_new(1,0,1)
                    local move = Vector3_new()
                    
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + dir end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - dir end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Vector3_new(-dir.Z,0,dir.X) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move + Vector3_new(dir.Z,0,-dir.X) end
                    
                    if move.Magnitude > 0 then
                        local target = move.Unit * Options.bhop_speed.Value
                        local smooth = Options.bhop_smooth.Value
                        hrp.Velocity = Vector3_new(
                            hrp.Velocity.X + (target.X - hrp.Velocity.X) * smooth, 
                            hrp.Velocity.Y, 
                            hrp.Velocity.Z + (target.Z - hrp.Velocity.Z) * smooth
                        )
                    end
                end
            end
        end
    end

    
    if Toggles.third_person.Value then
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = Options.tp_dist.Value
        LocalPlayer.CameraMinZoomDistance = Options.tp_dist.Value
    end


    local currentTime = tick()
    if currentTime - lastESPUpdate >= ESP_UPDATE_RATE then
        lastESPUpdate = currentTime
        
        for player, obj in pairs(ESP_Cache) do
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            local shouldRender = false
            
            if char and root and hum and hum.Health > 0 then
                local isEnemy = IsEnemy(player)
                if isEnemy then
                    local pos, vis = Camera:WorldToViewportPoint(root.Position)
                    if vis then
                        local distance = (Camera.CFrame.Position - root.Position).Magnitude
                        if distance <= 1000 then
                            shouldRender = true
                            
                           
                            local cf, size = char:GetBoundingBox()
                            local topY = Camera:WorldToViewportPoint(cf.Position + Vector3_new(0, size.Y/2, 0)).Y
                            local bottomY = Camera:WorldToViewportPoint(cf.Position - Vector3_new(0, size.Y/2, 0)).Y
                            local height = (topY - bottomY) * -1
                            local width = height * 0.55
                            local posVec = Vector2_new(pos.X - width/2, pos.Y - height/2)
                            local sizeVec = Vector2_new(width, height)

                         
                            if Toggles.esp_box.Value then
                                if Options.box_style.Value == 'Full' then
                                    for i=1,8 do 
                                        obj.Corners[i].Visible = false
                                        obj.CornerOutlines[i].Visible = false
                                    end
                                    
                                    obj.Box.Visible = true
                                    obj.Box.Size = sizeVec
                                    obj.Box.Position = posVec
                                    obj.Box.Color = Options.box_col.Value
                                    
                                    obj.BoxOutline.Visible = Toggles.esp_box_outline.Value
                                    obj.BoxOutline.Size = sizeVec
                                    obj.BoxOutline.Position = posVec
                                    
                                    obj.BoxFill.Visible = Toggles.esp_fill.Value
                                    if obj.BoxFill.Visible then
                                        obj.BoxFill.Size = sizeVec
                                        obj.BoxFill.Position = posVec
                                        obj.BoxFill.Color = Options.fill_col.Value
                                        obj.BoxFill.Transparency = (100 - Options.fill_trans.Value) / 100
                                    end
                                else
                                    obj.Box.Visible = false
                                    obj.BoxOutline.Visible = false
                                    obj.BoxFill.Visible = false
                                    
                                    local x, y = posVec.X, posVec.Y
                                    local r, b = x + width, y + height
                                    local lw, lh = width/4, height/4
                                    
                                    for i=1,8 do
                                        local cornerData = {
                                            {x, y, x+lw, y}, {x, y, x, y+lh},
                                            {r, y, r-lw, y}, {r, y, r, y+lh},
                                            {x, b, x+lw, b}, {x, b, x, b-lh},
                                            {r, b, r-lw, b}, {r, b, r, b-lh}
                                        }
                                        
                                        obj.CornerOutlines[i].Visible = Toggles.esp_box_outline.Value
                                        obj.CornerOutlines[i].From = Vector2_new(cornerData[i][1], cornerData[i][2])
                                        obj.CornerOutlines[i].To = Vector2_new(cornerData[i][3], cornerData[i][4])
                                        
                                        obj.Corners[i].Visible = true
                                        obj.Corners[i].From = Vector2_new(cornerData[i][1], cornerData[i][2])
                                        obj.Corners[i].To = Vector2_new(cornerData[i][3], cornerData[i][4])
                                        obj.Corners[i].Color = Options.box_col.Value
                                    end
                                end
                            else
                                obj.Box.Visible = false
                                obj.BoxOutline.Visible = false
                                obj.BoxFill.Visible = false
                                for i=1,8 do 
                                    obj.Corners[i].Visible = false
                                    obj.CornerOutlines[i].Visible = false
                                end
                            end

                           
                            obj.Name.Visible = Toggles.esp_name.Value
                            if obj.Name.Visible then 
                                obj.Name.Text = player.Name
                                obj.Name.Position = Vector2_new(pos.X, posVec.Y - 18)
                                obj.Name.Color = Options.name_col.Value
                                obj.Name.Outline = Toggles.esp_name_outline.Value 
                            end

                          
                            obj.Dist.Visible = Toggles.esp_dist.Value
                            if obj.Dist.Visible then 
                                obj.Dist.Text = math_floor(distance).."m"
                                obj.Dist.Position = Vector2_new(pos.X, posVec.Y + height + 2)
                                obj.Dist.Color = Options.dist_col.Value
                                obj.Dist.Outline = Toggles.esp_dist_outline.Value 
                            end

                          
                            if Toggles.esp_hp.Value then
                                local hpPct = hum.Health / hum.MaxHealth
                                local barHeight = height * hpPct
                                
                                obj.HealthOutline.Visible = Toggles.esp_hp_outline.Value
                                obj.HealthOutline.From = Vector2_new(posVec.X-6, posVec.Y)
                                obj.HealthOutline.To = Vector2_new(posVec.X-6, posVec.Y+height)
                                
                                obj.HealthBar.Visible = true
                                obj.HealthBar.From = Vector2_new(posVec.X-6, posVec.Y+height)
                                obj.HealthBar.To = Vector2_new(posVec.X-6, posVec.Y+height-barHeight)
                                obj.HealthBar.Color = Options.hp_col.Value
                            else
                                obj.HealthBar.Visible = false
                                obj.HealthOutline.Visible = false
                            end

                           
                            if Toggles.esp_skel.Value then
                                local idx = 1
                                for _, pair in ipairs(SkeletonConnections) do
                                    local pA = char:FindFirstChild(pair[1])
                                    local pB = char:FindFirstChild(pair[2])
                                    
                                    if pA and pB and idx <= 20 then
                                        local sA, vA = Camera:WorldToViewportPoint(pA.Position)
                                        local sB, vB = Camera:WorldToViewportPoint(pB.Position)
                                        
                                        if vA and vB then 
                                            obj.SkeletonLines[idx].Visible = true
                                            obj.SkeletonLines[idx].From = Vector2_new(sA.X, sA.Y)
                                            obj.SkeletonLines[idx].To = Vector2_new(sB.X, sB.Y)
                                            obj.SkeletonLines[idx].Color = Options.skel_col.Value
                                            idx = idx + 1 
                                        end
                                    end
                                end
                                for i=idx, 20 do obj.SkeletonLines[i].Visible = false end
                            else
                                for i=1, 20 do obj.SkeletonLines[i].Visible = false end
                            end
                        end
                    end
                end
            end
            
          
            if not shouldRender then
                obj.Box.Visible = false
                obj.BoxOutline.Visible = false
                obj.BoxFill.Visible = false
                obj.Name.Visible = false
                obj.Dist.Visible = false
                obj.HealthBar.Visible = false
                obj.HealthOutline.Visible = false
                for i=1,8 do 
                    obj.Corners[i].Visible = false
                    obj.CornerOutlines[i].Visible = false
                end
                for i=1, 20 do obj.SkeletonLines[i].Visible = false end
            end
        end
    end


    if Toggles.auto_fire.Value and LocalPlayer.Character then
        local currentTime = tick()
        local fireDelay = Options.auto_fire_delay.Value / 1000
        
        if currentTime - lastAutoFireTime >= fireDelay then
            local targetPart, predictedPos = GetClosestTarget()
            
            if targetPart and predictedPos then
                local targetChar = targetPart.Parent
                local canShoot = true
                
                if not Toggles.wallbang.Value then
                    local parts = Camera:GetPartsObscuringTarget({LocalPlayer.Character, targetChar}, {targetPart.Position})
                    canShoot = #parts == 0
                else
                    canShoot = canShootThroughWalls(targetChar)
                end
                
                if canShoot then
                    mouse1press()
                    task.defer(function()
                        task.wait(0.05)
                        mouse1release()
                    end)
                    lastAutoFireTime = currentTime
                end
            end
        end
    end

 
    if Toggles.silent_enabled.Value and LocalPlayer.Character and 
       UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        local targetPart, predictedPos = GetClosestTarget()
        
        if targetPart then
            local shootPos = predictedPos or targetPart.Position

            local originalCFrame = Camera.CFrame
            Camera.CFrame = CFrame_lookAt(originalCFrame.Position, shootPos)

            task.defer(function()
                Camera.CFrame = originalCFrame
            end)
        end
    end
end)


RunService.Heartbeat:Connect(function()
    if desyncEnabled and LocalPlayer.Character and desyncSetback then
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            desyncOldPosition = rootPart.CFrame
            

            if desyncMode == "Destroy Cheaters" then 
                desyncTeleportPosition = Vector3_new(999999999, 1, 1)
            elseif desyncMode == "Underground" then 
                desyncTeleportPosition = rootPart.Position - Vector3_new(0, 34, 0)
            elseif desyncMode == "Void Spam" then 
                if math_random(1, 2) == 1 then
                    desyncTeleportPosition = desyncOldPosition.Position
                else
                    desyncTeleportPosition = Vector3_new(
                        math_random(1000, 5000), 
                        math_random(1000, 5000), 
                        math_random(1000, 5000)
                    )
                end
            elseif desyncMode == "Void" then 
                desyncTeleportPosition = Vector3_new(
                    rootPart.Position.X + math_random(-3044, 3044), 
                    rootPart.Position.Y + math_random(-4044, 4044), 
                    rootPart.Position.Z + math_random(-3044, 3044)
                )
            end
            

            if desyncMode ~= "Rotation" then
                rootPart.CFrame = CFrame_new(desyncTeleportPosition)
                Camera.CameraSubject = desyncSetback
                RunService.RenderStepped:Wait()
                desyncSetback.CFrame = desyncOldPosition * CFrame_new(0, rootPart.Size.Y / 2 + 0.5, 0)
                rootPart.CFrame = desyncOldPosition
            end
        end
    end
end)


for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(function(p) 
    local cache = ESP_Cache[p]
    if cache then 
        for _, v in pairs(cache) do 
            if type(v) == "table" then 
                for _, l in pairs(v) do l:Remove() end 
            else 
                v:Remove() 
            end 
        end 
        ESP_Cache[p] = nil
    end

    predictionHistory[p] = nil
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder('Axioma.lua')
SaveManager:SetFolder('Axioma.lua')
ThemeManager:ApplyToTab(SettingsTab)
SaveManager:BuildConfigSection(SettingsTab)
