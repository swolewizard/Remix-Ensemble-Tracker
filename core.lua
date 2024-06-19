-- Create a table to hold our addon functions and variables
VendorItemTracker = {}
VendorItemTrackerDB = VendorItemTrackerDB or {}

-- Define multiple lists of item IDs associated with specific vendor names
local vendorItemLists = {
	[219031] = {215189, 215193, 215196, 215199, 215201, 215204, 215208, 215210, 215214, 215241, 215245, 215247, 215252, 215256, 215255, 215261, 215264, 215267, 215289, 215293, 215295, 215298, 215302, 215304, 215320, 215324, 215327, 215330, 215334, 215335, 215339, 215343, 215346},
	[219027] = {215190, 215192, 215200, 215203, 215207, 215211, 215242, 215244, 215250, 215254, 215262, 215265, 215290, 215291, 215299, 215301, 215322, 215323, 215331, 215333, 215340, 215342, 215195, 215205, 215213, 215248, 215259, 215268, 215296, 215305, 215328, 215336, 215345, 104403, 104405, 104406, 104408, 104399, 104407, 104409, 104400, 104401, 104402, 104404, 227550},
	[219030] = {215176, 215181, 215182, 215221, 215222, 215223, 215224, 215272, 215273, 215274, 215310, 215311, 215312},
	[219028] = {215191, 215194, 215197, 215198, 215202, 215206, 215209, 215212, 215215, 215243, 215246, 215249, 215251, 215253, 215258, 215260, 215263, 215266, 215288, 215292, 215294, 215297, 215300, 215303, 215321, 215325, 215326, 215329, 215332, 215337, 215341, 215338, 215344, 215347},
	[220618] = {217824, 217828, 217829, 217821, 217820, 217823, 217827, 217832, 217831, 217830, 217819, 217826, 217825, 217837, 217843, 217842, 217835, 217834, 217836, 217841, 217846, 217845, 217844, 217833, 217839, 217838},
	[219025] = {226127, 5976, 215219, 215220, 215275, 215276, 215277, 215352, 215353, 215354, 215355, 215238, 215239, 215240, 215285, 215286, 215287, 215356, 215357, 215358, 215183, 215184, 215185, 215225, 215226, 215227, 215228, 215278, 215279, 215280, 215281, 215313, 215314, 215315, 215186, 215187, 215188, 215229, 215230, 215231, 215232, 215282, 215283, 215284, 215316, 215317, 215318, 215319, 215216, 215217, 215218, 215269, 215270, 215271, 215306, 215307, 215308, 215309, 215348, 215349, 215350, 215351},
}

-- Function to check vendor items and add to the list if purchased
function VendorItemTracker:CheckVendorItems()
    local targetName = UnitName("target") or "Unknown Target"
    local targetGUID = UnitGUID("target")
    local targetNPCID = targetGUID and tonumber(targetGUID:match("-(%d+)-%x+$"))

    if not vendorItemLists[targetNPCID] then return end

    local function ProcessVendorItems(retries)
        local numItems = GetMerchantNumItems()
        local itemList = vendorItemLists[targetNPCID]
        if not itemList then return end
		
        local vendorItemIDs = {}
        for i = 1, numItems do
            local itemLink = GetMerchantItemLink(i)
            if itemLink then
                local vendorItemId = GetItemInfoInstant(itemLink)
                table.insert(vendorItemIDs, vendorItemId)
            end
        end
		
        if #vendorItemIDs ~= numItems then
            if retries > 0 then
                C_Timer.After(1, function() ProcessVendorItems(retries - 1) end)
            else
                print("|cFFFF0000Error|r: Please close the vendor and reopen to retry the scan.")
            end
            return
        end

        local itemsToUpdateDB = {}
        for _, itemId in ipairs(itemList) do
            if not VendorItemTrackerDB[itemId] and not tContains(vendorItemIDs, itemId) then
                print("|cff00FF00RemixEnsembleTracker|r: Purchased Ensemble ItemId:", itemId)
                table.insert(itemsToUpdateDB, itemId)
            end
        end
		
        for _, id in ipairs(itemsToUpdateDB) do
            VendorItemTrackerDB[id] = true
        end
    end
	
    if targetNPCID == 220618 then
        SetMerchantFilter(LE_LOOT_FILTER_ALL)
        C_Timer.After(1, function() ProcessVendorItems(5) end)
    else
        ProcessVendorItems(5)
    end
end

-- Function to get player's currency amount
local function GetCurrencyAmount(currencyID)
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    return info and info.quantity or 0
end

-- Hook into the BuyMerchantItem function
local originalBuyMerchantItem = BuyMerchantItem
BuyMerchantItem = function(index, quantity)
    originalBuyMerchantItem(index, quantity)
	
    local targetGUID = UnitGUID("target")
    local targetNPCID = targetGUID and tonumber(targetGUID:match("-(%d+)-%x+$"))
	
    if vendorItemLists[targetNPCID] then
        local itemLink = GetMerchantItemLink(index)
        local itemId = itemLink and tonumber(string.match(itemLink, "item:(%d+)"))
        if itemId and not VendorItemTrackerDB[itemId] then
            local hasEnoughCurrency = true
            local currencyAmountTotal = GetCurrencyAmount(2778)

            for i = 1, GetMerchantItemCostInfo(index) do
                local _, currencyAmount, currencyLink = GetMerchantItemCostItem(index, i)
                local currencyId = tonumber(currencyLink:match("currency:(%d+)"))

                if currencyId == 2778 and currencyAmount > currencyAmountTotal then
                    hasEnoughCurrency = false
                    print("|cff00FF00RemixEnsembleTracker|r: Not enough bronze to make the purchase.")
                    break
                end
            end
            
            if hasEnoughCurrency then
                print("|cff00FF00RemixEnsembleTracker|r: Purchased Ensemble ItemId:", itemId)
                VendorItemTrackerDB[itemId] = true
            end
        end
    end
end

-- Function to add information to the tooltip
local function AddTooltips(tooltip)
    if not tooltip or type(tooltip.GetItem) ~= "function" then return end
	local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    local itemId = tonumber(string.match(itemLink, "item:(%d+)"))
    if itemId and VendorItemTrackerDB[itemId] then
        tooltip:AddLine(" ------------------------------- ", 1, 0, 0)
        tooltip:AddLine("|      Already Purchased    |", 1, 0, 0)
        tooltip:AddLine(" ------------------------------- ", 1, 0, 0)
        tooltip:Show()
    end
end

-- Register the callback for the OnTooltipSetItem event
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddTooltips)

-- Create a frame to respond to events
local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "MERCHANT_SHOW" then
        C_Timer.After(0, function()
            VendorItemTracker:CheckVendorItems()
        end)
    end
end)

C_Timer.After(1, function()
    print("|cff00FF00RemixEnsembleTracker|r: Initialized")
end)