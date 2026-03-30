-- TEST SCRIPT: AUTO FARM MATERIAL SANGUINE ART
-- Materials needed: 1 Leviathan Heart, 2 Dark Fragment, 20 Vampire Fang, 20 Demonic Wisp
-- This script only farms: Vampire Fang (World 2) and Demonic Wisp (World 3)
-- 
-- Features:
-- ✅ Auto check if Sanguine Art already owned (stops script if yes)
-- ✅ No quest taking - tween and farm directly
-- ✅ No bring mob - natural farming
-- ✅ Auto world travel (World 2 ↔ World 3)
-- ✅ Fast attack + Auto Haki + Noclip
-- ✅ Auto buy Sanguine Art when materials ready
-- ✅ Equipped melee weapon
-- ✅ Updated fast attack system
--
-- Updated: New fast attack system & fixed hitbox

if not game:IsLoaded() then repeat task.wait() until game:IsLoaded() end

local Player = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

-- === CONFIGURATION ===
_G.Settings = {
    Team = "Pirates",
    SelectWeapon = "Combat", -- Melee weapon
    FarmHeight = 35,
    TweenSpeed = 350,
    AutoHaki = true,
    FastAttack = true,
    AutoFarm = false,
    FarmMethod = "Material", -- For fast attack system
    ActiveRaceV3 = true, -- Auto activate Race V3
    ActiveRaceV4 = true  -- Auto activate Race V4
}

-- Materials Requirements
local MaterialsNeeded = {
    ["Vampire Fang"] = 20,
    ["Demonic Wisp"] = 20
}

-- === WORLD DETECTION ===
local World1 = game.PlaceId == 2753915549 or game.PlaceId == 85211729168715
local World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
local World3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

-- === NPC CFRAME FOR SANGUINE ART ===
local SanguineNPC = CFrame.new(-16515.06640625, 22.811996459960938, -188.572998046875) -- World 3

-- === MONSTER CONFIG ===
local MonsterConfig = {
    ["Vampire Fang"] = {
        World = 2,
        Monster = "Vampire",
        MonsterCFrame = CFrame.new(-6037.66796875, 32.18463897705078, -1340.6597900390625)
    },
    ["Demonic Wisp"] = {
        World = 3,
        Monster = "Demonic Soul",
        MonsterCFrame = CFrame.new(-9505.8720703125, 172.10482788085938, 6158.9931640625)
    }
}

-- === GLOBAL VARIABLES ===
_G.LockTween = false
_G.CurrentTween = nil
_G.FarmingMaterial = false
_G.CurrentTargetMonster = ""

-- === PROGRESS FILE ===
local ProgressFileName = Player.Name .. "-Main.json"
local ProgressFilePath = ProgressFileName

-- Progress states
local ProgressStates = {
    FARM_VAMPIRE_FANG = "Farm Vampire Fang",
    FARM_DEMONIC_WISP = "Farm Demonic Wisp",
    GET_MELEE = "Get melee (Đã đủ material)",
    DONE = "Done Buy melee"
}

-- === PROGRESS FILE FUNCTIONS ===
function SaveProgress(progressState)
    local currentVampireFang = GetCountMaterials("Vampire Fang")
    local currentDemonicWisp = GetCountMaterials("Demonic Wisp")
    
    -- Load existing progress to compare
    local existingData = nil
    pcall(function()
        if isfile(ProgressFilePath) then
            local jsonData = readfile(ProgressFilePath)
            existingData = HttpService:JSONDecode(jsonData)
        end
    end)
    
    -- Only update material count if it INCREASES
    local savedVampireFang = currentVampireFang
    local savedDemonicWisp = currentDemonicWisp
    
    if existingData and existingData.Materials then
        -- Keep old count if current is lower (material decreased)
        if currentVampireFang < existingData.Materials.VampireFang then
            savedVampireFang = existingData.Materials.VampireFang
            print("🔒 Vampire Fang locked at: " .. savedVampireFang .. " (current: " .. currentVampireFang .. ")")
        end
        
        if currentDemonicWisp < existingData.Materials.DemonicWisp then
            savedDemonicWisp = existingData.Materials.DemonicWisp
            print("🔒 Demonic Wisp locked at: " .. savedDemonicWisp .. " (current: " .. currentDemonicWisp .. ")")
        end
    end
    
    local data = {
        Username = Player.Name,
        Progress = progressState,
        Timestamp = os.time(),
        Materials = {
            VampireFang = savedVampireFang,
            DemonicWisp = savedDemonicWisp
        }
    }
    
    local success, result = pcall(function()
        local jsonData = HttpService:JSONEncode(data)
        writefile(ProgressFilePath, jsonData)
    end)
    
    if success then
        print("💾 Progress saved: " .. progressState)
    else
        warn("❌ Failed to save progress: " .. tostring(result))
    end
end

function LoadProgress()
    local success, result = pcall(function()
        if isfile(ProgressFilePath) then
            local jsonData = readfile(ProgressFilePath)
            return HttpService:JSONDecode(jsonData)
        end
        return nil
    end)
    
    if success and result then
        print("📂 Progress loaded: " .. result.Progress)
        if result.Materials then
            print("  • Vampire Fang (saved): " .. result.Materials.VampireFang)
            print("  • Demonic Wisp (saved): " .. result.Materials.DemonicWisp)
        end
        return result
    else
        print("📂 No previous progress found, starting fresh")
        return nil
    end
end

function GetSavedMaterialCount(materialName)
    local success, result = pcall(function()
        if isfile(ProgressFilePath) then
            local jsonData = readfile(ProgressFilePath)
            local data = HttpService:JSONDecode(jsonData)
            if data.Materials then
                if materialName == "Vampire Fang" then
                    return data.Materials.VampireFang or 0
                elseif materialName == "Demonic Wisp" then
                    return data.Materials.DemonicWisp or 0
                end
            end
        end
        return 0
    end)
    
    if success then
        return result
    else
        return 0
    end
end

-- === CHOOSE TEAM FUNCTION ===
local function chooseTeam()
    print("🏴‍☠️ Choosing team...")
    
    local playerGui = Player:WaitForChild("PlayerGui", 10)
    if not playerGui then
        warn("❌ PlayerGui not found!")
        return false
    end
    
    if Player.Team or Player:FindFirstChild("Main") then
        print("✅ Team already chosen: " .. tostring(Player.Team))
        return true
    end
    
    print("⏳ Waiting for ChooseTeam GUI...")
    
    local chooseTeamGui = playerGui:FindFirstChild("Main (minimal)")
    if not chooseTeamGui then
        warn("❌ ChooseTeam GUI not found!")
        return false
    end
    
    local chooseTeam = chooseTeamGui:WaitForChild("ChooseTeam", 10)
    if not chooseTeam then
        warn("❌ ChooseTeam not found!")
        return false
    end
    
    local function clickTeamButton(teamName)
        local team = teamName:lower():find("pirate") and "Pirates" or "Marines"
        
        local container = chooseTeam:FindFirstChild("Container")
        if not container then return false end
        
        local teamButton = container:FindFirstChild(team)
        if not teamButton then return false end
        
        local frame = teamButton:FindFirstChild("Frame")
        if not frame then return false end
        
        local textButton = frame:FindFirstChild("TextButton")
        if not textButton then return false end
        
        local connections = getconnections(textButton.Activated)
        if #connections > 0 then
            print("🔘 Clicking " .. team .. " button...")
            for _, connection in ipairs(connections) do
                connection:Fire()
            end
            return true
        end
        return false
    end
    
    local lastAttempt = 0
    local maxAttempts = 30
    local attempts = 0
    
    while not (Player.Team or Player:FindFirstChild("Main")) and attempts < maxAttempts do
        if tick() - lastAttempt >= 0.5 then
            pcall(function()
                clickTeamButton(_G.Settings.Team)
            end)
            
            lastAttempt = tick()
            attempts = attempts + 1
        end
        
        task.wait()
    end
    
    if Player.Team or Player:FindFirstChild("Main") then
        print("🎉 Team chosen successfully: " .. tostring(Player.Team))
        return true
    else
        warn("❌ Failed to choose team after " .. maxAttempts .. " attempts")
        return false
    end
end

-- === MATERIAL CHECK FUNCTION ===
function GetCountMaterials(MaterialName)
    local Inventory = ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")
    for i, v in pairs(Inventory) do
        if v.Name == MaterialName then
            return v.Count
        end
    end
    return 0
end

function CheckItemCount(itemName, itemCount)
    for i, v in next, ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory") do
        if v.Name == itemName and v.Count >= itemCount then
            return true
        end
    end
    return false
end

function CheckSanguineArt()
    -- Check in Backpack
    if Player.Backpack and Player.Backpack:FindFirstChild("Sanguine Art") then
        return true
    end
    -- Check in Character (equipped)
    if Player.Character and Player.Character:FindFirstChild("Sanguine Art") then
        return true
    end
    -- Check in Inventory
    local success, Inventory = pcall(function()
        return ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")
    end)
    if success and Inventory then
        for i, v in pairs(Inventory) do
            if v.Name == "Sanguine Art" then
                return true
            end
        end
    end
    return false
end

-- === WORLD TRAVEL FUNCTIONS ===
function TravelToWorld2()
    if World2 then 
        print("✅ Already in World 2")
        return 
    end
    print("🌍 Traveling to World 2...")
    ReplicatedStorage.Remotes.CommF_:InvokeServer("TravelDressrosa")
    task.wait(5) -- Wait for teleport
end

function TravelToWorld3()
    if World3 then 
        print("✅ Already in World 3")
        return 
    end
    print("🌍 Traveling to World 3...")
    ReplicatedStorage.Remotes.CommF_:InvokeServer("TravelZou")
    task.wait(5) -- Wait for teleport
end

-- === AUTO HAKI ===
function AutoHaki()
    if not Player.Character:FindFirstChild("HasBuso") then
        ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso")
    end
end

-- === EQUIP WEAPON ===
local lastEquipTime = 0
function EquipWeapon(ToolSe)
    pcall(function()
        -- Check if a melee weapon is already equipped
        local equippedTool = Player.Character:FindFirstChildOfClass("Tool")
        if equippedTool and equippedTool.ToolTip == "Melee" then
            return -- Melee already equipped, don't do anything
        end
        
        -- Find any melee weapon in backpack and equip it
        for _, tool in pairs(Player.Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.ToolTip == "Melee" then
                task.wait(0.3)
                Player.Character.Humanoid:EquipTool(tool)
                
                -- Only print every 5 seconds to avoid spam
                if tick() - lastEquipTime > 5 then
                    print("🗡️ Equipped melee: " .. tool.Name)
                    lastEquipTime = tick()
                end
                return
            end
        end
        
        -- Only print warning every 5 seconds
        if tick() - lastEquipTime > 5 then
            print("⚠️ No melee weapon found in backpack")
            lastEquipTime = tick()
        end
    end)
end

-- === TWEEN FUNCTION ===
function topos(targetCFrame)
    pcall(function()
        if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = Player.Character.HumanoidRootPart
        local distance = (targetCFrame.Position - hrp.Position).Magnitude
        
        -- If already close, just set position
        if distance < 15 then
            if _G.CurrentTween then
                _G.CurrentTween:Cancel()
                _G.CurrentTween = nil
            end
            _G.LockTween = false
            hrp.CFrame = targetCFrame
            return
        end
        
        -- If already tweening to same target, don't create new tween
        if _G.LockTween and _G.CurrentTween then
            return
        end
        
        -- Stop any existing tween first
        if _G.CurrentTween then
            _G.CurrentTween:Cancel()
            _G.CurrentTween = nil
        end
        
        _G.LockTween = true
        
        -- Clean up old BodyVelocity
        for _, v in pairs(hrp:GetChildren()) do
            if v:IsA("BodyVelocity") and v.Name == "BodyClip" then
                v:Destroy()
            end
        end
        
        -- Create BodyVelocity
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "BodyClip"
        bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = hrp
        
        -- Clean up old part
        if Player.Character:FindFirstChild("PartTele") then
            Player.Character.PartTele:Destroy()
        end
        
        -- Create invisible part
        local part = Instance.new("Part")
        part.Name = "PartTele"
        part.Transparency = 1
        part.CanCollide = false
        part.Anchored = true
        part.CFrame = hrp.CFrame
        part.Parent = Player.Character
        
        -- Create tween
        local tween = TweenService:Create(part, TweenInfo.new(distance / _G.Settings.TweenSpeed, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
        _G.CurrentTween = tween
        
        -- Sync HRP with part
        local connection
        connection = RunService.Heartbeat:Connect(function()
            if not _G.LockTween or not part.Parent or not hrp.Parent then
                if connection then connection:Disconnect() end
                return
            end
            hrp.CFrame = part.CFrame
        end)
        
        tween:Play()
        tween.Completed:Connect(function()
            if connection then connection:Disconnect() end
            _G.LockTween = false
            if bodyVelocity and bodyVelocity.Parent then bodyVelocity:Destroy() end
            if part and part.Parent then part:Destroy() end
            _G.CurrentTween = nil
        end)
    end)
end

-- === NOCLIP ===
task.spawn(function()
    while task.wait() do
        pcall(function()
            if _G.FarmingMaterial then
                for _, v in pairs(Player.Character:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
            end
        end)
    end
end)

-- === AUTO EQUIP WEAPON LOOP ===
-- Check and re-equip melee weapon if it gets unequipped
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if _G.FarmingMaterial and Player.Character then
                -- Check if any melee weapon is equipped
                local tool = Player.Character:FindFirstChildOfClass("Tool")
                local hasMeleeEquipped = tool and tool.ToolTip == "Melee"
                
                -- Only equip if no melee weapon is equipped
                if not hasMeleeEquipped then
                    EquipWeapon(_G.Settings.SelectWeapon)
                end
            end
        end)
    end
end)

-- === ANTI AFK ===
task.spawn(function()
    Player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- === AUTO RACE V3 ===
task.spawn(function()
    pcall(function()
        while wait(1) do
            if _G.Settings.ActiveRaceV3 and _G.FarmingMaterial then
                ReplicatedStorage.Remotes.CommE:FireServer("ActivateAbility")
            end
        end
    end)
end)

-- === AUTO RACE V4 ===
task.spawn(function()
    while wait(0.2) do
        pcall(function()
            if _G.Settings.ActiveRaceV4 and _G.FarmingMaterial then
                if Player.Character:FindFirstChild("RaceEnergy") and Player.Character:FindFirstChild("RaceTransformed") then
                    if tonumber(Player.Character.RaceEnergy.Value) == 1 then
                        if Player.Character.RaceTransformed.Value == false then
                            VirtualInputManager:SendKeyEvent(true, "Y", false, game)
                            wait(0.1)
                            VirtualInputManager:SendKeyEvent(false, "Y", false, game)
                        end
                    end
                end
            end
        end)
    end
end)

-- === NEW FAST ATTACK SYSTEM ===
local function StartFastAttack()
    local Net = require(ReplicatedStorage.Modules.Net)
    
    task.spawn(function()
        while true do
            task.wait(0.01)
            if _G.Settings.FastAttack and _G.Settings.AutoFarm and not _G.LockTween then
                pcall(function()
                    local tool = Player.Character:FindFirstChildOfClass("Tool")
                    if not tool or tool.ToolTip ~= "Melee" then return end
                    
                    local hitList = {}
                    
                    -- Farm specific monster (Material farming)
                    if _G.Settings.FarmMethod == "Material" and _G.CurrentTargetMonster ~= "" then
                        for _, v in pairs(workspace.Enemies:GetChildren()) do
                            if v.Name == _G.CurrentTargetMonster and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                                local eHrp = v:FindFirstChild("HumanoidRootPart")
                                if eHrp and (eHrp.Position - Player.Character.HumanoidRootPart.Position).Magnitude <= 125 then
                                    table.insert(hitList, {[1] = v, [2] = eHrp})
                                end
                            end
                        end
                    end
                    
                    if #hitList > 0 then
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton1(Vector2.new(850, 520))
                        Net:RemoteEvent("RegisterAttack"):FireServer(0)
                        Net:RemoteEvent("RegisterHit"):FireServer(hitList[1][2], hitList, "078da5141")
                    end
                end)
            end
        end
    end)
end

-- Start Fast Attack
StartFastAttack()

-- === FARM MATERIAL FUNCTION ===
function FarmMaterial(materialName)
    local config = MonsterConfig[materialName]
    if not config then 
        warn("❌ Config not found for: " .. materialName)
        return 
    end
    
    _G.CurrentFarmingMaterial = materialName
    _G.CurrentTargetMonster = config.Monster
    print("🎯 Farming: " .. materialName)
    print("📍 Monster: " .. config.Monster)
    
    -- Equip melee weapon once
    EquipWeapon(_G.Settings.SelectWeapon)
    task.wait(0.5)
    
    -- Travel to correct world
    if config.World == 2 and not World2 then
        TravelToWorld2()
    elseif config.World == 3 and not World3 then
        TravelToWorld3()
    end
    
    task.wait(1)
    
    while _G.FarmingMaterial do
        pcall(function()
            -- Check if already have Sanguine Art
            if CheckSanguineArt() then
                print("\n✅ SANGUINE ART FOUND IN BACKPACK!")
                print("🛑 Stopping farm...")
                _G.FarmingMaterial = false
                _G.Settings.AutoFarm = false
                _G.CurrentTargetMonster = ""
                SaveProgress(ProgressStates.DONE)
                return
                end
                            -- Use saved count (always increases, never decreases)
            local savedCount = GetSavedMaterialCount(materialName)
            local currentCount = GetCountMaterials(materialName)
            local displayCount = math.max(savedCount, currentCount)
            local needed = MaterialsNeeded[materialName]
            
            if displayCount >= needed then
                print("✅ " .. materialName .. " complete: " .. displayCount .. "/" .. needed)
                _G.FarmingMaterial = false
                _G.CurrentTargetMonster = ""
                
                -- Lock progress when material is complete
                if materialName == "Vampire Fang" then
                    SaveProgress(ProgressStates.FARM_DEMONIC_WISP)
                elseif materialName == "Demonic Wisp" then
                    SaveProgress(ProgressStates.GET_MELEE)
                end
                return
            end
            
            -- Save progress every loop to lock increasing count
            SaveProgress(
                materialName == "Vampire Fang" and ProgressStates.FARM_VAMPIRE_FANG or ProgressStates.FARM_DEMONIC_WISP
            )
            
            print("📊 " .. materialName .. ": " .. displayCount .. "/" .. needed .. " (current: " .. currentCount .. ")")
            
            -- Farm mobs directly (no quest)
            if workspace.Enemies:FindFirstChild(config.Monster) then
                for _, v in pairs(workspace.Enemies:GetChildren()) do
                    if v.Name == config.Monster and v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
                        -- First, tween to mob
                        local targetPos = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Settings.FarmHeight, 0)
                        local distance = (Player.Character.HumanoidRootPart.Position - targetPos.Position).Magnitude
                        
                        if distance > 15 then
                            topos(targetPos)
                            task.wait(distance / _G.Settings.TweenSpeed + 0.5)
                        end
                        
                        -- Create BodyVelocity to prevent falling
                        local hrp = Player.Character.HumanoidRootPart
                        local antiGravity = Instance.new("BodyVelocity")
                        antiGravity.Name = "AntiGravity"
                        antiGravity.MaxForce = Vector3.new(0, math.huge, 0)
                        antiGravity.Velocity = Vector3.new(0, 0, 0)
                        antiGravity.Parent = hrp
                        
                        -- Lock position above mob
                        repeat
                            task.wait()
                            -- Check Sanguine Art even during combat
                            if CheckSanguineArt() then
                                print("\n✅ SANGUINE ART FOUND!")
                                _G.FarmingMaterial = false
                                _G.Settings.AutoFarm = false
                                SaveProgress(ProgressStates.DONE)
                                if antiGravity and antiGravity.Parent then antiGravity:Destroy() end
                                return
                            end
                            if _G.Settings.AutoHaki then AutoHaki() end
                            
                            -- Lock player position above mob (no tween, direct CFrame set)
                            if v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
                                v.Humanoid.WalkSpeed = 0
                                v.HumanoidRootPart.CanCollide = false
                                hrp.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, _G.Settings.FarmHeight, 0)
                            end
                        until not _G.FarmingMaterial or v.Humanoid.Health <= 0 or not v.Parent
                        
                        -- Cleanup BodyVelocity
                        if antiGravity and antiGravity.Parent then
                            antiGravity:Destroy()
                        end
                    end
                end
            else
                -- Tween to monster spawn
                topos(config.MonsterCFrame)
            end
        end)
        task.wait()
    end
end

-- === BUY SANGUINE ART FUNCTION ===
function BuySanguineArt()
    print("🛒 Buying Sanguine Art...")
    
    -- Travel to World 3 if not there
    if not World3 then
        TravelToWorld3()
    end
    
    task.wait(1)
    
    -- Tween to NPC
    local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local distance = (SanguineNPC.Position - hrp.Position).Magnitude
    if distance > 15 then
        topos(SanguineNPC)
        task.wait(distance / _G.Settings.TweenSpeed + 1)
    else
        hrp.CFrame = SanguineNPC
    end
    
    task.wait(0.5)
    
    -- Buy Sanguine Art
    ReplicatedStorage.Remotes.CommF_:InvokeServer("BuySanguineArt", true)
    ReplicatedStorage.Remotes.CommF_:InvokeServer("BuySanguineArt")
    
    print("✅ Purchase command executed!")
end

-- === MAIN SCRIPT ===
print("=" .. string.rep("=", 60) .. "=")
print("🎯 AUTO FARM MATERIAL SANGUINE ART - UPDATED VERSION")
print("=" .. string.rep("=", 60) .. "=")

-- Step 0: Check if already have Sanguine Art in backpack
if CheckSanguineArt() then
    print("\n✅ SANGUINE ART ALREADY OWNED!")
    print("🛑 Script stopped.")
    SaveProgress(ProgressStates.DONE)
    print("=" .. string.rep("=", 60) .. "=")
    return
end

-- Step 1: Load previous progress
local savedProgress = LoadProgress()
local currentProgress = nil

if savedProgress then
    print("\n📋 Previous progress: " .. savedProgress.Progress)
    -- ALWAYS trust saved progress
    currentProgress = savedProgress.Progress
    print("✅ Using saved progress state")
else
    -- First time running - check materials
    print("📊 First run - checking materials...")
    local vampireFang = GetCountMaterials("Vampire Fang")
    local demonicWisp = GetCountMaterials("Demonic Wisp")
    
    print("  • Vampire Fang: " .. vampireFang .. "/" .. MaterialsNeeded["Vampire Fang"])
    print("  • Demonic Wisp: " .. demonicWisp .. "/" .. MaterialsNeeded["Demonic Wisp"])
    
    -- Determine starting progress
    if vampireFang >= MaterialsNeeded["Vampire Fang"] and demonicWisp >= MaterialsNeeded["Demonic Wisp"] then
        currentProgress = ProgressStates.GET_MELEE
    elseif vampireFang >= MaterialsNeeded["Vampire Fang"] then
        currentProgress = ProgressStates.FARM_DEMONIC_WISP
    else
        currentProgress = ProgressStates.FARM_VAMPIRE_FANG
    end
    
    SaveProgress(currentProgress)
end

-- Step 2: Choose Team
chooseTeam()
task.wait(2)

-- Step 3: Display current progress
print("\n📊 Current Progress: " .. currentProgress)
print("💡 Material count only increases, never decreases!")

-- Step 4: Execute based on progress state
if currentProgress == ProgressStates.FARM_VAMPIRE_FANG then
    print("\n🧛 Farming Vampire Fang...")
    _G.FarmingMaterial = true
    _G.Settings.AutoFarm = true
    SaveProgress(ProgressStates.FARM_VAMPIRE_FANG)
    FarmMaterial("Vampire Fang")
    _G.FarmingMaterial = false
    _G.Settings.AutoFarm = false
    
    -- Check if Sanguine Art appeared during farming
    if CheckSanguineArt() then
        print("\n✅ SANGUINE ART FOUND! Script complete.")
        SaveProgress(ProgressStates.DONE)
        print("\n✨ SCRIPT COMPLETE! ✨")
        print("💾 Progress saved to: " .. ProgressFileName)
        print("=" .. string.rep("=", 60) .. "=")
        return
    end
    
    task.wait(1)
    currentProgress = ProgressStates.FARM_DEMONIC_WISP
end

if currentProgress == ProgressStates.FARM_DEMONIC_WISP then
    print("\n👻 Farming Demonic Wisp...")
    _G.FarmingMaterial = true
    _G.Settings.AutoFarm = true
    SaveProgress(ProgressStates.FARM_DEMONIC_WISP)
    FarmMaterial("Demonic Wisp")
    _G.FarmingMaterial = false
    _G.Settings.AutoFarm = false
    
    -- Check if Sanguine Art appeared during farming
    if CheckSanguineArt() then
        print("\n✅ SANGUINE ART FOUND! Script complete.")
        SaveProgress(ProgressStates.DONE)
        print("\n✨ SCRIPT COMPLETE! ✨")
        print("💾 Progress saved to: " .. ProgressFileName)
        print("=" .. string.rep("=", 60) .. "=")
        return
    end
    
    task.wait(1)
    currentProgress = ProgressStates.GET_MELEE
end

-- Step 5: Buy Sanguine Art (loop until success)
if currentProgress == ProgressStates.GET_MELEE then
    print("\n💎 Materials complete! Proceeding to purchase...")
    SaveProgress(ProgressStates.GET_MELEE)
    
    local purchaseAttempts = 0
    local maxAttempts = 5
    
    while not CheckSanguineArt() and purchaseAttempts < maxAttempts do
        purchaseAttempts = purchaseAttempts + 1
        print("\n🛒 Purchase attempt " .. purchaseAttempts .. "/" .. maxAttempts)
        
        BuySanguineArt()
        task.wait(3)
        
        if CheckSanguineArt() then
            print("\n✅ SANGUINE ART SUCCESSFULLY OBTAINED!")
            SaveProgress(ProgressStates.DONE)
            break
        else
            print("⚠️ Not found in backpack yet, retrying...")
            task.wait(2)
        end
    end
    
    if not CheckSanguineArt() then
        print("\n❌ Failed to obtain Sanguine Art after " .. maxAttempts .. " attempts")
        print("💡 Please check manually or restart script")
    end
end

print("\n✨ SCRIPT COMPLETE! ✨")
print("💾 Progress saved to: " .. ProgressFileName)
print("=" .. string.rep("=", 60) .. "=")
