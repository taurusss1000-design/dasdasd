local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local PoliceModule = {}
local policeRunning = false

-- =================================================================
-- HELPERS (Diambil dari metode auto courier)
-- =================================================================

local function jumpAndWait()
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    task.wait(0.3)

    local t = tick()
    while tick() - t < 3 do
        local state = hum:GetState()
        if state ~= Enum.HumanoidStateType.Jumping
        and state ~= Enum.HumanoidStateType.Freefall then
            break
        end
        task.wait(0.1)
    end
    task.wait(0.2)
end

local function findVehicle()
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

local function rideVehicle()
    local motor = findVehicle()
    if not motor then return end
    local char      = LocalPlayer.Character
    local driveSeat = motor:FindFirstChild("DriveSeat", true)
    if driveSeat then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = driveSeat.CFrame end
        driveSeat:Sit(char:FindFirstChildOfClass("Humanoid"))
    end
    task.wait(0.5)
end

local function _tweenVehicle(vehicle, targetCFrame, speed)
    local mainPart = vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart")
    if not mainPart then return end
    
    local parts = {}
    local originalAnchored = {}
    local tempWelds = {}
    
    for _, part in ipairs(vehicle:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(parts, part)
            originalAnchored[part] = part.Anchored
        end
    end
    
    -- Anchor mainPart, unanchor sisanya dan pasang WeldConstraint sementara
    mainPart.Anchored = true
    for _, part in ipairs(parts) do
        if part ~= mainPart then
            part.Anchored = false
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = mainPart
            weld.Part1 = part
            weld.Parent = mainPart
            table.insert(tempWelds, weld)
        end
    end
    
    -- Kalkulasi durasi berdasarkan distance dan speed
    local distance = (mainPart.Position - targetCFrame.Position).Magnitude
    local duration = distance / speed
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(mainPart, tweenInfo, { CFrame = targetCFrame })
    tween:Play()
    tween.Completed:Wait()
    
    -- Hapus weld sementara
    for _, weld in ipairs(tempWelds) do
        weld:Destroy()
    end
    
    -- Kembalikan state awal dan amankan physics
    for _, part in ipairs(parts) do 
        pcall(function()
            part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
        part.Anchored = originalAnchored[part] or false
    end
end

-- =================================================================
-- HELPERS: MISSION HANDLERS
-- =================================================================

-- Cari VehicleObject di ActiveMissions untuk tau posisi & ukuran objek
local function findVehicleObject()
    local activeMissions = Workspace:FindFirstChild("ActiveMissions")
    if not activeMissions then return nil end
    for _, child in pairs(activeMissions:GetDescendants()) do
        if child:IsA("BasePart") and child.Name == "VehicleObject" then
            return child
        end
    end
    return nil
 end

-- Hitung posisi tween yang aman (offset dari VehicleObject biar ga nyangkut)
local function getSafeTweenPosition(missionLoc)
    local vehicleObj = findVehicleObject()
    if vehicleObj then
        local vSize = vehicleObj.Size
        -- Offset = setengah ukuran terbesar + 10 studs biar aman ga nyangkut
        local offset = math.max(vSize.X, vSize.Z) / 2 + 10
        -- Arah dari VehicleObject ke missionLoc, kalau sama arah default ke X+
        local dir = (missionLoc - vehicleObj.Position)
        if dir.Magnitude < 1 then
            dir = Vector3.new(1, 0, 0)
        else
            dir = Vector3.new(dir.X, 0, dir.Z).Unit
        end
        local safePos = vehicleObj.Position + dir * offset
        safePos = Vector3.new(safePos.X, missionLoc.Y, safePos.Z)
        print("[Police] VehicleObject ditemukan! Size: " .. tostring(vSize))
        print("[Police] Safe tween offset: " .. tostring(offset) .. " studs")
        return safePos
    else
        -- VehicleObject belum ada, offset 15 studs ke arah X+ sebagai fallback
        print("[Police] VehicleObject belum ditemukan, pakai offset default 15 studs")
        return missionLoc + Vector3.new(15, 0, 0)
    end
end

-- Handle job PenertibanParkir:
-- 1. Cari VehicleObject untuk tau posisi & ukuran
-- 2. Equip BukuTilang
-- 3. Walk orbit memutari objek sampai ProximityPrompt "Issue Traffic Ticket" muncul
-- 4. Hold prompt
-- 5. Unequip
local function handlePenertibanParkir()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then
        print("[Police][Parkir] Character/Humanoid tidak ditemukan!")
        return false
    end
    
    -- Cari VehicleObject
    local vehicleObj = findVehicleObject()
    if not vehicleObj then
        print("[Police][Parkir] VehicleObject tidak ditemukan! Coba tunggu spawn...")
        local waitVeh = tick()
        while not vehicleObj and tick() - waitVeh < 10 do
            task.wait(0.5)
            vehicleObj = findVehicleObject()
        end
    end
    
    if not vehicleObj then
        print("[Police][Parkir] VehicleObject tetap tidak ditemukan setelah 10 detik!")
        return false
    end
    
    local vehiclePos = vehicleObj.Position
    local vehicleSize = vehicleObj.Size
    -- Radius orbit: setengah ukuran terbesar + 7 studs (ga terlalu mepet, ga terlalu jauh)
    local radius = math.max(vehicleSize.X, vehicleSize.Z) / 2 + 7
    
    print("[Police][Parkir] VehicleObject pos: " .. tostring(vehiclePos))
    print("[Police][Parkir] VehicleObject size: " .. tostring(vehicleSize))
    print("[Police][Parkir] Orbit radius: " .. tostring(radius))
    
    -- Equip BukuTilang
    local backpack = LocalPlayer.Backpack
    local tool = backpack:FindFirstChild("BukuTilang")
    if not tool then
        tool = char:FindFirstChild("BukuTilang")
    end
    if tool then
        tool.Parent = char
        print("[Police][Parkir] BukuTilang equipped!")
    else
        print("[Police][Parkir] BukuTilang tidak ditemukan!")
        return false
    end
    
    task.wait(0.5)
    
    -- Walk orbit memutari objek, cari ProximityPrompt
    local found = false
    local NUM_POINTS = 16 -- 16 titik orbit (setiap 22.5 derajat)
    local MAX_LAPS = 3   -- max 3 putaran
    
    -- Helper: cek apakah prompt "Issue Traffic Ticket" ada dan dalam jangkauan
    local function checkForPrompt()
        local activeMissions = Workspace:FindFirstChild("ActiveMissions")
        if not activeMissions then return nil end
        for _, v in pairs(activeMissions:GetDescendants()) do
            if v:IsA("ProximityPrompt") and v.ActionText == "Issue Traffic Ticket" then
                local promptPart = v.Parent
                if promptPart and promptPart:IsA("BasePart") then
                    local dist = (hrp.Position - promptPart.Position).Magnitude
                    if dist <= v.MaxActivationDistance + 2 then
                        return v
                    end
                end
            end
        end
        return nil
    end
    
    print("[Police][Parkir] Mulai orbit memutari objek...")
    
    for lap = 1, MAX_LAPS do
        print("[Police][Parkir] Putaran " .. lap .. "/" .. MAX_LAPS)
        for i = 0, NUM_POINTS - 1 do
            if not policeRunning then return false end
            
            -- Cek prompt sebelum pindah
            local prompt = checkForPrompt()
            if prompt then
                print("[Police][Parkir] Prompt ditemukan! Berhenti dan hold...")
                humanoid:MoveTo(hrp.Position) -- stop jalan
                task.wait(0.3)
                
                if fireproximityprompt then
                    fireproximityprompt(prompt)
                else
                    prompt:InputHoldBegin()
                    task.wait(prompt.HoldDuration + 0.1)
                    prompt:InputHoldEnd()
                end
                task.wait(prompt.HoldDuration + 0.5)
                print("[Police][Parkir] Traffic Ticket issued!")
                found = true
                break
            end
            
            -- Hitung posisi orbit berikutnya
            local angle = (i / NUM_POINTS) * math.pi * 2
            local targetPos = Vector3.new(
                vehiclePos.X + math.cos(angle) * radius,
                hrp.Position.Y,
                vehiclePos.Z + math.sin(angle) * radius
            )
            
            humanoid:MoveTo(targetPos)
            
            -- Tunggu sampai dekat target, sambil terus cek prompt
            local moveStart = tick()
            repeat
                task.wait(0.25)
                if not policeRunning then return false end
                
                -- Cek prompt sambil jalan
                local promptWhileWalking = checkForPrompt()
                if promptWhileWalking then
                    print("[Police][Parkir] Prompt ditemukan sambil jalan! Berhenti dan hold...")
                    humanoid:MoveTo(hrp.Position)
                    task.wait(0.3)
                    
                    if fireproximityprompt then
                        fireproximityprompt(promptWhileWalking)
                    else
                        promptWhileWalking:InputHoldBegin()
                        task.wait(promptWhileWalking.HoldDuration + 0.1)
                        promptWhileWalking:InputHoldEnd()
                    end
                    task.wait(promptWhileWalking.HoldDuration + 0.5)
                    print("[Police][Parkir] Traffic Ticket issued!")
                    found = true
                    break
                end
            until (hrp.Position - targetPos).Magnitude <= 3 or (tick() - moveStart > 6)
            
            if found then break end
        end
        if found then break end
    end
    
    -- Unequip BukuTilang
    local freshChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = freshChar:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:UnequipTools()
        print("[Police][Parkir] BukuTilang unequipped!")
    end
    
    if found then
        print("[Police][Parkir] Job PenertibanParkir SELESAI!")
    else
        print("[Police][Parkir] Gagal menemukan prompt setelah " .. MAX_LAPS .. " putaran!")
    end
    
    return found
end

-- =================================================================
-- MAIN LOGIC
-- =================================================================

local missionData = nil
local policeEventConn = nil

function PoliceModule:Start()
    if policeRunning then return end
    policeRunning = true
    missionData = nil
    
    task.spawn(function()
        print("[Police] Mengambil Job Police...")
        local TeamChangeRequest = ReplicatedStorage:FindFirstChild("TeamChangeRequest", true)
        if TeamChangeRequest then
            TeamChangeRequest:FireServer("Police", 0, 0, 1428858969, "Detector")
        else
            pcall(function() ReplicatedStorage.JobEvents.TeamChangeRequest:FireServer("Police", 0, 0, 1428858969, "Detector") end)
        end

        task.wait(1.5)
        if not policeRunning then return end

        print("[Police] Spawn Kendaraan...")
        local SELECTED_CAR = (_G.SpawnCar and _G.SpawnCar.SelectedCar and _G.SpawnCar.SelectedCar ~= "Refresh dulu...") and _G.SpawnCar.SelectedCar or "Yamahax-MioSporty"
        
        pcall(function()
            ReplicatedStorage:WaitForChild("SpawnCarEvents"):WaitForChild("SpawnCar"):FireServer(SELECTED_CAR)
        end)

        task.wait(5)
        if not policeRunning then return end

        print("[Police] Naik Kendaraan...")
        rideVehicle()
        task.wait(1)
        if not policeRunning then return end

        local motor = findVehicle()
        if motor then
            print("[Police] Tweening ke lokasi start job dengan speed 100...")
            local tweenLoc = Vector3.new(2836.453857421875, 4.23581600189209, -830.5399169921875)
            _tweenVehicle(motor, CFrame.new(tweenLoc), 100)
        end

        task.wait(0.5)
        if not policeRunning then return end

        print("[Police] Turun dari kendaraan...")
        jumpAndWait()
        if not policeRunning then return end

        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if humanoid and hrp then
            local startJobLoc = Vector3.new(2839.519287109375, 4.23581600189209, -841.3355712890625)
            print("[Police] Berjalan ke start job prompt...")
            humanoid:MoveTo(startJobLoc)
            
            local t = tick()
            repeat
                task.wait(0.1)
                if not policeRunning then return end
            until (hrp.Position - startJobLoc).Magnitude <= 4 or (tick() - t > 8)
            
            task.wait(0.5)
            if not policeRunning then return end

            -- =========================================================
            -- LISTEN MISSION DULU sebelum hold start job
            -- =========================================================
            print("[Police] Listening PoliceEvent untuk mission data...")
            local PoliceEvent = ReplicatedStorage:WaitForChild("PoliceAssets"):WaitForChild("PoliceEvent")
            
            missionData = nil
            if policeEventConn then policeEventConn:Disconnect() end
            
            policeEventConn = PoliceEvent.OnClientEvent:Connect(function(eventType, data)
                if eventType == "CreateMission" and data and data.missionLocation then
                    missionData = {
                        missionType = tostring(data.missionType),
                        missionLocation = data.missionLocation,
                    }
                    print("[Police] Mission diterima! Type: " .. missionData.missionType)
                    print("[Police] Location: " .. tostring(missionData.missionLocation))
                end
            end)
            
            -- =========================================================
            -- HOLD START JOB
            -- =========================================================
            print("[Police] Hold start job prompt...")
            pcall(function()
                local prompt = Workspace:FindFirstChild("PoliceJob", true) and Workspace.PoliceJob.Start.ProximityPrompt
                if prompt then
                    if fireproximityprompt then
                        fireproximityprompt(prompt)
                    else
                        prompt:InputHoldBegin()
                        task.wait(prompt.HoldDuration + 0.1)
                        prompt:InputHoldEnd()
                    end
                else
                    print("[Police] Prompt start job tidak ditemukan!")
                end
            end)
            print("[Police] Police Duty started!")
            
            -- =========================================================
            -- TUNGGU MISSION DATA MASUK
            -- =========================================================
            print("[Police] Menunggu mission data dari server...")
            local waitStart = tick()
            while policeRunning and not missionData do
                task.wait(0.5)
                if tick() - waitStart > 30 then
                    print("[Police] Timeout menunggu mission data (30 detik)!")
                    break
                end
            end
            if not policeRunning then return end
            
            if not missionData then
                print("[Police] Gagal mendapatkan mission data!")
                return
            end
            
            -- =========================================================
            -- NAIK KENDARAAN LAGI & TWEEN KE LOKASI MISI
            -- =========================================================
            print("[Police] Mission Type: " .. missionData.missionType)
            print("[Police] Tween ke lokasi misi: " .. tostring(missionData.missionLocation))
            
            -- Spawn kendaraan lagi
            print("[Police] Spawn Kendaraan untuk ke lokasi misi...")
            pcall(function()
                ReplicatedStorage:WaitForChild("SpawnCarEvents"):WaitForChild("SpawnCar"):FireServer(SELECTED_CAR)
            end)
            task.wait(5)
            if not policeRunning then return end
            
            print("[Police] Naik Kendaraan...")
            rideVehicle()
            task.wait(1)
            if not policeRunning then return end
            
            local motor2 = findVehicle()
            if motor2 then
                local missionLoc = missionData.missionLocation
                -- Hitung posisi tween yang aman (offset dari VehicleObject)
                local safeLoc = getSafeTweenPosition(Vector3.new(missionLoc.X, missionLoc.Y, missionLoc.Z))
                print("[Police] Tweening ke lokasi AMAN (offset): " .. tostring(safeLoc))
                _tweenVehicle(motor2, CFrame.new(safeLoc), 100)
            end
            
            task.wait(0.5)
            if not policeRunning then return end
            
            -- Turun dari kendaraan
            print("[Police] Turun dari kendaraan...")
            jumpAndWait()
            if not policeRunning then return end
            
            print("[Police] Sampai di lokasi misi!")
            print("[Police] Mission Type: " .. missionData.missionType)
            
            -- Handle berdasarkan tipe misi
            if missionData.missionType == "PenertibanParkir" then
                print("[Police] === AUTO HANDLE: PenertibanParkir ===")
                handlePenertibanParkir()
            else
                -- InsidenMogok atau tipe lain → manual dulu
                print("[Police] >>> Tipe misi '" .. missionData.missionType .. "' belum di-automate <<<")
                print("[Police] >>> KERJAIN MISI MANUAL, script nunggu mission berikutnya... <<<")
            end
            
            -- =========================================================
            -- LOOP: Tunggu CreateMission berikutnya → spawn → tween
            -- =========================================================
            while policeRunning do
                -- Reset missionData, tunggu CreateMission baru
                missionData = nil
                print("[Police] Menunggu CreateMission berikutnya...")
                
                local waitStart2 = tick()
                while policeRunning and not missionData do
                    task.wait(0.5)
                    -- Timeout 10 menit (misi manual bisa lama)
                    if tick() - waitStart2 > 600 then
                        print("[Police] Timeout 10 menit menunggu mission baru!")
                        break
                    end
                end
                
                if not policeRunning then break end
                if not missionData then
                    print("[Police] Tidak ada mission baru, berhenti loop.")
                    break
                end
                
                print("[Police] Mission baru diterima! Type: " .. missionData.missionType)
                print("[Police] Location: " .. tostring(missionData.missionLocation))
                
                -- Spawn kendaraan
                print("[Police] Spawn Kendaraan untuk ke lokasi misi baru...")
                pcall(function()
                    ReplicatedStorage:WaitForChild("SpawnCarEvents"):WaitForChild("SpawnCar"):FireServer(SELECTED_CAR)
                end)
                task.wait(5)
                if not policeRunning then break end
                
                -- Naik kendaraan
                print("[Police] Naik Kendaraan...")
                rideVehicle()
                task.wait(1)
                if not policeRunning then break end
                
                -- Tween ke lokasi misi baru (dengan offset aman)
                local motorLoop = findVehicle()
                if motorLoop then
                    local loc = missionData.missionLocation
                    local safeLoc = getSafeTweenPosition(Vector3.new(loc.X, loc.Y, loc.Z))
                    print("[Police] Tweening ke lokasi AMAN (offset): " .. tostring(safeLoc))
                    _tweenVehicle(motorLoop, CFrame.new(safeLoc), 100)
                else
                    print("[Police] Kendaraan tidak ditemukan!")
                end
                
                task.wait(0.5)
                if not policeRunning then break end
                
                -- Turun dari kendaraan
                print("[Police] Turun dari kendaraan...")
                jumpAndWait()
                if not policeRunning then break end
                
                print("[Police] Sampai di lokasi misi baru!")
                print("[Police] Mission Type: " .. missionData.missionType)
                
                -- Handle berdasarkan tipe misi
                if missionData.missionType == "PenertibanParkir" then
                    print("[Police] === AUTO HANDLE: PenertibanParkir ===")
                    handlePenertibanParkir()
                else
                    print("[Police] >>> Tipe misi '" .. missionData.missionType .. "' belum di-automate <<<")
                    print("[Police] >>> KERJAIN MISI MANUAL, script nunggu mission berikutnya... <<<")
                end
            end
            
            print("[Police] Loop selesai.")
        end
    end)
end

function PoliceModule:Stop()
    policeRunning = false
    if policeEventConn then
        policeEventConn:Disconnect()
        policeEventConn = nil
    end
    print("[Police] Auto Police Dihentikan!")
end

return PoliceModule

