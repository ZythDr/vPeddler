-- vPeddler compatibility module for Guda bag addon
--
-- Strategy: wrap Guda_ItemButton_SetItem instead of polling with OnUpdate.
-- Guda calls SetItem on every button whenever a bag or bank slot changes, so
-- our overlay is painted at exactly the right moment with zero background cost.
-- The button pool means buttons are reused across slots; we read button.bagID /
-- button.slotID / button.itemData directly (set by Guda before our wrapper runs).

local _G = getfenv(0)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    this:UnregisterEvent("PLAYER_ENTERING_WORLD")

    -- 1-second delay so all addons finish loading
    local waitFrame = CreateFrame("Frame")
    waitFrame:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed < 1 then return end
        this:SetScript("OnUpdate", nil)

        -- Bail if Guda is not present
        if not IsAddOnLoaded("Guda") or not _G["Guda"] then return end
        if not vPeddlerDB then return end
        local vPeddler = _G.vPeddler
        if not vPeddler then return end

        -- Register module
        local module = {}
        vPeddler.compatModules = vPeddler.compatModules or {}
        vPeddler.compatModules["Guda"] = module

        -- All buttons we have encountered (keyed by frame reference for fast iteration)
        local seenButtons = {}

        --======================================================
        -- Overlay frame pool (mirrors Guda's lock/junk icon pools)
        -- Parented to UIParent with DIALOG strata so it is never
        -- clipped by the bag frame's own border frames.
        --======================================================
        local overlayPool = {}

        local function AcquireOverlay()
            local f = table.remove(overlayPool)
            if not f then
                f = CreateFrame("Frame", nil, UIParent)
                f:SetFrameStrata("DIALOG")
                f:SetWidth(16)
                f:SetHeight(16)
                local tex = f:CreateTexture(nil, "OVERLAY")
                tex:SetAllPoints(f)
                f.tex = tex
            end
            return f
        end

        local function ReleaseOverlay(f)
            if not f then return end
            f:Hide()
            f:ClearAllPoints()
            table.insert(overlayPool, f)
        end

        --======================================================
        -- Helpers
        --======================================================

        local function GetTexturePath()
            local size = vPeddlerDB.iconSize or 16
            if vPeddlerDB.iconTexture == "goldcoin" then
                return "Interface\\Icons\\INV_Misc_Coin_01"
            end
            local sz = (size >= 36) and "64" or (size >= 23) and "32" or "16"
            local prefix = vPeddlerDB.iconOutline and "Peddler_outline_" or "Peddler_"
            return "Interface\\AddOns\\vPeddler\\textures\\" .. prefix .. sz .. ".tga"
        end

        local function ShouldSell(button)
            if not button.hasItem or not button.itemData then return false end
            if not vPeddlerDB or vPeddlerDB.enabled == false then return false end

            -- Read the link Guda already stored on the button — no extra API call
            local link = button.itemData.link
            if not link then return false end

            local itemId = vPeddler_GetItemId(link)
            if not itemId then return false end

            if vPeddler_IsItemFlagged and vPeddler_IsItemFlagged(itemId) then return true end

            local _, _, quality = GetItemInfo(link)
            if quality == 0 and vPeddlerDB.sellGray then return true end

            return false
        end

        --======================================================
        -- Icon update for a single button
        --======================================================

        function module:UpdateButton(button)
            if not button then return end

            -- Never show on remote-character or read-only views
            if button.otherChar or button.isReadOnly then
                if button.vPeddlerOverlay then
                    ReleaseOverlay(button.vPeddlerOverlay)
                    button.vPeddlerOverlay = nil
                end
                return
            end

            if not ShouldSell(button) then
                if button.vPeddlerOverlay then
                    ReleaseOverlay(button.vPeddlerOverlay)
                    button.vPeddlerOverlay = nil
                end
                return
            end

            -- Acquire an overlay frame from the pool if we don't have one
            if not button.vPeddlerOverlay then
                button.vPeddlerOverlay = AcquireOverlay()
            end

            local f    = button.vPeddlerOverlay
            local size = vPeddlerDB.iconSize or 16
            local pos  = vPeddlerDB.iconPosition or "TOPRIGHT"

            f:SetWidth(size)
            f:SetHeight(size)
            -- Anchor to the button so it follows it if the bag layout reflows
            f:ClearAllPoints()
            f:SetPoint(pos, button, pos, 0, 0)
            -- Stay above Guda's own quality-border frames (frame level + 5 matches lock icon)
            f:SetFrameLevel(button:GetFrameLevel() + 5)

            local tex = f.tex
            tex:SetTexture(GetTexturePath())
            tex:SetAlpha(vPeddlerDB.iconAlpha or 1.0)
            f:Show()
        end

        -- Refresh every button we have ever seen (used when settings change)
        function module:RefreshAll()
            for button in pairs(seenButtons) do
                self:UpdateButton(button)
            end
        end

        --======================================================
        -- Per-button click hook — installed once per pooled button.
        -- Also wraps OnHide so the overlay is released back to the
        -- pool whenever Guda hides a button (bag close, pool reuse).
        --======================================================

        local function EnsureClickHooked(button)
            if button.vPeddlerClickHooked then return end
            button.vPeddlerClickHooked = true

            -- Release overlay when Guda hides the button
            local origHide = button:GetScript("OnHide")
            button:SetScript("OnHide", function()
                if origHide then origHide() end
                if this.vPeddlerOverlay then
                    ReleaseOverlay(this.vPeddlerOverlay)
                    this.vPeddlerOverlay = nil
                end
            end)

            local origClick = button:GetScript("OnClick")
            button:SetScript("OnClick", function()
                -- Guard: Ctrl+RClick is Guda's own item-lock shortcut — never intercept it
                if arg1 == "RightButton" and not IsControlKeyDown() then
                    local modKey = string.upper(vPeddlerDB and vPeddlerDB.modifierKey or "ALT")
                    local modPressed =
                        (modKey == "ALT"   and IsAltKeyDown())     or
                        (modKey == "CTRL"  and IsControlKeyDown()) or
                        (modKey == "SHIFT" and IsShiftKeyDown())   or
                        (modKey == "NONE")

                    if modPressed and this.hasItem and this.bagID and this.slotID then
                        local link = GetContainerItemLink(this.bagID, this.slotID)
                        if link then
                            local itemId = vPeddler_GetItemId(link)
                            if itemId then
                                if vPeddler_IsItemFlagged(itemId) then
                                    vPeddler_UnflagItem(itemId, link)
                                else
                                    vPeddler_FlagItem(itemId, link)
                                end
                                -- Refresh every visible button so identical items update
                                -- immediately without waiting for Guda's next redraw
                                module:RefreshAll()
                                return  -- consume the click; don't pass to Guda
                            end
                        end
                    end
                end

                if origClick then origClick() end
            end)
        end

        --======================================================
        -- Core hook: wrap Guda_ItemButton_SetItem
        --
        -- By the time origSetItem returns, the button has:
        --   button.bagID, button.slotID, button.hasItem,
        --   button.itemData, button.isBank, button.otherChar
        -- We piggyback on that to paint/hide our overlay for free.
        --======================================================

        local origSetItem = Guda_ItemButton_SetItem
        Guda_ItemButton_SetItem = function(self, bagID, slotID, itemData, isBank, otherCharName, matchesFilter, isReadOnly)
            origSetItem(self, bagID, slotID, itemData, isBank, otherCharName, matchesFilter, isReadOnly)

            -- Skip remote-character views (can't sell those)
            if self.otherChar then return end

            EnsureClickHooked(self)
            seenButtons[self] = true
            module:UpdateButton(self)
        end

        --======================================================
        -- React to vPeddler settings changes (icon size/pos/texture…)
        --
        -- Two complementary hooks:
        --  1. vPeddler.OnOptionSet  — generic callback used by some modules
        --  2. The specific options-panel functions that the UI sliders/buttons
        --     call directly (same approach as the Bagnon compat module).
        --     These fire regardless of whether OnOptionSet exists.
        --======================================================

        if vPeddler.OnOptionSet and not vPeddler.gudaOnOptionSetHooked then
            local orig = vPeddler.OnOptionSet
            vPeddler.OnOptionSet = function(option, value)
                orig(option, value)
                module:RefreshAll()
            end
            vPeddler.gudaOnOptionSetHooked = true
        end

        -- Hook individual options functions (covers sliders, position buttons,
        -- outline toggle, texture dropdown — anything the options panel touches)
        local optionFuncs = {
            "vPeddlerOptions_IconPositionChange",
            "vPeddlerOptions_IconSizeChanged",
            "vPeddlerOptions_IconAlphaChanged",
            "vPeddlerOptions_OutlineToggle",
            "vPeddlerOptions_UpdatePreview",   -- fires for texture dropdown changes
            "vPeddlerOptions_SellGrayToggle",
        }
        for _, funcName in ipairs(optionFuncs) do
            if _G[funcName] and not vPeddler["gudaHooked_" .. funcName] then
                local orig = _G[funcName]
                _G[funcName] = function(a)
                    orig(a)
                    module:RefreshAll()
                end
                vPeddler["gudaHooked_" .. funcName] = true
            end
        end

        -- Also catch flag changes made via vanilla bag frame or other compat modules
        if vPeddler_OnFlagItem and not vPeddler.gudaFlagItemHooked then
            local orig = vPeddler_OnFlagItem
            vPeddler_OnFlagItem = function(itemId, flag)
                orig(itemId, flag)
                module:RefreshAll()
            end
            vPeddler.gudaFlagItemHooked = true
        end

        --======================================================
        -- Initial pass: handle buttons already visible if bags
        -- were open before our 1-second init delay elapsed
        --======================================================

        -- Button pool IDs are sequential from 1 with no gaps, so stopping on
        -- the first nil is safe and avoids scanning the full 500-slot range.
        for i = 1, 500 do
            local btn = _G["Guda_ItemButton" .. i]
            if not btn then break end
            if btn:IsShown() and btn.bagID then
                EnsureClickHooked(btn)
                seenButtons[btn] = true
                module:UpdateButton(btn)
            end
        end

        if vPeddlerDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF99CC33vPeddler|r: Guda compatibility loaded")
        end
    end)
end)
