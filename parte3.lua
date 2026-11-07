-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 3)
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