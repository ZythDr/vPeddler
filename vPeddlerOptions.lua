-- vPeddler Options Panel for Vanilla WoW 1.12

function vPeddler_CreateOptionsPanel()
    -- Create standalone frame
    local panel = CreateFrame("Frame", "vPeddlerOptionsFrame", UIParent)
    panel:SetWidth(350)
    panel:SetHeight(250)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- Fixed this line
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    panel:SetBackdropColor(0, 0, 0, 1)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() this:StartMoving() end)
    panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -20)  -- Fixed this line
    title:SetText("vPeddler Options")
    
    -- Create a close button
    local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)  -- Fixed this line
    
    -- Enable checkbox
    local enableCheck = CreateFrame("CheckButton", "vPeddlerEnableCheck", panel, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -50)  -- Fixed this line
    getglobal(enableCheck:GetName().."Text"):SetText("Enable vPeddler")
    enableCheck.tooltip = "Enable or disable vPeddler functionality"
    enableCheck:SetChecked(vPeddlerDB.enabled)
    enableCheck:SetScript("OnClick", function()
        vPeddlerDB.enabled = this:GetChecked()
    end)
    
    -- Auto-sell checkbox
    local autoSellCheck = CreateFrame("CheckButton", "vPeddlerAutoSellCheck", panel, "UICheckButtonTemplate")
    autoSellCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -8)
    getglobal(autoSellCheck:GetName().."Text"):SetText("Automatically sell grey items")
    autoSellCheck.tooltip = "Automatically sell all grey quality items when visiting a vendor"
    autoSellCheck:SetChecked(vPeddlerDB.autoSell)
    autoSellCheck:SetScript("OnClick", function()
        vPeddlerDB.autoSell = this:GetChecked()
    end)
    
    -- Auto-repair checkbox
    local autoRepairCheck = CreateFrame("CheckButton", "vPeddlerAutoRepairCheck", panel, "UICheckButtonTemplate")
    autoRepairCheck:SetPoint("TOPLEFT", autoSellCheck, "BOTTOMLEFT", 0, -8)
    getglobal(autoRepairCheck:GetName().."Text"):SetText("Automatically repair equipment")
    autoRepairCheck.tooltip = "Automatically repair all equipment when visiting a vendor"
    autoRepairCheck:SetChecked(vPeddlerDB.autoRepair)
    autoRepairCheck:SetScript("OnClick", function()
        vPeddlerDB.autoRepair = this:GetChecked()
    end)

    -- Auto-flag gray items checkbox
    local autoFlagGrayCheckbox = CreateFrame("CheckButton", "vPeddlerAutoFlagGrayCheckbox", vPeddlerOptionsFrame, "UICheckButtonTemplate")
    autoFlagGrayCheckbox:SetPoint("TOPLEFT", verboseModeCheckbox, "BOTTOMLEFT", 0, -10)
    autoFlagGrayCheckbox:SetChecked(vPeddlerDB.autoFlagGray)
    getglobal(autoFlagGrayCheckbox:GetName() .. "Text"):SetText("Automatically flag gray items for selling")
    autoFlagGrayCheckbox:SetScript("OnClick", function()
        vPeddlerDB.autoFlagGray = this:GetChecked()
        if vPeddlerDB.verboseMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Auto-flag gray items " .. (vPeddlerDB.autoFlagGray and "enabled" or "disabled"))
        end
        vPeddler.OnOptionSet("autoFlagGray", vPeddlerDB.autoFlagGray)
    end)
    
    -- Label for quality filters
    local qualityLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qualityLabel:SetPoint("TOPLEFT", autoRepairCheck, "BOTTOMLEFT", 0, -20)
    qualityLabel:SetText("Auto-sell these item qualities:")
    
    -- Quality checkboxes
    local qualities = {
        [0] = {name = "Poor (Grey)", color = {r=0.62, g=0.62, b=0.62}},
        [1] = {name = "Common (White)", color = {r=1, g=1, b=1}},
        [2] = {name = "Uncommon (Green)", color = {r=0.1, g=1, b=0.1}},
        [3] = {name = "Rare (Blue)", color = {r=0.1, g=0.1, b=1}},
        [4] = {name = "Epic (Purple)", color = {r=0.8, g=0.1, b=0.8}},
        [5] = {name = "Legendary (Orange)", color = {r=1, g=0.5, b=0}},
    }
    
    local lastCheck
    for i=0, 5 do
        local qualityCheck = CreateFrame("CheckButton", "vPeddlerQualityCheck"..i, panel, "UICheckButtonTemplate")
        if i == 0 then
            qualityCheck:SetPoint("TOPLEFT", qualityLabel, "BOTTOMLEFT", 0, -8)
        else
            qualityCheck:SetPoint("TOPLEFT", lastCheck, "BOTTOMLEFT", 0, -8)
        end
        
        local text = getglobal(qualityCheck:GetName().."Text")
        text:SetText(qualities[i].name)
        text:SetTextColor(qualities[i].color.r, qualities[i].color.g, qualities[i].color.b)
        
        qualityCheck:SetChecked(vPeddlerDB.ignoreQuality[i])
        qualityCheck:SetScript("OnClick", function()
            vPeddlerDB.ignoreQuality[i] = this:GetChecked()
        end)
        
        lastCheck = qualityCheck
    end
    
    return panel
end

-- Store current settings locally for editing
local tempSettings = {}

-- Called when the options frame is loaded
function vPeddlerOptions_OnLoad()
    -- Set the title text
    getglobal(this:GetName().."HeaderText"):SetText("vPeddler Options");
    
    -- Register slash commands
    SLASH_VPEDDLER1 = "/vpeddler";
    SLASH_VPEDDLER2 = "/vp";
    SlashCmdList["VPEDDLER"] = function(msg)
        vPeddlerOptions_SlashHandler(msg);
    end
    
    -- Set checkbox labels
    getglobal(vPeddlerEnabledCheckbox:GetName().."Text"):SetText("Enable vPeddler");
    getglobal(vPeddlerAutoRepairCheckbox:GetName().."Text"):SetText("Auto Repair (WIP)");
    getglobal(vPeddlerAutoSellCheckbox:GetName().."Text"):SetText("Auto Sell Junk");
    getglobal(vPeddlerManualSellButtonCheckbox:GetName().."Text"):SetText("Use Manual Sell Button (WIP)");
    getglobal(vPeddlerVerboseModeCheckbox:GetName().."Text"):SetText("Verbose Mode");    
    -- Add this line
    getglobal(vPeddlerIconOutlineCheckbox:GetName().."Text"):SetText("Outline");

    -- Update the slider min, max and step values for more granular control
    getglobal(vPeddlerIconSizeSlider:GetName().."Low"):SetText("Small");
    getglobal(vPeddlerIconSizeSlider:GetName().."High"):SetText("Large");
    vPeddlerIconSizeSlider:SetMinMaxValues(10, 40);
    vPeddlerIconSizeSlider:SetValueStep(1);

    -- Make the frame movable
    vPeddlerOptionsFrame:SetMovable(true)
    vPeddlerOptionsFrame:EnableMouse(true)
    vPeddlerOptionsFrame:RegisterForDrag("LeftButton")
    vPeddlerOptionsFrame:SetClampedToScreen(true)
end

-- Called when the options frame is shown
function vPeddlerOptions_OnShow()
    -- Copy current settings to temp storage
    tempSettings = {};
    for k, v in pairs(vPeddlerDB) do
        if type(v) ~= "table" then
            tempSettings[k] = v;
        end
    end
    
    -- Special handling for tables
    tempSettings.ignoreQuality = {};
    for k, v in pairs(vPeddlerDB.ignoreQuality) do
        tempSettings.ignoreQuality[k] = v;
    end
    
    -- Update checkboxes based on current settings
    vPeddlerEnabledCheckbox:SetChecked(vPeddlerDB.enabled)
    vPeddlerAutoRepairCheckbox:SetChecked(vPeddlerDB.autoRepair)
    vPeddlerAutoSellCheckbox:SetChecked(vPeddlerDB.autoSell)
    vPeddlerManualSellButtonCheckbox:SetChecked(vPeddlerDB.manualSellButton)
    vPeddlerVerboseModeCheckbox:SetChecked(vPeddlerDB.verboseMode)
    
    -- Set the slider directly to the actual pixel size value
    vPeddlerIconSizeSlider:SetValue(vPeddlerDB.iconSize);
    vPeddlerIconAlphaSlider:SetValue(vPeddlerDB.iconAlpha);
    
    -- Update other UI elements
    vPeddlerIconOutlineCheckbox:SetChecked(vPeddlerDB.iconOutline);
    
    -- Fix dropdown menus to show current values
    -- Modifier Key dropdown
    if vPeddlerDB.modifierKey == "ALT" then
        UIDropDownMenu_SetSelectedValue(vPeddlerModifierKeyDropdown, "ALT");
        UIDropDownMenu_SetText("Alt Key", vPeddlerModifierKeyDropdown);
    elseif vPeddlerDB.modifierKey == "CTRL" then
        UIDropDownMenu_SetSelectedValue(vPeddlerModifierKeyDropdown, "CTRL");
        UIDropDownMenu_SetText("Control Key", vPeddlerModifierKeyDropdown);
    elseif vPeddlerDB.modifierKey == "SHIFT" then
        UIDropDownMenu_SetSelectedValue(vPeddlerModifierKeyDropdown, "SHIFT");
        UIDropDownMenu_SetText("Shift Key", vPeddlerModifierKeyDropdown);
    end
    
    -- Icon Texture dropdown
    if vPeddlerDB.iconTexture == "coins" then
        UIDropDownMenu_SetSelectedValue(vPeddlerIconTextureDropdown, "coins");
        UIDropDownMenu_SetText("Peddler Coins", vPeddlerIconTextureDropdown);
    elseif vPeddlerDB.iconTexture == "goldcoin" then
        UIDropDownMenu_SetSelectedValue(vPeddlerIconTextureDropdown, "goldcoin");
        UIDropDownMenu_SetText("Gold Coins", vPeddlerIconTextureDropdown);
    end
    
    -- Update the preview to match current settings
    vPeddlerOptions_UpdatePreview();
end

-- Updates the preview icon
function vPeddlerOptions_UpdatePreview()
    local texture = vPeddlerIconPreviewTexture;
    local texturePath = "";
    local textureSize = "16"; -- Default size suffix
    
    -- Select appropriate texture file based on size thresholds
    if vPeddlerDB.iconSize >= 15 and vPeddlerDB.iconSize <= 22 then
        textureSize = "32" -- Medium texture (32x32)
    elseif vPeddlerDB.iconSize > 22 then
        textureSize = "64" -- Large texture (64x64)
    else
        textureSize = "16" -- Small texture (16x16)
    end
    
    -- Direct file references based on selected texture size and outline setting
    if vPeddlerDB.iconTexture == "coins" then
        if vPeddlerDB.iconOutline then
            texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_outline_" .. textureSize .. ".tga"
        else
            texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_" .. textureSize .. ".tga"
        end
    elseif vPeddlerDB.iconTexture == "goldcoin" then
        texturePath = "Interface\\Icons\\INV_Misc_Coin_01"
    else
        -- Default to peddler coins
        if vPeddlerDB.iconOutline then
            texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_outline_" .. textureSize .. ".tga"
        else
            texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_" .. textureSize .. ".tga"
        end
    end
    
    texture:SetTexture(texturePath);
    texture:SetWidth(vPeddlerDB.iconSize);
    texture:SetHeight(vPeddlerDB.iconSize);
    texture:SetAlpha(vPeddlerDB.iconAlpha or 0.8);
end

-- Handle the various toggle functions
function vPeddlerOptions_EnabledToggle()
    vPeddlerDB.enabled = vPeddlerEnabledCheckbox:GetChecked();
    DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Addon " .. (vPeddlerDB.enabled and "enabled" or "disabled"));
end

function vPeddlerOptions_AutoRepairToggle()
    vPeddlerDB.autoRepair = vPeddlerAutoRepairCheckbox:GetChecked();
end

function vPeddlerOptions_AutoSellToggle()
    local isChecked = vPeddlerAutoSellCheckbox:GetChecked()
    vPeddlerDB.autoSell = isChecked
    
    -- If enabling auto-sell, disable manual button
    if isChecked then
        vPeddlerDB.manualSellButton = false
        vPeddlerManualSellButtonCheckbox:SetChecked(false)
    end
end

function vPeddlerOptions_AutoFlagGraysToggle()
    vPeddlerDB.autoFlagGrays = vPeddlerAutoFlagGraysCheckbox:GetChecked();
    
    -- If enabled, flag all gray items
    if vPeddlerDB.autoFlagGrays then
        vPeddlerDB.ignoreQuality[0] = true;
    else
        vPeddlerDB.ignoreQuality[0] = false;
    end
end

function vPeddlerOptions_ManualSellButtonToggle()
    local isChecked = vPeddlerManualSellButtonCheckbox:GetChecked()
    vPeddlerDB.manualSellButton = isChecked
    
    -- If enabling manual button, disable auto-sell
    if isChecked then
        vPeddlerDB.autoSell = false
        vPeddlerAutoSellCheckbox:SetChecked(false)
    end
end

-- Slider handlers
function vPeddlerOptions_IconSizeChanged()
    -- Get the exact pixel value from the slider
    local newSize = vPeddlerIconSizeSlider:GetValue();
    
    -- Only update if the size has actually changed
    if newSize ~= vPeddlerDB.iconSize then
        vPeddlerDB.iconSize = newSize;
        vPeddlerOptions_UpdatePreview();
        
        -- Update all visible bag markers
        vPeddler_RefreshAllMarkers();
    end
end

function vPeddlerOptions_IconAlphaChanged()
    local value = vPeddlerIconAlphaSlider:GetValue();
    vPeddlerDB.iconAlpha = value;
    vPeddlerOptions_UpdatePreview();
    vPeddler_UpdateBagSlotMarkers();
end

-- Button highlighting for position selector
function vPeddlerOptions_UpdatePositionButtons(position)
    vPeddlerIconPosTLButton:UnlockHighlight();
    vPeddlerIconPosTRButton:UnlockHighlight();
    vPeddlerIconPosCButton:UnlockHighlight();  -- Add this line
    vPeddlerIconPosBLButton:UnlockHighlight();
    vPeddlerIconPosBRButton:UnlockHighlight();
    
    if position == "TOPLEFT" then
        vPeddlerIconPosTLButton:LockHighlight();
    elseif position == "TOPRIGHT" then
        vPeddlerIconPosTRButton:LockHighlight();
    elseif position == "CENTER" then           -- Add this case
        vPeddlerIconPosCButton:LockHighlight();
    elseif position == "BOTTOMLEFT" then
        vPeddlerIconPosBLButton:LockHighlight();
    elseif position == "BOTTOMRIGHT" then
        vPeddlerIconPosBRButton:LockHighlight();
    end
end

-- Handle position button clicks
function vPeddlerOptions_IconPositionChange(position)
    vPeddlerDB.iconPosition = position;
    vPeddlerOptions_UpdatePositionButtons(position);
    vPeddler_UpdateBagSlotMarkers();
end

-- Initialize the modifier key dropdown menu
function vPeddlerOptions_ModifierKeyDropdown_Initialize()
    local info = {};
    
    -- Alt Key
    info = {};
    info.text = "Alt Key";
    info.value = "ALT";
    info.func = function()
        vPeddlerDB.modifierKey = "ALT";
        UIDropDownMenu_SetSelectedValue(vPeddlerModifierKeyDropdown, "ALT");
        UIDropDownMenu_SetText("Alt Key", vPeddlerModifierKeyDropdown);
    end
    UIDropDownMenu_AddButton(info);
    
    -- Ctrl Key
    info = {};
    info.text = "Ctrl Key";
    info.value = "CTRL";
    info.func = function()
        vPeddlerDB.modifierKey = "CTRL";
        UIDropDownMenu_SetSelectedValue(vPeddlerModifierKeyDropdown, "CTRL");
        UIDropDownMenu_SetText("Ctrl Key", vPeddlerModifierKeyDropdown);
    end
    UIDropDownMenu_AddButton(info);
    
    -- Shift Key
    info = {};
    info.text = "Shift Key";
    info.value = "SHIFT";
    info.func = function()
        vPeddlerDB.modifierKey = "SHIFT";
        UIDropDownMenu_SetSelectedValue(vPeddlerModifierKeyDropdown, "SHIFT");
        UIDropDownMenu_SetText("Shift Key", vPeddlerModifierKeyDropdown);
    end
    UIDropDownMenu_AddButton(info);
end

-- Initialize the icon texture dropdown menu
function vPeddlerOptions_IconTextureDropdown_Initialize()
    local info = {};
    
    -- Peddler Coins (your custom icon)
    info = {};
    info.text = "Peddler Coins";
    info.value = "coins";
    info.func = function()
        vPeddlerDB.iconTexture = "coins";
        vPeddlerDB.iconTextureDisplayName = "Peddler Coins";
        UIDropDownMenu_SetSelectedValue(vPeddlerIconTextureDropdown, "coins");
        UIDropDownMenu_SetText("Peddler Coins", vPeddlerIconTextureDropdown);
        vPeddlerOptions_UpdatePreview();
        vPeddler_UpdateBagSlotMarkers();
    end
    UIDropDownMenu_AddButton(info);
    
    -- Gold Coins (game icon)
    info = {};
    info.text = "Gold Coins";
    info.value = "goldcoin";
    info.func = function()
        vPeddlerDB.iconTexture = "goldcoin";
        vPeddlerDB.iconTextureDisplayName = "Gold Coins";
        UIDropDownMenu_SetSelectedValue(vPeddlerIconTextureDropdown, "goldcoin");
        UIDropDownMenu_SetText("Gold Coins", vPeddlerIconTextureDropdown);
        vPeddlerOptions_UpdatePreview();
        vPeddler_UpdateBagSlotMarkers();
    end
    UIDropDownMenu_AddButton(info);
end

-- Update the vPeddlerOptions_ResetDefaults function:

function vPeddlerOptions_ResetDefaults()
    -- Ask for confirmation
    StaticPopupDialogs["VPEDDLER_RESET"] = {
        text = "Reset all vPeddler settings to defaults?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            -- Store flaggedItems before reset
            local oldFlagged = vPeddlerDB.flaggedItems or {}
            
            -- Reset settings
            vPeddler_InitDefaults(true); -- true means force reset
            
            -- Restore flagged items
            vPeddlerDB.flaggedItems = oldFlagged
            
            -- Refresh the UI
            vPeddlerOptions_OnShow();
            
            -- Force rebuild item cache and update all markers
            vPeddler.needsUpdate = true
            vPeddler_BuildItemCache()
            vPeddler_UpdateBagSlotMarkers();
            
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Settings reset to defaults");
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    };
    
    StaticPopup_Show("VPEDDLER_RESET");
end

-- Add this new function to reset flagged items:

function vPeddlerOptions_ResetFilters()
    -- Ask for confirmation
    StaticPopupDialogs["VPEDDLER_RESET_FILTERS"] = {
        text = "Reset all manually flagged items?\n\nThis will clear your auto-sell list but keep your other settings.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            -- Clear flagged items table
            vPeddlerDB.flaggedItems = {}
            
            -- Force rebuild item cache and update all markers
            vPeddler.needsUpdate = true
            vPeddler_BuildItemCache()
            vPeddler_UpdateBagSlotMarkers()
            
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Auto-sell list has been cleared")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    
    StaticPopup_Show("VPEDDLER_RESET_FILTERS")
end

-- Slash command handler
function vPeddlerOptions_SlashHandler(msg)
    if msg == "reset" then
        vPeddlerOptions_ResetDefaults();
    elseif msg == "debug" then
        vPeddlerDB.debug = not vPeddlerDB.debug;
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Debug mode " .. (vPeddlerDB.debug and "enabled" or "disabled"));
    else
        -- Toggle the options panel
        if vPeddlerOptionsFrame:IsShown() then
            HideUIPanel(vPeddlerOptionsFrame);
        else
            ShowUIPanel(vPeddlerOptionsFrame);
        end
    end
end

-- Update your existing vPeddler_InitDefaults function to include new options
function vPeddler_InitDefaults(force)
    -- Create database if it doesn't exist
    if not vPeddlerDB or force then
        vPeddlerDB = {}
    end
    
    -- General settings - always force these values when resetting
    if force then
        vPeddlerDB.enabled = true
        vPeddlerDB.autoRepair = true
        vPeddlerDB.autoSell = true
        vPeddlerDB.autoFlagGrays = true
        vPeddlerDB.manualSellButton = false
        vPeddlerDB.verboseMode = true 
    else
        -- Only set if not already set
        vPeddlerDB.enabled = vPeddlerDB.enabled or true
        vPeddlerDB.autoRepair = vPeddlerDB.autoRepair or true
        vPeddlerDB.autoSell = vPeddlerDB.autoSell or true
        vPeddlerDB.autoFlagGrays = vPeddlerDB.autoFlagGrays or true
        vPeddlerDB.manualSellButton = vPeddlerDB.manualSellButton or false
        vPeddlerDB.verboseMode = vPeddlerDB.verboseMode or true
    end
    
    -- Icon settings - always force these values when resetting
    if force then
        vPeddlerDB.iconSize = 16
        vPeddlerDB.iconAlpha = 1.0
        vPeddlerDB.iconPosition = "BOTTOMLEFT"
        vPeddlerDB.iconTexture = "coins"
        vPeddlerDB.iconTextureDisplayName = "Peddler Coins"
        vPeddlerDB.modifierKey = "ALT"
        vPeddlerDB.iconOutline = false
    else
        -- Only set if not already set
        vPeddlerDB.iconSize = vPeddlerDB.iconSize or 16
        vPeddlerDB.iconAlpha = vPeddlerDB.iconAlpha or 1.0
        vPeddlerDB.iconPosition = vPeddlerDB.iconPosition or "BOTTOMLEFT"
        vPeddlerDB.iconTexture = vPeddlerDB.iconTexture or "coins"
        vPeddlerDB.iconTextureDisplayName = vPeddlerDB.iconTextureDisplayName or "Peddler Coins"
        vPeddlerDB.modifierKey = vPeddlerDB.modifierKey or "ALT"
        vPeddlerDB.iconOutline = vPeddlerDB.iconOutline or false
    end
    
    -- Item qualities to auto-sell (only poor by default)
    vPeddlerDB.ignoreQuality = vPeddlerDB.ignoreQuality or {}
    if force or vPeddlerDB.ignoreQuality[0] == nil then
        vPeddlerDB.ignoreQuality[0] = true  -- Poor (gray)
    end
    
    for i=1, 5 do
        if force or vPeddlerDB.ignoreQuality[i] == nil then
            vPeddlerDB.ignoreQuality[i] = false
        end
    end
    
    -- Wanted items list and flagged items
    vPeddlerDB.wantedItems = vPeddlerDB.wantedItems or {}
    vPeddlerDB.flaggedItems = vPeddlerDB.flaggedItems or {}
    
    -- Debug mode
    vPeddlerDB.debug = vPeddlerDB.debug or false
end

-- Update the vPeddler.lua file to implement these new settings
function vPeddler_UpdateHookBasedOnModifier()
    -- Unhook existing
    if vPeddler.originalContainerFrameItemButton_OnClick then
        ContainerFrameItemButton_OnClick = vPeddler.originalContainerFrameItemButton_OnClick
    end
    
    -- Save original function if we haven't already
    if not vPeddler.originalContainerFrameItemButton_OnClick then
        vPeddler.originalContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
    end
    
    -- Set up new hook with current modifier key
    ContainerFrameItemButton_OnClick = function(button)
        local shouldHandle = false
        
        -- Check the appropriate modifier based on settings
        if vPeddlerDB.modifierKey == "ALT" and IsAltKeyDown() and arg1 == "RightButton" then
            shouldHandle = true
        elseif vPeddlerDB.modifierKey == "CTRL" and IsControlKeyDown() and arg1 == "RightButton" then
            shouldHandle = true
        elseif vPeddlerDB.modifierKey == "SHIFT" and IsShiftKeyDown() and arg1 == "RightButton" then
            shouldHandle = true
        end
        
        if shouldHandle then
            local bag = this:GetParent():GetID()
            local slot = this:GetID()
            local link = GetContainerItemLink(bag, slot)
            
            if link then
                local itemId = vPeddler_GetItemId(link)
                if itemId then
                    -- Toggle flagged status
                    if vPeddlerDB.flaggedItems[itemId] then
                        vPeddlerDB.flaggedItems[itemId] = nil
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Removed item from auto-sell list")
                    else
                        vPeddlerDB.flaggedItems[itemId] = true
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Added item to auto-sell list")
                    end
                    
                    -- Update all instances of this item
                    vPeddler_UpdateAllInstancesOfItem(itemId)
                    return
                end
            end
        end
        
        -- Call original handler
        vPeddler.originalContainerFrameItemButton_OnClick(button)
    end
end

-- Initialize options panel when player logs in
function vPeddler_InitOptions()
    vPeddler.optionsPanel = vPeddler_CreateOptionsPanel()
    
    -- Add slash command to open options
    SLASH_VPEDDLEROPTIONS1 = "/vpopt"
    SLASH_VPEDDLEROPTIONS2 = "/vpo"
    
    SlashCmdList["VPEDDLEROPTIONS"] = function(msg)
        vPeddler.optionsPanel:Show()
    end
end

-- Show or hide the options panel
function vPeddler_ToggleOptionsPanel()
    if vPeddlerOptionsFrame:IsVisible() then
        vPeddlerOptionsFrame:Hide()
    else
        vPeddlerOptionsFrame:Show()
    end
end

-- Update your slash command handler
SLASH_VPEDDLER1 = "/vpeddler"
SLASH_VPEDDLER2 = "/vp"
SlashCmdList["VPEDDLER"] = function(msg)
    if msg == "" or msg == "options" or msg == "config" then
        vPeddler_ToggleOptionsPanel()
    elseif msg == "reset" then
        vPeddlerOptions_ResetDefaults()
    elseif msg == "clearfilters" or msg == "resetfilters" then
        vPeddlerOptions_ResetFilters()
    elseif msg == "repair" then
        vPeddler_AutoRepair()
    elseif msg == "sell" then
        vPeddler_SellJunk()
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /vp or /vpeddler - Toggle options panel")
        DEFAULT_CHAT_FRAME:AddMessage("  /vp sell - Manually sell junk items")
        DEFAULT_CHAT_FRAME:AddMessage("  /vp repair - Manually repair items")
        DEFAULT_CHAT_FRAME:AddMessage("  /vp reset - Reset all settings to defaults")
        DEFAULT_CHAT_FRAME:AddMessage("  /vp resetfilters - Clear all manually flagged items")
        DEFAULT_CHAT_FRAME:AddMessage("  /vp help - Show this help text")
    else
        vPeddler_ToggleOptionsPanel()
    end
end

-- Add a new function for the outline toggle
function vPeddlerOptions_OutlineToggle()
    vPeddlerDB.iconOutline = vPeddlerIconOutlineCheckbox:GetChecked();
    vPeddlerOptions_UpdatePreview();
    vPeddler_UpdateBagSlotMarkers();
end

-- Add this handler for when the checkbox is clicked:
function vPeddlerOptions_VerboseModeToggle()
    vPeddlerDB.verboseMode = vPeddlerVerboseModeCheckbox:GetChecked();
end