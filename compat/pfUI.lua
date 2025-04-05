-- vPeddler compatibility module for pfUI
local _G = getfenv(0)

-- Create a frame to delay initialization until after all addons are loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    -- Remove the event so this only runs once
    this:UnregisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Wait 1 second after login for all addons to fully initialize
    local timer = CreateFrame("Frame")
    timer:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed < 1 then return end
        this:SetScript("OnUpdate", nil)
        
        -- Check if pfUI addon is loaded
        if not IsAddOnLoaded("pfUI") then
            if vPeddlerDB and vPeddlerDB.debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: pfUI addon not detected, module not loaded")
            end
            return
        end
        
        if vPeddlerDB and vPeddlerDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: pfUI module loaded")
        end
        
        -- Make sure vPeddler is loaded
        if not vPeddlerDB then return end

        local vPeddler = _G.vPeddler
        if not vPeddler then return end

        -- Set up module
        local module = {}
        vPeddler.compatModules = vPeddler.compatModules or {}
        vPeddler.compatModules["pfUI"] = module

        -- Module configuration
        local debugMode = vPeddlerDB.debug or false
        local updateThrottle = 0.5  -- Update every 0.5 seconds
        local elapsedTime = 0
        local buttonCache = {}      -- Cache of hooked buttons

        -- Debug function
        local function Debug(msg)
            if debugMode then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler pfUI:|r " .. msg)
            end
        end

        -- Get item ID from link
        local function GetItemId(link)
            if not link then return nil end
            
            local _, _, id = string.find(link, "item:(%d+):")
            if not id then
                _, _, id = string.find(link, "item:(%d+)")
            end
            if not id then return nil end
            
            return tonumber(id)
        end

        -- Function to check if an item should be sold
        local function ShouldSellItem(link)
            if not link or not vPeddlerDB or not vPeddlerDB.enabled then 
                return false 
            end
            
            local itemId = GetItemId(link)
            if not itemId then return false end
            
            -- Check if manually flagged
            if vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[itemId] then
                return true
            end
            
            -- Check if gray quality and should be sold
            local _, _, quality = GetItemInfo(link)
            if quality == 0 and vPeddlerDB.autoFlagGrays then
                return true
            end
            
            return false
        end

        -- Parse bag and slot from button name
        local function ParseButtonInfo(button)
            if not button or not button:GetName() then return nil, nil end
            
            local name = button:GetName()
            local bagID, slotID
            
            -- Handle main bank format (pfBag-1item#)
            if string.find(name, "pfBag%-1") then
                bagID = -1
                local _, _, id = string.find(name, "item(%d+)")
                slotID = id and tonumber(id)
            else
                -- Handle regular bag format (pfBag#item#)
                local _, _, bagMatch = string.find(name, "pfBag(%d+)")
                if bagMatch then
                    bagID = tonumber(bagMatch)
                    local _, _, id = string.find(name, "item(%d+)")
                    slotID = id and tonumber(id)
                end
            end
            
            return bagID, slotID
        end
        
        -- Process item flagging/unflagging
        local function ProcessVPeddlerItemClick(link)
            if not link then return end
            
            local itemId = GetItemId(link)
            if not itemId then return end
            
            -- Toggle flag status
            vPeddlerDB.flaggedItems = vPeddlerDB.flaggedItems or {}
            
            if vPeddlerDB.flaggedItems[itemId] then
                -- Item is currently flagged, unflag it
                vPeddlerDB.flaggedItems[itemId] = nil
                
                -- Output if verbose mode is enabled
                if vPeddlerDB.verboseMode then
                    local name = GetItemInfo(link)
                    if name then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Removed " .. name .. " from auto-sell list")
                    end
                end
            else
                -- Item is not flagged, flag it
                vPeddlerDB.flaggedItems[itemId] = true
                
                -- Output if verbose mode is enabled
                if vPeddlerDB.verboseMode then
                    local name = GetItemInfo(link)
                    if name then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Added " .. name .. " to auto-sell list")
                    end
                end
            end
            
            -- Force an immediate update
            module:UpdateAllButtons(true)
        end

        -- Scan for all pfUI buttons (bags and bank)
        function module:FindButtons()
            local foundCount = 0
            
            -- Look for all possible buttons in all containers
            -- Player bags (0-4)
            for bag = 0, 4 do
                for slot = 1, 36 do -- pfUI supports up to 36 slots per bag
                    local frameName = "pfBag" .. bag .. "item" .. slot
                    local frame = _G[frameName]
                    if frame then
                        if not buttonCache[frame] then
                            self:HookButton(frame)
                            foundCount = foundCount + 1
                        end
                    end
                end
            end
            
            -- Bank main container (-1)
            for slot = 1, 28 do
                local frameName = "pfBag-1item" .. slot
                local frame = _G[frameName]
                if frame then
                    if not buttonCache[frame] then
                        self:HookButton(frame)
                        foundCount = foundCount + 1
                    end
                end
            end
            
            -- Bank bags (5-11)
            for bag = 5, 11 do
                for slot = 1, 36 do
                    local frameName = "pfBag" .. bag .. "item" .. slot
                    local frame = _G[frameName]
                    if frame then
                        if not buttonCache[frame] then
                            self:HookButton(frame)
                            foundCount = foundCount + 1
                        end
                    end
                end
            end
            
            if foundCount > 0 and debugMode then
                Debug("Found " .. foundCount .. " new buttons")
            end
            
            return foundCount
        end

        -- Hook a button with our click handler and prepare for icons
        function module:HookButton(button)
            if not button or buttonCache[button] then return end
            
            -- Create texture for vendor icon (using OVERLAY level 7 for highest visibility)
            local tex = button:CreateTexture(nil, "OVERLAY", nil, 7)
            button.vPeddlerTex = tex
            tex:Hide()
            
            -- Apply texture visually
            tex:SetTexture("Interface\\AddOns\\vPeddler\\textures\\Peddler_16.tga")
            tex:SetWidth(16)
            tex:SetHeight(16)
            tex:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
            
            -- Cache the original OnClick handler
            button.vPeddlerOrigClick = button:GetScript("OnClick")
            
            -- Add our click handler
            button:SetScript("OnClick", function()
                -- Check for modifier+right click to flag/unflag items
                if arg1 == "RightButton" then
                    local modKey = string.lower(vPeddlerDB.modifierKey or "alt")
                    local modPressed = false
                    
                    if (modKey == "alt" and IsAltKeyDown()) or
                       (modKey == "ctrl" and IsControlKeyDown()) or
                       (modKey == "shift" and IsShiftKeyDown()) or
                       (modKey == "none") then
                        modPressed = true
                    end
                    
                    if modPressed then
                        local bagID, slotID = ParseButtonInfo(button)
                        if bagID and slotID then
                            local link = GetContainerItemLink(bagID, slotID)
                            if link then
                                -- Process flagging/unflagging
                                ProcessVPeddlerItemClick(link)
                                return
                            end
                        end
                    end
                end
                
                -- Call original handler if not our function
                if button.vPeddlerOrigClick then
                    button.vPeddlerOrigClick()
                end
            end)
            
            -- Add to our cache
            buttonCache[button] = true
            
            return button
        end

        -- Update a single button's icon
        function module:UpdateButton(button)
            if not button or not button.vPeddlerTex then return end
            
            local bagID, slotID = ParseButtonInfo(button)
            if not bagID or not slotID then
                button.vPeddlerTex:Hide()
                return
            end
            
            local link = GetContainerItemLink(bagID, slotID)
            if not link then
                button.vPeddlerTex:Hide()
                return
            end
            
            -- Check if item should be marked
            if ShouldSellItem(link) then
                -- Apply settings
                local size = vPeddlerDB.iconSize or 16
                local alpha = vPeddlerDB.iconAlpha or 1.0
                local position = vPeddlerDB.iconPosition or "TOPRIGHT"
                
                -- Clear and set position
                button.vPeddlerTex:ClearAllPoints()
                button.vPeddlerTex:SetPoint(position, button, position, 0, 0)
                
                -- Apply size and alpha
                button.vPeddlerTex:SetWidth(size)
                button.vPeddlerTex:SetHeight(size)
                button.vPeddlerTex:SetAlpha(alpha)
                
                -- Get the correct texture
                local texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_16.tga"
                
                if vPeddlerDB.iconTexture then
                    if vPeddlerDB.iconTexture == "coins" then
                        local textureSize = "16"
                        if size >= 36 then
                            textureSize = "64"
                        elseif size >= 23 then
                            textureSize = "32"
                        end
                        
                        local outlinePrefix = ""
                        if vPeddlerDB.iconOutline then
                            outlinePrefix = "outline_"
                        end
                        
                        texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_" .. 
                            outlinePrefix .. textureSize .. ".tga"
                    elseif vPeddlerDB.iconTexture == "goldcoin" then
                        texturePath = "Interface\\Icons\\INV_Misc_Coin_01"
                    elseif type(vPeddlerDB.iconTexture) == "string" then
                        texturePath = vPeddlerDB.iconTexture
                    end
                end
                
                -- Apply texture and show
                button.vPeddlerTex:SetTexture(texturePath)
                button.vPeddlerTex:Show()
            else
                -- Hide icon if item shouldn't be marked
                button.vPeddlerTex:Hide()
            end
        end

        -- Update all buttons
        function module:UpdateAllButtons(force)
            -- Find any new buttons first
            self:FindButtons()
            
            -- Update all buttons in cache
            local updated = 0
            for button in pairs(buttonCache) do
                self:UpdateButton(button)
                updated = updated + 1
            end
            
            if updated > 0 and debugMode then
                Debug("Updated " .. updated .. " buttons" .. (force and " (forced)" or ""))
            end
        end
        
        -- Hook into vPeddler_OnFlagItem to catch direct flagging
        if not vPeddler.pfUI_OnFlagItemHooked then
            -- Store original function if it exists
            vPeddler.pfUI_OrigOnFlagItem = vPeddler_OnFlagItem
            
            -- Create new function
            vPeddler_OnFlagItem = function(itemId, flagged)
                -- Call original if it exists
                if vPeddler.pfUI_OrigOnFlagItem then
                    vPeddler.pfUI_OrigOnFlagItem(itemId, flagged)
                end
                
                -- Force our update
                if module and module.UpdateAllButtons then
                    Debug("Item flag changed via vPeddler_OnFlagItem - updating buttons")
                    module:UpdateAllButtons(true)
                end
            end
            
            vPeddler.pfUI_OnFlagItemHooked = true
            Debug("Hooked vPeddler_OnFlagItem function")
        end
        
        -- Initialize the update frame for continuous updates
        local updateFrame = CreateFrame("Frame")
        updateFrame:SetScript("OnUpdate", function()
            -- Throttled updates
            elapsedTime = elapsedTime + arg1
            if elapsedTime >= updateThrottle then
                module:UpdateAllButtons()
                elapsedTime = 0
            end
        end)
        
        -- Register for events
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("BAG_UPDATE")
        eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
        eventFrame:RegisterEvent("BANKFRAME_OPENED")
        eventFrame:RegisterEvent("BANKFRAME_CLOSED")
        eventFrame:RegisterEvent("PLAYER_MONEY")
        eventFrame:RegisterEvent("MERCHANT_SHOW")
        eventFrame:RegisterEvent("MERCHANT_CLOSED")
        
        eventFrame:SetScript("OnEvent", function()
            if debugMode then
                Debug("Event triggered: " .. event)
            end
            
            -- Force immediate update for these events
            if event == "BANKFRAME_OPENED" or event == "BAG_UPDATE" or 
               event == "PLAYERBANKSLOTS_CHANGED" or event == "MERCHANT_CLOSED" then
                module:UpdateAllButtons(true)
            end
        end)
        
        -- Add debug commands to global space
        _G["VPEDDLER_PFUI_DEBUG"] = {
            ToggleDebug = function() 
                debugMode = not debugMode
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler pfUI:|r Debug mode " .. (debugMode and "enabled" or "disabled"))
            end,
            ForceUpdate = function()
                module:UpdateAllButtons(true)
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler pfUI:|r Forced full button update")
            end,
            Analyze = function()
                Debug("Analyzing pfUI buttons...")
                local bagCount, bankCount, bankBagCount = 0, 0, 0
                
                -- Count by type
                for button in pairs(buttonCache) do
                    local name = button:GetName() or "unnamed"
                    local bagID, slotID = ParseButtonInfo(button)
                    
                    if bagID == -1 then
                        bankCount = bankCount + 1
                    elseif bagID and bagID >= 5 then
                        bankBagCount = bankBagCount + 1
                    else
                        bagCount = bagCount + 1
                    end
                    
                    -- Print details for a few buttons of each type
                    if (bagID == 0 and slotID <= 2) or 
                       (bagID == -1 and slotID <= 2) or 
                       (bagID == 5 and slotID <= 2) then
                        
                        local link = bagID and slotID and GetContainerItemLink(bagID, slotID) or "none"
                        local shouldMark = link ~= "none" and ShouldSellItem(link) or false
                        DEFAULT_CHAT_FRAME:AddMessage("Button: " .. name .. 
                                                     " (Bag: " .. tostring(bagID) .. 
                                                     ", Slot: " .. tostring(slotID) .. 
                                                     ") - Should mark: " .. tostring(shouldMark) .. 
                                                     ", Icon shown: " .. tostring(button.vPeddlerTex and button.vPeddlerTex:IsShown() or false))
                    end
                end
                
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler pfUI:|r Found " .. bagCount .. " bag buttons, " .. 
                                           bankCount .. " bank buttons, " .. 
                                           bankBagCount .. " bank bag buttons")
            end
        }
        
        -- Force an initial update
        module:UpdateAllButtons(true)
        
        -- Show initialization message if in debug mode
        if debugMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler pfUI:|r Initialized with continuous update functionality")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler pfUI:|r Use /run VPEDDLER_PFUI_DEBUG.ToggleDebug() to toggle debug mode")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler pfUI:|r Use /run VPEDDLER_PFUI_DEBUG.ForceUpdate() to force an update")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler pfUI:|r Use /run VPEDDLER_PFUI_DEBUG.Analyze() to analyze buttons")
        end
    end)
end)