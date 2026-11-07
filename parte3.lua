-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 3 - CORRIGIDA)
-- ============================================================
local door_state = "IDLE"
local target_door_model, target_door_part = nil, nil
local target_prompt = nil
local door_interact_time = 0
local is_holding_e = false
local door_height_bp = nil
local door_target_height = nil
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

local function stop_height_controller()
    if door_height_bp then door_height_bp:Destroy(); door_height_bp = nil end
    door_target_height = nil
end

local function start_auto_open_door()
    RunService.Heartbeat:Connect(function(dt)
        -- Toggle desligado: reseta tudo
        if not cfg.auto_open_door then
            if door_state ~= "IDLE" then
                door_state = "IDLE"
                if is_holding_e then 
                    if target_prompt then pcall(function() target_prompt:InputHoldEnd() end) end
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); is_holding_e = false 
                end
                unlock_camera()
                stop_height_controller()
            end
            return
        end

        local char, hrp, hum = LocalPlayer.Character, get_hrp(), get_hum()
        if not char or not hrp or not hum then stop_height_controller() return end
        
        if hum.Health <= 0 then
            pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
            return
        end

        if #cached_doors == 0 then 
            stop_height_controller()
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

        -- IDLE: começa a flutuar 300 studs
        if door_state == "IDLE" then
            door_state = "WAITING"
            door_target_height = hrp.Position.Y + 300
            if not door_height_bp then
                door_height_bp = Instance.new("BodyPosition")
                door_height_bp.MaxForce = Vector3.new(0, math.huge, 0)
                door_height_bp.P = 5000
                door_height_bp.D = 500
                door_height_bp.Position = Vector3.new(hrp.Position.X, door_target_height, hrp.Position.Z)
                door_height_bp.Parent = hrp
            end
        end
        
        -- WAITING: flutuando nos 300 até liberar
        if door_state == "WAITING" then
            if door_height_bp then
                door_height_bp.Position = Vector3.new(hrp.Position.X, door_target_height, hrp.Position.Z)
            end
            
            if any_unlocked and closest_door then
                stop_height_controller()
                target_door_model = closest_door
                target_door_part = closest_part
                door_state = "FLYING"
                door_target_height = closest_part.Position.Y + 200
                door_height_bp = Instance.new("BodyPosition")
                door_height_bp.MaxForce = Vector3.new(0, math.huge, 0)
                door_height_bp.P = 5000
                door_height_bp.D = 500
                door_height_bp.Position = Vector3.new(hrp.Position.X, door_target_height, hrp.Position.Z)
                door_height_bp.Parent = hrp
            end
        end

        -- FLYING: voa horizontalmente em cima da porta
        if door_state == "FLYING" then
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) or check_if_locked(target_door_model) then 
                stop_height_controller()
                door_state = "IDLE"
                return 
            end
            
            if door_height_bp then
                door_height_bp.Position = Vector3.new(hrp.Position.X, door_target_height, hrp.Position.Z)
            end
            
            local door_xz = Vector3.new(target_door_part.Position.X, hrp.Position.Y, target_door_part.Position.Z)
            local dist_xz = (hrp.Position - door_xz).Magnitude
            
            if dist_xz > 4 then
                local move_dir = (door_xz - hrp.Position).Unit
                hrp.CFrame = hrp.CFrame + (move_dir * 100 * dt)
            else
                door_state = "DESCENDING"
                door_target_height = target_door_part.Position.Y + 3
            end
        end

        -- DESCENDING: desce devagar
        if door_state == "DESCENDING" then
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) then 
                stop_height_controller()
                door_state = "IDLE"
                return 
            end
            
            if door_height_bp then
                door_height_bp.Position = Vector3.new(hrp.Position.X, door_target_height, hrp.Position.Z)
            end
            
            local dist_y = math.abs(hrp.Position.Y - door_target_height)
            if dist_y < 2 then
                stop_height_controller()
                door_state = "OPENING"
                door_interact_time = tick()
                
                if not is_holding_e then
                    if target_prompt then pcall(function() target_prompt:InputHoldBegin() end) end
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    is_holding_e = true
                end
            end
        end

        -- OPENING: trava camera, segura E por 6s
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
                door_state = "IDLE"
                task.wait(0.5)
            end
        end
    end)
end