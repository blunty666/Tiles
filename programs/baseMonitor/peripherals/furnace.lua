local remotePeripherals = (...)

return {
	display_name = "Vanilla Furnace",
	width = 100,
	height = 80,
	add = function(name, window)
		local sourceObject = {
			windowID = window:GetUserdata()[2],
			displays = {
				fuelProgress = advancedTiles.addSimpleFluidBar(window, 10, 55, 0, 20, 10, "lava", 1),
				cookProgress = advancedTiles.addComplexBar(window, 30, 40, 0, 40, 10, 0xff0000, 1),
				[1] = window:AddItemSlot(15, 25, 0),
				[2] = window:AddItemSlot(15, 65, 0),
				[3] = window:AddItemSlot(85, 45, 0),
			},
		}
		sourceObject.displays.fuelProgress:SetRotation(270)
		return sourceObject
	end,
	update = function(name, sourceObject)
		local curBurn, maxBurn
		local isCooking, curCook
		local maxCook = 200
		local furnaceData = remotePeripherals:GetSourceData(name, "vanilla_furnace")
		if furnaceData then
			curBurn, maxBurn = furnaceData.getBurnTime, furnaceData.getCurrentItemBurnTime
			isCooking, curCook = furnaceData.isBurning, furnaceData.getCookTime
		end
			if type(curBurn) == "number" and type(maxBurn) == "number" then
			sourceObject.displays.fuelProgress:SetPercent(curBurn/maxBurn)
		else
			sourceObject.displays.fuelProgress:SetPercent(0)
		end
		if isCooking and type(curCook) == "number" then
			sourceObject.displays.cookProgress:SetPercent(curCook/maxCook)
		else
			sourceObject.displays.cookProgress:SetPercent(0)
		end

		local items
		local itemData = remotePeripherals:GetSourceData(name, "inventory")
		if itemData then
			items = itemData.getAllStacks
		end
		for i = 1, 3 do
			if items and items[i] then
				sourceObject.displays[i]:SetItemId(items[i].id)
				sourceObject.displays[i]:SetMeta(items[i].dmg)
				sourceObject.displays[i]:SetAmount(items[i].qty)
				if items[i].health_bar then
					sourceObject.displays[i]:SetDamageBar(items[i].health_bar)
				else
					sourceObject.displays[i]:SetDamageBar(0)
				end
			else
				sourceObject.displays[i]:SetAmount(false)
			end
		end
	end,
}
