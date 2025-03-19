-- vPeddler compatibility module for pfUI (Vanilla 1.12.1)

local _G = getfenv(0)
local debugMode = false

-- Check if higher priority bag addons are loaded first
local function CheckForPriorityAddons()
    -- List of addons that take priority over pfUI
    local priorityAddons = {
        -- Format: [addon name] = {load check function, display name}
        ["SUCC-bag"] = {
            function() 
                return IsAddOnLoaded("SUCC-bag") or
                       IsAddOnLoaded("SUCC-Bag") or
                       (_G["SUCC_bag"] ~= nil)
            end,
            "SUCC-bag"
        },
        ["EngBags"] = {
            function() 
                return IsAddOnLoaded("EngBags") or
                       (_G["EngInventory_frame"] ~= nil)
            end,
            "EngBags"
        },
        ["Bagnon"] = {
            function() 
                return IsAddOnLoaded("Bagnon_Core") or
                       IsAddOnLoaded("Bagnon") or
                       (_G["BagnonItem1"] ~= nil)
            end,
            "Bagnon"
        },
        ["BagShui"] = {
            function() 
                return IsAddOnLoaded("BagShui") or
                       (_G["BagShuiBag1"] ~= nil)
            end,
            "BagShui"
        }
    }
    
    -- Check each priority addon
    for addonKey, addonData in pairs(priorityAddons) do
        local checkFunc = addonData[1]
        local displayName = addonData[2]
        
        -- If the addon is loaded, return its name
        if checkFunc() then
            return displayName
        end
    end
    
    -- No priority addons found
    return nil
end

-- Check if pfUI is loaded
local function IsPfUILoaded()
    -- Try multiple detection methods
    if IsAddOnLoaded("pfUI") then return true end
    if _G["pfUI"] ~= nil then return true end
    
    -- Check for key pfUI frames/components
    if _G["pfBag1"] ~= nil then return true end
    if _G["pfContainer"] ~= nil then return true end
    
    return false
end

-- Create a frame to delay initialization until after all addons are loaded
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
        
        -- First check if a higher priority addon is loaded
        local priorityAddon = CheckForPriorityAddons()
        if priorityAddon then
            if vPeddlerDB and vPeddlerDB.debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: " .. priorityAddon .. 
                                             " detected, skipping pfUI integration")
            end
            return
        end
        
        -- Now check if pfUI is loaded
        if not IsPfUILoaded() then
            if vPeddlerDB and vPeddlerDB.debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: pfUI not detected")
            end
            return
        end
        
        -- Show loading message
        if vPeddlerDB and vPeddlerDB.verboseMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: pfUI integration loaded")
        end
        
        -- Make sure vPeddler is loaded
        if not vPeddlerDB then 
            return 
        end

        local vPeddler = _G.vPeddler
        if not vPeddler then return end

        -- Set up module
        local module = {}
        vPeddler.compatModules = vPeddler.compatModules or {}
        vPeddler.compatModules["pfUI"] = module

        -- Continue with rest of module initialization
        -- Enhanced implementation that adds vendor icons to pfUI bag slots

        local addonName = "vPeddler pfUI"
        local updateDelay = 0.2 -- Update interval in seconds
        local nextUpdateTime = 0
        local pendingUpdate = false
        local iconCache = {} -- Cache to track icon state

        -- Simple debug function
        local function Debug(msg)
            if not debugMode then return end
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33" .. addonName .. ":|r " .. msg)
        end

        -- Enhanced version of ForceFullIconRefresh with better texture handling
        local function ForceFullIconRefresh()
            -- Mark for update
            iconCache = {}
            pendingUpdate = true
            nextUpdateTime = 0
            
            -- Debug current settings
            if debugMode and vPeddlerDB then
                Debug("Current settings - Texture: " .. tostring(vPeddlerDB.iconTexture) .. 
                    ", Outline: " .. tostring(vPeddlerDB.iconOutline) ..
                    ", Size: " .. tostring(vPeddlerDB.iconSize))
            end
            
            -- Update existing icons immediately
            if pfUI and pfUI.bag then
                for bagID = 0, 4 do
                    local numSlots = GetContainerNumSlots(bagID)
                    for slotID = 1, numSlots do
                        local buttonName = "pfBag" .. bagID .. "item" .. slotID
                        local button = getglobal(buttonName)
                        
                        if button and button.vPeddlerFrame and button.vPeddlerIcon then
                            -- Update existing icons' appearance regardless of whether item should be marked
                            local position = vPeddlerDB and vPeddlerDB.iconPosition or "BOTTOMLEFT"
                            local size = vPeddlerDB and vPeddlerDB.iconSize or 16
                            local alpha = vPeddlerDB and vPeddlerDB.iconAlpha or 1.0
                            
                            button.vPeddlerFrame:ClearAllPoints()
                            button.vPeddlerFrame:SetPoint(position, button, position, 0, 0)
                            button.vPeddlerFrame:SetWidth(size)
                            button.vPeddlerFrame:SetHeight(size)
                            
                            -- Improved texture path calculation
                            local texturePath = "Interface\\Icons\\INV_Misc_Coin_01"
                            if vPeddlerDB and vPeddlerDB.iconTexture == "coins" then
                                local textureSize = size >= 36 and "64" or (size >= 23 and "32" or "16")
                                local outlinePrefix = ""
                                
                                if vPeddlerDB.iconOutline then
                                    outlinePrefix = "outline_"
                                end
                                
                                texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_" .. 
                                    outlinePrefix .. textureSize .. ".tga"
                                    
                                if debugMode then
                                    Debug("Setting texture path: " .. texturePath)
                                end
                            end
                            
                            button.vPeddlerIcon:SetTexture(texturePath)
                            button.vPeddlerIcon:SetAlpha(alpha)
                        end
                    end
                end
            end
            
            Debug("Forcing complete icon refresh with appearance update")
        end

        -- Check if an item should be marked for vendor selling
        local function ShouldMarkItem(link)
            if not link or not vPeddlerDB or not vPeddlerDB.enabled then return false end
            
            local itemId = vPeddler_GetItemId(link)
            if not itemId then return false end
            
            itemId = tonumber(itemId)
            
            -- Check if item is specifically flagged
            if vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[itemId] then
                return true
            end
            
            -- Quality-based auto-selling
            local _, _, quality = GetItemInfo(link)
            if quality and vPeddlerDB.ignoreQuality and vPeddlerDB.ignoreQuality[quality] then
                return true
            end
            
            return false
        end

        -- Create or update vendor badge on a button
        local function UpdateButtonIcon(button, show)
            if not button or not button:GetName() then return end
            
            -- Create frame for our icon if it doesn't exist
            if not button.vPeddlerFrame then
                local frameName = button:GetName() .. "VendorIcon"
                button.vPeddlerFrame = CreateFrame("Frame", frameName, button)
                button.vPeddlerIcon = button.vPeddlerFrame:CreateTexture(frameName .. "Texture", "OVERLAY")
                button.vPeddlerIcon:SetAllPoints(button.vPeddlerFrame)
            end
            
            -- Store current state in cache
            iconCache[button:GetName()] = show
            
            -- Hide if not showing
            if not show then
                button.vPeddlerFrame:Hide()
                return
            end
            
            -- Update position based on settings
            local position = vPeddlerDB and vPeddlerDB.iconPosition or "BOTTOMLEFT"
            local size = vPeddlerDB and vPeddlerDB.iconSize or 16
            local alpha = vPeddlerDB and vPeddlerDB.iconAlpha or 1.0
            
            button.vPeddlerFrame:ClearAllPoints()
            button.vPeddlerFrame:SetPoint(position, button, position, 0, 0)
            button.vPeddlerFrame:SetWidth(size)
            button.vPeddlerFrame:SetHeight(size)
            
            -- Update texture based on settings
            local texturePath = "Interface\\Icons\\INV_Misc_Coin_01"
            if vPeddlerDB and vPeddlerDB.iconTexture == "coins" then
                local textureSize = size >= 36 and "64" or (size >= 23 and "32" or "16")
                texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_" .. 
                    (vPeddlerDB.iconOutline and "outline_" or "") .. textureSize .. ".tga"
            end
            
            button.vPeddlerIcon:SetTexture(texturePath)
            button.vPeddlerIcon:SetAlpha(alpha)
            
            -- Show the icon
            button.vPeddlerFrame:Show()
        end

        -- Schedule an update to occur on the next update tick
        local function ScheduleUpdate()
            pendingUpdate = true
        end

        -- Process the update if it's time
        local function ProcessUpdate()
            local currentTime = GetTime()
            
            -- Only update if enough time has passed since the last update
            if currentTime < nextUpdateTime then
                return
            end
            
            -- Reset flags
            pendingUpdate = false
            nextUpdateTime = currentTime + updateDelay
            
            -- Only update if pfUI is loaded
            if not pfUI or not pfUI.bag then return end
            
            local count = 0
            local changed = 0
            
            -- Loop through bags and slots
            for bagID = 0, 4 do
                local numSlots = GetContainerNumSlots(bagID)
                for slotID = 1, numSlots do
                    local buttonName = "pfBag" .. bagID .. "item" .. slotID
                    local button = getglobal(buttonName)
                    
                    if button then
                        local link = GetContainerItemLink(bagID, slotID)
                        local shouldMark = link and ShouldMarkItem(link) or false
                        
                        -- Check if state has changed
                        if iconCache[buttonName] ~= shouldMark then
                            UpdateButtonIcon(button, shouldMark)
                            changed = changed + 1
                        end
                        
                        if shouldMark then
                            count = count + 1
                        end
                    end
                end
            end
            
            if changed > 0 then
                Debug("Updated " .. count .. " buttons with icons (" .. changed .. " changed)")
            end
        end

        -- Hook into vPeddler settings changes
        local function HookVPeddlerSettings()
            -- Only hook once
            if vPeddler.pfui_settings_hooked then return end
            
            -- Hook into OnOptionSet (this is the key function for all settings changes)
            if vPeddler.OnOptionSet then
                local originalOptionSet = vPeddler.OnOptionSet
                vPeddler.OnOptionSet = function(option, value)
                    -- Call original function
                    originalOptionSet(option, value)
                    
                    Debug("Option changed: " .. option .. " - Refreshing icons")
                    ForceFullIconRefresh()
                end
                vPeddler.pfui_settings_hooked = true
                Debug("Successfully hooked vPeddler settings")
            end
            
            -- Hook slash command to catch GUI interactions
            if SlashCmdList["VPEDDLER"] then
                local originalCmd = SlashCmdList["VPEDDLER"]
                SlashCmdList["VPEDDLER"] = function(msg)
                    originalCmd(msg)
                    
                    -- Short delay to allow GUI to update settings
                    local timer = CreateFrame("Frame")
                    local waiting = 0
                    timer:SetScript("OnUpdate", function()
                        waiting = waiting + arg1
                        if waiting > 0.1 then
                            ForceFullIconRefresh()
                            timer:SetScript("OnUpdate", nil)
                        end
                    end)
                end
                Debug("Successfully hooked slash command")
            end
        end

        -- More comprehensive hooks into vPeddler flagging functions
        local function HookVPeddlerFunctions()
            if not vPeddler then return end
            
            -- Hook AddItemToSellList
            if vPeddler.AddItemToSellList and not vPeddler.pfui_add_hooked then
                local originalAdd = vPeddler.AddItemToSellList
                vPeddler.AddItemToSellList = function(self, itemId)
                    originalAdd(self, itemId)
                    Debug("Item " .. itemId .. " added to sell list")
                    ForceFullIconRefresh() -- Force a full refresh instead of just scheduling
                end
                vPeddler.pfui_add_hooked = true
                Debug("Successfully hooked AddItemToSellList")
            end
            
            -- Hook RemoveItemFromSellList
            if vPeddler.RemoveItemFromSellList and not vPeddler.pfui_remove_hooked then
                local originalRemove = vPeddler.RemoveItemFromSellList
                vPeddler.RemoveItemFromSellList = function(self, itemId)
                    originalRemove(self, itemId)
                    Debug("Item " .. itemId .. " removed from sell list")
                    ForceFullIconRefresh() -- Force a full refresh instead of just scheduling
                end
                vPeddler.pfui_remove_hooked = true
                Debug("Successfully hooked RemoveItemFromSellList")
            end
            
            -- Hook ToggleItemFlag which is often used by UI actions
            if vPeddler.ToggleItemFlag and not vPeddler.pfui_toggle_hooked then
                local originalToggle = vPeddler.ToggleItemFlag
                vPeddler.ToggleItemFlag = function(self, itemId)
                    originalToggle(self, itemId)
                    Debug("Item flag toggled for " .. itemId)
                    ForceFullIconRefresh() -- Force a full refresh
                end
                vPeddler.pfui_toggle_hooked = true
                Debug("Successfully hooked ToggleItemFlag")
            end
        end

        -- Hook into vPeddler's slider controls directly
        local function HookVPeddlerSliders()
            -- Only hook once
            if vPeddler.pfui_sliders_hooked then return end
            
            -- Try to find the icon size slider
            local iconSizeSlider = getglobal("vPeddlerIconSizeSlider")
            if iconSizeSlider and iconSizeSlider:GetScript("OnValueChanged") then
                local originalOnValueChanged = iconSizeSlider:GetScript("OnValueChanged")
                iconSizeSlider:SetScript("OnValueChanged", function()
                    -- Call original handler first
                    originalOnValueChanged()
                    
                    -- Now update our icons with a slight delay to allow settings to save
                    local sliderTimer = CreateFrame("Frame")
                    local sliderWaiting = 0
                    sliderTimer:SetScript("OnUpdate", function()
                        sliderWaiting = sliderWaiting + arg1
                        if sliderWaiting > 0.1 then
                            Debug("Icon size changed - updating appearance")
                            ForceFullIconRefresh()
                            sliderTimer:SetScript("OnUpdate", nil)
                        end
                    end)
                end)
                Debug("Successfully hooked icon size slider")
            end
            
            -- Try to find the icon alpha slider
            local iconAlphaSlider = getglobal("vPeddlerIconAlphaSlider")
            if iconAlphaSlider and iconAlphaSlider:GetScript("OnValueChanged") then
                local originalAlphaChanged = iconAlphaSlider:GetScript("OnValueChanged")
                iconAlphaSlider:SetScript("OnValueChanged", function()
                    -- Call original handler first
                    originalAlphaChanged()
                    
                    -- Now update our icons with a slight delay
                    local alphaTimer = CreateFrame("Frame")
                    local alphaWaiting = 0
                    alphaTimer:SetScript("OnUpdate", function()
                        alphaWaiting = alphaWaiting + arg1
                        if alphaWaiting > 0.1 then
                            Debug("Icon alpha changed - updating appearance")
                            ForceFullIconRefresh()
                            alphaTimer:SetScript("OnUpdate", nil)
                        end
                    end)
                end)
                Debug("Successfully hooked icon alpha slider")
            end
            
            vPeddler.pfui_sliders_hooked = true
        end

        -- Hook the right-click handler that flags/unflags items
        local function HookContainerRightClick()
            -- Store original function if we haven't already
            if not vPeddler.pfui_original_containerclick and ContainerFrameItemButton_OnClick then
                vPeddler.pfui_original_containerclick = ContainerFrameItemButton_OnClick
                
                -- Replace with our modified version
                ContainerFrameItemButton_OnClick = function(button)
                    local modifierDown = false
                    
                    -- Check if the correct modifier key is held
                    if vPeddlerDB.modifierKey == "ALT" and IsAltKeyDown() then
                        modifierDown = true
                    elseif vPeddlerDB.modifierKey == "CTRL" and IsControlKeyDown() then
                        modifierDown = true
                    elseif vPeddlerDB.modifierKey == "SHIFT" and IsShiftKeyDown() then
                        modifierDown = true
                    end
                    
                    -- If right-clicking with modifier key, capture both before and after
                    if modifierDown and arg1 == "RightButton" then
                        -- Get the current flagged state before calling original function
                        local bag = this:GetParent():GetID()
                        local slot = this:GetID()
                        local link = GetContainerItemLink(bag, slot)
                        
                        if link then
                            local itemId = vPeddler_GetItemId(link)
                            if itemId then
                                -- Call original function
                                vPeddler.pfui_original_containerclick(button)
                                
                                -- Force immediate refresh of pfUI icons
                                Debug("Item flag toggled via right-click - forcing refresh")
                                ForceFullIconRefresh()
                                return
                            end
                        end
                    end
                    
                    -- Default behavior for all other cases
                    vPeddler.pfui_original_containerclick(button)
                end
                
                Debug("Successfully hooked ContainerFrameItemButton_OnClick for pfUI integration")
            end
        end

        -- Create the update frame
        local updateFrame = CreateFrame("Frame")
        updateFrame:SetScript("OnUpdate", function()
            if pendingUpdate then
                ProcessUpdate()
            end
        end)

        -- Hook bag events
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("BAG_UPDATE")
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("MERCHANT_SHOW")
        eventFrame:RegisterEvent("MERCHANT_CLOSED")
        eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
        eventFrame:SetScript("OnEvent", function()
            if event == "ADDON_LOADED" then
                if vPeddlerDB and pfUI then
                    -- Delay to ensure everything is fully initialized
                    local timer = CreateFrame("Frame")
                    local waiting = 0
                    timer:SetScript("OnUpdate", function()
                        waiting = waiting + arg1
                        if waiting > 1.0 then
                            HookVPeddlerSettings()
                            HookVPeddlerSliders()
                            HookVPeddlerFunctions()
                            HookContainerRightClick()
                            ForceFullIconRefresh()
                            timer:SetScript("OnUpdate", nil)
                            -- Don't unregister ADDON_LOADED as it may be needed for reloads
                        end
                    end)
                end
            else
                -- For all other events
                Debug(event .. " detected")
                pendingUpdate = true
                nextUpdateTime = 0
            end
        end)

        -- Only show message if debugMode is enabled
        if vPeddlerDB and vPeddlerDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: pfUI compatibility loaded")
        end
        
        -- Initialize immediately
        ForceFullIconRefresh()
    end)
end)