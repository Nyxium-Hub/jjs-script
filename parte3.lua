-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 3 - ATUALIZADA)
-- ============================================================
local door_state = "IDLE"
local target_door_model, target_door_part = nil, nil
local target_prompt = nil
local door_interact_time = 0
local is_holding_e = false
local door_fly_bp = nil
local door_fly_pos = nil
local camera_locked = false
local locked_cam_cf = nil

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

local function lock_camera()
    if not camera_locked then
        camera_locked = true
        locked_cam_cf = Camera.CFrame
    end
    if locked_cam_cf then
        Camera.CFrame = locked_cam_cf
    end
end

local function unlock_camera()
    camera_locked = false
    locked_cam_cf = nil
end

local function stop_door_fly()
    local hum = get_hum()
    if hum then hum.PlatformStand = false end
    if door_fly_bp then door_fly_bp:Destroy(); door_fly_bp = nil end
    door_fly_pos = nil
end

local function start_auto_open_door()
    RunService.Heartbeat:Connect(function(dt)
        -- Se o toggle desligou, reseta tudo
        if not cfg.auto_open_door then
            if door_state ~= "IDLE" then
                door_state = "IDLE"
                if is_holding_e then 
                    if target_prompt then pcall(function() target_prompt:InputHoldEnd() end) end
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); is_holding_e = false 
                end
                unlock_camera()
                stop_door_fly()
            end
            return
        end

        local char, hrp, hum = LocalPlayer.Character, get_hrp(), get_hum()
        if not char or not hrp or not hum then stop_door_fly() return end
        
        if hum.Health <= 0 then
            pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
            return
        end

        if #cached_doors == 0 then 
            stop_door_fly()
            if door_state ~= "IDLE" then door_state = "IDLE" unlock_camera() end
            return 
        end

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

        -- Se tá IDLE (sem porta liberada) -> Sobe 300 e fica lá esperando
        if door_state == "IDLE" then
            door_state = "WAITING"
            hum.PlatformStand = true
            door_fly_pos = hrp.Position + Vector3.new(0, 300, 0)
            if door_fly_bp then door_fly_bp:Destroy() end
            door_fly_bp = Instance.new("BodyPosition")
            door_fly_bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            door_fly_bp.P = 10000
            door_fly_bp.D = 500
            door_fly_bp.Position = door_fly_pos
            door_fly_bp.Parent = hrp
        end
        
        -- Se tá WAITING -> Verifica se liberou. Se sim, vai pra FLYING
        if door_state == "WAITING" then
            if any_unlocked and closest_door then
                stop_door_fly()
                target_door_model = closest_door
                target_door_part = closest_part
                door_state = "FLYING"
                hum.PlatformStand = true
                door_fly_pos = closest_part.Position + Vector3.new(0, 200, 0)
                door_fly_bp = Instance.new("BodyPosition")
                door_fly_bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                door_fly_bp.P = 10000
                door_fly_bp.D = 500
                door_fly_bp.Position = door_fly_pos
                door_fly_bp.Parent = hrp
            else
                -- Continua flutuando
                if door_fly_bp then door_fly_bp.Position = door_fly_pos end
            end
        end

        -- Se tá FLYING -> Voa até em cima da porta
        if door_state == "FLYING" then
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) or check_if_locked(target_door_model) then 
                stop_door_fly()
                door_state = "IDLE"
                return 
            end
            
            local door_pos = target_door_part.Position
            local top_door_pos = door_pos + Vector3.new(0, 200, 0)
            if door_fly_bp then door_fly_bp.Position = top_door_pos end
            
            -- Se chegou em cima da porta, desce pra interagir
            local dist = (hrp.Position - door_pos).Magnitude
            if dist < 15 then
                stop_door_fly()
                door_state = "DESCENDING"
                hum.PlatformStand = true
                -- Desce 200 studs
                if door_fly_bp then door_fly_bp:Destroy() end
                door_fly_bp = Instance.new("BodyPosition")
                door_fly_bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                door_fly_bp.P = 10000
                door_fly_bp.D = 500
                door_fly_bp.Position = door_pos + Vector3.new(0, 3, 0)
                door_fly_bp.Parent = hrp
            end
        end

        -- Se tá DESCENDING -> Desce e começa a interagir
        if door_state == "DESCENDING" then
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) then 
                stop_door_fly()
                door_state = "IDLE"
                return 
            end
            
            local door_pos = target_door_part.Position
            local dist = (hrp.Position - door_pos).Magnitude
            
            if dist < 4 then
                stop_door_fly()
                door_state = "OPENING"
                door_interact_time = tick()
                
                if not is_holding_e then
                    if target_prompt then pcall(function() target_prompt:InputHoldBegin() end) end
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    is_holding_e = true
                end
            else
                -- Continua descendo
                if door_fly_bp then door_fly_bp.Position = door_pos + Vector3.new(0, 3, 0) end
            end
        end

        -- Se tá OPENING -> Trava a câmera e interage por 6 segundos
        if door_state == "OPENING" then
            lock_camera()
            
            if hum.Health <= 0 then
                pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
            end
            
            if not target_door_model or not target_door_model:IsDescendantOf(Workspace) or (target_door_part and target_door_part.Transparency == 1) or (tick() - door_interact_time > 6) then
                if is_holding_e then 
                    if target_prompt then pcall(function() target_prompt:InputHoldEnd() end) end
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); is_holding_e = false 
                end
                
                unlock_camera()
                hum.PlatformStand = false
                door_state = "IDLE"
                task.wait(0.5)
            end
        end
    end)
end