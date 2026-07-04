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

-- =================================================================
-- HELPERS
-- =================================================================
local function enableNoclip(char)
    return RunService.Stepped:Connect(function()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function disableNoclip(char, conn)
    conn:Disconnect()
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
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
    print("[NoClip] Mati!")
    task.wait(0.3)

    -- Walk normal sampai bener-bener sampai
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
-- STEP 1: WALK KE KURSI + DUDUK (retry sampai berhasil)
-- =================================================================
local char = LocalPlayer.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local hrp = char and char:FindFirstChild("HumanoidRootPart")
if not hum or not hrp then return end

-- Pilih kursi terdekat
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
for attempt = 1, 5 do
    walkNoclip(closestSeat, 5)
    task.wait(0.3)
    duduk = tryDuduk()
    if duduk then break end
    print("[Office] Belum duduk, mundur dulu... attempt #" .. attempt)
    hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local backPos = hrp.Position + (hrp.Position - closestSeat).Unit * 5
        hum:MoveTo(backPos)
        task.wait(1.5)
    end
end

if not duduk then
    warn("[Office] Gagal duduk setelah 5 attempt!")
    return
end

task.wait(1)

-- =================================================================
-- STEP 2: AUTO JAWAB SOAL
-- =================================================================
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local WorkGui = playerGui:WaitForChild("WorkGui")
local stopMath = false

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

task.spawn(function()
    while not stopMath do
        task.wait(0.3)
        jawabSoal()
        task.wait(math.random(4, 12) / 10)
    end
    print("[Office] Math loop berhenti!")
end)

print("[Office] Auto jawab soal aktif!")

-- =================================================================
-- STEP 3: AUTO KE PRINTER + HOLD (noclip, matiin 5 studs sebelum)
-- =================================================================
RS.JobEvents.AssignPrintJob.OnClientEvent:Connect(function(printerName)
    print("[Office] Assigned ke printer: " .. printerName)

    -- Stop auto jawab soal
    stopMath = true
    print("[Office] Auto answer dimatiin!")

    local targetPos = Printers[printerName]
    if not targetPos then
        warn("[Office] Printer tidak dikenal: " .. printerName)
        return
    end

    -- Lompat dulu keluar kursi
    print("[Office] Jump keluar kursi...")
    jumpAndWait()

    -- Walk ke printer pakai noclip, matiin 5 studs sebelum sampai
    print("[Office] Jalan ke " .. printerName .. "...")
    local hrp2
    local dist
    for attempt = 1, 4 do
        walkNoclip(targetPos, 5)
        
        -- Pastikan sudah sampai baru hold
        hrp2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp2 then return end
        dist = (hrp2.Position - targetPos).Magnitude
        
        if dist <= 4 then
            break -- Berhasil sampai
        else
            warn("[Office] Nyangkut! Jarak: " .. math.floor(dist) .. ". Jump & retry " .. attempt .. "/4")
            jumpAndWait()
        end
    end

    if dist > 4 then
        warn("[Office] Gagal sampai ke printer setelah retry!")
        return
    end

    -- Hold
    task.wait(0.3)
    local prompt = Workspace.Computers[printerName].Part.ProximityPrompt
    print("[Office] Hold printer...")
    
    local cam = Workspace.CurrentCamera
    if cam and hrp2 then
        cam.CameraType = Enum.CameraType.Scriptable
        -- Set kamera dinamis: 10 stud di belakang player, naik 8 stud, menghadap targetPos (Printer)
        local back = hrp2.CFrame.LookVector * -10
        local camPos = hrp2.Position + back + Vector3.new(0, 8, 0)
        cam.CFrame = CFrame.new(camPos, targetPos)
    end
    task.wait(0.5)

    prompt:InputHoldBegin()
    task.wait(1.5)
    prompt:InputHoldEnd()
    
    if cam then cam.CameraType = Enum.CameraType.Custom end
    print("[Office] Selesai!")
end)

print("[Office] Auto Office dimulai!")
