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
    if ok_txt and type(qtext) == "string"
        and string.find(qtext:lower(), "bandit")
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

local function StartQuest(PosQ, Qname, Qdata)
    SetTask("SubTask", "[Quest] Tween → NPC | " .. Qname)
    topos(PosQ)
    WaitTween(12)

    -- Đảm bảo player đã đến gần NPC (trong vòng 15 studs) mới gọi remote
    local arrived = false
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local dist = (PosQ.Position - Player.Character.HumanoidRootPart.Position).Magnitude
        arrived = dist <= 15
    end

    if not arrived then
        -- Teleport thẳng nếu tween chưa đưa player đến đủ gần
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            Player.Character.HumanoidRootPart.CFrame = PosQ
        end
        task.wait(0.2)
    end

    -- Gọi remote 1 lần duy nhất
    pcall(function()
        ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", Qname, Qdata)
    end)
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
                for _, v in pairs(Workspace.Enemies:GetChildren()) do
                    if v.Name == Mon
                        and v:FindFirstChild("HumanoidRootPart")
                        and v:FindFirstChild("Humanoid")
                        and v.Humanoid.Health > 0
                    then
                        local title = Player.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text
                        if string.find(title, NameMon) then
                            SetTask("SubTask", string.format("[AutoFarm] Farm: %s", NameMon))

                            DisableFastAttack()
                            _G.CurrentTarget = v
                            EnableFastAttack()

                            repeat
                                task.wait()
                                if not v or not v.Parent then break end
                                if not v:FindFirstChild("Humanoid") or v.Humanoid.Health <= 0 then break end
                                if not Player.PlayerGui.Main.Quest.Visible then break end

                                EquipWeapon("Melee")
                                AutoHaki()

                                -- Follow mob real-time
                                if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                    Player.Character.HumanoidRootPart.CFrame =
                                        v.HumanoidRootPart.CFrame * CFrame.new(0, 20, 0)
                                end

                                BringEnemy(v.HumanoidRootPart.Position, {Mon})

                            until not v or not v.Parent
                                or v.Humanoid.Health <= 0
                                or not Player.PlayerGui.Main.Quest.Visible

                            DisableFastAttack()
                            _G.CurrentTarget = nil

                            local t0 = tick()
                            repeat task.wait(0.05)
                            until tick() - t0 >= 0.8 or not v or not v.Parent

                        else
                            ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest")
                        end
                        break
                    end
                end
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
--  FRUIT SYSTEM
-- =====================================================

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
--  KHỞI ĐỘNG TỰ ĐỘNG
-- =====================================================

-- Chờ character load
repeat task.wait() until Player.Character
    and Player.Character:FindFirstChild("HumanoidRootPart")
    and Player:FindFirstChild("Data")

print("[Kaitun] ✓ Character & Data loaded → Khởi động tất cả hệ thống...")

-- Loop 1: Auto Farm Level — dừng farm khi có fruit, tiếp tục khi hết
task.spawn(function()
    while task.wait(0.1) do
        -- Ưu tiên collect fruit trước khi farm
        if HasFruitOnMap() then
            SetTask("SubTask", "[Fruit] Phát hiện fruit trên map → dừng farm, đi collect...")
            DisableFastAttack()
            _G.CurrentTarget = nil
            TweenToFruits()
            SetTask("SubTask", "[Fruit] Đã collect xong → tiếp tục farm")
        else
            local ok, err = pcall(AutoFarmLevel)
            if not ok then
                _G.CurrentTarget = nil
                DisableFastAttack()
                SetTask("SubTask", "[AutoFarm] Lỗi: " .. tostring(err))
                task.wait(2)
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

-- Loop 5: Random Fruit (mua từ Cousin mỗi 5s)
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer("Cousin", "Buy")
        end)
    end
end)

print("[Kaitun] ✓ Tất cả hệ thống đã khởi động!")
print("[Kaitun] BringMob =", _G.BringMob)
