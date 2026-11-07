-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 2 - SPEED + BLOCK + FARM)
-- ============================================================
local VirtualInputManager = game:GetService("VirtualInputManager")
local Knit = ReplicatedStorage:WaitForChild("Knit"):WaitForChild("Knit"):WaitForChild("Services")
local BlockRE = Knit:WaitForChild("BlockService"):WaitForChild("RE")
local BlockActivate = BlockRE:WaitForChild("Activated")
local BlockDeactivate = BlockRE:WaitForChild("Deactivated")

local is_regenerating = false
task.spawn(function()
    while task.wait(0.1) do
        if cfg.auto_regen then
            local hum = get_hum()
            if hum and hum.Health <= 0 and not is_regenerating then
                is_regenerating = true
                task.spawn(function()
                    local end_time = tick() + 3
                    while tick() < end_time do
                        pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game) end)
                        task.wait(0.1)
                        pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
                        task.wait(0.1)
                    end
                    is_regenerating = false
                end)
            end
        end
    end
end)

local is_blocking = false
local function update_auto_block()
    if not cfg.auto_block then
        if is_blocking then pcall(function() BlockDeactivate:FireServer() end); VirtualInputManager:SendMouseButtonEvent(0, 0, 2, false, game, 0); is_blocking = false end
        return
    end
    local my_hrp = get_hrp()
    local enemy, min_dist = nil, cfg.block_range
    if my_hrp then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and is_alive(plr) then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (my_hrp.Position - hrp.Position).Magnitude
                    if dist < min_dist then min_dist, enemy = dist, plr end
                end
            end
        end
    end
    local is_attacking = false
    if enemy and enemy.Character then
        local enemy_hum = enemy.Character:FindFirstChildOfClass("Humanoid")
        if enemy_hum then
            for _, track in ipairs(enemy_hum:GetPlayingAnimationTracks()) do
                local a = track.Animation.Name:lower()
                if a:find("attack") or a:find("punch") or a:find("kick") or a:find("slash") or a:find("m1") then is_attacking = true break end
            end
        end
    end
    if is_attacking and not is_blocking then
        if enemy.Character and enemy.Character:FindFirstChild("HumanoidRootPart") then Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, enemy.Character.HumanoidRootPart.Position) end
        pcall(function() BlockActivate:FireServer() end); VirtualInputManager:SendMouseButtonEvent(0, 0, 2, true, game, 0); is_blocking = true
    elseif not is_attacking and is_blocking then
        pcall(function() BlockDeactivate:FireServer() end); VirtualInputManager:SendMouseButtonEvent(0, 0, 2, false, game, 0); is_blocking = false
    end
end

local fly_vel = nil
local function update_player_movement(dt)
    local char = LocalPlayer.Character
    local hrp = get_hrp()
    local hum = get_hum()
    if not char or not hrp or not hum then return end

    if cfg.speed_bypass then
        hum.WalkSpeed = 16
        if hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * cfg.speed_val * dt)
        end
    else
        hum.WalkSpeed = 16
    end

    if cfg.noclip_bypass then
        for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
        if hum.MoveDirection.Magnitude > 0 then hrp.CFrame = hrp.CFrame + (hum.MoveDirection * cfg.noclip_speed * dt) end
    else
        for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end end
        hrp.CanCollide = true
    end

    if cfg.jump_power_enabled then hum.UseJumpPower = true; hum.JumpPower = cfg.jump_power_val end

    if cfg.fly_bypass then
        hum.PlatformStand = true
        if not fly_vel or fly_vel.Parent ~= hrp then
            if fly_vel then fly_vel:Destroy() end
            fly_vel = Instance.new("BodyVelocity"); fly_vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge); fly_vel.Velocity = Vector3.zero; fly_vel.Parent = hrp
        end
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        fly_vel.Velocity = dir * cfg.fly_speed
    else
        if fly_vel then fly_vel:Destroy() fly_vel = nil end
        if hum.PlatformStand and not cfg.auto_farm_pumpkin and door_state ~= "WAITING" and door_state ~= "OPENING" then hum.PlatformStand = false end
    end
end

UserInputService.JumpRequest:Connect(function() if cfg.inf_jump then local hum = get_hum() if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)

-- FARM (versão original que funcionava)
local farm_state = "IDLE"
local flee_bp = nil
local flee_target = nil

local function has_pumpkin(plr)
    local char = plr.Character
    if not char then return false end
    if plr:GetAttribute("Pumpkin") or plr:GetAttribute("IsPumpkin") or plr:GetAttribute("HasPumpkin") then return true end
    if char:GetAttribute("Pumpkin") or char:GetAttribute("IsPumpkin") then return true end
    local bp = plr:FindFirstChildOfClass("Backpack")
    if bp then for _, item in ipairs(bp:GetChildren()) do local n = item.Name:lower() if n:find("pumpkin") or n:find("pum") or n:find("abóbora") or n:find("abobora") then return true end end end
    for _, item in ipairs(char:GetChildren()) do local n = item.Name:lower() if n:find("pumpkin") or n:find("pum") or n:find("abóbora") or n:find("abobora") then return true end end
    return false
end

local function start_auto_farm()
    RunService.Heartbeat:Connect(function(dt)
        if not cfg.auto_farm_pumpkin then
            if farm_state == "FLEE" then
                local hum = get_hum()
                if hum then hum.PlatformStand = false end
                if flee_bp then flee_bp:Destroy(); flee_bp = nil end
            end
            farm_state = "IDLE"
            flee_target = nil
            return
        end

        local char, my_hrp, hum = LocalPlayer.Character, get_hrp(), get_hum()
        if not char or not my_hrp or not hum then return end

        if has_pumpkin(LocalPlayer) then
            if farm_state ~= "FLEE" then
                farm_state = "FLEE"
                hum.PlatformStand = true
                flee_target = my_hrp.Position + Vector3.new(0, 300, 0)
                flee_bp = Instance.new("BodyPosition")
                flee_bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                flee_bp.P = 10000
                flee_bp.D = 500
                flee_bp.Position = flee_target
                flee_bp.Parent = my_hrp
            end
            if flee_bp then
                flee_bp.Position = flee_target
            end
            return
        else
            if farm_state == "FLEE" then
                hum.PlatformStand = false
                if flee_bp then flee_bp:Destroy(); flee_bp = nil end
                farm_state = "IDLE"
                flee_target = nil
            end
        end

        local target = nil
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and is_alive(plr) and has_pumpkin(plr) then target = plr break end
        end

        if target then
            local target_hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if target_hrp then
                farm_state = "ATTACKING"
                my_hrp.CFrame = CFrame.new(target_hrp.Position + Vector3.new(0, 0, 3))
                pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Three, false, game); task.wait(0.05); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Three, false, game) end)
            end
        else
            farm_state = "IDLE"
        end
    end)
end