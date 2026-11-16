--[[ itnoxify
   Fixed: UI now forces itself to appear
   - original look kept
   - Puzzle tab
   - Auto-analyze tick
   - mode detection (bullet/blitz/rapid)
]]

-- force clean previous run
pcall(function()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        local old = pg:FindFirstChild("itnoxify")
        if old then old:Destroy() end
        local old2 = pg:FindFirstChild("BestMoveGUI")
        if old2 then old2:Destroy() end
    end
end)
_G.__itnoxifyRunning = nil

if _G.__itnoxifyRunning then
    warn("[itnoxify] already running")
    return
end
_G.__itnoxifyRunning = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then
    warn("[itnoxify] PlayerGui not found")
    _G.__itnoxifyRunning = nil
    return
end

-- ===== create UI first so it always shows =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "itnoxify"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 420)
Main.Position = UDim2.new(1, -320, 0, 20)
Main.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 64, 72)
stroke.Thickness = 1
stroke.Parent = Main

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "♟ itnoxify"
Title.TextColor3 = Color3.fromRGB(230, 230, 240)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 24)
MinBtn.Position = UDim2.new(1, -32, 0, 4)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(230,230,240)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,6)

-- Tab bar
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -16, 0, 28)
TabBar.Position = UDim2.new(0, 8, 0, 36)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Main

local EngineTabBtn = Instance.new("TextButton")
EngineTabBtn.Size = UDim2.new(0.5, -4, 1, 0)
EngineTabBtn.Position = UDim2.new(0, 0, 0, 0)
EngineTabBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 170)
EngineTabBtn.Text = "Engine"
EngineTabBtn.TextColor3 = Color3.fromRGB(255,255,255)
EngineTabBtn.Font = Enum.Font.GothamBold
EngineTabBtn.TextSize = 13
EngineTabBtn.BorderSizePixel = 0
EngineTabBtn.Parent = TabBar
Instance.new("UICorner", EngineTabBtn).CornerRadius = UDim.new(0,6)

local PuzzleTabBtn = Instance.new("TextButton")
PuzzleTabBtn.Size = UDim2.new(0.5, -4, 1, 0)
PuzzleTabBtn.Position = UDim2.new(0.5, 4, 0, 0)
PuzzleTabBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
PuzzleTabBtn.Text = "Puzzle"
PuzzleTabBtn.TextColor3 = Color3.fromRGB(200,200,210)
PuzzleTabBtn.Font = Enum.Font.GothamBold
PuzzleTabBtn.TextSize = 13
PuzzleTabBtn.BorderSizePixel = 0
PuzzleTabBtn.Parent = TabBar
Instance.new("UICorner", PuzzleTabBtn).CornerRadius = UDim.new(0,6)

local EngineContent = Instance.new("Frame")
EngineContent.Name = "EngineContent"
EngineContent.Size = UDim2.new(1, -16, 1, -72)
EngineContent.Position = UDim2.new(0, 8, 0, 68)
EngineContent.BackgroundTransparency = 1
EngineContent.Parent = Main

local PuzzleContent = Instance.new("Frame")
PuzzleContent.Name = "PuzzleContent"
PuzzleContent.Size = UDim2.new(1, -16, 1, -72)
PuzzleContent.Position = UDim2.new(0, 8, 0, 68)
PuzzleContent.BackgroundTransparency = 1
PuzzleContent.Visible = false
PuzzleContent.Parent = Main

print("[itnoxify] UI created")

-- ===== now load modules (safe) =====
local AUTO_PLAY      = true
local AUTO_ANALYZE   = false
_G.__itnoxifyAutoPlay = AUTO_PLAY
local TIME_BUDGET    = 2.0
local MAX_DEPTH      = 40
local USE_VORTEX     = true
local HINT_COLOR     = Color3.fromRGB(150, 190, 70)

local PLAY_STYLES = {"Immortal", "Aggressive", "Solid", "Tactical", "Balanced"}
local currentStyleIndex = 1
local currentStyle = PLAY_STYLES[currentStyleIndex]

local STYLE_BIAS = {
    Immortal   = { timeMul = 1.6, depthMul = 1.4, minTime = 2.5, minDepth = 45 },
    Aggressive = { timeMul = 0.85, depthMul = 0.9, minTime = 1.2, minDepth = 28 },
    Solid      = { timeMul = 1.25, depthMul = 1.15, minTime = 2.0, minDepth = 38 },
    Tactical   = { timeMul = 1.1,  depthMul = 1.05, minTime = 1.8, minDepth = 35 },
    Balanced   = { timeMul = 1.0,  depthMul = 1.0,  minTime = 1.5, minDepth = 32 },
}

local MODE_BIAS = {
    bullet = { timeMul = 0.42, depthMul = 0.65, minTime = 0.35, minDepth = 18, loopWait = 0.10 },
    blitz  = { timeMul = 0.70, depthMul = 0.82, minTime = 0.80, minDepth = 26, loopWait = 0.16 },
    rapid  = { timeMul = 1.00, depthMul = 1.00, minTime = 1.40, minDepth = 32, loopWait = 0.25 },
}

local currentMode = "rapid"
local activeTab = "Engine"

local Engine, Bot, VortexBot, App

local okModules, errModules = pcall(function()
    local ChessFolder = ReplicatedStorage:WaitForChild("Chess", 8)
    local ClientFolder = ReplicatedStorage:WaitForChild("ChessClient", 8)
    Engine = require(ChessFolder:WaitForChild("Engine"))
    Bot    = require(ChessFolder:WaitForChild("Bot"))
    pcall(function() VortexBot = require(ChessFolder:WaitForChild("VortexBot")) end)
    App    = require(ClientFolder:WaitForChild("App"))
end)

if not okModules then
    warn("[itnoxify] module load failed: " .. tostring(errModules))
end

local PROMO_MAP2 = { q = 5, r = 4, b = 3, n = 2 }

local function makeLabel(parent, text, size, color, bold)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, size or 18)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or Color3.fromRGB(220,220,230)
    l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Parent = parent
    return l
end

local function makeRow(parent, labelText)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(200,200,210)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    return row
end

-- ========== ENGINE TAB ==========
local engLayout = Instance.new("UIListLayout")
engLayout.Padding = UDim.new(0, 6)
engLayout.SortOrder = Enum.SortOrder.LayoutOrder
engLayout.Parent = EngineContent

local rowAP = makeRow(EngineContent, "Auto-play:")
local AutoPlayBtn = Instance.new("TextButton")
AutoPlayBtn.Size = UDim2.new(0.45, -4, 1, -2)
AutoPlayBtn.Position = UDim2.new(0.55, 4, 0, 1)
AutoPlayBtn.BackgroundColor3 = AUTO_PLAY and Color3.fromRGB(60, 130, 80) or Color3.fromRGB(130, 60, 60)
AutoPlayBtn.Text = AUTO_PLAY and "ON" or "OFF"
AutoPlayBtn.TextColor3 = Color3.fromRGB(255,255,255)
AutoPlayBtn.Font = Enum.Font.GothamBold
AutoPlayBtn.TextSize = 12
AutoPlayBtn.BorderSizePixel = 0
AutoPlayBtn.Parent = rowAP
Instance.new("UICorner", AutoPlayBtn).CornerRadius = UDim.new(0,6)

local rowAA = makeRow(EngineContent, "Auto-analyze:")
local AutoAnalyzeBtn = Instance.new("TextButton")
AutoAnalyzeBtn.Size = UDim2.new(0.45, -4, 1, -2)
AutoAnalyzeBtn.Position = UDim2.new(0.55, 4, 0, 1)
AutoAnalyzeBtn.BackgroundColor3 = AUTO_ANALYZE and Color3.fromRGB(60, 130, 80) or Color3.fromRGB(130, 60, 60)
AutoAnalyzeBtn.Text = AUTO_ANALYZE and "ON" or "OFF"
AutoAnalyzeBtn.TextColor3 = Color3.fromRGB(255,255,255)
AutoAnalyzeBtn.Font = Enum.Font.GothamBold
AutoAnalyzeBtn.TextSize = 12
AutoAnalyzeBtn.BorderSizePixel = 0
AutoAnalyzeBtn.Parent = rowAA
Instance.new("UICorner", AutoAnalyzeBtn).CornerRadius = UDim.new(0,6)

local rowT = makeRow(EngineContent, "Time (s):")
local TimeBox = Instance.new("TextBox")
TimeBox.Size = UDim2.new(0.45, -4, 1, -2)
TimeBox.Position = UDim2.new(0.55, 4, 0, 1)
TimeBox.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
TimeBox.Text = tostring(TIME_BUDGET)
TimeBox.TextColor3 = Color3.fromRGB(230,230,240)
TimeBox.Font = Enum.Font.Gotham
TimeBox.TextSize = 12
TimeBox.BorderSizePixel = 0
TimeBox.Parent = rowT
Instance.new("UICorner", TimeBox).CornerRadius = UDim.new(0,6)

local rowD = makeRow(EngineContent, "Depth:")
local DepthBox = Instance.new("TextBox")
DepthBox.Size = UDim2.new(0.45, -4, 1, -2)
DepthBox.Position = UDim2.new(0.55, 4, 0, 1)
DepthBox.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
DepthBox.Text = tostring(MAX_DEPTH)
DepthBox.TextColor3 = Color3.fromRGB(230,230,240)
DepthBox.Font = Enum.Font.Gotham
DepthBox.TextSize = 12
DepthBox.BorderSizePixel = 0
DepthBox.Parent = rowD
Instance.new("UICorner", DepthBox).CornerRadius = UDim.new(0,6)

local rowS = makeRow(EngineContent, "Play style:")
local StyleBtn = Instance.new("TextButton")
StyleBtn.Size = UDim2.new(0.45, -4, 1, -2)
StyleBtn.Position = UDim2.new(0.55, 4, 0, 1)
StyleBtn.BackgroundColor3 = Color3.fromRGB(70, 90, 140)
StyleBtn.Text = currentStyle
StyleBtn.TextColor3 = Color3.fromRGB(255,255,255)
StyleBtn.Font = Enum.Font.GothamBold
StyleBtn.TextSize = 12
StyleBtn.BorderSizePixel = 0
StyleBtn.Parent = rowS
Instance.new("UICorner", StyleBtn).CornerRadius = UDim.new(0,6)

local StatusBest  = makeLabel(EngineContent, "Best: --", 18, Color3.fromRGB(150, 220, 150), true)
local StatusScore = makeLabel(EngineContent, "Score: --", 16)
local StatusDepth = makeLabel(EngineContent, "Depth: --", 16)
local StatusStyle = makeLabel(EngineContent, "Style: " .. currentStyle, 16, Color3.fromRGB(180, 200, 255))
local StatusMode  = makeLabel(EngineContent, "Mode: " .. currentMode, 16, Color3.fromRGB(200, 180, 140))
local StatusTurn  = makeLabel(EngineContent, "Turn: --", 16, Color3.fromRGB(200, 200, 120))
local StatusColor = makeLabel(EngineContent, "You: --", 16, Color3.fromRGB(180, 180, 220))

local AnalyzeBtn = Instance.new("TextButton")
AnalyzeBtn.Size = UDim2.new(1, 0, 0, 28)
AnalyzeBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 170)
AnalyzeBtn.Text = "Analyze now"
AnalyzeBtn.TextColor3 = Color3.fromRGB(255,255,255)
AnalyzeBtn.Font = Enum.Font.GothamBold
AnalyzeBtn.TextSize = 13
AnalyzeBtn.BorderSizePixel = 0
AnalyzeBtn.Parent = EngineContent
Instance.new("UICorner", AnalyzeBtn).CornerRadius = UDim.new(0,6)

local ClearBtn = Instance.new("TextButton")
ClearBtn.Size = UDim2.new(1, 0, 0, 24)
ClearBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 50)
ClearBtn.Text = "Clear arrow"
ClearBtn.TextColor3 = Color3.fromRGB(255,255,255)
ClearBtn.Font = Enum.Font.Gotham
ClearBtn.TextSize = 12
ClearBtn.BorderSizePixel = 0
ClearBtn.Parent = EngineContent
Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0,6)

-- ========== PUZZLE TAB ==========
local puzLayout = Instance.new("UIListLayout")
puzLayout.Padding = UDim.new(0, 8)
puzLayout.SortOrder = Enum.SortOrder.LayoutOrder
puzLayout.Parent = PuzzleContent

local PuzzleTitle = makeLabel(PuzzleContent, "Puzzle Solve", 20, Color3.fromRGB(220, 200, 140), true)
local PuzzleHint  = makeLabel(PuzzleContent, "Works on puzzle / analysis positions.\nFinds the best move and draws the arrow.", 32, Color3.fromRGB(180,180,190))
local PuzzleBest  = makeLabel(PuzzleContent, "Best: --", 18, Color3.fromRGB(150, 220, 150), true)
local PuzzleScore = makeLabel(PuzzleContent, "Score: --", 16)
local PuzzleDepth = makeLabel(PuzzleContent, "Depth: --", 16)
local PuzzleStatus= makeLabel(PuzzleContent, "Status: idle", 16, Color3.fromRGB(200, 200, 120))

local SolveBtn = Instance.new("TextButton")
SolveBtn.Size = UDim2.new(1, 0, 0, 32)
SolveBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 90)
SolveBtn.Text = "Solve Puzzle"
SolveBtn.TextColor3 = Color3.fromRGB(255,255,255)
SolveBtn.Font = Enum.Font.GothamBold
SolveBtn.TextSize = 14
SolveBtn.BorderSizePixel = 0
SolveBtn.Parent = PuzzleContent
Instance.new("UICorner", SolveBtn).CornerRadius = UDim.new(0,6)

local PuzzleClearBtn = Instance.new("TextButton")
PuzzleClearBtn.Size = UDim2.new(1, 0, 0, 26)
PuzzleClearBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 50)
PuzzleClearBtn.Text = "Clear arrow"
PuzzleClearBtn.TextColor3 = Color3.fromRGB(255,255,255)
PuzzleClearBtn.Font = Enum.Font.Gotham
PuzzleClearBtn.TextSize = 12
PuzzleClearBtn.BorderSizePixel = 0
PuzzleClearBtn.Parent = PuzzleContent
Instance.new("UICorner", PuzzleClearBtn).CornerRadius = UDim.new(0,6)

-- drag
local dragging, dragStart, startPos = false, nil, nil
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local busy = false
local forceAnalyze = false

local function clearArrow()
    pcall(function()
        if App and App.board then App.board:setArrow("hint", nil) end
    end)
end

local function drawArrow(uci)
    if not (Engine and uci and #uci >= 4) then return end
    local from = Engine.algToIndex64(string.sub(uci, 1, 2))
    local to   = Engine.algToIndex64(string.sub(uci, 3, 4))
    if not from or not to then return end
    pcall(function()
        if App and App.board then
            App.board:setArrow("hint", from, to, HINT_COLOR, 0.15)
        end
    end)
end

local function playMove(uci)
    if _G.__itnoxifyAutoPlay ~= true then return end
    if not (Engine and App and uci and #uci >= 4) then return end
    local from = Engine.algToIndex64(string.sub(uci, 1, 2))
    local to   = Engine.algToIndex64(string.sub(uci, 3, 4))
    local promoChar = string.sub(uci, 5, 5)
    local promo = PROMO_MAP2[promoChar] or 0
    if not from or not to then return end
    pcall(function()
        App.onBoardMove(from, to, promo, false)
    end)
end

local function shouldAct(session, force)
    if not session then return false end
    if session.over then return false end
    if session.kind == "idle" or session.kind == "analysis" then return false end
    if session.viewPly ~= #session.ucis then return false end
    if force then return true end
    local ok, myTurn = pcall(function() return session:isMyTurn() end)
    if not ok or not myTurn then return false end
    return true
end

local function readSettings()
    local t = tonumber(TimeBox.Text)
    if t and t > 0 then TIME_BUDGET = t end
    local d = tonumber(DepthBox.Text)
    if d and d > 0 then MAX_DEPTH = math.floor(d) end
end

local function detectMode(session)
    if not session then return "rapid" end
    local candidates = {
        session.timeControl, session.tc, session.baseTime, session.initialTime,
        session.clock, session.time, session.limit
    }
    for _, v in ipairs(candidates) do
        if type(v) == "number" and v > 0 then
            if v <= 60 then return "bullet" end
            if v <= 180 then return "blitz" end
            return "rapid"
        end
        if type(v) == "table" then
            local base = v.base or v.initial or v.time or v.limit
            if type(base) == "number" and base > 0 then
                if base <= 60 then return "bullet" end
                if base <= 180 then return "blitz" end
                return "rapid"
            end
        end
    end
    local strs = {
        tostring(session.kind or ""),
        tostring(session.mode or ""),
        tostring(session.gameMode or ""),
        tostring(session.timeControl or ""),
        tostring(session.tc or "")
    }
    for _, s in ipairs(strs) do
        s = s:lower()
        if s:find("bullet") then return "bullet" end
        if s:find("blitz")  then return "blitz"  end
        if s:find("rapid") or s:find("classic") or s:find("standard") then return "rapid" end
    end
    return "rapid"
end

local function applyBias(baseTime, baseDepth)
    local style = STYLE_BIAS[currentStyle] or STYLE_BIAS.Balanced
    local mode  = MODE_BIAS[currentMode]  or MODE_BIAS.rapid
    local t = baseTime * style.timeMul * mode.timeMul
    local d = math.floor(baseDepth * style.depthMul * mode.depthMul)
    t = math.max(style.minTime * mode.timeMul, math.max(mode.minTime, t))
    d = math.max(style.minDepth, math.max(mode.minDepth, d))
    return t, d
end

local function getBestMove(session)
    if not Bot then return nil end
    local okBook, book = pcall(function() return Bot.bookMove(session.ucis) end)
    if okBook and type(book) == "string" and #book >= 4 then
        return book, nil, "book"
    end
    if USE_VORTEX and VortexBot then
        local okV, resV = pcall(function()
            return VortexBot.reviewGame(session.startFen, session.ucis)
        end)
        if okV and type(resV) == "table" and type(resV.best) == "string" and #resV.best >= 4 then
            return resV.best, resV.score, resV.depth or "Vortex"
        end
    end
    local t, d = applyBias(TIME_BUDGET, MAX_DEPTH)
    local r = Bot.analyse(session.startFen, table.clone(session.ucis), t, d)
    if type(r) == "table" and type(r.best) == "string" then
        return r.best, r.score, r.depth
    end
    return nil
end

local function runAnalysis(force)
    if busy or not App then return end
    local session = App.session
    if not shouldAct(session, force) then
        StatusTurn.Text = "Turn: not your turn / idle"
        return
    end
    busy = true
    StatusTurn.Text = "Turn: thinking... (" .. currentStyle .. " / " .. currentMode .. ")"
    task.spawn(function()
        local captured = session
        local capturedCount = #session.ucis
        local resultBest, resultScore, resultDepth
        local ok, err = pcall(function()
            local b, s, d = getBestMove(captured)
            resultBest, resultScore, resultDepth = b, s, d
        end)
        busy = false
        readSettings()

        if not ok or not resultBest then
            if not ok then warn("[itnoxify] analyse error: " .. tostring(err)) end
            StatusTurn.Text = "Turn: error"
            return
        end
        if App.session ~= captured then return end
        if #App.session.ucis ~= capturedCount then return end

        StatusBest.Text  = "Best: " .. resultBest
        StatusScore.Text = "Score: " .. tostring(resultScore)
        StatusDepth.Text = "Depth: " .. tostring(resultDepth)
        StatusStyle.Text = "Style: " .. currentStyle
        StatusMode.Text  = "Mode: " .. currentMode
        StatusTurn.Text  = "Turn: " .. (captured:isMyTurn() and "your turn" or "opponent")
        StatusColor.Text = "You: " .. (captured.myColor == 1 and "White" or "Black") .. " | To move: " .. (captured.engine.side == 1 and "White" or "Black")

        drawArrow(resultBest)

        if _G.__itnoxifyAutoPlay == true and captured:isMyTurn() then
            playMove(resultBest)
        end
    end)
end

local function runPuzzleSolve()
    if busy or not App then return end
    local session = App.session
    if not session then
        PuzzleStatus.Text = "Status: no session"
        return
    end
    busy = true
    PuzzleStatus.Text = "Status: solving..."
    task.spawn(function()
        local resultBest, resultScore, resultDepth
        local ok, err = pcall(function()
            local b, s, d = getBestMove(session)
            resultBest, resultScore, resultDepth = b, s, d
        end)
        busy = false
        if not ok or not resultBest then
            PuzzleStatus.Text = "Status: error"
            return
        end
        PuzzleBest.Text  = "Best: " .. resultBest
        PuzzleScore.Text = "Score: " .. tostring(resultScore)
        PuzzleDepth.Text = "Depth: " .. tostring(resultDepth)
        PuzzleStatus.Text = "Status: solved"
        drawArrow(resultBest)
    end)
end

local function setTab(tab)
    activeTab = tab
    if tab == "Engine" then
        EngineContent.Visible = true
        PuzzleContent.Visible = false
        EngineTabBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 170)
        EngineTabBtn.TextColor3 = Color3.fromRGB(255,255,255)
        PuzzleTabBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
        PuzzleTabBtn.TextColor3 = Color3.fromRGB(200,200,210)
    else
        EngineContent.Visible = false
        PuzzleContent.Visible = true
        PuzzleTabBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 170)
        PuzzleTabBtn.TextColor3 = Color3.fromRGB(255,255,255)
        EngineTabBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
        EngineTabBtn.TextColor3 = Color3.fromRGB(200,200,210)
    end
end

EngineTabBtn.MouseButton1Click:Connect(function() setTab("Engine") end)
PuzzleTabBtn.MouseButton1Click:Connect(function() setTab("Puzzle") end)

StyleBtn.MouseButton1Click:Connect(function()
    currentStyleIndex = currentStyleIndex % #PLAY_STYLES + 1
    currentStyle = PLAY_STYLES[currentStyleIndex]
    StyleBtn.Text = currentStyle
    StatusStyle.Text = "Style: " .. currentStyle
end)

AutoPlayBtn.MouseButton1Click:Connect(function()
    AUTO_PLAY = not AUTO_PLAY
    _G.__itnoxifyAutoPlay = AUTO_PLAY
    AutoPlayBtn.Text = AUTO_PLAY and "ON" or "OFF"
    AutoPlayBtn.BackgroundColor3 = AUTO_PLAY and Color3.fromRGB(60,130,80) or Color3.fromRGB(130,60,60)
end)

AutoAnalyzeBtn.MouseButton1Click:Connect(function()
    AUTO_ANALYZE = not AUTO_ANALYZE
    AutoAnalyzeBtn.Text = AUTO_ANALYZE and "ON" or "OFF"
    AutoAnalyzeBtn.BackgroundColor3 = AUTO_ANALYZE and Color3.fromRGB(60,130,80) or Color3.fromRGB(130,60,60)
end)

AnalyzeBtn.MouseButton1Click:Connect(function()
    forceAnalyze = true
    runAnalysis(true)
end)

ClearBtn.MouseButton1Click:Connect(clearArrow)
PuzzleClearBtn.MouseButton1Click:Connect(clearArrow)
SolveBtn.MouseButton1Click:Connect(runPuzzleSolve)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TabBar.Visible = not minimized
    EngineContent.Visible = not minimized and activeTab == "Engine"
    PuzzleContent.Visible = not minimized and activeTab == "Puzzle"
    Main.Size = minimized and UDim2.new(0, 300, 0, 32) or UDim2.new(0, 300, 0, 420)
    MinBtn.Text = minimized and "+" or "—"
end)

TimeBox.FocusLost:Connect(readSettings)
DepthBox.FocusLost:Connect(readSettings)

-- main loop
task.spawn(function()
    while ScreenGui.Parent do
        local modeData = MODE_BIAS[currentMode] or MODE_BIAS.rapid
        task.wait(modeData.loopWait)

        if not App then
            StatusTurn.Text = "Turn: modules not loaded"
            continue
        end

        local session = App.session
        currentMode = detectMode(session)
        StatusMode.Text = "Mode: " .. currentMode

        if session and not session.over then
            StatusTurn.Text = "Turn: " .. (session:isMyTurn() and "your turn" or "opponent") .. "  (" .. tostring(session.kind) .. ")"
            StatusColor.Text = "You: " .. (session.myColor == 1 and "White" or "Black") .. " | To move: " .. (session.engine.side == 1 and "White" or "Black")
        else
            StatusTurn.Text = "Turn: idle / game over"
            StatusColor.Text = "You: --"
        end

        if forceAnalyze then
            forceAnalyze = false
        end

        if activeTab == "Engine"
            and (AUTO_ANALYZE or _G.__itnoxifyAutoPlay == true)
            and session and not session.over
            and session.viewPly == #session.ucis
            and session:isMyTurn()
            and not busy then
            runAnalysis(false)
        end
    end
    _G.__itnoxifyRunning = nil
end)

print("[itnoxify] ready")
