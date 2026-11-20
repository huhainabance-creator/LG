--[[
    ULTRA FPS BOOST v3 (Roblox)
    Тіні, світло, ефекти, текстури, частинки, вода, трава, небо, постобробка,
    Highlight, світові GUI, декор карти, ВСІ звуки і ВСІ анімації — вимкнено.
    + Дальність прорисовки: все, що далі RENDER_DISTANCE, не малюється.

    Клавіші:
      RightControl — вимкнути/увімкнути 3D-рендер повністю (для AFK)
    Коли вікно Roblox згорнуте — 3D вимикається сам, FPS знижується.
]]

local CONFIG = {
    FPS_CAP              = 999,   -- ліміт FPS (потрібен setfpscap в executor)
    UNFOCUSED_FPS        = 15,    -- FPS коли вікно не в фокусі
    PAUSE_3D_UNFOCUSED   = true,
    TOGGLE_3D_KEY        = Enum.KeyCode.RightControl,

    -- Дальність прорисовки
    RENDER_DISTANCE      = 250,   -- у студах; nil = вимкнути цю функцію
    CULL_INTERVAL        = 0.4,   -- як часто оновлювати (сек)

    -- Декор карти
    DELETE_DECOR         = true,  -- видаляти дерева/кущі/траву/квіти/каміння і дрібний декор
    DECOR_KEYWORDS       = {      -- назви (маленькими літерами), які вважаються декором
        "tree", "bush", "leaf", "leaves", "grass", "flower", "plant", "foliage",
        "shrub", "fern", "vine", "mushroom", "pebble", "decor", "rock", "stone",
    },
    DECOR_MAX_SIZE       = 25,    -- декор, у який можна впертися, видаляється тільки якщо менший за це
    SMALL_DECOR_SIZE     = 4,     -- дрібні непрохідні деталі (болти, гілочки) менші за це видаляються

    DELETE_TEXTURES      = true,
    PLASTIC_MATERIALS    = true,
    DELETE_PARTICLES     = true,
    DISABLE_LIGHTS       = true,
    DISABLE_HIGHLIGHTS   = true,
    DISABLE_WORLD_GUIS   = true,  -- таблички/написи на карті
    DISABLE_SOUNDS       = true,  -- ВСІ звуки
    DISABLE_ANIMATIONS   = true,  -- ВСІ анімації (гравці, NPC, моби, предмети)
    LOW_MESH_DETAIL      = true,
    FIELD_OF_VIEW        = nil,   -- напр. 60; nil = не чіпати
    BATCH_SIZE           = 500,
}

---------------------------------------------------------------------
local Players          = game:GetService("Players")
local Lighting         = game:GetService("Lighting")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer

local function try(f, ...) return pcall(f, ...) end

local function setHidden(obj, prop, val)
    if sethiddenproperty then try(sethiddenproperty, obj, prop, val) end
    try(function() obj[prop] = val end)
end

local function setCap(n)
    if setfpscap then try(setfpscap, n) end
end

---------------------------------------------------------------------
-- 1. FPS cap
setCap(CONFIG.FPS_CAP)

---------------------------------------------------------------------
-- 2. Рендер / фізика
try(function()
    local r = settings().Rendering
    r.QualityLevel = Enum.QualityLevel.Level01
    if CONFIG.LOW_MESH_DETAIL then
        r.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
    end
    r.EagerBulkExecution = false
end)
try(function() settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.DefaultAuto end)
try(function() settings().Physics.AllowSleep = true end)
try(function()
    local ugs = UserSettings():GetService("UserGameSettings")
    ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    ugs.GraphicsQualityLevel = 1
    if CONFIG.DISABLE_SOUNDS then ugs.MasterVolume = 0 end
end)
try(function() setHidden(game:GetService("MaterialService"), "Use2022Materials", false) end)
try(function() setHidden(Workspace, "InterpolationThrottling", Enum.InterpolationThrottlingMode.Enabled) end)
try(function() setHidden(Workspace, "LevelOfDetail", Enum.ModelLevelOfDetail.Automatic) end)
if CONFIG.DISABLE_SOUNDS then
    try(function() game:GetService("SoundService").AmbientReverb = Enum.ReverbType.NoReverb end)
end

---------------------------------------------------------------------
-- 3. Освітлення (без тіней)
local function optimizeLighting()
    Lighting.GlobalShadows = false
    Lighting.FogStart = 9e9
    Lighting.FogEnd = 9e9
    Lighting.ShadowSoftness = 0
    Lighting.Brightness = 2
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    Lighting.Ambient = Color3.fromRGB(100, 100, 100)
    try(function() Lighting.EnvironmentDiffuseScale = 0 end)
    try(function() Lighting.EnvironmentSpecularScale = 0 end)
    setHidden(Lighting, "Technology", Enum.Technology.Compatibility)
end
try(optimizeLighting)

Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
    if Lighting.GlobalShadows then Lighting.GlobalShadows = false end
end)
Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
    if Lighting.FogEnd < 9e9 then Lighting.FogEnd = 9e9 end
end)
Lighting:GetPropertyChangedSignal("Technology"):Connect(function()
    setHidden(Lighting, "Technology", Enum.Technology.Compatibility)
end)

---------------------------------------------------------------------
-- 4. Terrain
try(function()
    local t = Workspace:FindFirstChildOfClass("Terrain")
    if t then
        t.WaterWaveSize = 0
        t.WaterWaveSpeed = 0
        t.WaterReflectance = 0
        t.WaterTransparency = 0
        setHidden(t, "Decoration", false)
        t.CastShadow = false
    end
end)

---------------------------------------------------------------------
-- 5. Класи
local DELETE_ALWAYS = {
    BloomEffect = true, BlurEffect = true, SunRaysEffect = true,
    ColorCorrectionEffect = true, DepthOfFieldEffect = true,
    Sky = true, Atmosphere = true, Clouds = true,
}
local PARTICLES = {
    ParticleEmitter = true, Trail = true, Beam = true,
    Smoke = true, Fire = true, Sparkles = true,
}
local TEXTURES = {
    Decal = true, Texture = true, SurfaceAppearance = true, MaterialVariant = true,
}
local LIGHTS = { PointLight = true, SpotLight = true, SurfaceLight = true }
local SOUND_FX = {
    ReverbSoundEffect = true, EchoSoundEffect = true, ChorusSoundEffect = true,
    DistortionSoundEffect = true, FlangeSoundEffect = true, TremoloSoundEffect = true,
    PitchShiftSoundEffect = true, EqualizerSoundEffect = true, CompressorSoundEffect = true,
}
local KEEP_MATERIAL = {
    [Enum.Material.Glass] = true, [Enum.Material.ForceField] = true,
    [Enum.Material.Neon] = true,
}

---------------------------------------------------------------------
-- 6. Допоміжне: персонажі, інструменти, декор
local function isInCharacterOrTool(obj)
    if obj:FindFirstAncestorWhichIsA("Tool") or obj:FindFirstAncestorWhichIsA("Accessory") then
        return true
    end
    local model = obj:FindFirstAncestorWhichIsA("Model")
    while model do
        if model:FindFirstChildOfClass("Humanoid") then return true end
        model = model:FindFirstAncestorWhichIsA("Model")
    end
    return false
end

local function isOwnCharacter(obj)
    local char = LocalPlayer.Character
    return char ~= nil and obj:IsDescendantOf(char)
end

local function nameIsDecor(name)
    name = string.lower(name)
    if string.find(name, "rocket", 1, true) then return false end
    for _, kw in ipairs(CONFIG.DECOR_KEYWORDS) do
        if string.find(name, kw, 1, true) then return true end
    end
    return false
end

local function isInteractive(part)
    return part:FindFirstChildOfClass("TouchTransmitter")
        or part:FindFirstChildWhichIsA("ProximityPrompt")
        or part:FindFirstChildOfClass("ClickDetector")
        or (part.Parent and part.Parent:FindFirstChildWhichIsA("ProximityPrompt"))
end

local function isDecor(part)
    if part.Transparency >= 1 or isInteractive(part) or isInCharacterOrTool(part) then
        return false
    end
    local s = part.Size
    local maxSize = math.max(s.X, s.Y, s.Z)

    local named = nameIsDecor(part.Name)
        or (part.Parent and part.Parent ~= Workspace and nameIsDecor(part.Parent.Name))
    if named then
        -- не видаляємо великі тверді деталі (щоб не провалитися крізь підлогу "Grass")
        return (not part.CanCollide) or maxSize <= CONFIG.DECOR_MAX_SIZE
    end

    -- дрібний декор, крізь який і так проходиш
    return part.Anchored and not part.CanCollide and maxSize <= CONFIG.SMALL_DECOR_SIZE
end

---------------------------------------------------------------------
-- 7. Звуки та анімації
local handled = setmetatable({}, { __mode = "k" })

local function killSound(s)
    if handled[s] then return end
    handled[s] = true
    s.Volume = 0
    s:Stop()
    s:GetPropertyChangedSignal("Playing"):Connect(function()
        if s.Playing then s:Stop() end
    end)
    s:GetPropertyChangedSignal("Volume"):Connect(function()
        if s.Volume ~= 0 then s.Volume = 0 end
    end)
end

local function killAnimator(a)
    if handled[a] then return end
    handled[a] = true
    for _, track in ipairs(a:GetPlayingAnimationTracks()) do
        track:Stop(0)
    end
    a.AnimationPlayed:Connect(function(track) track:Stop(0) end)
end

---------------------------------------------------------------------
-- 8. Дальність прорисовки (реєстр деталей)
local cullParts = setmetatable({}, { __mode = "k" })
local culled    = setmetatable({}, { __mode = "k" })

local function registerCull(part)
    if not CONFIG.RENDER_DISTANCE then return end
    if part.Transparency >= 1 or isOwnCharacter(part) then return end
    cullParts[part] = true
end

---------------------------------------------------------------------
-- 9. Обробка одного об'єкта
local function optimize(obj)
    local class = obj.ClassName

    if CONFIG.DISABLE_SOUNDS and class == "Sound" then killSound(obj) return end
    if CONFIG.DISABLE_ANIMATIONS and class == "Animator" then killAnimator(obj) return end

    if obj:IsA("BasePart") then
        if obj:IsA("Terrain") then return end
        if CONFIG.DELETE_DECOR and isDecor(obj) then obj:Destroy() return end

        obj.CastShadow = false
        obj.Reflectance = 0
        if CONFIG.PLASTIC_MATERIALS and not KEEP_MATERIAL[obj.Material] then
            obj.Material = Enum.Material.SmoothPlastic
        end
        if obj:IsA("MeshPart") then
            if CONFIG.DELETE_TEXTURES then obj.TextureID = "" end
            if CONFIG.LOW_MESH_DETAIL then
                setHidden(obj, "RenderFidelity", Enum.RenderFidelity.Performance)
            end
        elseif obj:IsA("PartOperation") and CONFIG.LOW_MESH_DETAIL then
            setHidden(obj, "RenderFidelity", Enum.RenderFidelity.Performance)
        end
        registerCull(obj)
        return
    end

    if DELETE_ALWAYS[class] then obj:Destroy() return end

    if CONFIG.DELETE_TEXTURES then
        if TEXTURES[class] then obj:Destroy() return end
        if class == "SpecialMesh" then obj.TextureId = "" return end
    end

    if CONFIG.DELETE_PARTICLES then
        if PARTICLES[class] then obj:Destroy() return end
        if class == "Explosion" then obj.Visible = false return end
    end

    if CONFIG.DISABLE_LIGHTS and LIGHTS[class] then obj.Enabled = false return end
    if CONFIG.DISABLE_HIGHLIGHTS and class == "Highlight" then obj.Enabled = false return end
    if SOUND_FX[class] then obj.Enabled = false return end

    if CONFIG.DISABLE_WORLD_GUIS and (class == "SurfaceGui" or class == "BillboardGui") then
        obj.Enabled = false
        return
    end
end

local function safeOptimize(obj) pcall(optimize, obj) end

---------------------------------------------------------------------
-- 10. Прохід по грі пачками + нові об'єкти
local function processList(list)
    for i = 1, #list do
        safeOptimize(list[i])
        if i % CONFIG.BATCH_SIZE == 0 then RunService.Heartbeat:Wait() end
    end
end

local function hook(container)
    task.spawn(function() processList(container:GetDescendants()) end)
    container.DescendantAdded:Connect(function(obj) task.defer(safeOptimize, obj) end)
end

hook(Workspace)
hook(Lighting)

-- Звуки можуть бути будь-де (SoundService, PlayerGui, ReplicatedStorage...)
if CONFIG.DISABLE_SOUNDS then
    task.spawn(function()
        local ok, all = try(function() return game:GetDescendants() end)
        if ok then
            for i, obj in ipairs(all) do
                if obj:IsA("Sound") then pcall(killSound, obj) end
                if i % 2000 == 0 then RunService.Heartbeat:Wait() end
            end
        end
    end)
    game.DescendantAdded:Connect(function(obj)
        if obj:IsA("Sound") then task.defer(pcall, killSound, obj) end
    end)
end

---------------------------------------------------------------------
-- 11. Цикл дальності прорисовки
if CONFIG.RENDER_DISTANCE then
    task.spawn(function()
        local dist = CONFIG.RENDER_DISTANCE
        while true do
            local cam = Workspace.CurrentCamera
            if cam then
                local list, n = {}, 0
                for p in pairs(cullParts) do n += 1; list[n] = p end

                local pos = cam.CFrame.Position
                for i = 1, n do
                    local p = list[i]
                    if p.Parent then
                        local s = p.Size
                        local radius = math.max(s.X, s.Y, s.Z) * 0.5
                        local far = (p.Position - pos).Magnitude - radius > dist
                        if far ~= (culled[p] == true) then
                            culled[p] = far or nil
                            p.LocalTransparencyModifier = far and 1 or 0
                        end
                    else
                        cullParts[p] = nil
                        culled[p] = nil
                    end
                    if i % 3000 == 0 then
                        RunService.Heartbeat:Wait()
                        pos = cam.CFrame.Position
                    end
                end
            end
            task.wait(CONFIG.CULL_INTERVAL)
        end
    end)
end

---------------------------------------------------------------------
-- 12. Камера
if CONFIG.FIELD_OF_VIEW then
    local function applyFov()
        local cam = Workspace.CurrentCamera
        if cam then cam.FieldOfView = CONFIG.FIELD_OF_VIEW end
    end
    applyFov()
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyFov)
end

---------------------------------------------------------------------
-- 13. Вимкнення 3D (клавіша + коли вікно не в фокусі)
local manual3DOff = false
local function set3D(on) try(function() RunService:Set3dRenderingEnabled(on) end) end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CONFIG.TOGGLE_3D_KEY then
        manual3DOff = not manual3DOff
        set3D(not manual3DOff)
    end
end)

if CONFIG.PAUSE_3D_UNFOCUSED then
    UserInputService.WindowFocusReleased:Connect(function()
        set3D(false)
        setCap(CONFIG.UNFOCUSED_FPS)
    end)
    UserInputService.WindowFocused:Connect(function()
        set3D(not manual3DOff)
        setCap(CONFIG.FPS_CAP)
    end)
end

---------------------------------------------------------------------
-- 14. Лічильник FPS
do
    local gui = Instance.new("ScreenGui")
    gui.Name = "UltraFPSCounter"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    local ok = try(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromOffset(110, 24)
    label.Position = UDim2.fromOffset(6, 6)
    label.BackgroundColor3 = Color3.new(0, 0, 0)
    label.BackgroundTransparency = 0.4
    label.TextColor3 = Color3.fromRGB(0, 255, 120)
    label.Font = Enum.Font.Code
    label.TextSize = 16
    label.Text = "FPS: ..."
    label.Parent = gui

    local frames, last = 0, os.clock()
    RunService.Heartbeat:Connect(function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then
            label.Text = ("FPS: %d"):format(math.floor(frames / (now - last) + 0.5))
            frames, last = 0, now
        end
    end)
end

print("[UltraFPSBoost v3] Активовано")
