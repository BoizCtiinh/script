--// =====================================================
--//   KAITUN HUB - AUTO FARM LEVEL
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

-- BringMob bật luôn khi script chạy
_G.BringMob = true

-- SetTask fallback
if not SetTask then
    function SetTask(key, msg) print("[" .. key .. "] " .. msg) end
end

-- Storage đơn giản để lưu trạng thái giữa các session
local LocalStorage = {}
function LocalStorage:Get(key) return self[key] end
function LocalStorage:Set(key, val) self[key] = val end
function LocalStorage:Save() end -- placeholder nếu cần ghi file


-- =====================================================
--  PORTAL TELEPORT (ported from BF-MainNightHub)
-- =====================================================

-- Detect world (Sea1 / Sea2 / Sea3)
local rz_MAP = workspace:GetAttribute("MAP")
local World   = (rz_MAP == "Sea1" and 1)
             or ((rz_MAP == "Sea2" or rz_MAP == "Dungeons") and 2)
             or (rz_MAP == "Sea3" and 3)
             or 1

-- Portal entrance positions cho từng thế giới
local PortalData = {
    [1] = {
        ["Sky Arena 1"]       = Vector3.new(-4654,  872,  -1759),
        ["Sky Arena 2"]       = Vector3.new(-7894, 5547,   -380),
        ["UnderWater City 1"] = Vector3.new( 3876,   35,  -1939),
        ["UnderWater City 2"] = Vector3.new(61163,   11,   1819),
    },
    [2] = {
        ["Mansion"]   = Vector3.new( -288, 305,    613),
        ["Swan Room"] = Vector3.new( 2284,  15,    897),
        ["Out Ship"]  = Vector3.new(-6518,  83,   -145),
        ["In Ship"]   = Vector3.new(  923, 125,  32883),
    },
    [3] = {
        ["Mansion"]           = Vector3.new(-12550, 337,  -7476),
        ["Castle On The Sea"] = Vector3.new( -5073, 314,  -3152),
        ["Hydra Island"]      = Vector3.new(  5681,1013,   -313),
        ["Temple Of Time"]    = Vector3.new( 28294,14896,   103),
    },
}

-- Trả về Location zone mà position đang ở trong đó
local function InArea(pos)
    if typeof(pos) == "CFrame" then pos = pos.Position end
    local ok, result = pcall(function()
        for _, v in pairs(workspace._WorldOrigin.Locations:GetChildren()) do
            if v:IsA("BasePart") and v:FindFirstChildOfClass("SpecialMesh") then
                if (pos - v.Position).Magnitude <= v.Mesh.Scale.X then
                    return v
                end
            end
        end
        return {Name = ""}
    end)
    return (ok and result) or {Name = ""}
end

-- Tìm portal gần target nhất và kiểm tra xem nó có thực sự shortcut không
local function GetPortalTeleport(targetCFrame)
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    local hrp = Player.Character.HumanoidRootPart

    -- Không dùng portal nếu dưới đất sâu hoặc đang raid
    if hrp.CFrame.Y <= -500 then return false end
    pcall(function()
        if Player.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
            error("raiding")
        end
    end)

    -- Chỉ dùng portal nếu đích và player ở 2 khu vực khác nhau
    local targetPos  = (typeof(targetCFrame) == "CFrame") and targetCFrame.Position or targetCFrame
    local targetArea = InArea(targetPos)
    local playerArea = InArea(hrp.Position)
    if targetArea.Name == playerArea.Name then return false end

    -- Tìm portal gần target nhất
    local portals   = PortalData[World] or {}
    local bestPortal, bestName, bestDist = nil, "", math.huge
    for name, portalPos in pairs(portals) do
        local d = (portalPos - targetPos).Magnitude
        if d < bestDist then
            bestDist  = d
            bestPortal = portalPos
            bestName  = name
        end
    end
    if not bestPortal then return false end

    -- Chỉ dùng portal nếu nó thực sự rút ngắn đường đi (+ buffer 250 studs)
    local playerDist = (hrp.Position - targetPos).Magnitude
    if bestDist + 250 <= playerDist then
        return bestPortal, bestName
    end
    return false
end

local _lastPortalTick = 0

-- Gọi portal teleport nếu có thể; trả về true nếu đã dùng portal
local function TryPortalTeleport(targetCFrame)
    -- Rate-limit: tối đa 1 lần mỗi 8 giây để tránh spam
    if tick() - _lastPortalTick < 8 then return false end
    local ok, portal, name = pcall(GetPortalTeleport, targetCFrame)
    if ok and portal then
        print("[Portal] ✓ Sử dụng portal →", name)
        _lastPortalTick = tick()
        pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", portal)
        end)
        task.wait(1.5) -- chờ server load map mới
        return true
    end
    return false
end


-- =====================================================
--  TWEEN FUNCTIONS
-- =====================================================

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

function topos(targetCFrame)
    if _G.LockTween then return end
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end

    -- ✦ Thử portal teleport trước khi tween
    --   Nếu có portal shortcut thì dùng luôn, skip tween
    if TryPortalTeleport(targetCFrame) then return end

    local hrp      = Player.Character.HumanoidRootPart
    local distance = (targetCFrame.Position - hrp.Position).Magnitude

    if distance < 10 then
        hrp.CFrame = targetCFrame
        return
    end

    _G.LockTween = true

    for _, part in pairs(Player.Character:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end

    local bodyVelocity    = Instance.new("BodyVelocity")
    bodyVelocity.Name     = "BodyClip"
    bodyVelocity.Parent   = hrp
    bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)

    local part        = Instance.new("Part")
    part.Name         = "PartTele"
    part.Size         = Vector3.new(1, 1, 1)
    part.Transparency = 1
    part.CanCollide   = false
    part.Anchored     = true
    part.CFrame       = hrp.CFrame
    part.Parent       = Player.Character

    local duration  = distance / 350
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween     = TweenService:Create(part, tweenInfo, {CFrame = targetCFrame})

    local connection
    connection = RunService.Heartbeat:Connect(function()
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

local function WaitTween(timeout)
    timeout = timeout or 15
    local t = tick()
    repeat task.wait(0.05) until not _G.LockTween or tick() - t > timeout
end


-- =====================================================
--  FAST ATTACK
--  Remote được cache 1 lần khi script load
--  để tránh require() lỗi bên trong KillEnemy
-- =====================================================

local FastAttackEnabled = false
local AttackConnection

-- Lazy-init: cache sau khi Net module sẵn sàng
local _RegisterAttack, _RegisterHit
local function GetCombatRemotes()
    if _RegisterAttack and _RegisterHit then
        return _RegisterAttack, _RegisterHit
    end
    local ok, CombatFramework = pcall(require, ReplicatedStorage.Modules.Net)
    if not ok or not CombatFramework then return nil, nil end
    local ok2, ra = pcall(function() return CombatFramework:RemoteEvent("RegisterAttack", true) end)
    local ok3, rh = pcall(function() return CombatFramework:RemoteEvent("RegisterHit",   true) end)
    if ok2 and ok3 and ra and rh then
        _RegisterAttack = ra
        _RegisterHit    = rh
    end
    return _RegisterAttack, _RegisterHit
end

local function GetBladeHits()
    local hits = {}
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then
        return hits
    end
    local playerPos = Player.Character.HumanoidRootPart.Position
    for _, enemy in pairs(Workspace.Enemies:GetChildren()) do
        if enemy:FindFirstChild("Humanoid") and enemy:FindFirstChild("HumanoidRootPart") then
            if enemy.Humanoid.Health > 0 then
                if (enemy.HumanoidRootPart.Position - playerPos).Magnitude <= 65 then
                    table.insert(hits, enemy)
                end
            end
        end
    end
    return hits
end

function EnableFastAttack()
    if AttackConnection then return end

    local RegisterAttack, RegisterHit = GetCombatRemotes()
    if not RegisterAttack or not RegisterHit then
        warn("[FastAttack] Không lấy được remotes, thử lại sau...")
        return
    end

    FastAttackEnabled = true
    local tickCount = 0

    AttackConnection = RunService.Heartbeat:Connect(function()
        if not FastAttackEnabled then return end
        tickCount = tickCount + 1
        if tickCount % 2 ~= 0 then return end
        pcall(function()
            local hits = GetBladeHits()
            if #hits == 0 then return end
            local args = {[1] = nil, [2] = {}, [4] = "078da5141"}
            for _, enemy in pairs(hits) do
                RegisterAttack:FireServer(0)
                if not args[1] then args[1] = enemy.Head end
                table.insert(args[2], {[1] = enemy, [2] = enemy.HumanoidRootPart})
                table.insert(args[2], enemy)
            end
            RegisterHit:FireServer(unpack(args))
        end)
    end)
end

function DisableFastAttack()
    FastAttackEnabled = false
    if AttackConnection then
        AttackConnection:Disconnect()
        AttackConnection = nil
    end
end


-- =====================================================
--  EQUIP WEAPON
-- =====================================================

local function EquipWeapon(weaponName)
    pcall(function()
        if weaponName == "Melee" then
            for _, v in pairs(Player.Backpack:GetChildren()) do
                if v.ToolTip == "Melee" then
                    Player.Character.Humanoid:EquipTool(v)
                    return
                end
            end
            for _, v in pairs(Player.Character:GetChildren()) do
                if v:IsA("Tool") and v.ToolTip == "Melee" then return end
            end
        else
            local tool = Player.Backpack:FindFirstChild(weaponName)
            if tool then Player.Character.Humanoid:EquipTool(tool); return end
            if Player.Character:FindFirstChild(weaponName) then return end
        end
    end)
end


-- =====================================================
--  AUTO HAKI
-- =====================================================

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

-- targetNames: table tên mob được phép bring (nil = bring tất cả)
local function BringEnemy(PosMon, targetNames)
    if not _G.BringMob then return end

    local nameSet = {}
    if targetNames then
        for _, n in pairs(targetNames) do nameSet[n] = true end
    end

    pcall(function()
        for _, enemy in pairs(Workspace.Enemies:GetChildren()) do
            if targetNames and not nameSet[enemy.Name] then continue end

            if enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                if enemy:FindFirstChild("HumanoidRootPart") then
                    local dist = (enemy.HumanoidRootPart.Position - PosMon).Magnitude
                    if dist > 20 and dist <= 300 then
                        local offset = Vector3.new(
                            math.random(-6, 6),
                            0,
                            math.random(-6, 6)
                        )
                        enemy.HumanoidRootPart.CFrame = CFrame.new(PosMon + offset)
                        sethiddenproperty(Player, "SimulationRadius", math.huge)
                    end
                end
            end
        end
    end)
end


-- =====================================================
--  GET / KILL ENEMY
-- =====================================================

local function GetConnectionEnemies(enemyNames)
    for _, enemyName in pairs(enemyNames) do
        for _, enemy in pairs(Workspace.Enemies:GetChildren()) do
            if enemy.Name == enemyName and enemy:FindFirstChild("Humanoid") then
                if enemy.Humanoid.Health > 0 then return enemy end
            end
        end
    end
    return nil
end

-- Đọc vị trí spawn của mob từ ReplicatedStorage
-- Trả về CFrame của spawn point gần player nhất, hoặc nil
local function GetSpawnCFrameFromRS(mobName)
    local ok, result = pcall(function()
        local folder = ReplicatedStorage:FindFirstChild("FortBuilderReplicatedSpawnPositionsFolder")
        if not folder then return nil end
        local mobFolder = folder:FindFirstChild(mobName)
        if not mobFolder then return nil end

        local playerPos = Player.Character
            and Player.Character:FindFirstChild("HumanoidRootPart")
            and Player.Character.HumanoidRootPart.Position
            or Vector3.new(0, 0, 0)

        local bestCFrame, bestDist = nil, math.huge

        local function tryPart(part)
            local cf
            if part:IsA("BasePart") then
                cf = part.CFrame
            elseif part:IsA("CFrameValue") then
                cf = part.Value
            elseif part:IsA("Vector3Value") then
                cf = CFrame.new(part.Value)
            end
            if cf then
                local d = (cf.Position - playerPos).Magnitude
                if d < bestDist then bestDist = d; bestCFrame = cf end
            end
        end

        -- Bản thân mobFolder có thể là BasePart
        tryPart(mobFolder)
        -- Hoặc chứa các spawn point con
        for _, child in pairs(mobFolder:GetChildren()) do
            tryPart(child)
            -- Đệ quy một tầng (trường hợp nested model)
            for _, grandchild in pairs(child:GetChildren()) do
                tryPart(grandchild)
            end
        end

        return bestCFrame
    end)
    return ok and result or nil
end

-- Chờ mob xuất hiện trong Workspace, trước đó dùng RS để tween về đúng spawn point
-- Trả về enemy khi tìm thấy, hoặc nil nếu timeout
local function WaitForMobSpawn(enemyNames, posM, timeout)
    timeout = timeout or 30
    local t0 = tick()

    -- Tween về spawn point (lấy từ RS hoặc fallback về posM)
    local spawnCFrame
    for _, name in pairs(enemyNames) do
        spawnCFrame = GetSpawnCFrameFromRS(name)
        if spawnCFrame then break end
    end
    local waitPos = spawnCFrame or posM

    -- Chỉ tween nếu đang ở xa
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local dist = (waitPos.Position - Player.Character.HumanoidRootPart.Position).Magnitude
        if dist > 30 then
            topos(waitPos)
            WaitTween(15)
        end
    end

    -- Poll Workspace, fallback về RS poll nếu chưa thấy
    while tick() - t0 < timeout do
        local found = GetConnectionEnemies(enemyNames)
        if found then return found end

        local timeLeft = timeout - (tick() - t0)
        SetTask("SubTask", string.format(
            "[AutoFarm] Chờ mob spawn... (%.0fs)",
            timeLeft
        ))
        task.wait(0.5)
    end

    return nil
end

local function KillEnemy(enemy)
    if not enemy or not enemy.Parent then return end
    if not enemy:FindFirstChild("Humanoid") or enemy.Humanoid.Health <= 0 then return end
    if not enemy:FindFirstChild("HumanoidRootPart") then return end

    -- Reset sạch trước khi bắt đầu (tránh stale state từ lần trước)
    DisableFastAttack()
    _G.CurrentTarget = enemy

    pcall(function()
        local mobName     = enemy.Name
        local targetNames = {mobName}

        -- ① Snap ngay tới mob để server thấy đúng vị trí trước khi fire remotes
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            Player.Character.HumanoidRootPart.CFrame =
                CFrame.new(enemy.HumanoidRootPart.Position) * CFrame.new(0, 20, 0)
        end
        task.wait(0.1) -- nhường 1 frame để vị trí kịp replicate lên server

        -- ② Chờ combat remotes sẵn sàng (tối đa 5s, thử mỗi 0.3s)
        local remoteWait = 0
        while not _RegisterAttack or not _RegisterHit do
            GetCombatRemotes()
            task.wait(0.3)
            remoteWait = remoteWait + 0.3
            if remoteWait >= 5 then
                warn("[KillEnemy] Remote chưa sẵn sàng sau 5s → bỏ qua mob")
                return
            end
        end

        -- ③ Bật attack & setup
        EnableFastAttack()
        EquipWeapon("Melee")
        AutoHaki()

        -- ④ Vòng lặp farm: bám mob, bring cùng loại, giữ attack
        repeat
            task.wait()
            if not enemy or not enemy.Parent then break end
            if not enemy:FindFirstChild("Humanoid") or enemy.Humanoid.Health <= 0 then break end
            if not enemy:FindFirstChild("HumanoidRootPart") then break end

            local currentPos   = enemy.HumanoidRootPart.Position
            local followCFrame = CFrame.new(currentPos) * CFrame.new(0, 20, 0)

            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                Player.Character.HumanoidRootPart.CFrame = followCFrame
            end

            EquipWeapon("Melee")
            AutoHaki()
            BringEnemy(currentPos, targetNames)

        until not enemy or not enemy.Parent or enemy.Humanoid.Health <= 0
    end)

    -- Cleanup bắt buộc dù pcall lỗi hay không
    DisableFastAttack()

    -- Chờ mob despawn hoàn toàn trước khi cho phép chuyển target mới
    local t0 = tick()
    repeat task.wait(0.05)
    until tick() - t0 >= 0.8 or not enemy or not enemy.Parent

    _G.CurrentTarget = nil
end


-- =====================================================
--  AUTO STATS
-- =====================================================

local function AutoStats()
    pcall(function()
        local stats = {}
        for _, stat in pairs(Player.Data.Stats:GetChildren()) do
            if stat and stat:FindFirstChild("Level") then
                stats[stat.Name] = stat.Level.Value
            end
        end

        local currentLevel = Player.Data.Level.Value
        local target

        if (stats.Defense or 0) < MaxLevel and (
            (stats.Defense or 0) < (currentLevel / 80)
            or MaxLevel - (stats.Melee or 0) < 100
        ) then
            target = "Defense"
        elseif (stats.Melee or 0) < MaxLevel then
            target = "Melee"
        else
            target = "Sword"
        end

        ReplicatedStorage.Remotes.CommF_:InvokeServer("AddPoint", target, 999)
        SetTask("SubTask", string.format(
            "[AutoStats] Lv%d | DEF:%d | MELEE:%d | SWORD:%d → +%s",
            currentLevel,
            stats.Defense or 0,
            stats.Melee   or 0,
            stats.Sword   or 0,
            target
        ))
    end)
end


-- =====================================================
--  REDEEM CODES (X2 EXP)
--  Chỉ chạy khi: level < MaxLevel, ExpBoost == 0,
--                và chưa hết code
-- =====================================================

local REDEEM_CODES = {
    'BANEXPLOIT', 'NOMOREHACKS', "WildDares", 'BossBuild', 'GetPranked',
    'EARN_FRUITS', "Sub2UncleKizaru", 'FIGHT4FRUIT', "kittgaming",
    'TRIPLEABUSE', "Sub2CaptainMaui", 'Sub2Fer999', "Enyu_is_Pro",
    "Magicbus", "JCWK", 'Starcodeheo', 'Bluxxy', 'SUB2GAMERROBOT_EXP1',
    'Sub2NoobMaster123', 'Sub2Daigrock', "Axiore", "TantaiGaming",
    'StrawHatMaine', 'Sub2OfficialNoobie', "TheGreatAce", "SEATROLLIN",
    "24NOADMIN", 'ADMIN_TROLL', 'NEWTROLL', 'SECRET_ADMIN', "staffbattle",
    "NOEXPLOIT", "NOOB2ADMIN", "CODESLIDE", "fruitconcepts"
}

local function GetExpBoost()
    -- Đọc ExpBoost từ server data qua GuideModule
    local ok, boost = pcall(function()
        return getsenv(ReplicatedStorage.GuideModule)._G.ServerData.ExpBoost
    end)
    return ok and boost or 0
end

local function ShouldRedeem()
    local ok, level = pcall(function() return Player.Data.Level.Value end)
    if not ok or not level then return false end
    if level >= MaxLevel then return false end          -- Đã max level
    if GetExpBoost() ~= 0 then return false end        -- Đã có boost rồi
    if LocalStorage:Get("IsCodesRanOut") then return false end -- Đã thử hết code
    return true
end

local function RedeemCodes()
    if not ShouldRedeem() then return end

    SetTask("MainTask", "[RedeemCode] Đang redeem code X2 EXP...")

    for _, code in ipairs(REDEEM_CODES) do
        -- Kiểm tra lại mỗi vòng - nếu boost đã bật thì dừng
        if GetExpBoost() ~= 0 then
            SetTask("MainTask", "[RedeemCode] X2 EXP đã bật!")
            return
        end

        SetTask("MainTask", "[RedeemCode] Thử code: " .. code)

        local ok, result = pcall(function()
            return ReplicatedStorage.Remotes.Redeem:InvokeServer(code)
        end)

        task.wait(0.5)

        local resultText = (ok and result) or "Failed"
        SetTask("SubTask", "[RedeemCode] " .. code .. " → " .. tostring(resultText))

        -- Nếu code thành công kích hoạt X2 EXP
        if ok and result and type(result) == "string" and string.find(result, "SUCC") then
            SetTask("MainTask", "[RedeemCode] ✓ X2 Exp Boost đã được kích hoạt!")
            task.wait(1)
            return
        end
    end

    -- Đã thử hết tất cả code mà không có code nào kích hoạt boost
    SetTask("SubTask", "[RedeemCode] Đã thử hết code, không còn code nào hoạt động")
    LocalStorage:Set("IsCodesRanOut", true)
    LocalStorage:Save()
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
    -- Chỉ abandon "Bandit" đơn thuần (level thấp), KHÔNG abandon "Sky Bandit" hay các quest khác
    if ok_txt and type(qtext) == "string"
        and qtext:lower() == "bandit"
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
--  SKIP MODE
--  Floor 1: Shanda      (level  9 – 70)
--  Floor 2: Royal Squad (level 71 – 150)
--  Portal chung: Sky Palace (requestEntrance)
-- =====================================================

local SKY_PALACE_PORTAL = Vector3.new(-7894.6176757813, 5547.1416015625, -380.29119873047)

local SKIP_DATA = {
    -- Floor 1: Shanda  (level 9 → 70)
    [1] = {
        label     = "Shanda",
        mobs      = {"Shanda"},
        minLevel  = 9,
        maxLevel  = 70,
        spawnPos  = CFrame.new(-7757, 5562, -481),
        attackPos = CFrame.new(-7757, 5582, -481),
    },
    -- Floor 2: Royal Squad  (level 71 → 150)
    [2] = {
        label     = "Royal Squad",
        mobs      = {"Royal Squad"},
        minLevel  = 71,
        maxLevel  = 150,
        spawnPos  = CFrame.new(-7757, 5562, -481),
        attackPos = CFrame.new(-7757, 5582, -481),
    },
}

-- Các mốc level phải lên Sky Palace để nhận quest và farm
local function NeedsSkyPalace(level)
    return (level >= 475 and level <= 524)
        or (level >= 525 and level <= 549)
        or (level >= 550 and level <= 624)
end

-- Trả về floor index phù hợp với level hiện tại, hoặc nil nếu không áp dụng
local function GetSkipFloor(level)
    for floor, data in pairs(SKIP_DATA) do
        if level >= data.minLevel and level <= data.maxLevel then
            return floor
        end
    end
    return nil
end

local function SkipModeFarm(level)
    local floor = GetSkipFloor(level)
    if not floor then return false end

    local data = SKIP_DATA[floor]
    SetTask("MainTask", string.format(
        "[SkipMode] Floor %d | Lv%d | %s (Lv%d–%d)",
        floor, level, data.label, data.minLevel, data.maxLevel
    ))

    -- Vào Sky Palace nếu chưa ở đúng vùng
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local distToZone = (data.spawnPos.Position - Player.Character.HumanoidRootPart.Position).Magnitude
        if distToZone > 3000 then
            SetTask("SubTask", "[SkipMode] Vào portal → Sky Palace...")
            ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", SKY_PALACE_PORTAL)
            task.wait(2)
        end
    end

    local enemy = GetConnectionEnemies(data.mobs)
    if enemy then
        SetTask("SubTask", "[SkipMode] Tìm thấy " .. data.label .. " → tấn công")
        KillEnemy(enemy)
    else
        SetTask("SubTask", "[SkipMode] " .. data.label .. " chưa spawn → check RS + chờ...")
        local nextEnemy = WaitForMobSpawn(data.mobs, data.attackPos, 30)
        if nextEnemy then
            SetTask("SubTask", "[SkipMode] " .. data.label .. " đã spawn → tấn công")
            KillEnemy(nextEnemy)
        end
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
        task.wait(2)
        return
    end

    SetTask("MainTask", string.format("[AutoFarm] Lv%d | %s", level, NameMon))

    pcall(function()
        -- Abandon quest nếu sai mob
        local QuestTitle = Player.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text
        if QuestTitle and not string.find(QuestTitle, NameMon) then
            ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest")
        end

        local questVisible = Player.PlayerGui.Main.Quest.Visible

        if not questVisible then
            -- Chưa có quest → tween tới NPC
            SetTask("SubTask", string.format("[AutoFarm] Tween → NPC: %s", Qname))

            -- Teleport lên Sky Palace nếu cần
            if NeedsSkyPalace(level) then
                if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                    local distToSky = (Vector3.new(-7757, 5562, -481) - Player.Character.HumanoidRootPart.Position).Magnitude
                    if distToSky > 3000 then
                        SetTask("SubTask", "[AutoFarm] Teleport lên Sky Palace...")
                        ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", SKY_PALACE_PORTAL)
                        task.wait(2)
                    end
                end
            end

            topos(PosQ)
            WaitTween(12)

            -- Chỉ gọi remote khi đã đứng đủ gần NPC (≤ 5 studs)
            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (Player.Character.HumanoidRootPart.Position - PosQ.Position).Magnitude
                if dist <= 5 then
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", Qname, Qdata)
                end
            end

        else
            -- Đã có quest → farm mob
            if Workspace.Enemies:FindFirstChild(Mon) then
                local title = Player.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text
                if not string.find(title, NameMon) then
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest")
                    return
                end

                SetTask("SubTask", string.format("[AutoFarm] Farm: %s", NameMon))
                DisableFastAttack()
                EnableFastAttack()

                -- Duyệt TẤT CẢ mob cùng loại, không break sau 1 con
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

                            EquipWeapon("Melee")
                            AutoHaki()

                            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                Player.Character.HumanoidRootPart.CFrame =
                                    v.HumanoidRootPart.CFrame * CFrame.new(0, 20, 0)
                            end

                            BringEnemy(v.HumanoidRootPart.Position, {Mon})

                        until not v or not v.Parent
                            or v.Humanoid.Health <= 0
                            or not Player.PlayerGui.Main.Quest.Visible

                        _G.CurrentTarget = nil

                        -- Chờ mob despawn
                        local t0 = tick()
                        repeat task.wait(0.05)
                        until tick() - t0 >= 0.8 or not v or not v.Parent
                    end
                end

                DisableFastAttack()
            else
                -- Mob chưa spawn → tween về PosM chờ
                SetTask("SubTask", "[AutoFarm] Hết mob → chờ respawn...")
                topos(PosM)
                WaitTween(12)

                -- Check RS spawn
                local nextEnemy = WaitForMobSpawn({Mon, NameMon}, PosM, 30)
                if nextEnemy then task.wait(0.1) end
            end
        end
    end)
end


-- =====================================================
--  GET SABER (kích hoạt khi đạt level 300)
-- =====================================================

-- Check item trong inventory server (sword, gun, fruit, material...)
local function CheckItem(itemName)
    local ok, result = pcall(function()
        local inventory = ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")
        for _, v in pairs(inventory) do
            if v.Name == itemName then return v end
        end
        return nil
    end)
    return ok and result or nil
end

-- Check item trong backpack/character (Torch, Cup, tool cầm tay...)
local function CheckBackpack(itemName)
    for _, v in next, Player.Backpack:GetChildren() do
        if v:IsA("Tool") and (
            tostring(v) == itemName or
            v.Name == itemName or
            string.find(v.Name, itemName)
        ) then
            return v
        end
    end
    if Player.Character then
        for _, v in next, Player.Character:GetChildren() do
            if v:IsA("Tool") and (
                tostring(v) == itemName or
                v.Name == itemName or
                string.find(v.Name, itemName)
            ) then
                return v
            end
        end
    end
    return nil
end

local function IsAlive(v)
    return v and v.Parent
        and v:FindFirstChild("Humanoid")
        and v.Humanoid.Health > 0
        and v:FindFirstChild("HumanoidRootPart")
end

-- Tìm mob theo tên trong Workspace.Enemies
local function GetMobByName(target)
    local name = typeof(target) == "Instance" and target.Name or target
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if v.Name == name and IsAlive(v) then
            return v
        end
    end
    return nil
end

-- Kill mob theo tên, follow real-time + bring
local function KillMobByName(target)
    local v = GetMobByName(target)
    if not v or not IsAlive(v) then return end

    DisableFastAttack()
    EnableFastAttack()
    _G.CurrentTarget = v

    repeat
        task.wait()
        if not IsAlive(v) then break end

        EquipWeapon("Melee")
        AutoHaki()

        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            Player.Character.HumanoidRootPart.CFrame =
                v.HumanoidRootPart.CFrame * CFrame.new(0, 20, 0)
        end

        BringEnemy(v.HumanoidRootPart.Position, {v.Name})

    until not IsAlive(v)

    DisableFastAttack()
    _G.CurrentTarget = nil
    task.wait(0.5)
end

local function HopServers()
    SetTask("SubTask", "[Saber] Hop server sau 5 giây...")
    task.wait(5)
    pcall(function()
        local servers = {}
        local req = game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId ..
            "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
        )
        local body = game:GetService("HttpService"):JSONDecode(req)
        if body and body.data then
            for _, v in next, body.data do
                if type(v) == "table"
                    and tonumber(v.playing) and tonumber(v.maxPlayers)
                    and v.playing < v.maxPlayers
                    and v.id ~= game.JobId
                    and v.playing >= 10
                then
                    table.insert(servers, v.id)
                end
            end
        end
        if #servers > 0 then
            for _ = 1, 36 do
                game:GetService("TeleportService"):TeleportToPlaceInstance(
                    game.PlaceId,
                    servers[math.random(1, #servers)],
                    Player
                )
                task.wait(0.1)
            end
        end
    end)
end

local _saberDone = false

local function GetSaber()
    if _saberDone then return true end
    if CheckItem("Saber") then _saberDone = true; return true end  -- Saber là sword → check inventory

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
                    if not CheckBackpack("Torch") then  -- Torch là tool cầm tay
                        SetTask("SubTask", "[Saber] Lấy Torch...")
                        firetouchinterest(Workspace.Map.Jungle.Torch, Player.Character.HumanoidRootPart, 0)
                        firetouchinterest(Workspace.Map.Jungle.Torch, Player.Character.HumanoidRootPart, 1)
                    else
                        SetTask("SubTask", "[Saber] Thắp lửa Desert...")
                        EquipWeapon("Torch")
                        task.wait(0.2)
                        firetouchinterest(Player.Character.Torch.Handle, Workspace.Map.Desert.Burn.Fire, 0)
                        firetouchinterest(Player.Character.Torch.Handle, Workspace.Map.Desert.Burn.Fire, 1)
                    end
                else
                    local Progress = ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")

                    if Progress ~= 0 and Progress ~= 1 then
                        if not CheckBackpack("Cup") then  -- Cup là tool cầm tay
                            SetTask("SubTask", "[Saber] Lấy Cup...")
                            firetouchinterest(Workspace.Map.Desert.Cup, Player.Character.HumanoidRootPart, 0)
                            firetouchinterest(Workspace.Map.Desert.Cup, Player.Character.HumanoidRootPart, 1)
                        else
                            SetTask("SubTask", "[Saber] Dùng Cup...")
                            EquipWeapon("Cup")
                            task.wait(0.1)
                            ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "FillCup",
                                Player.Character:FindFirstChild("Cup"))
                            ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "SickMan")
                        end

                    elseif Progress == 0 then
                        SetTask("SubTask", "[Saber] Giết Mob Leader...")
                        KillMobByName("Mob Leader")

                    elseif Progress == 1 then
                        if not CheckBackpack("Relic") then  -- Relic là tool cầm tay
                            SetTask("SubTask", "[Saber] Lấy Relic...")
                            ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")
                        else
                            SetTask("SubTask", "[Saber] Dùng Relic mở cửa Jungle...")
                            EquipWeapon("Relic")
                            task.wait(0.1)
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

    if CheckItem("Saber") then
        _saberDone = true
        SetTask("MainTask", "[Saber] ✓ Đã lấy được Saber!")
        return true
    end
    return false
end




local function StoreFruitInBackpack()
    for _, e in pairs(Player.Backpack:GetChildren()) do
        local eatRemote = e:FindFirstChild("EatRemote", true)
        if eatRemote then
            local origName = e:GetAttribute("OriginalName")
            if origName then
                pcall(function()
                    ReplicatedStorage.Remotes.CommF_:InvokeServer(
                        "StoreFruit",
                        origName,
                        Player.Backpack:FindFirstChild(e.Name)
                    )
                end)
            end
        end
    end
end

-- Check có fruit nào trên map không
local function HasFruitOnMap()
    for _, obj in pairs(Workspace:GetChildren()) do
        if string.find(obj.Name, "Fruit") then
            return true
        end
    end
    return false
end

-- Tween tới từng fruit trên map rồi store
local function TweenToFruits()
    for _, obj in pairs(Workspace:GetChildren()) do
        if string.find(obj.Name, "Fruit") then
            pcall(function()
                topos(obj.Handle.CFrame)
                WaitTween(10)
                task.wait(0.3)
                StoreFruitInBackpack()
            end)
        end
    end
end


-- =====================================================
--  AUTO FULLY MELEE (ported from AryaMain)
--  Tự động mua và farm mastery tất cả melee theo thứ tự
-- =====================================================

-- Danh sách melee theo thứ tự, kèm thông tin NPC, giá, mastery yêu cầu
local MeleesOrder = {
    { name = "Black Leg",       id = "BlackLeg",       npc = "Dark Step Teacher",      mastery = 400, price = {Beli = 150000} },
    { name = "Electro",         id = "Electro",         npc = "Mad Scientist",          mastery = 400, price = {Beli = 500000} },
    { name = "Fishman Karate",  id = "FishmanKarate",   npc = "Water Kung-fu Teacher", mastery = 400, price = {Beli = 750000} },
    { name = "Dragon Claw",     id = "DragonClaw",      npc = "Sabi",                  mastery = 400, price = {Fragments = 1500} },
    { name = "Superhuman",      id = "Superhuman",      npc = "Martial Arts Master",   mastery = 400, price = {Beli = 3000000} },
    { name = "Death Step",      id = "DeathStep",       npc = "Phoeyu, the Reformed",  mastery = 400, price = {Beli = 2500000, Fragments = 5000}, requireSea = 2 },
    { name = "Sharkman Karate", id = "SharkmanKarate",  npc = "Sharkman Teacher",      mastery = 400, price = {Beli = 2500000, Fragments = 5000}, requireSea = 2 },
    { name = "Electric Claw",   id = "ElectricClaw",    npc = "Previous Hero",         mastery = 400, price = {Beli = 2500000, Fragments = 5000}, requireSea = 3 },
    { name = "Dragon Talon",    id = "DragonTalon",     npc = "Uzoth",                 mastery = 400, price = {Beli = 2500000, Fragments = 5000}, requireSea = 3 },
    { name = "Godhuman",        id = "Godhuman",        npc = "Ancient Monk",          mastery = 350, price = {Beli = 5000000, Fragments = 5000},
        requireSea = 3,
        -- Cần Dragon Talon mastery >= 400 trước
        extraCheck = function()
            for _, tool in pairs(Player.Backpack:GetChildren()) do
                if tool.Name == "Dragon Talon" and tool:FindFirstChild("Level") then
                    return tool.Level.Value >= 400
                end
            end
            if Player.Character then
                for _, tool in pairs(Player.Character:GetChildren()) do
                    if tool:IsA("Tool") and tool.Name == "Dragon Talon" and tool:FindFirstChild("Level") then
                        return tool.Level.Value >= 400
                    end
                end
            end
            return false
        end
    },
}

-- Lấy CFrame của NPC từ workspace.NPCs hoặc ReplicatedStorage.NPCs
local function GetNPCCFrame(npcName)
    local function tryFind(parent)
        if not parent then return nil end
        local npc = parent:FindFirstChild(npcName)
        if npc then
            local ok, cf = pcall(function() return npc:GetPivot() end)
            return ok and cf or nil
        end
        return nil
    end
    return tryFind(workspace.NPCs) or tryFind(game.ReplicatedStorage.NPCs)
end

-- Đọc giá trị currency từ Player.Data
local function GetCurrency(currencyName)
    local ok, val = pcall(function()
        return Player.Data[currencyName].Value
    end)
    return (ok and val) or 0
end

-- Kiểm tra đủ tiền mua melee
local function CanAffordMelee(price)
    for currency, amount in pairs(price) do
        if GetCurrency(currency) < amount then
            return false, currency, amount
        end
    end
    return true
end

-- Lấy mastery hiện tại của melee từ backpack/character
-- Trả về số (mastery) nếu đang sở hữu, nil nếu chưa có
local function GetMeleeMastery(meleeName)
    for _, container in pairs({Player.Backpack, Player.Character}) do
        if container then
            for _, tool in pairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool.Name == meleeName then
                    if tool:FindFirstChild("Level") then
                        return tool.Level.Value
                    end
                    return 0 -- có tool nhưng không có Level
                end
            end
        end
    end
    return nil -- chưa sở hữu
end

-- Equip melee theo tên
local function EquipMelee(meleeName)
    pcall(function()
        local tool = Player.Backpack:FindFirstChild(meleeName)
        if tool then
            Player.Character.Humanoid:EquipTool(tool)
        end
    end)
end

-- Tween tới NPC và mua melee
-- Trả về true nếu mua thành công
local function BuyMeleeFromNPC(meleeData)
    local npcCFrame = GetNPCCFrame(meleeData.npc)
    if not npcCFrame then
        SetTask("SubTask", "[AutoMelee] ✗ Không tìm thấy NPC: " .. meleeData.npc)
        return false
    end

    SetTask("MainTask", "[AutoMelee] ► Mua " .. meleeData.name)
    SetTask("SubTask",  "[AutoMelee] Đang tween tới " .. meleeData.npc)

    -- Dừng fast attack trong khi di chuyển đến NPC
    DisableFastAttack()
    _G.CurrentTarget = nil

    -- Tween đến NPC (lặp cho đến khi đến nơi, tối đa 60s)
    local deadline = tick() + 60
    repeat
        topos(npcCFrame)
        WaitTween(15)
        task.wait(0.3)

        if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then
            break
        end
        local dist = (npcCFrame.Position - Player.Character.HumanoidRootPart.Position).Magnitude
        if dist <= 12 then break end
    until tick() > deadline

    task.wait(0.5) -- để server nhận biết vị trí

    -- Gọi remote mua melee
    SetTask("SubTask", "[AutoMelee] Đang mua " .. meleeData.name .. "...")

    local ok = pcall(function()
        if meleeData.id == "DragonClaw" then
            -- Dragon Claw cần 2 bước: check rồi buy
            ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "1")
            task.wait(0.5)
            ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "2")
        elseif meleeData.id == "Godhuman" then
            ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyGodhuman", true)
            task.wait(0.5)
            ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyGodhuman")
        else
            ReplicatedStorage.Remotes.CommF_:InvokeServer("Buy" .. meleeData.id)
        end
    end)

    task.wait(1.5) -- chờ server xác nhận và item vào backpack

    -- Kiểm tra đã có chưa
    if CheckBackpack(meleeData.name) then
        SetTask("SubTask", "[AutoMelee] ✓ Đã mua thành công: " .. meleeData.name)
        -- Equip ngay sau khi mua để bắt đầu farm mastery
        EquipMelee(meleeData.name)
        return true
    end

    SetTask("SubTask", "[AutoMelee] ✗ Mua thất bại: " .. meleeData.name .. " (kiểm tra lại tiền/điều kiện)")
    return false
end

-- Hàm chính Auto Fully Melee
-- Trả về:
--   "buying"  → đang tween & mua melee, skip farm tick này
--   "mastery" → đang farm mastery (farm bình thường nhưng equip melee đó)
--   false     → không có gì cần làm (all done hoặc chờ tiền)
local _meleeAllDone = false
local function AutoFullyMelee()
    if _meleeAllDone then return false end

    local allDone = true

    for _, meleeData in ipairs(MeleesOrder) do
        -- Bỏ qua nếu yêu cầu sea khác
        if meleeData.requireSea and meleeData.requireSea ~= World then
            -- Nếu sea yêu cầu cao hơn sea hiện tại, dừng luôn (chưa tới sea đó)
            if meleeData.requireSea > World then
                break
            end
            continue
        end

        -- Bỏ qua nếu có điều kiện phụ chưa đủ
        if meleeData.extraCheck and not meleeData.extraCheck() then
            allDone = false
            SetTask("SubTask", "[AutoMelee] Chờ điều kiện cho " .. meleeData.name)
            break
        end

        local mastery = GetMeleeMastery(meleeData.name)

        if mastery == nil then
            -- Chưa sở hữu melee này
            allDone = false
            local canBuy, missCurrency, missAmount = CanAffordMelee(meleeData.price)
            if canBuy then
                -- Đủ tiền → dừng farm, tween & mua
                BuyMeleeFromNPC(meleeData)
                return "buying"
            else
                -- Chưa đủ tiền → tiếp tục farm để kiếm tiền, thông báo
                local need = missAmount - GetCurrency(missCurrency)
                SetTask("SubTask", string.format(
                    "[AutoMelee] Chờ đủ %s cho %s (cần thêm %d)",
                    missCurrency, meleeData.name, need
                ))
                -- Không break, để farming xảy ra bình thường
                break
            end

        elseif mastery < meleeData.mastery then
            -- Có rồi nhưng mastery chưa đủ → equip và farm
            allDone = false
            SetTask("SubTask", string.format(
                "[AutoMelee] Farm mastery %s: %d / %d",
                meleeData.name, mastery, meleeData.mastery
            ))
            EquipMelee(meleeData.name)
            return "mastery" -- farming bình thường với melee này được equip

        end
        -- mastery >= yêu cầu → melee này xong, tiếp tục vòng lặp
    end

    if allDone then
        _meleeAllDone = true
        SetTask("SubTask", "[AutoMelee] ✓ Đã hoàn thành tất cả melee!")
    end

    return false
end


-- =====================================================
--  KHỞI ĐỘNG TỰ ĐỘNG
-- =====================================================

-- Chờ character load
repeat task.wait() until Player.Character
    and Player.Character:FindFirstChild("HumanoidRootPart")
    and Player:FindFirstChild("Data")

print("[Kaitun] ✓ Character & Data loaded → Khởi động tất cả hệ thống...")

-- Loop 1: Auto Farm Level — ưu tiên: Saber > AutoMelee(buy) > Fruit > Farm(+mastery)
task.spawn(function()
    while task.wait(0.1) do
        local ok, level = pcall(function() return Player.Data.Level.Value end)
        local currentLevel = ok and level or 0

        -- Ưu tiên 1: GetSaber khi đạt level 300
        if currentLevel >= 300 and not _saberDone then
            local saberOk, saberErr = pcall(GetSaber)
            if not saberOk then
                SetTask("SubTask", "[Saber] Lỗi: " .. tostring(saberErr))
                task.wait(2)
            end

        -- Ưu tiên 2: Auto Fully Melee
        --   "buying"  → dừng farm, đang tween/mua melee
        --   "mastery" → farming bình thường, melee đã được equip
        --   false     → không có gì cần làm với melee
        else
            local meleeOk, meleeState = pcall(AutoFullyMelee)
            if not meleeOk then meleeState = false end

            if meleeState == "buying" then
                -- Đang mua melee, bỏ qua farm tick này
                task.wait(0.5)

            -- Ưu tiên 3: Collect fruit (kể cả khi đang farm mastery)
            elseif HasFruitOnMap() then
                SetTask("SubTask", "[Fruit] Phát hiện fruit → dừng farm, đi collect...")
                DisableFastAttack()
                _G.CurrentTarget = nil
                TweenToFruits()
                SetTask("SubTask", "[Fruit] Đã collect xong → tiếp tục farm")

            -- Ưu tiên 4: Farm bình thường (bao gồm cả mastery farming)
            else
                local farmOk, farmErr = pcall(AutoFarmLevel)
                if not farmOk then
                    _G.CurrentTarget = nil
                    DisableFastAttack()
                    SetTask("SubTask", "[AutoFarm] Lỗi: " .. tostring(farmErr))
                    task.wait(2)
                end
            end
        end
    end
end)

-- Loop 2: Auto Stats (event-based)
task.spawn(function()
    repeat task.wait() until Player.Data:FindFirstChild("Points")

    -- Chạy ngay 1 lần
    AutoStats()

    -- Lắng nghe thay đổi Points
    Player.Data.Points.Changed:Connect(function(newVal)
        if newVal and newVal > 0 then
            AutoStats()
        end
    end)

    print("[Kaitun] ✓ AutoStats → Online")
end)

-- Loop 3: Auto Haki (giữ Buso luôn bật, check mỗi 5s)
task.spawn(function()
    while task.wait(5) do
        AutoHaki()
    end
end)

-- Loop 4: Redeem Code X2 EXP (thử 1 lần lúc đầu, sau đó check mỗi 60s)
task.spawn(function()
    task.wait(3)
    RedeemCodes()

    while task.wait(60) do
        if not LocalStorage:Get("IsCodesRanOut") and GetExpBoost() == 0 then
            RedeemCodes()
        end
    end
end)

-- Loop 5: Random Fruit (mua từ Cousin liên tục, không wait)
task.spawn(function()
    while true do
        pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer("Cousin", "Buy")
        end)
        task.wait(0.5) -- nhỏ nhất để tránh throttle server
    end
end)

-- Loop 6: Auto Store — lắng nghe ChildAdded backpack, store ngay khi có fruit
task.spawn(function()
    local function onItemAdded(item)
        task.wait(0.1) -- chờ item load xong attributes
        pcall(function()
            local eatRemote = item:FindFirstChild("EatRemote", true)
            if eatRemote then
                local origName = item:GetAttribute("OriginalName")
                if origName then
                    ReplicatedStorage.Remotes.CommF_:InvokeServer(
                        "StoreFruit",
                        origName,
                        Player.Backpack:FindFirstChild(item.Name)
                    )
                end
            end
        end)
    end

    -- Store tất cả fruit đang có trong backpack ngay khi script chạy
    pcall(StoreFruitInBackpack)

    -- Bắt event khi item mới vào backpack
    Player.Backpack.ChildAdded:Connect(onItemAdded)
end)
print("[Kaitun] BringMob =", _G.BringMob)
