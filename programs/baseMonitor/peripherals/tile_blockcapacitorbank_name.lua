local remotePeripherals = (...)

local function round(val, decimal)
	if decimal then
		return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
	else
		return math.floor(val+0.5)
	end
end

return {
	display_name = "EnderIO Capacitor Bank",
	width = 60,
	height = 130,
	add = function(name, window, userConfig)
		local object
		
		local size = userConfig:Get(table.concat({"peripheral", "tile_blockcapacitorbank_name", name, "size"}, "."))
		if size then
			size = tonumber(size) or 1
		else
			size = 1
		end
		
		local fillBar = advancedTiles.addComplexBar(window, 10, 80, 0, 60, 40, 0xff0000, 1)
		fillBar:SetRotation(270)
		fillBar:GetBackground():SetClickable(false)
		
		local fillText = window:AddText(5, 90, "", 0x000000)
		local maxText = window:AddText(55, 100, "", 0x000000)
		maxText:SetObjectAnchor("RIGHT", "TOP")
			
		local expansionWindow = guiTiles.newBasicWindow(window:AddSubTile(60, 10, -2), 95, 110, false)
		expansionWindow:AddText(5, 5, "Fill history:", 0x000000)
		expansionWindow:SetVisible(false)
		expansionWindow:SetClickable(false)
		guiTiles.makeDraggable(window, expansionWindow:GetBackground())
			
		local historyGraph = advancedTiles.addLineGraph(expansionWindow, 5, 15, 0, 85, 60, 0xff0000, 1)
		historyGraph:GetBackground():SetClickable(false)
		
		expansionWindow:AddText(5, 85, "Configure Size:", 0x000000)
		
		local textBox
		local function editSize(size)
			local newSize = tonumber(size)
			if newSize and newSize % 1 == 0 then
				print("New Size = ", newSize)
				object.size = newSize
				userConfig:Set(table.concat({"peripheral", "tile_blockcapacitorbank_name", name, "size"}, "."), size)
				userConfig:Save()
			else
				print("Invalid Size = ", size)
				textBox:SetText(tostring(object.size))
			end
		end
		textBox = expansionWindow:AddTextBox(5, 95, 0, 85, editSize)
		textBox.background:SetVisible(false)
		textBox:SetText(tostring(size))
		
		local toggleButton = window:AddButton(10, 115, 0, "More", 0x7fcc19, 0x000000, 0x57a64e, 0x000000, 40, 10)
		toggleButton:SetOnRelease(
			function()
				if expansionWindow:GetVisible() then
					expansionWindow:SetVisible(false)
					expansionWindow:SetClickable(false)
					toggleButton:SetText("More")
				else
					expansionWindow:SetVisible(true)
					expansionWindow:SetClickable(true)
					toggleButton:SetText("Less")
				end
			end
		)
		
		object = {
			windowID = window:GetUserdata()[2],
			displays = {
				fillBar = fillBar,
				fillText = fillText,
				maxText = maxText,
				historyGraph = historyGraph,
			},
			size = size,
			backgroundUpdate = true,
		}
		
		return object
	end,
	update = function(name, sourceObject)
		local percent = 0
		local data = remotePeripherals:GetSourceData(name, "rf_receiver")
		if data then
			local curEnergy = data.getEnergyStored
			local maxEnergy = data.getMaxEnergyStored
			
			local unit, unitText = 1000000000000, "T"
			if maxEnergy*sourceObject.size >= 1000000000 then
				unit, unitText = 1000000000, "B"
			elseif maxEnergy*sourceObject.size >= 1000000 then
				unit, unitText = 1000000, "M"
			elseif maxEnergy*sourceObject.size >= 1000 then
				unit, unitText = 1000, "K"
			end
			
			local fillTextValue = curEnergy*sourceObject.size / unit
			fillTextValue = round(fillTextValue, 2)
			sourceObject.displays.fillText:SetText(tostring(fillTextValue))
			
			local maxTextValue = maxEnergy*sourceObject.size / unit
			maxTextValue = round(maxTextValue, 2)
			sourceObject.displays.maxText:SetText("/"..tostring(maxTextValue)..unitText.." RF")
			
			if type(curEnergy) == "number" and type(maxEnergy) == "number" then
				percent = curEnergy / maxEnergy
			end
		end
		sourceObject.displays.fillBar:SetPercent(percent)
		sourceObject.displays.historyGraph:Update(percent)
	end,
}
