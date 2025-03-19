-- vPeddler: Vendor Assistant for Vanilla WoW 1.12
-- Main addon file

-- Create addon global table
vPeddler = {}
vPeddler.version = "1.0"
vPeddler.isVendorOpen = false
vPeddler.itemCache = {}  -- Cache to track item status

-- Basic initialization
-- Consolidated initialization function
function vPeddler_InitDefaults(force)
    -- Create vPeddlerDB if it doesn't exist
    if not vPeddlerDB then
        vPeddlerDB = {
            enabled = true,
            autoSell = true,
            autoRepair = true,
            flaggedItems = {},
            verboseMode = true,
            iconSize = 16,
            iconAlpha = 1.0,
            iconPosition = "BOTTOMLEFT",
            iconTexture = "coins",
            modifierKey = "ALT",
            iconOutline = false,
            minProfit = 0,
            autoFlagGrey = true,
            manualSellButton = false,
            debug = false,
            autoFlagGray = true,

            -- Quality settings
            ignoreQuality = {
                [0] = true,  -- Poor (Grey)
                [1] = false, -- Common (White)
                [2] = false, -- Uncommon (Green)
                [3] = false, -- Rare (Blue)
                [4] = false, -- Epic (Purple)
                [5] = false, -- Legendary (Orange)
            }
        }
    else
        -- Ensure all critical settings exist even for existing profiles
        if not vPeddlerDB.flaggedItems then vPeddlerDB.flaggedItems = {} end
        
        -- Ensure icon settings exist
        if vPeddlerDB.iconSize == nil then vPeddlerDB.iconSize = 16 end
        if vPeddlerDB.iconAlpha == nil then vPeddlerDB.iconAlpha = 1.0 end
        if vPeddlerDB.iconPosition == nil then vPeddlerDB.iconPosition = "BOTTOMLEFT" end
        if vPeddlerDB.iconTexture == nil then vPeddlerDB.iconTexture = "coins" end
        if vPeddlerDB.modifierKey == nil then vPeddlerDB.modifierKey = "ALT" end
        if vPeddlerDB.iconOutline == nil then vPeddlerDB.iconOutline = false end
        
        -- Quality settings
        if not vPeddlerDB.ignoreQuality then
            vPeddlerDB.ignoreQuality = {
                [0] = true,  -- Poor (Grey)
                [1] = false, -- Common (White)
                [2] = false, -- Uncommon (Green)
                [3] = false, -- Rare (Blue)
                [4] = false, -- Epic (Purple)
                [5] = false, -- Legendary (Orange)
            }
        end
        
        -- Ensure additional settings exist
        if vPeddlerDB.autoFlagGrays then vPeddler_AutoFlagGrayItems() end
        if vPeddlerDB.manualSellButton == nil then vPeddlerDB.manualSellButton = false end
        if vPeddlerDB.debug == nil then vPeddlerDB.debug = false end
        if vPeddlerDB.verboseMode == nil then vPeddlerDB.verboseMode = true end
        if vPeddlerDB.autoFlagGray == nil then vPeddlerDB.autoFlagGray = true end
    end
    
    -- Standardize on autoFlagGrays with an 's'
    if vPeddlerDB.autoFlagGrays == nil then 
        vPeddlerDB.autoFlagGrays = true 
    end
    
    -- Remove any old variants of the setting to avoid confusion
    vPeddlerDB.autoFlagGray = nil
    vPeddlerDB.autoFlagGrey = nil
    
    -- Ensure manuallyUnflagged table exists
    vPeddlerDB.manuallyUnflagged = vPeddlerDB.manuallyUnflagged or {}
end

vPeddler.texturePool = {}
vPeddler.lastUpdate = 0
vPeddler.updateThrottle = 0.1 -- Seconds between bag updates

vPeddler.currentSaleCache = {}
vPeddler.totalEarnings = 0
vPeddler.totalSold = 0

-- Consolidated and optimized event registration

local eventFrame = CreateFrame("Frame")

function vPeddler_OnLoad()
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", vPeddler_OnEvent)
end

function vPeddler_OnEvent()
    if event == "ADDON_LOADED" then
        if arg1 == "vPeddler" then
            vPeddler_InitDefaults()
            vPeddler_Initialize()
            
            -- Register remaining events after loading
            eventFrame:RegisterEvent("MERCHANT_SHOW")
            eventFrame:RegisterEvent("MERCHANT_CLOSED")
            eventFrame:RegisterEvent("BAG_UPDATE")
            eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
            eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
            
            -- Run auto-flag for gray items if the setting is enabled
            if vPeddlerDB and vPeddlerDB.autoFlagGrays then
                C_Timer.After(1, vPeddler_AutoFlagGrayItems)
            end
            
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Loaded and ready")
        end
    elseif event == "MERCHANT_SHOW" then
        vPeddler.isVendorOpen = true
        if vPeddlerDB.enabled then
            if vPeddlerDB.autoRepair then
                vPeddler_AutoRepair()
            end
            
            -- Check if we should auto-sell or show the button
            if vPeddlerDB.autoSell and not vPeddlerDB.manualSellButton then
                vPeddler_SellJunk()
            elseif vPeddlerDB.manualSellButton then
                vPeddler_CreateManualSellButton()
            end
        end
    elseif event == "MERCHANT_CLOSED" then
        -- Clear the cache when leaving vendor
        vPeddler.isVendorOpen = false
        vPeddler.currentSaleCache = {}
        -- Hide the sell button if it exists
        if vPeddler.sellButton then
            vPeddler.sellButton:Hide()
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Run auto-flag for gray items if enabled
        if vPeddlerDB and vPeddlerDB.autoFlagGrays then
            vPeddler_AutoFlagGrayItems()
        end
        
        -- Update bag markers if they're visible
        vPeddler_UpdateBagSlotMarkers()
    elseif event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED" then
        -- Directly handle bag updates without unnecessary function calls
        vPeddler.needsUpdate = true
        
        -- Only update visible bags
        for i = 0, 4 do
            if vPeddler_IsBagOpen(i) then
                vPeddler_UpdateBagSlotMarkers()
                break
            end
        end
    end
end

vPeddler_OnLoad()

-- Auto-repair functionality
function vPeddler_AutoRepair()
    local repairCost, canRepair = GetRepairAllCost()
    if canRepair and repairCost > 0 then
        if repairCost <= GetMoney() then
            RepairAllItems()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Repaired all items for "..vPeddler_FormatMoney(repairCost))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Not enough gold to repair ("..vPeddler_FormatMoney(repairCost).." needed)")
        end
    end
end

function vPeddler_SellJunk()
    -- Clear any existing queue
    vPeddler.sellQueue = {}
    vPeddler.queueSize = 0
    
    -- Record starting gold
    vPeddler.startMoney = GetMoney()
    
    -- Scan all bags for junk
    local itemCount = 0
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemName, _, quality = GetItemInfo(link)
                local itemId = vPeddler_GetItemId(link)
                
                -- Check if this item should be sold
                local shouldSell = false
                
                -- Check quality-based selling
                if quality and vPeddlerDB.ignoreQuality[quality] then
                    shouldSell = true
                end
                
                -- Check manually flagged items
                if itemId and vPeddlerDB.flaggedItems[itemId] then
                    shouldSell = true
                end
                if shouldSell then
                    -- Add to queue
                    table.insert(vPeddler.sellQueue, {bag = bag, slot = slot})
                    vPeddler.queueSize = vPeddler.queueSize + 1
                    itemCount = itemCount + 1
                end
            end
        end
    end
    
    -- Start the selling process if there are items to sell
    if vPeddler.queueSize > 0 then
        if vPeddlerDB.verboseMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Selling " .. itemCount .. " items...")
        end
        vPeddler_ProcessSellQueue()
    end
end

-- Helper function to get item ID from link
function vPeddler_GetItemId(link)
    if not link then return nil end
    
    -- Try different pattern matches for item IDs
    local _, _, id = string.find(link, "item:(%d+):")
    if not id then
        _, _, id = string.find(link, "item:(%d+)") -- Fallback pattern
    end
    if not id then return nil end
    
    return tonumber(id)
end    

function vPeddler_GetVendorPrice(bag, slot)
    -- Create tooltip if needed
    if not vPeddlerTooltip then
        vPeddlerTooltip = CreateFrame("GameTooltip", "vPeddlerTooltip", nil, "GameTooltipTemplate")
    end
    
    -- Set up tooltip
    vPeddlerTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    vPeddlerTooltip:ClearLines()
    vPeddlerTooltip:SetBagItem(bag, slot)
    
    -- Look for sell price line
    for i = 1, vPeddlerTooltip:NumLines() do
        local text = getglobal("vPeddlerTooltipTextLeft" .. i):GetText()
        if text and string.find(text, "Sell Price") then
            -- Found the sell price line, now extract the value
            
            -- Try to handle different formats
            local gold = string.match(text, "(%d+) Gold") or 0
            local silver = string.match(text, "(%d+) Silver") or 0
            local copper = string.match(text, "(%d+) Copper") or 0
            
            gold = tonumber(gold) or 0
            silver = tonumber(silver) or 0
            copper = tonumber(copper) or 0
            
            local totalValue = gold * 10000 + silver * 100 + copper
            return totalValue
        end
    end
    
    return 0 -- Default if no price found
end

-- Replace the money formatting function:

function vPeddler_FormatMoney(money)
    return vPeddler_GetCoinTextureString(money or 0)
end

function vPeddler_HookContainerFrames()
    -- Store the original function for later
    if not vPeddler.originalContainerFrameItemButton_OnClick then
        vPeddler.originalContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
    end
    
    ContainerFrameItemButton_OnClick = function(button)
        local shouldHandle = false
        
        -- Determine which modifier key to check for
        local modKey = vPeddlerDB.modifierKey or "ALT"
        
        if modKey == "ALT" and IsAltKeyDown() and arg1 == "RightButton" then
            shouldHandle = true
        elseif modKey == "CTRL" and IsControlKeyDown() and arg1 == "RightButton" then
            shouldHandle = true
        elseif modKey == "SHIFT" and IsShiftKeyDown() and arg1 == "RightButton" then
            shouldHandle = true
        end
        
        if shouldHandle then
            local bag = this:GetParent():GetID()
            local slot = this:GetID()
            local link = GetContainerItemLink(bag, slot)
            
            if link then
                local itemId = vPeddler_GetItemId(link)
                if itemId then
                    -- Get item name
                    local name = GetItemInfo(link)
                    name = name or ("ItemID: "..itemId)
                    
                    -- Toggle flagged status
                    if vPeddlerDB.flaggedItems[itemId] then
                        vPeddler_UnflagItem(itemId, link)
                    else
                        vPeddlerDB.flaggedItems[itemId] = true
                        
                        -- Print to chat if verbose mode is enabled
                        if vPeddlerDB.verboseMode then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Added "..link.." to auto-sell list")
                        end
                    end
                    
                    -- Update all instances of this item across all bags
                    vPeddler_UpdateAllInstancesOfItem(itemId)
                    
                    return
                end
            end
        end
        
        -- Call original handler if we didn't handle it
        vPeddler.originalContainerFrameItemButton_OnClick(button)
    end
end

-- Function to update just a single slot marker
function vPeddler_UpdateSingleSlotMarker(bag, slot)
    -- Skip if DB isn't ready
    if not vPeddlerDB then return end
    
    -- Skip if addon is disabled
    if not vPeddlerDB.enabled then return end
    
    -- Name for our marker texture
    local markerName = "vPeddlerMarker"..bag.."_"..slot
    
    -- Check if the slot is empty first
    local link = GetContainerItemLink(bag, slot)
    if not link then
        -- No item in slot, hide the marker if it exists
        local marker = getglobal(markerName)
        if marker then marker:Hide() end
        return
    end
    
    -- Get item info
    local name, _, quality = GetItemInfo(link)
    local itemId = vPeddler_GetItemId(link)
    if not itemId then return end
    
    -- Check if item should be marked
    local shouldMark = false
    
    -- Check quality-based marking
    if quality and vPeddlerDB.ignoreQuality and vPeddlerDB.ignoreQuality[quality] then
        shouldMark = true
    end
    
    -- Check manually flagged items
    if itemId and vPeddlerDB.flaggedItems and vPeddlerDB.flaggedItems[itemId] then
        shouldMark = true
    end
    
    -- Get the container frame
    local containerFrame = getglobal("ContainerFrame"..(bag+1))
    if not containerFrame then return end
    
    -- Look for the button for this slot
    local button = getglobal("ContainerFrame"..(bag+1).."Item"..(GetContainerNumSlots(bag)-(slot-1)))
    if not button then return end
    
    -- Get existing marker or create new one
    local marker = getglobal(markerName)
    if not marker then
        marker = button:CreateTexture(markerName, "OVERLAY")
    end
    
    -- If item should not be marked, hide it and return
    if not shouldMark then
        marker:Hide()
        return
    end
    
    -- Position based on settings
    local position = vPeddlerDB.iconPosition or "BOTTOMLEFT"
    marker:ClearAllPoints()
    marker:SetPoint(position, button, position, 0, 0)
    
    -- Size based on settings
    local size = vPeddlerDB.iconSize or 16
    marker:SetWidth(size)
    marker:SetHeight(size)
    
    -- Alpha based on settings
    local alpha = vPeddlerDB.iconAlpha or 1.0
    marker:SetAlpha(alpha)
    
    -- Fix: Properly declare the texture path variable locally
    local texturePath
    
    -- Determine texture path
    if vPeddlerDB.iconTexture == "coins" then
        -- Find texture file based on size
        local textureSize = "16"
        if size >= 23 and size <= 36 then
            textureSize = "32"
        elseif size > 36 then
            textureSize = "64"
        end
        
        -- Adjust file path based on outline setting
        if vPeddlerDB.iconOutline then
            texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_outline_" .. textureSize .. ".tga"
        else
            texturePath = "Interface\\AddOns\\vPeddler\\textures\\Peddler_" .. textureSize .. ".tga"
        end
    else
        texturePath = "Interface\\Icons\\INV_Misc_Coin_01"
    end
    
    -- Set the texture
    if texturePath then
        marker:SetTexture(texturePath)
        marker:Show()
        
        -- Debug: only show if debug is enabled
        if vPeddlerDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Showing marker at " .. bag .. ":" .. slot)
        end
    else
        -- Fallback to default texture if path is nil
        marker:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        marker:Show()
    end
end

-- Setup event handling
eventFrame:SetScript("OnEvent", vPeddler_OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")

function vPeddler_Initialize()
    -- Set up hooks
    vPeddler_HookContainerFrames()
    
    -- Update bag displays when they're shown
    local orig_ContainerFrame_OnShow = ContainerFrame_OnShow
    ContainerFrame_OnShow = function()
        -- Always call original function first
        orig_ContainerFrame_OnShow()
        
        -- Get the bag ID that was just opened
        local bag = this:GetID()
        
        -- Only do a full update if cache is marked as needing it
        if vPeddler.needsUpdate then
            vPeddler_BuildItemCache()
        end
        
        -- Just update this specific bag's markers
        vPeddler_UpdateBagMarkers(bag)
    end
    
    -- Function to update just one bag's markers
    function vPeddler_UpdateBagMarkers(bag)
        if not bag then return end
        
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            vPeddler_UpdateSingleSlotMarker(bag, slot)
        end
    end

    -- More efficient update on ContainerFrame_Update - just update the specific bag
    local orig_ContainerFrame_Update = ContainerFrame_Update
    ContainerFrame_Update = function(frame)
        -- Always call original function first
        if not frame then
            -- Default behavior when frame is nil
            orig_ContainerFrame_Update()
            return
        else
            -- Pass the frame parameter
            orig_ContainerFrame_Update(frame)
        end
        
        -- Only proceed if we have a valid frame
        if not frame or not frame.GetID then return end
        
        -- Get the bag ID that was updated
        local bag = frame:GetID()
        
        -- Update just this bag's markers
        vPeddler_UpdateBagMarkers(bag)
    end

    -- Run auto-flag for gray items if enabled
    if vPeddlerDB and vPeddlerDB.autoFlagGrays then
        -- Add a debug message
        if vPeddlerDB.verboseMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Running initial auto-flag for gray items...")
        end
        vPeddler_AutoFlagGrayItems()
    end
end

function vPeddler_UpdateBagSlotMarkers()
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            vPeddler_UpdateSingleSlotMarker(bag, slot)
        end
    end
end

-- Function to check if a bag is open
function vPeddler_IsBagOpen(bagID)
    -- Bag 0 = Backpack has a special frame
    if bagID == 0 then
        return ContainerFrame1:IsVisible()
    else
        -- For other bags
        for i=1, NUM_CONTAINER_FRAMES do
            local frame = getglobal("ContainerFrame"..i)
            if frame:IsVisible() and frame:GetID() == bagID then
                return true
            end
        end
    end
    return false
end

-- Texture pool management functions
function vPeddler_GetTexture(name)
    -- Check if texture already exists
    local existing = getglobal(name)
    if existing then return existing end
    
    -- Check if we have one in the pool
    if table.getn(vPeddler.texturePool) > 0 then
        local texture = table.remove(vPeddler.texturePool)
        texture:SetName(name)
        return texture
    end
    
    -- No existing texture, create new one
    return nil
end

function vPeddler_ReleaseTexture(texture)
    if not texture then return end
    texture:Hide()
    texture:ClearAllPoints()
    table.insert(vPeddler.texturePool, texture)
end

eventFrame:Show()

-- Test function to manually force marking
function vPeddler_TestMark()
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = vPeddler_GetItemId(link)
                if itemId then
                    local name = GetItemInfo(link) or "Unknown Item"
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: TEST - Found item " .. name .. " in bag " .. bag .. ", slot " .. slot)
                    
                    -- Force mark first item found
                    vPeddlerDB.flaggedItems[itemId] = true
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: TEST - Flagged item " .. name)
                    vPeddler_UpdateBagSlotMarkers()
                    return
                end
            end
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: TEST - No items found in bags")
end

-- Add a slash command for testing
SLASH_VPTEST1 = "/vptest"
SlashCmdList["VPTEST"] = function(msg)
    vPeddler_TestMark()
end

-- Create a global sellFrame
vPeddler.sellFrame = CreateFrame("Frame")

-- Update the process queue function
function vPeddler_ProcessSellQueue()
    if vPeddler.queueSize <= 0 then
        -- Calculate Earnings
        local earned = GetMoney() - vPeddler.startMoney
        
        -- Only report if we actually sold something
        if earned > 0 and vPeddlerDB.verboseMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Sold items for " .. 
                vPeddler_GetCoinTextureString(earned))
        end
        return
    end
    
    -- Process one item
    local item = table.remove(vPeddler.sellQueue, 1)
    vPeddler.queueSize = vPeddler.queueSize - 1
    
    -- Verify item is valid
    if not item or not item.bag or not item.slot then
        vPeddler_ProcessSellQueue()
        return
    end
    
    -- Clear item from cache immediately
    local cacheKey = item.bag .. "_" .. item.slot
    if vPeddler.itemCache then
        vPeddler.itemCache[cacheKey] = nil
    end
    
    -- Look for and hide the marker if it exists
    local markerName = "vPeddlerMarker" .. item.bag .. "_" .. item.slot
    local marker = getglobal(markerName)
    if marker then marker:Hide() end
    
    -- Use the item (sells it to vendor)
    UseContainerItem(item.bag, item.slot)
    
    -- Schedule next item sell
    vPeddler.sellTimer = vPeddler.sellTimer or CreateFrame("Frame")
    vPeddler.sellTimer.timeToSell = GetTime() + 0.2 -- 200ms between sells
    vPeddler.sellTimer:SetScript("OnUpdate", function()
        if GetTime() >= this.timeToSell then
            this:SetScript("OnUpdate", nil)
            vPeddler_ProcessSellQueue()
        end
    end)
end

SLASH_VPDEBUG1 = "/vpdebug"
SlashCmdList["VPDEBUG"] = function(msg)
    -- Show current settings
    DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Debug Info")
    DEFAULT_CHAT_FRAME:AddMessage("  Enabled: " .. (vPeddlerDB.enabled and "Yes" or "No"))
    DEFAULT_CHAT_FRAME:AddMessage("  AutoSell: " .. (vPeddlerDB.autoSell and "Yes" or "No"))
    DEFAULT_CHAT_FRAME:AddMessage("  AutoRepair: " .. (vPeddlerDB.autoRepair and "Yes" or "No"))
    
    -- Show flagged items
    local count = 0
    for id, _ in pairs(vPeddlerDB.flaggedItems) do
        count = count + 1
    end
    DEFAULT_CHAT_FRAME:AddMessage("  Flagged items: " .. count)
    
    -- Force bag update
    DEFAULT_CHAT_FRAME:AddMessage("  Updating bag markers...")
    vPeddler_UpdateBagSlotMarkers()
end

-- Add special event just for bag updates
function vPeddler_OnBagUpdate(event, bagID)
    -- Mark cache as needing an update
    vPeddler.needsUpdate = true
    
    -- Only update visible bags, and only if they're open
    if vPeddler_IsBagOpen(bagID) then
        vPeddler_UpdateBagSlotMarkers()
    end
end

function vPeddler_BuildItemCache()
    vPeddler.itemCache = {}  -- Reset cache
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = vPeddler_GetItemId(link)
                if itemId then
                    local _, _, quality = GetItemInfo(link)
                    
                    -- Calculate and cache whether this item should be sold
                    local shouldSell = false
                    
                    if quality and vPeddlerDB.ignoreQuality[quality] then
                        shouldSell = true
                    end
                    
                    if itemId and vPeddlerDB.flaggedItems[itemId] then
                        shouldSell = true
                    end
                    
                    -- Store in cache indexed by bag and slot
                    vPeddler.itemCache[bag .. "_" .. slot] = {
                        itemId = itemId,
                        shouldSell = shouldSell
                    }
                end
            end
        end
    end
    
    vPeddler.needsUpdate = false  -- Reset the update flag
end

-- Function to update all instances of an item

function vPeddler_UpdateAllInstancesOfItem(itemId)
    -- Skip if no itemId provided
    if not itemId then return end
    
    -- Loop through all bags
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local currentItemId = vPeddler_GetItemId(link)
                if currentItemId == itemId then
                    -- Clear cache for this item
                    local cacheKey = bag .. "_" .. slot
                    if vPeddler.itemCache then
                        vPeddler.itemCache[cacheKey] = nil
                    end
                    
                    -- Update its marker
                    vPeddler_UpdateSingleSlotMarker(bag, slot)
                end
            end
        end
    end
end

function vPeddler_GetCoinTextureString(money)
    if not money or money == 0 then return "0|cFFB87333c|r" end
    
    local gold = floor(money / 10000)
    local silver = floor((money - (gold * 10000)) / 100)
    local copper = floor(money - (gold * 10000) - (silver * 100))
    
    local text = ""
    if gold > 0 then 
        text = text .. gold .. "|cFFFFD700g|r"
        if silver > 0 or copper > 0 then text = text .. " " end
    end
    
    if silver > 0 then 
        text = text .. silver .. "|cFFC0C0C0s|r"
        if copper > 0 then text = text .. " " end
    end
    
    if copper > 0 or (gold == 0 and silver == 0) then 
        text = text .. copper .. "|cFFB87333c|r"
    end
    
    return text
end

SLASH_VPCOIN1 = "/vpcoin"
SlashCmdList["VPCOIN"] = function(msg)
    -- Show various amounts with coin textures
    DEFAULT_CHAT_FRAME:AddMessage("Test coin textures:")
    DEFAULT_CHAT_FRAME:AddMessage("1 copper: " .. vPeddler_GetCoinTextureString(1))
    DEFAULT_CHAT_FRAME:AddMessage("1 silver: " .. vPeddler_GetCoinTextureString(100))
    DEFAULT_CHAT_FRAME:AddMessage("1 gold: " .. vPeddler_GetCoinTextureString(10000))
    DEFAULT_CHAT_FRAME:AddMessage("Mixed: " .. vPeddler_GetCoinTextureString(12345))
end

-- Function to refresh all markers when settings change

function vPeddler_RefreshAllMarkers()
    -- Clear the cache
    vPeddler.itemCache = {}
    vPeddler.needsUpdate = true
    
    -- Update all visible bags
    for bag = 0, 4 do
        if vPeddler_IsBagOpen(bag) then
            vPeddler_UpdateBagMarkers(bag)
        end
    end
end

-- Call this function whenever settings change that affect marker appearance

-- Add the manual sell button functionality

function vPeddler_CreateManualSellButton()
    if vPeddler.sellButton then
        vPeddler.sellButton:Show()
        return
    end
    
    -- Create a button on the merchant frame
    local button = CreateFrame("Button", "vPeddlerSellButton", MerchantFrame, "UIPanelButtonTemplate")
    button:SetWidth(100)
    button:SetHeight(22)
    button:SetText("Sell Junk")
    button:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 10, 10)
    
    -- Set click handler
    button:SetScript("OnClick", function()
        -- Only do something if we're enabled
        if not vPeddlerDB.enabled then return end
        vPeddler_SellJunk()
    end)
    
    vPeddler.sellButton = button
end

-- More robust gray item detection without using _G

function vPeddler_AutoFlagGrayItems(forceFlag)
    if not vPeddlerDB then return end
    
    local flaggedCount = 0
    local grayCount = 0
    
    -- Process all items in all bags
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                -- Check if it's gray by examining the color code in the item link
                -- Gray items have the color code |cff9d9d9d
                local isGray = string.find(link, "|cff9d9d9d")
                
                if isGray then
                    grayCount = grayCount + 1
                    local itemId = vPeddler_GetItemId(link)
                    if itemId then
                        -- Only flag if not explicitly unflagged previously
                        if not (vPeddlerDB.manuallyUnflagged and vPeddlerDB.manuallyUnflagged[itemId]) or forceFlag then
                            -- Auto-flag this item
                            vPeddlerDB.flaggedItems[itemId] = true
                            flaggedCount = flaggedCount + 1
                            
                            -- Debug output for each item flagged
                            if vPeddlerDB.verboseMode then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Flagged " .. link)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Always update the markers after flagging items
    vPeddler_UpdateBagSlotMarkers()
    
    -- Show summary message
    if vPeddlerDB.verboseMode then
        if grayCount > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Found " .. grayCount .. " gray items, auto-flagged " .. flaggedCount .. " for selling")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: No gray items found in bags")
        end
    end
    
    return flaggedCount
end

-- Helper function to count total bag slots
function getNumTotalBagSlots()
    local count = 0
    for bag = 0, 4 do
        count = count + GetContainerNumSlots(bag)
    end
    return count
end

-- Function to handle bag updates (when items are added to bags)
function vPeddler_OnBagUpdateDelayed()
    -- Auto-flag any gray items in bags
    if vPeddlerDB and vPeddlerDB.autoFlagGrays then
        vPeddler_AutoFlagGrayItems()
    end
    
    -- Update bag markers if they're visible
    vPeddler_UpdateBagSlotMarkers()
end

-- Enhanced function to handle manually unflagging an item
function vPeddler_UnflagItem(itemId, link)
    if not itemId then return end
    
    -- Remove from flagged items
    if vPeddlerDB.flaggedItems[itemId] then
        vPeddlerDB.flaggedItems[itemId] = nil
    end
    
    -- Check if this is a gray item by looking at the link color
    local isGray = link and string.find(link, "|cff9d9d9d")
    
    -- Only add to manually unflagged if it's a gray item
    if isGray then
        -- Remember that this item was manually unflagged
        vPeddlerDB.manuallyUnflagged = vPeddlerDB.manuallyUnflagged or {}
        vPeddlerDB.manuallyUnflagged[itemId] = true
    end
    
    -- Print to chat if verbose mode is enabled
    if vPeddlerDB.verboseMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Removed " .. (link or itemId) .. " from auto-sell list")
    end
    
    -- Update all instances of this item
    vPeddler_UpdateAllInstancesOfItem(itemId)
end

-- Function to clear flags on all gray items
function vPeddler_ClearAllGrayItemFlags()
    -- Loop through all items in bags to identify gray ones
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                -- Check if it's gray by examining the color code
                local isGray = string.find(link, "|cff9d9d9d")
                
                if isGray then
                    local itemId = vPeddler_GetItemId(link)
                    if itemId then
                        -- Remove it from flagged items
                        vPeddlerDB.flaggedItems[itemId] = nil
                    end
                end
            end
        end
    end
end