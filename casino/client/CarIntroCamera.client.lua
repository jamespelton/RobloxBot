-- CAR ARRIVAL INTRO CAMERA (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Written by James. One change, marked [REX]: a safety release. The camera and
-- controls are handed over on "drive" and only given back on "done", so if the
-- server errors or the sequence is interrupted the player is left with no
-- controls and a frozen camera, with no way out but rejoining.
-- Paired with CarIntroServer, which drives the phases.

local SAFETY_SECONDS = 20 -- [REX] hand control back regardless after this long

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local event = ReplicatedStorage:WaitForChild("CarIntroEvent")
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local shot = nil
local carModel, arrival
local shotStart = 0
local sequenceStart = 0

local function carPosition()
    if carModel and carModel.PrimaryPart then
        return carModel.PrimaryPart.Position
    end
    return arrival.Position
end

-- [REX] pulled out of the "done" branch so the safety timeout can use it too
local function restore()
    shot = nil
    controls:Enable()
    camera.CameraType = Enum.CameraType.Custom
    local character = player.Character
    if character then
        camera.CameraSubject = character:FindFirstChildOfClass("Humanoid")
    end
end

RunService:BindToRenderStep("CarIntroCamera", Enum.RenderPriority.Camera.Value + 1, function()
    if not shot then
        return
    end

    -- [REX] never strand the player behind a stuck cutscene
    if os.clock() - sequenceStart > SAFETY_SECONDS then
        warn("[CarIntro] no 'done' from the server, releasing the camera")
        restore()
        return
    end

    local t = os.clock() - shotStart
    if shot == "drive" then
        -- Low shot from the front corner, following the car as it pulls up
        local camPos = (arrival * CFrame.new(-16, 4, -12)).Position
        camera.CFrame = CFrame.lookAt(camPos, carPosition() + Vector3.new(0, 2.5, 0))
    elseif shot == "exit" then
        -- Slowly push in on the driver's door
        local a = math.min(t / 4, 1)
        local camPos = (arrival * CFrame.new(-13 + 3 * a, 5.5 - a, -7 + 2 * a)).Position
        local focus = (arrival * CFrame.new(-4.5, 3.5, -0.6)).Position
        camera.CFrame = CFrame.lookAt(camPos, focus)
    end
end)

event.OnClientEvent:Connect(function(phase, model, arrivalCF)
    if phase == "drive" or phase == "exit" then
        carModel = model
        arrival = arrivalCF
        if not shot then
            sequenceStart = os.clock() -- [REX] clock the whole sequence, not each shot
        end
        shot = phase
        shotStart = os.clock()
        controls:Disable()
        camera.CameraType = Enum.CameraType.Scriptable
    elseif phase == "done" then
        restore()
    end
end)

-- Tell the server we're ready once the loading screen is gone
local playerGui = player:WaitForChild("PlayerGui")
task.wait(1)
while playerGui:FindFirstChild("LoadingScreen") do
    task.wait(0.2)
end
event:FireServer("ready")
