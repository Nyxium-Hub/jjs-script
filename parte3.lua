-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 3)
-- ============================================================
local door_state = "IDLE"
local target_door_model, target_door_part = nil, nil
local target_prompt = nil
local door_interact_time = 0
local last_health = 100
local door_speed = 60
local door_attempts = 0
local door_walk_timer = 0

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

local function reset_character()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.Anchored = false; hrp.CanCollide = true end
    if hum then
        hum.PlatformStand = false
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = true end
    end
end

local function instant_interact(prompt)
    if not prompt then return false end
    if fireproximityprompt then
        local ok = pcall(function() fireproximityprompt(prompt) end)
        if ok then return true end
    end
    local ok2 = pcall(function()
        prompt.HoldDuration = 0.001
        prompt.MaxActivationDistance = 100
        prompt:InputHoldBegin()
        task.wait(0.05)
        prompt:InputHoldEnd()
    end)
    if ok2 then return true end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    return false
end

local function smart_nav(start_pos, target_pos, char, door_model)
    door_walk_timer = door_walk_timer + 0.016
    if door_walk_timer > 2.5 then return Vector3.new(0, 1, 0) end
    local base_dir = (target_pos - start_pos).Unit
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, door_model}
    params.IgnoreWater = true
    local angles = {0, 15, -15, 30, -30, 45, -45, 60, -60}
    for _, ang in ipairs(angles) do
        local rot = CFrame.Angles(0, math.rad(ang), 0) * base_dir
        local hit = Workspace:Raycast(start_pos, rot * 12, params)
        if not hit then return rot end
    end
    return base_dir
end

local function start_auto_open_door()
    RunService.Heartbeat:Connect(function(dt)
        if not cfg.auto_open_door then
            if door_state ~= "IDLE" then
                door_state = "IDLE"
                reset_character()
                target_prompt = nil
                door_attempts = 0
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

        if hum.Health < last_health and door_state == "OPENING" then
            last_health = hum.Health
            door_state = "WALKING"
            door_attempts = 0
            return
        end
        last_health = hum.Health

        if door_state == "IDLE" then
            local closest_door, min_dist = nil, math.huge
            local closest_part = nil
            for _, door in ipairs(cached_doors) do
                if door and door:IsDescendantOf(Workspace) then
                    if not check_if_locked(door) then
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
            if closest_door and closest_part then
                target_door_model = closest_door
                target_door_part = closest_part
                door_state = "WALKING"
                door_attempts = 0
                door_walk_timer = 0
            end
            return
        end

        if door_state == "WALKING" then
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) or check_if_locked(target_door_model) then
                door_state = "IDLE" return
            end
            local target_pos = target_door_part.Position
            if target_prompt and target_prompt.Parent and target_prompt.Parent:IsA("BasePart") then
                target_pos = target_prompt.Parent.Position
            end
            local dist = (hrp.Position - target_pos).Magnitude
            if dist > 4 then
                local move_dir = smart_nav(hrp.Position, target_pos, char, target_door_model)
                hrp.CFrame = hrp.CFrame + (move_dir * door_speed * dt)
            else
                door_state = "OPENING"
                door_interact_time = tick()
            end
            return
        end

        if door_state == "OPENING" then
            if not target_door_model or not target_door_model:IsDescendantOf(Workspace) or (target_door_part and target_door_part.Transparency == 1) then
                reset_character()
                door_state = "IDLE"
                target_prompt = nil
                door_attempts = 0
                return
            end
            if tick() - door_interact_time > 0.5 then
                door_interact_time = tick()
                door_attempts = door_attempts + 1
                instant_interact(target_prompt)
                if door_attempts > 10 then
                    door_state = "IDLE"
                    target_prompt = nil
                    door_attempts = 0
                end
            end
            return
        end
    end)
end

function set_door_speed(v) door_speed = v end

if update_auto_block then RunService.Heartbeat:Connect(update_auto_block) end
if update_player_movement then RunService.RenderStepped:Connect(update_player_movement) end
if start_auto_farm then start_auto_farm() end
if start_auto_open_door then start_auto_open_door() end
if start_esp then start_esp() end