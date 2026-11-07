-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 2 - FARM NO CHÃO)
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
        for _, p in ipairs(char:GetDescendants()) do 
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then 
                p.CanCollide = false 
            end 
        end
        if hum.MoveDirection.Magnitude > 0 then hrp.CFrame = hrp.CFrame + (hum.MoveDirection * cfg.noclip_speed * dt) end
    else
        for _, p in ipairs(char:GetDescendants()) do 
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then 
                p.CanCollide = true 
            end 
        end
    end
    hrp.CanCollide = true

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
    end
end

UserInputService.JumpRequest:Connect(function() if cfg.inf_jump then local hum = get_hum() if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)

-- FARM PUMPKIN ANDANDO NO CHÃO
local farm_state = "IDLE"
local farm_target = nil
local farm_walk_timer = 0
local farm_last_hit = 0

local function has_pumpkin(plr)
    local char = plr.Character
    if not char then return false end
    if plr:GetAttribute("Pumpkin") or plr:GetAttribute("IsPumpkin") or plr:GetAttribute("HasPumpkin") then return true end
    if char:GetAttribute("Pumpkin") or char:GetAttribute("IsPumpkin") then return true end
    local bp = plr:FindFirstChildOfClass("Backpack")
    if bp then for _, item in ipairs(bp:GetChildren()) do local n = item.Name:lower() if n == "pumpkin" or n == "pumpkinhead" or n == "pum" then return true end end end
    for _, item in ipairs(char:GetChildren()) do local n = item.Name:lower() if n == "pumpkin" or n == "pumpkinhead" or n == "pum" then return true end end
    return false
end

local function get_nav_dir(start_pos, target_pos, char, target_char)
    farm_walk_timer = farm_walk_timer + 0.01
    if farm_walk_timer > 2.5 then return Vector3.new(0, 1, 0) end
    local base_dir = (target_pos - start_pos).Unit
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, target_char}
    params.IgnoreWater = true
    local angles = {0, 20, -20, 40, -40, 60, -60}
    for _, ang in ipairs(angles) do
        local rot = CFrame.Angles(0, math.rad(ang), 0) * base_dir
        local hit = Workspace:Raycast(start_pos, rot * 15, params)
        if not hit then return rot end
    end
    return base_dir
end

local function start_auto_farm()
    RunService.Heartbeat:Connect(function(dt)
        if not cfg.auto_farm_pumpkin then
            farm_state = "IDLE"
            farm_target = nil
            farm_walk_timer = 0
            local hum = get_hum()
            local hrp = get_hrp()
            if hum then hum.PlatformStand = false end
            if hrp then hrp.Anchored = false end
            return
        end

        local char, my_hrp, hum = LocalPlayer.Character, get_hrp(), get_hum()
        if not char or not my_hrp or not hum then return end

        if has_pumpkin(LocalPlayer) then
            farm_state = "DONE"
            return
        end

        if farm_state == "IDLE" then
            local target = nil
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and is_alive(plr) and has_pumpkin(plr) then target = plr break end
            end
            if target then
                farm_target = target
                farm_state = "WALKING"
                farm_walk_timer = 0
            end
        end

        if farm_state == "WALKING" and farm_target then
            local target_hrp = farm_target.Character and farm_target.Character:FindFirstChild("HumanoidRootPart")
            if not target_hrp or not is_alive(farm_target) then farm_state = "IDLE" farm_target = nil return end
            local dist = (my_hrp.Position - target_hrp.Position).Magnitude
            if dist > 3 then
                local move_dir = get_nav_dir(my_hrp.Position, target_hrp.Position, char, farm_target.Character)
                -- Speed bypass de 60 studs por frame
                my_hrp.CFrame = my_hrp.CFrame + (move_dir * 60 * dt)
            else
                farm_state = "ATTACKING"
            end
        end

        if farm_state == "ATTACKING" and farm_target then
            local target_hrp = farm_target.Character and farm_target.Character:FindFirstChild("HumanoidRootPart")
            if not target_hrp or not is_alive(farm_target) then farm_state = "IDLE" farm_target = nil return end
            local dist = (my_hrp.Position - target_hrp.Position).Magnitude
            if dist > 3 then
                farm_state = "WALKING"
                return
            end
            if tick() - farm_last_hit > 0.4 then
                farm_last_hit = tick()
                pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Three, false, game); task.wait(0.05); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Three, false, game) end)
            end
        end
    end)
end