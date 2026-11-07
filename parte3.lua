-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 3 - AUTO DOOR CORRIGIDO)
-- ============================================================
local door_state = "IDLE"
local target_door_model, target_door_part = nil, nil
local target_prompt = nil
local door_interact_time = 0
local is_holding_e = false
local door_fly_y = nil
local door_just_opened_time = 0

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

local function start_auto_open_door()
    RunService.Heartbeat:Connect(function(dt)
        if not cfg.auto_open_door then
            if door_state ~= "IDLE" then
                door_state = "IDLE"
                if is_holding_e then
                    if target_prompt then pcall(function() target_prompt:InputHoldEnd() end) end
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); is_holding_e = false
                end
                local hum = get_hum()
                if hum then hum.PlatformStand = false end
            end
            return
        end

        local char, hrp, hum = LocalPlayer.Character, get_hrp(), get_hum()
        if not char or not hrp or not hum then return end
        if hum.Health <= 0 then
            pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
            return
        end
        if #cached_doors == 0 then return end

        -- Procura a próxima porta destrancada (sempre)
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

        -- IDLE / ESPERA
        if door_state == "IDLE" or door_state == "WAITING" then
            hum.PlatformStand = true
            hum.WalkSpeed = 0
            if door_state == "IDLE" then
                door_state = "WAITING"
                door_fly_y = hrp.Position.Y + 300
            end

            if any_unlocked and closest_door then
                target_door_model = closest_door
                target_door_part = closest_part
                door_state = "SUBINDO_POS_PORTA"
                door_fly_y = hrp.Position.Y + 200
            else
                -- Fica subindo/mantendo os 300
                local current_y = hrp.Position.Y
                if current_y < door_fly_y - 3 then
                    hrp.CFrame = CFrame.new(hrp.Position.X, current_y + 4, hrp.Position.Z)
                else
                    hrp.CFrame = CFrame.new(hrp.Position.X, door_fly_y, hrp.Position.Z)
                end
            end
        end

        -- SUBINDO_POS_PORTA: sobe 200 depois de abrir porta
        if door_state == "SUBINDO_POS_PORTA" then
            hum.PlatformStand = true
            local current_y = hrp.Position.Y
            if current_y < door_fly_y - 3 then
                hrp.CFrame = CFrame.new(hrp.Position.X, current_y + 4, hrp.Position.Z)
            else
                hrp.CFrame = CFrame.new(hrp.Position.X, door_fly_y, hrp.Position.Z)
                door_state = "VOANDO"
            end
        end

        -- VOANDO: voa horizontal em cima da porta
        if door_state == "VOANDO" then
            hum.PlatformStand = true
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) then
                door_state = "IDLE" return
            end
            local door_xz = Vector3.new(target_door_part.Position.X, hrp.Position.Y, target_door_part.Position.Z)
            local dist_xz = (hrp.Position - door_xz).Magnitude
            if dist_xz > 5 then
                local move_dir = (door_xz - hrp.Position).Unit
                hrp.CFrame = hrp.CFrame + (move_dir * 200 * dt)
            else
                door_state = "DESCENDO_FRENTE"
            end
        end

        -- DESCENDO_FRENTE: desce 30 studs na frente da porta
        if door_state == "DESCENDO_FRENTE" then
            hum.PlatformStand = true
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) then
                door_state = "IDLE" return
            end
            local look = target_door_part.CFrame.LookVector
            local front_pos = target_door_part.Position + (look * 30)
            local current_y = hrp.Position.Y
            if current_y > front_pos.Y + 3 then
                hrp.CFrame = CFrame.new(front_pos.X, current_y - 6, front_pos.Z)
            else
                door_state = "ANDANDO_PORTA"
            end
        end

        -- ANDANDO_PORTA: anda até a porta
        if door_state == "ANDANDO_PORTA" then
            hum.PlatformStand = false
            hum.WalkSpeed = 16
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) then
                door_state = "IDLE" return
            end
            local target_pos = target_door_part.Position
            local dist = (hrp.Position - target_pos).Magnitude
            if dist > 4 then
                local move_dir = (target_pos - hrp.Position).Unit
                hrp.CFrame = hrp.CFrame + (move_dir * 100 * dt)
            else
                door_state = "OPENING"
                hum.WalkSpeed = 0
                door_interact_time = tick()
                if not is_holding_e then
                    if target_prompt then pcall(function() target_prompt:InputHoldBegin() end) end
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    is_holding_e = true
                end
            end
        end

        -- OPENING: segura E por 6s, depois sobe 200 e vai pra próxima
        if door_state == "OPENING" then
            if hum.Health <= 0 then
                pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
            end
            if target_door_part then hrp.CFrame = CFrame.new(target_door_part.Position + Vector3.new(0, 2, 0)) end
            if not target_door_model or not target_door_model:IsDescendantOf(Workspace) or (target_door_part and target_door_part.Transparency == 1) or (tick() - door_interact_time > 6) then
                if is_holding_e then
                    if target_prompt then pcall(function() target_prompt:InputHoldEnd() end) end
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); is_holding_e = false
                end
                hum.PlatformStand = true
                hum.WalkSpeed = 16
                -- Sobe 200 e vai pra próxima porta
                door_state = "WAITING"
                door_fly_y = hrp.Position.Y + 300
                task.wait(0.3)
            end
        end
    end)
end

if update_auto_block then RunService.Heartbeat:Connect(update_auto_block) end
if update_player_movement then RunService.RenderStepped:Connect(update_player_movement) end
if start_auto_farm then start_auto_farm() end
if start_auto_open_door then start_auto_open_door() end
if start_esp then start_esp() end