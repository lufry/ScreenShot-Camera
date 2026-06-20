local addonName = ...

local ADDON_TITLE = "ScreenShot Camera"
local DB_GLOBAL = "ScreenShotCameraDB"

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

local EMOTES = {
    { label = "Angry",            command = "ANGRY" },
    { label = "Apologize",        command = "APOLOGIZE" },
    { label = "Applaud",          command = "APPLAUD" },
    { label = "Attack Target",    command = "ATTACKTARGET" },
    { label = "Bashful",          command = "BASHFUL" },
    { label = "Beg",              command = "BEG" },
    { label = "Blame",            command = "BLAME" },
    { label = "Blush",            command = "BLUSH" },
    { label = "Boggle",           command = "BOGGLE" },
    { label = "Boop",             command = "BOOP" },
    { label = "Bored",            command = "BORED" },
    { label = "Bow",              command = "BOW" },
    { label = "Bye",              command = "BYE" },
    { label = "Cackle",           command = "CACKLE" },
    { label = "Charge",           command = "CHARGE" },
    { label = "Cheer",            command = "CHEER" },
    { label = "Chicken",          command = "CHICKEN" },
    { label = "Chuckle",          command = "CHUCKLE" },
    { label = "Clap",             command = "CLAP" },
    { label = "Commend",          command = "COMMEND" },
    { label = "Confused",         command = "CONFUSED" },
    { label = "Congratulate",     command = "CONGRATULATE" },
    { label = "Cower",            command = "COWER" },
    { label = "Cry",              command = "CRY" },
    { label = "Curious",          command = "CURIOUS" },
    { label = "Curtsey",          command = "CURTSEY" },
    { label = "Dance",            command = "DANCE" },
    { label = "Disagree",         command = "DISAGREE" },
    { label = "Doubt",            command = "DOUBT" },
    { label = "Drink",            command = "DRINK" },
    { label = "Eat",              command = "EAT" },
    { label = "Flee",             command = "FLEE" },
    { label = "Flex",             command = "FLEX" },
    { label = "Flirt",            command = "FLIRT" },
    { label = "Follow Me",        command = "FOLLOWME" },
    { label = "For the Alliance", command = "FORTHEALLIANCE" },
    { label = "For the Horde",    command = "FORTHEHORDE" },
    { label = "Gasp",             command = "GASP" },
    { label = "Giggle",           command = "GIGGLE" },
    { label = "Gloat",            command = "GLOAT" },
    { label = "Golf Clap",        command = "GOLFCLAP" },
    { label = "Greet",            command = "GREET" },
    { label = "Grovel",           command = "GROVEL" },
    { label = "Growl",            command = "GROWL" },
    { label = "Guffaw",           command = "GUFFAW" },
    { label = "Hail",             command = "HAIL" },
    { label = "Heal Me",          command = "HELPME" },
    { label = "Hello",            command = "HELLO" },
    { label = "Help Me",          command = "HELPME" },
    { label = "Huzzah",           command = "HUZZAH" },
    { label = "Impressed",        command = "IMPRESSED" },
    { label = "Incoming",         command = "INCOMING" },
    { label = "Insult",           command = "INSULT" },
    { label = "Kiss",             command = "KISS" },
    { label = "Kneel",            command = "KNEEL" },
    { label = "Laugh",            command = "LAUGH" },
    { label = "Lay Down",         command = "LAYDOWN" },
    { label = "Lost",             command = "LOST" },
    { label = "Magnificent",      command = "MAGNIFICENT" },
    { label = "Mercy",            command = "MERCY" },
    { label = "Mount Special",    command = "MOUNTSPECIAL" },
    { label = "Mourn",            command = "MOURN" },
    { label = "No",               command = "NO" },
    { label = "Nod",              command = "NOD" },
    { label = "Object",           command = "OBJECT" },
    { label = "OOM",              command = "OOM" },
    { label = "Oops",             command = "OOPS" },
    { label = "Open Fire",        command = "OPENFIRE" },
    { label = "Plead",            command = "PLEAD" },
    { label = "Point",            command = "POINT" },
    { label = "Ponder",           command = "PONDER" },
    { label = "Pray",             command = "PRAY" },
    { label = "Puzzled",          command = "PUZZLED" },
    { label = "Quack",            command = "QUACK" },
    { label = "Rasp",             command = "RASP" },
    { label = "Read",             command = "READ" },
    { label = "Roar",             command = "ROAR" },
    { label = "ROFL",             command = "ROFL" },
    { label = "Rude",             command = "RUDE" },
    { label = "Salute",           command = "SALUTE" },
    { label = "Scared",           command = "SCARED" },
    { label = "Shout",            command = "SHOUT" },
    { label = "Shrug",            command = "SHRUG" },
    { label = "Shy",              command = "SHY" },
    { label = "Sigh",             command = "SIGH" },
    { label = "Silly",            command = "SILLY" },
    { label = "Sing",             command = "SING" },
    { label = "Sit",              command = "SIT" },
    { label = "Sleep",            command = "SLEEP" },
    { label = "Sniff",            command = "SNIFF" },
    { label = "Stand",            command = "STAND" },
    { label = "Surrender",        command = "SURRENDER" },
    { label = "Talk",             command = "TALK" },
    { label = "Talk (Excited)",   command = "TALKEX" },
    { label = "Talk (Question)",  command = "TALKQ" },
    { label = "Taunt",            command = "TAUNT" },
    { label = "Thank",            command = "THANK" },
    { label = "Threaten",         command = "THREATEN" },
    { label = "Train",            command = "TRAIN" },
    { label = "Victory",          command = "VICTORY" },
    { label = "Violin",           command = "VIOLIN" },
    { label = "Wait",             command = "WAIT" },
    { label = "Wave",             command = "WAVE" },
    { label = "Welcome",          command = "WELCOME" },
    { label = "Whistle",          command = "WHISTLE" },
    { label = "Whoa",             command = "WHOA" },
    { label = "Yawn",             command = "YAWN" },
    { label = "You're Welcome",   command = "YW" },
}

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
        if target[key] == nil then
            target[key] = DeepCopy(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            ApplyDefaults(target[key], value)
        end
    end
    return target
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or 0
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

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    elseif x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end
    return 0
end

local function Trim(value)
    if strtrim then
        return strtrim(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function After(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
    else
        callback()
    end
end

local function ReadCVar(cvar)
    if C_CVar and C_CVar.GetCVar then
        local ok, value = pcall(C_CVar.GetCVar, cvar)
        if ok then return value end
    end
    if GetCVar then
        local ok, value = pcall(GetCVar, cvar)
        if ok then return value end
    end
end

local function WriteCVar(cvar, value)
    if value == nil then return false end
    local textValue = tostring(value)
    if C_CVar and C_CVar.SetCVar then
        local ok, result = pcall(C_CVar.SetCVar, cvar, textValue)
        if ok and result ~= false then return true end
    end
    if SetCVar then
        local ok, result = pcall(SetCVar, cvar, textValue, addonName)
        if ok and result ~= false then return true end
    end
    return false
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
    if not db or not db.originals then return end
    for cvar, value in pairs(db.originals) do
        WriteCVar(cvar, value)
    end
    db.originals = {}
end

local function SetOverlayColor(texture, r, g, b, alpha)
    if not texture then return end
    if alpha <= 0.001 then
        texture:Hide()
        return
    end
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, 1)
    else
        texture:SetTexture(r, g, b, 1)
    end
    texture:SetAlpha(alpha)
    texture:Show()
end

local function EnsureFilterFrame()
    if filterFrame then return filterFrame end
    local parent = WorldFrame or UIParent
    filterFrame = CreateFrame("Frame", "ScreenShotCameraFilterFrame", parent)
    filterFrame:SetFrameStrata("LOW")
    filterFrame:SetFrameLevel(0)
    filterFrame:EnableMouse(false)
    if UIParent then
        filterFrame:SetAllPoints(UIParent)
    else
        filterFrame:SetAllPoints(parent)
    end
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

local function TakeCleanScreenshot()
    if not Screenshot then return end
    local uiWasShown = UIParent and UIParent:IsShown()
    local panelWasShown = mainFrame and mainFrame:IsShown()

    if UIParent and uiWasShown then
        local ok = pcall(UIParent.Hide, UIParent)
        if not ok or UIParent:IsShown() then
            print(ADDON_TITLE .. ": cannot hide the UI right now.")
            Screenshot()
            return
        end
    end

    local function doScreenshotAndRestore()
        Screenshot()
        After(1.0, function()
            if UIParent and uiWasShown then
                pcall(UIParent.Show, UIParent)
            end
            if mainFrame and panelWasShown then
                mainFrame:Show()
                RefreshControlState()
            end
        end)
    end

    if db.selectedEmote then
        DoEmote(db.selectedEmote)
        After(1.5, doScreenshotAndRestore)
    else
        After(0.1, doScreenshotAndRestore)
    end
end

local function ApplyCameraSettings()
    if not db then return end
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

    WriteCVar("test_cameraOverShoulder", horizontal)
    WriteCVar("test_cameraDynamicPitch", usesDynamicPitch and 1 or 0)
    WriteCVar("test_cameraDynamicPitchBaseFovPad", vertical)
    WriteCVar("test_cameraDynamicPitchBaseFovPadFlying", vertical)

    if math.abs(horizontal) > 0.001 or usesDynamicPitch then
        WriteCVar("CameraKeepCharacterCentered", 0)
    end
    if math.abs(horizontal) > 0.001 then
        WriteCVar("CameraReduceUnexpectedMovement", 0)
    end
    ApplyFilterSettings()
end

local function GetEmoteLabelByCommand(command)
    if not command then return "None" end
    for _, emote in ipairs(EMOTES) do
        if emote.command == command then
            return emote.label
        end
    end
    return "None"
end

RefreshControlState = function()
    if not mainFrame or not db then return end
    if controls.enable then
        controls.enable:SetChecked(db.enabled)
    end
    for _, slider in pairs(controls.sliders or {}) do
        if slider.SetEnabled then
            slider:SetEnabled(db.enabled)
        end
        slider:SetAlpha(db.enabled and 1 or 0.45)
    end
    if controls.status then
        controls.status:SetText(db.enabled and "Camera active" or "Camera inactive")
    end
    if controls.refreshEmoteText then
        controls.refreshEmoteText()
    end
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
    local sliderName = "ScreenShotCamera" .. name .. "Slider"
    local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 26, yOffset)
    slider:SetPoint("RIGHT", parent, "RIGHT", -26, 0)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    _G[sliderName .. "Low"]:SetText(tostring(minValue))
    _G[sliderName .. "High"]:SetText(tostring(maxValue))

    local title = _G[sliderName .. "Text"]
    title:SetText(label .. ": " .. FormatNumber(owner[key], decimals))
    slider:SetScript("OnValueChanged", function(self, value)
        value = Round(value, decimals)
        owner[key] = value
        title:SetText(label .. ": " .. FormatNumber(value, decimals))
        ApplyCameraSettings()
    end)
    slider:SetValue(owner[key])
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
    if controls.refreshEmoteText then
        controls.refreshEmoteText()
    end
    ApplyCameraSettings()
    RefreshControlState()
end

local function CreateMainFrame()
    if mainFrame then return mainFrame end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    mainFrame = CreateFrame("Frame", "ScreenShotCameraFrame", UIParent, template)
    mainFrame:SetSize(430, 560)
    mainFrame:SetPoint(db.window.point or "CENTER", UIParent, db.window.point or "CENTER", db.window.x or 0, db.window.y or 0)
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

    if mainFrame.SetBackdrop then
        mainFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText(ADDON_TITLE)

    local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local enable = CreateFrame("CheckButton", "ScreenShotCameraEnableCheck", mainFrame, "UICheckButtonTemplate")
    enable:SetPoint("TOPLEFT", 22, -52)
    _G[enable:GetName() .. "Text"]:SetText("Enable addon")
    enable:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked() and true or false
        ApplyCameraSettings()
        RefreshControlState()
    end)
    controls.enable = enable

    controls.status = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    controls.status:SetPoint("TOPRIGHT", -24, -62)

    controls.sliders = {
        horizontal = CreateSlider(mainFrame, "Horizontal", "Horizontal offset (X)", "horizontalOffset", -10, 10, 0.1, 1, -105),
        vertical = CreateSlider(mainFrame, "Vertical", "Vertical angle", "verticalOffset", 0, 1, 0.01, 2, -165),
        brightness = CreateSlider(mainFrame, "Brightness", "Brightness", "brightness", -1, 1, 0.01, 2, -235, db.filters),
        contrast = CreateSlider(mainFrame, "Contrast", "Contrast", "contrast", -1, 1, 0.01, 2, -295, db.filters),
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

    local DD_W       = 260
    local DD_ITEM_H  = 20
    local DD_VISIBLE = 9
    local POPUP_H    = DD_VISIBLE * DD_ITEM_H + 20

    local ddBdTpl = BackdropTemplateMixin and "BackdropTemplate" or nil
    local ddToggle = CreateFrame("Button", nil, mainFrame, ddBdTpl)
    ddToggle:SetSize(DD_W, 28)
    ddToggle:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 24, -444)
    if ddToggle.SetBackdrop then
        ddToggle:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end
    ddToggle:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local ddText = ddToggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ddText:SetPoint("LEFT",  10, 0)
    ddText:SetPoint("RIGHT", -32, 0)
    ddText:SetJustifyH("LEFT")
    ddText:SetText("None")

    local ddArrowTexture = ddToggle:CreateTexture(nil, "OVERLAY")
    ddArrowTexture:SetSize(24, 24)
    ddArrowTexture:SetPoint("RIGHT", ddToggle, "RIGHT", -4, 0)
    ddArrowTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local ddIntercept = CreateFrame("Frame", nil, UIParent)
    ddIntercept:SetAllPoints(UIParent)
    ddIntercept:SetFrameStrata("DIALOG")
    ddIntercept:SetFrameLevel(10)
    ddIntercept:EnableMouse(true)
    ddIntercept:Hide()

    local ddPopup = CreateFrame("Frame", nil, UIParent, ddBdTpl)
    ddPopup:SetSize(DD_W, POPUP_H)
    ddPopup:SetFrameStrata("DIALOG")
    ddPopup:SetFrameLevel(20)
    ddPopup:Hide()
    if ddPopup.SetBackdrop then
        ddPopup:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        })
    end

    local ddScroll = CreateFrame("ScrollFrame", nil, ddPopup)
    ddScroll:SetPoint("TOPLEFT",     ddPopup, "TOPLEFT",     6, -8)
    ddScroll:SetPoint("BOTTOMRIGHT", ddPopup, "BOTTOMRIGHT", -24, 8)

    local TOTAL_ITEMS = #EMOTES + 1
    local ddContent = CreateFrame("Frame", nil, ddScroll)
    ddContent:SetSize(DD_W - 30, TOTAL_ITEMS * DD_ITEM_H)
    ddScroll:SetScrollChild(ddContent)

    local ddScrollBar = CreateFrame("Slider", nil, ddPopup, "UIPanelScrollBarTemplate")
    ddScrollBar:SetPoint("TOPRIGHT", ddPopup, "TOPRIGHT", -6, -23)
    ddScrollBar:SetPoint("BOTTOMRIGHT", ddPopup, "BOTTOMRIGHT", -6, 23)
    ddScrollBar:SetMinMaxValues(0, math.max(1, (TOTAL_ITEMS * DD_ITEM_H) - (DD_VISIBLE * DD_ITEM_H)))
    ddScrollBar:SetValueStep(DD_ITEM_H)
    ddScrollBar:SetValue(0)
    ddScrollBar:SetWidth(16)

    ddScroll:SetScript("OnVerticalScroll", function(self, offset)
        ddScrollBar:SetValue(offset)
    end)
    ddScrollBar:SetScript("OnValueChanged", function(self, value)
        ddScroll:SetVerticalScroll(value)
    end)

    local function CloseDD()
        ddPopup:Hide()
        ddIntercept:Hide()
    end

    local function ScrollToIndex(index)
        local itemTop = (index - 1) * DD_ITEM_H
        local viewTop = ddScroll:GetVerticalScroll()
        local viewBot = viewTop + DD_VISIBLE * DD_ITEM_H
        if itemTop < viewTop then
            ddScroll:SetVerticalScroll(itemTop)
        elseif itemTop + DD_ITEM_H > viewBot then
            ddScroll:SetVerticalScroll(itemTop + DD_ITEM_H - DD_VISIBLE * DD_ITEM_H)
        end
    end

    local function OpenDD()
        ddPopup:ClearAllPoints()
        ddPopup:SetPoint("TOPLEFT", ddToggle, "BOTTOMLEFT", 0, 0)
        ddPopup:Show()
        ddIntercept:Show()
        
        local maxRange = math.max(0, (TOTAL_ITEMS * DD_ITEM_H) - (DD_VISIBLE * DD_ITEM_H))
        ddScrollBar:SetMinMaxValues(0, maxRange)

        if db.selectedEmote then
            for i, emote in ipairs(EMOTES) do
                if emote.command == db.selectedEmote then
                    ScrollToIndex(i + 1)
                    break
                end
            end
        else
            ddScroll:SetVerticalScroll(0)
        end
    end

    local function RefreshDDText()
        ddText:SetText(GetEmoteLabelByCommand(db.selectedEmote))
    end

    ddIntercept:SetScript("OnMouseDown", CloseDD)
    ddToggle:SetScript("OnClick", function()
        if ddPopup:IsShown() then CloseDD() else OpenDD() end
    end)
    mainFrame:HookScript("OnHide", CloseDD)

    ddPopup:EnableMouseWheel(true)
    ddPopup:SetScript("OnMouseWheel", function(self, delta)
        local cur = ddScroll:GetVerticalScroll()
        local max = ddScroll:GetVerticalScrollRange()
        ddScroll:SetVerticalScroll(math.max(0, math.min(max, cur - delta * DD_ITEM_H * 2)))
    end)

    local function MakeRow(index, label, command)
        local btn = CreateFrame("Button", nil, ddContent)
        btn:SetSize(DD_W - 30, DD_ITEM_H)
        btn:SetPoint("TOPLEFT", 0, -(index - 1) * DD_ITEM_H)
        btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", 6, 0)
        txt:SetText(label)

        btn:SetScript("OnClick", function()
            db.selectedEmote = command
            RefreshDDText()
            CloseDD()
        end)
    end

    MakeRow(1, "None", nil)
    for i, emote in ipairs(EMOTES) do
        MakeRow(i + 1, emote.label, emote.command)
    end

    controls.refreshEmoteText = RefreshDDText
    RefreshDDText()

    local note = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 24, 68)
    note:SetPoint("BOTTOMRIGHT", -24, 68)
    note:SetJustifyH("LEFT")
    note:SetText("Color filters are overlay-based approximations for screenshots.")

    local reset = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    reset:SetSize(118, 24)
    reset:SetPoint("BOTTOMLEFT", 24, 32)
    reset:SetText("Reset sliders")
    reset:SetScript("OnClick", ResetSettings)

    local screenshot = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    screenshot:SetSize(118, 24)
    screenshot:SetPoint("LEFT", reset, "RIGHT", 10, 0)
    screenshot:SetText("Screenshot")
    screenshot:SetScript("OnClick", TakeCleanScreenshot)

    local credit = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    credit:SetPoint("BOTTOMRIGHT", -24, 12)
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
    local radius = ((Minimap:GetWidth() or 140) / 2) + 10
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function SaveMinimapButtonPosition()
    if not db or not db.minimap or not Minimap or not UIParent or not GetCursorPosition then return end
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local angle = math.deg(Atan2(cursorY - centerY, cursorX - centerX))
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

    local fallback = minimapButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fallback:SetPoint("CENTER", 0, 0)
    fallback:SetText("SC")

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
        After(0, function() self.wasDragged = nil end)
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
    print("|cff7fffd4" .. ADDON_TITLE .. "|r /ssc, /ssc on, /ssc off, /ssc reset")
end

local function HandleSlashCommand(message)
    message = string.lower(Trim(message or ""))
    if message == "on" then
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

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_TITLE)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local function Initialize()
    _G[DB_GLOBAL] = ApplyDefaults(_G[DB_GLOBAL] or {}, defaults)
    db = _G[DB_GLOBAL]

    CreateMainFrame()
    RegisterSettingsPanel()
    CreateMinimapButton()

    SLASH_SCREENSHOTCAMERA1 = "/ssc"
    SLASH_SCREENSHOTCAMERA2 = "/screenshotcamera"
    SlashCmdList.SCREENSHOTCAMERA = HandleSlashCommand

    After(0.25, function()
        ApplyCameraSettings()
        RefreshControlState()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        Initialize()
    end
end)