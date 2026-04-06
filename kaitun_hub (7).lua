--// =====================================================
--//   KAITUN HUB - AUTO FARM LEVEL + AUTO FULLY MELEE
--//   Script tự động 100% - chạy ngay khi load
--//   Tác giả: Kaitun Team
--// =====================================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Player   = Players.LocalPlayer
local MaxLevel = 2800

_G.BringMob = true

if not SetTask then
    function SetTask(key, msg) print("[" .. key .. "] " .. msg) end
end

local LocalStorage = {}
function LocalStorage:Get(key)      return self[key] end
function LocalStorage:Set(key, val) self[key] = val  end
function LocalStorage:Save()        end


-- =====================================================
--  TWEEN
-- =====================================================

local function StopTween()
    _G.LockTween = false
    if not Player.Character then return end
    if Player.Character:FindFirstChild("BodyClip")  then Player.Character.BodyClip:Destroy()  end
    if Player.Character:FindFirstChild("PartTele")  then Player.Character.PartTele:Destroy()  end
    local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.Anchored = false end
end

function topos(targetCFrame)
    if _G.LockTween then return end
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end

    local hrp      = Player.Character.HumanoidRootPart
    local distance = (targetCFrame.Position - hrp.Position).Magnitude

    if distance < 10 then hrp.CFrame = targetCFrame; return end

    _G.LockTween = true
    for _, part in pairs(Player.Character:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end

    local bv    = Instance.new("BodyVelocity")
    bv.Name     = "BodyClip"
    bv.Parent   = hrp
    bv.MaxForce = Vector3.new(100000, 100000, 100000)
    bv.Velocity = Vector3.new(0, 0, 0)

    local part        = Instance.new("Part")
    part.Name         = "PartTele"
    part.Size         = Vector3.new(1, 1, 1)
    part.Transparency = 1
    part.CanCollide   = false
    part.Anchored     = true
    part.CFrame       = hrp.CFrame
    part.Parent       = Player.Character

    local tween = TweenService:Create(part,
        TweenInfo.new(distance / 350, Enum.EasingStyle.Linear),
        { CFrame = targetCFrame }
    )

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not _G.LockTween or not part.Parent or not hrp.Parent then
            conn:Disconnect(); StopTween(); return
        end
        hrp.CFrame = part.CFrame
    end)

    tween:Play()
    tween.Completed:Connect(function() conn:Disconnect(); StopTween() end)
end

local function WaitTween(timeout)
    timeout = timeout or 15
    local t = tick()
    repeat task.wait(0.05) until not _G.LockTween or tick() - t > timeout
end


-- =====================================================
--  FAST ATTACK
-- =====================================================

local FastAttackEnabled = false
local AttackConnection
local _RegisterAttack, _RegisterHit

local function GetCombatRemotes()
    if _RegisterAttack and _RegisterHit then return _RegisterAttack, _RegisterHit end
    local ok, net = pcall(require, ReplicatedStorage.Modules.Net)
    if not ok or not net then return nil, nil end
    local ok2, ra = pcall(function() return net:RemoteEvent("RegisterAttack", true) end)
    local ok3, rh = pcall(function() return net:RemoteEvent("RegisterHit",   true) end)
    if ok2 and ok3 and ra and rh then _RegisterAttack = ra; _RegisterHit = rh end
    return _RegisterAttack, _RegisterHit
end

local function GetBladeHits()
    local hits = {}
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return hits end
    local pos = Player.Character.HumanoidRootPart.Position
    for _, e in pairs(Workspace.Enemies:GetChildren()) do
        if e:FindFirstChild("Humanoid") and e:FindFirstChild("HumanoidRootPart")
            and e.Humanoid.Health > 0
            and (e.HumanoidRootPart.Position - pos).Magnitude <= 65
        then
            table.insert(hits, e)
        end
    end
    return hits
end

function EnableFastAttack()
    if AttackConnection then return end
    local ra, rh = GetCombatRemotes()
    if not ra or not rh then warn("[FastAttack] Remotes chưa sẵn sàng"); return end

    FastAttackEnabled = true
    local tick_ = 0
    AttackConnection = RunService.Heartbeat:Connect(function()
        if not FastAttackEnabled then return end
        tick_ = tick_ + 1
        if tick_ % 2 ~= 0 then return end
        pcall(function()
            local hits = GetBladeHits()
            if #hits == 0 then return end
            local args = { [1] = nil, [2] = {}, [4] = "078da5141" }
            for _, e in pairs(hits) do
                ra:FireServer(0)
                if not args[1] then args[1] = e.Head end
                table.insert(args[2], { [1] = e, [2] = e.HumanoidRootPart })
                table.insert(args[2], e)
            end
            rh:FireServer(unpack(args))
        end)
    end)
end

function DisableFastAttack()
    FastAttackEnabled = false
    if AttackConnection then AttackConnection:Disconnect(); AttackConnection = nil end
end


-- =====================================================
--  EQUIP / HAKI
-- =====================================================

local function EquipWeapon(weaponName)
    pcall(function()
        if weaponName == "Melee" then
            for _, v in pairs(Player.Backpack:GetChildren()) do
                if v.ToolTip == "Melee" then Player.Character.Humanoid:EquipTool(v); return end
            end
        else
            local tool = Player.Backpack:FindFirstChild(weaponName)
            if tool then Player.Character.Humanoid:EquipTool(tool) end
        end
    end)
end

local function AutoHaki()
    pcall(function()
        if not Player.Character:FindFirstChild("HasBuso") then
            ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso")
        end
    end)
end


-- =====================================================
--  BRING MOB
-- =====================================================

local function BringEnemy(PosMon, targetNames)
    if not _G.BringMob then return end
    local nameSet = {}
    if targetNames then for _, n in pairs(targetNames) do nameSet[n] = true end end
    pcall(function()
        for _, e in pairs(Workspace.Enemies:GetChildren()) do
            if targetNames and not nameSet[e.Name] then continue end
            if e:FindFirstChild("Humanoid") and e.Humanoid.Health > 0
                and e:FindFirstChild("HumanoidRootPart")
            then
                local dist = (e.HumanoidRootPart.Position - PosMon).Magnitude
                if dist > 20 and dist <= 300 then
                    e.HumanoidRootPart.CFrame = CFrame.new(
                        PosMon + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
                    )
                    sethiddenproperty(Player, "SimulationRadius", math.huge)
                end
            end
        end
    end)
end


-- =====================================================
--  GET / KILL ENEMY
-- =====================================================

local function GetConnectionEnemies(enemyNames)
    for _, name in pairs(enemyNames) do
        for _, e in pairs(Workspace.Enemies:GetChildren()) do
            if e.Name == name and e:FindFirstChild("Humanoid") and e.Humanoid.Health > 0 then
                return e
            end
        end
    end
    return nil
end

local function GetSpawnCFrameFromRS(mobName)
    local ok, result = pcall(function()
        local folder = ReplicatedStorage:FindFirstChild("FortBuilderReplicatedSpawnPositionsFolder")
        if not folder then return nil end
        local mobFolder = folder:FindFirstChild(mobName)
        if not mobFolder then return nil end

        local playerPos = (Player.Character and Player.Character:FindFirstChild("HumanoidRootPart"))
            and Player.Character.HumanoidRootPart.Position or Vector3.new(0, 0, 0)

        local bestCF, bestDist = nil, math.huge
        local function tryPart(p)
            local cf
            if     p:IsA("BasePart")     then cf = p.CFrame
            elseif p:IsA("CFrameValue")  then cf = p.Value
            elseif p:IsA("Vector3Value") then cf = CFrame.new(p.Value)
            end
            if cf then
                local d = (cf.Position - playerPos).Magnitude
                if d < bestDist then bestDist = d; bestCF = cf end
            end
        end

        tryPart(mobFolder)
        for _, child in pairs(mobFolder:GetChildren()) do
            tryPart(child)
            for _, gc in pairs(child:GetChildren()) do tryPart(gc) end
        end
        return bestCF
    end)
    return ok and result or nil
end

local function WaitForMobSpawn(enemyNames, posM, timeout)
    timeout = timeout or 30
    local t0 = tick()
    local spawnCF
    for _, name in pairs(enemyNames) do
        spawnCF = GetSpawnCFrameFromRS(name)
        if spawnCF then break end
    end
    local waitPos = spawnCF or posM
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        if (waitPos.Position - Player.Character.HumanoidRootPart.Position).Magnitude > 30 then
            topos(waitPos); WaitTween(15)
        end
    end
    while tick() - t0 < timeout do
        local found = GetConnectionEnemies(enemyNames)
        if found then return found end
        SetTask("SubTask", string.format("[AutoFarm] Chờ mob spawn... (%.0fs)", timeout - (tick() - t0)))
        task.wait(0.5)
    end
    return nil
end

local function KillEnemy(enemy)
    if not enemy or not enemy.Parent then return end
    if not enemy:FindFirstChild("Humanoid") or enemy.Humanoid.Health <= 0 then return end
    if not enemy:FindFirstChild("HumanoidRootPart") then return end

    DisableFastAttack()
    _G.CurrentTarget = enemy

    pcall(function()
        local targetNames = { enemy.Name }
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            Player.Character.HumanoidRootPart.CFrame =
                CFrame.new(enemy.HumanoidRootPart.Position) * CFrame.new(0, 20, 0)
        end
        task.wait(0.1)

        local waited = 0
        while not _RegisterAttack or not _RegisterHit do
            GetCombatRemotes(); task.wait(0.3); waited = waited + 0.3
            if waited >= 5 then warn("[KillEnemy] Remote timeout"); return end
        end

        EnableFastAttack()
        EquipWeapon("Melee")
        AutoHaki()

        repeat
            task.wait()
            if not enemy or not enemy.Parent then break end
            if not enemy:FindFirstChild("Humanoid") or enemy.Humanoid.Health <= 0 then break end
            if not enemy:FindFirstChild("HumanoidRootPart") then break end
            Player.Character.HumanoidRootPart.CFrame =
                CFrame.new(enemy.HumanoidRootPart.Position) * CFrame.new(0, 20, 0)
            EquipWeapon("Melee")
            AutoHaki()
            BringEnemy(enemy.HumanoidRootPart.Position, targetNames)
        until not enemy or not enemy.Parent or enemy.Humanoid.Health <= 0
    end)

    DisableFastAttack()
    local t0 = tick()
    repeat task.wait(0.05) until tick() - t0 >= 0.8 or not enemy or not enemy.Parent
    _G.CurrentTarget = nil
end


-- =====================================================
--  AUTO STATS
-- =====================================================

local function AutoStats()
    pcall(function()
        local stats = {}
        for _, stat in pairs(Player.Data.Stats:GetChildren()) do
            if stat and stat:FindFirstChild("Level") then stats[stat.Name] = stat.Level.Value end
        end
        local level = Player.Data.Level.Value
        local target
        if (stats.Defense or 0) < MaxLevel
            and ((stats.Defense or 0) < (level / 80) or MaxLevel - (stats.Melee or 0) < 100)
        then
            target = "Defense"
        elseif (stats.Melee or 0) < MaxLevel then
            target = "Melee"
        else
            target = "Sword"
        end
        ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint", target, 999)
        SetTask("SubTask", string.format(
            "[AutoStats] Lv%d | DEF:%d | MELEE:%d | SWORD:%d → +%s",
            level, stats.Defense or 0, stats.Melee or 0, stats.Sword or 0, target
        ))
    end)
end


-- =====================================================
--  REDEEM CODES (X2 EXP)
-- =====================================================

local REDEEM_CODES = {
    'BANEXPLOIT','NOMOREHACKS','WildDares','BossBuild','GetPranked',
    'EARN_FRUITS','Sub2UncleKizaru','FIGHT4FRUIT','kittgaming',
    'TRIPLEABUSE','Sub2CaptainMaui','Sub2Fer999','Enyu_is_Pro',
    'Magicbus','JCWK','Starcodeheo','Bluxxy','SUB2GAMERROBOT_EXP1',
    'Sub2NoobMaster123','Sub2Daigrock','Axiore','TantaiGaming',
    'StrawHatMaine','Sub2OfficialNoobie','TheGreatAce','SEATROLLIN',
    '24NOADMIN','ADMIN_TROLL','NEWTROLL','SECRET_ADMIN','staffbattle',
    'NOEXPLOIT','NOOB2ADMIN','CODESLIDE','fruitconcepts',
}

local function GetExpBoost()
    local ok, boost = pcall(function()
        return getsenv(ReplicatedStorage.GuideModule)._G.ServerData.ExpBoost
    end)
    return ok and boost or 0
end

local function ShouldRedeem()
    local ok, level = pcall(function() return Player.Data.Level.Value end)
    if not ok or not level then return false end
    return level < MaxLevel
        and GetExpBoost() == 0
        and not LocalStorage:Get("IsCodesRanOut")
end

local function RedeemCodes()
    if not ShouldRedeem() then return end
    SetTask("MainTask", "[RedeemCode] Đang redeem code X2 EXP...")
    for _, code in ipairs(REDEEM_CODES) do
        if GetExpBoost() ~= 0 then SetTask("MainTask", "[RedeemCode] X2 EXP đã bật!"); return end
        SetTask("MainTask", "[RedeemCode] Thử code: " .. code)
        local ok, result = pcall(function() return ReplicatedStorage.Remotes.Redeem:InvokeServer(code) end)
        task.wait(0.5)
        SetTask("SubTask", "[RedeemCode] " .. code .. " → " .. tostring((ok and result) or "Failed"))
        if ok and result and type(result) == "string" and string.find(result, "SUCC") then
            SetTask("MainTask", "[RedeemCode] ✓ X2 Exp Boost kích hoạt!"); task.wait(1); return
        end
    end
    SetTask("SubTask", "[RedeemCode] Đã thử hết code")
    LocalStorage:Set("IsCodesRanOut", true)
end


-- =====================================================
--  QUEST SYSTEM
-- =====================================================

local old_getquest = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/noguchihyuga/idk/refs/heads/main/Quest.lua"
))()

local function getquest(...)
    local ok_lvl, lvl   = pcall(function() return Player.Data.Level.Value end)
    local ok_txt, qtext = pcall(function()
        return Player.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text
    end)
    if ok_txt and type(qtext) == "string" and qtext:lower() == "bandit"
        and ok_lvl and lvl > 10
    then
        ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest")
    end
    return old_getquest(...)
end

local function AbandonQuest()
    pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest") end)
    task.wait(0.5)
end


-- =====================================================
--  SKIP MODE  (Sky Palace - Shanda / Royal Squad)
-- =====================================================

local SKY_PALACE_PORTAL = Vector3.new(-7894.6176757813, 5547.1416015625, -380.29119873047)

local SKIP_DATA = {
    [1] = { label="Shanda",      mobs={"Shanda"},       minLevel=9,   maxLevel=70,
            spawnPos=CFrame.new(-7757,5562,-481), attackPos=CFrame.new(-7757,5582,-481) },
    [2] = { label="Royal Squad", mobs={"Royal Squad"},  minLevel=71,  maxLevel=150,
            spawnPos=CFrame.new(-7757,5562,-481), attackPos=CFrame.new(-7757,5582,-481) },
}

local function NeedsSkyPalace(level)
    return (level >= 475 and level <= 549) or (level >= 550 and level <= 624)
end

local function GetSkipFloor(level)
    for floor, data in pairs(SKIP_DATA) do
        if level >= data.minLevel and level <= data.maxLevel then return floor end
    end
    return nil
end

local function SkipModeFarm(level)
    local floor = GetSkipFloor(level)
    if not floor then return false end
    local data = SKIP_DATA[floor]
    SetTask("MainTask", string.format("[SkipMode] Floor %d | Lv%d | %s", floor, level, data.label))

    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        if (data.spawnPos.Position - Player.Character.HumanoidRootPart.Position).Magnitude > 3000 then
            SetTask("SubTask", "[SkipMode] Vào portal → Sky Palace...")
            ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", SKY_PALACE_PORTAL)
            task.wait(2)
        end
    end

    local enemy = GetConnectionEnemies(data.mobs)
    if enemy then
        KillEnemy(enemy)
    else
        local next = WaitForMobSpawn(data.mobs, data.attackPos, 30)
        if next then KillEnemy(next) end
    end
    return true
end


-- =====================================================
--  AUTO FARM LEVEL
-- =====================================================

local function AutoFarmLevel()
    local ok, level = pcall(function() return Player.Data.Level.Value end)
    if not ok or not level then task.wait(1); return end
    if SkipModeFarm(level) then return end

    local Mon, Qname, Qdata, NameMon, PosM, PosQ = getquest()
    if not Mon or not Qname or not PosM or not PosQ then
        SetTask("MainTask", "[AutoFarm] Level " .. level)
        SetTask("SubTask", "[AutoFarm] Không có quest data → chờ...")
        task.wait(2); return
    end

    SetTask("MainTask", string.format("[AutoFarm] Lv%d | %s", level, NameMon))

    pcall(function()
        local QuestTitle = Player.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text
        if QuestTitle and not string.find(QuestTitle, NameMon) then
            ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest")
        end

        if not Player.PlayerGui.Main.Quest.Visible then
            SetTask("SubTask", string.format("[AutoFarm] Tween → NPC: %s", Qname))
            if NeedsSkyPalace(level) then
                if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                    if (Vector3.new(-7757,5562,-481) - Player.Character.HumanoidRootPart.Position).Magnitude > 3000 then
                        SetTask("SubTask", "[AutoFarm] Teleport lên Sky Palace...")
                        ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", SKY_PALACE_PORTAL)
                        for _, waitFor in ipairs({"Shanda","Royal Squad","Sky Bandit","God's Guard","Warden","Chief Warden","Shisa"}) do
                            if Mon == waitFor then
                                task.wait(2)
                                local found = WaitForMobSpawn({Mon, NameMon}, PosM, 30)
                                if found then
                                    SetTask("SubTask", "[AutoFarm] Đã lên Sky Palace, tấn công " .. NameMon)
                                    KillEnemy(found); return
                                end
                            end
                        end
                    end
                end
            end
            topos(PosQ); WaitTween(12)
            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                if (Player.Character.HumanoidRootPart.Position - PosQ.Position).Magnitude <= 5 then
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", Qname, Qdata)
                end
            end
        else
            if Workspace.Enemies:FindFirstChild(Mon) then
                local title = Player.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text
                if not string.find(title, NameMon) then
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest"); return
                end
                SetTask("SubTask", string.format("[AutoFarm] Farm: %s", NameMon))
                DisableFastAttack(); EnableFastAttack()

                for _, v in pairs(Workspace.Enemies:GetChildren()) do
                    if v.Name == Mon
                        and v:FindFirstChild("HumanoidRootPart")
                        and v:FindFirstChild("Humanoid")
                        and v.Humanoid.Health > 0
                    then
                        if not Player.PlayerGui.Main.Quest.Visible then break end
                        _G.CurrentTarget = v
                        repeat
                            task.wait()
                            if not v or not v.Parent then break end
                            if not v:FindFirstChild("Humanoid") or v.Humanoid.Health <= 0 then break end
                            if not Player.PlayerGui.Main.Quest.Visible then break end
                            EquipWeapon("Melee"); AutoHaki()
                            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                Player.Character.HumanoidRootPart.CFrame =
                                    v.HumanoidRootPart.CFrame * CFrame.new(0, 20, 0)
                            end
                            BringEnemy(v.HumanoidRootPart.Position, {Mon})
                        until not v or not v.Parent or v.Humanoid.Health <= 0
                            or not Player.PlayerGui.Main.Quest.Visible
                        _G.CurrentTarget = nil
                        local t0 = tick()
                        repeat task.wait(0.05) until tick()-t0 >= 0.8 or not v or not v.Parent
                    end
                end
                DisableFastAttack()
            else
                SetTask("SubTask", "[AutoFarm] Hết mob → chờ respawn...")
                topos(PosM); WaitTween(12)
                local next = WaitForMobSpawn({Mon, NameMon}, PosM, 30)
                if next then task.wait(0.1) end
            end
        end
    end)
end


-- =====================================================
--  GET SABER
-- =====================================================

local function CheckItem(itemName)
    local ok, result = pcall(function()
        local inv = ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")
        for _, v in pairs(inv) do if v.Name == itemName then return v end end
        return nil
    end)
    return ok and result or nil
end

local function CheckBackpack(itemName)
    local function check(list)
        for _, v in next, list do
            if v:IsA("Tool") and (tostring(v)==itemName or v.Name==itemName or string.find(v.Name,itemName)) then
                return v
            end
        end
    end
    return check(Player.Backpack:GetChildren())
        or (Player.Character and check(Player.Character:GetChildren()))
        or nil
end

local function IsAlive(v)
    return v and v.Parent
        and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0
        and v:FindFirstChild("HumanoidRootPart")
end

local function GetMobByName(target)
    local name = typeof(target) == "Instance" and target.Name or target
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if v.Name == name and IsAlive(v) then return v end
    end
    return nil
end

local function KillMobByName(target)
    local v = GetMobByName(target)
    if not v or not IsAlive(v) then return end
    DisableFastAttack(); EnableFastAttack()
    _G.CurrentTarget = v
    repeat
        task.wait(); if not IsAlive(v) then break end
        EquipWeapon("Melee"); AutoHaki()
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            Player.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0,20,0)
        end
        BringEnemy(v.HumanoidRootPart.Position, {v.Name})
    until not IsAlive(v)
    DisableFastAttack(); _G.CurrentTarget = nil; task.wait(0.5)
end

local function HopServers()
    SetTask("SubTask", "[Saber] Hop server sau 5 giây...")
    task.wait(5)
    pcall(function()
        local servers = {}
        local body = game:GetService("HttpService"):JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId..
                "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
        )
        if body and body.data then
            for _, v in next, body.data do
                if type(v)=="table" and tonumber(v.playing) and tonumber(v.maxPlayers)
                    and v.playing < v.maxPlayers and v.id ~= game.JobId and v.playing >= 10
                then
                    table.insert(servers, v.id)
                end
            end
        end
        if #servers > 0 then
            for _ = 1, 36 do
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, servers[math.random(1,#servers)], Player)
                task.wait(0.1)
            end
        end
    end)
end

local _saberDone = false

local function GetSaber()
    if _saberDone then return true end
    if CheckItem("Saber") then _saberDone = true; return true end
    SetTask("MainTask", "[Saber] Đang làm nhiệm vụ Saber...")

    pcall(function()
        local jungleFinalPart = Workspace.Map.Jungle.Final.Part
        if jungleFinalPart.CanCollide then
            if Workspace.Map.Jungle.QuestPlates.Door.CanCollide then
                SetTask("SubTask", "[Saber] Kích hoạt quest plates Jungle...")
                for _, v in next, Workspace.Map.Jungle.QuestPlates:GetChildren() do
                    if v:FindFirstChild("Button") and v.Button:FindFirstChild("TouchInterest") then
                        firetouchinterest(v.Button, Player.Character.HumanoidRootPart, 0)
                        firetouchinterest(v.Button, Player.Character.HumanoidRootPart, 1)
                    end
                end
            else
                if Workspace.Map.Desert.Burn.Part.CanCollide then
                    if not CheckBackpack("Torch") then
                        SetTask("SubTask", "[Saber] Lấy Torch...")
                        firetouchinterest(Workspace.Map.Jungle.Torch, Player.Character.HumanoidRootPart, 0)
                        firetouchinterest(Workspace.Map.Jungle.Torch, Player.Character.HumanoidRootPart, 1)
                    else
                        SetTask("SubTask", "[Saber] Thắp lửa Desert...")
                        EquipWeapon("Torch"); task.wait(0.2)
                        firetouchinterest(Player.Character.Torch.Handle, Workspace.Map.Desert.Burn.Fire, 0)
                        firetouchinterest(Player.Character.Torch.Handle, Workspace.Map.Desert.Burn.Fire, 1)
                    end
                else
                    local Progress = ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")
                    if Progress ~= 0 and Progress ~= 1 then
                        if not CheckBackpack("Cup") then
                            SetTask("SubTask", "[Saber] Lấy Cup...")
                            firetouchinterest(Workspace.Map.Desert.Cup, Player.Character.HumanoidRootPart, 0)
                            firetouchinterest(Workspace.Map.Desert.Cup, Player.Character.HumanoidRootPart, 1)
                        else
                            SetTask("SubTask", "[Saber] Dùng Cup...")
                            EquipWeapon("Cup"); task.wait(0.1)
                            ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "FillCup",
                                Player.Character:FindFirstChild("Cup"))
                            ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "SickMan")
                        end
                    elseif Progress == 0 then
                        SetTask("SubTask", "[Saber] Giết Mob Leader...")
                        KillMobByName("Mob Leader")
                    elseif Progress == 1 then
                        if not CheckBackpack("Relic") then
                            SetTask("SubTask", "[Saber] Lấy Relic...")
                            ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")
                        else
                            SetTask("SubTask", "[Saber] Dùng Relic mở cửa Jungle...")
                            EquipWeapon("Relic"); task.wait(0.1)
                            firetouchinterest(Player.Character.Relic.Handle, Workspace.Map.Jungle.Final.Invis, 0)
                            firetouchinterest(Player.Character.Relic.Handle, Workspace.Map.Jungle.Final.Invis, 1)
                        end
                    end
                end
            end
        else
            local saberExpert = GetMobByName("Saber Expert")
            if saberExpert then
                SetTask("SubTask", "[Saber] Giết Saber Expert...")
                KillMobByName("Saber Expert")
            else
                SetTask("SubTask", "[Saber] Không thấy Saber Expert → hop server...")
                HopServers()
            end
        end
    end)

    if CheckItem("Saber") then _saberDone = true; SetTask("MainTask","[Saber] ✓ Đã lấy Saber!"); return true end
    return false
end


-- =====================================================
--  FRUIT COLLECT
-- =====================================================

local function StoreFruitInBackpack()
    for _, e in pairs(Player.Backpack:GetChildren()) do
        if e:FindFirstChild("EatRemote", true) then
            local orig = e:GetAttribute("OriginalName")
            if orig then
                pcall(function()
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", orig,
                        Player.Backpack:FindFirstChild(e.Name))
                end)
            end
        end
    end
end

local function HasFruitOnMap()
    for _, obj in pairs(Workspace:GetChildren()) do
        if string.find(obj.Name, "Fruit") then return true end
    end
    return false
end

local function TweenToFruits()
    for _, obj in pairs(Workspace:GetChildren()) do
        if string.find(obj.Name, "Fruit") then
            pcall(function()
                topos(obj.Handle.CFrame); WaitTween(10); task.wait(0.3)
                StoreFruitInBackpack()
            end)
        end
    end
end


-- =====================================================
--  AUTO FULLY MELEE
-- =====================================================

-- Thứ tự mua: Black Leg → Electro → Fishman Karate → Dragon Claw
-- → Superhuman → Death Step → Sharkman Karate → Electric Claw
-- → Dragon Talon → Godhuman → Sanguine Art

local MELEE_LIST = {
    "Black Leg", "Electro", "Fishman Karate", "Dragon Claw",
    "Superhuman", "Death Step", "Sharkman Karate", "Electric Claw",
    "Dragon Talon", "Godhuman", "Sanguine Art",
}

-- Remote cần gọi khi mua (single hoặc multi-call)
local MELEE_REMOTES = {
    ["Black Leg"]       = { "BuyBlackLeg"                                           },
    ["Electro"]         = { "BuyElectro"                                            },
    ["Fishman Karate"]  = { "BuyFishmanKarate"                                      },
    ["Dragon Claw"]     = { {"BlackbeardReward","DragonClaw","1"}, {"BlackbeardReward","DragonClaw","2"} },
    ["Superhuman"]      = { "BuySuperhuman"                                         },
    ["Death Step"]      = { "BuyDeathStep"                                          },
    ["Sharkman Karate"] = { "BuySharkmanKarate"                                     },
    ["Electric Claw"]   = { "BuyElectricClaw"                                       },
    ["Dragon Talon"]    = { "BuyDragonTalon"                                        },
    ["Godhuman"]        = { "BuyGodhuman"                                           },
    ["Sanguine Art"]    = { {"BuySanguineArt", true}, {"BuySanguineArt"}            },
}

-- NPC bán melee
local MELEE_NPC = {
    ["Black Leg"]       = "Dark Step Teacher",
    ["Electro"]         = "Mad Scientist",
    ["Fishman Karate"]  = "Water Kung-fu Teacher",
    ["Dragon Claw"]     = "Sabi",
    ["Superhuman"]      = "Martial Arts Master",
    ["Death Step"]      = "Phoeyu, the Reformed",
    ["Sharkman Karate"] = "Sharkman Teacher",
    ["Electric Claw"]   = "Previous Hero",
    ["Dragon Talon"]    = "Uzoth",
    ["Godhuman"]        = "Ancient Monk",
    ["Sanguine Art"]    = "Shafi",
}

-- Giá mua (Beli / Fragments)
local MELEE_PRICE = {
    ["Black Leg"]       = { Beli = 150000                   },
    ["Electro"]         = { Beli = 500000                   },
    ["Fishman Karate"]  = { Beli = 750000                   },
    ["Dragon Claw"]     = { Fragments = 1500                },
    ["Superhuman"]      = { Beli = 3000000                  },
    ["Death Step"]      = { Beli = 2500000, Fragments = 5000 },
    ["Sharkman Karate"] = { Beli = 2500000, Fragments = 5000 },
    ["Electric Claw"]   = { Beli = 2500000, Fragments = 5000 },
    ["Dragon Talon"]    = { Beli = 2500000, Fragments = 5000 },
    ["Godhuman"]        = { Beli = 5000000, Fragments = 5000 },
    ["Sanguine Art"]    = { Beli = 3000000, Fragments = 3000 },
}

-- Mastery cần đạt mới unlock melee tiếp theo
local MELEE_MASTERY_REQ = {
    ["Black Leg"]       = 400,
    ["Electro"]         = 400,
    ["Fishman Karate"]  = 400,
    ["Dragon Claw"]     = 400,
    ["Superhuman"]      = 400,
    ["Death Step"]      = 400,
    ["Sharkman Karate"] = 400,
    ["Electric Claw"]   = 400,
    ["Dragon Talon"]    = 400,
    ["Godhuman"]        = 350,
    ["Sanguine Art"]    = 400,
}

-- Sea yêu cầu để mua (nil = bất kỳ)
local MELEE_SEA_REQ = {
    ["Death Step"]      = 2,
    ["Sharkman Karate"] = 2,
    ["Electric Claw"]   = 3,
    ["Dragon Talon"]    = 3,
    ["Godhuman"]        = 3,
    ["Sanguine Art"]    = 3,
}

-- Lấy Sea hiện tại từ PlaceId
local function GetCurrentSea()
    local pid = game.PlaceId
    if pid == 85211729168715 or pid == 2753915549  then return 1 end
    if pid == 79091703265657 or pid == 4442272183  then return 2 end
    if pid == 100117331123089 or pid == 7449423635 then return 3 end
    return 1
end

-- Đọc Beli / Fragments của player
local function GetCurrency(name)
    local ok, val = pcall(function() return Player.Data[name].Value end)
    return ok and val or 0
end

-- Đọc mastery melee từ Tool trong character/backpack
local function GetMeleeMastery(meleeName)
    local function findIn(list)
        for _, v in pairs(list) do
            if v:IsA("Tool") and v.ToolTip == "Melee" and v.Name == meleeName then
                local lvl = v:FindFirstChild("Level")
                return lvl and lvl.Value or 0
            end
        end
    end
    return findIn(Player.Character:GetChildren())
        or findIn(Player.Backpack:GetChildren())
        or 0
end

-- Check player đang cầm melee tên X
local function HasMeleeEquipped(meleeName)
    for _, v in pairs(Player.Character:GetChildren()) do
        if v:IsA("Tool") and v.ToolTip == "Melee" and v.Name == meleeName then return true end
    end
    for _, v in pairs(Player.Backpack:GetChildren()) do
        if v:IsA("Tool") and v.ToolTip == "Melee" and v.Name == meleeName then return true end
    end
    return false
end

-- =====================================================
--  NPC FINDER
--  Quy tắc game: NPC chỉ tồn tại ở MỘT trong hai nơi tại một thời điểm:
--    • ReplicatedStorage.NPCs : player đang ở XA  → dùng để navigate
--    • Workspace.NPCs         : player đã ĐỦ GẦN → NPC thật, invoke remote được
-- =====================================================

local function FindNPCInWorkspace(npcName)
    local folder = Workspace:FindFirstChild("NPCs")
    return folder and folder:FindFirstChild(npcName) or nil
end

local function FindNPCInRS(npcName)
    local folder = ReplicatedStorage:FindFirstChild("NPCs")
    return folder and folder:FindFirstChild(npcName) or nil
end

-- Lấy CFrame từ NPC model (hỗ trợ nhiều kiểu instance)
local function GetNPCCFrame(npc)
    if not npc then return nil end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.CFrame end
    if npc:IsA("Model") and npc.PrimaryPart then return npc.PrimaryPart.CFrame end
    local ok, cf = pcall(function() return npc:GetModelCFrame() end)
    if ok and cf then return cf end
    local ok2, cf2 = pcall(function() return npc.WorldPivot end)
    if ok2 and cf2 then return cf2 end
    if npc:IsA("BasePart") then return npc.CFrame end
    return nil
end

-- Trả về (CFrame, isInWorkspace):
--   true  = NPC đã spawn vào WS → có thể invoke remote ngay
--   false = NPC còn ở RS → cần tiếp tục tween đến gần hơn
local function GetNPCNavCFrame(npcName)
    local wsNPC = FindNPCInWorkspace(npcName)
    if wsNPC then
        local cf = GetNPCCFrame(wsNPC)
        if cf then return cf, true end
    end
    local rsNPC = FindNPCInRS(npcName)
    if rsNPC then
        local cf = GetNPCCFrame(rsNPC)
        if cf then return cf, false end
    end
    return nil, nil
end

-- Fire remote mua melee (hỗ trợ single/multi call)
local function FireMeleeRemote(meleeName)
    local remotes = MELEE_REMOTES[meleeName]
    if not remotes then return end
    if type(remotes[1]) == "table" then
        -- Multiple calls (Dragon Claw, Sanguine Art)
        for _, args in ipairs(remotes) do
            pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer(unpack(args)) end)
            task.wait(0.5)
        end
    else
        -- Single call
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer(unpack(remotes)) end)
    end
end

-- Trạng thái nội bộ của AutoFullyMelee
local _meleeBuying    = false  -- true khi đang trong quá trình đi mua
local _meleeAllDone   = false  -- true khi đã xong tất cả melee trong list

-- Quét danh sách, trả về melee tiếp theo cần xử lý (hoặc nil nếu xong hết)
local function GetNextMeleeTarget()
    local sea = GetCurrentSea()
    for _, name in ipairs(MELEE_LIST) do
        local mastery = GetMeleeMastery(name)
        local req     = MELEE_MASTERY_REQ[name] or 400

        -- Đã đủ mastery → xong, sang melee tiếp
        if mastery >= req then continue end

        -- Đã sở hữu (mastery > 0 hoặc có trong tay) nhưng chưa đủ → cần farm
        if mastery > 0 or HasMeleeEquipped(name) then return name, "farm" end

        -- Chưa mua: kiểm tra sea requirement
        local seaReq = MELEE_SEA_REQ[name]
        if seaReq and sea ~= seaReq then
            -- Sai sea, không thể mua → skip (sẽ được mở khi travel sea đúng)
            continue
        end

        -- Kiểm tra đủ tiền
        local price     = MELEE_PRICE[name] or {}
        local canAfford = true
        for currency, required in pairs(price) do
            if GetCurrency(currency) < required then
                canAfford = false
                SetTask("SubTask", string.format(
                    "[Melee] Chờ đủ %s (%d/%d) để mua %s",
                    currency, GetCurrency(currency), required, name
                ))
                break
            end
        end

        if canAfford then return name, "buy" end
        -- Chưa đủ tiền → để farm kiếm thêm, nhưng vẫn tiếp tục xem
        -- các melee sau có cần farm mastery không
    end
    return nil, nil
end

-- Luồng chính AutoFullyMelee (chạy trong task.spawn riêng)
-- _meleeBuying được set true để Main Loop biết tạm dừng AutoFarmLevel
local function AutoFullyMelee()
    while task.wait(0.5) do
        if _meleeAllDone then break end

        local name, action = GetNextMeleeTarget()

        -- Xong hết danh sách
        if not name then
            _meleeAllDone = true
            _meleeBuying  = false
            SetTask("MainTask", "[Melee] ✓ Đã mua & farm đủ mastery tất cả melee!")
            break
        end

        if action == "farm" then
            -- Chỉ equip đúng melee, để Main Loop tiếp tục farm bình thường
            _meleeBuying = false
            SetTask("SubTask", string.format(
                "[Melee] Farm mastery %s (%d/%d) → equip",
                name, GetMeleeMastery(name), MELEE_MASTERY_REQ[name] or 400
            ))
            EquipWeapon("Melee")

        elseif action == "buy" then
            -- Báo cho Main Loop biết: TẠM DỪNG farm, đang đi mua melee
            _meleeBuying = true

            local npcName = MELEE_NPC[name]
            if not npcName then
                SetTask("SubTask", "[Melee] Không có NPC data cho " .. name)
                _meleeBuying = false
                continue
            end

            SetTask("MainTask", "[Melee] Đi mua " .. name .. " từ " .. npcName)
            DisableFastAttack()

            -- Tween đến NPC.
            -- • NPC ở RS  → player còn xa, tiếp tục tween
            -- • NPC ở WS  → player đã đủ gần, NPC thật đã spawn → mua được
            local NAV_TIMEOUT = 30
            local navStart    = tick()
            local readyToBuy  = false

            while tick() - navStart < NAV_TIMEOUT do
                if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then
                    task.wait(0.5); continue
                end

                local navCF, isInWorkspace = GetNPCNavCFrame(npcName)
                if not navCF then
                    SetTask("SubTask", "[Melee] Không tìm thấy NPC: " .. npcName .. " → chờ...")
                    task.wait(2); continue
                end

                if isInWorkspace then
                    -- NPC đã ở WS → đủ gần, có thể invoke remote
                    readyToBuy = true
                    break
                end

                -- NPC còn ở RS → cần tween đến gần hơn
                local dist = (Player.Character.HumanoidRootPart.Position - navCF.Position).Magnitude
                SetTask("SubTask", string.format(
                    "[Melee] Tween → %s (còn %.0f studs, chờ NPC spawn...)", npcName, dist
                ))
                topos(navCF)
                WaitTween(12)
            end

            if not readyToBuy then
                SetTask("SubTask", "[Melee] Timeout tween tới " .. npcName .. " → thử lại sau")
                _meleeBuying = false
                continue
            end

            -- Mua
            SetTask("SubTask", "[Melee] Mua " .. name .. "...")
            DisableFastAttack() -- dừng attack khi đứng trước NPC
            FireMeleeRemote(name)
            task.wait(1)

            -- Kiểm tra kết quả
            if HasMeleeEquipped(name) or GetMeleeMastery(name) > 0 then
                SetTask("SubTask", "[Melee] ✓ Mua " .. name .. " thành công!")
                EquipWeapon("Melee")
            else
                SetTask("SubTask", "[Melee] Mua " .. name .. " chưa thành công, sẽ thử lại...")
            end

            _meleeBuying = false
        end
    end
end


-- =====================================================
--  KHỞI ĐỘNG
-- =====================================================

repeat task.wait()
until Player.Character
    and Player.Character:FindFirstChild("HumanoidRootPart")
    and Player:FindFirstChild("Data")

print("[Kaitun] ✓ Character & Data loaded → Khởi động tất cả hệ thống...")

-- Loop 1: Auto Farm Level — ưu tiên: Saber > Fruit > Melee Buy > Farm
task.spawn(function()
    while task.wait(0.1) do
        local ok, level = pcall(function() return Player.Data.Level.Value end)
        local currentLevel = ok and level or 0

        -- Ưu tiên 1: GetSaber (level ≥ 300)
        if currentLevel >= 300 and not _saberDone then
            local saberOk, saberErr = pcall(GetSaber)
            if not saberOk then
                SetTask("SubTask", "[Saber] Lỗi: " .. tostring(saberErr)); task.wait(2)
            end

        -- Ưu tiên 2: Collect fruit trên map
        elseif HasFruitOnMap() then
            SetTask("SubTask", "[Fruit] Phát hiện fruit → dừng farm, đi collect...")
            DisableFastAttack()
            _G.CurrentTarget = nil
            TweenToFruits()
            SetTask("SubTask", "[Fruit] Đã collect xong → tiếp tục farm")

        -- Ưu tiên 3: Đang đi mua melee → nhường cho AutoFullyMelee xử lý
        elseif _meleeBuying then
            SetTask("MainTask", "[Farm] Tạm dừng — đang đi mua melee...")
            DisableFastAttack()
            _G.CurrentTarget = nil
            task.wait(0.5)

        -- Ưu tiên 4: Farm bình thường
        else
            local farmOk, farmErr = pcall(AutoFarmLevel)
            if not farmOk then
                _G.CurrentTarget = nil
                DisableFastAttack()
                SetTask("SubTask", "[AutoFarm] Lỗi: " .. tostring(farmErr)); task.wait(2)
            end
        end
    end
end)

-- Loop 2: Auto Fully Melee (chạy song song, tự nhường cho farm khi action == "farm")
task.spawn(AutoFullyMelee)

-- Loop 3: Auto Stats (event-based)
task.spawn(function()
    repeat task.wait() until Player.Data:FindFirstChild("Points")
    AutoStats()
    Player.Data.Points.Changed:Connect(function(newVal)
        if newVal and newVal > 0 then AutoStats() end
    end)
    print("[Kaitun] ✓ AutoStats → Online")
end)

-- Loop 4: Auto Haki (check mỗi 5s)
task.spawn(function()
    while task.wait(5) do AutoHaki() end
end)

-- Loop 5: Redeem Code X2 EXP (thử 1 lần lúc đầu, sau đó check mỗi 60s)
task.spawn(function()
    task.wait(3); RedeemCodes()
    while task.wait(60) do
        if not LocalStorage:Get("IsCodesRanOut") and GetExpBoost() == 0 then
            RedeemCodes()
        end
    end
end)

-- Loop 6: Random Fruit (mua từ Cousin liên tục)
task.spawn(function()
    while true do
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("Cousin", "Buy") end)
        task.wait(0.5)
    end
end)

-- Loop 7: Auto Store — store ngay khi nhặt được fruit
task.spawn(function()
    local function onItemAdded(item)
        task.wait(0.1)
        pcall(function()
            if item:FindFirstChild("EatRemote", true) then
                local orig = item:GetAttribute("OriginalName")
                if orig then
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("StoreFruit", orig,
                        Player.Backpack:FindFirstChild(item.Name))
                end
            end
        end)
    end
    pcall(StoreFruitInBackpack)
    Player.Backpack.ChildAdded:Connect(onItemAdded)
end)

print("[Kaitun] ✓ Tất cả systems online | BringMob =", _G.BringMob)
