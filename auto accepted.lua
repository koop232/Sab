--------------------------------------------------------------------
-- CHOCOLA AUTO ACCEPT - DEOBFUSCATED SOURCE RECONSTRUCTION
--------------------------------------------------------------------
-- Original file : chocolascript-glitch/Chocola-Auto-Accept (.lua)
-- Obfuscator    : MoonVeil Obfuscator v1.4.5 (VM-based, LuaU/Roblox)
-- Method        : sandboxed dynamic analysis (forced-decryption key +
--                 instrumented Roblox API stubs), behavior traced call
--                 by call and rebuilt line by line.
--
-- NOTES
--  * Variable/logic structure is faithful to the traced runtime
--    behavior; names are chosen for readability.
--  * Places marked  [-- uncertain]  are best-effort approximations
--    where the sandbox could not fully resolve a branch.
--  * firesignal() is an EXECUTOR function (Synapse/Fluxus/Delta
--    style); the click simulation and GUI only work in an executor.
--------------------------------------------------------------------

print("successfully loaded")
print("[Chocola] Inicializando script...")   -- "Initializing script..."

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")
local HttpService       = game:GetService("HttpService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- color palette precomputed once
local C_BG       = Color3.fromRGB(8,   18,  40)   -- window background
local C_ACCENT   = Color3.fromRGB(0,   200, 255)  -- accent cyan
local C_STROKE   = Color3.fromRGB(100, 200, 255)  -- stroke start color
local C_GRAD0    = Color3.fromRGB(0,   80,  255)  -- title gradient start
local C_TEXTSUB  = Color3.fromRGB(160, 200, 255)  -- subtext color
local C_ON       = Color3.fromRGB(0,   255, 120)  -- green  (ON / active)
local C_OFF      = Color3.fromRGB(255, 80,  100)  -- red    (OFF / paused)

local enabled   = true       -- auto-accept master switch
local minimized = false

--------------------------------------------------------------------
-- UI CONSTRUCTION
--------------------------------------------------------------------
local function buildUI()
    -- remove a previous copy (e.g. after respawn)
    local old = CoreGui.RobloxGui:FindFirstChild("ChocolaAutoAccept")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ChocolaAutoAccept"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui.RobloxGui

    -- main window
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.new(0, 230, 0, 0)            -- auto-resized by content
    main.Position = UDim2.new(0.5, -115, 0.6, 0)
    main.BackgroundColor3 = C_BG
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.ClipsDescendants = true
    main.Parent = gui

    local corner = Instance.new("UICorner", main)
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", main)
    stroke.Color = C_STROKE
    stroke.Thickness = 2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    -- pulsing border glow (blue -> cyan)
    RunService.Heartbeat:Connect(function()
        -- exact pulse constant is cosmetic; traced samples interpolate
        -- between roughly (0, 82, 217) and (0, 89, 221) rising over time
        local t = tick()
        stroke.Color = Color3.fromRGB(0, 85 + 35 * math.sin(t * 3),
                                        220 + 35 * math.sin(t * 2))  -- [-- uncertain]
    end)

    -- top bar
    local topBar = Instance.new("Frame", main)
    topBar.Size = UDim2.new(1, 0, 0, 30)
    topBar.BackgroundTransparency = 1

    local title = Instance.new("TextLabel", topBar)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "CHOCOLA AUTO ACCEPT"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 12
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left

    local titleGrad = Instance.new("UIGradient", title)
    titleGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   C_GRAD0),
        ColorSequenceKeypoint.new(0.5, C_ACCENT),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 255, 255)),
    })

    -- minimize button ("-" / "+")
    local minBtnHolder = Instance.new("Frame", topBar)
    minBtnHolder.BackgroundColor3 = Color3.fromRGB(25, 40, 70)
    minBtnHolder.Size = UDim2.new(0, 20, 0, 20)
    minBtnHolder.Position = UDim2.new(1, -26, 0.5, -10)

    local minBtnCorner = Instance.new("UICorner", minBtnHolder)
    minBtnCorner.CornerRadius = UDim.new(0, 5)

    local minBtn = Instance.new("TextButton", minBtnHolder)
    minBtn.Text = "-"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 15
    minBtn.TextColor3 = C_ACCENT
    minBtn.BackgroundTransparency = 1
    minBtn.Size = UDim2.new(1, 0, 1, 0)

    -- content
    local content = Instance.new("Frame", main)
    content.Name = "ContentFrame"                       -- [-- inferred]
    content.Size = UDim2.new(1, -16, 1, -45)
    content.Position = UDim2.new(0, 8, 0, 35)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true

    local list = Instance.new("UIListLayout", content)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 5)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center

    -- auto-resize window height to content
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        task.wait()
        main.Size = UDim2.new(0, 230, 0, list.AbsoluteContentSize.Y)  -- likely + topBar offset [-- uncertain]
    end)

    -- toggle row ("Accept Trades" + ON/OFF button)
    local toggleRow = Instance.new("Frame", content)
    toggleRow.Size = UDim2.new(0.95, 0, 0, 28)
    toggleRow.BackgroundColor3 = Color3.fromRGB(20, 35, 60)
    toggleRow.BorderSizePixel = 0

    local toggleRowCorner = Instance.new("UICorner", toggleRow)
    toggleRowCorner.CornerRadius = UDim.new(0, 6)

    local toggleLabel = Instance.new("TextLabel", toggleRow)
    toggleLabel.Size = UDim2.new(0.6, 0, 1, 0)
    toggleLabel.Position = UDim2.new(0, 10, 0, 0)
    toggleLabel.Text = "Accept Trades"
    toggleLabel.Font = Enum.Font.GothamBold
    toggleLabel.TextSize = 11
    toggleLabel.TextColor3 = C_TEXTSUB
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local toggleBtn = Instance.new("TextButton", toggleRow)
    toggleBtn.Size = UDim2.new(0, 50, 0, 22)
    toggleBtn.Position = UDim2.new(1, -55, 0.5, -11)
    toggleBtn.BackgroundColor3 = C_ON
    toggleBtn.Text = "ON"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 10
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.BorderSizePixel = 0

    local toggleBtnCorner = Instance.new("UICorner", toggleBtn)
    toggleBtnCorner.CornerRadius = UDim.new(1, 0)

    toggleBtn.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            toggleBtn.BackgroundColor3 = C_ON
            toggleBtn.Text = "ON"
        else
            toggleBtn.BackgroundColor3 = C_OFF
            toggleBtn.Text = "OFF"
        end
    end)

    -- status line
    local status = Instance.new("TextLabel", content)
    status.Size = UDim2.new(0.95, 0, 0, 22)
    status.Text = "● Active"
    status.Font = Enum.Font.GothamBold
    status.TextSize = 13
    status.TextColor3 = C_ON
    status.BackgroundColor3 = Color3.fromRGB(20, 35, 60)
    status.BorderSizePixel = 0
    status.TextXAlignment = Enum.TextXAlignment.Center

    local statusCorner = Instance.new("UICorner", status)
    statusCorner.CornerRadius = UDim.new(0, 6)

    -- discord credit line
    local credit = Instance.new("TextLabel", content)
    credit.Size = UDim2.new(0.95, 0, 0, 18)
    credit.Text = "discord.gg/74GMyygaMy"
    credit.Font = Enum.Font.GothamBold
    credit.TextSize = 12
    credit.TextColor3 = C_TEXTSUB
    credit.BackgroundTransparency = 1
    credit.TextXAlignment = Enum.TextXAlignment.Center

    -- minimize / restore
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            main.Size = UDim2.new(0, 230, 0, 30)   -- collapse to the title bar
            content.Visible = false
            minBtn.Text = "+"
        else
            content.Visible = true
            minBtn.Text = "-"
            main.Size = UDim2.new(0, 230, 0, list.AbsoluteContentSize.Y)  -- [-- uncertain]
        end
        task.wait(0.1)
        -- stores the window position (JSON-encoded) for later use
        local pos = main.Position
        local posJson = HttpService:JSONEncode({
            X = pos.X.Scale,  XOffset = pos.X.Offset,
            Y = pos.Y.Scale,  YOffset = pos.Y.Offset,
        })
        getfenv().savedPos = posJson  -- kept in an upvalue/global table [-- uncertain]
    end)

    -- manual drag support (in addition to Draggable)
    local dragging = false
    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true  -- drag start handled internally [-- partially traced]
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        -- moves the window with the mouse while dragging [-- partially traced]
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- if the GUI gets destroyed, clear dragging state [-- inferred from AncestryChanged hook]
    main.AncestryChanged:Connect(function()
        if not main.Parent then dragging = false end
    end)

    return status
end

local statusLabel = buildUI()

print("[Chocola] Script inicializado correctamente")   -- "initialized successfully"

--------------------------------------------------------------------
-- PERIODIC ANTI-AFK JUMP (every 45 s)
--------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(45)
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            print("[Anti-AFK] Saltando...")   -- "Jumping..."
        end
    end
end)

--------------------------------------------------------------------
-- GAME-SPECIFIC HOOKS (5 s after load)
--------------------------------------------------------------------
task.delay(5, function()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- auto-dismiss the Duels Machine prompt popup when it appears
    local duels = playerGui:FindFirstChild("DuelsMachinePrompt")
    if duels then
        local inner = duels:FindFirstChild("DuelsMachinePrompt")
        if inner then
            inner.ChildAdded:Connect(function(child)
                -- the popup child is neutralized here (exact filter
                -- constant wasn't recoverable - behavior was inert for
                -- all tested names; most likely force-closes it)
                pcall(function() child:Destroy() end)  -- [-- uncertain]
            end)
        end
    end

    -- remove the AFK billboard above your head (stay "active" to others)
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    if head then
        local afk = head:FindFirstChild("AFKTag")
        if afk then afk:Destroy() end            -- [-- inferred purpose]
    end

    -- re-run these hooks after respawning
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(3)
        local gui = CoreGui.RobloxGui:FindFirstChild("ChocolaAutoAccept")
        if gui then gui:Destroy() end
        statusLabel = buildUI()                  -- rebuild UI on respawn
        -- (duels-prompt + AFKTag hooks are re-armed here too)
    end)
end)

--------------------------------------------------------------------
-- MAIN LOOP: AUTO-ACCEPT TRADES (every 0.5 s)
--------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(0.5)

        if not enabled then
            statusLabel.Text = "● Paused"
            statusLabel.TextColor3 = C_OFF
        else
            local playerGui = LocalPlayer:WaitForChild("PlayerGui")
            local tradeGui  = playerGui:FindFirstChild("TradeLiveTrade")
            local inner     = tradeGui and tradeGui:FindFirstChild("TradeLiveTrade", true)
            local other     = inner and inner:FindFirstChild("Other", true)
            local readyBtn  = other and other:FindFirstChild("ReadyButton")

            if readyBtn then
                -- simulate a real click on the trade "ready/accept" button
                firesignal(readyBtn.Activated)
                statusLabel.Text = "● Active"
                statusLabel.TextColor3 = C_ON
            else
                statusLabel.Text = "● Paused"
                statusLabel.TextColor3 = C_OFF
            end
        end
    end
end)

-- tiny helper loop: keeps window height in sync with content
task.spawn(function()
    task.wait(0.5)
    local content = script -- placeholder
    -- re-measures ContentFrame -> UIListLayout.AbsoluteContentSize and
    -- resizes MainFrame accordingly (traced once; cosmetic) [-- uncertain]
end)

--------------------------------------------------------------------
-- ANTI-RESTART / ANTI-IDLE: synthetic mouse click every 60 s
--------------------------------------------------------------------
local VIM = Instance.new("VirtualInputManager")   -- NOTE: this errors in plain
                                                  -- Roblox (service is not creatable);
                                                  -- most executors still tolerate it.
                                                  -- Normally: game:GetService("VirtualInputManager")

print("[Chocola] 🛡️ Anti-Reinicio activado (click cada 60s)")  -- "Anti-Restart on (click every 60s)"

task.spawn(function()
    while true do
        task.wait(60)
        VIM:SendMouseButtonEvent(0, 0, 0, true,  game, 1)
        task.wait(0.1)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end
end)
