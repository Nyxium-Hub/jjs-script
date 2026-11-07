local door_state = "IDLE"
local target_door_model, target_door_part = nil, nil
local target_prompt = nil
local door_interact_time = 0
local is_holding_e = false
local wait_bp = nil
local wait_fly_y = nil

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
    wait_fly_y = nil
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
                door_state = "FLYING"
                hum.PlatformStand = true
                wait_fly_y = closest_part.Position.Y + 200
                wait_bp = Instance.new("BodyPosition")
                wait_bp.MaxForce = Vector3.new(0, math.huge, 0)
                wait_bp.P = 10000
                wait_bp.D = 500
                wait_bp.Position = Vector3.new(hrp.Position.X, wait_fly_y, hrp.Position.Z)
                wait_bp.Parent = hrp
            else
                door_state = "WAITING"
                hum.PlatformStand = true
                wait_fly_y = hrp.Position.Y + 300
                if not wait_bp then
                    wait_bp = Instance.new("BodyPosition")
                    wait_bp.MaxForce = Vector3.new(0, math.huge, 0)
                    wait_bp.P = 10000
                    wait_bp.D = 500
                    wait_bp.Position = Vector3.new(hrp.Position.X, wait_fly_y, hrp.Position.Z)
                    wait_bp.Parent = hrp
                end
            end
        end

        if door_state == "WAITING" then
            if any_unlocked then
                stop_waiting()
                target_door_model = closest_door
                target_door_part = closest_part
                door_state = "FLYING"
                hum.PlatformStand = true
                wait_fly_y = closest_part.Position.Y + 200
                wait_bp = Instance.new("BodyPosition")
                wait_bp.MaxForce = Vector3.new(0, math.huge, 0)
                wait_bp.P = 10000
                wait_bp.D = 500
                wait_bp.Position = Vector3.new(hrp.Position.X, wait_fly_y, hrp.Position.Z)
                wait_bp.Parent = hrp
            else
                if wait_bp then wait_bp.Position = Vector3.new(hrp.Position.X, wait_fly_y, hrp.Position.Z) end
            end
        end

        if door_state == "FLYING" then
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) then
                door_state = "IDLE" return
            end
            if wait_bp then wait_bp.Position = Vector3.new(hrp.Position.X, wait_fly_y, hrp.Position.Z) end
            local door_xz = Vector3.new(target_door_part.Position.X, hrp.Position.Y, target_door_part.Position.Z)
            local dist_xz = (hrp.Position - door_xz).Magnitude
            if dist_xz > 5 then
                local move_dir = (door_xz - hrp.Position).Unit
                hrp.CFrame = hrp.CFrame + (move_dir * 150 * dt)
            else
                door_state = "DESCENDING"
                if wait_bp then wait_bp:Destroy(); wait_bp = nil end
                hum.PlatformStand = false
            end
        end

        if door_state == "DESCENDING" then
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) then
                door_state = "IDLE" return
            end
            local target_pos = target_door_part.Position
            local dist = (hrp.Position - target_pos).Magnitude
            if dist > 4 then
                local move_dir = (target_pos - hrp.Position).Unit
                hrp.CFrame = hrp.CFrame + (move_dir * 200 * dt)
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
                hum.PlatformStand = false
                hum.WalkSpeed = 16
                for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end
                door_state = "IDLE"
                task.wait(0.5)
            end
        end
    end)
end

if update_auto_block then RunService.Heartbeat:Connect(update_auto_block) end
if update_player_movement then RunService.RenderStepped:Connect(update_player_movement) end
if start_auto_farm then start_auto_farm() end
if start_auto_open_door then start_auto_open_door() end
if start_esp then start_esp() end