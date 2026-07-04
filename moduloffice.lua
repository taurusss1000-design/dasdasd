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
-- Acuan jarak: 1 stud
-- Kalau duduk kursi lain saat jalan -> jump doang, lanjut MoveTo
-- =================================================================
local function persistentWalkToPrinter(targetPos)
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end

    print("[Office] Walk ke printer dimulai...")

    local noclipConn = enableNoclip(char)
    local arrived    = false
    local timeout    = tick() + 60

    while not arrived and tick() < timeout do
        hrp = char:FindFirstChild("HumanoidRootPart")
        hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then break end

        -- Kalau nyangkut duduk kursi lain -> jump aja, cukup
        if hum.Sit then
            warn("[Office] Nyangkut duduk saat jalan! Jump...")
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(0.4)
        end

        local dist = (hrp.Position - targetPos).Magnitude
        if dist <= 2.5 then
            arrived = true
            print("[Office] Printer tercapai! dist: " .. string.format("%.2f", dist))
            break
        end

        hum:MoveTo(targetPos)
        task.wait(0.2)
    end

    disableNoclip(char, noclipConn)

    if not arrived then
        warn("[Office] Timeout walk ke printer!")
    end

    return arrived
end

-- =================================================================
-- HOLD PRINTER SAMPAI NOTIF 7 MUNCUL (berhasil)
-- Kalau belum muncul -> walk lagi + hold lagi
-- =================================================================
local function holdPrinterUntilSuccess(printerName, targetPos)
    local Notif = RS:WaitForChild("Notification"):WaitForChild("Notifications")

    while officeRunning do
        -- Walk ke printer sampai 1 stud
        local ok = persistentWalkToPrinter(targetPos)
        if not ok then
            warn("[Office] Gagal walk ke printer, retry...")
            task.wait(1)
            continue
        end

        task.wait(0.2)

        -- Set camera agar prompt aktif
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        if cam and hrp then
            cam.CameraType = Enum.CameraType.Scriptable
            local back = hrp.CFrame.LookVector * -10
            cam.CFrame = CFrame.new(hrp.Position + back + Vector3.new(0, 8, 0), targetPos)
        end
        task.wait(0.2)

        -- Tunggu prompt enabled
        local prompt = Workspace.Computers[printerName].Part.ProximityPrompt
        local waitT = tick()
        while not prompt.Enabled and tick() - waitT < 8 do
            task.wait(0.1)
        end

        if not prompt.Enabled then
            warn("[Office] Prompt belum aktif, retry walk...")
            if cam then cam.CameraType = Enum.CameraType.Custom end
            task.wait(0.5)
            continue
        end

        -- Listen notif 7 = print berhasil
        local printSuccess = false
        local notifConn
        notifConn = Notif.OnClientEvent:Connect(function(notifType, msg, id)
            if id == 7 then
                printSuccess = true
                print("[Office] Notif 7 diterima: " .. tostring(msg))
                notifConn:Disconnect()
            end
        end)

        -- Hold printer
        local holdDur = prompt.HoldDuration or 1.5
        print("[Office] Hold printer (" .. holdDur .. "s)...")
        prompt:InputHoldBegin()

        -- Tunggu selama hold berlangsung
        -- Kalau character duduk saat hold, jump aja
        local holdStart = tick()
        while tick() - holdStart < holdDur + 0.5 do
            local hChar = LocalPlayer.Character
            local hHum  = hChar and hChar:FindFirstChildOfClass("Humanoid")
            if hHum and hHum.Sit then
                hHum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            task.wait(0.1)
        end

        prompt:InputHoldEnd()

        -- Tunggu notif 7 max 3 detik setelah InputHoldEnd
        local waitNotif = tick()
        while not printSuccess and tick() - waitNotif < 3 do
            task.wait(0.1)
        end

        pcall(function() notifConn:Disconnect() end)

        if cam then cam.CameraType = Enum.CameraType.Custom end

        if printSuccess then
            print("[Office] Print berhasil! Lanjut loop...")
            return true
        else
            warn("[Office] Print belum berhasil (notif 7 tidak muncul), walk + hold ulang...")
            task.wait(0.5)
        end
    end

    return false
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

        local function findSeatObject()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Seat") and (obj.Position - closestSeat).Magnitude < 2 then
                    return obj
                end
            end
            return nil
        end

        -- Arah menjauh untuk retry duduk: kanan, kiri, depan, belakang
        local AwayDirs = {
            Vector3.new(10, 0, 0),
            Vector3.new(-10, 0, 0),
            Vector3.new(0, 0, 10),
            Vector3.new(0, 0, -10),
        }

        -- Walk ke titik target pakai noclip, tunggu sampai radius stud
        local function walkToPos(targetPos, radius)
            radius = radius or 1
            local conn = enableNoclip(char)
            local t = tick()
            while tick() - t < 15 do
                hrp = char:FindFirstChild("HumanoidRootPart")
                hum = char:FindFirstChildOfClass("Humanoid")
                if not hrp or not hum then break end
                if (hrp.Position - targetPos).Magnitude <= radius then break end
                hum:MoveTo(targetPos)
                task.wait(0.15)
            end
            disableNoclip(char, conn)
            task.wait(0.2)
        end

        -- Coba duduk. Kalau gagal (berdiri di atas kursi),
        -- walk menjauh 10 studs lalu balik lagi. Urutan: kanan -> kiri -> depan -> belakang
        local function trySitWithRetry(seatObj, seatPos)
            local dirIndex = 1

            for attempt = 1, 8 do
                if not officeRunning then break end

                print("[Office] Walk ke kursi attempt #" .. attempt .. "...")
                walkToPos(seatPos, 1)

                hrp = char:FindFirstChild("HumanoidRootPart")
                hum = char:FindFirstChildOfClass("Humanoid")
                if not hrp or not hum then break end

                -- Coba Sit() kalau sudah 1.5 stud
                if (hrp.Position - seatPos).Magnitude <= 1.5 then
                    pcall(function() seatObj:Sit(hum) end)
                    task.wait(0.3)
                end

                if hum.Sit then
                    print("[Office] Duduk berhasil! attempt #" .. attempt)
                    return true
                end

                -- Masih berdiri di atas kursi -> walk menjauh 10 studs
                local awayDir = AwayDirs[dirIndex]
                dirIndex = (dirIndex % #AwayDirs) + 1
                hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then break end
                warn("[Office] Gagal duduk, menjauh " .. tostring(awayDir) .. " attempt #" .. attempt)
                walkToPos(hrp.Position + awayDir, 1)
                task.wait(0.3)
            end

            return false
        end

        print("[Office] Jalan ke kursi...")
        local seatObj = findSeatObject()
        local duduk = false

        if seatObj then
            print("[Office] Kursi ditemukan, trySitWithRetry...")
            duduk = trySitWithRetry(seatObj, closestSeat)
        else
            warn("[Office] Seat object tidak ditemukan!")
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

        -- STEP 3: Jump keluar kursi
        print("[Office] Jump keluar kursi...")
        jumpAndWait()

        local hum2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum2 and hum2.Sit then
            hum2:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(0.5)
        end

        -- STEP 4: Walk + hold printer sampai notif 7 (berhasil)
        local targetPos = Printers[printerAssigned]
        if not targetPos then
            warn("[Office] Printer tidak dikenal: " .. tostring(printerAssigned))
            task.wait(2)
            continue
        end

        print("[Office] Menuju " .. printerAssigned .. "...")
        holdPrinterUntilSuccess(printerAssigned, targetPos)

        task.wait(1.5)
    end
end

task.spawn(startOffice)
print("[Office] Auto Office Loop dimulai! v7")
