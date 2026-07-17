local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "King Vypers",
    Icon = "rbxassetid://139467646163013",
    Folder = "KingVypers",
    Background = "rbxassetid://97514324988224",
    BackgroundImageTransparency = 0.35,
    Size = UDim2.new(0, 530, 0, 300),
    MinSize = Vector2.new(530, 300),
    MaxSize = Vector2.new(530, 300),
    NewElements = true,
    OpenButton = {
        Enabled = false,
    },
})

-- */  Colors  /* --
local Kings = Color3.fromHex("#120324")
local Mains = Color3.fromHex("#110029")
local Purple = Color3.fromHex("#7775F2")
local Yellow = Color3.fromHex("#ECA201")
local Green = Color3.fromHex("#10C550")
local Grey = Color3.fromHex("#292828")
local Blue = Color3.fromHex("#257AF7")
local Red = Color3.fromHex("#EF4F1D")


-- TARUH DISINI ↓
WindUI:AddTheme({
    Name = "MachTheme",
    Background = Kings,
})
WindUI:SetTheme("MachTheme")
-- SAMPAI SINI ↑

-- Tambahkan setelah CreateWindow
Window:Tag({
    Title = "PREMIUM",
    Color = Mains,
})

Window:Tag({
    Title = "BETA",
    Color = Purple,
})

-- =================================================================
-- 🔴 TOMBOL MERAH (PC + MOBILE SUPPORT)
-- =================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

-- Protection
local protectGui
local success, result = pcall(function()
    if gethui then
        return gethui()
    elseif syn and syn.protect_gui then
        local sg = Instance.new("ScreenGui")
        syn.protect_gui(sg)
        sg.Parent = CoreGui
        return sg.Parent
    else
        return CoreGui
    end
end)

if success then
    protectGui = result
else
    protectGui = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MachFishingButton"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = protectGui

local buttonFrame = Instance.new("Frame")
buttonFrame.Size = UDim2.new(0, 42, 0, 42)
buttonFrame.Position = UDim2.new(0, 20, 0, 20)
buttonFrame.BackgroundTransparency = 1
buttonFrame.Parent = screenGui

local imageButton = Instance.new("ImageButton")
imageButton.Size = UDim2.new(1, 0, 1, 0)
imageButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)       -- merah -> hitam pekat
imageButton.BackgroundTransparency = 0.2
imageButton.Image = "rbxassetid://107726435417936"
imageButton.ScaleType = Enum.ScaleType.Fit
imageButton.Parent = buttonFrame

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = imageButton

local uiStroke = Instance.new("UIStroke")
uiStroke.Thickness = 2
uiStroke.Color = Color3.fromRGB(60, 60, 60)                     -- merah muda -> abu gelap
uiStroke.Parent = imageButton

local uiGradient = Instance.new("UIGradient")
uiGradient.Color = ColorSequence.new(
    Color3.fromRGB(20, 20, 20),                                  -- merah -> hitam pekat
    Color3.fromRGB(60, 60, 60)                                   -- merah muda -> abu gelap
)
uiGradient.Parent = uiStroke

-- ========================================
-- 🖱️📱 DRAG + CLICK (PC + MOBILE)
-- ========================================
local dragging = false
local dragInput
local dragStart
local startPos

imageButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = buttonFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

imageButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

-- DRAG MOVEMENT (PC + MOBILE)
UserInputService.InputChanged:Connect(function(input)
    if dragging and dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        buttonFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- CLICK DETECTION (PC + MOBILE)
local clickStart = nil
imageButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        clickStart = input.Position
    end
end)

imageButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if clickStart then
            local moved = (input.Position - clickStart).Magnitude
            
            -- CLICK (ga di-drag)
            if moved < 10 then
                if Window and Window.Toggle then
                    Window:Toggle()
                    print("🔄 Window toggled")
                end
            end
            
            clickStart = nil
        end
    end
end)

-- HOVER EFFECT (PC only)
imageButton.MouseEnter:Connect(function()
    TweenService:Create(imageButton, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
end)

imageButton.MouseLeave:Connect(function()
    TweenService:Create(imageButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
end)

-- INFO TAB

	local InfoTab = Window:Tab({
		Title = "Info",
		Icon = "solar:info-square-bold",
		IconColor = Mains,
		IconShape = "Square",
		Border = true,
	})






local HttpService = game:GetService("HttpService")
-- Fungsi fetch member count
local memberCount = "N/A"
local onlineCount = "N/A"

local function fetchDiscordInfo()
    local req = request or http_request or syn and syn.request
    if not req then return end
    
    local success, result = pcall(function()
        return req({
            Url = "https://discord.com/api/v9/invites/XmWf3YQPpZ?with_counts=true",
            Method = "GET",
            Headers = {
                ["User-Agent"] = "Mozilla/5.0"
            }
        })
    end)
    
    if success and result and result.StatusCode == 200 then
        local ok, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(result.Body)
        end)
        
        if ok and data then
            memberCount = tostring(data.approximate_member_count or "N/A")
            onlineCount = tostring(data.approximate_presence_count or "N/A")
        end
    end
end

-- Fetch dulu sebelum bikin UI
fetchDiscordInfo()

-- Info + buttons + banner semua dalam satu frame
local ServerInfo = InfoTab:Paragraph({
    Title = "King Vypers | Official",
    Desc = "• Member Count: " .. memberCount .. "\n• Online Count: " .. onlineCount,
    Image = "rbxassetid://107726435417936",
    Thumbnail = "rbxassetid://83197533072664",
    ThumbnailSize = 80,
    Buttons = {
        {
            Title = "Copy Discord Invite",
            Color= Color3.fromHex("#5707AB"),
            Icon = "link",
            Callback = function()
                if setclipboard then
                    setclipboard("https://discord.gg/XmWf3YQPpZ")
                end
            end
        },
        {
            Title = "Update Info",
            Icon = "refresh-cw",
            Callback = function()
                fetchDiscordInfo()
                ServerInfo:SetDesc("• Member Count: " .. memberCount .. "\n• Online Count: " .. onlineCount)
            end
        }
    }
})

-- FISHING TAB
local Fishing = Window:Tab({
    Title = "Fishing",
    Icon = "fish",
	IconColor = Mains,
	IconShape = "Square",
	Border = true,
})

-- =============================================
-- 🐟 AUTO FISH SECTION
-- =============================================

local AutoFishSection = Fishing:Section({ Title = "Auto Fish", Box = true, TextXAlignment = "Center", TextSize = 15, Opened = true })

local legitFishingEnabled = false
local legitFishingConnection = nil

AutoFishSection:Toggle({
    Title = "Legit Fishing",
    Icon = "fish",
    Default = false,
    Callback = function(state)
        legitFishingEnabled = state

        if state then
            print("[Auto Fish] ON")

            legitFishingConnection = task.spawn(function()
                local player = game:GetService("Players").LocalPlayer
                local char = player.Character or player.CharacterAdded:Wait()
                local VIM = game:GetService("VirtualInputManager")
                local Knit = game:GetService("ReplicatedStorage").Packages
                    ._Index["sleitnick_knit@1.7.0"].knit.Services
                local ReplicationRF = Knit.FishingReplicationService.RF
                local RewardRF = Knit.FishingRewardService.RF
                local RewardRE = Knit.FishingRewardService.RE

                -- Auto detect
                local reelButton = player.PlayerGui.FishingMobile:FindFirstChild("ReelButton")
                local IS_MOBILE = reelButton ~= nil
                print(IS_MOBILE and "Mobile detected!" or "PC detected!")

                local currentUUID = nil
                local isPulling = false
                local castSuccess = false
                local castFailed = false

                -- Listen FishCaught
                local caughtConn = RewardRE.FishCaught.OnClientEvent:Connect(function(data)
                    if data then
                        print("[CAUGHT]", data.FishID, "|", data.Weight, "Kg")
                    end
                    isPulling = false
                end)

                -- Hook ConfirmFloatingCast + StopFishing via __namecall
                local ConfirmRF = Knit.FishingReplicationService.RF.ConfirmFloatingCast
                local StopRF = Knit.FishingReplicationService.RF.StopFishing
                local mt = getrawmetatable(game)
                local oldNamecall = mt.__namecall
                setreadonly(mt, false)
                mt.__namecall = function(self, ...)
                    local method = getnamecallmethod()
                    if self == ConfirmRF and method == "InvokeServer" then
                        castSuccess = true
                        print("[Cast Sukses! ConfirmFloatingCast datang]")
                    elseif self == StopRF and method == "InvokeServer" then
                        castFailed = true
                        print("[Cast Gagal! StopFishing datang]")
                    end
                    return oldNamecall(self, ...)
                end
                setreadonly(mt, true)

                while legitFishingEnabled do
                    castSuccess = false
                    castFailed = false
                    currentUUID = nil
                    isPulling = false

                    -- [1] Cek dan equip rod
                    local equippedTool = char:FindFirstChildOfClass("Tool")
                    if equippedTool then
                        print("[1] Sudah pegang rod:", equippedTool.Name)
                    else
                        print("[1] Belum pegang rod, equip slot 1...")
                        VIM:SendKeyEvent(true, Enum.KeyCode.One, false, game)
                        task.wait(0.1)
                        VIM:SendKeyEvent(false, Enum.KeyCode.One, false, game)
                        task.wait(0.5)
                        print("[1] Slot 1 equipped!")
                    end

                    -- [2] Cast loop sampai sukses
                    local fillbar = player.PlayerGui.FishingPanel.ThrowFrame.FillContainer.Fillbar
                    repeat
                        if not legitFishingEnabled then break end
                        castSuccess = false
                        castFailed = false
                        currentUUID = nil
                        print("[2] Casting...")
                        if IS_MOBILE then
                            firesignal(reelButton.MouseButton1Down)
                        else
                            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        end

                        local maxFillWait = 0
                        repeat 
                            task.wait(0.05) 
                            maxFillWait += 0.05
                        until fillbar.Size.Y.Scale >= 0.99 or castFailed or not legitFishingEnabled or maxFillWait > 3

                        if IS_MOBILE then
                            firesignal(reelButton.MouseButton1Up)
                        else
                            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        end

                        -- Tunggu ConfirmFloatingCast atau StopFishing max 10 detik
                        local timeout = 0
                        while not castSuccess and not castFailed and timeout < 10 and legitFishingEnabled do
                            task.wait(0.1)
                            timeout += 0.1
                        end

                        if castFailed then
                            print("[Cast Gagal! StopFishing detected, retry...")
                            task.wait(1)
                        elseif not castSuccess then
                            print("[Cast Gagal] Timeout 10 detik, retry...")
                        end
                    until castSuccess or not legitFishingEnabled

                    if not legitFishingEnabled then break end

                    print("[3] Cast done! Waiting fish...")

                    -- [3] Tunggu UUID pake event
                    local uuidEvent = Instance.new("BindableEvent")
                    local uuidConn
                    uuidConn = RewardRE.FishingPullState.OnClientEvent:Connect(function(data)
                        if data and data.sessionId and currentUUID == nil then
                            currentUUID = data.sessionId
                            print("[UUID]", currentUUID)
                            uuidConn:Disconnect()
                            uuidEvent:Fire()
                        end
                    end)

                    local uuidTimeout = task.delay(15, function()
                        uuidEvent:Fire()
                    end)

                    uuidEvent.Event:Wait()
                    uuidEvent:Destroy()
                    pcall(function() task.cancel(uuidTimeout) end)

                    if currentUUID == nil then
                        print("[ERROR] UUID timeout!")
                        if not legitFishingEnabled then break end
                        task.wait(1)
                        continue
                    end

                    -- [4] Pull langsung tanpa delay
                    print("[4] Pulling UUID:", currentUUID)
                    isPulling = true
                    RewardRF.FishingPullInput:InvokeServer(currentUUID, "begin")
                    while isPulling and legitFishingEnabled do
                        RewardRF.FishingPullInput:InvokeServer(currentUUID, "tap")
                        task.wait()
                    end

                    print("[5] Done! Looping...")
                    task.wait(3)
                end

                -- Cleanup
                caughtConn:Disconnect()
                setreadonly(mt, false)
                mt.__namecall = oldNamecall
                setreadonly(mt, true)
                print("[Auto Fish] OFF")
            end)
        else
            print("[Auto Fish] Stopping...")
            legitFishingEnabled = false
        end
    end,
})

local autoMinigameEnabled = false
local autoMinigameConnUUID = nil
local autoMinigameConnCaught = nil

AutoFishSection:Toggle({
    Title = "Auto Minigame Only",
    Icon = "gamepad-2",
    Default = false,
    Callback = function(state)
        autoMinigameEnabled = state
        
        local Knit = game:GetService("ReplicatedStorage").Packages._Index["sleitnick_knit@1.7.0"].knit.Services
        local RewardRF = Knit.FishingRewardService.RF
        local RewardRE = Knit.FishingRewardService.RE

        if state then
            print("[Auto Minigame] ON")
            
            local isPulling = false
            local pullTask = nil

            autoMinigameConnCaught = RewardRE.FishCaught.OnClientEvent:Connect(function(data)
                isPulling = false
                if pullTask then
                    task.cancel(pullTask)
                    pullTask = nil
                end
                print("[Auto Minigame] Ikan ketangkep!")
            end)

            autoMinigameConnUUID = RewardRE.FishingPullState.OnClientEvent:Connect(function(data)
                if data and data.sessionId and autoMinigameEnabled then
                    local currentUUID = data.sessionId
                    print("[Auto Minigame] Minigame mulai! UUID:", currentUUID)
                    
                    isPulling = true
                    RewardRF.FishingPullInput:InvokeServer(currentUUID, "begin")
                    
                    pullTask = task.spawn(function()
                        while isPulling and autoMinigameEnabled do
                            RewardRF.FishingPullInput:InvokeServer(currentUUID, "tap")
                            task.wait()
                        end
                    end)
                end
            end)

        else
            print("[Auto Minigame] OFF")
            if autoMinigameConnUUID then autoMinigameConnUUID:Disconnect() end
            if autoMinigameConnCaught then autoMinigameConnCaught:Disconnect() end
        end
    end,
})

InfoTab:Select()
