-- =============================================
-- AUTO JOB BARISTA MODULE v2
-- By King Vypers
-- Load via: loadstring(game:HttpGet("raw_url"))()
-- =============================================

local BaristaModule = {}

-- =================================================================
-- SERVICES
-- =================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local LocalPlayer       = Players.LocalPlayer
local Workspace         = game:GetService("Workspace")

-- =================================================================
-- SESSION ID
-- =================================================================
local currentSession = 0

local function newSession()
    currentSession = currentSession + 1
    return currentSession
end

local function isSessionAlive(sid)
    return sid == currentSession
end

-- =================================================================
-- STATE (exposed ke luar lewat BaristaModule)
-- =================================================================
BaristaModule.running          = false
BaristaModule.fixingMachine    = false
BaristaModule.machineNeedsRepair = false
BaristaModule.noclipEnabled    = false
BaristaModule.lastServeTime    = 0
BaristaModule.totalCycle       = 0
BaristaModule.startTime        = 0  -- tick() saat toggle dinyalakan

-- Config (bisa diubah dari luar sebelum start)
BaristaModule.timeoutEnabled   = false
BaristaModule.timeoutMax       = 90
BaristaModule.kickLimitEnabled = false
BaristaModule.kickLimitMinutes = 120

-- Webhook callback — di-set dari dds.lua setelah module di-load
-- Contoh: BaristaModule.onRepairEvent = sendWebhookRepairEvent
BaristaModule.onRepairEvent = nil

-- =================================================================
-- POSISI
-- =================================================================
local BREW_POS    = Vector3.new(-4998.09,     4.51,      -793.85)
local SERVE_POS   = Vector3.new(-4995.49,     4.28,      -761.86)
local MACHINE_POS = Vector3.new(-5113.675781, 3.189320,  -672.781311)
local JOB_POS     = { Name = "Barista", TeamId = 11378976, X = -4990.60, Y = 4.51, Z = -715.17 }
local JOB_VEC     = Vector3.new(JOB_POS.X, JOB_POS.Y, JOB_POS.Z)
local ARRIVE_DIST = 5

-- =================================================================
-- NOCLIP
-- =================================================================
RunService.Stepped:Connect(function()
    if BaristaModule.noclipEnabled then
        local char = LocalPlayer.Character
        if char then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide then
                    v.CanCollide = false
                end
            end
        end
    end
end)

-- =================================================================
-- INTERNAL HELPERS
-- =================================================================
local function unsit()
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    if hum.SeatPart then
        hum.Sit  = false
        task.wait(0.1)
        hum.Jump = true
        task.wait(0.1)
    end
end

local function walkFix(pos, sid)
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    if not hum then return false end
    hum:MoveTo(pos)
    local t = tick()
    while tick() - t < 30 do
        if sid and not isSessionAlive(sid) then return false end
        task.wait(0.1)
        if hum.SeatPart then unsit() task.wait(0.2) hum:MoveTo(pos) end
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - pos).Magnitude < ARRIVE_DIST then return true end
    end
    return false
end

local function waitArrived(pos, timeout, sid)
    timeout = timeout or 30
    local t = tick()
    while tick() - t < timeout do
        if sid and not isSessionAlive(sid) then return false end
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - pos).Magnitude < ARRIVE_DIST then return true end
        task.wait(0.2)
    end
    return false
end

local function isJobActive()
    local ok, result = pcall(function()
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
        local mui       = PlayerGui:FindFirstChild("BaristaMissionUI")
        if not (mui and mui.Enabled) then return false end
        local container = mui:FindFirstChild("Container")
        return container ~= nil and container.Visible
    end)
    return ok and result == true
end

local function rotateCamera()
    local camera = workspace.CurrentCamera
    for i = 0, 11 do
        pcall(function()
            camera.CFrame = CFrame.new(camera.CFrame.Position) * CFrame.Angles(0, math.rad(i * 30), 0)
        end)
        task.wait(0.12)
    end
end

local function getJobPrompt()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Name == "JobPrompt" then return v end
    end
end

local function findMyMotor()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closest, closestDist = nil, 50
    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and model:FindFirstChild("DriveSeat", true) then
            local mp = model.PrimaryPart
            if mp and (mp.Position - hrp.Position).Magnitude < closestDist then
                closestDist = (mp.Position - hrp.Position).Magnitude
                closest     = model
            end
        end
    end
    return closest
end

local function rideMotor()
    local motor = findMyMotor()
    if not motor then return end
    local char = LocalPlayer.Character
    if not char then return end
    local anims = motor:FindFirstChild("Anims")
    if anims then
        pcall(function() anims:FireServer("CreatePlayer",   char) end) task.wait(0.2)
        pcall(function() anims:FireServer("RegisterPlayer", char) end) task.wait(0.2)
    end
    local kickstand = motor:FindFirstChild("Kickstand")
    if kickstand then
        pcall(function() kickstand:FireServer("StandUp", 0, 0, 0, 0, false) end) task.wait(0.2)
    end
    local driveSeat = motor:FindFirstChild("DriveSeat", true)
    if driveSeat then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = driveSeat.CFrame end
        driveSeat:Sit(char:FindFirstChildOfClass("Humanoid"))
    end
end

local function exitMotor()
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    if not (char and hum) then return end
    hum.Sit  = false
    hum.Jump = true
    task.wait(0.1)
    if hum.SeatPart then
        char:PivotTo(char:GetPivot() * CFrame.new(0, 2, 0))
        hum.Sit  = false
        hum.Jump = true
    end
    task.wait(0.3)
end

-- =================================================================
-- FIX MACHINE
-- =================================================================
local function doFixMachine(sid)
    BaristaModule.fixingMachine   = true
    BaristaModule.noclipEnabled   = true

    -- Notif webhook: mesin rusak
    if BaristaModule.onRepairEvent then
        pcall(BaristaModule.onRepairEvent, "broken")
    end

    walkFix(MACHINE_POS, sid)
    if not isSessionAlive(sid) then
        BaristaModule.noclipEnabled = false
        BaristaModule.fixingMachine = false
        return
    end
    if not waitArrived(MACHINE_POS, 15, sid) then
        BaristaModule.noclipEnabled = false
        BaristaModule.fixingMachine = false
        return
    end

    task.wait(0.5)

    local supplyPrompt = nil
    pcall(function() supplyPrompt = Workspace.BaristaJob.Interactions.SupplyPart.SupplyPart.SupplyPrompt end)
    if not supplyPrompt then
        for _, v in pairs(Workspace:GetDescendants()) do
            if v.Name == "SupplyPrompt" and v:IsA("ProximityPrompt") then supplyPrompt = v break end
        end
    end

    if supplyPrompt then
        pcall(function()
            supplyPrompt:InputHoldBegin()
            task.wait(supplyPrompt.HoldDuration + 0.05)
            supplyPrompt:InputHoldEnd()
        end)
    end

    -- Tunggu konfirmasi label hilang (mesin selesai diperbaiki)
    local waitT     = tick() + 15
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    while tick() < waitT do
        if not isSessionAlive(sid) then break end
        local label = ""
        pcall(function() label = PlayerGui.BaristaMissionUI.Container.MainFrame.Frame.AdditionLabel.Text end)
        if label ~= "Machine needs maintenance" then break end
        task.wait(0.5)
    end

    if isSessionAlive(sid) then
        -- Notif webhook: mesin selesai diperbaiki
        if BaristaModule.onRepairEvent then
            pcall(BaristaModule.onRepairEvent, "fixed")
        end
        walkFix(BREW_POS, sid)
        task.wait(0.5)
    end

    BaristaModule.noclipEnabled      = false
    BaristaModule.machineNeedsRepair = false
    BaristaModule.fixingMachine      = false
end

-- =================================================================
-- BREW LOOP
-- =================================================================
local function doBrewLoop(sid)
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    BaristaModule.noclipEnabled = true

    walkFix(BREW_POS, sid)
    if not isSessionAlive(sid) then BaristaModule.noclipEnabled = false return end

    while BaristaModule.running and isSessionAlive(sid) and _G.KingVypersRunning do
        local char     = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not humanoid then task.wait(2) continue end

        -- Fix mesin prioritas
        if BaristaModule.machineNeedsRepair and not BaristaModule.fixingMachine then
            doFixMachine(sid)
            if not isSessionAlive(sid) then break end
            walkFix(BREW_POS, sid)
            task.wait(0.5)
            continue
        end
        if BaristaModule.fixingMachine then task.wait(0.5) continue end

        -- ============================================
        -- STEP 1: BREW
        -- ============================================
        local brewSuccess = false
        while not brewSuccess and BaristaModule.running and isSessionAlive(sid) and _G.KingVypersRunning do
            if BaristaModule.machineNeedsRepair then break end

            walkFix(BREW_POS, sid)
            if not isSessionAlive(sid) then break end
            if BaristaModule.machineNeedsRepair then break end

            local arrived = waitArrived(BREW_POS, 15, sid)
            if not isSessionAlive(sid) then break end
            if BaristaModule.machineNeedsRepair then break end
            if not arrived then task.wait(15) continue end

            task.wait(1)
            if not isSessionAlive(sid) then break end
            if BaristaModule.machineNeedsRepair then break end

            -- Tunggu MachinePrompt enabled (max 15 detik)
            local machinePrompt = nil
            local mpT = tick()
            while tick() - mpT < 15 and BaristaModule.running and isSessionAlive(sid) do
                if BaristaModule.machineNeedsRepair then break end
                pcall(function()
                    local mp = Workspace.BaristaJob.Interactions.MachinePart.MachinePart.MachinePrompt
                    if mp and mp.Enabled then machinePrompt = mp end
                end)
                if machinePrompt then break end
                task.wait(0.3)
            end
            if not isSessionAlive(sid) then break end
            if BaristaModule.machineNeedsRepair then break end
            if not machinePrompt then task.wait(15) continue end

            task.wait(1)
            if not isSessionAlive(sid) then break end

            -- Set camera supaya ProximityPrompt muncul (tidak terhalang)
            -- PENTING: jangan ubah CameraType ke Scriptable karena akan freeze karakter!
            -- Cukup override CFrame saja, kamera akan balik sendiri setelah sesaat
            local cam = Workspace.CurrentCamera
            if cam then
                cam.CFrame = CFrame.new(Vector3.new(-4998.32, 8.11, -805.22), Vector3.new(-4998.31, 7.90, -804.24))
            end
            task.wait(0.5)

            -- Hold MachinePrompt
            local holdOk = false
            pcall(function()
                machinePrompt:InputHoldBegin()
                task.wait(machinePrompt.HoldDuration + 0.1)
                machinePrompt:InputHoldEnd()
                holdOk = true
            end)
            if not isSessionAlive(sid) then break end
            if not holdOk then task.wait(15) continue end

            -- Tunggu minigame muncul (max 15 detik)
            local minigameFrame = nil
            local mgT = tick()
            while tick() - mgT < 15 and BaristaModule.running and isSessionAlive(sid) do
                local bGui = PlayerGui:FindFirstChild("BaristaGUI")
                local mf   = bGui and bGui:FindFirstChild("MinigameFrame")
                if mf and mf.Visible then minigameFrame = mf break end
                task.wait(0.2)
            end
            if not isSessionAlive(sid) then break end
            if not minigameFrame then task.wait(15) continue end

            -- Main minigame
            local bgBar        = minigameFrame:FindFirstChild("BackgroundBar")
            local tapZone      = minigameFrame:FindFirstChild("TapZone")
            local targetZone   = bgBar and bgBar:FindFirstChild("TargetZone")
            local playerCursor = bgBar and bgBar:FindFirstChild("PlayerCursor")

            local function tap()
                if not tapZone then return end
                local r = math.random(1, 2)
                if r == 1 then
                    pcall(function() firesignal(tapZone.MouseButton1Click) end)
                else
                    pcall(function() firesignal(tapZone.MouseButton1Down) end)
                    task.wait(math.random(3, 8) * 0.01)
                    pcall(function() firesignal(tapZone.MouseButton1Up) end)
                end
            end

            local lastTapTime = 0
            while minigameFrame.Visible and BaristaModule.running and isSessionAlive(sid) do
                task.wait(math.random(10, 20) * 0.001)
                if not (targetZone and playerCursor) then break end
                local targetTop = targetZone.AbsolutePosition.Y
                local targetBot = targetTop + targetZone.AbsoluteSize.Y
                local cursorMid = playerCursor.AbsolutePosition.Y + playerCursor.AbsoluteSize.Y / 2
                local now       = tick()
                if cursorMid > targetBot then
                    local interval = math.max(0.02, 0.08 - ((cursorMid - targetBot) / 500))
                    if now - lastTapTime >= interval then tap() lastTapTime = tick() end
                elseif cursorMid >= targetTop and cursorMid <= targetBot then
                    if math.random(1, 100) <= 30 then
                        local interval = math.random(60, 100) * 0.001
                        if now - lastTapTime >= interval then tap() lastTapTime = tick() end
                    end
                end
            end
            if not isSessionAlive(sid) then break end

            brewSuccess = true
        end

        if not isSessionAlive(sid) or not BaristaModule.running or not _G.KingVypersRunning then break end
        if not brewSuccess then continue end

        task.wait(math.random(8, 15) * 0.1)

        -- ============================================
        -- STEP 2: SERVE ORDER
        -- ============================================
        local serveSuccess = false
        while not serveSuccess and BaristaModule.running and isSessionAlive(sid) and _G.KingVypersRunning do
            walkFix(SERVE_POS, sid)
            if not isSessionAlive(sid) then break end

            local arrived = waitArrived(SERVE_POS, 15, sid)
            if not isSessionAlive(sid) then break end
            if not arrived then task.wait(15) continue end

            task.wait(1)
            if not isSessionAlive(sid) then break end

            local regPrompt = nil
            local rpT = tick()
            while tick() - rpT < 15 and BaristaModule.running and isSessionAlive(sid) do
                pcall(function()
                    local rp = Workspace.BaristaJob.Interactions.RegisterPart.RegisterPart.RegisterPrompt
                    if rp and rp.Enabled then regPrompt = rp end
                end)
                if regPrompt then break end
                task.wait(0.3)
            end
            if not isSessionAlive(sid) then break end
            if not regPrompt then task.wait(15) continue end

            local holdOk = false
            pcall(function()
                regPrompt:InputHoldBegin()
                task.wait(regPrompt.HoldDuration + 0.5)
                regPrompt:InputHoldEnd()
                holdOk = true
            end)
            if not isSessionAlive(sid) then break end
            if not holdOk then task.wait(15) continue end

            local confirmT = tick()
            while regPrompt.Enabled and tick() - confirmT < 15 do
                if not isSessionAlive(sid) then break end
                task.wait(0.2)
            end
            if not isSessionAlive(sid) then break end

            if not regPrompt.Enabled then
                serveSuccess                 = true
                BaristaModule.totalCycle     = BaristaModule.totalCycle + 1
                BaristaModule.lastServeTime  = tick()
                print("[Barista] ✅ Cycle #" .. BaristaModule.totalCycle .. " selesai!")
            else
                task.wait(15)
            end
        end

        if not isSessionAlive(sid) or not BaristaModule.running or not _G.KingVypersRunning then break end
        if not serveSuccess then continue end

        task.wait(math.random(5, 10) * 0.1)
        walkFix(BREW_POS, sid)
        task.wait(0.5)
    end

    BaristaModule.noclipEnabled = false
end

-- =================================================================
-- TRY START JOB
-- =================================================================
local function tryStartJob(sid)
    local JOB_START_WALK_POS = Vector3.new(-4991.52, 4.29, -714.94)

    while BaristaModule.running and isSessionAlive(sid) and _G.KingVypersRunning do
        if isJobActive() then return true end

        -- Coba set posisi kamera target sebelum jalan biar prompt langsung kebaca pas nongol
        pcall(function()
            local cam = workspace.CurrentCamera
            local camPos = Vector3.new(-5002.21, 12.17, -716.06)
            local camLook = Vector3.new(0.8552, -0.5104, 0.0894)
            cam.CFrame = CFrame.new(camPos, camPos + camLook)
        end)

        -- Mulai jalan
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:MoveTo(JOB_START_WALK_POS) end

        -- Jalan sambil cek prompt (selama jalan ke tujuan)
        local t = tick()
        local jobPrompt = nil
        local arrived = false

        while tick() - t < 15 and BaristaModule.running and isSessionAlive(sid) do
            if not isSessionAlive(sid) then return false end
            if hum and hum.SeatPart then unsit() task.wait(0.2) hum:MoveTo(JOB_START_WALK_POS) end
            
            jobPrompt = getJobPrompt()
            if jobPrompt and jobPrompt.Enabled then break end -- Kalo nemu prompt, hajar langsung!
            
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - JOB_START_WALK_POS).Magnitude < ARRIVE_DIST then 
                arrived = true 
                break 
            end
            task.wait(0.1)
        end

        if not isSessionAlive(sid) then return false end

        -- Kalo stuck dan gak nemu prompt sama sekali
        if not arrived and not jobPrompt then
            task.wait(5)
            continue
        end

        if not jobPrompt then jobPrompt = getJobPrompt() end

        -- Kalau masih belom nemu, rotate camera pelan-pelan buat nyari
        if not jobPrompt then
            rotateCamera()
            task.wait(0.3)
            
            local jpT       = tick()
            local camAngle  = 0
            while not jobPrompt and tick() - jpT < 15 and BaristaModule.running and isSessionAlive(sid) do
                jobPrompt = getJobPrompt()
                if not jobPrompt then
                    camAngle = camAngle + 30
                    pcall(function()
                        local cam = workspace.CurrentCamera
                        cam.CFrame = CFrame.new(cam.CFrame.Position) * CFrame.Angles(0, math.rad(camAngle), 0)
                    end)
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position - JOB_START_WALK_POS).Magnitude > ARRIVE_DIST then
                        if hum then hum:MoveTo(JOB_START_WALK_POS) end
                    end
                    task.wait(0.4)
                end
            end
        end

        if not isSessionAlive(sid) then return false end
        if not jobPrompt then task.wait(5) continue end

        -- Hold JobPrompt
        pcall(function()
            jobPrompt:InputHoldBegin()
            local holdDur = jobPrompt.HoldDuration
            local tHold   = tick()
            while tick() - tHold < holdDur + 0.1 do
                if not jobPrompt.Enabled then break end
                task.wait(0.05)
            end
            jobPrompt:InputHoldEnd()
        end)

        local confirmT  = tick()
        local confirmed = false
        while tick() - confirmT < 15 do
            if not isSessionAlive(sid) then return false end
            if isJobActive() then confirmed = true break end
            task.wait(0.5)
        end

        if confirmed then return true end
        task.wait(5)
    end
    return false
end

-- =================================================================
-- SETUP
-- =================================================================
local function doSetup()
    local sid = currentSession

    BaristaModule.machineNeedsRepair = false
    BaristaModule.fixingMachine      = false
    BaristaModule.noclipEnabled      = false
    BaristaModule.lastServeTime      = tick()

    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.RootPart then hum:MoveTo(hum.RootPart.Position) end
    task.wait(0.5)

    pcall(function()
        ReplicatedStorage:WaitForChild("JobEvents"):WaitForChild("TeamChangeRequest")
            :FireServer(JOB_POS.Name, JOB_POS.TeamId, 1, 0, "Detector")
    end)
    task.wait(1)
    if not isSessionAlive(sid) then return end

    pcall(function()
        local SpawnCar = _G.SpawnCar
        if SpawnCar and SpawnCar.SelectedCar and SpawnCar.SelectedCar ~= "Refresh dulu..." then
            ReplicatedStorage:WaitForChild("SpawnCarEvents"):WaitForChild("SpawnCar"):FireServer(SpawnCar.SelectedCar)
        else
            ReplicatedStorage:WaitForChild("SpawnCarEvents"):WaitForChild("SpawnCar"):FireServer("Motor1")
        end
    end)
    task.wait(4)
    if not isSessionAlive(sid) then return end

    rideMotor()
    task.wait(2)
    if not isSessionAlive(sid) then return end

    local hrp   = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local motor = findMyMotor()
    if not (motor and hrp) then BaristaModule.running = false return end

    pcall(function()
        local tPos = Vector3.new(-5005.13, 4.29, -716.64)
        motor:SetPrimaryPartCFrame(CFrame.new(tPos))
        task.wait(0.1)
        hrp.CFrame = CFrame.new(tPos.X, tPos.Y + 2, tPos.Z)
    end)
    task.wait(1)
    if not isSessionAlive(sid) then return end

    exitMotor()
    task.wait(1)
    if not isSessionAlive(sid) then return end

    local jobOk = tryStartJob(sid)
    if not jobOk or not isSessionAlive(sid) then BaristaModule.running = false return end

    task.wait(1)
    if not isSessionAlive(sid) then return end

    doBrewLoop(sid)
end

-- =================================================================
-- MONITOR (timeout + machine + kick limit)
-- =================================================================
task.spawn(function()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    while true do
        task.wait(1)

        if not BaristaModule.running then
            BaristaModule.lastServeTime = tick()
            continue
        end

        -- KICK LIMIT CHECK
        if BaristaModule.kickLimitEnabled and BaristaModule.startTime > 0 then
            local elapsed = tick() - BaristaModule.startTime
            if elapsed >= (BaristaModule.kickLimitMinutes * 60) then
                print("[Barista] ⏰ Kick limit tercapai! Kick sekarang...")
                if BaristaModule.onKickEvent then
                    pcall(BaristaModule.onKickEvent, "Sesi Barista mencapai limit (" .. BaristaModule.kickLimitMinutes .. " menit). Kick untuk safety!")
                end
                BaristaModule.running = false
                newSession()
                task.wait(2)
                LocalPlayer:Kick("[KingVypers] Auto Farm Limited - For your safety Rejoin")
                return
            end
        end

        -- TIMEOUT RESTART
        if BaristaModule.timeoutEnabled and (tick() - BaristaModule.lastServeTime > BaristaModule.timeoutMax) then
            print("[Barista] ⚠️ Timeout! Restart...")
            BaristaModule.running            = false
            BaristaModule.machineNeedsRepair = false
            BaristaModule.fixingMachine      = false
            BaristaModule.noclipEnabled      = false
            newSession()
            task.wait(5)
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum:MoveTo(hum.RootPart and hum.RootPart.Position or Vector3.zero) end
            task.wait(1)
            BaristaModule.running           = true
            BaristaModule.lastServeTime     = tick()
            task.spawn(doSetup)
            continue
        end

        if BaristaModule.fixingMachine then continue end

        -- MACHINE REPAIR CHECK
        local addLabel = ""
        pcall(function()
            addLabel = PlayerGui.BaristaMissionUI.Container.MainFrame.Frame.AdditionLabel.Text
        end)
        if addLabel == "Machine needs maintenance" and not BaristaModule.machineNeedsRepair then
            BaristaModule.machineNeedsRepair = true
            print("[Barista] 🔧 Mesin butuh perbaikan!")
        end

        if not BaristaModule.machineNeedsRepair then
            pcall(function()
                local sp = Workspace.BaristaJob.Interactions.SupplyPart.SupplyPart.SupplyPrompt
                if sp and sp.Enabled then BaristaModule.machineNeedsRepair = true end
            end)
        end
    end
end)

-- =================================================================
-- PUBLIC API
-- =================================================================

-- Mulai farming
function BaristaModule:Start()
    if self.running then
        print("[Barista] Sudah running!")
        return
    end
    self.running            = true
    self.machineNeedsRepair = false
    self.fixingMachine      = false
    self.startTime          = tick()
    newSession()
    print("[Barista] ▶ Start! Kick limit: " .. self.kickLimitMinutes .. " menit")
    task.spawn(doSetup)
end

-- Stop farming
function BaristaModule:Stop()
    self.running    = false
    self.startTime  = 0
    newSession()
    print("[Barista] ⏹ Stop!")
end

-- Cek apakah sedang running
function BaristaModule:IsRunning()
    return self.running
end

-- Set timeout
function BaristaModule:SetTimeout(seconds, enabled)
    self.timeoutMax     = seconds or 90
    self.timeoutEnabled = enabled ~= false
end

-- Set kick limit
function BaristaModule:SetKickLimit(minutes, enabled)
    self.kickLimitMinutes = minutes or 120
    self.kickLimitEnabled = enabled ~= false
end

print("[Barista Module] ✅ Loaded! Gunakan BaristaModule:Start() untuk mulai.")
return BaristaModule
