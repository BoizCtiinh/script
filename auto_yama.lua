-- Blox Fruits Elite Hunter V2 - Complete Version
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

print("========================================")
print("Elite Hunter V2 - Initializing...")
print("========================================")

-- STEP 1: CHOOSE TEAM
print("[1/3] Choosing team...")

local function ChooseTeam()
    local success1 = pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local commF = remotes:FindFirstChild("CommF_")
            if commF then
                commF:InvokeServer("SetTeam", "Pirates")
                print("✓ Team set via RemoteFunction")
                return true
            end
        end
    end)
    
    if success1 then
        task.wait(0.5)
        if Player.Team then
            print("✓ Team confirmed: " .. tostring(Player.Team))
            return true
        end
    end
    
    print("Trying UI method...")
    local attempts = 0
    repeat
        attempts = attempts + 1
        task.wait(0.5)
        
        pcall(function()
            local main = PlayerGui:FindFirstChild("Main")
            if main then
                local chooseTeam = main:FindFirstChild("ChooseTeam")
                if chooseTeam and chooseTeam.Visible then
                    local container = chooseTeam:FindFirstChild("Container")
                    if container then
                        local pirates = container:FindFirstChild("Pirates")
                        if pirates then
                            for _, child in pairs(pirates:GetDescendants()) do
                                if child:IsA("TextButton") then
                                    for _, connection in pairs(getconnections(child.Activated)) do
                                        connection:Fire()
                                    end
                                    print("✓ Clicked Pirates button")
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end)
        
    until Player.Team ~= nil or attempts >= 10
    
    if Player.Team then
        print("✓ Team selected: " .. tostring(Player.Team))
        return true
    else
        warn("⚠ Could not select team")
        return false
    end
end

ChooseTeam()
task.wait(1)

-- STEP 2: LOAD CONFIG
print("[2/3] Loading configuration...")

-- Config file path (per user)
local CONFIG_FILE = Player.Name .. "_elite_config.json"

local function loadConfig()
    local success, result = pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            local content = readfile(CONFIG_FILE)
            local config = HttpService:JSONDecode(content)
            print("✓ Config loaded for user: " .. Player.Name)
            return config
        end
    end)
    
    if success and result then
        return result
    end
    
    print("✓ Using default config for: " .. Player.Name)
    return {
        autoHop = false,
        autoFarm = false,
        autoYama = false,
        noAttackAnimation = true
    }
end

local function saveConfig(config)
    pcall(function()
        if writefile then
            local json = HttpService:JSONEncode(config)
            writefile(CONFIG_FILE, json)
            print("✓ Config saved to: " .. CONFIG_FILE)
        else
            warn("⚠ writefile not supported")
        end
    end)
end

local savedConfig = loadConfig()

-- CONFIG
local AUTO_HOP_ENABLED = savedConfig.autoHop
local AUTO_FARM_ENABLED = savedConfig.autoFarm
local AUTO_YAMA_ENABLED = savedConfig.autoYama or false
local NO_ATTACK_ANIMATION = savedConfig.noAttackAnimation
local CHECK_INTERVAL = 5
local HOP_DELAY = 3
_G.SelectWeapon = _G.SelectWeapon or "Melee" -- Default weapon is Melee

-- Auto select melee weapon
task.spawn(function()
    while wait(0.5) do
        pcall(function()
            if _G.SelectWeapon == "Melee" then
                for _, v in pairs(Player.Backpack:GetChildren()) do
                    if v.ToolTip == "Melee" then
                        if Player.Backpack:FindFirstChild(tostring(v.Name)) then
                            _G.SelectWeapon = v.Name
                            break
                        end
                    end
                end
            end
        end)
    end
end)

-- NO ATTACK ANIMATION
if NO_ATTACK_ANIMATION then
    task.spawn(function()
        local Client = game.Players.LocalPlayer
        
        pcall(function()
            local CombatFramework = Client.PlayerScripts:FindFirstChild("CombatFramework")
            if CombatFramework then
                local Particle = CombatFramework:FindFirstChild("Particle")
                local STOP = Particle and require(Particle)
                
                local RigLib = game:GetService("ReplicatedStorage").CombatFramework:FindFirstChild("RigLib")
                local STOPRL = RigLib and require(RigLib)
                
                if STOP and STOPRL then
                    while task.wait() do
                        pcall(function()
                            -- Backup original functions
                            if not shared.orl then 
                                shared.orl = STOPRL.wrapAttackAnimationAsync 
                            end
                            if not shared.cpc then 
                                shared.cpc = STOP.play 
                            end
                            
                            -- Hook wrapAttackAnimationAsync
                            STOPRL.wrapAttackAnimationAsync = function(a, b, c, d, func)
                                local Hits = STOPRL.getBladeHits(b, c, d)
                                if Hits then
                                    if NO_ATTACK_ANIMATION then
                                        -- Disable particle effects
                                        STOP.play = function() end
                                        
                                        -- Play animation instantly (no visible animation)
                                        a:Play(0.01, 0.01, 0.01)
                                        
                                        -- Execute hit function
                                        func(Hits)
                                        
                                        -- Restore particle function
                                        STOP.play = shared.cpc
                                        
                                        -- Wait half animation length then stop
                                        wait(a.length * 0.5)
                                        a:Stop()
                                    else
                                        -- Normal animation
                                        a:Play()
                                    end
                                end
                            end
                        end)
                    end
                else
                    warn("⚠ CombatFramework modules not found for NoAttackAnimation")
                end
            end
        end)
    end)
    
    -- Also remove visual effects
    task.spawn(function()
        while wait(0.5) do
            pcall(function()
                if Player.Character and NO_ATTACK_ANIMATION then
                    for _, effect in pairs(Player.Character:GetDescendants()) do
                        if effect:IsA("ParticleEmitter") or effect:IsA("Trail") or effect:IsA("Beam") then
                            effect.Enabled = false
                        end
                    end
                end
            end)
        end
    end)
    
    print("✓ No Attack Animation enabled")
end

-- FAST ATTACK SETUP
_G.FastAttack = true
_G.FastAttackMethod = 1 -- Method 1 by default, will auto switch to Method 2 if failed

-- Fast Attack Method 1 (Primary)
if _G.FastAttack then
    local _ENV = (getgenv or getrenv or getfenv)()

    local function SafeWaitForChild(parent, childName)
        local success, result = pcall(function()
            return parent:WaitForChild(childName, 5)
        end)
        if not success or not result then
            warn("[FastAttack] Failed to find: " .. childName)
        end
        return result
    end

    local VirtualInputManager = game:GetService("VirtualInputManager")
    local RunService = game:GetService("RunService")
    
    local Remotes = SafeWaitForChild(ReplicatedStorage, "Remotes")
    
    if Remotes then
        local Modules = SafeWaitForChild(ReplicatedStorage, "Modules")
        local Net = Modules and SafeWaitForChild(Modules, "Net")
        
        if Net then
            local RegisterAttack = SafeWaitForChild(Net, "RE/RegisterAttack")
            local RegisterHit = SafeWaitForChild(Net, "RE/RegisterHit")
            
            if RegisterAttack and RegisterHit then
                local WorldOrigin = SafeWaitForChild(workspace, "_WorldOrigin")
                local Characters = SafeWaitForChild(workspace, "Characters")
                local Enemies = SafeWaitForChild(workspace, "Enemies")
                
                local Settings = {
                    AutoClick = true,
                    ClickDelay = 0.00001
                }
                
                local FastAttack = {
                    Distance = 100,
                    attackMobs = true,
                    attackPlayers = true
                }
                
                local function IsAlive(character)
                    return character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0
                end
                
                local function ProcessEnemies(OthersEnemies, Folder)
                    local BasePart = nil
                    if not Folder then return BasePart end
                    
                    for _, Enemy in pairs(Folder:GetChildren()) do
                        local Head = Enemy:FindFirstChild("Head")
                        if Head and IsAlive(Enemy) then
                            local distance = (Head.Position - Player.Character.HumanoidRootPart.Position).Magnitude
                            if distance < FastAttack.Distance then
                                if Enemy ~= Player.Character then
                                    table.insert(OthersEnemies, { Enemy, Head })
                                    BasePart = Head
                                end
                            end
                        end
                    end
                    return BasePart
                end
                
                function FastAttack:Attack(BasePart, OthersEnemies)
                    if not BasePart or #OthersEnemies == 0 then return end
                    if RegisterAttack then
                        RegisterAttack:FireServer(Settings.ClickDelay or 0)
                    end
                    if RegisterHit then
                        RegisterHit:FireServer(BasePart, OthersEnemies)
                    end
                end
                
                function FastAttack:AttackNearest()
                    local OthersEnemies = {}
                    local Part1 = ProcessEnemies(OthersEnemies, Enemies)
                    local Part2 = ProcessEnemies(OthersEnemies, Characters)
                    if #OthersEnemies > 0 then
                        self:Attack(Part1 or Part2, OthersEnemies)
                    end
                end
                
                function FastAttack:BladeHits()
                    if not IsAlive(Player.Character) then return end
                    local Equipped = Player.Character:FindFirstChildOfClass("Tool")
                    if Equipped and Equipped.ToolTip ~= "Gun" then
                        self:AttackNearest()
                    end
                end
                
                        task.spawn(function()
                            while task.wait(Settings.ClickDelay) do
                                pcall(function()
                                    if Settings.AutoClick and AUTO_FARM_ENABLED then
                                        FastAttack:BladeHits()
                                    end
                                end)
                            end
                        end)
                
                _ENV.rz_FastAttack = FastAttack
                _G.FastAttackMethod = 1
                print("✓ Fast Attack Method 1 enabled")
            else
                warn("⚠ Fast Attack Method 1 failed - RegisterAttack/RegisterHit not found")
                _G.FastAttackMethod = 2
            end
        else
            warn("⚠ Fast Attack Method 1 failed - Net module not found")
            _G.FastAttackMethod = 2
        end
    else
        warn("⚠ Fast Attack Method 1 failed - Remotes not found")
        _G.FastAttackMethod = 2
    end
end

-- Fast Attack Method 2 (Fallback - Camera-based)
if _G.FastAttackMethod == 2 then
    print("✓ Using Fast Attack Method 2 (Fallback)")
    
    local Camera = workspace.CurrentCamera
    
    -- CameraShaker bypass (removes attack shake)
    task.spawn(function()
        while task.wait() do
            pcall(function()
                if Camera then
                    Camera.CFrame = Camera.CFrame
                end
            end)
        end
    end)
    
    -- Click-based fast attack
    task.spawn(function()
        local CombatFramework = require(game.Players.LocalPlayer.PlayerScripts.CombatFramework)
        local CombatFrameworkR = getupvalues(CombatFramework)[2]
        
        while task.wait() do
            pcall(function()
                if AUTO_FARM_ENABLED and Player.Character then
                    local tool = Player.Character:FindFirstChildOfClass("Tool")
                    if tool and tool.ToolTip ~= "Gun" then
                        -- Fast click method
                        local ac = CombatFrameworkR.activeController
                        if ac and ac.equipped then
                            -- Increment hit count
                            if ac.hitboxMagnitude then
                                ac.hitboxMagnitude = 100
                            end
                            
                            -- Fast attack
                            for i = 1, 1 do
                                local bladehit = require(game.ReplicatedStorage.CombatFramework.RigLib).getBladeHits(
                                    Player.Character,
                                    {Player.Character.HumanoidRootPart},
                                    60
                                )
                                
                                if bladehit then
                                    local cframemon = {}
                                    for k, v in pairs(bladehit) do
                                        if v.Parent and v.Parent:FindFirstChild("Humanoid") and v.Parent:FindFirstChild("HumanoidRootPart") then
                                            if v.Parent.Humanoid.Health > 0 then
                                                table.insert(cframemon, v.Parent.HumanoidRootPart)
                                            end
                                        end
                                    end
                                    
                                    if #cframemon > 0 then
                                        local target = cframemon[1]
                                        ac:attack()
                                        
                                        game:GetService("ReplicatedStorage").RigControllerEvent:FireServer(
                                            "weaponChange",
                                            tostring(tool.Name)
                                        )
                                        
                                        game:GetService("ReplicatedStorage").Remotes.Validator:FireServer(
                                            math.floor(target.Position.X),
                                            target
                                        )
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end

-- STATE
local isHopping = false
local lastCheckTime = 0
local scriptStartTime = tick()
local INITIAL_WAIT_TIME = 5

-- Remove old UI
local oldUI = PlayerGui:FindFirstChild("EliteHunterV2Gui")
if oldUI then oldUI:Destroy() end

-- STEP 3: CREATE UI
print("[3/3] Creating UI...")

-- UTILITY FUNCTIONS
local function getCommF()
    if not ReplicatedStorage then return nil end
    local rem = ReplicatedStorage:FindFirstChild("Remotes")
    if not rem then return nil end
    return rem:FindFirstChild("CommF_")
end

local function GetEliteProgress()
    local progress = 0
    pcall(function()
        local comm = getCommF()
        if comm then
            local result = comm:InvokeServer("EliteHunter", "Progress")
            if result then
                if type(result) == "string" then
                    local num = string.match(result, "defeated (%d+) elite")
                    if num then progress = tonumber(num) or 0 end
                elseif type(result) == "number" then
                    progress = result
                end
            end
        end
    end)
    return progress
end

local function HasEliteQuest()
    local hasQuest = false
    pcall(function()
        local comm = getCommF()
        if comm then
            local result = comm:InvokeServer("EliteHunter")
            if result and type(result) == "string" then
                local msg = string.lower(result)
                if string.find(msg, "don't have anything") or string.find(msg, "come back later") then
                    hasQuest = false
                else
                    hasQuest = true
                end
            elseif result == true or result == 1 then
                hasQuest = true
            end
        end
    end)
    return hasQuest
end

-- Check if Elite is spawned
local function IsEliteSpawned()
    local eliteNames = {"Diablo", "Deandre", "Urban"}
    
    for _, name in pairs(eliteNames) do
        if ReplicatedStorage:FindFirstChild(name) then
            return true, name
        end
        if workspace.Enemies:FindFirstChild(name) then
            return true, name
        end
    end
    return false, nil
end

local function ServerHop()
    if isHopping then return end
    isHopping = true
    
    print("[Elite Hunter V2] Starting server hop...")
    
    local success = pcall(function()
        local servers = {}
        local req = syn and syn.request or http and http.request or http_request or request
        
        if req then
            local response = req({
                Url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", game.PlaceId),
                Method = "GET"
            })
            
            if response and response.Body then
                local data = HttpService:JSONDecode(response.Body)
                if data and data.data then
                    for _, server in pairs(data.data) do
                        if server.playing < server.maxPlayers and server.id ~= game.JobId then
                            table.insert(servers, server.id)
                        end
                    end
                end
            end
        end
        
        if #servers > 0 then
            local randomServer = servers[math.random(1, #servers)]
            TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, Player)
        else
            TeleportService:Teleport(game.PlaceId, Player)
        end
    end)
    
    if not success then
        pcall(function()
            TeleportService:Teleport(game.PlaceId, Player)
        end)
    end
    
    task.wait(5)
    isHopping = false
end

-- Tween/Teleport system
local TweenService = game:GetService("TweenService")
_G.LockTween = false

local function StopTween()
    _G.LockTween = false
    
    if Player.Character then
        if Player.Character:FindFirstChild("BodyClip") then
            Player.Character.BodyClip:Destroy()
        end
        if Player.Character:FindFirstChild("PartTele") then
            Player.Character.PartTele:Destroy()
        end
        if Player.Character:FindFirstChild("HumanoidRootPart") then
            Player.Character.HumanoidRootPart.Anchored = false
        end
    end
end

local function Tween(targetCFrame)
    if _G.LockTween then return end
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = Player.Character.HumanoidRootPart
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    
    -- If very close, just teleport
    if distance < 10 then
        hrp.CFrame = targetCFrame
        return
    end
    
    _G.LockTween = true
    
    -- Create BodyVelocity for smooth movement
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "BodyClip"
    bodyVelocity.Parent = hrp
    bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    
    -- Create invisible part for tweening
    local part = Instance.new("Part")
    part.Name = "PartTele"
    part.Size = Vector3.new(1, 1, 1)
    part.Transparency = 1
    part.CanCollide = false
    part.Anchored = true
    part.CFrame = hrp.CFrame
    part.Parent = Player.Character
    
    -- Calculate tween duration
    local speed = 350
    local duration = distance / speed
    
    -- Create tween for the part
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(part, tweenInfo, {CFrame = targetCFrame})
    
    -- Update HumanoidRootPart to follow the part
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if not _G.LockTween or not part.Parent or not hrp.Parent then
            connection:Disconnect()
            StopTween()
            return
        end
        
        hrp.CFrame = part.CFrame
    end)
    
    tween:Play()
    
    tween.Completed:Connect(function()
        connection:Disconnect()
        StopTween()
    end)
end

-- Lock tween function (for stopping smoothly)
function LockTween()
    if _G.LockTween then
        return
    end
    _G.LockTween = true
    task.wait()
    
    local char = Player.Character
    if char and char:IsDescendantOf(workspace) then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = hrp.CFrame
        end
    end
    
    task.wait()
    
    if char then
        if char:FindFirstChild("BodyClip") then
            char.BodyClip:Destroy()
        end
        if char:FindFirstChild("PartTele") then
            char.PartTele:Destroy()
        end
    end
    
    _G.LockTween = false
end

-- Equip weapon
local function EquipWeapon(weaponName)
    pcall(function()
        -- If weaponName is "Melee", find any melee weapon
        if weaponName == "Melee" then
            for _, v in pairs(Player.Backpack:GetChildren()) do
                if v.ToolTip == "Melee" then
                    Player.Character.Humanoid:EquipTool(v)
                    return
                end
            end
            -- Check if already equipped
            for _, v in pairs(Player.Character:GetChildren()) do
                if v:IsA("Tool") and v.ToolTip == "Melee" then
                    return -- Already equipped
                end
            end
        else
            -- Equip specific weapon
            local tool = Player.Backpack:FindFirstChild(weaponName)
            if tool then
                Player.Character.Humanoid:EquipTool(tool)
                return
            end
            
            -- Check if already equipped
            if Player.Character:FindFirstChild(weaponName) then
                return
            end
        end
    end)
end

-- Auto Haki
local function AutoHaki()
    pcall(function()
        if not Player.Character:FindFirstChild("HasBuso") then
            local comm = getCommF()
            if comm then
                comm:InvokeServer("Buso")
            end
        end
    end)
end

-- CREATE UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EliteHunterV2Gui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 520, 0, 170)
MainFrame.AnchorPoint = Vector2.new(0.5, 0)
MainFrame.Position = UDim2.new(0.5, 0, 0, 15)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(255, 0, 0)
UIStroke.Thickness = 3
UIStroke.Parent = MainFrame

spawn(function()
    local hue = 0
    while wait(0.03) do
        if not MainFrame.Parent then break end
        hue = (hue + 0.005) % 1
        UIStroke.Color = Color3.fromHSV(hue, 1, 1)
    end
end)

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -20, 1, -20)
ContentFrame.Position = UDim2.new(0, 10, 0, 10)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 0, 25)
TitleLabel.Position = UDim2.new(0, 10, 0, 5)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 18
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Text = "Elite Hunter V2 - " .. Player.Name
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = ContentFrame

local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Size = UDim2.new(0.48, -10, 0, 22)
ProgressLabel.Position = UDim2.new(0, 10, 0, 35)
ProgressLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
ProgressLabel.BorderSizePixel = 0
ProgressLabel.Font = Enum.Font.GothamBold
ProgressLabel.TextSize = 15
ProgressLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
ProgressLabel.Text = "Elite Kills: ..."
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Center
ProgressLabel.Parent = ContentFrame

local ProgressCorner = Instance.new("UICorner")
ProgressCorner.CornerRadius = UDim.new(0, 6)
ProgressCorner.Parent = ProgressLabel

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0.48, -10, 0, 22)
StatusLabel.Position = UDim2.new(0.52, 0, 0, 35)
StatusLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
StatusLabel.BorderSizePixel = 0
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 15
StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
StatusLabel.Text = "Status: Checking..."
StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
StatusLabel.Parent = ContentFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusLabel

local ToggleFarmButton = Instance.new("TextButton")
ToggleFarmButton.Size = UDim2.new(0.48, -10, 0, 22)
ToggleFarmButton.Position = UDim2.new(0, 10, 0, 62)
ToggleFarmButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
ToggleFarmButton.BorderSizePixel = 0
ToggleFarmButton.Font = Enum.Font.GothamBold
ToggleFarmButton.TextSize = 14
ToggleFarmButton.TextColor3 = Color3.fromRGB(255, 100, 100)
ToggleFarmButton.Text = "Auto Farm: OFF"
ToggleFarmButton.Parent = ContentFrame

local FarmCorner = Instance.new("UICorner")
FarmCorner.CornerRadius = UDim.new(0, 6)
FarmCorner.Parent = ToggleFarmButton

local ToggleHopButton = Instance.new("TextButton")
ToggleHopButton.Size = UDim2.new(0.48, -10, 0, 22)
ToggleHopButton.Position = UDim2.new(0.52, 0, 0, 62)
ToggleHopButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
ToggleHopButton.BorderSizePixel = 0
ToggleHopButton.Font = Enum.Font.GothamBold
ToggleHopButton.TextSize = 14
ToggleHopButton.TextColor3 = Color3.fromRGB(255, 100, 100)
ToggleHopButton.Text = "Auto Hop: OFF"
ToggleHopButton.Parent = ContentFrame

local HopCorner = Instance.new("UICorner")
HopCorner.CornerRadius = UDim.new(0, 6)
HopCorner.Parent = ToggleHopButton

-- No Attack Animation Toggle Button
local ToggleAnimButton = Instance.new("TextButton")
ToggleAnimButton.Size = UDim2.new(1, -20, 0, 22)
ToggleAnimButton.Position = UDim2.new(0, 10, 0, 89)
ToggleAnimButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
ToggleAnimButton.BorderSizePixel = 0
ToggleAnimButton.Font = Enum.Font.GothamBold
ToggleAnimButton.TextSize = 14
ToggleAnimButton.TextColor3 = Color3.fromRGB(255, 100, 100)
ToggleAnimButton.Text = "No Animation: OFF"
ToggleAnimButton.Parent = ContentFrame

local AnimCorner = Instance.new("UICorner")
AnimCorner.CornerRadius = UDim.new(0, 6)
AnimCorner.Parent = ToggleAnimButton

-- Auto Yama Toggle Button
local ToggleYamaButton = Instance.new("TextButton")
ToggleYamaButton.Size = UDim2.new(1, -20, 0, 22)
ToggleYamaButton.Position = UDim2.new(0, 10, 0, 116)
ToggleYamaButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
ToggleYamaButton.BorderSizePixel = 0
ToggleYamaButton.Font = Enum.Font.GothamBold
ToggleYamaButton.TextSize = 14
ToggleYamaButton.TextColor3 = Color3.fromRGB(255, 100, 100)
ToggleYamaButton.Text = "Auto Yama: OFF"
ToggleYamaButton.Parent = ContentFrame

local YamaCorner = Instance.new("UICorner")
YamaCorner.CornerRadius = UDim.new(0, 6)
YamaCorner.Parent = ToggleYamaButton

local function updateButtonUI()
    if AUTO_FARM_ENABLED then
        ToggleFarmButton.Text = "Auto Farm: ON"
        ToggleFarmButton.TextColor3 = Color3.fromRGB(100, 255, 100)
        ToggleFarmButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    else
        ToggleFarmButton.Text = "Auto Farm: OFF"
        ToggleFarmButton.TextColor3 = Color3.fromRGB(255, 100, 100)
        ToggleFarmButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    end
    
    if AUTO_HOP_ENABLED then
        ToggleHopButton.Text = "Auto Hop: ON"
        ToggleHopButton.TextColor3 = Color3.fromRGB(100, 255, 100)
        ToggleHopButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    else
        ToggleHopButton.Text = "Auto Hop: OFF"
        ToggleHopButton.TextColor3 = Color3.fromRGB(255, 100, 100)
        ToggleHopButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    end
    
    if NO_ATTACK_ANIMATION then
        ToggleAnimButton.Text = "No Animation: ON"
        ToggleAnimButton.TextColor3 = Color3.fromRGB(100, 255, 100)
        ToggleAnimButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    else
        ToggleAnimButton.Text = "No Animation: OFF"
        ToggleAnimButton.TextColor3 = Color3.fromRGB(255, 100, 100)
        ToggleAnimButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    end
    
    if AUTO_YAMA_ENABLED then
        ToggleYamaButton.Text = "Auto Yama: ON"
        ToggleYamaButton.TextColor3 = Color3.fromRGB(100, 255, 100)
        ToggleYamaButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    else
        ToggleYamaButton.Text = "Auto Yama: OFF"
        ToggleYamaButton.TextColor3 = Color3.fromRGB(255, 100, 100)
        ToggleYamaButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    end
end

updateButtonUI()

ToggleFarmButton.MouseButton1Click:Connect(function()
    AUTO_FARM_ENABLED = not AUTO_FARM_ENABLED
    
    -- Stop tween and fast attack when disabling
    if not AUTO_FARM_ENABLED then
        print("[Elite Hunter V2] Stopping Auto Farm...")
        LockTween()
        task.wait(0.5) -- Wait for tween to fully stop
    end
    
    updateButtonUI()
    saveConfig({
        autoHop = AUTO_HOP_ENABLED, 
        autoFarm = AUTO_FARM_ENABLED,
        autoYama = AUTO_YAMA_ENABLED,
        noAttackAnimation = NO_ATTACK_ANIMATION
    })
    print("[Elite Hunter V2] Auto Farm " .. (AUTO_FARM_ENABLED and "ON" or "OFF"))
end)

ToggleHopButton.MouseButton1Click:Connect(function()
    AUTO_HOP_ENABLED = not AUTO_HOP_ENABLED
    updateButtonUI()
    saveConfig({
        autoHop = AUTO_HOP_ENABLED, 
        autoFarm = AUTO_FARM_ENABLED,
        autoYama = AUTO_YAMA_ENABLED,
        noAttackAnimation = NO_ATTACK_ANIMATION
    })
    print("[Elite Hunter V2] Auto Hop " .. (AUTO_HOP_ENABLED and "ON" or "OFF"))
end)

ToggleAnimButton.MouseButton1Click:Connect(function()
    NO_ATTACK_ANIMATION = not NO_ATTACK_ANIMATION
    updateButtonUI()
    saveConfig({
        autoHop = AUTO_HOP_ENABLED, 
        autoFarm = AUTO_FARM_ENABLED,
        autoYama = AUTO_YAMA_ENABLED,
        noAttackAnimation = NO_ATTACK_ANIMATION
    })
    print("[Elite Hunter V2] No Animation " .. (NO_ATTACK_ANIMATION and "ON" or "OFF"))
end)

ToggleYamaButton.MouseButton1Click:Connect(function()
    AUTO_YAMA_ENABLED = not AUTO_YAMA_ENABLED
    updateButtonUI()
    saveConfig({
        autoHop = AUTO_HOP_ENABLED, 
        autoFarm = AUTO_FARM_ENABLED,
        autoYama = AUTO_YAMA_ENABLED,
        noAttackAnimation = NO_ATTACK_ANIMATION
    })
    print("[Elite Hunter V2] Auto Yama " .. (AUTO_YAMA_ENABLED and "ON" or "OFF"))
end)

local function updateEliteInfo()
    pcall(function()
        local progress = GetEliteProgress()
        ProgressLabel.Text = "Elite Kills: " .. tostring(progress)
        
        local hasQuest = HasEliteQuest()
        
        local timeSinceStart = tick() - scriptStartTime
        local isGameLoading = timeSinceStart < INITIAL_WAIT_TIME
        
        if hasQuest then
            StatusLabel.Text = "Status: Quest Active"
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            if isGameLoading then
                local waitTimeLeft = math.ceil(INITIAL_WAIT_TIME - timeSinceStart)
                StatusLabel.Text = "Loading... (" .. waitTimeLeft .. "s)"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                return
            end
            
            StatusLabel.Text = "Status: No Quest"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            
            if AUTO_HOP_ENABLED and not isHopping then
                local currentTime = tick()
                if currentTime - lastCheckTime >= CHECK_INTERVAL then
                    lastCheckTime = currentTime
                    StatusLabel.Text = "Hopping in " .. HOP_DELAY .. "s"
                    task.wait(HOP_DELAY)
                    ServerHop()
                end
            end
        end
    end)
end

-- Check if has Yama
local function HasYama()
    local hasYama = false
    
    pcall(function()
        -- Check Backpack
        if Player.Backpack:FindFirstChild("Yama") then
            hasYama = true
            return
        end
        
        -- Check Character
        if Player.Character and Player.Character:FindFirstChild("Yama") then
            hasYama = true
            return
        end
        
        -- Check via RemoteFunction (most reliable)
        local comm = getCommF()
        if comm then
            local inv = comm:InvokeServer("getInventory")
            if inv then
                for _, item in pairs(inv) do
                    local itemName = ""
                    if type(item) == "table" then
                        itemName = item.Name or ""
                    elseif item and item.Name then
                        itemName = item.Name
                    else
                        itemName = tostring(item)
                    end
                    
                    if string.find(string.lower(itemName), "yama") then
                        hasYama = true
                        return
                    end
                end
            end
        end
    end)
    
    return hasYama
end

-- AUTO YAMA LOOP
spawn(function()
    local yamaFarmActive = false
    
    while wait(0.5) do
        if AUTO_YAMA_ENABLED then
            pcall(function()
                -- Check if already have Yama
                if HasYama() then
                    if yamaFarmActive then
                        print("[Auto Yama] ✓ Yama obtained successfully!")
                        yamaFarmActive = false
                    end
                    return
                end
                
                -- Check Elite Hunter progress
                local comm = getCommF()
                if comm then
                    local result = comm:InvokeServer("EliteHunter", "Progress")
                    local progress = 0
                    
                    if type(result) == "string" then
                        local num = string.match(result, "defeated (%d+) elite")
                        if num then
                            progress = tonumber(num) or 0
                        end
                    elseif type(result) == "number" then
                        progress = result
                    end
                    
                    if progress >= 30 then
                        if not yamaFarmActive then
                            print("[Auto Yama] Progress: " .. progress .. "/30 ✓")
                            print("[Auto Yama] Starting Yama farm sequence...")
                            yamaFarmActive = true
                        end
                        
                        -- Find Yama (Correct path: Hitbox not Handle!)
                        local yama = workspace:FindFirstChild("Map") 
                            and workspace.Map:FindFirstChild("Waterfall")
                            and workspace.Map.Waterfall:FindFirstChild("SealedKatana")
                            and workspace.Map.Waterfall.SealedKatana:FindFirstChild("Hitbox")
                        
                        if yama then
                            local yamaPos = yama.CFrame
                            
                            -- Check distance to Yama
                            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                local distance = (yamaPos.Position - Player.Character.HumanoidRootPart.Position).Magnitude
                                
                                if distance > 300 then
                                    print("[Auto Yama] Teleporting to Yama location...")
                                    Tween(yamaPos * CFrame.new(0, 5, 0))
                                    task.wait(2)
                                end
                            end
                            
                            -- Check for Ghost enemies
                            local ghostFound = false
                            for _, v in pairs(workspace.Enemies:GetChildren()) do
                                if v.Name == "Ghost [Lv. 1500]" and v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
                                    ghostFound = true
                                    
                                    print("[Auto Yama] Farming Ghost [Lv. 1500]...")
                                    
                                    repeat task.wait()
                                        -- Enable Haki
                                        AutoHaki()
                                        
                                        -- Equip weapon
                                        EquipWeapon(_G.SelectWeapon)
                                        
                                        -- Remove animator for smoother fight
                                        if v.Humanoid:FindFirstChild("Animator") then
                                            v.Humanoid.Animator:Destroy()
                                        end
                                        
                                        -- Disable collision
                                        v.HumanoidRootPart.CanCollide = false
                                        v.Humanoid.WalkSpeed = 0
                                        v.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                                        
                                        -- Tween to ghost
                                        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                            local targetPos = v.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0)
                                            local dist = (targetPos.Position - Player.Character.HumanoidRootPart.Position).Magnitude
                                            
                                            if dist > 10 then
                                                Tween(targetPos)
                                            else
                                                if not _G.LockTween then
                                                    Player.Character.HumanoidRootPart.CFrame = targetPos
                                                end
                                            end
                                        end
                                        
                                        sethiddenproperty(Player, "SimulationRadius", math.huge)
                                        
                                    until not AUTO_YAMA_ENABLED or v.Humanoid.Health <= 0 or not v.Parent or HasYama()
                                    
                                    LockTween()
                                    break
                                end
                            end
                            
                            -- If no ghosts, click Yama
                            if not ghostFound then
                                print("[Auto Yama] No more Ghosts - Clicking Yama...")
                                LockTween()
                                
                                -- Teleport close to Yama
                                if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                    Player.Character.HumanoidRootPart.CFrame = yamaPos * CFrame.new(0, 3, 0)
                                    task.wait(0.5)
                                end
                                
                                -- Click Yama (Hitbox has ClickDetector)
                                local clickDetector = yama:FindFirstChild("ClickDetector")
                                if clickDetector then
                                    fireclickdetector(clickDetector)
                                    print("[Auto Yama] Clicked Yama!")
                                    task.wait(1)
                                    
                                    -- Verify if obtained
                                    if HasYama() then
                                        print("[Auto Yama] ✓ Yama obtained!")
                                        yamaFarmActive = false
                                    else
                                        print("[Auto Yama] Waiting for Yama to appear...")
                                    end
                                else
                                    warn("[Auto Yama] ClickDetector not found on Hitbox")
                                end
                            end
                        else
                            warn("[Auto Yama] SealedKatana.Hitbox not found in workspace")
                            print("[Auto Yama] You may need >= 30 Elite kills for Yama to spawn")
                        end
                    else
                        if yamaFarmActive then
                            yamaFarmActive = false
                        end
                    end
                end
            end)
        else
            if yamaFarmActive then
                yamaFarmActive = false
                LockTween()
            end
        end
    end
end)

-- AUTO FARM ELITE LOOP
spawn(function()
    while wait() do
        if AUTO_FARM_ENABLED then
            pcall(function()
                local questGui = PlayerGui:FindFirstChild("Main") and PlayerGui.Main:FindFirstChild("Quest")
                
                -- Check if has Elite quest
                if questGui and questGui.Visible then
                    local questTitle = questGui:FindFirstChild("Container") and questGui.Container:FindFirstChild("QuestTitle")
                    if questTitle and questTitle:FindFirstChild("Title") then
                        local title = questTitle.Title.Text
                        
                        -- If quest is Elite (Diablo/Deandre/Urban)
                        if string.find(title, "Diablo") or string.find(title, "Deandre") or string.find(title, "Urban") then
                            
                            -- Check if Elite boss is in workspace
                            local foundBoss = false
                            for _, v in pairs(workspace.Enemies:GetChildren()) do
                                if (v.Name == "Diablo" or v.Name == "Deandre" or v.Name == "Urban") then
                                    if v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
                                        foundBoss = true
                                        
                                        repeat task.wait()
                                            -- Enable Haki
                                            AutoHaki()
                                            
                                            -- Equip weapon
                                            EquipWeapon(_G.SelectWeapon)
                                            
                                            -- Disable collision
                                            v.HumanoidRootPart.CanCollide = false
                                            v.Humanoid.WalkSpeed = 0
                                            v.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                                            
                                            -- Check distance and tween/teleport accordingly
                                            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                                local targetPos = v.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0)
                                                local distance = (targetPos.Position - Player.Character.HumanoidRootPart.Position).Magnitude
                                                
                                                if distance > 10 then
                                                    -- Far away, use tween
                                                    Tween(targetPos)
                                                else
                                                    -- Close enough, lock position
                                                    if not _G.LockTween then
                                                        Player.Character.HumanoidRootPart.CFrame = targetPos
                                                    end
                                                end
                                            end
                                            
                                            -- Set simulation radius
                                            sethiddenproperty(Player, "SimulationRadius", math.huge)
                                            
                                        until not AUTO_FARM_ENABLED or v.Humanoid.Health <= 0 or not v.Parent
                                        
                                        LockTween() -- Stop tween when done
                                        break
                                    end
                                end
                            end
                            
                            -- If boss not in workspace, check ReplicatedStorage and tween there
                            if not foundBoss then
                                LockTween() -- Stop current tween
                                
                                if ReplicatedStorage:FindFirstChild("Diablo") then
                                    local boss = ReplicatedStorage:FindFirstChild("Diablo")
                                    if boss:FindFirstChild("HumanoidRootPart") then
                                        Tween(boss.HumanoidRootPart.CFrame * CFrame.new(2, 20, 2))
                                    end
                                elseif ReplicatedStorage:FindFirstChild("Deandre") then
                                    local boss = ReplicatedStorage:FindFirstChild("Deandre")
                                    if boss:FindFirstChild("HumanoidRootPart") then
                                        Tween(boss.HumanoidRootPart.CFrame * CFrame.new(2, 20, 2))
                                    end
                                elseif ReplicatedStorage:FindFirstChild("Urban") then
                                    local boss = ReplicatedStorage:FindFirstChild("Urban")
                                    if boss:FindFirstChild("HumanoidRootPart") then
                                        Tween(boss.HumanoidRootPart.CFrame * CFrame.new(2, 20, 2))
                                    end
                                end
                            end
                        end
                    end
                else
                    -- No quest visible, get quest from NPC
                    LockTween()
                    local comm = getCommF()
                    if comm then
                        comm:InvokeServer("EliteHunter")
                        task.wait(1)
                    end
                end
            end)
        else
            LockTween()
            task.wait(1)
        end
    end
end)

print("✓ UI Created")
task.wait(2)
updateEliteInfo()

spawn(function()
    while wait(CHECK_INTERVAL) do
        if ScreenGui.Parent then
            updateEliteInfo()
        else
            break
        end
    end
end)

print("========================================")
print("✓ Elite Hunter V2 Loaded!")
print("✓ User: " .. Player.Name)
print("✓ Config: " .. CONFIG_FILE)
print("✓ Team: " .. tostring(Player.Team))
print("✓ Weapon: " .. _G.SelectWeapon)
print("✓ Fast Attack: Method " .. _G.FastAttackMethod)
print("✓ Auto Farm: " .. (AUTO_FARM_ENABLED and "ON" or "OFF"))
print("✓ Auto Hop: " .. (AUTO_HOP_ENABLED and "ON" or "OFF"))
print("✓ Auto Yama: " .. (AUTO_YAMA_ENABLED and "ON" or "OFF"))
print("✓ No Animation: " .. (NO_ATTACK_ANIMATION and "ON" or "OFF"))
print("========================================")