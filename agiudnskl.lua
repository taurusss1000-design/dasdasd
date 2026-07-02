--[[
    KingVypers Premium — Key System v3.1
    Clean Compact Edition — Fixed
]]

repeat task.wait() until game:IsLoaded()

-- ── CONFIG ──────────────────────────────────────────────────
local CFG = {
    API_URL      = "cobabujank-production.up.railway.app",
    ENDPOINT     = "/api/validate-key",
    SCRIPTS      = {
        -- [131378148336503] = "https://raw.githubusercontent.com/SapuLidi-Eak/Asallahyakan/refs/heads/main/d_d_s.lua", --dds --utama lama
        [131378148336503] = "https://raw.githubusercontent.com/taurusss1000-design/allangmateiheang/refs/heads/main/heankdds.lua",
        [114862923457266] = "https://raw.githubusercontent.com/SapuLidi-Eak/Asallahyakan/refs/heads/main/non_dds_job", --dds
        [114069860751320] = "https://raw.githubusercontent.com/SapuLidi-Eak/Asallahyakan/refs/heads/main/non_dds_job", --dds
        [115335745596349] = "https://raw.githubusercontent.com/SapuLidi-Eak/Asallahyakan/refs/heads/main/non_dds_job", --dds
        [122318572211216] = "https://raw.githubusercontent.com/SapuLidi-Eak/Asallahyakan/refs/heads/main/non_dds_job", --dds
        [130342654546662] = "https://raw.githubusercontent.com/SapuLidi-Eak/Asallahyakan/refs/heads/main/tebakkata.lua", --sambungkata
        [121864768012064] = "https://raw.githubusercontent.com/SapuLidi-Eak/Asallahyakan/refs/heads/main/pis_it.lua", --pis it
        [110369730911937]= "https://raw.githubusercontent.com/SapuLidi-Eak/Asallahyakan/refs/heads/main/king_cd_id.lua" --cdid
    },
    SAVE_KEY     = true,
    KEY_FILE     = "KingVypers_Key.txt",
    DEBUG        = false,
    CHECK_INTERVAL = 600, -- Cek key setiap 5 menit (detik)
}

local T = {
    BG       = Color3.fromRGB(14, 11, 24),
    BG2      = Color3.fromRGB(19, 15, 32),
    SURFACE  = Color3.fromRGB(25, 20, 42),
    BORDER   = Color3.fromRGB(46, 37, 69),
    ACCENT   = Color3.fromRGB(108, 63, 197),
    ACCENT_H = Color3.fromRGB(127, 80, 216),
    TEXT     = Color3.fromRGB(232, 224, 255),
    MUTED    = Color3.fromRGB(107, 95, 138),
    SUCCESS  = Color3.fromRGB(80, 200, 140),
    ERROR    = Color3.fromRGB(224, 90, 106),
}

-- ── SERVICES ────────────────────────────────────────────────
local Http    = game:GetService("HttpService")
local TweenS  = game:GetService("TweenService")
local UIS     = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

-- ── UTILS ───────────────────────────────────────────────────
local function log(...)
    if CFG.DEBUG then print("[KV]", ...) end
end

local function hwid()
    if gethwid then return gethwid() end
    if syn and syn.fingerprint then return syn.fingerprint() end
    return game:GetService("RbxAnalyticsService"):GetClientId()
end

local function savedKey()
    if not CFG.SAVE_KEY then return nil end
    local ok, v = pcall(function()
        if isfile and isfile(CFG.KEY_FILE) then
            return readfile(CFG.KEY_FILE)
        end
        return nil
    end)
    return ok and v or nil
end

local function saveKey(k)
    pcall(function()
        if writefile then
            writefile(CFG.KEY_FILE, k)
        end
    end)
end

local function deleteKey()
    pcall(function()
        if delfile and isfile and isfile(CFG.KEY_FILE) then
            delfile(CFG.KEY_FILE)
        end
    end)
end

local function notify(t, b)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = t,
            Text = b,
            Duration = 4
        })
    end)
end

-- ── API ─────────────────────────────────────────────────────
local function makeRequest(url, method, headers, body)
    local fns = {
        function()
            if syn and syn.request then
                return syn.request({Url=url, Method=method, Headers=headers, Body=body})
            end
        end,
        function()
            if request then
                return request({Url=url, Method=method, Headers=headers, Body=body})
            end
        end,
        function()
            if http_request then
                return http_request({Url=url, Method=method, Headers=headers, Body=body})
            end
        end,
    }
    for _, fn in ipairs(fns) do
        local ok, res = pcall(fn)
        if ok and res then
            return res -- Kembalikan res meskipun StatusCode bukan 200, biar bisa baca error messagenya
        end
    end
    return nil
end

local function validateKey(key)
    local res = makeRequest(
        CFG.API_URL .. CFG.ENDPOINT,
        "POST",
        {["Content-Type"] = "application/json"},
        Http:JSONEncode({key = key, hwid = hwid()})
    )
    if not res then
        return {success = false, message = "Connection failed / No Internet"}
    end
    local ok, data = pcall(function()
        return Http:JSONDecode(res.Body)
    end)
    if ok and data then
        -- Jika API mengembalikan data (termasuk kalau error 403 / 404 tapi body-nya json), return datanya
        return data
    end
    return {success = false, message = "Server error " .. tostring(res.StatusCode)}
end

-- ── UI HELPERS ──────────────────────────────────────────────
local function tween(obj, t, props)
    TweenS:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad), props):Play()
end

local function corner(parent, px)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, px or 8)
    c.Parent = parent
end

local function makeStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or T.BORDER
    s.Thickness = thickness or 1
    s.Transparency = 0
    s.Parent = parent
    return s
end

local function makeLabel(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.Font = props.Font or Enum.Font.GothamMedium
    l.TextSize = props.TextSize or 12
    l.TextColor3 = props.Color or T.TEXT
    l.Text = props.Text or ""
    l.TextXAlignment = props.Align or Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.Position = props.Pos or UDim2.new(0, 0, 0, 0)
    l.Size = props.Size or UDim2.new(1, 0, 0, 20)
    l.ZIndex = props.Z or 5
    l.Parent = parent
    return l
end

local function makeButton(parent, props)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = props.BG or T.SURFACE
    b.BorderSizePixel = 0
    b.Position = props.Pos or UDim2.new(0, 0, 0, 0)
    b.Size = props.Size or UDim2.new(1, 0, 0, 36)
    b.Font = props.Font or Enum.Font.GothamMedium
    b.Text = props.Text or ""
    b.TextColor3 = props.Color or T.MUTED
    b.TextSize = props.TextSize or 12
    b.AutoButtonColor = false
    b.ZIndex = props.Z or 4
    b.Parent = parent
    corner(b, props.Radius or 8)
    return b
end

-- ── BUILD UI ────────────────────────────────────────────────
local function buildUI()
    pcall(function()
        local e = CoreGui:FindFirstChild("KV_Auth")
        if e then e:Destroy() end
    end)

    local sg = Instance.new("ScreenGui")
    sg.Name = "KV_Auth"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999

    if gethui then
        sg.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(sg)
        sg.Parent = CoreGui
    else
        sg.Parent = CoreGui
    end

    -- Overlay
    local overlay = Instance.new("Frame")
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.45
    overlay.BorderSizePixel = 0
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.ZIndex = 1
    overlay.Parent = sg

    -- Card (320x200) — lebih kecil karena WA/Discord dihapus
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = T.BG
    card.BorderSizePixel = 0
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.Size = UDim2.new(0, 320, 0, 200)
    card.ZIndex = 2
    card.Parent = sg
    corner(card, 12)
    makeStroke(card, T.BORDER, 1)

    -- Draggable
    local dragging, dragStart, startPos = false, nil, nil
    card.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inp.Position
            startPos = card.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and (
            inp.UserInputType == Enum.UserInputType.MouseMovement or
            inp.UserInputType == Enum.UserInputType.Touch
        ) then
            local d = inp.Position - dragStart
            card.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)

    -- Header (teks saja, tanpa dot/icon)
    local header = Instance.new("Frame")
    header.BackgroundColor3 = T.BG2
    header.BorderSizePixel = 0
    header.Size = UDim2.new(1, 0, 0, 48)
    header.ZIndex = 3
    header.Parent = card
    corner(header, 12)

    local hfill = Instance.new("Frame")
    hfill.BackgroundColor3 = T.BG2
    hfill.BorderSizePixel = 0
    hfill.Position = UDim2.new(0, 0, 0, 36)
    hfill.Size = UDim2.new(1, 0, 0, 12)
    hfill.ZIndex = 3
    hfill.Parent = card

    -- Teks header centered
    makeLabel(header, {
        Text = "King Vypers Premium",
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Color = T.TEXT,
        Pos = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -56, 1, 0),
        Align = Enum.TextXAlignment.Left,
        Z = 4,
    })

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.BackgroundTransparency = 1
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -12, 0.5, 0)
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "x"
    closeBtn.TextColor3 = T.MUTED
    closeBtn.TextSize = 14
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 5
    closeBtn.Parent = header
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, 0.15, {TextColor3 = T.ERROR})
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, 0.15, {TextColor3 = T.MUTED})
    end)

    -- Body
    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0, 16, 0, 56)
    body.Size = UDim2.new(1, -32, 1, -64)
    body.ZIndex = 3
    body.Parent = card

    makeLabel(body, {
        Text = "LICENSE KEY",
        TextSize = 10,
        Color = T.MUTED,
        Pos = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 14),
        Z = 4,
    })

    -- Input
    local inputFrame = Instance.new("Frame")
    inputFrame.BackgroundColor3 = T.SURFACE
    inputFrame.BorderSizePixel = 0
    inputFrame.Position = UDim2.new(0, 0, 0, 18)
    inputFrame.Size = UDim2.new(1, 0, 0, 38)
    inputFrame.ZIndex = 4
    inputFrame.Parent = body
    corner(inputFrame, 8)
    local inputStroke = makeStroke(inputFrame, T.BORDER, 1)

    local keyInput = Instance.new("TextBox")
    keyInput.BackgroundTransparency = 1
    keyInput.Position = UDim2.new(0, 12, 0, 0)
    keyInput.Size = UDim2.new(1, -24, 1, 0)
    keyInput.Font = Enum.Font.GothamMedium
    keyInput.PlaceholderText = "XXXX-XXXX-XXXX-XXXX"
    keyInput.PlaceholderColor3 = T.MUTED
    keyInput.Text = ""
    keyInput.TextColor3 = T.TEXT
    keyInput.TextSize = 12
    keyInput.ClearTextOnFocus = false
    keyInput.ZIndex = 5
    keyInput.Parent = inputFrame

    keyInput.Focused:Connect(function()
        tween(inputStroke, 0.2, {Color = T.ACCENT})
    end)
    keyInput.FocusLost:Connect(function()
        tween(inputStroke, 0.2, {Color = T.BORDER})
    end)

    -- Verify button
    local verifyBtn = makeButton(body, {
        BG = T.ACCENT,
        Pos = UDim2.new(0, 0, 0, 66),
        Size = UDim2.new(1, 0, 0, 38),
        Font = Enum.Font.GothamBold,
        Text = "Verify License",
        Color = T.TEXT,
        TextSize = 13,
        Z = 4,
        Radius = 8,
    })
    verifyBtn.MouseEnter:Connect(function()
        tween(verifyBtn, 0.15, {BackgroundColor3 = T.ACCENT_H})
    end)
    verifyBtn.MouseLeave:Connect(function()
        tween(verifyBtn, 0.15, {BackgroundColor3 = T.ACCENT})
    end)

    -- Status label
    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Position = UDim2.new(0, 0, 0, 112)
    status.Size = UDim2.new(1, 0, 0, 16)
    status.Font = Enum.Font.Gotham
    status.Text = ""
    status.TextColor3 = T.MUTED
    status.TextSize = 11
    status.ZIndex = 4
    status.Parent = body

    return {
        sg = sg,
        card = card,
        overlay = overlay,
        keyInput = keyInput,
        verifyBtn = verifyBtn,
        status = status,
        closeBtn = closeBtn,
    }
end

-- ── LOGIC ───────────────────────────────────────────────────
local function setStatus(ui, msg, kind)
    local colors = {
        success = T.SUCCESS,
        error   = T.ERROR,
        info    = T.ACCENT_H,
        default = T.MUTED,
    }
    ui.status.Text = msg
    ui.status.TextColor3 = colors[kind] or colors.default
end

local function setLoading(ui, on)
    ui.verifyBtn.Active = not on
    ui.keyInput.TextEditable = not on
    if on then
        ui.verifyBtn.Text = "Verifying..."
        tween(ui.verifyBtn, 0.15, {BackgroundColor3 = Color3.fromRGB(70, 40, 130)})
    else
        ui.verifyBtn.Text = "Verify License"
        tween(ui.verifyBtn, 0.15, {BackgroundColor3 = T.ACCENT})
    end
end

local function destroyUI(ui)
    tween(ui.overlay, 0.25, {BackgroundTransparency = 1})
    TweenS:Create(ui.card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 280, 0, 160),
    }):Play()
    task.wait(0.35)
    pcall(function() ui.sg:Destroy() end)
end

-- ── EXPIRY CHECKER ──────────────────────────────────────────
local function startExpiryChecker(key)
    task.spawn(function()
        while task.wait(CFG.CHECK_INTERVAL) do
            log("Checking key validity...")
            local result = validateKey(key)
            if not result.success then
                local reason = result.message or "Key expired"
                warn("[KV] Key invalid:", reason)
                notify("KingVypers — Session Ended", reason)
                deleteKey()
                task.wait(2) -- Beri waktu notif muncul dulu
                local player = game:GetService("Players").LocalPlayer
                if player then
                    player:Kick("[KingVypers] " .. reason .. " — Silakan renew key kamu.")
                end
                break
            else
                log("Key still valid.")
            end
        end
    end)
end

local function loadMain(key)
    local scriptUrl = CFG.SCRIPTS[game.PlaceId]
    if not scriptUrl then
        warn("[KV] Game not supported. PlaceId:", game.PlaceId)
        notify("Game Not Supported", "This game is not supported by KingVypers Premium.")
        return
    end

    local ok, err = pcall(function()
        loadstring(game:HttpGet(scriptUrl, true))()
    end)
    if not ok then
        warn("[KV] Failed to load script:", err)
        notify("Error", "Failed to load main script")
    end

    -- Mulai background checker setelah script dimuat
    startExpiryChecker(key)
end

local function shake(card)
    local orig = card.Position
    for i = 1, 4 do
        card.Position = UDim2.new(orig.X.Scale, orig.X.Offset - 6, orig.Y.Scale, orig.Y.Offset)
        task.wait(0.04)
        card.Position = UDim2.new(orig.X.Scale, orig.X.Offset + 6, orig.Y.Scale, orig.Y.Offset)
        task.wait(0.04)
    end
    card.Position = orig
end

local function onVerify(ui)
    local key = ui.keyInput.Text:upper():gsub("%s+", "")
    if key == "" then
        setStatus(ui, "Enter a license key first", "error")
        return
    end
    if #key < 8 then
        setStatus(ui, "Key format is invalid", "error")
        return
    end

    setLoading(ui, true)
    setStatus(ui, "Authenticating...", "info")

    task.spawn(function()
        local result = validateKey(key)
        setLoading(ui, false)

        if result.success then
            setStatus(ui, "Access granted", "success")
            saveKey(key)
            notify("KingVypers", "Welcome! Loading script...")
            task.wait(1.2)
            destroyUI(ui)
            loadMain(key)  -- Kirim key ke loadMain untuk expiry checker
        else
            -- Menampilkan pesan error asli dari API (seperti: Key Expired / Reset HWID)
            local errMsg = result.message or "Authentication failed"
            setStatus(ui, errMsg, "error")
            ui.keyInput.Text = ""
            shake(ui.card)
            ui.keyInput:CaptureFocus()
        end
    end)
end

-- ── MAIN ────────────────────────────────────────────────────
local function main()
    local saved = savedKey()
    if saved and saved ~= "" then
        notify("KingVypers", "Validating saved key...")
        local result = validateKey(saved)
        if result.success then
            notify("KingVypers", "Welcome back!")
            loadMain(saved)  -- Kirim key ke loadMain untuk expiry checker
            return
        else
            deleteKey()
        end
    end

    local ui = buildUI()

    -- Entrance animation
    ui.card.Size = UDim2.new(0, 280, 0, 160)
    ui.card.BackgroundTransparency = 1
    ui.overlay.BackgroundTransparency = 1
    tween(ui.overlay, 0.3, {BackgroundTransparency = 0.45})
    TweenS:Create(ui.card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
        Size = UDim2.new(0, 320, 0, 200),
    }):Play()

    -- Events
    ui.closeBtn.MouseButton1Click:Connect(function()
        destroyUI(ui)
    end)

    ui.verifyBtn.MouseButton1Click:Connect(function()
        onVerify(ui)
    end)

    ui.keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            onVerify(ui)
        end
    end)
end

-- ── INIT ────────────────────────────────────────────────────
local ok, err = pcall(main)
if not ok then
    warn("[KV] Init error:", err)
    notify("KingVypers Error", tostring(err))
end
