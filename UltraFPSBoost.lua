--[[
    ULTRA FPS BOOST v2 (Roblox)
    Максимальний буст FPS: тіні, світло, ефекти, текстури, частинки,
    вода, трава, небо, постобробка, Highlight, світові GUI — все вимкнено.
    Нові об'єкти обробляються автоматично.

    Клавіші:
      RightControl — вимкнути/увімкнути 3D-рендер повністю (для AFK, FPS у стелю)
    Коли вікно Roblox згорнуте — 3D вимикається сам, FPS знижується (менше навантаження на ПК).
]]

local CONFIG = {
    FPS_CAP              = 999,   -- ліміт FPS (потрібен setfpscap в executor)
    UNFOCUSED_FPS        = 15,    -- FPS коли вікно згорнуте / не в фокусі
    PAUSE_3D_UNFOCUSED   = true,  -- вимикати 3D-рендер, коли вікно не в фокусі
    TOGGLE_3D_KEY        = Enum.KeyCode.RightControl,
    DELETE_TEXTURES      = true,  -- видалити Decal/Texture/SurfaceAppearance, текстури мешів
    PLASTIC_MATERIALS    = true,  -- усі матеріали -> SmoothPlastic
    DELETE_PARTICLES     = true,  -- видалити частинки, сліди, промені, вогонь, дим
    DISABLE_LIGHTS       = true,  -- вимкнути всі джерела світла (PointLight/SpotLight/SurfaceLight)
    DISABLE_HIGHLIGHTS   = true,  -- вимкнути Highlight (дуже важкий ефект)
    DISABLE_WORLD_GUIS   = true,  -- вимкнути SurfaceGui/BillboardGui на карті (таблички, написи)
    DISABLE_VIEWPORTS    = false, -- сховати ViewportFrame в інтерфейсі (може сховати прев'ю в магазині)
    LOW_MESH_DETAIL      = true,  -- мінімальна деталізація мешів
    FIELD_OF_VIEW        = nil,   -- напр. 60 (менше FOV = менше об'єктів у кадрі), nil = не чіпати
    BATCH_SIZE           = 500,   -- скільки об'єктів обробляти за кадр
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
-- 2. Глобальні налаштування рендеру / фізики
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
end)
try(function() setHidden(game:GetService("MaterialService"), "Use2022Materials", false) end)
try(function() setHidden(Workspace, "InterpolationThrottling", Enum.InterpolationThrottlingMode.Enabled) end)
try(function() setHidden(Workspace, "LevelOfDetail", Enum.ModelLevelOfDetail.Automatic) end)

---------------------------------------------------------------------
-- 3. Освітлення
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

local function optimize(obj)
    local class = obj.ClassName

    if obj:IsA("BasePart") then
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
    if CONFIG.DISABLE_VIEWPORTS and class == "ViewportFrame" then
        obj.Visible = false
        return
    end
end

local function safeOptimize(obj) pcall(optimize, obj) end

---------------------------------------------------------------------
-- 6. Прохід по грі пачками + нові об'єкти
local function processContainer(container)
    local list = container:GetDescendants()
    for i = 1, #list do
        safeOptimize(list[i])
        if i % CONFIG.BATCH_SIZE == 0 then RunService.Heartbeat:Wait() end
    end
end

local function hook(container)
    task.spawn(processContainer, container)
    container.DescendantAdded:Connect(function(obj) task.defer(safeOptimize, obj) end)
end

hook(Workspace)
hook(Lighting)
if CONFIG.DISABLE_VIEWPORTS then
    task.spawn(function() hook(LocalPlayer:WaitForChild("PlayerGui")) end)
end

---------------------------------------------------------------------
-- 7. Камера
if CONFIG.FIELD_OF_VIEW then
    local function applyFov()
        local cam = Workspace.CurrentCamera
        if cam then cam.FieldOfView = CONFIG.FIELD_OF_VIEW end
    end
    applyFov()
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyFov)
end

---------------------------------------------------------------------
-- 8. Вимкнення 3D (клавіша + коли вікно не в фокусі)
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
-- 9. Лічильник FPS
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

print("[UltraFPSBoost v2] Активовано")
