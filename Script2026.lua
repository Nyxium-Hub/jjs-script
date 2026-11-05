-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 1)
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local K = getgenv().karpa or {}
getgenv().karpa = K

K.cfg = {
    -- Combate
    auto_block = false, block_range = 20,
    auto_combo = false, combo_range = 15, combo_delay = 0.1,
    auto_black_flash = false,
    
    -- Player
    speed_bypass = false, speed_val = 60,
    noclip_bypass = false, noclip_speed = 30,
    v_fly = false, v_fly_speed = 100,
    
    -- ESP
    esp_enabled = false, esp_name = true, esp_distance = true, esp_health_bar = true,
    esp_box = true, esp_skeleton = false, esp_chams = false, esp_character = true, esp_lines = false,
    
    -- Misc
    anti_afk = false,
}
local cfg = K.cfg

-- ============================================================
-- REMOTES E FUNÇÕES AUXILIARES
-- ============================================================
local Knit = ReplicatedStorage:WaitForChild("Knit"):WaitForChild("Knit"):WaitForChild("Services")
local BlockRE = Knit:WaitForChild("BlockService"):WaitForChild("RE")
local BlockActivate = BlockRE:WaitForChild("Activated")
local BlockDeactivate = BlockRE:WaitForChild("Deactivated")

local function get_hrp() local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() return c:FindFirstChild("HumanoidRootPart") end
local function get_hum() local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() return c:FindFirstChildOfClass("Humanoid") end
local function is_alive(plr) local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") return h and h.Health > 0 end

local function get_closest_enemy(range)
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

-- ============================================================
-- AUTO BLOCK
-- ============================================================
local is_blocking = false
local function update_auto_block()
    if not cfg.auto_block then
        if is_blocking then pcall(function() BlockDeactivate:FireServer() end); is_blocking = false end
        return
    end
    local enemy = get_closest_enemy(cfg.block_range)
    local is_attacking = false
    
    if enemy and enemy.Character then
        local enemy_hum = enemy.Character:FindFirstChildOfClass("Humanoid")
        if enemy_hum then
            for _, track in ipairs(enemy_hum:GetPlayingAnimationTracks()) do
                local a = track.Animation.Name:lower()
                if a:find("attack") or a:find("punch") or a:find("kick") or a:find("slash") or a:find("m1") then
                    is_attacking = true break
                end
            end
        end
    end
    if is_attacking and not is_blocking then
        if enemy.Character and enemy.Character:FindFirstChild("HumanoidRootPart") then
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, enemy.Character.HumanoidRootPart.Position)
        end
        pcall(function() BlockActivate:FireServer() end)
        is_blocking = true
    elseif not is_attacking and is_blocking then
        pcall(function() BlockDeactivate:FireServer() end)
        is_blocking = false
    end
end

-- ============================================================
-- PLAYER: TP WALK, NOCLIP BYPASS, V-FLY
-- ============================================================
local v_fly_vel = nil
local function update_player_movement(dt)
    local char = LocalPlayer.Character
    local hrp = get_hrp()
    local hum = get_hum()
    if not char or not hrp or not hum then return end
    
    -- TP WALK (Speed Bypass)
    if cfg.speed_bypass then
        hum.WalkSpeed = 16
        if hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * cfg.speed_val * dt)
        end
    else
        hum.WalkSpeed = 16
    end
    
    -- NOCLIP BYPASS
    if cfg.noclip_bypass then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = false end
        end
        hrp.CanCollide = false
        -- Se estiver andando, empurra o HRP para frente para burlar o "puxão" do anticheat
        if hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * cfg.noclip_speed * dt)
        end
    else
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
    
    -- V-FLY (Vehicle Fly Bypass)
    if cfg.v_fly then
        hum.PlatformStand = true
        if not v_fly_vel or v_fly_vel.Parent ~= hrp then
            if v_fly_vel then v_fly_vel:Destroy() end
            v_fly_vel = Instance.new("BodyVelocity")
            v_fly_vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            v_fly_vel.Velocity = Vector3.zero
            v_fly_vel.Parent = hrp
        end
        
        local dir = Vector3.zero
        local cam_cf = Camera.CFrame
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then dir += cam_cf.LookVector end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then dir -= cam_cf.LookVector end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then dir -= cam_cf.RightVector end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then dir += cam_cf.RightVector end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
        
        if dir.Magnitude > 0 then dir = dir.Unit end
        v_fly_vel.Velocity = dir * cfg.v_fly_speed
    else
        if v_fly_vel then v_fly_vel:Destroy() v_fly_vel = nil end
        if hum.PlatformStand then hum.PlatformStand = false end
    end
end

-- ============================================================
-- ESP
-- ============================================================
local esp_objects, esp_chams = {}, {}
local function create_esp(plr)
    if plr == LocalPlayer or esp_objects[plr] then return end
    local obj = {}
    obj.name = Drawing.new("Text"); obj.name.Size=16; obj.name.Center=true; obj.name.Outline=true; obj.name.Color=Color3.fromRGB(255,255,255); obj.name.Visible=false
    obj.distance = Drawing.new("Text"); obj.distance.Size=14; obj.distance.Center=true; obj.distance.Outline=true; obj.distance.Color=Color3.fromRGB(255,255,0); obj.distance.Visible=false
    obj.character = Drawing.new("Text"); obj.character.Size=14; obj.character.Center=true; obj.character.Outline=true; obj.character.Color=Color3.fromRGB(255,100,255); obj.character.Visible=false
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
            local head_pos, on_screen = Camera:WorldToViewportPoint(head.Position)
            if not on_screen then
                for _, v in pairs(obj) do if typeof(v)=="table" then for _,l in ipairs(v) do l.Visible=false end else v.Visible=false end end
                apply_chams(plr, false) continue
            end
            apply_chams(plr, cfg.esp_chams)
            local dist = (get_hrp().Position - hrp.Position).Magnitude
            
            obj.name.Text = plr.Name; obj.name.Position = Vector2.new(head_pos.X, head_pos.Y - 45); obj.name.Visible = cfg.esp_name
            obj.distance.Text = string.format("[%d m]", math.floor(dist)); obj.distance.Position = Vector2.new(head_pos.X, head_pos.Y - 25); obj.distance.Visible = cfg.esp_distance
            local cName = plr:GetAttribute("Character") or char:GetAttribute("Character") or char.Name
            obj.character.Text = "[" .. tostring(cName) .. "]"; obj.character.Position = Vector2.new(head_pos.X, head_pos.Y - 65); obj.character.Visible = cfg.esp_character
            
            local root_pos = Camera:WorldToViewportPoint(hrp.Position)
            local height, width = math.abs(head_pos.Y - root_pos.Y) * 1.5, math.abs(head_pos.Y - root_pos.Y) * 1.5 * 0.6
            local top_left = Vector2.new(head_pos.X - width/2, head_pos.Y - height * 0.2)
            obj.box.Size = Vector2.new(width, height); obj.box.Position = top_left; obj.box.Visible = cfg.esp_box
            
            if cfg.esp_health_bar then
                local hp_ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                obj.hp_bg.Size = Vector2.new(3, height); obj.hp_bg.Position = Vector2.new(top_left.X - 6, top_left.Y); obj.hp_bg.Visible = true
                obj.hp_fill.Size = Vector2.new(3, height * hp_ratio); obj.hp_fill.Position = Vector2.new(top_left.X - 6, top_left.Y + (height * (1 - hp_ratio))); obj.hp_fill.Color = Color3.fromRGB(math.floor(255*(1-hp_ratio)), math.floor(255*hp_ratio), 0); obj.hp_fill.Visible = true
            else obj.hp_bg.Visible = false; obj.hp_fill.Visible = false end
            
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
local is_combing = false
local function start_auto_combo()
    RunService.Heartbeat:Connect(function()
        if not cfg.auto_combo or is_combing then return end
        local enemy = get_closest_enemy(cfg.combo_range)
        if not enemy or not enemy.Character then return end
        local my_hrp, enemy_hrp = get_hrp(), enemy.Character:FindFirstChild("HumanoidRootPart")
        if not my_hrp or not enemy_hrp then return end
        
        is_combing = true
        if (my_hrp.Position - enemy_hrp.Position).Magnitude > 10 then
            my_hrp.CFrame = my_hrp.CFrame + (enemy_hrp.Position - my_hrp.Position).Unit * 5; task.wait(0.1)
        end
        pcall(function() VirtualInputManager:SendMouseButtonEvent(0,0,1,true,game,0); task.wait(0.1); VirtualInputManager:SendMouseButtonEvent(0,0,1,false,game,0) end)
        task.wait(0.1)
        pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Three, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Three, false, game) end)
        task.wait(0.2)
        if cfg.auto_black_flash then
            task.wait(0.15)
            pcall(function() VirtualInputManager:SendMouseButtonEvent(0,0,1,true,game,0); task.wait(0.05); VirtualInputManager:SendMouseButtonEvent(0,0,1,false,game,0) end)
        end
        task.wait(0.3); is_combing = false
    end)
end

local function start_anti_afk()
    RunService.Heartbeat:Connect(function()
        if not cfg.anti_afk then return end
        pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
    end)
end

-- INICIALIZAÇÃO DOS LOOPS
RunService.Heartbeat:Connect(update_auto_block)
RunService.RenderStepped:Connect(update_player_movement)
start_auto_combo()
start_esp()
start_anti_afk()

-- INTERFACE WIND UI (TEMA ESCURO/PRETO)
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Nyxium | Itadori",
    Author = "karpa",
    Folder = "NyxiumItadori",
    Size = UDim2.fromOffset(520, 420),
    Theme = "Dark", -- Voltou ao tema padrão escuro
    Resizable = true,
})

-- ABA COMBAT
local Tab = Window:Tab({ Title = "Combat", Icon = "swords" })
Tab:Section({ Title = "Auto Combo (M1 + Skill 3)" })
Tab:Toggle({ Title = "Auto Combo", Desc = "Executa M1 + Divergent Fist", Default = false, Callback = function(s) cfg.auto_combo = s end })
Tab:Slider({ Title = "Combo Range", Value = { Min = 5, Max = 30, Default = 15 }, Callback = function(v) cfg.combo_range = v end })

Tab:Section({ Title = "Auto Black Flash" })
Tab:Toggle({ Title = "Auto Black Flash", Desc = "Tenta o timing perfeito", Default = false, Callback = function(s) cfg.auto_black_flash = s end })

Tab:Section({ Title = "Auto Block (Remotes)" })
Tab:Toggle({ Title = "Auto Block", Desc = "Ativa a defesa via Remote", Default = false, Callback = function(s) cfg.auto_block = s end })
Tab:Slider({ Title = "Block Range", Value = { Min = 5, Max = 50, Default = 20 }, Callback = function(v) cfg.block_range = v end })

-- ABA PLAYER
local PlayerTab = Window:Tab({ Title = "Player", Icon = "user" })

PlayerTab:Section({ Title = "Speed Bypass (TP Walk)" })
PlayerTab:Toggle({ Title = "Enable Speed Bypass", Default = false, Callback = function(s) cfg.speed_bypass = s end })
PlayerTab:Slider({ Title = "Speed Value", Value = { Min = 16, Max = 250, Default = 60 }, Callback = function(v) cfg.speed_val = v end })

PlayerTab:Section({ Title = "Noclip Bypass" })
PlayerTab:Toggle({ Title = "Enable Noclip Bypass", Desc = "Força a passagem sem colisão", Default = false, Callback = function(s) cfg.noclip_bypass = s end })
PlayerTab:Slider({ Title = "Push Speed", Value = { Min = 10, Max = 100, Default = 30 }, Callback = function(v) cfg.noclip_speed = v end })

PlayerTab:Section({ Title = "V-Fly (Vehicle Fly)" })
PlayerTab:Toggle({ Title = "Enable V-Fly", Desc = "Voo não detectável", Default = false, Callback = function(s) cfg.v_fly = s end })
PlayerTab:Slider({ Title = "Fly Speed", Value = { Min = 16, Max = 500, Default = 100 }, Callback = function(v) cfg.v_fly_speed = v end })

-- ABA VISUALS (ESP)
local VisTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
VisTab:Section({ Title = "ESP Principal" })
VisTab:Toggle({ Title = "Enable ESP", Default = false, Callback = function(s) cfg.esp_enabled = s end })
VisTab:Toggle({ Title = "Chams (Branco)", Default = false, Callback = function(s) cfg.esp_chams = s end })
VisTab:Toggle({ Title = "Box", Default = true, Callback = function(s) cfg.esp_box = s end })
VisTab:Toggle({ Title = "Skeleton", Default = false, Callback = function(s) cfg.esp_skeleton = s end })
VisTab:Toggle({ Title = "Lines", Default = false, Callback = function(s) cfg.esp_lines = s end })

VisTab:Section({ Title = "Informações" })
VisTab:Toggle({ Title = "Nome", Default = true, Callback = function(s) cfg.esp_name = s end })
VisTab:Toggle({ Title = "Personagem", Default = true, Callback = function(s) cfg.esp_character = s end })
VisTab:Toggle({ Title = "Distância", Default = true, Callback = function(s) cfg.esp_distance = s end })
VisTab:Toggle({ Title = "Barra de Vida", Default = true, Callback = function(s) cfg.esp_health_bar = s end })

-- ABA MISC
local MiscTab = Window:Tab({ Title = "Misc", Icon = "settings" })
MiscTab:Section({ Title = "Outros" })
MiscTab:Toggle({ Title = "Anti AFK", Default = false, Callback = function(s) cfg.anti_afk = s end })
MiscTab:Button({
    Title = "Unload Script",
    Callback = function() 
        Window:Destroy() 
        for _, plr in pairs(Players:GetPlayers()) do
            if esp_objects[plr] then
                for _, v in pairs(esp_objects[plr]) do if typeof(v) == "table" then for _, line in ipairs(v) do line:Remove() end else v:Remove() end end
            end
            apply_chams(plr, false)
        end
    end,
})