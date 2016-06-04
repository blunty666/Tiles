local remotePeripherals = (...)

return {
	width = 60,
	height = 100,
	add = function(name, window)
		local fillBar = advancedTiles.addSimpleFluidBar(window, 10, 80, 0, 60, 40, "water", 1)
		fillBar:SetRotation(270)
		fillBar:GetBackground():SetClickable(false)
		
		local expansionWindow = guiTiles.newBasicWindow(window:AddSubTile(60, 10, -2), 95, 80, false)
		expansionWindow:AddText(5, 5, "Fill history:", 0x000000)
		expansionWindow:SetVisible(false)
		expansionWindow:SetClickable(false)
		guiTiles.makeDraggable(window, expansionWindow:GetBackground())
		
		local historyGraph = advancedTiles.addLineGraph(expansionWindow, 5, 15, 0, 85, 60, 0xff0000, 1)
		historyGraph:GetBackground():SetClickable(false)
	
		local toggleButton = window:AddButton(10, 85, 0, "More", 0x7fcc19, 0x000000, 0x57a64e, 0x000000, 40, 10)
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
	
		local object = {
			windowID = window:GetUserdata()[2],
			displays = {
				currFuid = false,
				fillBar = fillBar,
				historyGraph = historyGraph,
			},
			backgroundUpdate = true,
		}
		
		return object
	end,
	update = function(name, object)
		local percent = 0
		local data = remotePeripherals:GetSourceData(name, "fluid_handler")
		if data then
			local tankInfo = data.getTankInfo
			if tankInfo and tankInfo[1] then
				if tankInfo[1].contents then
					if object.currFuid ~= tankInfo[1].contents.name then
						object.currFuid = tankInfo[1].contents.name
						object.displays.fillBar:GetBar():SetFluid(object.currFuid)
					end
					percent = tankInfo[1].contents.amount / tankInfo[1].capacity
				end
			end
		end
		object.displays.fillBar:SetPercent(percent)
		object.displays.historyGraph:Update(percent)
	end,
}
