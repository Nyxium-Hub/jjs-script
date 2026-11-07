-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 3 - LÓGICA)
-- ============================================================
local door_state = "IDLE"
local target_door_model, target_door_part = nil, nil
local target_prompt = nil
local door_interact_time = 0
local walk_timer = 0
local is_holding_e = false
local wait_bp = nil
local wait_target = nil

local function check_if_locked(door)
    local prompt = door:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then return not prompt.Enabled end
    local frame = door:FindFirstChild("Frame")
    if frame then
        local children = frame:GetChildren()
        if children[3] then
            local thirdChild = children[3]
            if thirdChild:GetAttribute("Locked") == true then return true end
            if thirdChild:IsA("BoolValue") and thirdChild.Value == true then return true end
            local b = thirdChild:FindFirstChild("Locked")
            if b and b:IsA("BoolValue") and b.Value == true then return true end
        end
    end
    for _, obj in ipairs(door:GetDescendants()) do
        if obj.Name == "Locked" and obj:IsA("BoolValue") and obj.Value == true then return true end
    end
    return false
end

local function stop_waiting()
    local hum = get_hum()
    if hum then hum.PlatformStand = false end
    if wait_bp then wait_bp:Destroy(); wait_bp = nil end
    wait_target = nil
end

local function get_navigation_dir(start_pos, target_pos, char, door_model)
    if walk_timer > 2.5 then return Vector3.new(0, 1, 0) end
    local base_dir = (target_pos - start_pos).Unit
    local ray_params = RaycastParams.new()
    ray_params.FilterType = Enum.RaycastFilterType.Exclude
    ray_params.FilterDescendantsInstances = {char, door_model}
    ray_params.IgnoreWater = true
    local angles = {0, 20, -20, 45, -45, 70, -70, 90, -90}
    for _, angle in ipairs(angles) do
        local rotated_dir = (CFrame.Angles(0, math.rad(angle), 0) * base_dir)
        local hit = Workspace:Raycast(start_pos, rotated_dir * 20, ray_params)
        if not hit then return rotated_dir end
    end
    return base_dir
end

local function start_auto_open_door()
    RunService.Heartbeat:Connect(function(dt)
        if not cfg.auto_open_door then
            if door_state ~= "IDLE" then
                door_state = "IDLE"
                if is_holding_e then 
                    if target_prompt then pcall(function() target_prompt:InputHoldEnd() end) end
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); is_holding_e = false 
                end
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.Anchored = false
                    for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end
                end
                stop_waiting()
            end
            return
        end

        local char, hrp, hum = LocalPlayer.Character, get_hrp(), get_hum()
        if not char or not hrp or not hum then stop_waiting() return end
        
        if hum.Health <= 0 then
            pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
            return
        end

        if #cached_doors == 0 then stop_waiting() return end

        local closest_door, min_dist = nil, math.huge
        local closest_part = nil
        local any_unlocked = false
        
        for _, door in ipairs(cached_doors) do
            if door and door:IsDescendantOf(Workspace) then
                if not check_if_locked(door) then
                    any_unlocked = true
                    local part = door:IsA("Model") and (door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart")) or door
                    if part then
                        local dist = (hrp.Position - part.Position).Magnitude
                        if dist < min_dist then 
                            min_dist = dist
                            closest_door = door
                            closest_part = part
                            target_prompt = door:FindFirstChildWhichIsA("ProximityPrompt", true)
                        end
                    end
                end
            end
        end

        if door_state == "IDLE" then
            if any_unlocked and closest_door then
                stop_waiting()
                target_door_model = closest_door
                target_door_part = closest_part
                door_state = "WALKING"
                walk_timer = 0
            else
                door_state = "WAITING"
                hum.PlatformStand = true
                wait_target = hrp.Position + Vector3.new(0, 300, 0)
                if not wait_bp then
                    wait_bp = Instance.new("BodyPosition")
                    wait_bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    wait_bp.P = 10000
                    wait_bp.D = 500
                    wait_bp.Position = wait_target
                    wait_bp.Parent = hrp
                end
            end
        end
        
        if door_state == "WAITING" then
            if any_unlocked then
                stop_waiting()
                target_door_model = closest_door
                target_door_part = closest_part
                door_state = "WALKING"
                walk_timer = 0
            else
                if wait_bp then
                    wait_bp.Position = wait_target
                end
            end
        end

        if door_state == "WALKING" then
            walk_timer = walk_timer + dt
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) or check_if_locked(target_door_model) then 
                door_state = "IDLE" return 
            end
            
            if cfg.door_noclip then
                for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
            end
            
            local target_pos = target_door_part.Position
            if target_prompt and target_prompt.Parent and target_prompt.Parent:IsA("BasePart") then
                target_pos = target_prompt.Parent.Position
            end
            
            local dist = (hrp.Position - target_pos).Magnitude
            
            if dist > 4 then
                local move_dir = get_navigation_dir(hrp.Position, target_pos, char, target_door_model)
                hrp.CFrame = hrp.CFrame + (move_dir * 130 * dt)
            else
                door_state = "OPENING"
                hum.WalkSpeed = 0
                door_interact_time = tick()
                
                for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
                
                if not is_holding_e then
                    if target_prompt then pcall(function() target_prompt:InputHoldBegin() end) end
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    is_holding_e = true
                end
            end
        end

        if door_state == "OPENING" then
            if hum.Health <= 0 then
                pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
            end
            
            if target_door_part then
                hrp.CFrame = CFrame.new(target_door_part.Position + Vector3.new(0, 2, 0))
            end
            
            if not target_door_model or not target_door_model:IsDescendantOf(Workspace) or (target_door_part and target_door_part.Transparency == 1) or (tick() - door_interact_time > 6) then
                if is_holding_e then 
                    if target_prompt then pcall(function() target_prompt:InputHoldEnd() end) end
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); is_holding_e = false 
                end
                
                hum.PlatformStand = false
                hum.WalkSpeed = 16
                for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end
                door_state = "IDLE"
                task.wait(0.5)
            end
        end
    end)
end

RunService.Heartbeat:Connect(update_auto_block)
RunService.RenderStepped:Connect(update_player_movement)
start_auto_farm()
start_auto_open_door()
start_esp()

-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 4 - INTERFACE)
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = WindUI:CreateWindow({ Title = "Nyxium | Itadori", Author = "karpa", Folder = "NyxiumItadori", Size = UDim2.fromOffset(520, 420), Theme = "Dark", Resizable = true })

local Tab = Window:Tab({ Title = "Combat", Icon = "swords" })
Tab:Section({ Title = "Auto Black Flash" })
Tab:Toggle({ Title = "Auto Black Flash", Default = false, Callback = function(s) cfg.auto_black_flash = s end })
Tab:Section({ Title = "Auto Block" })
Tab:Toggle({ Title = "Auto Block", Default = false, Callback = function(s) cfg.auto_block = s end })
Tab:Slider({ Title = "Block Range", Value = { Min = 5, Max = 50, Default = 20 }, Callback = function(v) cfg.block_range = v end })

local MiscTab = Window:Tab({ Title = "Misc", Icon = "crosshair" })
MiscTab:Section({ Title = "Aimbot" })
MiscTab:Toggle({ Title = "Enable Aimbot", Default = false, Callback = function(s) cfg.aim_enabled = s end })
MiscTab:Toggle({ Title = "Hold RMB", Desc = "Só puxa segurando o botão direito", Default = false, Callback = function(s) cfg.aim_hold_rmb = s end })
MiscTab:Toggle({ Title = "Show FOV", Default = false, Callback = function(s) cfg.show_fov = s end })
MiscTab:Toggle({ Title = "Visible Check", Default = true, Callback = function(s) cfg.aim_visible_check = s end })
MiscTab:Toggle({ Title = "Dead Check", Default = true, Callback = function(s) cfg.aim_dead_check = s end })
MiscTab:Slider({ Title = "FOV Size", Value = { Min = 20, Max = 500, Default = 120 }, Callback = function(v) cfg.aim_fov = v end })
MiscTab:Slider({ Title = "Smoothness", Value = { Min = 1, Max = 100, Default = 15 }, Callback = function(v) cfg.aim_smoothness = v end })

MiscTab:Section({ Title = "Console Lock On" })
MiscTab:Toggle({ Title = "Enable Lock On", Default = false, Callback = function(s) cfg.lock_on_enabled = s end })
MiscTab:Slider({ Title = "Lock On Range (Studs)", Desc = "Só trava se o cara estiver perto", Value = { Min = 5, Max = 50, Default = 20 }, Callback = function(v) cfg.lock_on_range = v end })

MiscTab:Section({ Title = "Auto Regen" })
MiscTab:Toggle({ Title = "Auto Regen (R Key)", Desc = "Aperta R para reviver", Default = false, Callback = function(s) cfg.auto_regen = s end })

local PlayerTab = Window:Tab({ Title = "Player", Icon = "user" })
PlayerTab:Section({ Title = "Speed Bypass" })
PlayerTab:Toggle({ Title = "Enable Speed Bypass", Default = false, Callback = function(s) cfg.speed_bypass = s end })
PlayerTab:Slider({ Title = "Speed Value", Value = { Min = 16, Max = 250, Default = 60 }, Callback = function(v) cfg.speed_val = v end })
PlayerTab:Section({ Title = "Noclip Bypass" })
PlayerTab:Toggle({ Title = "Enable Noclip Bypass", Default = false, Callback = function(s) cfg.noclip_bypass = s end })
PlayerTab:Slider({ Title = "Push Speed", Value = { Min = 10, Max = 100, Default = 60 }, Callback = function(v) cfg.noclip_speed = v end })
PlayerTab:Section({ Title = "Fly Bypass" })
PlayerTab:Toggle({ Title = "Enable Fly Bypass", Default = false, Callback = function(s) cfg.fly_bypass = s end })
PlayerTab:Slider({ Title = "Fly Speed", Value = { Min = 16, Max = 500, Default = 100 }, Callback = function(v) cfg.fly_speed = v end })
PlayerTab:Section({ Title = "Jump Power" })
PlayerTab:Toggle({ Title = "Enable Jump Power", Default = false, Callback = function(s) cfg.jump_power_enabled = s end })
PlayerTab:Slider({ Title = "Jump Power Value", Value = { Min = 50, Max = 250, Default = 50 }, Callback = function(v) cfg.jump_power_val = v end })
PlayerTab:Toggle({ Title = "Infinite Jump", Default = false, Callback = function(s) cfg.inf_jump = s end })

local FarmTab = Window:Tab({ Title = "Farm", Icon = "leaf" })
FarmTab:Section({ Title = "Pumpkin Farm" })
FarmTab:Toggle({ Title = "Auto Get Player Pumpkin (Suave)", Default = false, Callback = function(s) cfg.auto_farm_pumpkin = s end })
FarmTab:Section({ Title = "Halloween Door Farm" })
FarmTab:Toggle({ Title = "ESP Halloween Door (Chams)", Default = false, Callback = function(s) cfg.esp_door = s end })
FarmTab:Toggle({ Title = "Auto Open Door (Voo 300)", Default = false, Callback = function(s) cfg.auto_open_door = s end })
FarmTab:Toggle({ Title = "Door Noclip", Desc = "Atravessa paredes para chegar na porta", Default = true, Callback = function(s) cfg.door_noclip = s end })

local VisTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
VisTab:Section({ Title = "ESP Principal" })
VisTab:Toggle({ Title = "Enable ESP", Default = false, Callback = function(s) cfg.esp_enabled = s end })
VisTab:Toggle({ Title = "Chams (Branco)", Default = false, Callback = function(s) cfg.esp_chams = s end })
VisTab:Section({ Title = "Elementos" })
VisTab:Toggle({ Title = "Box", Default = false, Callback = function(s) cfg.esp_box = s end })
VisTab:Toggle({ Title = "Skeleton", Default = false, Callback = function(s) cfg.esp_skeleton = s end })
VisTab:Toggle({ Title = "Lines", Default = false, Callback = function(s) cfg.esp_lines = s end })
VisTab:Toggle({ Title = "Nome", Default = false, Callback = function(s) cfg.esp_name = s end })
VisTab:Toggle({ Title = "Distância", Default = false, Callback = function(s) cfg.esp_distance = s end })
VisTab:Toggle({ Title = "Barra de Vida", Default = false, Callback = function(s) cfg.esp_health_bar = s end })