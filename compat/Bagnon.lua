-- vPeddler compatibility module for Bagnon (Vanilla 1.12.1)

local _G = getfenv(0)
local debugMode = false
local bagnonLoaded = false
local banknonLoaded = false
local hookHandlers = {}

-- Debug function
local function Debug(msg)
    if debugMode or vPeddlerDB and vPeddlerDB.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler-Bagnon:|r " .. tostring(msg))
    end
end

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
        
        -- Simple check for Bagnon and Banknon - either the addon or the UI elements
        local isBagnonPresent = IsAddOnLoaded("Bagnon_Core") or 
                                IsAddOnLoaded("Bagnon") or
                                (_G["BagnonItem1"] ~= nil)
                                
        local isBanknonPresent = IsAddOnLoaded("Banknon") or 
                                (_G["BanknonItem1"] ~= nil)
        
        -- Update debug message to show both addon states
        if vPeddlerDB and vPeddlerDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Bagnon " .. 
                (isBagnonPresent and "found" or "not found") .. ", Banknon " ..
                (isBanknonPresent and "found" or "not found"))
        end
        
        if not isBagnonPresent and not isBanknonPresent then
            return
        end
        
        -- Mark as loaded
        bagnonLoaded = true
        banknonLoaded = isBanknonPresent
        
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
    
    -- Check for bank-specific data first
    if button.bankslot then
        -- Bank slot (fetch using appropriate API)
        local link = GetContainerItemLink(-1, button.bankslot)
        return -1, button.bankslot, link
    end
    
    -- Try explicit item slot reference stored on button
    if button.bag ~= nil and button.slot ~= nil then
        local link = GetContainerItemLink(button.bag, button.slot)
        return button.bag, button.slot, link
    end
    
    -- Try parent frame ID + button ID
    if button:GetParent() and button:GetID() > 0 then
        local parentID = button:GetParent():GetID()
        if parentID >= 0 or parentID == -1 then -- -1 is often used for bank
            local link = GetContainerItemLink(parentID, button:GetID())
            return parentID, button:GetID(), link
        end
    end
    
    return nil, nil, nil
end

-- Special function to get bank item data
function GetBanknonItemInfo(button)
    if not button then return nil, nil, nil end
    
    -- Try bank-specific ID from Banknon
    if button.bankID and button.bankID > 0 then
        local link = GetContainerItemLink(-1, button.bankID)
        return -1, button.bankID, link
    end
    
    -- Try standard bank slot detection
    if button:GetID() > 0 and button:GetParent() and 
       button:GetParent():GetName() and string.find(button:GetParent():GetName(), "Bank") then
        local bankSlot = button:GetID()
        local link = GetContainerItemLink(-1, bankSlot)
        return -1, bankSlot, link
    end
    
    -- Extract from name if possible
    local buttonName = button:GetName() or ""
    local slotNum = tonumber(string.match(buttonName, "(%d+)$"))
    if slotNum and slotNum > 0 then
        local link = GetContainerItemLink(-1, slotNum)
        if link then
            return -1, slotNum, link
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
function UpdateAllBagnonButtons(includeBank)
    local buttonCount = 0
    local markedCount = 0
    local changedCount = 0
    
    -- Process all known BagnonItem buttons (regular bags)
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
    
    -- Process bank buttons if requested
    if includeBank then
        for i = 1, 100 do
            -- Try different possible bank button naming patterns including the correct BanknonItem pattern
            local button = getglobal("BanknonItem" .. i) or
                           getglobal("BagnonBankItem" .. i) or 
                           getglobal("BanknItem" .. i) or
                           getglobal("BagnonItem" .. (i + 100))
            
            if button and button:IsVisible() then
                buttonCount = buttonCount + 1
                
                -- Update bank item
                if UpdateButtonMark(button) then
                    changedCount = changedCount + 1
                end
                
                -- Count if marked
                if button.vPeddlerMark and button.vPeddlerMark:IsShown() then
                    markedCount = markedCount + 1
                end
            end
        end
    end
    
    if debugMode and (changedCount > 0) then
        Debug("Processed " .. buttonCount .. " buttons, marked " .. markedCount .. 
              ", changed " .. changedCount .. " icons")
    end
end

-- Disable the UpdateBankButtons function
function UpdateBankButtons()
    -- This function has been disabled to prevent debug spam
    local buttonCount = 0
    local markedCount = 0
    
    -- Just run ScanBanknonFrames instead which doesn't have debug spam
    ScanBanknonFrames()
    
    return buttonCount, markedCount, 0
end

-- Add a function specifically to update a single button's icon based on itemID
function UpdateBankButtonByItemId(itemId)
    -- Scan all bank buttons to find matching items
    for i = 1, 100 do
        local button = getglobal("BanknonItem" .. i)
        if button and button:IsVisible() then
            local bankSlot = button:GetID()
            if bankSlot and bankSlot > 0 then
                local link = GetContainerItemLink(-1, bankSlot)
                if link then
                    local buttonItemId = vPeddler_GetItemId(link)
                    if buttonItemId and buttonItemId == itemId then
                        -- Check if it should be marked now
                        local shouldMark = vPeddlerDB and vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[itemId]
                        
                        -- Force icon state based on current flag status
                        if shouldMark then
                            if not button.vPeddlerMark then
                                CreateVendorMark(button)
                            end
                            if button.vPeddlerMark then
                                button.vPeddlerMark:Show()
                            end
                        else
                            if button.vPeddlerMark then
                                button.vPeddlerMark:Hide()
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Direct Banknon scanning function - completely rewritten
function ScanBanknonFrames()
    -- Enable debug to see what's happening
    local debugThis = false
    
    -- STEP 1: Remove ALL bank icons to start fresh
    for i = 1, 200 do
        local button = getglobal("BanknonItem" .. i)
        if button and button.vPeddlerMark then
            button.vPeddlerMark:Hide()
            button.vPeddlerMark:SetParent(nil)
            button.vPeddlerMark = nil
        end
    end
    
    -- STEP 2: First scan slots 1-24 (main bank)
    for slot = 1, 24 do
        -- Get the item link for this main bank slot
        local link = GetContainerItemLink(-1, slot)
        
        -- If there's an item in this slot, find its button and mark it
        if link then
            local itemId = vPeddler_GetItemId(link)
            local shouldMark = itemId and vPeddlerDB and vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[itemId]
            
            if shouldMark then
                -- Find the button for this slot
                local button = getglobal("BanknonItem" .. slot)
                
                if button and button:IsVisible() then
                    -- Create mark
                    CreateVendorMark(button)
                    button.vPeddlerMark:Show()
                    
                    -- Save correct bag/slot info
                    button.vPeddlerBagId = -1
                    button.vPeddlerSlotId = slot
                    
                    if debugThis then
                        Debug("Marked main bank slot " .. slot .. " with item ID " .. itemId)
                    end
                end
            end
        end
    end
    
    -- STEP 3: Now scan bank bags (containers 5-11)
    local continousSlotId = 25  -- Banknon seems to use slots 25+ for bank bags
    
    for bagId = 5, 11 do
        local numSlots = GetContainerNumSlots(bagId)
        
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bagId, slot)
            
            if link then
                local itemId = vPeddler_GetItemId(link)
                local shouldMark = itemId and vPeddlerDB and vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[itemId]
                
                if shouldMark then
                    -- Try to find the correct button for this bank bag slot
                    -- We'll try the calculated continuous slot ID first
                    local button = getglobal("BanknonItem" .. continousSlotId)
                    
                    if button and button:IsVisible() then
                        -- Create mark
                        CreateVendorMark(button)
                        button.vPeddlerMark:Show()
                        
                        -- Save correct bag/slot info
                        button.vPeddlerBagId = bagId
                        button.vPeddlerSlotId = slot
                        
                        if debugThis then
                            Debug("Marked bank bag " .. bagId .. " slot " .. slot .. 
                                  " as button " .. continousSlotId .. " with item ID " .. itemId)
                        end
                    end
                end
            end
            
            -- Increment to the next continuous slot ID
            continousSlotId = continousSlotId + 1
        end
    end
    
    -- STEP 4: Set up right-click handling for all bank buttons
    for i = 1, 100 do
        local button = getglobal("BanknonItem" .. i)
        if button and button:IsVisible() and not button.vPeddlerClickHooked then
            -- Set up right-click handling
            SetupBankButtonRightClick(button)
        end
    end
    
    return true
end

-- Helper function to set up right-click handling
function SetupBankButtonRightClick(button)
    -- Save the original OnClick script
    button.vPeddlerOriginalOnClick = button:GetScript("OnClick")
    
    -- Set the new OnClick handler
    button:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            -- Check which modifier key is configured in vPeddler
            local modifierValid = false
            
            if vPeddlerDB.modifierKey == "alt" and IsAltKeyDown() then
                modifierValid = true
            elseif vPeddlerDB.modifierKey == "ctrl" and IsControlKeyDown() then
                modifierValid = true
            elseif vPeddlerDB.modifierKey == "shift" and IsShiftKeyDown() then
                modifierValid = true
            elseif not vPeddlerDB.modifierKey or vPeddlerDB.modifierKey == "none" then
                modifierValid = true
            end
            
            if modifierValid then
                -- Get the item link - try to use stored bag/slot first
                local itemLink
                if this.vPeddlerBagId and this.vPeddlerSlotId then
                    itemLink = GetContainerItemLink(this.vPeddlerBagId, this.vPeddlerSlotId)
                else
                    -- Use button ID as fallback
                    local buttonId = this:GetID()
                    if buttonId <= 24 then
                        itemLink = GetContainerItemLink(-1, buttonId)
                    end
                end
                
                if itemLink then
                    -- Process the click
                    if vPeddler_ProcessItemClick then
                        vPeddler_ProcessItemClick(itemLink)
                    else
                        -- Fallback: Toggle flag status directly
                        local clickedItemId = vPeddler_GetItemId(itemLink)
                        if clickedItemId then
                            local wasFlagged = vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[clickedItemId]
                            vPeddler_SetItemFlag(clickedItemId, not wasFlagged)
                        end
                    end
                    
                    -- Force a rescan after a small delay
                    local timer = CreateFrame("Frame")
                    timer:SetScript("OnUpdate", function()
                        this.elapsed = (this.elapsed or 0) + arg1
                        if this.elapsed < 0.1 then return end
                        timer:SetScript("OnUpdate", nil)
                        ScanBanknonFrames()
                    end)
                    
                    return -- Don't call original handler
                end
            end
        end
        
        -- Not our special click, call original handler
        if button.vPeddlerOriginalOnClick then
            button.vPeddlerOriginalOnClick()
        end
    end)
    
    button.vPeddlerClickHooked = true
end

-- Update the bank event handler
local bankEventFrame = CreateFrame("Frame")
bankEventFrame:RegisterEvent("BANKFRAME_OPENED")
bankEventFrame:SetScript("OnEvent", function()
    -- Run a scan immediately when bank opens
    ScanBanknonFrames()
    
    -- Then scan again after a small delay to ensure all items are loaded
    local timer = CreateFrame("Frame")
    timer:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed < 0.5 then return end
        timer:SetScript("OnUpdate", nil)
        ScanBanknonFrames()
    end)
end)

-- Add PLAYERBANKSLOTS_CHANGED handler
local bankUpdateFrame = CreateFrame("Frame")
bankUpdateFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
bankUpdateFrame:SetScript("OnEvent", function()
    -- Update without any debug output
    ScanBanknonFrames()
end)

-- Replace vPeddler_OnFlagItem hook with direct call to vPeddler_SetItemFlag
if vPeddler_SetItemFlag and not banknonFlagHooked then
    local origSetItemFlag = vPeddler_SetItemFlag
    vPeddler_SetItemFlag = function(itemId, flag)
        -- Call original function
        origSetItemFlag(itemId, flag)
        
        -- Update bank items if bank is open
        if BankFrame and BankFrame:IsVisible() then
            -- First do a focused update
            UpdateBankButtonByItemId(itemId)
            
            -- Then do a complete scan after a slight delay
            local timer = CreateFrame("Frame")
            timer:SetScript("OnUpdate", function()
                this.elapsed = (this.elapsed or 0) + arg1
                if this.elapsed < 0.1 then return end
                timer:SetScript("OnUpdate", nil)
                ScanBanknonFrames()
            end)
        end
    end
    banknonFlagHooked = true
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
            UpdateButtonAppearanceForButton(button)
        end
    end
    
    -- Now also process all BanknonItem buttons
    for i = 1, 100 do
        local buttonName = "BanknonItem" .. i
        local button = getglobal(buttonName)
        
        if button and button.vPeddlerMark then
            UpdateButtonAppearanceForButton(button)
        end
    end
    
    lastUpdateTime = 0
end

-- Helper function to update a single button's appearance
function UpdateButtonAppearanceForButton(button)
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
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("BANKFRAME_CLOSED")
    eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    
    eventFrame:SetScript("OnEvent", function()
        if event == "ITEM_LOCK_CHANGED" then
            EnableFastUpdateMode(1.5)
        elseif event == "BANKFRAME_OPENED" then
            Debug("Bank opened - scanning bank items")
            ScanBanknonFrames()
        elseif event == "PLAYERBANKSLOTS_CHANGED" then
            Debug("Bank slots changed")
            ScanBanknonFrames()
        elseif event == "BANKFRAME_CLOSED" then
            CleanupBankIcons()
        else
            lastUpdateTime = 0
        end
    end)
end

-- Add a new function to clean up bank icons
function CleanupBankIcons()
    Debug("Cleaning up bank icons")
    local cleanCount = 0
    
    -- Check for buttons using Bagnon's bank item naming patterns
    for i = 1, 200 do
        -- Try different possible bank button naming patterns
        local button = getglobal("BanknonItem" .. i)
        
        if button and button.vPeddlerMark then
            button.vPeddlerMark:Hide()
            button.vPeddlerMark:SetParent(nil)
            button.vPeddlerMark = nil
            button.vPeddlerIcon = nil
            cleanCount = cleanCount + 1
        end
    end
    
    Debug("Cleaned up " .. cleanCount .. " bank item icons")
end

-- Create a continuous bank monitoring system that ensures icons stay updated
local bankMonitorFrame = CreateFrame("Frame")
bankMonitorFrame:Hide()  -- Start hidden until bank opens
local bankUpdateThrottle = 0.5  -- Update every half second as suggested

-- Bank monitor update function
bankMonitorFrame:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + arg1
    if this.elapsed < bankUpdateThrottle then return end
    this.elapsed = 0
    
    -- Run the bank scan without debug spam
    ScanBanknonFrames()
end)

-- Update bank event handlers to enable/disable continuous monitoring
local bankEventFrame = CreateFrame("Frame")
bankEventFrame:RegisterEvent("BANKFRAME_OPENED")
bankEventFrame:RegisterEvent("BANKFRAME_CLOSED")
bankEventFrame:SetScript("OnEvent", function()
    if event == "BANKFRAME_OPENED" then
        -- Run a scan immediately when bank opens
        ScanBanknonFrames()
        
        -- Enable continuous monitoring
        bankMonitorFrame.elapsed = 0
        bankMonitorFrame:Show()
        
        -- Then scan again after a small delay to ensure all items are loaded
        local timer = CreateFrame("Frame")
        timer:SetScript("OnUpdate", function()
            this.elapsed = (this.elapsed or 0) + arg1
            if this.elapsed < 0.5 then return end
            timer:SetScript("OnUpdate", nil)
            ScanBanknonFrames()
        end)
    elseif event == "BANKFRAME_CLOSED" then
        -- Disable continuous monitoring when bank closes
        bankMonitorFrame:Hide()
        
        -- Clean up icons
        CleanupBankIcons()
    end
end)

-- Replace the PLAYERBANKSLOTS_CHANGED handler - no longer needed with continuous monitoring
local bankUpdateFrame = CreateFrame("Frame")
bankUpdateFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
bankUpdateFrame:SetScript("OnEvent", function()
    -- Force an immediate update when a bank slot changes
    bankMonitorFrame.elapsed = bankUpdateThrottle  -- Force update on next OnUpdate
end)

-- Initialize the module
function Initialize()
    -- Set up hooks and monitoring
    HookIntovPeddler()
    SetupEventMonitoring()
    
    -- Register bank-specific events
    local bankFrame = CreateFrame("Frame")
    bankFrame:RegisterEvent("BANKFRAME_OPENED")
    bankFrame:RegisterEvent("BANKFRAME_CLOSED")
    bankFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    
    bankFrame:SetScript("OnEvent", function()
        Debug("Bank event: " .. event)
        
        if event == "BANKFRAME_OPENED" then
            local timer = CreateFrame("Frame")
            timer:SetScript("OnUpdate", function()
                this.elapsed = (this.elapsed or 0) + arg1
                if this.elapsed < 0.25 then return end
                timer:SetScript("OnUpdate", nil)
                
                ScanBanknonFrames()
            end)
        elseif event == "PLAYERBANKSLOTS_CHANGED" then
            ScanBanknonFrames()
        end
    end)
    
    if activeMonitoring then
        SetupActiveMonitoring()
    end
    
    lastUpdateTime = 0
    
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler Bagnon:|r Module initialized!")
    end
end