-- ============================================
-- ORDINARYSCRIPT v5.3 - MOBILE (FIXED MINIMIZE BUTTON)
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local AttackRemote = ReplicatedStorage.Systems.ActionsSystem.Network.Attack

-- Find Consume remote
local function findRemote(obj, name)
    if not obj then return nil end
    for _, child in ipairs(obj:GetChildren() or {}) do
        if child:IsA("RemoteFunction") and child.Name == name then return child end
        local found = findRemote(child, name)
        if found then return found end
    end
    return nil
end
local consumeRemote = findRemote(ReplicatedStorage, "Consume")

-- ===========================
-- OWNER & WHITELIST
-- ===========================
local OWNER_NAME = "VKRISTRUE"
local protectedPlayers = {
    ["david12wee123"] = true, ["peeds001"] = true, ["omyimpro"] = true,
    ["caandyyy7"] = true, ["saitama_e6"] = true, ["sreekesh65"] = true,
    ["raizellll2"] = true, ["jl_ph102"] = true, ["andrew_anderson5"] = true,
    ["evelynisasuzy"] = true, ["mymaingotbanned10"] = true, ["hghfhrhdthereal"] = true,
    ["toto052pogi1234"] = true, ["Olliebob234567backup"] = true, ["tuhzu30mnek"] = true,
    ["inuuaya"] = true, ["Kalleanka12305"] = true, ["No122947"] = true, ["Robin_1212342"] = true,
}

local function isOwner(p) return p and p.Name == OWNER_NAME end
local function isProtected(p) return p and (isOwner(p) or protectedPlayers[p.Name]) end

-- ===========================
-- CONFIGURATION
-- ===========================
local killAuraActive = false
local attackCycleConn = nil
local spinning = false
local spinCoroutine = nil
local espEnabled = false
local espBillboards = {}
local espScanning = true
local antiAttachment = true
local autoTPEnabled = true
local autoHealEnabled = true
local walkspeedEnabled = false
local flying = false
local flyBodyVelocity = nil
local flyBodyGyro = nil

local range = 68
local attackIndex = 1
local healthThreshold = 8
local tpDistance = 600
local tpUpward = 80
local lastTPTime = 0
local tpCooldown = 8
local targetWalkspeed = 50
local walkspeedLoop = nil
local flySpeed = 100
local healingLock = false
local isTeleporting = false
local deathMarkers = {}
local spawnMarker = nil
local spawnPosition = nil
local displayedHealth = nil

-- Mobile movement
local moveDirection = Vector3.new()
local moveUp = false
local moveDown = false

-- Minimize variables
local mainFrame = nil
local minimizedButton = nil
local isMinimized = false
local savedPosition = nil

-- ===========================
-- MARKER SYSTEMS
-- ===========================
local function createDeathMarker(pos)
    local part = Instance.new("Part")
    part.Size = Vector3.new(2, 0.5, 2)
    part.Position = pos
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.new("Really black")
    part.Material = Enum.Material.Neon
    part.Transparency = 0.3
    part.Parent = Workspace
    local bill = Instance.new("BillboardGui")
    bill.AlwaysOnTop = true
    bill.Size = UDim2.new(0, 80, 0, 80)
    bill.StudsOffset = Vector3.new(0, 3, 0)
    bill.Parent = part
    local skull = Instance.new("TextLabel")
    skull.Size = UDim2.new(1, 0, 1, 0)
    skull.BackgroundTransparency = 1
    skull.Text = "💀"
    skull.TextScaled = true
    skull.Font = Enum.Font.GothamBold
    skull.Parent = bill
    table.insert(deathMarkers, part)
    task.delay(300, function() pcall(function() part:Destroy() end) end)
    return part
end

local function createSpawnMarker(pos)
    spawnPosition = pos
    if spawnMarker then pcall(function() spawnMarker:Destroy() end) end
    local part = Instance.new("Part")
    part.Size = Vector3.new(3, 1, 3)
    part.Position = pos
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.new("Lime green")
    part.Material = Enum.Material.Neon
    part.Transparency = 0.3
    part.Parent = Workspace
    local bill = Instance.new("BillboardGui")
    bill.AlwaysOnTop = true
    bill.Size = UDim2.new(0, 80, 0, 80)
    bill.StudsOffset = Vector3.new(0, 3, 0)
    bill.Parent = part
    local emoji = Instance.new("TextLabel")
    emoji.Size = UDim2.new(1, 0, 1, 0)
    emoji.BackgroundTransparency = 1
    emoji.Text = "🏠"
    emoji.TextScaled = true
    emoji.Font = Enum.Font.GothamBold
    emoji.Parent = bill
    spawnMarker = part
    return part
end

local function teleportToSpawn()
    if not spawnPosition then print("[SPAWN] No spawn set") return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        createDeathMarker(root.Position)
        root.CFrame = CFrame.new(spawnPosition)
        print("[SPAWN] Teleported")
    end
end

local function teleportToSafety()
    if isTeleporting then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if tick() - lastTPTime < tpCooldown then return end
    isTeleporting = true
    local dir = Camera.CFrame.LookVector
    if dir.Magnitude < 0.1 then dir = root.CFrame.LookVector end
    local newPos = root.Position + (-dir * tpDistance) + Vector3.new(0, tpUpward, 0)
    createDeathMarker(root.Position)
    root.CFrame = CFrame.new(newPos)
    lastTPTime = tick()
    task.wait(0.2)
    isTeleporting = false
end

local function findFoodSlot()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local master = gui:FindFirstChild("MasterScreenGui")
    if not master then return nil end
    local hotbar = master:FindFirstChild("Hotbar")
    if not hotbar then return nil end
    local bestSlot, bestQty = nil, 0
    for i = 1, 9 do
        local slot = hotbar:FindFirstChild(tostring(i))
        if slot and slot:IsA("ImageButton") then
            local qtyLbl = slot:FindFirstChild("QtyLabel")
            if qtyLbl and qtyLbl:IsA("TextLabel") then
                local qty = tonumber(qtyLbl.Text) or 0
                if qty > bestQty then bestSlot, bestQty = i, qty end
            end
        end
    end
    return bestSlot, bestQty
end

local function eatFood()
    if healingLock or not consumeRemote then return false end
    local slot = findFoodSlot()
    if not slot then return false end
    healingLock = true
    local s = pcall(function() consumeRemote:InvokeServer(slot) end)
    healingLock = false
    return s
end

-- ===========================
-- KILL AURA
-- ===========================
local function isAttached(target)
    if isProtected(target) then return false end
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or not tRoot then return false end
    local dist = (myRoot.Position - tRoot.Position).Magnitude
    local dot = myRoot.CFrame.LookVector:Dot((tRoot.Position - myRoot.Position).Unit)
    return dist <= 8 and dot < -0.3
end

local function getTargets()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("Humanoid") or myChar.Humanoid.Health <= 0 then return {} end
    local myPos = myChar.HumanoidRootPart.Position
    local targets = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not isProtected(p) then
            local char = p.Character
            if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                local dist = (char.HumanoidRootPart.Position - myPos).Magnitude
                if dist <= range then table.insert(targets, char) end
            end
        end
    end
    return targets
end

local function attackTarget(t)
    if not t then return end
    pcall(function() AttackRemote:InvokeServer(t, attackIndex) end)
    attackIndex = attackIndex == 1 and 2 or 1
end

local function attackAll()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not isProtected(p) and isAttached(p) and p.Character then
            attackTarget(p.Character)
        end
    end
    for _, t in ipairs(getTargets()) do attackTarget(t) end
end

local function toggleKA()
    killAuraActive = not killAuraActive
    if killAuraActive then
        if attackCycleConn then attackCycleConn:Disconnect() end
        attackCycleConn = RunService.RenderStepped:Connect(attackAll)
    else
        if attackCycleConn then attackCycleConn:Disconnect(); attackCycleConn = nil end
    end
end

-- ===========================
-- ESP SYSTEM
-- ===========================
local function createESP(p)
    if not p or p == LocalPlayer or not espEnabled then return end
    if espBillboards[p] then
        for _, v in ipairs(espBillboards[p]) do pcall(function() v:Destroy() end) end
        espBillboards[p] = nil
    end
    if not p.Character then return end
    local root = p.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 140, 0, 50)
    bill.StudsOffset = Vector3.new(0, 3, 0)
    bill.MaxDistance = 1000
    bill.Adornee = root
    bill.Parent = root
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 2
    frame.Parent = bill
    
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = p.Name
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 14
    nameLbl.Parent = frame
    
    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, 0, 0.45, 0)
    infoLbl.Position = UDim2.new(0, 0, 0.55, 0)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Font = Enum.Font.Gotham
    infoLbl.TextSize = 11
    infoLbl.Parent = frame
    
    espBillboards[p] = {bill, frame, nameLbl, infoLbl}
    
    local conn = RunService.RenderStepped:Connect(function()
        if not bill or not bill.Parent then return end
        local myChar = LocalPlayer.Character
        local tRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if myChar and myChar:FindFirstChild("HumanoidRootPart") and tRoot then
            local dist = (myChar.HumanoidRootPart.Position - tRoot.Position).Magnitude
            local health = p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health or 0
            infoLbl.Text = string.format("🎯%.0fm|❤️%.0f", dist, health/2)
            
            if isOwner(p) then
                frame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
                nameLbl.Text = "👑"..p.Name.."👑"
            elseif isProtected(p) then
                frame.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
                nameLbl.Text = p.Name.."🤝"
            elseif isAttached(p) then
                frame.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                nameLbl.Text = p.Name.."🔗"
            elseif dist <= range then
                frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            else
                frame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            end
            nameLbl.TextColor3 = Color3.fromRGB(255,255,255)
        end
    end)
    espBillboards[p][5] = conn
end

local function refreshESP()
    if not espEnabled then
        for p,_ in pairs(espBillboards) do
            if espBillboards[p] and espBillboards[p][5] then pcall(function() espBillboards[p][5]:Disconnect() end) end
            for i=1,4 do pcall(function() if espBillboards[p] and espBillboards[p][i] then espBillboards[p][i]:Destroy() end end) end
            espBillboards[p] = nil
        end
        return
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if not espBillboards[p] then createESP(p)
            elseif p.Character and espBillboards[p][1] and espBillboards[p][1].Adornee ~= p.Character:FindFirstChild("HumanoidRootPart") then createESP(p) end
        end
    end
    for p,_ in pairs(espBillboards) do if not p or not p.Parent then
        if espBillboards[p] and espBillboards[p][5] then pcall(function() espBillboards[p][5]:Disconnect() end) end
        for i=1,4 do pcall(function() if espBillboards[p] and espBillboards[p][i] then espBillboards[p][i]:Destroy() end end) end
        espBillboards[p] = nil
    end end
end

local function toggleESP()
    espEnabled = not espEnabled
    if espEnabled then
        for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer then createESP(p) end end
    else
        for p,_ in pairs(espBillboards) do
            if espBillboards[p] and espBillboards[p][5] then pcall(function() espBillboards[p][5]:Disconnect() end) end
            for i=1,4 do pcall(function() if espBillboards[p] and espBillboards[p][i] then espBillboards[p][i]:Destroy() end end) end
            espBillboards[p] = nil
        end
    end
end

-- ===========================
-- FLIGHT SYSTEM
-- ===========================
local function updateFlight()
    if not flying then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local cam = Workspace.CurrentCamera
    local move = (cam.CFrame.RightVector * moveDirection.X) + (cam.CFrame.LookVector * -moveDirection.Z)
    if move.Magnitude > 0 then move = move.Unit end
    if moveUp then move = move + Vector3.new(0,1,0) end
    if moveDown then move = move - Vector3.new(0,1,0) end
    
    if move.Magnitude > 0 then
        if flyBodyVelocity then flyBodyVelocity.Velocity = move * flySpeed end
    elseif flyBodyVelocity then
        flyBodyVelocity.Velocity = Vector3.new(0,0,0)
    end
    if flyBodyGyro then flyBodyGyro.CFrame = cam.CFrame end
    local hum = char:FindFirstChild("Humanoid")
    if hum then hum.PlatformStand = true end
end

local function toggleFlight()
    flying = not flying
    if flying then
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                if flyBodyVelocity then flyBodyVelocity:Destroy() end
                if flyBodyGyro then flyBodyGyro:Destroy() end
                flyBodyVelocity = Instance.new("BodyVelocity")
                flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyVelocity.Parent = root
                flyBodyGyro = Instance.new("BodyGyro")
                flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyGyro.P = 10000
                flyBodyGyro.Parent = root
            end
            local hum = char:FindFirstChild("Humanoid")
            if hum then hum.PlatformStand = true end
        end
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end
end

-- ===========================
-- JOYSTICK CONTROLS
-- ===========================
local function setupMobileControls()
    local joystick = Instance.new("Frame")
    joystick.Size = UDim2.new(0, 120, 0, 120)
    joystick.Position = UDim2.new(0, 15, 1, -135)
    joystick.BackgroundColor3 = Color3.fromRGB(40,40,50)
    joystick.BackgroundTransparency = 0.6
    joystick.BorderSizePixel = 2
    joystick.BorderColor3 = Color3.fromRGB(255,100,100)
    joystick.Visible = false
    joystick.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 45, 0, 45)
    knob.Position = UDim2.new(0.5, -22, 0.5, -22)
    knob.BackgroundColor3 = Color3.fromRGB(255,100,100)
    knob.BorderSizePixel = 0
    knob.Parent = joystick
    
    local active, startPos = false
    joystick.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then
            active = true
            startPos = inp.Position
        end
    end)
    
    joystick.InputChanged:Connect(function(inp)
        if active and inp.UserInputType == Enum.UserInputType.Touch then
            local delta = inp.Position - startPos
            local maxDist = 40
            local dist = math.min(delta.Magnitude, maxDist)
            local angle = math.atan2(delta.Y, delta.X)
            local newX = math.cos(angle) * dist
            local newY = math.sin(angle) * dist
            knob.Position = UDim2.new(0.5, -22 + newX, 0.5, -22 + newY)
            moveDirection = Vector3.new(newX/maxDist, 0, newY/maxDist)
        end
    end)
    
    joystick.InputEnded:Connect(function(inp)
        if active and inp.UserInputType == Enum.UserInputType.Touch then
            active = false
            knob.Position = UDim2.new(0.5, -22, 0.5, -22)
            moveDirection = Vector3.new()
        end
    end)
    
    local upBtn = Instance.new("TextButton")
    upBtn.Size = UDim2.new(0, 55, 0, 55)
    upBtn.Position = UDim2.new(1, -70, 1, -125)
    upBtn.Text = "▲"
    upBtn.TextSize = 24
    upBtn.BackgroundColor3 = Color3.fromRGB(0,100,150)
    upBtn.BorderSizePixel = 0
    upBtn.Visible = false
    upBtn.Parent = LocalPlayer:WaitForChild("PlayerGui")
    upBtn.MouseButton1Down:Connect(function() moveUp = true end)
    upBtn.MouseButton1Up:Connect(function() moveUp = false end)
    
    local downBtn = Instance.new("TextButton")
    downBtn.Size = UDim2.new(0, 55, 0, 55)
    downBtn.Position = UDim2.new(1, -70, 1, -60)
    downBtn.Text = "▼"
    downBtn.TextSize = 24
    downBtn.BackgroundColor3 = Color3.fromRGB(150,50,50)
    downBtn.BorderSizePixel = 0
    downBtn.Visible = false
    downBtn.Parent = LocalPlayer:WaitForChild("PlayerGui")
    downBtn.MouseButton1Down:Connect(function() moveDown = true end)
    downBtn.MouseButton1Up:Connect(function() moveDown = false end)
    
    local function updateVis()
        local v = flying
        joystick.Visible = v
        upBtn.Visible = v
        downBtn.Visible = v
    end
    local ot = toggleFlight
    toggleFlight = function() ot(); updateVis() end
end

-- ===========================
-- HEALTH MONITOR
-- ===========================
local function setupHealth()
    local gui = LocalPlayer:WaitForChild("PlayerGui", 10)
    local master = gui:WaitForChild("MasterScreenGui", 10)
    local hotbar = master:WaitForChild("Hotbar", 10)
    displayedHealth = hotbar:WaitForChild("DisplayedHealth", 10)
    local last = displayedHealth.Value
    RunService.RenderStepped:Connect(function()
        if not displayedHealth then return end
        local cur = displayedHealth.Value
        if autoTPEnabled and not isTeleporting and cur < healthThreshold and last >= healthThreshold then teleportToSafety()
        elseif autoTPEnabled and last - cur >= 4 and cur < 14 then teleportToSafety() end
        if autoHealEnabled and cur < last and cur < 16 then eatFood()
        elseif autoHealEnabled and cur < 12 and cur < last then eatFood() end
        last = cur
    end)
end

-- ===========================
-- MOBILE GUI with CORRECT MINIMIZE BUTTON
-- ===========================
local function createMobileGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "OrdinaryScript"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitF    ["evelynisasuzy"] = true, ["mymaingotbanned10"] = true, ["hghfhrhdthereal"] = true,
    ["toto052pogi1234"] = true, ["Olliebob234567backup"] = true, ["tuhzu30mnek"] = true,
    ["inuuaya"] = true, ["Kalleanka12305"] = true, ["No122947"] = true, ["Robin_1212342"] = true,
}

local function isOwner(p) return p and p.Name == OWNER_NAME end
local function isProtected(p) return p and (isOwner(p) or protectedPlayers[p.Name]) end

-- ===========================
-- CONFIGURATION
-- ===========================
local killAuraActive = false
local attackCycleConn = nil
local spinning = false
local spinCoroutine = nil
local espEnabled = false
local espBillboards = {}
local espScanning = true
local antiAttachment = true
local autoTPEnabled = true
local autoHealEnabled = true
local walkspeedEnabled = false
local flying = false
local flyBodyVelocity = nil
local flyBodyGyro = nil

local range = 68
local attackIndex = 1
local healthThreshold = 8
local tpDistance = 600
local tpUpward = 80
local lastTPTime = 0
local tpCooldown = 8
local targetWalkspeed = 50
local walkspeedLoop = nil
local flySpeed = 100
local healingLock = false
local isTeleporting = false
local deathMarkers = {}
local spawnMarker = nil
local spawnPosition = nil
local displayedHealth = nil

-- Mobile movement
local moveDirection = Vector3.new()
local moveUp = false
local moveDown = false
local minimizedPos = nil
local isMinimized = false

-- ===========================
-- MARKER SYSTEMS
-- ===========================
local function createDeathMarker(pos)
    local part = Instance.new("Part")
    part.Size = Vector3.new(2, 0.5, 2)
    part.Position = pos
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.new("Really black")
    part.Material = Enum.Material.Neon
    part.Transparency = 0.3
    part.Parent = Workspace
    local bill = Instance.new("BillboardGui")
    bill.AlwaysOnTop = true
    bill.Size = UDim2.new(0, 80, 0, 80)
    bill.StudsOffset = Vector3.new(0, 3, 0)
    bill.Parent = part
    local skull = Instance.new("TextLabel")
    skull.Size = UDim2.new(1, 0, 1, 0)
    skull.BackgroundTransparency = 1
    skull.Text = "💀"
    skull.TextScaled = true
    skull.Font = Enum.Font.GothamBold
    skull.Parent = bill
    table.insert(deathMarkers, part)
    task.delay(300, function() pcall(function() part:Destroy() end) end)
    return part
end

local function createSpawnMarker(pos)
    spawnPosition = pos
    if spawnMarker then pcall(function() spawnMarker:Destroy() end) end
    local part = Instance.new("Part")
    part.Size = Vector3.new(3, 1, 3)
    part.Position = pos
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.new("Lime green")
    part.Material = Enum.Material.Neon
    part.Transparency = 0.3
    part.Parent = Workspace
    local bill = Instance.new("BillboardGui")
    bill.AlwaysOnTop = true
    bill.Size = UDim2.new(0, 80, 0, 80)
    bill.StudsOffset = Vector3.new(0, 3, 0)
    bill.Parent = part
    local emoji = Instance.new("TextLabel")
    emoji.Size = UDim2.new(1, 0, 1, 0)
    emoji.BackgroundTransparency = 1
    emoji.Text = "🏠"
    emoji.TextScaled = true
    emoji.Font = Enum.Font.GothamBold
    emoji.Parent = bill
    spawnMarker = part
    return part
end

local function teleportToSpawn()
    if not spawnPosition then print("[SPAWN] No spawn set") return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        createDeathMarker(root.Position)
        root.CFrame = CFrame.new(spawnPosition)
        print("[SPAWN] Teleported")
    end
end

local function teleportToSafety()
    if isTeleporting then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if tick() - lastTPTime < tpCooldown then return end
    isTeleporting = true
    local dir = Camera.CFrame.LookVector
    if dir.Magnitude < 0.1 then dir = root.CFrame.LookVector end
    local newPos = root.Position + (-dir * tpDistance) + Vector3.new(0, tpUpward, 0)
    createDeathMarker(root.Position)
    root.CFrame = CFrame.new(newPos)
    lastTPTime = tick()
    task.wait(0.2)
    isTeleporting = false
end

local function findFoodSlot()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local master = gui:FindFirstChild("MasterScreenGui")
    if not master then return nil end
    local hotbar = master:FindFirstChild("Hotbar")
    if not hotbar then return nil end
    local bestSlot, bestQty = nil, 0
    for i = 1, 9 do
        local slot = hotbar:FindFirstChild(tostring(i))
        if slot and slot:IsA("ImageButton") then
            local qtyLbl = slot:FindFirstChild("QtyLabel")
            if qtyLbl and qtyLbl:IsA("TextLabel") then
                local qty = tonumber(qtyLbl.Text) or 0
                if qty > bestQty then bestSlot, bestQty = i, qty end
            end
        end
    end
    return bestSlot, bestQty
end

local function eatFood()
    if healingLock or not consumeRemote then return false end
    local slot = findFoodSlot()
    if not slot then return false end
    healingLock = true
    local s = pcall(function() consumeRemote:InvokeServer(slot) end)
    healingLock = false
    return s
end

-- ===========================
-- KILL AURA
-- ===========================
local function isAttached(target)
    if isProtected(target) then return false end
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or not tRoot then return false end
    local dist = (myRoot.Position - tRoot.Position).Magnitude
    local dot = myRoot.CFrame.LookVector:Dot((tRoot.Position - myRoot.Position).Unit)
    return dist <= 8 and dot < -0.3
end

local function getTargets()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("Humanoid") or myChar.Humanoid.Health <= 0 then return {} end
    local myPos = myChar.HumanoidRootPart.Position
    local targets = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not isProtected(p) then
            local char = p.Character
            if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                local dist = (char.HumanoidRootPart.Position - myPos).Magnitude
                if dist <= range then table.insert(targets, char) end
            end
        end
    end
    return targets
end

local function attackTarget(t)
    if not t then return end
    pcall(function() AttackRemote:InvokeServer(t, attackIndex) end)
    attackIndex = attackIndex == 1 and 2 or 1
end

local function attackAll()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not isProtected(p) and isAttached(p) and p.Character then
            attackTarget(p.Character)
        end
    end
    for _, t in ipairs(getTargets()) do attackTarget(t) end
end

local function toggleKA()
    killAuraActive = not killAuraActive
    if killAuraActive then
        if attackCycleConn then attackCycleConn:Disconnect() end
        attackCycleConn = RunService.RenderStepped:Connect(attackAll)
    else
        if attackCycleConn then attackCycleConn:Disconnect(); attackCycleConn = nil end
    end
end

-- ===========================
-- ESP SYSTEM
-- ===========================
local function createESP(p)
    if not p or p == LocalPlayer or not espEnabled then return end
    if espBillboards[p] then
        for _, v in ipairs(espBillboards[p]) do pcall(function() v:Destroy() end) end
        espBillboards[p] = nil
    end
    if not p.Character then return end
    local root = p.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 140, 0, 50)
    bill.StudsOffset = Vector3.new(0, 3, 0)
    bill.MaxDistance = 1000
    bill.Adornee = root
    bill.Parent = root
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 2
    frame.Parent = bill
    
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = p.Name
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 14
    nameLbl.Parent = frame
    
    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, 0, 0.45, 0)
    infoLbl.Position = UDim2.new(0, 0, 0.55, 0)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Font = Enum.Font.Gotham
    infoLbl.TextSize = 11
    infoLbl.Parent = frame
    
    espBillboards[p] = {bill, frame, nameLbl, infoLbl}
    
    local conn = RunService.RenderStepped:Connect(function()
        if not bill or not bill.Parent then return end
        local myChar = LocalPlayer.Character
        local tRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if myChar and myChar:FindFirstChild("HumanoidRootPart") and tRoot then
            local dist = (myChar.HumanoidRootPart.Position - tRoot.Position).Magnitude
            local health = p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health or 0
            infoLbl.Text = string.format("🎯%.0fm|❤️%.0f", dist, health/2)
            
            if isOwner(p) then
                frame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
                nameLbl.Text = "👑"..p.Name.."👑"
            elseif isProtected(p) then
                frame.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
                nameLbl.Text = p.Name.."🤝"
            elseif isAttached(p) then
                frame.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
                nameLbl.Text = p.Name.."🔗"
            elseif dist <= range then
                frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            else
                frame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            end
            nameLbl.TextColor3 = Color3.fromRGB(255,255,255)
        end
    end)
    espBillboards[p][5] = conn
end

local function refreshESP()
    if not espEnabled then
        for p,_ in pairs(espBillboards) do
            if espBillboards[p] and espBillboards[p][5] then pcall(function() espBillboards[p][5]:Disconnect() end) end
            for i=1,4 do pcall(function() if espBillboards[p] and espBillboards[p][i] then espBillboards[p][i]:Destroy() end end) end
            espBillboards[p] = nil
        end
        return
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if not espBillboards[p] then createESP(p)
            elseif p.Character and espBillboards[p][1] and espBillboards[p][1].Adornee ~= p.Character:FindFirstChild("HumanoidRootPart") then createESP(p) end
        end
    end
    for p,_ in pairs(espBillboards) do if not p or not p.Parent then
        if espBillboards[p] and espBillboards[p][5] then pcall(function() espBillboards[p][5]:Disconnect() end) end
        for i=1,4 do pcall(function() if espBillboards[p] and espBillboards[p][i] then espBillboards[p][i]:Destroy() end end) end
        espBillboards[p] = nil
    end end
end

local function toggleESP()
    espEnabled = not espEnabled
    if espEnabled then
        for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer then createESP(p) end end
    else
        for p,_ in pairs(espBillboards) do
            if espBillboards[p] and espBillboards[p][5] then pcall(function() espBillboards[p][5]:Disconnect() end) end
            for i=1,4 do pcall(function() if espBillboards[p] and espBillboards[p][i] then espBillboards[p][i]:Destroy() end end) end
            espBillboards[p] = nil
        end
    end
end

-- ===========================
-- FLIGHT SYSTEM
-- ===========================
local function updateFlight()
    if not flying then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local cam = Workspace.CurrentCamera
    local move = (cam.CFrame.RightVector * moveDirection.X) + (cam.CFrame.LookVector * -moveDirection.Z)
    if move.Magnitude > 0 then move = move.Unit end
    if moveUp then move = move + Vector3.new(0,1,0) end
    if moveDown then move = move - Vector3.new(0,1,0) end
    
    if move.Magnitude > 0 then
        if flyBodyVelocity then flyBodyVelocity.Velocity = move * flySpeed end
    elseif flyBodyVelocity then
        flyBodyVelocity.Velocity = Vector3.new(0,0,0)
    end
    if flyBodyGyro then flyBodyGyro.CFrame = cam.CFrame end
    local hum = char:FindFirstChild("Humanoid")
    if hum then hum.PlatformStand = true end
end

local function toggleFlight()
    flying = not flying
    if flying then
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                if flyBodyVelocity then flyBodyVelocity:Destroy() end
                if flyBodyGyro then flyBodyGyro:Destroy() end
                flyBodyVelocity = Instance.new("BodyVelocity")
                flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyVelocity.Parent = root
                flyBodyGyro = Instance.new("BodyGyro")
                flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyGyro.P = 10000
                flyBodyGyro.Parent = root
            end
            local hum = char:FindFirstChild("Humanoid")
            if hum then hum.PlatformStand = true end
        end
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end
end

-- ===========================
-- JOYSTICK CONTROLS
-- ===========================
local function setupMobileControls()
    local joystick = Instance.new("Frame")
    joystick.Size = UDim2.new(0, 120, 0, 120)
    joystick.Position = UDim2.new(0, 15, 1, -135)
    joystick.BackgroundColor3 = Color3.fromRGB(40,40,50)
    joystick.BackgroundTransparency = 0.6
    joystick.BorderSizePixel = 2
    joystick.BorderColor3 = Color3.fromRGB(255,100,100)
    joystick.Visible = false
    joystick.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 45, 0, 45)
    knob.Position = UDim2.new(0.5, -22, 0.5, -22)
    knob.BackgroundColor3 = Color3.fromRGB(255,100,100)
    knob.BorderSizePixel = 0
    knob.Parent = joystick
    
    local active, startPos = false
    joystick.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then
            active = true
            startPos = inp.Position
        end
    end)
    
    joystick.InputChanged:Connect(function(inp)
        if active and inp.UserInputType == Enum.UserInputType.Touch then
            local delta = inp.Position - startPos
            local maxDist = 40
            local dist = math.min(delta.Magnitude, maxDist)
            local angle = math.atan2(delta.Y, delta.X)
            local newX = math.cos(angle) * dist
            local newY = math.sin(angle) * dist
            knob.Position = UDim2.new(0.5, -22 + newX, 0.5, -22 + newY)
            moveDirection = Vector3.new(newX/maxDist, 0, newY/maxDist)
        end
    end)
    
    joystick.InputEnded:Connect(function(inp)
        if active and inp.UserInputType == Enum.UserInputType.Touch then
            active = false
            knob.Position = UDim2.new(0.5, -22, 0.5, -22)
            moveDirection = Vector3.new()
        end
    end)
    
    local upBtn = Instance.new("TextButton")
    upBtn.Size = UDim2.new(0, 55, 0, 55)
    upBtn.Position = UDim2.new(1, -70, 1, -125)
    upBtn.Text = "▲"
    upBtn.TextSize = 24
    upBtn.BackgroundColor3 = Color3.fromRGB(0,100,150)
    upBtn.BorderSizePixel = 0
    upBtn.Visible = false
    upBtn.Parent = LocalPlayer:WaitForChild("PlayerGui")
    upBtn.MouseButton1Down:Connect(function() moveUp = true end)
    upBtn.MouseButton1Up:Connect(function() moveUp = false end)
    
    local downBtn = Instance.new("TextButton")
    downBtn.Size = UDim2.new(0, 55, 0, 55)
    downBtn.Position = UDim2.new(1, -70, 1, -60)
    downBtn.Text = "▼"
    downBtn.TextSize = 24
    downBtn.BackgroundColor3 = Color3.fromRGB(150,50,50)
    downBtn.BorderSizePixel = 0
    downBtn.Visible = false
    downBtn.Parent = LocalPlayer:WaitForChild("PlayerGui")
    downBtn.MouseButton1Down:Connect(function() moveDown = true end)
    downBtn.MouseButton1Up:Connect(function() moveDown = false end)
    
    local function updateVis()
        local v = flying
        joystick.Visible = v
        upBtn.Visible = v
        downBtn.Visible = v
    end
    local ot = toggleFlight
    toggleFlight = function() ot(); updateVis() end
end

-- ===========================
-- HEALTH MONITOR
-- ===========================
local function setupHealth()
    local gui = LocalPlayer:WaitForChild("PlayerGui", 10)
    local master = gui:WaitForChild("MasterScreenGui", 10)
    local hotbar = master:WaitForChild("Hotbar", 10)
    displayedHealth = hotbar:WaitForChild("DisplayedHealth", 10)
    local last = displayedHealth.Value
    RunService.RenderStepped:Connect(function()
        if not displayedHealth then return end
        local cur = displayedHealth.Value
        if autoTPEnabled and not isTeleporting and cur < healthThreshold and last >= healthThreshold then teleportToSafety()
        elseif autoTPEnabled and last - cur >= 4 and cur < 14 then teleportToSafety() end
        if autoHealEnabled and cur < last and cur < 16 then eatFood()
        elseif autoHealEnabled and cur < 12 and cur < last then eatFood() end
        last = cur
    end)
end

-- ===========================
-- MOBILE GUI (COMPACT)
-- ===========================
local function createMobileGUI()
    local scr = Instance.new("ScreenGui")
    scr.Name = "OrdinaryScript"
    scr.ResetOnSpawn = false
    scr.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, 350)
    mainFrame.Position = minimizedPos or UDim2.new(0.5, -140, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20,20,25)
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 1
    mainFrame.BorderColor3 = Color3.fromRGB(255,100,100)
    mainFrame.ClipsDescendants = true
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = scr
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(30,30,40)
    titleBar.BackgroundTransparency = 0.3
    titleBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "⚡ ORDINARY"
    title.TextColor3 = Color3.fromRGB(255,100,100)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    title.Parent = titleBar
    
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -35, 0, 2)
    minBtn.Text = "−"
    minBtn.TextColor3 = Color3.fromRGB(255,255,255)
    minBtn.BackgroundColor3 = Color3.fromRGB(50,50,60)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 16
    minBtn.Parent = titleBar
    
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, 0, 0, 30)
    tabBar.Position = UDim2.new(0, 0, 0, 35)
    tabBar.BackgroundColor3 = Color3.fromRGB(25,25,30)
    tabBar.BackgroundTransparency = 0.3
    tabBar.Parent = mainFrame
    
    local tabs = {"⚔️", "🏃", "🛠️", "👥"}
    local tabNames = {"COMBAT", "MOVEMENT", "UTILITY", "PLAYERS"}
    local tabBtns = {}
    local currentTab = "COMBAT"
    
    local container = Instance.new("ScrollingFrame")
    container.Size = UDim2.new(1, -10, 1, -75)
    container.Position = UDim2.new(0, 5, 0, 70)
    container.BackgroundTransparency = 1
    container.ScrollBarThickness = 3
    container.CanvasSize = UDim2.new(0, 0, 0, 0)
    container.Parent = mainFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = container
    
    -- Helper: Toggle button
    local function addToggle(text, state, cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 38)
        btn.Text = text .. (state and " ✓" or " ✗")
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.BackgroundColor3 = state and Color3.fromRGB(0,130,0) or Color3.fromRGB(55,55,65)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.Parent = container
        local s = state
        btn.MouseButton1Click:Connect(function()
            s = not s
            btn.Text = text .. (s and " ✓" or " ✗")
            btn.BackgroundColor3 = s and Color3.fromRGB(0,130,0) or Color3.fromRGB(55,55,65)
            cb(s)
        end)
    end
    
    -- Helper: Slider (FIXED)
    local function addSlider(text, min, max, val, cb)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 60)
        frame.BackgroundColor3 = Color3.fromRGB(40,40,50)
        frame.Parent = container
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 5, 0, 5)
        label.Text = text..": "..val
        label.TextColor3 = Color3.fromRGB(255,255,255)
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Parent = frame
        
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, -20, 0, 4)
        bar.Position = UDim2.new(0, 10, 0, 35)
        bar.BackgroundColor3 = Color3.fromRGB(80,80,100)
        bar.Parent = frame
        
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((val-min)/(max-min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(255,100,100)
        fill.Parent = bar
        
        local dragging = false
        local dragConn, endConn, changeConn
        
        local function startDrag()
            dragging = true
        end
        
        local function endDrag()
            dragging = false
        end
        
        local function updateDrag(inp)
            if dragging and inp.UserInputType == Enum.UserInputType.Touch then
                local x = math.clamp(inp.Position.X - bar.AbsolutePosition.X, 0, bar.AbsoluteSize.X)
                local newVal = min + (x / bar.AbsoluteSize.X) * (max - min)
                newVal = math.floor(newVal)
                fill.Size = UDim2.new((newVal-min)/(max-min), 0, 1, 0)
                label.Text = text..": "..newVal
                cb(newVal)
            end
        end
        
        fill.MouseButton1Down:Connect(startDrag)
        dragConn = UserInputService.InputChanged:Connect(updateDrag)
        endConn = UserInputService.InputEnded:Connect(endDrag)
    end
    
    -- Helper: Button
    local function addButton(text, color, cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 38)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.BackgroundColor3 = color
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.Parent = container
        btn.MouseButton1Click:Connect(cb)
    end
    
    -- Build tabs
    local function buildCombat()
        addToggle("KILL AURA", killAuraActive, function(s) toggleKA() end)
        addToggle("SPIN", spinning, function(s)
            spinning = s
            if spinning and not spinCoroutine then
                spinCoroutine = coroutine.create(function()
                    local a,t,d = 0,0,1
                    while spinning do
                        local char = LocalPlayer.Character
                        if char and char:FindFirstChild("HumanoidRootPart") then
                            local root = char.HumanoidRootPart
                            a = a + 60
                            t = t + (d*5)
                            if math.abs(t) > 15 then d = -d end
                            root.CFrame = root.CFrame * CFrame.Angles(math.rad(t), math.rad(a), math.rad(t*0.5))
                        end
                        task.wait(0.016)
                    end
                    spinCoroutine = nil
                end)
                coroutine.resume(spinCoroutine)
            end
        end)
        addToggle("ANTI-ATTACH", antiAttachment, function(s) antiAttachment = s end)
        addToggle("AUTO-TP", autoTPEnabled, function(s) autoTPEnabled = s end)
        addToggle("AUTO-HEAL", autoHealEnabled, function(s) autoHealEnabled = s end)
        addToggle("ESP", espEnabled, function(s) toggleESP() end)
        addSlider("RANGE", 30, 120, range, function(v) range = v end)
    end
    
    local function buildMovement()
        addToggle("FLIGHT", flying, function(s) toggleFlight() end)
        addSlider("FLY SPEED", 50, 400, flySpeed, function(v) flySpeed = v end)
        addToggle("SPEED", walkspeedEnabled, function(s)
            walkspeedEnabled = s
            if walkspeedLoop then walkspeedLoop:Disconnect() end
            if s then
                walkspeedLoop = RunService.Heartbeat:Connect(function()
                    local char = LocalPlayer.Character
                    if char then
                        local hum = char:FindFirstChild("Humanoid")
                        if hum and hum.WalkSpeed ~= targetWalkspeed then hum.WalkSpeed = targetWalkspeed end
                    end
                end)
            else
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    if hum then hum.WalkSpeed = 16 end
                end
            end
        end)
        addSlider("SPEED VAL", 16, 200, targetWalkspeed, function(v)
            targetWalkspeed = v
            if walkspeedEnabled then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") then
                    char.Humanoid.WalkSpeed = v
                end
            end
        end)
        addButton("💚 MANUAL HEAL", Color3.fromRGB(100,150,100), function() eatFood() end)
        addButton("🏠 TP SPAWN", Color3.fromRGB(0,100,150), function() teleportToSpawn() end)
        addButton("📍 SET SPAWN", Color3.fromRGB(0,130,0), function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                createSpawnMarker(char.HumanoidRootPart.Position)
            end
        end)
    end
    
    local function buildUtility()
        addButton("🗑️ CLEAR MARKERS", Color3.fromRGB(150,100,50), function()
            for _, m in ipairs(deathMarkers) do pcall(function() m:Destroy() end) end
            deathMarkers = {}
        end)
        addButton("🔄 RESET", Color3.fromRGB(150,50,50), function()
            range = 68
            targetWalkspeed = 50
            flySpeed = 100
            if walkspeedEnabled then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") then
                    char.Humanoid.WalkSpeed = targetWalkspeed
                end
            end
        end)
    end
    
    local function buildPlayers()
        local list = Instance.new("ScrollingFrame")
        list.Size = UDim2.new(1, 0, 1, 0)
        list.BackgroundTransparency = 1
        list.ScrollBarThickness = 3
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.Parent = container
        
        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 4)
        listLayout.Parent = list
        
        local function refresh()
            for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local frame = Instance.new("Frame")
                    frame.Size = UDim2.new(1, 0, 0, 40)
                    frame.BackgroundColor3 = Color3.fromRGB(45,45,55)
                    frame.Parent = list
                    
                    local name = Instance.new("TextLabel")
                    name.Size = UDim2.new(0.45, 0, 1, 0)
                    name.Position = UDim2.new(0, 8, 0, 0)
                    name.Text = isOwner(p) and "👑"..p.Name or p.Name
                    name.TextColor3 = isOwner(p) and Color3.fromRGB(255,215,0) or Color3.fromRGB(255,255,255)
                    name.Font = Enum.Font.GothamBold
                    name.TextSize = 11
                    name.TextXAlignment = Enum.TextXAlignment.Left
                    name.BackgroundTransparency = 1
                    name.Parent = frame
                    
                    local tp = Instance.new("TextButton")
                    tp.Size = UDim2.new(0, 50, 0, 32)
                    tp.Position = UDim2.new(0.5, -60, 0.5, -16)
                    tp.Text = "📍"
                    tp.BackgroundColor3 = isOwner(p) and Color3.fromRGB(80,80,80) or Color3.fromRGB(0,100,150)
                    tp.TextColor3 = Color3.fromRGB(255,255,255)
                    tp.Font = Enum.Font.GothamBold
                    tp.TextSize = 14
                    tp.Parent = frame
                    if not isOwner(p) then
                        tp.MouseButton1Click:Connect(function()
                            local tr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                            local mr = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if tr and mr then mr.CFrame = CFrame.new(tr.Position) end
                        end)
                    end
                    
                    local prot = Instance.new("TextButton")
                    prot.Size = UDim2.new(0, 50, 0, 32)
                    prot.Position = UDim2.new(0.75, -45, 0.5, -16)
                    prot.Text = isProtected(p) and (isOwner(p) and "👑" or "🛡️") or "○"
                    prot.BackgroundColor3 = isProtected(p) and Color3.fromRGB(0,130,0) or Color3.fromRGB(80,80,80)
                    prot.TextColor3 = Color3.fromRGB(255,255,255)
                    prot.Font = Enum.Font.GothamBold
                    prot.TextSize = 12
                    prot.Parent = frame
                    
                    if not isOwner(p) then
                        prot.MouseButton1Click:Connect(function()
                            if protectedPlayers[p.Name] then
                                protectedPlayers[p.Name] = nil
                                prot.Text = "○"
                                prot.BackgroundColor3 = Color3.fromRGB(80,80,80)
                            else
                                protectedPlayers[p.Name] = true
                                prot.Text = "🛡️"
                                prot.BackgroundColor3 = Color3.fromRGB(0,130,0)
                            end
                            refreshESP()
                            refresh()
                        end)
                    end
                end
            end
            list.CanvasSize = UDim2.new(0, 0, 0, (#Players:GetPlayers()-1)*44 + 10)
        end
        refresh()
        Players.PlayerAdded:Connect(refresh)
        Players.PlayerRemoving:Connect(refresh)
    end
    
    -- Tab switching
    local function switchTab(tab)
        currentTab = tab
        for _, c in ipairs(container:GetChildren()) do
            if c ~= layout then c:Destroy() end
        end
        if tab == "COMBAT" then buildCombat()
        elseif tab == "MOVEMENT" then buildMovement()
        elseif tab == "UTILITY" then buildUtility()
        elseif tab == "PLAYERS" then buildPlayers() end
        container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end
    
    for i, t in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.25, 0, 1, 0)
        btn.Position = UDim2.new((i-1)*0.25, 0, 0, 0)
        btn.Text = t
        btn.TextColor3 = i==1 and Color3.fromRGB(255,100,100) or Color3.fromRGB(180,180,180)
        btn.BackgroundColor3 = Color3.fromRGB(35,35,45)
        btn.BackgroundTransparency = i==1 and 0 or 0.5
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.Parent = tabBar
        btn.MouseButton1Click:Connect(function()
            for j, b in ipairs(tabBtns) do
                b.BackgroundTransparency = 0.5
                b.TextColor3 = Color3.fromRGB(180,180,180)
            end
            btn.BackgroundTransparency = 0
            btn.TextColor3 = Color3.fromRGB(255,100,100)
            switchTab(tabNames[i])
        end)
        tabBtns[i] = btn
    end
    
    -- Minimize logic with position saving
    local function updateMinimize()
        isMinimized = not isMinimized
        if isMinimized then
            minimizedPos = mainFrame.Position
            mainFrame.Size = UDim2.new(0, 50, 0, 50)
            mainFrame.Position = minimizedPos
            titleBar.Visible = false
            tabBar.Visible = false
            container.Visible = false
            minBtn.Text = "+"
            minBtn.Position = UDim2.new(1, -45, 0, 2)
        else
            mainFrame.Size = UDim2.new(0, 280, 0, 350)
            mainFrame.Position = minimizedPos or UDim2.new(0.5, -140, 0.5, -175)
            titleBar.Visible = true
            tabBar.Visible = true
            container.Visible = true
            minBtn.Text = "−"
            minBtn.Position = UDim2.new(1, -40, 0, 2)
        end
    end
    
    minBtn.MouseButton1Click:Connect(updateMinimize)
    switchTab("COMBAT")
    return scr
end

-- ===========================
-- INITIALIZATION
-- ===========================
task.wait(0.5)
local char = LocalPlayer.Character
if char and char:FindChild("HumanoidRootPart") then
    createSpawnMarker(char.HumanoidRootPart.Position)
end

pcall(setupHealth)
pcall(setupMobileControls)

local gui = createMobileGUI()
gui.Enabled = true

RunService.RenderStepped:Connect(updateFlight)

Players.PlayerAdded:Connect(function(p)
    task.wait(0.5)
    if espEnabled then createESP(p) end
end)

local scanner = coroutine.wrap(function()
    while espScanning do
        if espEnabled then refreshESP() end
        task.wait(0.2)
    end
end)
scanner()

print([[
╔════════════════════════════════════════╗
║ 🔥 ORDINARYSCRIPT v5.2 - MOBILE        ║
╠════════════════════════════════════════╣
║ 👑 OWNER: ]]..OWNER_NAME..[[            ║
║ 📱 COMPACT TABBED UI                   ║
║ 🎮 FLIGHT: JOYSTICK + ▲/▼              ║
╚════════════════════════════════════════╝
]])
