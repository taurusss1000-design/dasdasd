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
-- MAIN LOGIC
-- =================================================================

function PoliceModule:Start()
    if policeRunning then return end
    policeRunning = true
    
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
        end
    end)
end

function PoliceModule:Stop()
    policeRunning = false
    print("[Police] Auto Police Dihentikan!")
end

return PoliceModule
