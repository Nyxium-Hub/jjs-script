-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 4 - SEM COMBAT)
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = WindUI:CreateWindow({ Title = "Nyxium | Itadori", Author = "karpa", Folder = "NyxiumItadori", Size = UDim2.fromOffset(520, 420), Theme = "Dark", Resizable = true })

local function notify(title, text)
    if WindUI and WindUI.Notify then
        pcall(function() WindUI:Notify({ Title = title, Content = text, Duration = 3 }) end)
    end
end

-- BOTÃO PRETO FLUTUANTE
local gui = Instance.new("ScreenGui")
gui.Name = "NyxiumFloat"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = game:GetService("CoreGui")

local floatingBtn = Instance.new("TextButton")
floatingBtn.Size = UDim2.fromOffset(44, 44)
floatingBtn.Position = UDim2.new(0, 20, 0, 100)
floatingBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
floatingBtn.Text = "N"
floatingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
floatingBtn.Font = Enum.Font.GothamBold
floatingBtn.TextSize = 20
floatingBtn.BorderSizePixel = 0
floatingBtn.AutoButtonColor = false
floatingBtn.Parent = gui
local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(0, 10); c1.Parent = floatingBtn
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(80, 80, 80); stroke.Thickness = 2; stroke.Parent = floatingBtn

local dragging = false
local dragStart = nil
local startPos = nil
local hasDragged = false

floatingBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        hasDragged = false
        dragStart = input.Position
        startPos = floatingBtn.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then
            hasDragged = true
        end
        floatingBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

floatingBtn.MouseButton1Click:Connect(function()
    if not hasDragged then
        pcall(function() Window:Toggle() end)
    end
    hasDragged = false
end)

-- ABAS (SEM COMBAT)
local MiscTab = Window:Tab({ Title = "Misc", Icon = "crosshair" })
MiscTab:Section({ Title = "Aimbot" })
MiscTab:Toggle({ Title = "Enable Aimbot", Default = false, Callback = function(s) cfg.aim_enabled = s; notify("Aimbot", s and "Ativado" or "Desativado") end })
MiscTab:Toggle({ Title = "Hold RMB", Default = false, Callback = function(s) cfg.aim_hold_rmb = s; notify("Hold RMB", s and "Ativado" or "Desativado") end })
MiscTab:Toggle({ Title = "Show FOV", Default = false, Callback = function(s) cfg.show_fov = s; notify("Show FOV", s and "Ativado" or "Desativado") end })
MiscTab:Toggle({ Title = "Visible Check", Default = true, Callback = function(s) cfg.aim_visible_check = s end })
MiscTab:Toggle({ Title = "Dead Check", Default = true, Callback = function(s) cfg.aim_dead_check = s end })
MiscTab:Slider({ Title = "FOV Size", Value = { Min = 20, Max = 500, Default = 120 }, Callback = function(v) cfg.aim_fov = v end })
MiscTab:Slider({ Title = "Smoothness", Value = { Min = 1, Max = 100, Default = 15 }, Callback = function(v) cfg.aim_smoothness = v end })
MiscTab:Section({ Title = "Console Lock On" })
MiscTab:Toggle({ Title = "Enable Lock On", Default = false, Callback = function(s) cfg.lock_on_enabled = s; notify("Lock On", s and "Ativado" or "Desativado") end })
MiscTab:Slider({ Title = "Lock On Range", Value = { Min = 5, Max = 50, Default = 20 }, Callback = function(v) cfg.lock_on_range = v end })
MiscTab:Section({ Title = "Auto Regen" })
MiscTab:Toggle({ Title = "Auto Regen (R)", Default = false, Callback = function(s) cfg.auto_regen = s; notify("Auto Regen", s and "Ativado" or "Desativado") end })

local PlayerTab = Window:Tab({ Title = "Player", Icon = "user" })
PlayerTab:Section({ Title = "Speed Bypass" })
PlayerTab:Toggle({ Title = "Enable Speed", Default = false, Callback = function(s) cfg.speed_bypass = s; notify("Speed Bypass", s and "Ativado" or "Desativado") end })
PlayerTab:Slider({ Title = "Speed Value", Value = { Min = 16, Max = 250, Default = 60 }, Callback = function(v) cfg.speed_val = v end })
PlayerTab:Section({ Title = "Noclip Bypass" })
PlayerTab:Toggle({ Title = "Enable Noclip", Default = false, Callback = function(s) cfg.noclip_bypass = s; notify("Noclip", s and "Ativado" or "Desativado") end })
PlayerTab:Slider({ Title = "Push Speed", Value = { Min = 10, Max = 100, Default = 60 }, Callback = function(v) cfg.noclip_speed = v end })
PlayerTab:Section({ Title = "Fly Bypass" })
PlayerTab:Toggle({ Title = "Enable Fly", Default = false, Callback = function(s) cfg.fly_bypass = s; notify("Fly", s and "Ativado" or "Desativado") end })
PlayerTab:Slider({ Title = "Fly Speed", Value = { Min = 16, Max = 500, Default = 100 }, Callback = function(v) cfg.fly_speed = v end })
PlayerTab:Section({ Title = "Jump Power" })
PlayerTab:Toggle({ Title = "Enable Jump", Default = false, Callback = function(s) cfg.jump_power_enabled = s; notify("Jump Power", s and "Ativado" or "Desativado") end })
PlayerTab:Slider({ Title = "Jump Value", Value = { Min = 50, Max = 250, Default = 50 }, Callback = function(v) cfg.jump_power_val = v end })
PlayerTab:Toggle({ Title = "Infinite Jump", Default = false, Callback = function(s) cfg.inf_jump = s; notify("Infinite Jump", s and "Ativado" or "Desativado") end })

local FarmTab = Window:Tab({ Title = "Farm", Icon = "leaf" })
FarmTab:Section({ Title = "Pumpkin Farm" })
FarmTab:Toggle({ Title = "Auto Get Pumpkin", Default = false, Callback = function(s) cfg.auto_farm_pumpkin = s; notify("Auto Pumpkin", s and "Ativado" or "Desativado") end })
FarmTab:Section({ Title = "Halloween Door Farm" })
FarmTab:Toggle({ Title = "ESP Halloween Door", Default = false, Callback = function(s) cfg.esp_door = s; notify("ESP Door", s and "Ativado" or "Desativado") end })
FarmTab:Toggle({ Title = "Auto Open Door", Default = false, Callback = function(s) cfg.auto_open_door = s; notify("Auto Door", s and "Ativado" or "Desativado") end })
FarmTab:Toggle({ Title = "Door Noclip", Default = true, Callback = function(s) cfg.door_noclip = s; notify("Door Noclip", s and "Ativado" or "Desativado") end })

local VisTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
VisTab:Section({ Title = "ESP Principal" })
VisTab:Toggle({ Title = "Enable ESP", Default = false, Callback = function(s) cfg.esp_enabled = s; notify("ESP", s and "Ativado" or "Desativado") end })
VisTab:Toggle({ Title = "Chams", Default = false, Callback = function(s) cfg.esp_chams = s; notify("Chams", s and "Ativado" or "Desativado") end })
VisTab:Section({ Title = "Elementos" })
VisTab:Toggle({ Title = "Box", Default = false, Callback = function(s) cfg.esp_box = s end })
VisTab:Toggle({ Title = "Skeleton", Default = false, Callback = function(s) cfg.esp_skeleton = s end })
VisTab:Toggle({ Title = "Lines", Default = false, Callback = function(s) cfg.esp_lines = s end })
VisTab:Toggle({ Title = "Nome", Default = false, Callback = function(s) cfg.esp_name = s end })
VisTab:Toggle({ Title = "Distância", Default = false, Callback = function(s) cfg.esp_distance = s end })
VisTab:Toggle({ Title = "Barra de Vida", Default = false, Callback = function(s) cfg.esp_health_bar = s end })