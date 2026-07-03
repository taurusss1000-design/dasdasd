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

    local noclipConn
    noclipConn = RunService.Stepped:Connect(function()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)

    hum:MoveTo(targetPos)

    repeat
        task.wait(0.1)
        hrp = char:FindFirstChild("HumanoidRootPart")
    until not hrp or (hrp.Position - targetPos).Magnitude <= stopRadius

    noclipConn:Disconnect()
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    task.wait(0.3)

    -- Walk normal sampai sampai
    hrp = char:FindFirstChild("HumanoidRootPart")
    for attempt = 1, 10 do
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

-- =================================================================
-- STEP 1: WALK KE KURSI + DUDUK (retry sampai bener-bener duduk)
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
    local seat = nil
    for _, obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
        if obj:IsA("Seat") and (obj.Position - closestSeat).Magnitude < 2 then
            seat = obj
            break
        end
    end
    if seat then
        seat:Sit(hum)
        task.wait(0.5)
        -- Cek bener-bener duduk
        if hum.Sit then
            print("[Office] Duduk berhasil!")
            return true
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

    -- Belum duduk, menjauh dulu 5 studs lalu coba lagi
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
-- STEP 2: AUTO JAWAB SOAL TERUS SAMPAI DIARAHKAN KE PRINTER
-- =================================================================
local GenerateQuestion = RS.JobEvents.GenerateQuestion
local CorrectAnswer    = RS.JobEvents.CorrectAnswer

local answerConn
local successConn
local isAnswering = false

answerConn = GenerateQuestion.OnClientEvent:Connect(function(question, choices, questionId)
    if isAnswering then return end -- skip kalau lagi proses jawab
    isAnswering = true

    print("[Office] Soal masuk: " .. question)

    -- Hitung jawaban
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

    -- Tunggu random 2-6 detik biar kelihatan natural
    task.wait(math.random(2, 6))

    if not answerId then
        warn("[Office] Jawaban tidak ditemukan untuk soal: " .. question)
        isAnswering = false
        return
    end

    -- Kirim jawaban ke server
    CorrectAnswer:FireServer(answerId, questionId)
    print("[Office] Jawaban terkirim! " .. question .. " = " .. tostring(answer))

    -- Tunggu konfirmasi "success" dari server sebelum siap soal berikutnya
    if successConn then successConn:Disconnect() end
    successConn = CorrectAnswer.OnClientEvent:Connect(function(status)
        if status == "success" then
            successConn:Disconnect()
            successConn = nil
            print("[Office] Server konfirmasi: success! Siap soal berikutnya...")
            isAnswering = false -- server akan kirim soal berikutnya via GenerateQuestion
        end
    end)

    -- Safety timeout: kalau 15 detik server ga reply, reset juga
    task.spawn(function()
        task.wait(15)
        if isAnswering then
            warn("[Office] Timeout konfirmasi server, reset isAnswering...")
            if successConn then successConn:Disconnect() successConn = nil end
            isAnswering = false
        end
    end)
end)

print("[Office] Auto jawab soal aktif, menunggu soal dari server...")

-- =================================================================
-- STEP 3: DIARAHKAN KE PRINTER → STOP JAWAB → WALK → HOLD
-- =================================================================
RS.JobEvents.AssignPrintJob.OnClientEvent:Connect(function(printerName)
    print("[Office] Assigned ke printer: " .. printerName)

    -- Stop auto jawab soal
    answerConn:Disconnect()
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
