local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- =================================================================
-- DATA
-- =================================================================
local SeatPositions = {
    Vector3.new(-5925.75, 2.71, -261.01),
    Vector3.new(-5946.30, 2.71, -260.95),
    Vector3.new(-5968.74, 2.71, -228.44),
    Vector3.new(-5880.50, 2.71, -261.01),
    Vector3.new(-5878.44, 2.71, -228.62),
    Vector3.new(-5967.17, 2.71, -260.84),
    Vector3.new(-5927.33, 2.71, -228.61),
    Vector3.new(-5947.88, 2.71, -228.55),
    Vector3.new(-5902.42, 2.71, -228.54),
}

local Printers = {
    ["Print_1"] = Vector3.new(-6008.84, 4.58, -210.84),
    ["Print_2"] = Vector3.new(-6008.84, 4.58, -224.52),
    ["Print_3"] = Vector3.new(-6008.84, 4.58, -238.36),
    ["Print_4"] = Vector3.new(-5868.43, 4.58, -213.19),
    ["Print_5"] = Vector3.new(-5868.43, 4.58, -249.96),
}

local officeRunning = true

local RetryOffsets = {
    Vector3.new(0, 0, 10),
    Vector3.new(10, 0, 0),
    Vector3.new(-10, 0, 0),
    Vector3.new(0, 0, -10),
}

-- =================================================================
-- HELPERS
-- =================================================================
local function enableNoclip(char)
    return RunService.Stepped:Connect(function()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

local function disableNoclip(char, conn)
    conn:Disconnect()
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = true end
    end
end

local function walkNoclip(targetPos, stopRadius)
    stopRadius = stopRadius or 5
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    local conn = enableNoclip(char)
    hum:MoveTo(targetPos)

    repeat
        task.wait(0.1)
        hrp = char:FindFirstChild("HumanoidRootPart")
    until not hrp or (hrp.Position - targetPos).Magnitude <= stopRadius

    disableNoclip(char, conn)
    task.wait(0.3)

    for attempt = 1, 10 do
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then break end
        local dist = (hrp.Position - targetPos).Magnitude
        if dist <= 3 then
            print("[Walk] Sampai! dist: " .. math.floor(dist))
            break
        end
        hum:MoveTo(targetPos)
        local t = tick()
        repeat
            task.wait(0.1)
            hrp = char:FindFirstChild("HumanoidRootPart")
        until not hrp
            or (hrp and (hrp.Position - targetPos).Magnitude <= 3)
            or (tick() - t >= 8)
    end
end

local function jumpAndWait()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    task.wait(0.3)
    local t = tick()
    while tick() - t < 3 do
        local state = hum:GetState()
        if state ~= Enum.HumanoidStateType.Jumping
        and state ~= Enum.HumanoidStateType.Freefall then break end
        task.wait(0.1)
    end
    task.wait(0.3)
end

-- =================================================================
-- PERSISTENT WALK KE PRINTER
-- Terus paksa MoveTo + noclip sampai beneran nyampe
-- Tidak bisa dihentikan oleh gerakan player
-- =================================================================
local function persistentWalkToPrinter(targetPos, arrivedRadius)
    arrivedRadius = arrivedRadius or 3.5
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end

    print("[Office] Persistent walk ke printer dimulai...")

    -- Noclip aktif selama perjalanan
    local noclipConn = enableNoclip(char)

    -- Loop paksa MoveTo terus setiap 0.2 detik
    -- Tidak peduli player gerak, script tetap paksa balik ke printer
    local arrived = false
    local timeout = tick() + 60  -- max 60 detik

    while not arrived and tick() < timeout do
        hrp = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then break end

        -- Kalau nyangkut duduk di kursi lain, langsung paksa berdiri + jump
        if hum.Sit then
            warn("[Office] Kena duduk kursi lain! Force stand up...")
            hum.Sit = false
            task.wait(0.1)
            -- Kalau masih duduk, jump paksa
            if hum.Sit then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                task.wait(0.3)
            end
            -- Angkat posisi karakter sedikit biar lepas dari seat
            if hrp then
                hrp.CFrame = hrp.CFrame * CFrame.new(0, 3, 0)
            end
            task.wait(0.3)
        end

        local dist = (hrp.Position - targetPos).Magnitude
        if dist <= arrivedRadius then
            arrived = true
            print("[Office] Printer tercapai! dist: " .. string.format("%.1f", dist))
            break
        end

        -- Paksa MoveTo setiap tick — ini yang bikin ga bisa distop player
        hum:MoveTo(targetPos)
        task.wait(0.2)
    end

    -- Matikan noclip setelah sampai
    disableNoclip(char, noclipConn)

    if not arrived then
        warn("[Office] Timeout! Gagal sampai ke printer dalam 60 detik.")
    end

    return arrived
end

-- =================================================================
-- MAIN LOOP
-- =================================================================
local function startOffice()
    while officeRunning do
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then task.wait(1) continue end

        -- STEP 1: Pilih kursi terdekat
        local closestSeat, closestDist = SeatPositions[1], math.huge
        for _, pos in ipairs(SeatPositions) do
            local dist = (hrp.Position - pos).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestSeat = pos
            end
        end

        local function tryDuduk()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Seat") and (obj.Position - closestSeat).Magnitude < 2 then
                    obj:Sit(hum)
                    task.wait(0.5)
                    if hum.Sit then
                        print("[Office] Duduk berhasil!")
                        return true
                    end
                end
            end
            return false
        end

        print("[Office] Jalan ke kursi...")
        local duduk = false
        for attempt = 1, 8 do
            if not officeRunning then break end
            walkNoclip(closestSeat, 5)
            task.wait(0.3)
            duduk = tryDuduk()
            if duduk then break end

            hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then break end
            local offset = RetryOffsets[((attempt - 1) % #RetryOffsets) + 1]
            local backPos = hrp.Position + offset
            print("[Office] Belum duduk, geser ke " .. tostring(offset) .. " attempt #" .. attempt)
            hum:MoveTo(backPos)
            task.wait(1.5)
        end

        if not duduk then
            warn("[Office] Gagal duduk, retry dari awal...")
            task.wait(2)
            continue
        end

        task.wait(1)

        -- STEP 2: Auto jawab soal
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        local WorkGui = playerGui:WaitForChild("WorkGui")
        local stopMath = false
        local printerAssigned = nil

        local function jawabSoal()
            local questionLabel = WorkGui:FindFirstChild("QuestionLabel")
            if not questionLabel or not questionLabel.Visible or questionLabel.Text == "" then return end
            local a, op, b = string.match(questionLabel.Text, "(%d+)%s*([%+%-%*/])%s*(%d+)")
            if not a then return end
            local n1, n2 = tonumber(a), tonumber(b)
            local jawaban
            if     op == "+" then jawaban = n1 + n2
            elseif op == "-" then jawaban = n1 - n2
            elseif op == "*" then jawaban = n1 * n2
            elseif op == "/" and n2 ~= 0 then jawaban = n1 / n2
            else return end
            print("[Office] Soal: " .. questionLabel.Text .. " = " .. jawaban)
            local frame = WorkGui:FindFirstChild("Frame")
            if not frame then return end
            for _, btn in pairs(frame:GetChildren()) do
                if btn:IsA("TextButton") and btn.Visible and tonumber(btn.Text) == jawaban then
                    task.wait(math.random(8, 25) / 10)
                    if stopMath then return end
                    firesignal(btn.MouseButton1Click)
                    print("[Office] Klik jawaban: " .. jawaban)
                    return
                end
            end
        end

        -- Hook printer event
        local printerConn
        printerConn = RS.JobEvents.AssignPrintJob.OnClientEvent:Connect(function(printerName)
            print("[Office] Assigned ke printer: " .. printerName)
            stopMath = true
            printerAssigned = printerName
            printerConn:Disconnect()
        end)

        -- Math loop
        task.spawn(function()
            while not stopMath do
                task.wait(0.3)
                jawabSoal()
                task.wait(math.random(4, 12) / 10)
            end
            print("[Office] Math loop berhenti!")
        end)

        print("[Office] Auto jawab soal aktif!")

        -- Tunggu sampai printer assigned
        repeat task.wait(0.5) until printerAssigned ~= nil or not officeRunning
        if not officeRunning then break end

        -- STEP 3: Ke printer + hold
        local targetPos = Printers[printerAssigned]
        if not targetPos then
            warn("[Office] Printer tidak dikenal!")
            task.wait(2)
            continue
        end

        print("[Office] Jump keluar kursi...")
        jumpAndWait()

        -- Pastikan karakter bener-bener udah turun dari kursi
        local hum2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum2 and hum2.Sit then
            hum2.Sit = false
            task.wait(0.5)
        end

        print("[Office] Persistent walk ke " .. printerAssigned .. "...")

        -- Ini yang fix: persistent loop, ga bisa dihentikan oleh player
        local berhasil = persistentWalkToPrinter(targetPos, 3.5)

        if not berhasil then
            warn("[Office] Gagal sampai ke printer, retry dari awal...")
            task.wait(2)
            continue
        end

        task.wait(0.3)

        -- Setup kamera agar prompt terjangkau
        local hrp2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        if cam and hrp2 then
            cam.CameraType = Enum.CameraType.Scriptable
            local back = hrp2.CFrame.LookVector * -10
            local camPos = hrp2.Position + back + Vector3.new(0, 8, 0)
            cam.CFrame = CFrame.new(camPos, targetPos)
        end
        task.wait(0.5)

        local prompt = Workspace.Computers[printerAssigned].Part.ProximityPrompt
        print("[Office] Hold printer...")
        prompt:InputHoldBegin()
        task.wait(1.5)
        prompt:InputHoldEnd()

        if cam then cam.CameraType = Enum.CameraType.Custom end
        print("[Office] Print selesai! Ngulang dari awal...")
        task.wait(2)
    end
end

task.spawn(startOffice)
print("[Office] Auto Office Loop dimulai! v2")
