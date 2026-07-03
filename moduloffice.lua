local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

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

local function walkNoclip(targetPos, stopRadius)
    stopRadius = stopRadius or 5
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    -- Aktifin noclip
    local noclipConn
    noclipConn = RunService.Stepped:Connect(function()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)

    hum:MoveTo(targetPos)

    -- Monitor jarak
    repeat
        task.wait(0.1)
        hrp = char:FindFirstChild("HumanoidRootPart")
    until not hrp or (hrp.Position - targetPos).Magnitude <= stopRadius

    -- Matiin noclip
    noclipConn:Disconnect()
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    print("[NoClip] Mati!")
    task.wait(0.3)

    -- Lanjut walk normal sampai bener-bener sampai
    hrp = char:FindFirstChild("HumanoidRootPart")
    for attempt = 1, 10 do
        if not hrp then break end
        local dist = (hrp.Position - targetPos).Magnitude
        if dist <= 3 then
            print("[Walk] Sampai! dist: " .. math.floor(dist))
            break
        end
        print("[Walk] attempt #" .. attempt .. " | dist: " .. math.floor(dist))
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

-- =================================================================
-- STEP 1: WALK KE KURSI + DUDUK
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

print("[Office] Jalan ke kursi...")
walkNoclip(closestSeat, 5)
task.wait(0.3)

-- Duduk
local seat = nil
for _, obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
    if obj:IsA("Seat") and (obj.Position - closestSeat).Magnitude < 2 then
        seat = obj
        break
    end
end

if seat then
    seat:Sit(hum)
    print("[Office] Duduk!")
else
    warn("[Office] Kursi tidak ditemukan!")
    return
end

task.wait(1)

-- =================================================================
-- STEP 2: AUTO JAWAB SOAL
-- =================================================================
local GenerateQuestion = RS.JobEvents.GenerateQuestion
local CorrectAnswer = RS.JobEvents.CorrectAnswer

local answerConn
answerConn = GenerateQuestion.OnClientEvent:Connect(function(question, choices, questionId)
    print("[Office] Soal: " .. question)

    local a, op, b = question:match("(%d+) ([%+%-%*%/]) (%d+)")
    a, b = tonumber(a), tonumber(b)

    local answer
    if op == "+" then answer = a + b
    elseif op == "-" then answer = a - b
    elseif op == "*" then answer = a * b
    elseif op == "/" then answer = a / b
    end

    local answerId
    for _, choice in ipairs(choices) do
        if tonumber(choice.Text) == answer then
            answerId = choice.ID
            break
        end
    end

    task.wait(math.random(2, 6))

    if answerId then
        CorrectAnswer:FireServer(answerId, questionId)
        print("[Office] Jawaban terkirim! " .. question .. " = " .. answer)
    else
        warn("[Office] Jawaban tidak ditemukan!")
    end
end)

-- =================================================================
-- STEP 3: AUTO KE PRINTER + HOLD
-- =================================================================
RS.JobEvents.AssignPrintJob.OnClientEvent:Connect(function(printerName)
    print("[Office] Assigned ke: " .. printerName)

    -- Stop jawab soal dulu
    answerConn:Disconnect()
    print("[Office] Auto answer dimatiin!")

    local targetPos = Printers[printerName]
    if not targetPos then warn("[Office] Printer tidak dikenal!") return end

    -- Lompat dulu keluar kursi
    print("[Office] Jump keluar kursi...")
    jumpAndWait()

    -- Walk ke printer pakai noclip, matiin 5 studs sebelum sampai
    print("[Office] Jalan ke " .. printerName)
    walkNoclip(targetPos, 5)

    -- Pastikan sudah sampai
    local hrp2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp2 then return end
    local dist = (hrp2.Position - targetPos).Magnitude
    if dist > 4 then
        warn("[Office] Gagal sampai ke printer, dist: " .. math.floor(dist))
        return
    end

    -- Hold
    task.wait(0.3)
    local prompt = game:GetService("Workspace").Computers[printerName].Part.ProximityPrompt
    print("[Office] Hold printer...")
    prompt:InputHoldBegin()
    task.wait(1.5)
    prompt:InputHoldEnd()
    print("[Office] Selesai!")
end)

print("[Office] Auto Office dimulai!")
