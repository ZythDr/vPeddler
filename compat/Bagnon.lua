-- vPeddler compatibility module for Bagnon (Vanilla 1.12.1)

local _G = getfenv(0)
local debugMode = false
local bagnonLoaded = false
local hookHandlers = {}

-- Delayed initialization frame
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    -- Remove the event so this only runs once
    this:UnregisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Wait briefly after login
    local timer = CreateFrame("Frame")
    timer:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed < 1 then return end
        this:SetScript("OnUpdate", nil)
        
        -- Simple check for Bagnon - either the addon or the UI elements
        local isBagnonPresent = IsAddOnLoaded("Bagnon_Core") or 
                                IsAddOnLoaded("Bagnon") or
                                (_G["BagnonItem1"] ~= nil)
        
        if not isBagnonPresent then
            if vPeddlerDB and vPeddlerDB.debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Bagnon not detected")
            end
            return
        end
        
        -- Mark as loaded
        bagnonLoaded = true
        
        -- Show loading message
        if vPeddlerDB and vPeddlerDB.verboseMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Bagnon integration loaded")
        end
        
        -- Initialize variables
        activeMonitoring = true
        updateThrottle = 0.25
        fastUpdateThrottle = 0.1
        currentThrottle = updateThrottle
        lastUpdateTime = 0
        fastUpdateEndTime = 0
        
        -- Initialize the module
        Initialize()
    end)
end)

-- Get itemInfo (bag, slot, link) from a Bagnon button
local function GetBagnonItemInfo(button)
    if not button then return nil, nil, nil end
    
    -- Try explicit item slot reference stored on button
    if button.bag ~= nil and button.slot ~= nil then
        local link = GetContainerItemLink(button.bag, button.slot)
        return button.bag, button.slot, link
    end
    
    -- Try parent frame ID + button ID
    if button:GetParent() and button:GetID() > 0 then
        local parentID = button:GetParent():GetID()
        if parentID >= 0 then
            local link = GetContainerItemLink(parentID, button:GetID())
            return parentID, button:GetID(), link
        end
    end
    
    return nil, nil, nil
end

-- Check if an item should be marked as vendor trash
local function ShouldMarkAsVendor(link)
    if not link or not vPeddlerDB or not vPeddlerDB.enabled then return false end
    
    local itemId = vPeddler_GetItemId(link)
    if not itemId then return false end
    
    -- Check if manually flagged
    if vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[itemId] then
        return true
    end
    
    return false
end

-- Create a vendor mark icon for a button
local function CreateVendorMark(button)
    if not button or not button:GetName() then return end
    
    -- Clean up existing icon if present
    if button.vPeddlerMark then
        button.vPeddlerMark:Hide()
        button.vPeddlerMark:SetParent(nil)
        button.vPeddlerMark = nil
        button.vPeddlerIcon = nil
    end
    
    -- Create a new mark frame
    local markFrame = CreateFrame("Frame", button:GetName() .. "vPeddlerMark", button)
    
    -- Position settings
    local position = vPeddlerDB and vPeddlerDB.iconPosition or "BOTTOMLEFT"
    local size = vPeddlerDB and vPeddlerDB.iconSize or 16
    
    markFrame:SetWidth(size)
    markFrame:SetHeight(size) 
    markFrame:ClearAllPoints()
    markFrame:SetPoint(position, button, position, 0, 0)
    markFrame:SetFrameLevel(button:GetFrameLevel() + 5)
    
    -- Create the texture
    local iconTex = markFrame:CreateTexture(button:GetName() .. "vPeddlerMarkTex", "OVERLAY")
    iconTex:SetAllPoints(markFrame)
    
    -- Determine which texture to use
    local texturePath = "Interface\\Icons\\INV_Misc_Coin_01"
    if vPeddlerDB and vPeddlerDB.iconTexture == "coins" then
        local textureSize = "16"
        if size >= 23 and size <= 36 then textureSize = "32"
        elseif size > 36 then textureSize = "64" end
        
        if vPeddlerDB and vPeddlerDB.iconOutline then
            texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_outline_" .. textureSize .. ".tga"
        else
            texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_" .. textureSize .. ".tga"
        end
    end
    
    -- Apply the texture
    iconTex:SetTexture(texturePath)
    iconTex:SetAlpha(vPeddlerDB and vPeddlerDB.iconAlpha or 1.0)
    
    -- Store references
    button.vPeddlerMark = markFrame
    button.vPeddlerIcon = iconTex
    
    return markFrame
end

-- Update a single button's vendor mark
local function UpdateButtonMark(button)
    local bag, slot, link = GetBagnonItemInfo(button)
    
    -- Handle case where we couldn't determine bag/slot
    if not bag or not slot or not link then
        if button.vPeddlerMark then 
            button.vPeddlerMark:Hide()
        end
        return false
    end
    
    -- Check if this item should be marked
    local shouldMark = ShouldMarkAsVendor(link)
    
    -- Check if icon state needs to change
    local currentlyMarked = button.vPeddlerMark and button.vPeddlerMark:IsShown()
    
    if shouldMark ~= currentlyMarked then
        -- State needs to change!
        if shouldMark then
            -- Create mark if needed
            if not button.vPeddlerMark then
                CreateVendorMark(button)
            end
            
            -- Show the mark
            button.vPeddlerMark:Show()
        elseif button.vPeddlerMark then
            -- Hide the mark
            button.vPeddlerMark:Hide()
        end
        return true -- State changed
    end
    
    return false -- No change needed
end

-- Process all the BagnonItem buttons
function UpdateAllBagnonButtons()
    local buttonCount = 0
    local markedCount = 0
    local changedCount = 0
    
    -- Process all known BagnonItem buttons
    for i = 1, 120 do
        local buttonName = "BagnonItem" .. i
        local button = getglobal(buttonName)
        
        if button and button:IsVisible() then
            buttonCount = buttonCount + 1
            
            -- Update and track if icon state changed
            if UpdateButtonMark(button) then
                changedCount = changedCount + 1
            end
            
            -- Count if marked
            if button.vPeddlerMark and button.vPeddlerMark:IsShown() then
                markedCount = markedCount + 1
            end
        end
    end
    
    if debugMode and (changedCount > 0) then
        Debug("Processed " .. buttonCount .. " buttons, marked " .. markedCount .. 
              ", changed " .. changedCount .. " icons")
    end
end

-- Temporarily enable fast update mode
function EnableFastUpdateMode(duration)
    duration = duration or 1.0  -- Default to 1 second of fast updates
    fastUpdateEndTime = GetTime() + duration
    currentThrottle = fastUpdateThrottle
    lastUpdateTime = 0  -- Force immediate update
end

-- Check if any buttons need updating due to changes
function CheckForButtonUpdates()
    -- Check if fast update mode should end
    if fastUpdateEndTime > 0 and GetTime() > fastUpdateEndTime then
        fastUpdateEndTime = 0
        currentThrottle = updateThrottle
    end
    
    -- Check if throttle time has elapsed
    if GetTime() - lastUpdateTime < currentThrottle then
        return -- Too soon since last update
    end
    
    -- Update all visible buttons
    UpdateAllBagnonButtons()
    lastUpdateTime = GetTime()
end

-- Update all button appearance settings including position
function UpdateButtonAppearance()
    -- Process all BagnonItem buttons
    for i = 1, 120 do
        local buttonName = "BagnonItem" .. i
        local button = getglobal(buttonName)
        
        if button and button.vPeddlerMark then
            local markFrame = button.vPeddlerMark
            local iconTex = button.vPeddlerIcon
            
            -- Update position
            local position = vPeddlerDB and vPeddlerDB.iconPosition or "BOTTOMLEFT"
            local size = vPeddlerDB and vPeddlerDB.iconSize or 16
            
            markFrame:SetWidth(size)
            markFrame:SetHeight(size)
            markFrame:ClearAllPoints()
            markFrame:SetPoint(position, button, position, 0, 0)
            
            -- Update texture
            local texturePath = "Interface\\Icons\\INV_Misc_Coin_01"
            if vPeddlerDB and vPeddlerDB.iconTexture == "coins" then
                local textureSize = "16"
                if size >= 23 and size <= 36 then textureSize = "32"
                elseif size > 36 then textureSize = "64" end
                
                if vPeddlerDB and vPeddlerDB.iconOutline then
                    texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_outline_" .. textureSize .. ".tga"
                else
                    texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_" .. textureSize .. ".tga"
                end
            end
            
            iconTex:SetTexture(texturePath)
            iconTex:SetAlpha(vPeddlerDB and vPeddlerDB.iconAlpha or 1.0)
        end
    end
    
    lastUpdateTime = 0
end

-- Create the active monitoring system
function SetupActiveMonitoring()
    local monitorFrame = CreateFrame("Frame")
    local elapsed = 0
    
    monitorFrame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        
        if elapsed >= currentThrottle then
            elapsed = 0
            CheckForButtonUpdates()
        end
    end)
end

-- Hook into vPeddler settings changes
function HookIntovPeddler()
    -- Hook option setter
    if not hookHandlers.vPeddlerOptions and vPeddler.OnOptionSet then
        local origOnOptionSet = vPeddler.OnOptionSet
        vPeddler.OnOptionSet = function(option, value)
            origOnOptionSet(option, value)
            
            -- Update for visual changes
            if option == "iconPosition" or
               option == "iconSize" or
               option == "iconTexture" or
               option == "iconOutline" or
               option == "iconAlpha" then
                UpdateButtonAppearance()
            else
                lastUpdateTime = 0
                EnableFastUpdateMode(1.0)
            end
        end
        hookHandlers.vPeddlerOptions = true
    end
    
    -- Hook item flagging function
    if vPeddler_OnFlagItem and not hookHandlers.vPeddlerFlagging then
        local origOnFlagItem = vPeddler_OnFlagItem
        vPeddler_OnFlagItem = function(itemId, flag)
            origOnFlagItem(itemId, flag)
            EnableFastUpdateMode(1.0)
        end
        hookHandlers.vPeddlerFlagging = true
    end
    
    -- Hook directly into the icon position change function
    if vPeddlerOptions_IconPositionChange and not hookHandlers.vPeddlerPositionChange then
        local origFunction = vPeddlerOptions_IconPositionChange
        vPeddlerOptions_IconPositionChange = function(position)
            origFunction(position)
            
            -- Add a small delay to allow the setting to be saved
            local timer = CreateFrame("Frame")
            local delay = 0
            timer:SetScript("OnUpdate", function()
                delay = delay + arg1
                if delay >= 0.1 then
                    UpdateButtonAppearance()
                    EnableFastUpdateMode(0.5)
                    timer:SetScript("OnUpdate", nil)
                end
            end)
        end
        hookHandlers.vPeddlerPositionChange = true
    end
    
    -- Hook size change function
    if vPeddlerOptions_IconSizeChanged and not hookHandlers.IconSizeChanged then
        local origFunction = vPeddlerOptions_IconSizeChanged
        vPeddlerOptions_IconSizeChanged = function()
            origFunction()
            UpdateButtonAppearance()
        end
        hookHandlers.IconSizeChanged = true
    end
    
    -- Hook alpha change function
    if vPeddlerOptions_IconAlphaChanged and not hookHandlers.IconAlphaChanged then
        local origFunction = vPeddlerOptions_IconAlphaChanged
        vPeddlerOptions_IconAlphaChanged = function()
            origFunction()
            UpdateButtonAppearance()
        end
        hookHandlers.IconAlphaChanged = true
    end
    
    -- Hook outline toggle function
    if vPeddlerOptions_OutlineToggle and not hookHandlers.OutlineToggle then
        local origFunction = vPeddlerOptions_OutlineToggle
        vPeddlerOptions_OutlineToggle = function()
            origFunction()
            UpdateButtonAppearance()
        end
        hookHandlers.OutlineToggle = true
    end
    
    -- Hook style toggle function
    if vPeddlerOptions_IconStyleToggle and not hookHandlers.IconStyleToggle then
        local origFunction = vPeddlerOptions_IconStyleToggle
        vPeddlerOptions_IconStyleToggle = function()
            origFunction()
            UpdateButtonAppearance()
        end
        hookHandlers.IconStyleToggle = true
    end
end

-- Set up event monitoring
function SetupEventMonitoring()
    local eventFrame = CreateFrame("Frame")
    
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")
    eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    
    eventFrame:SetScript("OnEvent", function()
        if event == "ITEM_LOCK_CHANGED" then
            EnableFastUpdateMode(1.5)
        else
            lastUpdateTime = 0
        end
    end)
end

-- Helper function for debug messages
local function Debug(msg)
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler Bagnon:|r " .. msg)
    end
end

-- Initialize the module
function Initialize()
    -- Set up hooks and monitoring
    HookIntovPeddler()
    SetupEventMonitoring()
    
    -- Set up active monitoring
    if activeMonitoring then
        SetupActiveMonitoring()
    end
    
    -- Force initial update
    lastUpdateTime = 0
    
    -- Use conditional message instead of Debug function
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler Bagnon:|r Module initialized!")
    end
end