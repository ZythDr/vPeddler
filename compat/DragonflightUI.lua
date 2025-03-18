-- vPeddler compatibility module for Turtle-Dragonflight bags
local _G = getfenv(0)

-- Only load if vPeddler exists
local vPeddler = _G.vPeddler
if not vPeddler then return end

local module = {}
vPeddler.compatModules = vPeddler.compatModules or {}
vPeddler.compatModules["Turtle-Dragonflight"] = module

-- Module state
local buttonCache = {}      -- Cache of processed buttons
local updateDelay = 0       -- Update timer
local bagFrameNames = {}    -- Detected bag frame names
local buttonPatterns = {}   -- Detected button patterns
local debugMode = false     -- Debug mode

-- Cache frequently used functions
local GetContainerItemLink = GetContainerItemLink
local GetItemInfo = GetItemInfo
local pairs = pairs

-- Debug function
local function Debug(msg)
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler Turtle-DF:|r " .. msg)
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
    if quality == 0 and vPeddlerDB.sellGray then
        return true
    end
    
    return false
end

-- Check if bags are visible and discover frames
function module:AreBagsVisible()
    -- If we've already found a frame name that works, check it first
    for frameName in pairs(bagFrameNames) do
        local frame = _G[frameName]
        if frame and frame:IsVisible() then
            return true
        end
    end
    
    -- High priority frames - check these first
    local highPriorityFrames = {"TDFBags", "TurtleDF_BagFrame", "SUCC_bag"}
    for _, frameName in ipairs(highPriorityFrames) do
        local frame = _G[frameName]
        if frame and frame:IsVisible() then
            bagFrameNames[frameName] = true
            return true
        end
    end
    
    -- Check standard container frames
    for i = 1, 5 do
        local frameName = "ContainerFrame" .. i
        local frame = _G[frameName]
        if frame and frame:IsVisible() then
            bagFrameNames[frameName] = true
            return true
        end
    end
    
    return false
end

-- Find all bag buttons
function module:FindButtons()
    local foundCount = 0
    
    -- First check known patterns
    if next(buttonPatterns) then
        for pattern in pairs(buttonPatterns) do
            for i = 1, 120 do
                local frameName = pattern .. i
                local frame = _G[frameName]
                if frame and not buttonCache[frame] then
                    self:HookButton(frame)
                    foundCount = foundCount + 1
                end
            end
        end
        
        if foundCount > 0 then
            return foundCount
        end
    end
    
    -- Try common naming patterns
    local commonPatterns = {
        "TurtleDFBagItem", "TDF_BagItem", "SUCC_bagItem",
        "ContainerFrame1Item", "ContainerFrame2Item"
    }
    
    for _, pattern in ipairs(commonPatterns) do
        for i = 1, 40 do
            local frameName = pattern .. i
            local frame = _G[frameName]
            if frame then
                buttonPatterns[pattern] = true
                if not buttonCache[frame] then
                    self:HookButton(frame)
                    foundCount = foundCount + 1
                end
            end
        end
    end
    
    return foundCount
end

-- Hook a single button
function module:HookButton(button)
    if not button or buttonCache[button] then return end
    
    -- Create texture for vendor icon
    local tex = button:CreateTexture(nil, "OVERLAY")
    button.vPeddlerTex = tex
    tex:Hide()
    
    -- Apply texture visually
    tex:SetTexture("Interface\\AddOns\\vPeddler\\textures\\Peddler_16.tga")
    tex:SetWidth(16)
    tex:SetHeight(16)
    tex:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    
    -- Add to cache
    buttonCache[button] = true
    
    return button
end

-- Update a specific button
function module:UpdateButton(button)
    if not button or not button.vPeddlerTex then return end
    
    -- Get bag/slot from button
    local bag, slot
    
    -- Try direct approach
    if button:GetParent() and button:GetParent():GetID() and button:GetID() then
        bag = button:GetParent():GetID()
        slot = button:GetID()
    end
    
    -- If that failed, try to parse from button name
    if not bag or not slot then
        local btnName = button:GetName()
        if btnName then
            -- Try common pattern
            local bagID, slotID = string.match(btnName, "(%d+)Item(%d+)")
            if bagID and slotID then
                bag = tonumber(bagID)
                slot = tonumber(slotID)
            end
        end
    end
    
    if not bag or not slot or bag < 0 or bag > 4 then
        return
    end
    
    local link = GetContainerItemLink(bag, slot)
    
    -- No icon if no item
    if not link then
        button.vPeddlerTex:Hide()
        return
    end
    
    -- Check if item should be sold
    if ShouldSellItem(link) then
        local size = vPeddlerDB.iconSize or 16
        local alpha = vPeddlerDB.iconAlpha or 1.0
        local position = "TOPRIGHT"
        
        -- Position from settings
        if vPeddlerDB.iconPosition then
            if vPeddlerDB.iconPosition == "TOPLEFT" then
                position = "TOPLEFT"
            elseif vPeddlerDB.iconPosition == "BOTTOMLEFT" then
                position = "BOTTOMLEFT"
            elseif vPeddlerDB.iconPosition == "BOTTOMRIGHT" then
                position = "BOTTOMRIGHT"
            elseif vPeddlerDB.iconPosition == "C" or vPeddlerDB.iconPosition == "CENTER" then
                position = "CENTER"
            end
        end
        
        -- Apply position
        button.vPeddlerTex:ClearAllPoints()
        button.vPeddlerTex:SetPoint(position, button, position, 0, 0)
        
        -- Apply size and alpha
        button.vPeddlerTex:SetWidth(size)
        button.vPeddlerTex:SetHeight(size)
        button.vPeddlerTex:SetAlpha(alpha)
        
        -- Determine texture based on settings
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
    if not self:AreBagsVisible() then return end
    
    -- Find new buttons each time
    self:FindButtons()
    
    -- Update all buttons
    for button in pairs(buttonCache) do
        self:UpdateButton(button)
    end
end

-- Hook bag events
function module:HookBagEvents()
    -- Hook Turtle-Dragonflight functions if found
    if _G.Turtle and _G.Turtle.Dragonflight then
        local tdf = _G.Turtle.Dragonflight
        
        local functionNames = {"ToggleBags", "OpenBags", "CloseBags"}
        for _, funcName in ipairs(functionNames) do
            if tdf[funcName] and type(tdf[funcName]) == "function" then
                local originalFunc = tdf[funcName]
                tdf[funcName] = function(param1, param2, param3, param4)
                    local result = originalFunc(param1, param2, param3, param4)
                    module:ScheduleUpdate(0.1)
                    return result
                end
            end
        end
    end
    
    -- Hook standard bag functions
    local originalOpenAllBags = OpenAllBags
    OpenAllBags = function()
        local result = originalOpenAllBags()
        module:UpdateAllButtons()
        return result
    end
end

-- Schedule an update with delay
function module:ScheduleUpdate(delay)
    local timer = CreateFrame("Frame")
    timer.elapsed = 0
    timer.delay = delay or 0.1
    
    timer:SetScript("OnUpdate", function()
        timer.elapsed = timer.elapsed + arg1
        if timer.elapsed >= timer.delay then
            module:UpdateAllButtons()
            timer:SetScript("OnUpdate", nil)
        end
    end)
end

-- Initialize module
function module:Init()
    -- Main frame for updates
    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnUpdate", function()
        -- Only proceed if bags are visible
        if not self:AreBagsVisible() then return end
        
        -- Throttle updates
        updateDelay = updateDelay + arg1
        if updateDelay < 0.2 then return end
        updateDelay = 0
        
        -- Update all buttons
        self:UpdateAllButtons()
    end)
    
    -- Hook events
    self:HookBagEvents()
    
    -- Register for standard events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("BAG_UPDATE")
    self.eventFrame:RegisterEvent("MERCHANT_SHOW")
    self.eventFrame:RegisterEvent("MERCHANT_CLOSED")
    
    self.eventFrame:SetScript("OnEvent", function()
        if self:AreBagsVisible() then
            self:UpdateAllButtons()
        end
    end)
    
    -- Initialize immediately if bags are open
    if self:AreBagsVisible() then
        self:UpdateAllButtons()
    end
    
    return true
end

-- Debug/test commands
_G.VPEDDLER_TurtleBagTest = {
    ForceRefresh = function()
        module:UpdateAllButtons()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler:|r Forced refresh of all icons")
    end,
    
    ToggleDebug = function()
        debugMode = not debugMode
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler:|r Debug mode " .. (debugMode and "enabled" or "disabled"))
    end
}

-- Initialize
module:Init()

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler:|r Turtle-Dragonflight bag module loaded")