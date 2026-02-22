













































































































































getgenv().amethyst = {
    ['Aimbot'] = {
        ['Enabled']       = true,
        ['FOV']           = 120,
        ['PreciseMouse']  = false,
        ['Easing']        = 'Circular',
        ['Smoothness']    = 0.05,
    },
    ['Triggerbot'] = {
        ['Enabled']       = true,
        ['RequireTool']   = true,
        ['HoldTime']      = 0,
        ['Cooldown']      = 0
    },
    ['Checks'] = {
        ['IgnoreDead']      = true,
        ['CheckTeam']       = true,
        ['CheckForceField'] = true,
    }
}

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UIS                = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Camera             = workspace.CurrentCamera
local LocalPlayer        = Players.LocalPlayer

local RayParams = RaycastParams.new()
RayParams.FilterType  = Enum.RaycastFilterType.Blacklist
RayParams.IgnoreWater = true

local connections = {}

local triggerbotState = {
    CanFire      = true,
    LastFireTime = 0,
    IsHolding    = false,
    HoldTask     = nil
}

local GameProductInfo = MarketplaceService:GetProductInfo(game.PlaceId)
local GameInformation = {}
setmetatable(GameInformation, {
    __index = function(_, Key)
        Key = tostring(Key):lower()
        if Key == "name" then
            return GameProductInfo.Name
        elseif Key == "id" or Key == "identification" then
            return game.PlaceId
        elseif Key == "description" or Key == "desc" then
            return GameProductInfo.Description
        elseif Key == "created" then
            return GameProductInfo.Created
        elseif Key == "lastupdatedate" or Key == "lastupdated" then
            return GameProductInfo.Updated
        elseif Key == "isnew" then
            return GameProductInfo.IsNew
        elseif Key == "creator" then
            local Creator = {}
            setmetatable(Creator, {
                __index = function(_, Key)
                    Key = tostring(Key):lower()
                    if Key == "name" then
                        return GameProductInfo.Creator.Name
                    elseif Key == "id" or Key == "identification" then
                        return GameProductInfo.Creator.Id
                    elseif Key == "type" then
                        return GameProductInfo.Creator.CreatorType
                    elseif Key == "isverified" or Key == "hasverifiedbadge" then
                        return GameProductInfo.Creator.HasVerifiedBadge
                    end
                end
            })
            table.freeze(Creator)
            return Creator
        end
    end
})
table.freeze(GameInformation)

local isHoodCustoms = GameInformation.name:lower():find("hood customs") ~= nil

local function IsKnocked(player)
    if not player or not player.Character then return false end
    local be = player.Character:FindFirstChild("BodyEffects")
    if not be then return false end
    local ko = be:FindFirstChild("K.O")
    return ko and ko.Value or false
end

local function IsGrabbed(player)
    if not player or not player.Character then return false end
    return player.Character:FindFirstChild("GRABBING_CONSTRAINT") ~= nil
end

local function HasForcefield(player)
    if not player or not player.Character then return false end
    return player.Character:FindFirstChild("Forcefield") ~= nil
end

local function getEasedDelta(delta, easingStyle)
    local alpha = TweenService:GetValue(1, Enum.EasingStyle[easingStyle], Enum.EasingDirection.Out)
    return delta * alpha
end

local function isPlayerValid(player)
    if not player or not player.Character then return false end

    if isHoodCustoms then
        if IsKnocked(player) then return false end
        if IsGrabbed(player) then return false end
        if HasForcefield(player) then return false end
        if IsKnocked(LocalPlayer) then return false end
    else
        if amethyst['Checks']['IgnoreDead'] then
            local humanoid = player.Character:FindFirstChildWhichIsA("Humanoid")
            if not humanoid then return false end

            if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
                return false
            end
        end

        if amethyst['Checks']['CheckTeam'] and game.PlaceId ~= 85788627530413 then
            local gameName = GameInformation.name:lower()

            if gameName:find("bronx") and gameName:find("duels") then
                if player.Character:FindFirstChildOfClass("Highlight") then
                    local localChar = LocalPlayer.Character
                    if localChar and localChar:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (player.Character.HumanoidRootPart.Position - localChar.HumanoidRootPart.Position).Magnitude
                        if dist <= 75 then
                            return false
                        end
                    else
                        return false
                    end
                end
            else
                if LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
                    return false
                end

                if LocalPlayer.TeamColor and player.TeamColor and LocalPlayer.TeamColor == player.TeamColor then
                    return false
                end
            end
        end

        if amethyst['Checks']['CheckForceField'] and player.Character then
            if player.Character:FindFirstChildOfClass("ForceField") then
                return false
            end
        end
    end

    return true
end

local function getClosestVisiblePlayer()
    local mousePos     = UIS:GetMouseLocation()
    local closestPlayer        = nil
    local closestHeadScreenPos = nil
    local closestDistance      = math.huge

    RayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isPlayerValid(player) then
            local character = player.Character
            if not character then continue end

            local head = character:FindFirstChild("Head")
            if not head then continue end

            if isHoodCustoms and head.Transparency >= 0.5 then continue end

            local headScreen, headOnScreen = Camera:WorldToViewportPoint(head.Position)
            if headOnScreen then
                local dist = (Vector2.new(headScreen.X, headScreen.Y) - mousePos).Magnitude

                if dist <= amethyst['Aimbot']['FOV'] and dist < closestDistance then
                    local origin    = Camera.CFrame.Position
                    local direction = (head.Position - origin).Unit * 1000
                    local result    = workspace:Raycast(origin, direction, RayParams)

                    if result and result.Instance and result.Instance:IsDescendantOf(character) then
                        closestDistance      = dist
                        closestPlayer        = player
                        closestHeadScreenPos = Vector2.new(headScreen.X, headScreen.Y)
                    end
                end
            end
        end
    end

    return closestPlayer, closestHeadScreenPos
end

local function getTargetFromCenter()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local unitRay      = Camera:ViewportPointToRay(screenCenter.X, screenCenter.Y)

    RayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, RayParams)

    if result and result.Instance then
        local hitPart  = result.Instance
        local character = hitPart:FindFirstAncestorOfClass("Model")
        if character then
            local player = Players:GetPlayerFromCharacter(character)
            if player and player ~= LocalPlayer and isPlayerValid(player) then
                return player
            end
        end
    end

    return nil
end

local function hasToolEquipped()
    if not amethyst['Triggerbot']['RequireTool'] then return true end

    local character = LocalPlayer.Character
    if not character then return false end

    return character:FindFirstChildOfClass("Tool") ~= nil
end

local function hasKnifeEquipped()
    local character = LocalPlayer.Character
    if not character then return false end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return false end

    return tool.Name:lower():find("knife") ~= nil
end

local function triggerbotFire()
    if not triggerbotState.CanFire then return end
    if not hasToolEquipped() then return end

    if isHoodCustoms and hasKnifeEquipped() then return end

    if game.PlaceId == 85788627530413 and amethyst['Checks']['CheckForceField'] then
        local localChar = LocalPlayer.Character
        if localChar and localChar:FindFirstChildOfClass("ForceField") then return end
    end

    local now = tick()
    if now - triggerbotState.LastFireTime < amethyst['Triggerbot']['Cooldown'] then return end

    local target = getTargetFromCenter()
    if not target then return end

    triggerbotState.CanFire      = false
    triggerbotState.LastFireTime = now

    mouse1press()
    triggerbotState.IsHolding = true

    if triggerbotState.HoldTask then
        triggerbotState.HoldTask:Cancel()
    end

    triggerbotState.HoldTask = task.delay(amethyst['Triggerbot']['HoldTime'], function()
        if triggerbotState.IsHolding then
            mouse1release()
            triggerbotState.IsHolding = false
            triggerbotState.HoldTask  = nil
            triggerbotState.CanFire   = true
        end
    end)
end

local function aimbotUpdate()
    local player, screenPos = getClosestVisiblePlayer()
    if not player or not screenPos then return end

    local mousePos  = UIS:GetMouseLocation()
    local rawDelta  = screenPos - mousePos
    local easedDelta = getEasedDelta(rawDelta, amethyst['Aimbot']['Easing'])

    if amethyst['Aimbot']['PreciseMouse'] then
        local newX = mousePos.X + (rawDelta.X * amethyst['Aimbot']['Smoothness']) + easedDelta.X
        local newY = mousePos.Y + (rawDelta.Y * amethyst['Aimbot']['Smoothness']) + easedDelta.Y
        mousemoveabs(newX, newY)
    else
        local delta = (rawDelta * amethyst['Aimbot']['Smoothness']) + (easedDelta * 0.1)
        mousemoverel(delta.X, delta.Y)
    end
end

local function onRenderStep()
    if amethyst['Aimbot']['Enabled'] then
        aimbotUpdate()
    end

    if amethyst['Triggerbot']['Enabled'] then
        triggerbotFire()
    end
end
RunService:BindToRenderStep("AmethystAimbot", Enum.RenderPriority.Camera.Value - 1, onRenderStep)

table.insert(connections, {
    Disconnect = function()
        RunService:UnbindFromRenderStep("AmethystAimbot")
    end
})

local function selfDestruct()
    if triggerbotState.HoldTask then
        triggerbotState.HoldTask:Cancel()
        if triggerbotState.IsHolding then
            mouse1release()
        end
    end

    for _, conn in pairs(connections) do
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end
end

local inputConn = UIS.InputBegan:Connect(function(key, processed)
    if processed then return end
    if key.KeyCode == Enum.KeyCode.End then
        selfDestruct()
    end
end)
table.insert(connections, inputConn)
