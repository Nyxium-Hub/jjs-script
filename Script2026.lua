-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 1)
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local K = getgenv().karpa or {}
getgenv().karpa = K

K.cfg = {
    auto_block = false, block_range = 20, auto_black_flash = false,
    aim_enabled = false, aim_hold_rmb = false, aim_fov = 120, show_fov = false,
    aim_visible_check = true, aim_dead_check = true, aim_smoothness = 15, aim_hitbox = "Head",
    lock_on_enabled = false, lock_on_range = 20, lock_on_key = Enum.KeyCode.LeftShift, lock_on_holding = false,
    speed_bypass = false, speed_val = 60, noclip_bypass = false, noclip_speed = 60,
    fly_bypass = false, fly_speed = 100, jump_power_enabled = false, jump_power_val = 50, inf_jump = false,
    auto_farm_pumpkin = false,
    esp_enabled = false, esp_box = false, esp_name = false, esp_distance = false, esp_health_bar = false,
    esp_skeleton = false, esp_lines = false, esp_chams = false, anti_afk = false,
}
local cfg = K.cfg

local function get_hrp() local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() return c:FindFirstChild("HumanoidRootPart") end
local function get_hum() local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() return c:FindFirstChildOfClass("Humanoid") end
local function is_alive(plr) local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") return h and h.Health > 0 end

-- CONSOLE LOCK ON
local lock_square = Drawing.new("Square")
lock_square.Thickness = 2; lock_square.Color = Color3.fromRGB(255, 0, 0); lock_square.Transparency = 1; lock_square.Filled = false; lock_square.Visible = false

UserInputService.InputBegan:Connect(function(input, gp) if not gp and input.KeyCode == cfg.lock_on_key and cfg.lock_on_enabled then cfg.lock_on_holding = true end end)
UserInputService.InputEnded:Connect(function(input, gp) if not gp and input.KeyCode == cfg.lock_on_key then cfg.lock_on_holding = false end end)

local function get_closest_in_range(range)
    local my_hrp = get_hrp()
    if not my_hrp then return nil end
    local closest, min_dist = nil, range
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and is_alive(plr) then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (my_hrp.Position - hrp.Position).Magnitude
                if dist < min_dist then min_dist, closest = dist, plr end
            end
        end
    end
    return closest, min_dist
end

RunService.RenderStepped:Connect(function()
    if cfg.lock_on_enabled and cfg.lock_on_holding then
        local target = get_closest_in_range(cfg.lock_on_range)
        if target and target.Character then
            local enemy_head = target.Character:FindFirstChild("Head")
            if enemy_head then
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, enemy_head.Position)
                local pos, on_screen = Camera:WorldToViewportPoint(enemy_head.Position)
                if on_screen then
                    lock_square.Size = Vector2.new(40, 40); lock_square.Position = Vector2.new(pos.X - 20, pos.Y - 20); lock_square.Visible = true
                else lock_square.Visible = false end
            end
        else lock_square.Visible = false end
    else lock_square.Visible = false end
end)

-- AIMBOT TRADICIONAL
local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1; fov_circle.NumSides = 64; fov_circle.Color = Color3.fromRGB(255, 255, 255); fov_circle.Transparency = 0.5; fov_circle.Filled = false; fov_circle.Visible = false

local function get_aim_target()
    local best, best_dist = nil, cfg.aim_fov
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or (cfg.aim_dead_check and hum.Health <= 0) then continue end
        local part = char:FindFirstChild(cfg.aim_hitbox)
        if not part then continue end
        local pos, on_screen = Camera:WorldToViewportPoint(part.Position)
        if not on_screen then continue end
        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
        if dist <= best_dist then
            if cfg.aim_visible_check then
                local ray = Ray.new(Camera.CFrame.Position, part.Position - Camera.CFrame.Position)
                local hit, _ = Workspace:FindPartOnRay(ray, LocalPlayer.Character)
                if hit and not hit:IsDescendantOf(char) then continue end
            end
            best, best_dist = part, dist
        end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    if cfg.show_fov then
        fov_circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2); fov_circle.Radius = cfg.aim_fov; fov_circle.Visible = true
    else fov_circle.Visible = false end

    if cfg.aim_enabled then
        local is_holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if (cfg.aim_hold_rmb and is_holding) or (not cfg.aim_hold_rmb) then
            local target = get_aim_target()
            if target then
                local goal = CFrame.lookAt(Camera.CFrame.Position, target.Position)
                if cfg.aim_smoothness > 1 then Camera.CFrame = Camera.CFrame:Lerp(goal, 1 / cfg.aim_smoothness)
                else Camera.CFrame = goal end
            end
        end
    end
end)

-- ESP
local esp_objects, esp_chams = {}, {}
local function create_esp(plr)
    if plr == LocalPlayer or esp_objects[plr] then return end
    local obj = {}
    obj.name = Drawing.new("Text"); obj.name.Size=16; obj.name.Center=true; obj.name.Outline=true; obj.name.Color=Color3.fromRGB(255,255,255); obj.name.Visible=false
    obj.distance = Drawing.new("Text"); obj.distance.Size=14; obj.distance.Center=true; obj.distance.Outline=true; obj.distance.Color=Color3.fromRGB(255,255,0); obj.distance.Visible=false
    obj.box = Drawing.new("Square"); obj.box.Thickness=1; obj.box.Color=Color3.fromRGB(255,255,255); obj.box.Transparency=1; obj.box.Filled=false; obj.box.Visible=false
    obj.hp_bg = Drawing.new("Square"); obj.hp_bg.Color=Color3.fromRGB(0,0,0); obj.hp_bg.Filled=true; obj.hp_bg.Visible=false
    obj.hp_fill = Drawing.new("Square"); obj.hp_fill.Color=Color3.fromRGB(0,255,0); obj.hp_fill.Filled=true; obj.hp_fill.Visible=false
    obj.line = Drawing.new("Line"); obj.line.Thickness=1; obj.line.Color=Color3.fromRGB(255,255,255); obj.line.Transparency=0.5; obj.line.Visible=false
    obj.skeleton = {}
    for i=1,20 do obj.skeleton[i] = Drawing.new("Line"); obj.skeleton[i].Thickness=1; obj.skeleton[i].Color=Color3.fromRGB(255,255,255); obj.skeleton[i].Transparency=1; obj.skeleton[i].Visible=false end
    esp_objects[plr] = obj
end

local function apply_chams(plr, state)
    if plr == LocalPlayer then return end
    if state then
        if not esp_chams[plr] and plr.Character then
            local h = Instance.new("Highlight"); h.Name="NyxiumChams"; h.FillColor=Color3.fromRGB(255,255,255); h.OutlineColor=Color3.fromRGB(255,255,255); h.FillTransparency=0.5; h.OutlineTransparency=0; h.Adornee=plr.Character; h.Parent=CoreGui
            esp_chams[plr] = h
        end
    else
        if esp_chams[plr] then esp_chams[plr]:Destroy(); esp_chams[plr]=nil end
    end
end

local skel_r15 = {{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","HumanoidRootPart"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
local skel_r6 = {{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}

local function start_esp()
    RunService.RenderStepped:Connect(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if not cfg.esp_enabled or not is_alive(plr) then
                if esp_objects[plr] then
                    for _, v in pairs(esp_objects[plr]) do if typeof(v)=="table" then for _,l in ipairs(v) do l.Visible=false end else v.Visible=false end end
                end
                apply_chams(plr, false) continue
            end
            if not esp_objects[plr] then create_esp(plr) end
            local obj, char = esp_objects[plr], plr.Character
            local hrp, head, hum = char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChild("Head"), char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not head or not hum then
                for _, v in pairs(obj) do if typeof(v)=="table" then for _,l in ipairs(v) do l.Visible=false end else v.Visible=false end end
                apply_chams(plr, false) continue
            end
            local head_pos, on_screen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local foot_pos, _ = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 2.5, 0))
            if not on_screen then
                for _, v in pairs(obj) do if typeof(v)=="table" then for _,l in ipairs(v) do l.Visible=false end else v.Visible=false end end
                apply_chams(plr, false) continue
            end
            apply_chams(plr, cfg.esp_chams)
            local dist = (get_hrp().Position - hrp.Position).Magnitude
            local height = math.abs(head_pos.Y - foot_pos.Y)
            local width = height * 0.6
            local top_left = Vector2.new(head_pos.X - width / 2, head_pos.Y)
            
            obj.box.Size = Vector2.new(width, height); obj.box.Position = top_left; obj.box.Visible = cfg.esp_box
            if cfg.esp_health_bar then
                local hp_ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                local bar_x = top_left.X - 6
                obj.hp_bg.Size = Vector2.new(3, height); obj.hp_bg.Position = Vector2.new(bar_x, top_left.Y); obj.hp_bg.Visible = true
                obj.hp_fill.Size = Vector2.new(3, height * hp_ratio); obj.hp_fill.Position = Vector2.new(bar_x, top_left.Y + (height * (1 - hp_ratio))); obj.hp_fill.Color = Color3.fromRGB(math.floor(255*(1-hp_ratio)), math.floor(255*hp_ratio), 0); obj.hp_fill.Visible = true
            else obj.hp_bg.Visible = false; obj.hp_fill.Visible = false end
            
            obj.name.Text = plr.Name; obj.name.Position = Vector2.new(head_pos.X, top_left.Y - 20); obj.name.Visible = cfg.esp_name
            obj.distance.Text = string.format("[%d m]", math.floor(dist)); obj.distance.Position = Vector2.new(head_pos.X, top_left.Y + height + 5); obj.distance.Visible = cfg.esp_distance
            obj.line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y); obj.line.To = Vector2.new(head_pos.X, head_pos.Y); obj.line.Visible = cfg.esp_lines
            
            if cfg.esp_skeleton then
                local skel = char:FindFirstChild("UpperTorso") and skel_r15 or skel_r6
                local i = 1
                for _, conn in ipairs(skel) do
                    local p1, p2 = char:FindFirstChild(conn[1]), char:FindFirstChild(conn[2])
                    if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                        local s1, o1 = Camera:WorldToViewportPoint(p1.Position); local s2, o2 = Camera:WorldToViewportPoint(p2.Position)
                        if o1 and o2 and i <= #obj.skeleton then obj.skeleton[i].From = Vector2.new(s1.X, s1.Y); obj.skeleton[i].To = Vector2.new(s2.X, s2.Y); obj.skeleton[i].Visible = true; i = i + 1 end
                    end
                end
                for j = i, #obj.skeleton do obj.skeleton[j].Visible = false end
            else for _, line in ipairs(obj.skeleton) do line.Visible = false end end
        end
    end)
end
-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 2)
-- ============================================================
local TweenService = game:GetService("TweenService")

local Knit = ReplicatedStorage:WaitForChild("Knit"):WaitForChild("Knit"):WaitForChild("Services")
local BlockRE = Knit:WaitForChild("BlockService"):WaitForChild("RE")
local BlockActivate = BlockRE:WaitForChild("Activated")
local BlockDeactivate = BlockRE:WaitForChild("Deactivated")

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
    
    if cfg.speed_bypass then hum.WalkSpeed = 16; if hum.MoveDirection.Magnitude > 0 then hrp.CFrame = hrp.CFrame + (hum.MoveDirection * cfg.speed_val * dt) end else hum.WalkSpeed = 16 end
    
    if cfg.noclip_bypass then
        for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
        if hum.MoveDirection.Magnitude > 0 then hrp.CFrame = hrp.CFrame + (hum.MoveDirection * cfg.noclip_speed * dt) end
    else
        for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end end; hrp.CanCollide = true
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
        if hum.PlatformStand and not cfg.auto_farm_pumpkin then hum.PlatformStand = false end
    end
end

UserInputService.JumpRequest:Connect(function() if cfg.inf_jump then local hum = get_hum() if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)

-- AUTO FARM PUMPKIN
local farm_state = "IDLE"
local function has_pumpkin(plr)
    local char = plr.Character
    if not char then return false end
    
    local bp = plr:FindFirstChildOfClass("Backpack")
    if bp then 
        for _, item in ipairs(bp:GetChildren()) do 
            local n = item.Name:lower()
            if n:find("pumpkin") or n:find("pum") or n:find("abóbora") or n:find("abobora") then return true end 
        end 
    end
    for _, item in ipairs(char:GetChildren()) do 
        if item:IsA("Tool") or item:IsA("Accessory") then
            local n = item.Name:lower()
            if n:find("pumpkin") or n:find("pum") or n:find("abóbora") or n:find("abobora") then return true end 
        end 
    end
    if plr:GetAttribute("Pumpkin") or plr:GetAttribute("IsPumpkin") or plr:GetAttribute("HasPumpkin") then return true end
    return false
end

local function start_auto_farm()
    RunService.Heartbeat:Connect(function()
        if not cfg.auto_farm_pumpkin then
            if farm_state == "SAFE" then local hum = get_hum() if hum then hum.PlatformStand = false end farm_state = "IDLE" end
            return
        end
        if farm_state ~= "IDLE" then return end
        
        local char, my_hrp, hum = LocalPlayer.Character, get_hrp(), get_hum()
        if not char or not my_hrp or not hum then return end

        if has_pumpkin(LocalPlayer) then
            farm_state = "SAFE"
            hum.PlatformStand = true
            local bp = Instance.new("BodyPosition"); bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bp.Position = my_hrp.Position + Vector3.new(0, 300, 0); bp.Parent = my_hrp
            task.spawn(function()
                while cfg.auto_farm_pumpkin and has_pumpkin(LocalPlayer) do
                    local current_hrp = get_hrp()
                    if current_hrp and bp then bp.Position = Vector3.new(current_hrp.Position.X, current_hrp.Position.Y + 10, current_hrp.Position.Z) else break end
                    task.wait(0.5)
                end
                if bp then bp:Destroy() end
                if hum then hum.PlatformStand = false end
                farm_state = "IDLE"
            end)
            return
        end

        local target = nil
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and is_alive(plr) and has_pumpkin(plr) then target = plr break end
        end
        if not target then return end

        farm_state = "MOVING"
        task.spawn(function()
            local success, err = pcall(function()
                local target_hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if not target_hrp then return end
                hum.PlatformStand = true
                local dist = (my_hrp.Position - target_hrp.Position).Magnitude
                local duration = math.clamp(dist / 150, 0.3, 1.5)
                local tween = TweenService:Create(my_hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = target_hrp.CFrame * CFrame.new(0, 0, 3)})
                tween:Play(); tween.Completed:Wait()
                hum.PlatformStand = false
                farm_state = "ATTACKING"
                local end_time = tick() + 2
                while tick() < end_time and cfg.auto_farm_pumpkin do
                    if not target.Character then break end
                    pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 1, true, game, 0); task.wait(0.05); VirtualInputManager:SendMouseButtonEvent(0, 0, 1, false, game, 0) end)
                    pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Three, false, game); task.wait(0.05); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Three, false, game) end)
                    task.wait(0.1)
                end
            end)
            if not success then warn("AutoFarm erro: ", err) end
            farm_state = "IDLE"
        end)
    end)
end

RunService.Heartbeat:Connect(update_auto_block)
RunService.RenderStepped:Connect(update_player_movement)
start_auto_farm()
start_esp()

-- INTERFACE WIND UI
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
FarmTab:Toggle({ Title = "Auto Get Player Pumpkin", Default = false, Callback = function(s) cfg.auto_farm_pumpkin = s end })

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