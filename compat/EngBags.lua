-- vPeddler integration module for EngBags inventory addon

-- Performance and behavior configuration
local SETTINGS = {
    debugMode = false,             -- Enable verbose logging
    settingsCheckInterval = 0.1,   -- Settings monitoring frequency
    updateThrottle = 0.2,          -- Anti-spam delay between updates
    initRetryDelay = 1,            -- Time between init attempts
    iconScanLimit = 200            -- Max button slots to scan
}

-- Core variables
local initialized = false
local lastUpdateTime = 0
local lastSettings = {}
local moveUpdatePending = false
local moveUpdateTimer = nil

-- Output functions for different verbosity levels
local function Debug(msg)
    if SETTINGS.debugMode then DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: " .. msg) end
end

local function Message(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: " .. msg)
end

-- Extracts bag and slot info from an EngBags button
local function GetItemFromButton(button)
    if not button or not button:GetName() then return nil, nil, nil end
    
    -- Extract button number from name
    local buttonName = button:GetName()
    local buttonNum = nil
    
    if string.find(buttonName, "EngInventory_frame_Item_") then
        buttonNum = tonumber(string.sub(buttonName, string.len("EngInventory_frame_Item_") + 1))
    elseif string.find(buttonName, "EngBank_frame_Item_") then
        buttonNum = tonumber(string.sub(buttonName, string.len("EngBank_frame_Item_") + 1))
    else
        return nil, nil, nil
    end
    
    if not buttonNum or not EngInventory_item_cache then return nil, nil, nil end
    
    -- Find item in EngInventory's cache
    for bagID, bagData in pairs(EngInventory_item_cache) do
        for slotID, itemData in pairs(bagData) do
            if itemData.button_num == buttonNum then
                local bag = itemData.bagnum
                local slot = itemData.slotnum
                local link = GetContainerItemLink(bag, slot)
                return bag, slot, link
            end
        end
    end
    
    return nil, nil, nil
end

-- Determines if an item should be marked for vendor sale
local function ShouldMarkAsVendor(link)
    if not link or not vPeddlerDB or not vPeddlerDB.enabled then return false end
    
    local itemId = vPeddler_GetItemId(link)
    if not itemId then return false end
    
    -- Check manually flagged items
    if vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[itemId] then
        return true
    end
    
    -- Check quality-based rules
    local _, _, quality = GetItemInfo(link)
    if quality and vPeddlerDB.ignoreQuality and vPeddlerDB.ignoreQuality[quality] then
        return true
    end
    
    return false
end

-- Creates or recreates a vendor icon on a button
local function CreateVendorIcon(button)
    if not button or not vPeddlerDB then return nil end
    
    -- Remove any existing icon
    if button.vPeddlerIcon then
        button.vPeddlerIcon:Hide()
        button.vPeddlerIcon = nil
    end
    
    -- Create new icon with fresh settings
    local icon = button:CreateTexture(button:GetName() .. "vPeddlerIcon", "OVERLAY")
    
    -- Apply current settings
    local position = vPeddlerDB.iconPosition or "BOTTOMLEFT"
    local size = vPeddlerDB.iconSize or 16
    local alpha = vPeddlerDB.iconAlpha or 1.0
    
    -- Position and size
    icon:ClearAllPoints()
    icon:SetPoint(position, button, position, 0, 0)
    icon:SetWidth(size)
    icon:SetHeight(size)
    
    -- Choose texture based on settings
    local texturePath = "Interface\\Icons\\INV_Misc_Coin_01"
    if vPeddlerDB.iconTexture == "coins" then
        local textureSize = "16"
        if size >= 23 and size <= 36 then textureSize = "32"
        elseif size > 36 then textureSize = "64" end
        
        if vPeddlerDB.iconOutline then
            texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_outline_" .. textureSize .. ".tga"
        else
            texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_" .. textureSize .. ".tga"
        end
    end
    
    icon:SetTexture(texturePath)
    icon:SetAlpha(alpha)
    
    button.vPeddlerIcon = icon
    return icon
end

-- Adds item flagging functionality to button clicks
local function HookButtonClick(button)
    if not button or button.vPeddlerClickHooked then return end
    
    local origClick = button:GetScript("OnClick") or function() end
    
    button:SetScript("OnClick", function()
        -- Check for modifier + right click
        local modKey = vPeddlerDB.modifierKey or "ALT"
        local isRightClick = (arg1 == "RightButton")
        local hasModifier = false
        
        if modKey == "ALT" and IsAltKeyDown() then hasModifier = true
        elseif modKey == "CTRL" and IsControlKeyDown() then hasModifier = true
        elseif modKey == "SHIFT" and IsShiftKeyDown() then hasModifier = true
        end
        
        if isRightClick and hasModifier then
            -- Process vPeddler flagging
            local bag, slot, link = GetItemFromButton(this)
            if bag and slot and link then
                local itemId = vPeddler_GetItemId(link)
                if itemId then
                    -- Toggle flag status
                    if not vPeddlerDB.flaggedItems then vPeddlerDB.flaggedItems = {} end
                    
                    if vPeddlerDB.flaggedItems[itemId] then
                        vPeddler_UnflagItem(itemId, link)
                        -- Only show message if verboseMode is enabled
                        if vPeddlerDB.verboseMode then
                            Message("Removed " .. link .. " from auto-sell list")
                        end
                    else
                        vPeddlerDB.flaggedItems[itemId] = true
                        -- Only show message if verboseMode is enabled
                        if vPeddlerDB.verboseMode then
                            Message("Added " .. link .. " to auto-sell list")
                        end
                    end
                    
                    -- Update icons after flag change
                    UpdateAllIcons(true)
                    return
                end
            end
        end
        
        -- Not our action, call original
        origClick()
    end)
    
    button.vPeddlerClickHooked = true
end

-- Removes all vendor icons from inventory and bank
local function ClearAllIcons()
    for i=1, SETTINGS.iconScanLimit do
        local button = getglobal("EngInventory_frame_Item_"..i)
        if button and button.vPeddlerIcon then
            button.vPeddlerIcon:Hide()
            button.vPeddlerIcon = nil
        end
        
        button = getglobal("EngBank_frame_Item_"..i)
        if button and button.vPeddlerIcon then
            button.vPeddlerIcon:Hide()
            button.vPeddlerIcon = nil
        end
    end
end

-- Main function that updates all vendor icons
function UpdateAllIcons(forceRecreate)
    if not vPeddlerDB or not vPeddlerDB.enabled or not EngInventory_item_cache then return 0 end
    
    -- Clear all icons if forcing recreation
    if forceRecreate then ClearAllIcons() end
    
    local updatedCount = 0
    
    -- Process inventory buttons
    for i = 1, SETTINGS.iconScanLimit do
        local button = getglobal("EngInventory_frame_Item_" .. i)
        if button and button:IsVisible() then
            -- Hook click handler if needed
            if not button.vPeddlerClickHooked then HookButtonClick(button) end
            
            -- Check if this button should have an icon
            local bag, slot, link = GetItemFromButton(button)
            local shouldHaveIcon = bag and slot and link and ShouldMarkAsVendor(link)
            
            -- Update icon state
            if shouldHaveIcon then
                if forceRecreate or not button.vPeddlerIcon then
                    CreateVendorIcon(button):Show()
                    updatedCount = updatedCount + 1
                elseif not button.vPeddlerIcon:IsShown() then
                    button.vPeddlerIcon:Show()
                    updatedCount = updatedCount + 1
                end
            elseif button.vPeddlerIcon and button.vPeddlerIcon:IsShown() then
                button.vPeddlerIcon:Hide()
                updatedCount = updatedCount + 1
            end
        end
    end
    
    -- Process bank buttons (same logic)
    for i = 1, SETTINGS.iconScanLimit do
        local button = getglobal("EngBank_frame_Item_" .. i)
        if button and button:IsVisible() then
            if not button.vPeddlerClickHooked then HookButtonClick(button) end
            
            local bag, slot, link = GetItemFromButton(button)
            local shouldHaveIcon = bag and slot and link and ShouldMarkAsVendor(link)
            
            if shouldHaveIcon then
                if forceRecreate or not button.vPeddlerIcon then
                    CreateVendorIcon(button):Show()
                    updatedCount = updatedCount + 1
                elseif not button.vPeddlerIcon:IsShown() then
                    button.vPeddlerIcon:Show()
                    updatedCount = updatedCount + 1
                end
            elseif button.vPeddlerIcon and button.vPeddlerIcon:IsShown() then
                button.vPeddlerIcon:Hide()
                updatedCount = updatedCount + 1
            end
        end
    end
    
    return updatedCount
end

-- Detects changes in vPeddler settings
local function CheckSettingsChanged()
    if not vPeddlerDB then return false end
    
    local currentSettings = {
        iconSize = vPeddlerDB.iconSize,
        iconPosition = vPeddlerDB.iconPosition,
        iconTexture = vPeddlerDB.iconTexture,
        iconOutline = vPeddlerDB.iconOutline,
        iconAlpha = vPeddlerDB.iconAlpha,
        enabled = vPeddlerDB.enabled,
        modifierKey = vPeddlerDB.modifierKey
    }
    
    -- First call will always return false (nothing to compare)
    if not lastSettings.iconSize then
        lastSettings = currentSettings
        return false
    end
    
    -- Check each setting for changes
    for key, value in pairs(currentSettings) do
        if lastSettings[key] ~= value then
            lastSettings = currentSettings
            return true
        end
    end
    
    return false
end

-- Hooks into EngInventory's update function
local function HookEngInventoryUpdate()
    if not EngInventory_UpdateWindow then return false end
    
    local originalUpdateWindow = EngInventory_UpdateWindow
    
    EngInventory_UpdateWindow = function()
        originalUpdateWindow()
        
        -- Update our icons with throttling
        local currentTime = GetTime()
        if currentTime - lastUpdateTime > SETTINGS.updateThrottle then
            lastUpdateTime = currentTime
            UpdateAllIcons()
        end
    end
    
    return true
end

-- Hooks into EngBank's update function
local function HookEngBankUpdate()
    if not EngBank_UpdateWindow then return false end
    
    local originalUpdateWindow = EngBank_UpdateWindow
    
    EngBank_UpdateWindow = function()
        originalUpdateWindow()
        
        -- Update our icons with throttling
        local currentTime = GetTime()
        if currentTime - lastUpdateTime > SETTINGS.updateThrottle then
            lastUpdateTime = currentTime
            UpdateAllIcons()
        end
    end
    
    return true
end

-- Hooks into vPeddler options frame for settings monitoring
local function HookOptionsFrameVisibility()
    if not vPeddlerOptionsFrame or vPeddlerOptionsFrame.vPeddlerHooked then return end
    
    -- Hook OnShow to begin settings monitoring
    local origOnShow = vPeddlerOptionsFrame:GetScript("OnShow") or function() end
    vPeddlerOptionsFrame:SetScript("OnShow", function()
        origOnShow()
        Debug("Options frame shown - refreshing settings monitor")
        isMonitoringSettings = true
    end)
    
    -- Hook OnHide to apply settings and stop monitoring
    local origOnHide = vPeddlerOptionsFrame:GetScript("OnHide") or function() end
    vPeddlerOptionsFrame:SetScript("OnHide", function()
        origOnHide()
        Debug("Options frame hidden - applying final settings")
        isMonitoringSettings = false
        UpdateAllIcons(true)  -- Force refresh when options frame is closed
    end)
    
    vPeddlerOptionsFrame.vPeddlerHooked = true
    return true
end

-- Main initialization function
local function Initialize()
    if initialized then return end
    
    if not vPeddlerDB then return false end
    if not EngInventory_item_cache then return false end
    
    -- Hook EngBags functions
    local success = HookEngInventoryUpdate()
    HookEngBankUpdate()
    
    -- Hook options frame visibility if it exists
    HookOptionsFrameVisibility()
    
    -- If options frame doesn't exist yet, watch for it
    if not vPeddlerOptionsFrame then
        local optionsWatcher = CreateFrame("Frame")
        local watcherElapsed = 0
        optionsWatcher:SetScript("OnUpdate", function()
            watcherElapsed = watcherElapsed + arg1
            -- Check every second
            if watcherElapsed >= 1.0 then
                watcherElapsed = 0
                if vPeddlerOptionsFrame then
                    HookOptionsFrameVisibility()
                    optionsWatcher:SetScript("OnUpdate", nil)
                end
            end
        end)
    end
    
    -- Make refresh function available to main addon
    if vPeddler then
        vPeddler.RefreshEngBagsIcons = function() 
            UpdateAllIcons(true) 
        end
    end
    
    -- Hook vPeddler's OnOptionSet
    if vPeddler and vPeddler.OnOptionSet and not vPeddler.engBagsHooked then
        local origFunction = vPeddler.OnOptionSet
        vPeddler.OnOptionSet = function(option, value)
            origFunction(option, value)
            UpdateAllIcons(true)
        end
        vPeddler.engBagsHooked = true
    end
    
    if success then
        initialized = true
        Debug("EngBags integration loaded")
        return true
    else
        return false
    end
end

-- Module slash commands
SLASH_VPE1 = "/vpe"
SlashCmdList["VPE"] = function(msg)
    if msg == "debug" then
        SETTINGS.debugMode = not SETTINGS.debugMode
        Message("EngBags debug mode " .. (SETTINGS.debugMode and "enabled" or "disabled"))
    elseif msg == "update" then
        UpdateAllIcons(true)
        Debug("Updated vendor icons")
    elseif msg == "settings" then
        Message("Current throttle settings:")
        DEFAULT_CHAT_FRAME:AddMessage("  Settings check interval: " .. SETTINGS.settingsCheckInterval .. "s")
        DEFAULT_CHAT_FRAME:AddMessage("  Update throttle: " .. SETTINGS.updateThrottle .. "s")
        DEFAULT_CHAT_FRAME:AddMessage("  Init retry delay: " .. SETTINGS.initRetryDelay .. "s")
        DEFAULT_CHAT_FRAME:AddMessage("  Icon scan limit: " .. SETTINGS.iconScanLimit)
    elseif msg == "reinit" then
        initialized = false
        Initialize()
        Debug("Reinitialized EngBags integration")
    else
        Message("EngBags commands")
        DEFAULT_CHAT_FRAME:AddMessage("  /vpe debug - Toggle debug mode")
        DEFAULT_CHAT_FRAME:AddMessage("  /vpe update - Force update icons")
        DEFAULT_CHAT_FRAME:AddMessage("  /vpe settings - Show current settings")
        DEFAULT_CHAT_FRAME:AddMessage("  /vpe reinit - Reinitialize integration")
    end
end

-- Settings monitor that only activates when options UI is visible
local settingsFrame = CreateFrame("Frame")
local lastCheckTime = 0
local isMonitoringSettings = false

settingsFrame:SetScript("OnUpdate", function()
    if not initialized then return end
    
    -- Check if options frame is visible
    local shouldMonitor = false
    if vPeddlerOptionsFrame and vPeddlerOptionsFrame:IsVisible() then
        shouldMonitor = true
    end
    
    -- Track monitoring state changes
    if shouldMonitor and not isMonitoringSettings then
        isMonitoringSettings = true
        Debug("Settings monitoring started - options UI is visible")
    elseif not shouldMonitor and isMonitoringSettings then
        isMonitoringSettings = false
        Debug("Settings monitoring stopped - options UI closed")
    end
    
    -- Only check settings when monitoring is active
    if isMonitoringSettings then
        local currentTime = GetTime()
        if currentTime - lastCheckTime < SETTINGS.settingsCheckInterval then return end
        lastCheckTime = currentTime
        
        if CheckSettingsChanged() then
            Debug("Settings changed - updating icons")
            UpdateAllIcons(true)
        end
    end
end)

-- Handles item movement with delayed refresh
local function HandleItemMovement()
    -- Cancel any existing timer
    if moveUpdateTimer then
        moveUpdateTimer:SetScript("OnUpdate", nil)
        moveUpdateTimer = nil
    end
    
    moveUpdatePending = true
    
    -- Delayed update gives EngBags time to finish its own updates
    moveUpdateTimer = CreateFrame("Frame")
    local elapsed = 0
    moveUpdateTimer:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= 0.2 then
            if moveUpdatePending then
                Debug("Item movement detected - refreshing icons")
                UpdateAllIcons(true)
                moveUpdatePending = false
            end
            moveUpdateTimer:SetScript("OnUpdate", nil)
            moveUpdateTimer = nil
        end
    end)
end

-- Item movement event watcher
local itemMovementFrame = CreateFrame("Frame")
itemMovementFrame:RegisterEvent("ITEM_LOCK_CHANGED")
itemMovementFrame:RegisterEvent("CURSOR_UPDATE")
itemMovementFrame:RegisterEvent("BAG_UPDATE")
itemMovementFrame:SetScript("OnEvent", function()
    if moveUpdatePending then return end
    HandleItemMovement()
end)

-- Retry initialization until successful
local function TryInitialize()
    if not Initialize() then
        local timer = CreateFrame("Frame")
        local elapsed = 0
        timer:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed >= SETTINGS.initRetryDelay then
                TryInitialize()
                timer:SetScript("OnUpdate", nil)
            end
        end)
    end
end

-- Event registration for addon loading
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    local timer = CreateFrame("Frame")
    local elapsed = 0
    timer:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= SETTINGS.initRetryDelay then
            TryInitialize()
            timer:SetScript("OnUpdate", nil)
        end
    end)
end)

-- Try immediate initialization
TryInitialize()