local remotePeripherals = (...)

return {
	display_name = "Redstone Furnace",
	width = 100,
	height = 80,
	add = function(name, window)
		local sourceObject = {
			windowID = window:GetUserdata()[2],
			cookProgress = 0,
			displays = {
				energy = advancedTiles.addComplexBar(window, 10, 70, 0, 50, 10, 0xff0000, 1),
				cookProgress = advancedTiles.addSimpleBoxBar(window, 50, 42, 0, 20, 6, 0xffffff, 1),
				[1] = window:AddItemSlot(40, 45, 0),
				[2] = window:AddItemSlot(80, 45, 0),
			},
		}
		sourceObject.displays.energy:SetRotation(270)
		return sourceObject
	end,
	update = function(name, sourceObject)
		local curEnergy, maxEnergy
		local energyPerTick
		local rfData = remotePeripherals:GetSourceData(name, "rf_info")
		if rfData then
			curEnergy = rfData.getEnergyInfo
			maxEnergy = rfData.getMaxEnergyInfo
			energyPerTick = rfData.getEnergyPerTickInfo
		end

		if type(curEnergy) == "number" and type(maxEnergy) == "number" then
			sourceObject.displays.energy:SetPercent(curEnergy/maxEnergy)
		else
			sourceObject.displays.energy:SetPercent(0)
		end

		if type(energyPerTick) == "number" and energyPerTick > 0 then
			sourceObject.cookProgress = (sourceObject.cookProgress + 1) % 5
			sourceObject.displays.cookProgress:SetPercent(sourceObject.cookProgress/4)
		else
			sourceObject.displays.cookProgress:SetPercent(0)
		end

		local items
		local itemData = remotePeripherals:GetSourceData(name, "inventory")
		if itemData then
			items = itemData.getAllStacks
		end
		for i = 1, 2 do
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
