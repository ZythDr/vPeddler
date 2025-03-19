-- vPeddler compatibility module for Bagshui

-- 1. First, define a central debug function near the top of the file
local function Debug(msg)
    -- Only show debug messages if debug mode is enabled
    if not vPeddlerDB or not vPeddlerDB.debug then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler-Bagshui|r: " .. tostring(msg))
end

local function CheckAddonsLoaded()
    -- Check for Bagshui using multiple reliable methods
    local bagshuiLoaded = false
    
    -- Method 1: Check for specific BagshuiBagsItem frames
    for i = 1, 10 do -- Only need to check a few
        if getglobal("BagshuiBagsItem" .. i) then
            Debug("Detected BagshuiBagsItem" .. i)
            bagshuiLoaded = true
            break
        end
    end
    
    -- Method 2: Check for BagshuiBagsFrame (main container)
    if not bagshuiLoaded and getglobal("BagshuiBagsFrame") then
        Debug("Detected BagshuiBagsFrame")
        bagshuiLoaded = true
    end
    
    -- Method 3: Check for Bagshui global object
    if not bagshuiLoaded and Bagshui and Bagshui.prototypes and Bagshui.prototypes.Inventory then
        Debug("Detected Bagshui.prototypes.Inventory")
        bagshuiLoaded = true
    end
    
    -- Check if vPeddler is loaded and initialized
    local vPeddlerLoaded = vPeddlerDB ~= nil
    
    if bagshuiLoaded and vPeddlerLoaded then
        -- Both addons are loaded, initialize the module
        NotifyLoaded()
        Initialize()
        return true
    end
    
    return false
end

local function NotifyLoaded()
    if vPeddlerDB and vPeddlerDB.verboseMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Bagshui compatibility loaded")
    end
end

-- Debug settings
local debugMode = false

-- Configuration
local isInitialized = false
local markedButtons = {}

-- Check if an item should be marked for vendor selling
local function ShouldMarkItem(link)
    if not link or not vPeddlerDB then return false end
    
    -- Check if addon is enabled - more permissive check
    if vPeddlerDB.enabled == false then return false end
    
    -- Get item info
    local itemId = vPeddler_GetItemId(link)
    if not itemId then return false end
    
    -- Manual flag check - this is the most important part
    if vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[itemId] then
        return true
    end
    
    -- Quality check - keep this the same
    local _, _, quality = GetItemInfo(link)
    if quality and vPeddlerDB.ignoreQuality and vPeddlerDB.ignoreQuality[quality] then
        return true
    end
    
    return false
end

-- Update icon appearance to match current settings
local function UpdateIconAppearance(button)
    if not button or not button.vPeddlerVendorFrame then return end
    
    -- Position
    local position = vPeddlerDB and vPeddlerDB.iconPosition or "BOTTOMLEFT"
    button.vPeddlerVendorFrame:ClearAllPoints()
    button.vPeddlerVendorFrame:SetPoint(position, button, position, 0, 0)
    
    -- Size
    local size = vPeddlerDB and vPeddlerDB.iconSize or 16
    button.vPeddlerVendorFrame:SetWidth(size)
    button.vPeddlerVendorFrame:SetHeight(size)
    
    -- Texture
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
    
    button.vPeddlerVendorIcon:SetTexture(texturePath)
    button.vPeddlerVendorIcon:SetAlpha(vPeddlerDB and vPeddlerDB.iconAlpha or 1.0)
end

-- Create vendor badge for a button
local function CreateVendorBadge(button)
    if not button or not button:GetName() then return nil end
    
    local vendorFrameName = button:GetName() .. "VendorBadge"
    local existingFrame = getglobal(vendorFrameName)
    if existingFrame then
        Debug("Found existing frame: " .. vendorFrameName)
        return existingFrame
    end
    
    local vendorFrame = CreateFrame("Frame", vendorFrameName, button)
    Debug("Created new frame: " .. vendorFrameName)
    
    local position = vPeddlerDB and vPeddlerDB.iconPosition or "BOTTOMLEFT"
    vendorFrame:ClearAllPoints()
    vendorFrame:SetPoint(position, button, position, 0, 0)
    
    local size = vPeddlerDB and vPeddlerDB.iconSize or 16
    vendorFrame:SetWidth(size)
    vendorFrame:SetHeight(size)
    
    local iconName = vendorFrameName .. "Icon"
    local icon = vendorFrame:CreateTexture(iconName, "OVERLAY")
    icon:SetAllPoints(vendorFrame)
    
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
    
    icon:SetTexture(texturePath)
    icon:SetAlpha(vPeddlerDB and vPeddlerDB.iconAlpha or 1.0)
    
    button.vPeddlerVendorFrame = vendorFrame
    button.vPeddlerVendorIcon = icon
    
    vendorFrame:Hide()
    
    return vendorFrame
end

-- Add our vendor mark to a button
local function MarkButton(button)
    if not button then return end
    
    if not button.vPeddlerVendorFrame then
        CreateVendorBadge(button)
    else
        UpdateIconAppearance(button)
    end
    
    if button.vPeddlerVendorFrame then
        button.vPeddlerVendorFrame:Show()
        Debug("Marked button: " .. button:GetName())
    else
        Debug("Failed to mark button: " .. button:GetName())
    end
end

-- Hide the vendor mark on a button
local function HideButtonMark(button)
    if not button or not button.vPeddlerVendorFrame then return end
    button.vPeddlerVendorFrame:Hide()
end

-- Add a hook to Bagshui's OnUpdate function
local function HookBagshuiButtonUpdates()
    if not Bagshui or not Bagshui.prototypes or not Bagshui.prototypes.Inventory then
        Debug("Could not find Bagshui.prototypes.Inventory")
        return false
    end
    
    if Bagshui.prototypes.Inventory.ItemButton_OnUpdate then
        local originalOnUpdate = Bagshui.prototypes.Inventory.ItemButton_OnUpdate
        
        Bagshui.prototypes.Inventory.ItemButton_OnUpdate = function(self, elapsed)
            originalOnUpdate(self, elapsed)
            
            local button = this
            if button and button.bagshuiData and button.bagshuiData.item and button.bagshuiData.item.itemLink then
                if ShouldMarkItem(button.bagshuiData.item.itemLink) then
                    MarkButton(button)
                else
                    HideButtonMark(button)
                end
            end
        end
        
        Debug("Successfully hooked Bagshui.prototypes.Inventory.ItemButton_OnUpdate")
        return true
    end
    
    return false
end

-- Process all visible buttons in Bagshui
local function UpdateAllButtons()
    local markedCount = 0
    local totalButtons = 0
    
    local maxButtons = 0
    for i = 1, 500 do
        if getglobal("BagshuiBagsItem" .. i) then
            maxButtons = i
        end
    end
    
    Debug("Found " .. maxButtons .. " potential Bagshui buttons")
    
    for i = 1, maxButtons do
        local button = getglobal("BagshuiBagsItem" .. i)
        if button and button:IsVisible() then
            totalButtons = totalButtons + 1
            Debug("Found visible button: " .. button:GetName())
            
            if button.bagshuiData and button.bagshuiData.item and button.bagshuiData.item.itemLink then
                Debug("Button has item: " .. button.bagshuiData.item.itemLink)
                if ShouldMarkItem(button.bagshuiData.item.itemLink) then
                    MarkButton(button)
                    markedCount = markedCount + 1
                else
                    HideButtonMark(button)
                end
            else
                Debug("Button has no item data")
                HideButtonMark(button)
            end
        end
    end
    
    Debug("Updated " .. markedCount .. " buttons out of " .. totalButtons .. " visible")
    -- Only show this message when debug mode is enabled
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Marked " .. markedCount .. " vendor trash items")
    end
end

-- Verify Bagshui button structure
local function VerifyBagshuiButtons()
    -- Only run this function in debug mode
    if not debugMode then
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Checking Bagshui button structure...")
    
    if not Bagshui then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Error:|r Bagshui addon not found")
        return
    end
    
    if not Bagshui.prototypes or not Bagshui.prototypes.Inventory then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Error:|r Bagshui.prototypes.Inventory not found")
        return
    end
    
    if not Bagshui.prototypes.Inventory.ItemButton_OnUpdate then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Error:|r Bagshui.prototypes.Inventory.ItemButton_OnUpdate not found")
        return
    end
    
    local buttonsFound = 0
    local visibleButtons = 0
    local buttonsWithItems = 0
    
    for i = 1, 50 do
        local buttonName = "BagshuiBagsItem" .. i
        local button = getglobal(buttonName)
        
        if button then
            buttonsFound = buttonsFound + 1
            
            if button:IsVisible() then
                visibleButtons = visibleButtons + 1
                
                if button.bagshuiData and button.bagshuiData.item and button.bagshuiData.item.itemLink then
                    buttonsWithItems = buttonsWithItems + 1
                    DEFAULT_CHAT_FRAME:AddMessage("  Button " .. i .. ": " .. button.bagshuiData.item.itemLink)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("  Button " .. i .. ": No item data")
                end
            end
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Found " .. buttonsFound .. " buttons, " .. 
                                 visibleButtons .. " visible, " .. buttonsWithItems .. " with items")
end

-- Initialize module with several retries
local function TryInitialize(attempt)
    attempt = attempt or 1
    if attempt > 3 then return end
    
    Debug("vPeddlerDB.enabled = " .. tostring(vPeddlerDB.enabled) .. ", flaggedItems count = " .. (vPeddlerDB.flaggedItems and table.getn(vPeddlerDB.flaggedItems) or "nil"))
    Debug("Initialization attempt #" .. attempt)
    
    local hookSuccess = HookBagshuiButtonUpdates()
    
    if vPeddler and vPeddler.OnOptionSet and not vPeddler.OnOptionSetHooked then
        local originalOptionSet = vPeddler.OnOptionSet
        vPeddler.OnOptionSet = function(option, value)
            originalOptionSet(option, value)
            
            Debug("vPeddler settings changed, updating icons")
            UpdateAllButtons()
        end
        vPeddler.OnOptionSetHooked = true
        Debug("Hooked vPeddler.OnOptionSet")
    end
    
    if vPeddler_OnFlagItem and not vPeddler_OnFlagItemHooked then
        local originalFlagItem = vPeddler_OnFlagItem
        vPeddler_OnFlagItem = function(itemId, flag)
            originalFlagItem(itemId, flag)
            
            Debug("Item " .. tostring(itemId) .. " flag changed, updating icons")
            UpdateAllButtons()
        end
        vPeddler_OnFlagItemHooked = true
        Debug("Hooked vPeddler_OnFlagItem")
    end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    eventFrame:SetScript("OnEvent", function()
        Debug("Event triggered: " .. event)
        local timer = CreateFrame("Frame")
        local elapsed = 0
        timer:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed >= 0.5 then
                UpdateAllButtons()
                timer:SetScript("OnUpdate", nil)
            end
        end)
    end)
    
    SLASH_VPB1 = "/vpb"
    SlashCmdList["VPB"] = function(msg)
        if msg == "test" then
            TestMarkAllButtons()
        elseif msg == "debug" then
            debugMode = not debugMode
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Debug mode " .. (debugMode and "enabled" or "disabled"))
        elseif msg == "update" then
            UpdateAllButtons()
        elseif msg == "verify" then
            VerifyBagshuiButtons()
        else
            UpdateAllButtons()
            
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Commands:")
            DEFAULT_CHAT_FRAME:AddMessage("  /vpb - Update trash markers")
            DEFAULT_CHAT_FRAME:AddMessage("  /vpb test - Add test markers to all buttons")
            DEFAULT_CHAT_FRAME:AddMessage("  /vpb debug - Toggle debug messages")
            DEFAULT_CHAT_FRAME:AddMessage("  /vpb update - Force update buttons")
            DEFAULT_CHAT_FRAME:AddMessage("  /vpb verify - Check Bagshui button structure")
        end
    end
    
    local initTimer = CreateFrame("Frame")
    local initElapsed = 0
    initTimer:SetScript("OnUpdate", function()
        initElapsed = initElapsed + arg1
        if initElapsed >= 1.0 then
            UpdateAllButtons()
            initTimer:SetScript("OnUpdate", nil)
        end
    end)
    
    if not hookSuccess then
        local retryTimer = CreateFrame("Frame")
        local retryElapsed = 0
        retryTimer:SetScript("OnUpdate", function()
            retryElapsed = retryElapsed + arg1
            if retryElapsed >= 3.0 then
                TryInitialize(attempt + 1)
                retryTimer:SetScript("OnUpdate", nil)
            end
        end)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Bagshui integration loaded successfully")
        -- Only verify buttons in debug mode
        if debugMode then
            VerifyBagshuiButtons()
        end
    end
    
    isInitialized = true
end

-- Wait until Bagshui is fully loaded
local startupTimer = CreateFrame("Frame")
local startupElapsed = 0
startupTimer:SetScript("OnUpdate", function()
    startupElapsed = startupElapsed + arg1
    if startupElapsed >= 3.0 then
        if IsAddOnLoaded("Bagshui") then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Initializing Bagshui compatibility...")
            TryInitialize()
        end
        startupTimer:SetScript("OnUpdate", nil)
    end
end)

-- Also watch for Bagshui loading later
local loadWatcher = CreateFrame("Frame")
loadWatcher:RegisterEvent("ADDON_LOADED")
loadWatcher:SetScript("OnEvent", function()
    if arg1 == "Bagshui" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Bagshui detected, will initialize shortly...")
        local timer = CreateFrame("Frame")
        local elapsed = 0
        timer:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed >= 3.0 then
                TryInitialize()
                timer:SetScript("OnUpdate", nil)
            end
        end)
        loadWatcher:UnregisterAllEvents()
    end
end)

-- Variable to prevent multiple hook attempts
local vPeddler_OnFlagItemHooked = false
