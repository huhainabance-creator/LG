--[[
    ULTRA FPS BOOST (Roblox)
    Максимальний буст FPS: вимикає тіні, ефекти, текстури, частинки,
    воду, траву, постобробку, ставить мінімальну якість рендеру
    і обробляє всі нові об'єкти, що з'являються в грі.

    Запуск: вставити в executor (або як LocalScript у StarterPlayerScripts).
    Налаштування нижче в таблиці CONFIG.
]]

local CONFIG = {
    FPS_CAP              = 999,   -- ліміт FPS (потрібен setfpscap в executor)
    REMOVE_TEXTURES      = true,  -- прибрати Decal/Texture/SurfaceAppearance і текстури мешів
    PLASTIC_MATERIALS    = true,  -- усі матеріали -> SmoothPlastic
    DISABLE_PARTICLES    = true,  -- частинки, сліди, промені, вогонь, дим
    DISABLE_POST_EFFECTS = true,  -- Bloom, Blur, SunRays, ColorCorrection, DOF
    REMOVE_SKY_AND_ATMO  = true,  -- Sky, Atmosphere, Clouds
    LOW_WATER_AND_GRASS  = true,  -- вода без хвиль/відбиттів, без трави
    HIDE_ACCESSORIES     = false, -- сховати аксесуари інших гравців (шапки і т.д.)
    REMOVE_CLOTHES       = false, -- прибрати одяг (Shirt/Pants) у всіх
    LOW_MESH_DETAIL      = true,  -- мінімальна деталізація мешів
    DISABLE_3D_SOUND_FX  = true,  -- вимкнути звукові ефекти (Reverb, Echo і т.д.)
    SHOW_FPS_COUNTER     = true,  -- показувати лічильник FPS
    BATCH_SIZE           = 400,   -- скільки об'єктів обробляти за кадр (менше = без фризу на старті)
}

---------------------------------------------------------------------
local Players     = game:GetService("Players")
local Lighting    = game:GetService("Lighting")
local RunService  = game:GetService("RunService")
local Workspace   = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local function try(f, ...) local ok, r = pcall(f, ...) return ok, r end

local function setHidden(obj, prop, val)
    if sethiddenproperty then
        try(sethiddenproperty, obj, prop, val)
    end
    try(function() obj[prop] = val end)
end

---------------------------------------------------------------------
-- 1. FPS cap
if setfpscap then try(setfpscap, CONFIG.FPS_CAP) end

---------------------------------------------------------------------
-- 2. Глобальні налаштування рендеру
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
try(function() settings().Network.IncomingReplicationLag = 0 end)

try(function()
    local ugs = UserSettings():GetService("UserGameSettings")
    ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    ugs.GraphicsQualityLevel = 1
end)

-- Старі матеріали (легші за 2022 PBR)
try(function()
    local ms = game:GetService("MaterialService")
    setHidden(ms, "Use2022Materials", false)
end)

---------------------------------------------------------------------
-- 3. Освітлення
local function optimizeLighting()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.FogStart = 9e9
    Lighting.ShadowSoftness = 0
    try(function() Lighting.EnvironmentDiffuseScale = 0 end)
    try(function() Lighting.EnvironmentSpecularScale = 0 end)
    setHidden(Lighting, "Technology", Enum.Technology.Compatibility)
    Lighting.Brightness = 2
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end
try(optimizeLighting)

local POST_FX = {
    BloomEffect = true, BlurEffect = true, SunRaysEffect = true,
    ColorCorrectionEffect = true, DepthOfFieldEffect = true,
}
local SKY_FX = { Sky = true, Atmosphere = true, Clouds = true }

---------------------------------------------------------------------
-- 4. Terrain (вода і трава)
if CONFIG.LOW_WATER_AND_GRASS then
    try(function()
        local t = Workspace:FindFirstChildOfClass("Terrain")
        if t then
            t.WaterWaveSize = 0
            t.WaterWaveSpeed = 0
            t.WaterReflectance = 0
            t.WaterTransparency = 0
            setHidden(t, "Decoration", false)
        end
    end)
end

---------------------------------------------------------------------
-- 5. Обробка одного об'єкта
local PARTICLE_CLASSES = {
    ParticleEmitter = true, Trail = true, Beam = true,
    Smoke = true, Fire = true, Sparkles = true,
}
local SOUND_FX = {
    ReverbSoundEffect = true, EchoSoundEffect = true, ChorusSoundEffect = true,
    DistortionSoundEffect = true, FlangeSoundEffect = true, TremoloSoundEffect = true,
    PitchShiftSoundEffect = true, EqualizerSoundEffect = true, CompressorSoundEffect = true,
}

local function isOtherCharacterPart(obj)
    local model = obj:FindFirstAncestorOfClass("Model")
    if not model then return false end
    local plr = Players:GetPlayerFromCharacter(model)
    return plr ~= nil and plr ~= LocalPlayer
end

local function optimize(obj)
    local class = obj.ClassName

    if obj:IsA("BasePart") then
        obj.CastShadow = false
        obj.Reflectance = 0
        if CONFIG.PLASTIC_MATERIALS and obj.Material ~= Enum.Material.Glass
            and obj.Material ~= Enum.Material.ForceField then
            obj.Material = Enum.Material.SmoothPlastic
        end
        if obj:IsA("MeshPart") then
            if CONFIG.REMOVE_TEXTURES then obj.TextureID = "" end
            if CONFIG.LOW_MESH_DETAIL then
                setHidden(obj, "RenderFidelity", Enum.RenderFidelity.Performance)
            end
        elseif obj:IsA("UnionOperation") and CONFIG.LOW_MESH_DETAIL then
            setHidden(obj, "RenderFidelity", Enum.RenderFidelity.Performance)
        end
        return
    end

    if CONFIG.REMOVE_TEXTURES then
        if class == "Decal" or class == "Texture" then
            obj.Transparency = 1
            return
        elseif class == "SurfaceAppearance" or class == "MaterialVariant" then
            obj:Destroy()
            return
        elseif class == "SpecialMesh" then
            obj.TextureId = ""
            return
        end
    end

    if CONFIG.DISABLE_PARTICLES then
        if PARTICLE_CLASSES[class] then
            obj.Enabled = false
            return
        elseif class == "Explosion" then
            obj.BlastPressure = 1
            obj.BlastRadius = 1
            obj.Visible = false
            return
        end
    end

    if POST_FX[class] and CONFIG.DISABLE_POST_EFFECTS then
        obj.Enabled = false
        return
    end

    if SKY_FX[class] and CONFIG.REMOVE_SKY_AND_ATMO then
        obj:Destroy()
        return
    end

    if class == "PointLight" or class == "SpotLight" or class == "SurfaceLight" then
        obj.Shadows = false
        return
    end

    if CONFIG.DISABLE_3D_SOUND_FX and SOUND_FX[class] then
        obj.Enabled = false
        return
    end

    if class == "Accessory" and CONFIG.HIDE_ACCESSORIES and isOtherCharacterPart(obj) then
        obj:Destroy()
        return
    end

    if CONFIG.REMOVE_CLOTHES and (class == "Shirt" or class == "Pants" or class == "ShirtGraphic") then
        obj:Destroy()
        return
    end
end

local function safeOptimize(obj)
    pcall(optimize, obj)
end

---------------------------------------------------------------------
-- 6. Прохід по всій грі пачками (щоб не було фризу)
local function processContainer(container)
    local list = container:GetDescendants()
    for i = 1, #list do
        safeOptimize(list[i])
        if i % CONFIG.BATCH_SIZE == 0 then
            RunService.Heartbeat:Wait()
        end
    end
end

for _, obj in ipairs(Lighting:GetChildren()) do safeOptimize(obj) end
task.spawn(processContainer, Workspace)
task.spawn(function()
    local cam = Workspace.CurrentCamera
    if cam then processContainer(cam) end
end)

-- Нові об'єкти (підвантаження карти, ефекти зброї, нові гравці)
Workspace.DescendantAdded:Connect(function(obj)
    task.defer(safeOptimize, obj)
end)
Lighting.DescendantAdded:Connect(function(obj)
    task.defer(safeOptimize, obj)
end)

-- Деякі ігри повертають тіні/туман скриптами — повертаємо назад
Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
    if Lighting.GlobalShadows then Lighting.GlobalShadows = false end
end)
Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
    if Lighting.FogEnd < 9e9 then Lighting.FogEnd = 9e9 end
end)

---------------------------------------------------------------------
-- 7. Очистка пам'яті
task.spawn(function()
    while task.wait(60) do
        try(function() collectgarbage("collect") end)
    end
end)

---------------------------------------------------------------------
-- 8. Лічильник FPS
if CONFIG.SHOW_FPS_COUNTER then
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
    RunService.RenderStepped:Connect(function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then
            label.Text = ("FPS: %d"):format(math.floor(frames / (now - last) + 0.5))
            frames, last = 0, now
        end
    end)
end

print("[UltraFPSBoost] Активовано")
