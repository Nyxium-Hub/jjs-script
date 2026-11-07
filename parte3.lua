-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 3)
-- ============================================================
local door_state = "IDLE"
local target_door_model, target_door_part = nil, nil
local target_prompt = nil
local door_interact_time = 0
local walk_timer = 0
local is_holding_e = false

local wait_start_pos = nil
local wait_target_pos = nil
local wait_anchored = false

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
    local hrp = get_hrp()
    if hum then hum.PlatformStand = false end
    if hrp and wait_anchored then hrp.Anchored = false end
    wait_anchored = false
    wait_start_pos = nil
    wait_target_pos = nil
end

local function get_navigation_dir(start_pos, target_pos, char, door_model)
    if walk_timer > 2.5 then
        return Vector3.new(0, 1, 0)
    end
    
    local base_dir = (target_pos - start_pos).Unit
    local ray_params = RaycastParams.new()
    ray_params.FilterType = Enum.RaycastFilterType.Exclude
    ray_params.FilterDescendantsInstances = {char, door_model}
    ray_params.IgnoreWater = true
    
    local angles = {0, 20, -20, 45, -45, 70, -70, 90, -90}
    for _, angle in ipairs(angles) do
        local rotated_dir = (CFrame.Angles(0, math.rad(angle), 0) * base_dir)
        local hit = Workspace:Raycast(start_pos, rotated_dir * 20, ray_params)
        if not hit then
            return rotated_dir
        end
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
                wait_start_pos = hrp.Position
                wait_target_pos = wait_start_pos + Vector3.new(0, 300, 0)
                wait_anchored = false
            end
        end
        
        if door_state == "WAITING" then
            if any_unlocked then
                stop_waiting()
                target_door_model = closest_door
                target_door_part = closest_part
                door_state = "WALKING"
