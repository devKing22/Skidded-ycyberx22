-- Basic Menu & ESP
-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

-- Local Player
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Configuration
local Config = {
    BoxESP = false,
    NameESP = false,
    MenuOpen = true
}

-- Drawing Cache
local ESP_Cache = {}

-- UI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NullSyntaxMenu"
-- Try to parent to CoreGui for safety/hide from game, fallback to PlayerGui
if pcall(function() ScreenGui.Parent = CoreGui end) then
else
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Title.Text = "NullSyntax Menu"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18
Title.Parent = MainFrame

-- Draggable Logic
local dragging, dragInput, dragStart, startPos
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Toggles
local function CreateToggle(name, yPos, configKey)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, -20, 0, 30)
    Button.Position = UDim2.new(0, 10, 0, yPos)
    Button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    Button.Text = name .. ": OFF"
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.Parent = MainFrame
    
    Button.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        Button.Text = name .. ": " .. (Config[configKey] and "ON" or "OFF")
        Button.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(60, 60, 60)
    end)
end

CreateToggle("Box ESP", 40, "BoxESP")
CreateToggle("Name ESP", 80, "NameESP")

-- Menu Toggle Key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Insert then
        Config.MenuOpen = not Config.MenuOpen
        MainFrame.Visible = Config.MenuOpen
    end
end)

-- ESP Functions
local function CreateDrawing(type, properties)
    local drawing = Drawing.new(type)
    for k, v in pairs(properties) do
        drawing[k] = v
    end
    return drawing
end

local function AddESP(player)
    if player == LocalPlayer then return end
    
    local Objects = {
        Box = CreateDrawing("Square", {
            Thickness = 1,
            Color = Color3.new(1, 0, 0),
            Filled = false,
            Visible = false
        }),
        Name = CreateDrawing("Text", {
            Text = player.Name,
            Color = Color3.new(1, 1, 1),
            Center = true,
            Outline = true,
            Visible = false,
            Size = 16
        })
    }
    
    ESP_Cache[player] = Objects
end

local function RemoveESP(player)
    if ESP_Cache[player] then
        for _, drawing in pairs(ESP_Cache[player]) do
            drawing:Remove()
        end
        ESP_Cache[player] = nil
    end
end

-- Update Loop
RunService.RenderStepped:Connect(function()
    for player, objects in pairs(ESP_Cache) do
        if not player.Parent then
            RemoveESP(player)
            continue
        end
        
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
            local rootPart = character.HumanoidRootPart
            local head = character:FindFirstChild("Head")
            
            local vector, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
            
            if onScreen then
                local rootPos = rootPart.Position
                local headPos = head and head.Position or (rootPos + Vector3.new(0, 2, 0))
                local legPos = rootPos - Vector3.new(0, 3, 0)
                
                local headVec = Camera:WorldToViewportPoint(headPos + Vector3.new(0, 0.5, 0))
                local legVec = Camera:WorldToViewportPoint(legPos)
                
                local height = legVec.Y - headVec.Y
                local width = height / 2
                
                -- Box ESP
                if Config.BoxESP then
                    objects.Box.Visible = true
                    objects.Box.Size = Vector2.new(width, height)
                    objects.Box.Position = Vector2.new(vector.X - width / 2, headVec.Y)
                else
                    objects.Box.Visible = false
                end
                
                -- Name ESP
                if Config.NameESP then
                    objects.Name.Visible = true
                    objects.Name.Position = Vector2.new(vector.X, headVec.Y - 20)
                else
                    objects.Name.Visible = false
                end
            else
                objects.Box.Visible = false
                objects.Name.Visible = false
            end
        else
            objects.Box.Visible = false
            objects.Name.Visible = false
        end
    end
end)

-- Player Events
Players.PlayerAdded:Connect(AddESP)
Players.PlayerRemoving:Connect(RemoveESP)

for _, player in pairs(Players:GetPlayers()) do
    AddESP(player)
end
