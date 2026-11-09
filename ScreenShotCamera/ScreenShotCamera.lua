local addonName = ...

local ADDON_TITLE = "ScreenShot Camera"
local DB_GLOBAL = "ScreenShotCameraDB"

-- Forever is Camelot, not Classic and not WOW_PROJECT_MAINLINE.
-- Pin the executable build as well as the TOC interface, even if the user
-- enables "Load out of date AddOns" on another client.
local version, build, _, interface = GetBuildInfo()
if WOW_PROJECT_ID ~= 18 or version ~= "1.60.1" or tonumber(build) ~= 70862 or interface ~= 16001 then
    print(ADDON_TITLE .. ": requires WoW Forever 1.60.1.70862 (interface 16001).")
    return
end

local defaults = {
    enabled = false,
    horizontalOffset = 0,
    verticalOffset = 0,
    window = {
        point = "CENTER",
        x = 0,
        y = 0,
    },
    minimap = {
        angle = 225,
    },
    filters = {
        brightness = 0,
        contrast = 0,
        temperature = 0,
    },
    originals = {},
}

local controlledCVars = {
    "test_cameraOverShoulder",
    "test_cameraDynamicPitch",
    "test_cameraDynamicPitchBaseFovPad",
    "test_cameraDynamicPitchBaseFovPadFlying",
    "CameraKeepCharacterCentered",
    "CameraReduceUnexpectedMovement",
}

local db
local mainFrame
local minimapButton
local filterFrame
local filterTextures = {}
local controls = {}
local RefreshControlState

local EMOTES = {}
local emoteByCommand = {}
local pendingShot
local cameraPending = false
local cameraError = false

local function BuildEmoteList()
    wipe(EMOTES)
    wipe(emoteByCommand)
    local labels = {}
    for index = 1, MAXEMOTEINDEX do
        local token = _G["EMOTE" .. index .. "_TOKEN"]
        if token and not labels[token] then
            labels[token] = _G["EMOTE" .. index .. "_CMD1"]
        end
    end
    -- The exact animated Emote submenu beside chat, in the client's order.
    -- TextEmoteSpeechList belongs to the separate voice submenu.
    for _, token in ipairs(EmoteList) do
        if not emoteByCommand[token] then
            local entry = { command = token, label = labels[token] or token }
            EMOTES[#EMOTES + 1] = entry
            emoteByCommand[token] = entry
        end
    end
end

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = DeepCopy(child)
    end
    return copy
end

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(target[key]) ~= type(value) then
            target[key] = DeepCopy(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            ApplyDefaults(target[key], value)
        end
    end
    return target
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or 0
    if value ~= value then value = 0 end -- Reject NaN in damaged saved data.
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end

local function Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor((tonumber(value) or 0) * mult + 0.5) / mult
end

local function FormatNumber(value, decimals)
    return string.format("%." .. tostring(decimals or 1) .. "f", value)
end

local function ReadCVar(cvar)
    local ok, value = pcall(C_CVar.GetCVar, cvar)
    if ok then return value end
end

local function WriteCVar(cvar, value)
    if value == nil then return false end
    local ok, success = pcall(C_CVar.SetCVar, cvar, tostring(value))
    return ok and success == true
end

local function CaptureOriginals()
    db.originals = db.originals or {}
    for _, cvar in ipairs(controlledCVars) do
        if db.originals[cvar] == nil then
            local value = ReadCVar(cvar)
            if value ~= nil then
                db.originals[cvar] = value
            end
        end
    end
end

local function RestoreOriginals()
    if not db then return end
    -- Only restore our own CVars. Keep failed restores for the next safe retry.
    for _, cvar in ipairs(controlledCVars) do
        local value = db.originals[cvar]
        if value ~= nil then
            if WriteCVar(cvar, value) then
                db.originals[cvar] = nil
            else
                cameraError = true
            end
        end
    end
end

local function SetOverlayColor(texture, r, g, b, alpha)
    if not texture then return end
    if alpha <= 0.001 then
        texture:Hide()
        return
    end
    texture:SetColorTexture(r, g, b, 1)
    texture:SetAlpha(alpha)
    texture:Show()
end

local function EnsureFilterFrame()
    if filterFrame then return filterFrame end
    local parent = WorldFrame
    filterFrame = CreateFrame("Frame", "ScreenShotCameraFilterFrame", parent)
    filterFrame:SetFrameStrata("LOW")
    filterFrame:SetFrameLevel(0)
    filterFrame:EnableMouse(false)
    filterFrame:SetAllPoints(WorldFrame)

    for _, name in ipairs({ "contrast", "temperature", "brightness" }) do
        local texture = filterFrame:CreateTexture(nil, "OVERLAY")
        texture:SetAllPoints(filterFrame)
        texture:SetBlendMode("BLEND")
        texture:Hide()
        filterTextures[name] = texture
    end
    filterFrame:Hide()
    return filterFrame
end

local function ApplyFilterSettings()
    if not db then return end
    EnsureFilterFrame()
    if not db.enabled then
        filterFrame:Hide()
        return
    end
    db.filters = ApplyDefaults(db.filters or {}, defaults.filters)
    db.filters.brightness = Clamp(db.filters.brightness, -1, 1)
    db.filters.contrast = Clamp(db.filters.contrast, -1, 1)
    db.filters.temperature = Clamp(db.filters.temperature, -1, 1)

    local brightness = Round(db.filters.brightness, 2)
    local contrast = Round(db.filters.contrast, 2)
    local temperature = Round(db.filters.temperature, 2)
    local hasFilter = math.abs(brightness) > 0.001 or math.abs(contrast) > 0.001 or math.abs(temperature) > 0.001

    if not hasFilter then
        filterFrame:Hide()
        return
    end

    filterFrame:Show()
    if contrast >= 0 then
        SetOverlayColor(filterTextures.contrast, 0, 0, 0, contrast * 0.24)
    else
        SetOverlayColor(filterTextures.contrast, 0.85, 0.85, 0.85, math.abs(contrast) * 0.22)
    end
    if temperature >= 0 then
        SetOverlayColor(filterTextures.temperature, 1, 0.46, 0.12, temperature * 0.28)
    else
        SetOverlayColor(filterTextures.temperature, 0.16, 0.42, 1, math.abs(temperature) * 0.28)
    end
    if brightness >= 0 then
        SetOverlayColor(filterTextures.brightness, 1, 1, 1, brightness * 0.32)
    else
        SetOverlayColor(filterTextures.brightness, 0, 0, 0, math.abs(brightness) * 0.36)
    end
end

local function FinishScreenshot(message)
    local shot = pendingShot
    if not shot then return end
    shot.cancelled = true
    if shot.captureTimer then shot.captureTimer:Cancel() end
    if shot.timeout then shot.timeout:Cancel() end
    if message then
        print(ADDON_TITLE .. ": " .. message)
    end
    if shot.uiHidden then
        -- UIParent contains protected children: retry after combat if necessary.
        local ok = pcall(UIParent.Show, UIParent)
        if not ok or not UIParent:IsShown() then
            RefreshControlState()
            return
        end
        shot.uiHidden = false
    end
    pendingShot = nil
    RefreshControlState()
end

local function TakeCleanScreenshot()
    if pendingShot then return end
    if InCombatLockdown() then
        print(ADDON_TITLE .. ": clean screenshots are unavailable during combat.")
        return
    end

    -- Do not execute stale commands imported from older versions.
    if db.selectedEmote and not emoteByCommand[db.selectedEmote] then
        db.selectedEmote = nil
    end
    if db.selectedEmote then
        local ok, success = pcall(C_ChatInfo.PerformEmote, db.selectedEmote)
        if not ok or not success then
            print(ADDON_TITLE .. ": the selected emote cannot be performed right now.")
            return
        end
    end

    local shot = { uiHidden = false }
    pendingShot = shot
    if UIParent:IsShown() then
        -- Record ownership before hiding, so an error cannot strand the UI.
        shot.uiHidden = true
        local ok = pcall(UIParent.Hide, UIParent)
        if not ok or UIParent:IsShown() then
            FinishScreenshot("cannot hide the UI right now; screenshot cancelled.")
            return
        end
    end
    RefreshControlState()
    shot.timeout = C_Timer.NewTimer(10, function()
        if pendingShot == shot then
            FinishScreenshot("screenshot timed out; restoring the UI.")
        end
    end)
    shot.captureTimer = C_Timer.NewTimer(db.selectedEmote and 1.5 or 0.2, function()
        if pendingShot ~= shot or shot.cancelled then return end
        if InCombatLockdown() then
            FinishScreenshot("screenshot cancelled on entering combat.")
            return
        end
        if UIParent:IsShown() then
            FinishScreenshot("the UI was reopened; screenshot cancelled.")
            return
        end
        shot.requested = true
        local ok = pcall(Screenshot)
        if not ok then FinishScreenshot("screenshot failed; restoring the UI.") end
    end)
end

local function ApplyCameraSettings()
    if not db then return end
    if InCombatLockdown() then
        cameraPending = true
        return
    end
    cameraPending = false
    cameraError = false
    db.horizontalOffset = Clamp(db.horizontalOffset, -10, 10)
    db.verticalOffset = Clamp(db.verticalOffset, 0, 1)

    if not db.enabled then
        RestoreOriginals()
        ApplyFilterSettings()
        return
    end

    CaptureOriginals()
    local horizontal = Round(db.horizontalOffset, 1)
    local vertical = Round(db.verticalOffset, 2)
    local usesDynamicPitch = vertical > 0.001

    local desired = {
        test_cameraOverShoulder = horizontal,
        test_cameraDynamicPitch = usesDynamicPitch and 1 or 0,
        test_cameraDynamicPitchBaseFovPad = vertical,
        test_cameraDynamicPitchBaseFovPadFlying = vertical,
        CameraKeepCharacterCentered = (math.abs(horizontal) > 0.001 or usesDynamicPitch)
            and 0 or db.originals.CameraKeepCharacterCentered,
        CameraReduceUnexpectedMovement = math.abs(horizontal) > 0.001
            and 0 or db.originals.CameraReduceUnexpectedMovement,
    }
    for _, cvar in ipairs(controlledCVars) do
        -- Never change a CVar unless we have a recoverable original value.
        if db.originals[cvar] == nil or not WriteCVar(cvar, desired[cvar]) then
            cameraError = true
        end
    end

    ApplyFilterSettings()
end

RefreshControlState = function()
    if not mainFrame or not db then return end
    controls.enable:SetChecked(db.enabled)
    local editable = not InCombatLockdown() and not pendingShot
    controls.enable:SetEnabled(editable)
    controls.reset:SetEnabled(editable)
    controls.screenshot:SetEnabled(editable)
    controls.emote:SetEnabled(editable)
    for _, slider in pairs(controls.sliders) do
        slider:SetEnabled(db.enabled and editable)
    end
    local status = db.enabled and "Camera active" or "Camera inactive"
    if cameraError then status = "Some camera settings unavailable" end
    if cameraPending then status = "Camera changes pending" end
    if InCombatLockdown() then status = "Controls paused in combat" end
    if pendingShot then status = "Capture in progress" end
    controls.status:SetText(status)
    controls.emote:GenerateMenu()
end

local function SaveWindowPosition()
    if not mainFrame or not db then return end
    local point, _, _, x, y = mainFrame:GetPoint(1)
    db.window.point = point or "CENTER"
    db.window.x = Round(x or 0, 0)
    db.window.y = Round(y or 0, 0)
end

local function CreateSlider(parent, name, label, key, minValue, maxValue, step, decimals, yOffset, owner)
    owner = owner or db
    local slider = CreateFrame("Frame", "ScreenShotCamera" .. name .. "Slider", parent,
        "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 26, yOffset)
    slider:SetPoint("RIGHT", parent, "RIGHT", -26, 0)
    slider:SetHeight(40)
    local Label = MinimalSliderWithSteppersMixin.Label
    slider:Init(owner[key], minValue, maxValue, (maxValue - minValue) / step, {
        [Label.Top] = function(value) return label .. ": " .. FormatNumber(value, decimals) end,
        [Label.Min] = function() return tostring(minValue) end,
        [Label.Max] = function() return tostring(maxValue) end,
    })
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        owner[key] = Round(Clamp(value, minValue, maxValue), decimals)
        ApplyCameraSettings()
        RefreshControlState()
    end, slider)
    return slider
end

local function ResetSettings()
    db.horizontalOffset = defaults.horizontalOffset
    db.verticalOffset = defaults.verticalOffset
    db.filters = ApplyDefaults(db.filters or {}, defaults.filters)
    db.filters.brightness = defaults.filters.brightness
    db.filters.contrast = defaults.filters.contrast
    db.filters.temperature = defaults.filters.temperature
    db.selectedEmote = nil

    if controls.sliders then
        controls.sliders.horizontal:SetValue(db.horizontalOffset)
        controls.sliders.vertical:SetValue(db.verticalOffset)
        controls.sliders.brightness:SetValue(db.filters.brightness)
        controls.sliders.contrast:SetValue(db.filters.contrast)
        controls.sliders.temperature:SetValue(db.filters.temperature)
    end
    ApplyCameraSettings()
    RefreshControlState()
end

local function CreateMainFrame()
    if mainFrame then return mainFrame end
    mainFrame = CreateFrame("Frame", "ScreenShotCameraFrame", UIParent, "ButtonFrameTemplate")
    ButtonFrameTemplate_HidePortrait(mainFrame)
    ButtonFrameTemplate_HideAttic(mainFrame)
    mainFrame:SetTitle(ADDON_TITLE .. " - Forever")
    mainFrame.Inset:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -6, 92)
    mainFrame:SetSize(460, 610)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetPoint(db.window.point, UIParent, db.window.point, db.window.x, db.window.y)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition()
    end)
    mainFrame:Hide()

    tinsert(UISpecialFrames, "ScreenShotCameraFrame")

    local enable = CreateFrame("CheckButton", "ScreenShotCameraEnableCheck", mainFrame, "UICheckButtonTemplate")
    enable:SetPoint("TOPLEFT", 22, -38)
    _G[enable:GetName() .. "Text"]:SetText("Enable addon")
    enable:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked() and true or false
        ApplyCameraSettings()
        RefreshControlState()
    end)
    controls.enable = enable

    controls.status = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    controls.status:SetPoint("TOPLEFT", 28, -74)

    controls.sliders = {
        horizontal = CreateSlider(mainFrame, "Horizontal", "Horizontal offset (X)", "horizontalOffset", -10, 10, 0.1, 1, -105),
        vertical = CreateSlider(mainFrame, "Vertical", "Dynamic pitch", "verticalOffset", 0, 1, 0.01, 2, -165),
        brightness = CreateSlider(mainFrame, "Brightness", "Brightness", "brightness", -1, 1, 0.01, 2, -235, db.filters),
        contrast = CreateSlider(mainFrame, "Contrast", "Shade / haze", "contrast", -1, 1, 0.01, 2, -295, db.filters),
        temperature = CreateSlider(mainFrame, "Temperature", "Temperature", "temperature", -1, 1, 0.01, 2, -355, db.filters),
    }

    local emoteSep = mainFrame:CreateTexture(nil, "ARTWORK")
    emoteSep:SetHeight(1)
    emoteSep:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  24, -415)
    emoteSep:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -24, -415)
    emoteSep:SetColorTexture(0.35, 0.35, 0.35, 0.7)

    local emoteLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emoteLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 24, -426)
    emoteLabel:SetText("Emote for screenshot:")

    local dropdown = CreateFrame("DropdownButton", "ScreenShotCameraEmoteDropdown", mainFrame,
        "WowStyle1DropdownTemplate")
    dropdown:SetWidth(280)
    dropdown:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 26, -449)
    dropdown:SetDefaultText(NONE)
    dropdown:SetupMenu(function(_, rootDescription)
        rootDescription:SetScrollMode(260)
        local function IsSelected(command) return db.selectedEmote == command end
        local function Select(command) db.selectedEmote = command end
        rootDescription:CreateRadio(NONE, IsSelected, Select, nil)
        for _, emote in ipairs(EMOTES) do
            rootDescription:CreateRadio(emote.label, IsSelected, Select, emote.command)
        end
    end)
    controls.emote = dropdown

    local note = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 24, 56)
    note:SetPoint("BOTTOMRIGHT", -24, 56)
    note:SetJustifyH("LEFT")
    note:SetText("Filters are color overlays, not image post-processing.\nEmotes match the animated Emote menu beside chat.")

    local reset = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    reset:SetSize(118, 24)
    reset:SetPoint("BOTTOMLEFT", 24, 25)
    reset:SetText("Reset sliders")
    reset:SetScript("OnClick", ResetSettings)
    controls.reset = reset

    local screenshot = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    screenshot:SetSize(118, 24)
    screenshot:SetPoint("LEFT", reset, "RIGHT", 10, 0)
    screenshot:SetText("Screenshot")
    screenshot:SetScript("OnClick", TakeCleanScreenshot)
    controls.screenshot = screenshot

    local credit = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    credit:SetPoint("BOTTOMRIGHT", -24, 7)
    credit:SetText("ideated by Tumnus-Nemesis")

    RefreshControlState()
    return mainFrame
end

local function ToggleMainFrame()
    CreateMainFrame()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        RefreshControlState()
    end
end

local function UpdateMinimapButtonPosition()
    if not minimapButton or not db or not db.minimap or not Minimap then return end
    local angle = math.rad(db.minimap.angle or defaults.minimap.angle)
    local radiusX = Minimap:GetWidth() / 2 + 10
    local radiusY = Minimap:GetHeight() / 2 + 10
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radiusX, math.sin(angle) * radiusY)
end

local function SaveMinimapButtonPosition()
    if not db or not db.minimap or not Minimap or not UIParent or not GetCursorPosition then return end
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    if not centerX or not centerY then return end
    local scale = Minimap:GetEffectiveScale()
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
    if angle < 0 then angle = angle + 360 end
    db.minimap.angle = Round(angle, 0)
    UpdateMinimapButtonPosition()
end

local function CreateMinimapButton()
    if minimapButton or not Minimap then return minimapButton end
    minimapButton = CreateFrame("Button", "ScreenShotCameraMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:RegisterForClicks("LeftButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:SetScript("OnClick", function(self)
        if self.wasDragged then return end
        ToggleMainFrame()
    end)
    minimapButton:SetScript("OnDragStart", function(self)
        self.wasDragged = true
        self:SetScript("OnUpdate", SaveMinimapButtonPosition)
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        SaveMinimapButtonPosition()
        C_Timer.After(0, function() self.wasDragged = nil end)
    end)
    minimapButton:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ADDON_TITLE)
        GameTooltip:AddLine("Click: open or close the panel", 1, 1, 1)
        GameTooltip:AddLine("Drag: move the button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    UpdateMinimapButtonPosition()
    return minimapButton
end

local function PrintHelp()
    print("|cff7fffd4" .. ADDON_TITLE .. "|r /ssc, /ssc on, /ssc off, /ssc reset, /ssc shot")
end

local function HandleSlashCommand(message)
    message = string.lower(strtrim(message or ""))
    if pendingShot then
        print(ADDON_TITLE .. ": wait for the current capture to finish.")
        return
    end
    if message == "shot" then
        TakeCleanScreenshot()
    elseif message == "on" then
        db.enabled = true
        ApplyCameraSettings()
        RefreshControlState()
        print(ADDON_TITLE .. ": enabled.")
    elseif message == "off" then
        db.enabled = false
        ApplyCameraSettings()
        RefreshControlState()
        print(ADDON_TITLE .. ": disabled.")
    elseif message == "reset" then
        ResetSettings()
        print(ADDON_TITLE .. ": sliders reset.")
    elseif message == "help" or message == "?" then
        PrintHelp()
    else
        ToggleMainFrame()
    end
end

local function RegisterSettingsPanel()
    local panel = CreateFrame("Frame")
    panel.name = ADDON_TITLE

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ADDON_TITLE)

    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetSize(170, 28)
    openButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    openButton:SetText("Open camera panel")
    openButton:SetScript("OnClick", ToggleMainFrame)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", 0, -16)
    hint:SetText("Quick command: /ssc")

    local category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_TITLE)
    Settings.RegisterAddOnCategory(category)
end

local function NormalizeDatabase()
    if type(_G[DB_GLOBAL]) ~= "table" then _G[DB_GLOBAL] = {} end
    db = ApplyDefaults(_G[DB_GLOBAL], defaults)
    db.horizontalOffset = Clamp(db.horizontalOffset, -10, 10)
    db.verticalOffset = Clamp(db.verticalOffset, 0, 1)
    for key in pairs(defaults.filters) do db.filters[key] = Clamp(db.filters[key], -1, 1) end
    db.minimap.angle = Clamp(db.minimap.angle, 0, 360)
    local anchors = { CENTER=true, TOP=true, BOTTOM=true, LEFT=true, RIGHT=true,
        TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true }
    if not anchors[db.window.point] then db.window.point = "CENTER" end
    db.window.x = Clamp(db.window.x, -10000, 10000)
    db.window.y = Clamp(db.window.y, -10000, 10000)
    local originals = {}
    for _, cvar in ipairs(controlledCVars) do
        local value = tonumber(db.originals[cvar])
        if value and value == value and math.abs(value) < math.huge then
            originals[cvar] = tostring(value)
        end
    end
    db.originals = originals
    BuildEmoteList()
    if not emoteByCommand[db.selectedEmote] then db.selectedEmote = nil end
end

local function Initialize()
    NormalizeDatabase()
    CreateMainFrame()
    RegisterSettingsPanel()
    CreateMinimapButton()

    SLASH_SCREENSHOTCAMERA1 = "/ssc"
    SLASH_SCREENSHOTCAMERA2 = "/screenshotcamera"
    SlashCmdList.SCREENSHOTCAMERA = HandleSlashCommand
    ApplyCameraSettings()
    RefreshControlState()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        Initialize()
        self:RegisterEvent("PLAYER_LOGOUT")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("SCREENSHOT_SUCCEEDED")
        self:RegisterEvent("SCREENSHOT_FAILED")
    elseif event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
        if pendingShot and pendingShot.requested then
            FinishScreenshot(event == "SCREENSHOT_FAILED" and "screenshot failed." or nil)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if pendingShot then FinishScreenshot("screenshot cancelled on entering combat.") end
        RefreshControlState()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingShot and pendingShot.cancelled then FinishScreenshot() end
        ApplyCameraSettings()
        RefreshControlState()
    elseif event == "PLAYER_LOGOUT" then
        if pendingShot then FinishScreenshot() end
        RestoreOriginals()
    end
end)
