-- vPeddler compatibility module for SUCC-bag
local _G = getfenv(0)

-- Only initialize if SUCC_bag is loaded
if not SUCC_bag then return end

local vPeddler = _G.vPeddler
if not vPeddler then return end

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
local debugMode = false      -- Start with debug enabled to troubleshoot

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

-- Check if SUCC_bag is currently visible
local function IsBagVisible()
    return SUCC_bag and SUCC_bag:IsVisible()
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
    
    Debug("Hooked button: " .. (button:GetName() or "unnamed"))
    return button
end

-- Update a specific button
function module:UpdateButton(button)
    if not button or not button.vPeddlerTex then return end
    
    -- Get bag/slot from button
    local bag, slot
    if button:GetParent() and button:GetParent():GetID() and button:GetID() then
        bag = button:GetParent():GetID()
        slot = button:GetID()
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
    if not IsBagVisible() then return end
    
    -- Find new buttons each time
    self:FindButtons()
    
    -- Update all buttons
    local updated = 0
    for button in pairs(buttonCache) do
        self:UpdateButton(button)
        updated = updated + 1
    end
    
    if updated > 0 then
        Debug("Updated " .. updated .. " buttons")
    end
end

-- Initialize module
function module:Init()
    Debug("Initializing SUCC-bag module")
    
    -- Main frame for continuous updates
    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnUpdate", function()
        -- Only proceed if bags are visible
        if not IsBagVisible() then return end
        
        -- Throttle updates to 5 times/second
        updateDelay = updateDelay + arg1
        if updateDelay < 0.2 then return end
        updateDelay = 0
        
        -- Update all buttons
        self:UpdateAllButtons()
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
    
    -- Register for events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("BAG_UPDATE")
    self.eventFrame:RegisterEvent("MERCHANT_SHOW")
    self.eventFrame:RegisterEvent("MERCHANT_CLOSED")
    
    self.eventFrame:SetScript("OnEvent", function()
        if IsBagVisible() then
            self:UpdateAllButtons()
        end
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
    end
}

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00vPeddler:|r SUCC-bag module loaded. Type '/script VPEDDLER_SuccBagTest.ForceRefresh()' to refresh icons.")