-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 1)
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
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
    auto_farm_pumpkin = false, esp_door = false, auto_open_door = false, door_noclip = true,
    esp_enabled = false, esp_box = false, esp_name = false, esp_distance = false, esp_health_bar = false,
    esp_skeleton = false, esp_lines = false, esp_chams = false, anti_afk = false, auto_regen = false,
}
local cfg = K.cfg

local function get_hrp() local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() return c:FindFirstChild("HumanoidRootPart") end
local function get_hum() local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() return c:FindFirstChildOfClass("Humanoid") end
local function is_alive(plr) local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") return h and h.Health > 0 end

local cached_doors = {}
task.spawn(function()
    while task.wait(2) do
        local temp = {}
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v.Name == "HalloweenDoor" then table.insert(temp, v) end
        end
        cached_doors = temp
    end
end)

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
    return closest
end

RunService.RenderStepped:Connect(function()
    if cfg.lock_on_enabled and cfg.lock_on_holding then
        local target = get_closest_in_range(cfg.lock_on_range)
        if target and target.Character and target.Character:FindFirstChild("Head") then
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, target.Character.Head.Position)
            local pos, on_screen = Camera:WorldToViewportPoint(target.Character.Head.Position)
            if on_screen then lock_square.Size = Vector2.new(40, 40); lock_square.Position = Vector2.new(pos.X - 20, pos.Y - 20); lock_square.Visible = true
            else lock_square.Visible = false end
        else lock_square.Visible = false end
    else lock_square.Visible = false end
end)

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1; fov_circle.NumSides = 64; fov_circle.Color = Color3.fromRGB(255, 255, 255); fov_circle.Transparency = 0.5; fov_circle.Filled = false; fov_circle.Visible = false

local function get_aim_target()
    local best, best_dist = nil, cfg.aim_fov
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and is_alive(player) then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and (not cfg.aim_dead_check or hum.Health > 0) then
                local part = char:FindFirstChild(cfg.aim_hitbox)
                if part then
                    local pos, on_screen = Camera:WorldToViewportPoint(part.Position)
                    if on_screen then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist <= best_dist then
                            if cfg.aim_visible_check then
                                local ray = Ray.new(Camera.CFrame.Position, part.Position - Camera.CFrame.Position)
                                local hit, _ = Workspace:FindPartOnRay(ray, LocalPlayer.Character)
                                if not (hit and not hit:IsDescendantOf(char)) then best, best_dist = part, dist end
                            else best, best_dist = part, dist end
                        end
                    end
                end
            end
        end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    if cfg.show_fov then fov_circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2); fov_circle.Radius = cfg.aim_fov; fov_circle.Visible = true
    else fov_circle.Visible = false end

    if cfg.aim_enabled and (not cfg.aim_hold_rmb or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then
        local target = get_aim_target()
        if target then
            local goal = CFrame.lookAt(Camera.CFrame.Position, target.Position)
            Camera.CFrame = cfg.aim_smoothness > 1 and Camera.CFrame:Lerp(goal, 1 / cfg.aim_smoothness) or goal
        end
    end
end)

local esp_objects, esp_chams, esp_doors, door_chams = {}, {}, {}, {}

local function remove_player_esp(plr)
    if esp_objects[plr] then
        for _, v in pairs(esp_objects[plr]) do if typeof(v)=="table" then for _,l in ipairs(v) do l:Remove() end else v:Remove() end end
        esp_objects[plr] = nil
    end
    if esp_chams[plr] then esp_chams[plr]:Destroy(); esp_chams[plr] = nil end
end
Players.PlayerRemoving:Connect(remove_player_esp)

local function create_esp(plr)
    if plr == LocalPlayer or esp_objects[plr] then return end
    local obj = {}
    obj.name = Drawing.new("Text"); obj.name.Size=16; obj.name.Center=true; obj.name.Outline=true; obj.name.Visible=false
    obj.distance = Drawing.new("Text"); obj.distance.Size=14; obj.distance.Center=true; obj.distance.Outline=true; obj.distance.Visible=false
    obj.box = Drawing.new("Square"); obj.box.Thickness=1; obj.box.Transparency=1; obj.box.Filled=false; obj.box.Visible=false
    obj.hp_bg = Drawing.new("Square"); obj.hp_bg.Filled=true; obj.hp_bg.Visible=false
    obj.hp_fill = Drawing.new("Square"); obj.hp_fill.Filled=true; obj.hp_fill.Visible=false
    obj.line = Drawing.new("Line"); obj.line.Thickness=1; obj.line.Transparency=0.5; obj.line.Visible=false
    obj.skeleton = {}
    for i=1,20 do obj.skeleton[i] = Drawing.new("Line"); obj.skeleton[i].Thickness=1; obj.skeleton[i].Visible=false end
    esp_objects[plr] = obj
end

local skel_r15 = {{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","HumanoidRootPart"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
local skel_r6 = {{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}

local function start_esp()
    RunService.RenderStepped:Connect(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if not cfg.esp_enabled or not is_alive(plr) then
                if esp_objects[plr] then for _, v in pairs(esp_objects[plr]) do if typeof(v)=="table" then for _,l in ipairs(v) do l.Visible=false end else v.Visible=false end end end
                if esp_chams[plr] then esp_chams[plr]:Destroy(); esp_chams[plr]=nil end
                continue
            end
            if not esp_objects[plr] then create_esp(plr) end
            local obj, char = esp_objects[plr], plr.Character
            local hrp, head, hum = char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChild("Head"), char and char:FindFirstChildOfClass("Humanoid")
            if hrp and head and hum then
                local head_pos, on_screen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local foot_pos, _ = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 2.5, 0))
                if on_screen then
                    if cfg.esp_chams and not esp_chams[plr] then
                        local h = Instance.new("Highlight"); h.FillColor=Color3.fromRGB(255,255,255); h.OutlineColor=Color3.fromRGB(255,255,255); h.Adornee=char; h.Parent=CoreGui; esp_chams[plr]=h
                    end
                    local dist = (get_hrp().Position - hrp.Position).Magnitude
                    local height = math.abs(head_pos.Y - foot_pos.Y)
                    local width = height * 0.6
                    local top_left = Vector2.new(head_pos.X - width / 2, head_pos.Y)
                    
                    obj.box.Size = Vector2.new(width, height); obj.box.Position = top_left; obj.box.Visible = cfg.esp_box; obj.box.Color = Color3.fromRGB(255, 255, 255)
                    if cfg.esp_health_bar then
                        local hp_ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        obj.hp_bg.Size = Vector2.new(3, height); obj.hp_bg.Position = Vector2.new(top_left.X - 6, top_left.Y); obj.hp_bg.Visible = true; obj.hp_bg.Color = Color3.fromRGB(0,0,0)
                        obj.hp_fill.Size = Vector2.new(3, height * hp_ratio); obj.hp_fill.Position = Vector2.new(top_left.X - 6, top_left.Y + (height * (1 - hp_ratio))); obj.hp_fill.Color = Color3.fromRGB(0, 255, 0); obj.hp_fill.Visible = true
                    else obj.hp_bg.Visible = false; obj.hp_fill.Visible = false end
                    
                    obj.name.Text = plr.Name; obj.name.Position = Vector2.new(head_pos.X, top_left.Y - 20); obj.name.Visible = cfg.esp_name; obj.name.Color = Color3.fromRGB(255,255,255)
                    obj.distance.Text = string.format("[%d m]", math.floor(dist)); obj.distance.Position = Vector2.new(head_pos.X, top_left.Y + height + 5); obj.distance.Visible = cfg.esp_distance; obj.distance.Color = Color3.fromRGB(255,255,0)
                    obj.line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y); obj.line.To = Vector2.new(head_pos.X, head_pos.Y); obj.line.Visible = cfg.esp_lines; obj.line.Color = Color3.fromRGB(255,255,255)
                    
                    if cfg.esp_skeleton then
                        local skel = char:FindFirstChild("UpperTorso") and skel_r15 or skel_r6
                        local i = 1
                        for _, conn in ipairs(skel) do
                            local p1, p2 = char:FindFirstChild(conn[1]), char:FindFirstChild(conn[2])
                            if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                                local s1, o1 = Camera:WorldToViewportPoint(p1.Position); local s2, o2 = Camera:WorldToViewportPoint(p2.Position)
                                if o1 and o2 and i <= #obj.skeleton then obj.skeleton[i].From = Vector2.new(s1.X, s1.Y); obj.skeleton[i].To = Vector2.new(s2.X, s2.Y); obj.skeleton[i].Visible = true; obj.skeleton[i].Color = Color3.fromRGB(255,255,255); i = i + 1 end
                            end
                        end
                        for j = i, #obj.skeleton do obj.skeleton[j].Visible = false end
                    else for _, line in ipairs(obj.skeleton) do line.Visible = false end end
                else
                    for _, v in pairs(obj) do if typeof(v)=="table" then for _,l in ipairs(v) do l.Visible=false end else v.Visible=false end end
                    if esp_chams[plr] then esp_chams[plr]:Destroy(); esp_chams[plr]=nil end
                end
            end
        end

        if cfg.esp_door then
            for _, door in ipairs(cached_doors) do
                if door and door:IsDescendantOf(Workspace) then
                    local part = door:IsA("Model") and (door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart")) or door
                    if part then
                        local pos, on_screen = Camera:WorldToViewportPoint(part.Position)
                        if not esp_doors[door] then
                            esp_doors[door] = Drawing.new("Text"); esp_doors[door].Size = 14; esp_doors[door].Center = true; esp_doors[door].Outline = true; esp_doors[door].Color = Color3.fromRGB(255, 165, 0); esp_doors[door].Text = "Halloween Door"
                        end
                        if on_screen then esp_doors[door].Position = Vector2.new(pos.X, pos.Y); esp_doors[door].Visible = true
                        else esp_doors[door].Visible = false end

                        if not door_chams[door] then
                            local h = Instance.new("Highlight"); h.FillColor=Color3.fromRGB(255, 165, 0); h.OutlineColor=Color3.fromRGB(255, 165, 0); h.Adornee=door; h.Parent=CoreGui; door_chams[door]=h
                        end
                    end
                end
            end
        else
            for door, txt in pairs(esp_doors) do txt:Remove(); esp_doors[door] = nil; if door_chams[door] then door_chams[door]:Destroy(); door_chams[door]=nil end end
        end
        
        for door, txt in pairs(esp_doors) do
            if not door or not door:IsDescendantOf(Workspace) then
                txt:Remove(); esp_doors[door] = nil
                if door_chams[door] then door_chams[door]:Destroy(); door_chams[door] = nil end
            end
        end
    end)
end
