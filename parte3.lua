-- ============================================================
-- NYXIUM HUB - ITADORI (PARTE 3)
-- ============================================================
local door_state = "SUBINDO_INICIAL"
local target_door_model, target_door_part = nil, nil
local target_prompt = nil
local door_interact_time = 0
local is_holding_e = false
local door_bp = nil
local door_target_y = nil
local wait_start = 0

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

local function remove_door_bp()
    if door_bp then door_bp:Destroy(); door_bp = nil end
end

local function create_door_bp(hrp, y)
    if door_bp then door_bp:Destroy() end
    hrp.CanCollide = true
    door_bp = Instance.new("BodyPosition")
    door_bp.MaxForce = Vector3.new(0, 1000000, 0)
    door_bp.P = 100000
    door_bp.D = 5000
    door_bp.Position = Vector3.new(hrp.Position.X, y, hrp.Position.Z)
    door_bp.Parent = hrp
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

local function start_auto_open_door()
    RunService.Heartbeat:Connect(function(dt)
        if not cfg.auto_open_door then
            if door_state ~= "SUBINDO_INICIAL" then
                door_state = "SUBINDO_INICIAL"
                if is_holding_e then
                    if target_prompt then pcall(function() target_prompt:InputHoldEnd() end) end
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); is_holding_e = false
                end
                remove_door_bp()
                reset_character()
                door_target_y = nil
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

        if door_state == "SUBINDO_INICIAL" then
            if not door_target_y then
                door_target_y = hrp.Position.Y + 300
                create_door_bp(hrp, door_target_y)
            end
            if door_bp then
                door_bp.Position = Vector3.new(hrp.Position.X, door_target_y, hrp.Position.Z)
            end
            if math.abs(hrp.Position.Y - door_target_y) < 5 then
                door_state = "PROCURANDO"
            end
            return
        end

        if door_state == "PROCURANDO" then
            if door_bp then door_bp.Position = Vector3.new(hrp.Position.X, door_target_y, hrp.Position.Z) end
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
                door_state = "VOANDO"
                door_target_y = closest_part.Position.Y + 250
            end
            return
        end

        if door_state == "VOANDO" then
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) then
                door_state = "PROCURANDO" return
            end
            if door_bp then door_bp.Position = Vector3.new(hrp.Position.X, door_target_y, hrp.Position.Z) end
            local target_xz = Vector3.new(target_door_part.Position.X, hrp.Position.Y, target_door_part.Position.Z)
            local dist_xz = (hrp.Position - target_xz).Magnitude
            if dist_xz > 5 then
                hrp.CFrame = hrp.CFrame + ((target_xz - hrp.Position).Unit * 200 * dt)
            else
                door_state = "ESPERANDO"
                wait_start = tick()
            end
            return
        end

        if door_state == "ESPERANDO" then
            if door_bp then door_bp.Position = Vector3.new(hrp.Position.X, door_target_y, hrp.Position.Z) end
            if tick() - wait_start >= 1 then
                door_state = "DESCENDO"
            end
            return
        end

        if door_state == "DESCENDO" then
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) then
                door_state = "PROCURANDO" return
            end
            remove_door_bp()
            local right_pos = target_door_part.Position + (target_door_part.CFrame.RightVector * 50)
            local target_pos = Vector3.new(right_pos.X, target_door_part.Position.Y + 2, right_pos.Z)
            local dir = target_pos - hrp.Position
            local dist = dir.Magnitude
            if dist > 3 then
                hrp.CFrame = CFrame.new(hrp.Position + (dir.Unit * 120 * dt))
            else
                door_state = "ANDANDO_PORTA"
                hum.WalkSpeed = 16
            end
            return
        end

        if door_state == "ANDANDO_PORTA" then
            if not target_door_part or not target_door_part:IsDescendantOf(Workspace) then
                door_state = "PROCURANDO" return
            end
            local target_pos = target_door_part.Position
            if target_prompt and target_prompt.Parent and target_prompt.Parent:IsA("BasePart") then
                target_pos = target_prompt.Parent.Position
            end
            local dist = (hrp.Position - target_pos).Magnitude
            if dist > 3 then
                hrp.CFrame = hrp.CFrame + ((target_pos - hrp.Position).Unit * 80 * dt)
            else
                door_state = "OPENING"
                door_interact_time = tick()
                if not is_holding_e then
                    if target_prompt then pcall(function() target_prompt:InputHoldBegin() end) end
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    is_holding_e = true
                end
            end
            return
        end

        if door_state == "OPENING" then
            if target_door_part then
                hrp.CFrame = CFrame.new(target_door_part.Position + Vector3.new(0, 2, 0))
            end
            if not target_door_model or not target_door_model:IsDescendantOf(Workspace) or (target_door_part and target_door_part.Transparency == 1) or (tick() - door_interact_time > 6) then
                if is_holding_e then
                    if target_prompt then pcall(function() target_prompt:InputHoldEnd() end) end
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); is_holding_e = false
                end
                hum.PlatformStand = false
                hum.WalkSpeed = 16
                door_state = "SUBINDO_INICIAL"
                door_target_y = nil
            end
            return
        end
    end)
end

if update_auto_block then RunService.Heartbeat:Connect(update_auto_block) end
if update_player_movement then RunService.RenderStepped:Connect(update_player_movement) end
if start_auto_farm then start_auto_farm() end
if start_auto_open_door then start_auto_open_door() end
if start_esp then start_esp() end