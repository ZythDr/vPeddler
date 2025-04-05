-- vPeddler compatibility module for SUCC-bag
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
        
        -- Now check if the SUCC-bag addon is loaded
        local isSUCCLoaded = IsAddOnLoaded("SUCC-bag") or 
                            IsAddOnLoaded("SUCC-Bag") or
                            IsAddOnLoaded("succ-bag")
        
        if not isSUCCLoaded or not _G["SUCC_bag"] then
            if vPeddlerDB and vPeddlerDB.debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: SUCC-bag addon not detected, module not loaded")
            end
            return
        end
        
        if vPeddlerDB and vPeddlerDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: SUCC-bag module loaded")
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
        vPeddler.compatModules["SUCC-bag"] = module

        -- Cache frequently used functions
        local GetContainerItemLink = GetContainerItemLink
        local GetItemInfo = GetItemInfo
        local pairs = pairs

        -- Module state
        local buttonCache = {}      -- Cache of processed buttons
        local updateDelay = 0       -- Update timer
        local debugMode = false     -- Change from true to false

        -- Debug function
        local function Debug(msg)
            if debugMode then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler SUCC-bag:|r " .. msg)
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
                Debug("Item accepted: " .. link .. " is flagged")
                return true
            end
            
            -- Check if gray quality and should be sold
            local _, _, quality = GetItemInfo(link)
            if quality == 0 and vPeddlerDB.sellGray then
                Debug("Item accepted: " .. link .. " is gray")
                return true
            end
            
            return false
        end

        -- Add a function to check if an item is flagged
        local function IsItemFlagged(itemId)
            if not itemId or not vPeddlerDB or not vPeddlerDB.flaggedItems then
                return false
            end
            return vPeddlerDB.flaggedItems[itemId] == true
        end

        -- Check if SUCC_bag is currently visible
        local function IsBagVisible()
            return SUCC_bag and SUCC_bag:IsVisible()
        end

        -- Check if bank is currently visible - attach to the module
        function module:IsBankVisible()
            return SUCC_bag and SUCC_bag.bank and SUCC_bag.bank:IsVisible()
        end

        -- Around line 70, add this helper function for item flagging
        local function ProcessVPeddlerItemClick(link)
            -- This is a replacement for the missing vPeddler_ProcessItemClick function
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
        end

        -- Find all SUCC_bag buttons
        function module:FindButtons()
            local foundCount = 0
            
            -- Method 1: Standard numeric pattern scanning
            for i = 1, 200 do
                local frameName = "SUCC_bagItem" .. i
                local frame = _G[frameName]
                if frame then
                    if not buttonCache[frame] then
                        self:HookButton(frame)
                        foundCount = foundCount + 1
                    end
                end
            end
            
            if foundCount > 0 then
                Debug("Found " .. foundCount .. " new buttons")
            end
            
            return foundCount
        end

        -- Find all SUCC-bag bank buttons
        function module:FindBankButtons()
            local foundCount = 0
            
            -- Scan for bank items using the SUCC_bagBankItem pattern
            for i = 1, 200 do
                local frameName = "SUCC_bagBankItem" .. i
                local frame = _G[frameName]
                if frame then
                    if not buttonCache[frame] then
                        self:HookButton(frame)
                        foundCount = foundCount + 1
                    end
                end
            end
            
            if foundCount > 0 then
                Debug("Found " .. foundCount .. " new bank buttons")
            end
            
            return foundCount
        end

        -- Hook a single button
        function module:HookButton(button)
            if not button or buttonCache[button] then return end
            
            -- Create texture for vendor icon with proper visibility settings
            local buttonName = button:GetName() or ""
            local isBankButton = string.find(buttonName, "BankItem") ~= nil
            
            -- Create texture with special handling for bank buttons
            local tex
            if isBankButton then
                -- For bank buttons, use a named texture with highest overlay level
                tex = button:CreateTexture(buttonName.."_vPeddlerTex", "OVERLAY", nil, 7)
            else
                -- Standard approach for regular bag buttons
                tex = button:CreateTexture(nil, "OVERLAY")
            end
            
            button.vPeddlerTex = tex
            tex:Hide()
            
            -- Apply texture visually
            tex:SetTexture("Interface\\AddOns\\vPeddler\\textures\\Peddler_16.tga")
            tex:SetWidth(16)
            tex:SetHeight(16)
            tex:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
            
            -- Cache the original OnClick handler
            button.vPeddlerOrigClick = button:GetScript("OnClick")
            
            -- Around line 180, modify the HookButton function's OnClick handler
            button:SetScript("OnClick", function()
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
                        local link
                        
                        if isBankButton then
                            link = GetContainerItemLink(-1, button:GetID())
                        else
                            link = GetContainerItemLink(button:GetParent():GetID(), button:GetID())
                        end
                        
                        if link then
                            -- Use our local function instead of vPeddler_ProcessItemClick
                            ProcessVPeddlerItemClick(link)
                            
                            -- Force update with delay
                            local timer = CreateFrame("Frame")
                            timer:SetScript("OnUpdate", function()
                                this.elapsed = (this.elapsed or 0) + arg1
                                if this.elapsed < 0.1 then return end
                                timer:SetScript("OnUpdate", nil)
                                
                                if isBankButton then
                                    module:UpdateAllBankButtons()
                                else
                                    module:UpdateAllButtons()
                                end
                            end)
                            return
                        end
                    end
                end
                
                if button.vPeddlerOrigClick then
                    button.vPeddlerOrigClick()
                end
            end)
            
            buttonCache[button] = true
            
            return button
        end

        -- Update a specific button
        function module:UpdateButton(button)
            if not button or not button.vPeddlerTex then return end
            
            local link
            local buttonName = button:GetName() or ""
            
            -- Handle different button types based on name pattern
            if string.find(buttonName, "BankItem") then
                -- Get the bank button ID number using string.find instead of string.match
                local buttonID = nil
                if buttonName and type(buttonName) == "string" then
                    local _, _, id = string.find(buttonName, "BankItem(%d+)")
                    if id then
                        buttonID = tonumber(id)
                    end
                end
                
                if buttonID and buttonID <= 24 then
                    -- Main bank slots (1-24) use container ID -1
                    link = GetContainerItemLink(-1, button:GetID())
                else
                    -- For expanded bank slots (25+), try a different approach
                    -- First, try to get the item directly using this button's ID
                    for bagID = 5, 11 do
                        local testLink = GetContainerItemLink(bagID, button:GetID())
                        if testLink then
                            link = testLink
                            break
                        end
                    end
                    
                    -- If that didn't work, try using parent information
                    if not link then
                        -- Try parent bag ID first
                        local parentBagID = button:GetParent() and button:GetParent():GetID()
                        if parentBagID and parentBagID >= 5 and parentBagID <= 11 then
                            link = GetContainerItemLink(parentBagID, button:GetID())
                        else
                            -- Try grandparent as fallback
                            local containerID = button:GetParent() and button:GetParent():GetParent() and button:GetParent():GetParent():GetID()
                            if containerID and containerID >= 5 and containerID <= 11 then
                                link = GetContainerItemLink(containerID, button:GetID())
                            end
                        end
                    end
                    
                    -- If we still don't have a link, give up
                    if not link then
                        button.vPeddlerTex:Hide()
                        return
                    end
                end
            else
                -- Regular bag item
                local bag, slot
                if button:GetParent() and button:GetParent():GetID() and button:GetID() then
                    bag = button:GetParent():GetID()
                    slot = button:GetID()
                    
                    if bag >= 0 and bag <= 4 and slot > 0 then
                        link = GetContainerItemLink(bag, slot)
                    end
                end
            end
            
            -- No icon if no item
            if not link then
                button.vPeddlerTex:Hide()
                return
            end
            
                        -- Check if item should be sold
            if ShouldSellItem(link) then
                local size = vPeddlerDB.iconSize or 16
                local alpha = vPeddlerDB.iconAlpha or 1.0
                local position = vPeddlerDB.iconPosition or "TOPRIGHT"
                
-- Apply position
-- Apply position
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
                
                -- Apply the texture
                button.vPeddlerTex:SetTexture(texturePath)
                button.vPeddlerTex:Show()
            else
                -- Hide icon
                button.vPeddlerTex:Hide()
            end
        end

        -- Update all buttons
        function module:UpdateAllButtons()
            if not IsBagVisible() then return end
            
            -- Find new buttons each time
            self:FindButtons()
            
            -- Update all buttons
            local updated = 0
            for button in pairs(buttonCache) do
                -- Skip bank buttons in this function
                if button:GetName() and not string.find(button:GetName(), "BankItem") then
                    self:UpdateButton(button)
                    updated = updated + 1
                end
            end
            
            if updated > 0 and debugMode then
                Debug("Updated " .. updated .. " buttons")
            end
        end

        -- Update all bank buttons
        function module:UpdateAllBankButtons()
            -- Skip if bank isn't open
            if not self:IsBankVisible() then return end
            
            -- Find new bank buttons
            self:FindBankButtons()
            
            -- Update all bank buttons
            local updated = 0
            for button in pairs(buttonCache) do
                -- Only update buttons with names containing "BankItem"
                if button:GetName() and string.find(button:GetName(), "BankItem") then
                    self:UpdateButton(button)  -- Use the same function for both types
                    updated = updated + 1
                end
            end
            
            if updated > 0 and debugMode then
                Debug("Updated " .. updated .. " bank buttons")
            end
        end

        -- Add this to the module (around line 490)
        function module:DebugBankButtons()
            local foundButtons = 0
            local hooked = 0
            
            -- Scan and report status of bank buttons
            for i = 1, 200 do
                local frameName = "SUCC_bagBankItem" .. i
                local frame = _G[frameName]
                if frame then
                    foundButtons = foundButtons + 1
                    if buttonCache[frame] then
                        hooked = hooked + 1
                    end
                    
                    -- Try to get item info
                    local link = GetContainerItemLink(-1, frame:GetID())
                    local itemId = link and GetItemId(link)
                    local isFlagged = itemId and vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[itemId]
                    
                    DEFAULT_CHAT_FRAME:AddMessage("Button " .. frameName .. " ID: " .. frame:GetID() .. 
                        ", Hooked: " .. (buttonCache[frame] and "Yes" or "No") .. 
                        ", Item: " .. (link or "none") ..
                        ", Flagged: " .. (isFlagged and "Yes" or "No") ..
                        ", Texture: " .. (frame.vPeddlerTex and (frame.vPeddlerTex:IsShown() and "Shown" or "Hidden") or "None"))
                end
            end
            
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler SUCC-bag:|r Found " .. foundButtons .. 
                " bank buttons, " .. hooked .. " hooked")
        end

        -- Initialize module
        function module:Init()
            Debug("Initializing SUCC-bag module")
            
            -- Main frame for continuous updates
            self.frame = CreateFrame("Frame")
            self.frame:SetScript("OnUpdate", function()
                -- Only proceed if bags are visible
                if not IsBagVisible() and not self:IsBankVisible() then return end
                
                -- Throttle updates to 5 times/second
                updateDelay = updateDelay + arg1
                if updateDelay < 0.2 then return end
                updateDelay = 0
                
                -- Update appropriate buttons
                if IsBagVisible() then
                    self:UpdateAllButtons()
                end
                
                if self:IsBankVisible() then
                    self:UpdateAllBankButtons()
                end
            end)
            
            -- Hook SUCC_bag's OnShow
            if SUCC_bag then
                local originalOnShow = SUCC_bag:GetScript("OnShow") or function() end
                SUCC_bag:SetScript("OnShow", function()
                    originalOnShow()
                    Debug("SUCC_bag shown")
                    self:UpdateAllButtons()
                end)
            end
            
            -- Hook SUCC_bag.bank's OnShow
            if SUCC_bag and SUCC_bag.bank then
                local originalBankOnShow = SUCC_bag.bank:GetScript("OnShow") or function() end
                SUCC_bag.bank:SetScript("OnShow", function()
                    originalBankOnShow()
                    Debug("SUCC_bag.bank shown")
                    
                    -- Use a timer to ensure all bank frames are loaded
                    local timer = CreateFrame("Frame")
                    timer:SetScript("OnUpdate", function()
                        this.elapsed = (this.elapsed or 0) + arg1
                        if this.elapsed < 0.5 then return end
                        timer:SetScript("OnUpdate", nil)
                        
                        -- Important: Use standard button hooking for bank items
                        module:FindButtons()
                        module:UpdateAllBankButtons()
                    end)
                end)
            end
            
            -- Register for events
            self.eventFrame = CreateFrame("Frame")
            self.eventFrame:RegisterEvent("BAG_UPDATE")
            self.eventFrame:RegisterEvent("MERCHANT_SHOW")
            self.eventFrame:RegisterEvent("MERCHANT_CLOSED")
            self.eventFrame:RegisterEvent("BANKFRAME_OPENED")
            self.eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
            
            self.eventFrame:SetScript("OnEvent", function()
                if event == "BANKFRAME_OPENED" then
                    -- Use slightly longer delay for bank opening
                    local timer = CreateFrame("Frame")
                    timer:SetScript("OnUpdate", function()
                        this.elapsed = (this.elapsed or 0) + arg1
                        if this.elapsed < 0.5 then return end
                        timer:SetScript("OnUpdate", nil)
                        
                        -- Force a scan for bank buttons on bank open
                        Debug("Bank opened, scanning for buttons")
                        module:FindBankButtons()
                        module:UpdateAllBankButtons()
                    end)
                elseif event == "PLAYERBANKSLOTS_CHANGED" then
                    -- Bank slot changes
                    if module:IsBankVisible() then
                        module:UpdateAllBankButtons()
                    end
                elseif IsBagVisible() then
                    self:UpdateAllButtons()
                elseif module:IsBankVisible() then
                    self:UpdateAllBankButtons()
                end
            end)
            
            -- Also add a bank frame handler
            local bankEventFrame = CreateFrame("Frame")
            bankEventFrame:RegisterEvent("BANKFRAME_OPENED")
            bankEventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
            bankEventFrame:SetScript("OnEvent", function()
                if not module:IsBankVisible() then return end
                
                -- Small delay to ensure all bank frames are fully loaded
                local timer = CreateFrame("Frame")
                timer:SetScript("OnUpdate", function()
                    this.elapsed = (this.elapsed or 0) + arg1
                    if this.elapsed < 0.3 then return end
                    timer:SetScript("OnUpdate", nil)
                    
                    -- Use the standard functions that work for bags but call them on bank frames
                    module:FindButtons()
                    module:UpdateAllBankButtons()
                end)
            end)
            
            -- Initialize immediately if bags are open
            if IsBagVisible() then
                self:UpdateAllButtons()
            end
            
            Debug("Module initialization complete")
            return true
        end

        -- Initialize
        module:Init()

        -- Register debugging functions
        VPEDDLER_SuccBagTest = {
            ForceRefresh = function()
                module:UpdateAllButtons()
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler:|r Forced refresh of all SUCC-bag icons")
            end,
            
            ToggleDebug = function()
                debugMode = not debugMode
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler:|r Debug mode " .. (debugMode and "enabled" or "disabled"))
            end,

            DebugBank = function()
                module:DebugBankButtons()
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler:|r Debug report for SUCC-bag bank buttons generated")
            end
        }

        if SUCC_bag and vPeddlerDB and vPeddlerDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: SUCC-bag module loaded")
        end
    end)
end)