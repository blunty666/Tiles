local tArgs = {...}

--===== FIND TERMINAL GLASSES BRIDGE =====--
local bridge
if type(tArgs[1]) == "string" and peripheral.getType(tArgs[1]) == "openperipheral_bridge" then
	bridge = peripheral.wrap(tArgs[1])
	bridge.clear()
else
	error("could not find bridge on side: "..tostring(tArgs[1]))
end

--===== FIND PROGRAM PATH =====--
local path = fs.getDir(shell.getRunningProgram())

--===== LOAD APIS =====--
local apiPath = fs.combine(path, "apis")
local requiredAPIs = {
	"tiles",
	"guiTiles",
	"advancedTiles",
	"remotePeripheralClient",
}
for _, apiName in ipairs(requiredAPIs) do
	if not _G[apiName] then
		if not os.loadAPI(fs.combine(apiPath, apiName)) then
			error("Could not load API: "..apiName)
		end
	end
end

--===== LOAD CONFIG =====--
local configMethods = {
	Get = function(self, key)
		return self.data[key] or false
	end,
	Set = function(self, key, value)
		if type(key) == "string" and type(value) == "string" then
			self.data[key] = value
			return true
		end
		return false
	end,
	Load = function(self)
		if fs.exists(self.path) and not fs.isDir(self.path) then
			local handle = fs.open(self.path, "r")
			if handle then
				local data = handle.readAll()
				handle.close()
				if data then
					data = textutils.unserialise(data)
					if type(data) == "table" then
						self.data = data
						return true
					end
				end
			end
		end
		return false
	end,
	Save = function(self)
		if not fs.exists(self.path) or not fs.isDir(self.path) then
			local handle = fs.open(self.path, "w")
			if handle then
				handle.write(textutils.serialise(self.data))
				handle.close()
				return true
			end
		end
		return false
	end,
}
local configMetatable = {__index = configMethods}

local function initConfig(path)
	if type(path) ~= "string" then
		error("config.init - string expected", 2)
	elseif fs.exists(path) and fs.isDir(path) then
		error("config.init - invalid path: "..path, 2)
	end
	local config = {
		path = path,
		data = {},
	}
	return setmetatable(config, configMetatable)
end

--===== CHECK CONFIG DIR =====--
local configPath = fs.combine(path, "config")
if not fs.exists(configPath) then
	fs.makeDir(configPath)
elseif not fs.isDir(configPath) then
	error("someone is using my config directory!!!")
end

--===== LOAD REMOTE PERIPHERAL CLIENT =====--
local remotePeripherals = remotePeripheralClient.new()

--===== LOAD PERIPHERAL DATA =====--
local peripheralPath = fs.combine(path, "peripherals")
local peripherals = {}
local function loadPeripheral(peripheralName)
	local func, err = loadfile(fs.combine(peripheralPath, peripheralName))
	if func then
		local ok, ret = pcall(func, remotePeripherals)
		if not ok then
			printError("error loading peripheralData for: "..peripheralName)
			printError("got error: "..ret)
		else
			peripherals[peripheralName] = ret
		end
	end
end
for _, peripheralName in ipairs(fs.list(peripheralPath)) do
	loadPeripheral(peripheralName)
end

--===== LOAD SOURCE DATA =====--
local sourcePath = fs.combine(path, "sources")
local sources = {}
local function loadSource(sourceName)
	local func, err = loadfile(fs.combine(sourcePath, sourceName))
	if func then
		local ok, ret = pcall(func, remotePeripherals)
		if not ok then
			printError("error loading sourceData for: "..sourceName)
			printError("got error: "..ret)
		else
			sources[sourceName] = ret
		end
	end
end
for _, sourceName in ipairs(fs.list(sourcePath)) do
	loadSource(sourceName)
end

local function textToSize(text, width)
	if width <= 6 then
		return "..."
	elseif tiles.getMaxStringLength(text, width, 1) < string.len(text) then
		return string.sub(text, 1, tiles.getMaxStringLength(text, width - 6, 1)).."..."
	end
	return text
end

local minWidth, minHeight = 20, 10
local function newGraphWindow(windowHandler, surfaceHandler, uniqueID, width, height, updateName, objectType, configName)
	local width, height = math.max(width, minWidth), math.max(height, minHeight)

	local window = windowHandler:New(surfaceHandler:AddTile(-(width/2), -(height/2), 1), width, height, true)
	window:SetScreenAnchor("MIDDLE", "MIDDLE")

	local expansionWindow = guiTiles.newBasicWindow(window:AddSubTile(0, -10, -1), 100, 10, false)
	expansionWindow:SetVisible(false)
	expansionWindow:SetClickable(false)

	local mainText = window:AddText(1, 1, textToSize(configName, width - 10), 0x000000)
	mainText:SetZ(1)
	mainText:SetClickable(false)
	local textBackground = window:AddBox(1, 1, width - 9, 8, 0xffffff, 1)
	textBackground:SetVisible(false)
	textBackground:SetOnClick(
		function(object, button)
			if button == 1 then
				expansionWindow:SetVisible(true)
				expansionWindow:SetClickable(true)
			end
		end
	)
	guiTiles.makeDraggable(window, textBackground)
			
	local textBox
	local function textBoxSubmit(text)
		text = updateName(objectType, uniqueID, text)
		textBox:SetText(text)
		textBox:SetCursorPos(0)
		mainText:SetText(textToSize(text, width - 10))
		expansionWindow:SetVisible(false)
		expansionWindow:SetClickable(false)
	end
	textBox = expansionWindow:AddTextBox(0, 0, 0, 100, textBoxSubmit)
	textBox.background:SetVisible(false)
	textBox:SetText(configName)
	textBox:SetOnDeselect(function() textBoxSubmit(textBox:GetText()) end)

	local closeButton = window:AddButton(width - 8, 1, 1, "X", 0xff0000, 0xffffff, 0x00ff00, 0x000000)
	closeButton:SetOnRelease(function() window:SetDrawn(false) end)
			
	return window
end

local function newPlayerHandler(playerUUID, surfaceHandler)
	return function()

		local guiHandler = guiTiles.newGuiHandler(surfaceHandler)

		local windowHandler = guiTiles.newBasicWindowHandler()
		
		local userConfig = initConfig(fs.combine(configPath, playerUUID))
		userConfig:Load()
		
		local selectionWindow = guiTiles.newBasicWindow(surfaceHandler:AddTile(10, 10, 2), 80, 50)
		local peripheralTypes = {}
		local sourceTypes = {}
		
		local peripheralButton = selectionWindow:AddButton(10, 10, 0, "Peripherals", 0x7fcc19, 0x000000, 0x57a64e, 0x000000)
		peripheralButton:SetOnRelease(
			function()
				sourceTypes.listWindow:SetVisible(false)
				sourceTypes.listWindow:SetClickable(false)
				peripheralTypes.listWindow:SetVisible(true)
				peripheralTypes.listWindow:SetClickable(true)
			end
		)
		local sourceButton = selectionWindow:AddButton(17, 30, 0, "Sources", 0x7fcc19, 0x000000, 0x57a64e, 0x000000)
		sourceButton:SetOnRelease(
			function()
				peripheralTypes.listWindow:SetVisible(false)
				peripheralTypes.listWindow:SetClickable(false)
				sourceTypes.listWindow:SetVisible(true)
				sourceTypes.listWindow:SetClickable(true)
			end
		)
		
		do -- peripheralTypes
			peripheralTypes.list = {}
			peripheralTypes.selectedTypeList = false
			
			peripheralTypes.listWindow = guiTiles.newBasicWindow(selectionWindow:AddSubTile(selectionWindow:GetWidth() + 5, 0, 0), 150, 80)
			peripheralTypes.listWindow:SetVisible(false)
			peripheralTypes.listWindow:SetClickable(false)
			peripheralTypes.listWindow:AddFancyText(6, 6, 0, "Peripherals", 0x000000, 1)
			
			local function onListSelect(index, peripheralType)
				if peripheralTypes.selectedTypeList then
					peripheralTypes.selectedTypeList:SetVisible(false)
					peripheralTypes.selectedTypeList:SetClickable(false)
				end
				local sourceList = peripheralTypes.list[peripheralType].listWindow
				if sourceList then
					sourceList:SetVisible(true)
					sourceList:SetClickable(true)
					peripheralTypes.selectedTypeList = sourceList
				end
			end
			peripheralTypes.listObject = peripheralTypes.listWindow:AddList(5, 25, 0, 140, 50, onListSelect, {})
			
			peripheralTypes.add = function(peripheralType, name)
				local peripheralData = peripheralTypes.list[peripheralType]
				if peripheralData then
					local configName = userConfig:Get(table.concat({"peripheral", peripheralType, name}, ".")) or name
					local window = newGraphWindow(windowHandler, surfaceHandler, name, peripheralData.width, peripheralData.height, peripheralTypes.update, peripheralType, configName)
					local object = peripheralTypes.list[peripheralType].add(name, window, userConfig)
					peripheralTypes.list[peripheralType].list[name] = object
					peripheralTypes.list[peripheralType].listObject:AddItem(1, {name, configName})
				end
			end
			peripheralTypes.update = function(peripheralType, peripheralName, peripheralNewName)
				if string.len(peripheralNewName) == 0 then
					peripheralNewName = peripheralName
				end
				userConfig:Set(table.concat({"peripheral", peripheralType, peripheralName}, "."), peripheralNewName)
				userConfig:Save()
				if peripheralTypes.list[peripheralType] then
					local list = peripheralTypes.list[peripheralType].listObject
					
					for index, itemData in ipairs(list.items) do
						if itemData[1] == peripheralName then
							list:SetItem(index, {itemData[1], peripheralNewName})
							break
						end
					end
				end
				return peripheralNewName
			end
			peripheralTypes.remove = function(peripheralType, name)
				local object = peripheralTypes.list[peripheralType].list[name]
				if object then
					windowHandler:Delete(object.windowID)
					for index, itemName in ipairs(peripheralTypes.list[peripheralType].listObject.items) do
						if itemName[1] == name then
							peripheralTypes.list[peripheralType].listObject:RemoveItem(index)
							break
						end
					end
					peripheralTypes.list[peripheralType].list[name] = nil
				end
			end
		end
		
		do -- sourceTypes
			sourceTypes.list = {}
			sourceTypes.selectedTypeList = false
			
			sourceTypes.listWindow = guiTiles.newBasicWindow(selectionWindow:AddSubTile(selectionWindow:GetWidth() + 5, 0, 0), 150, 80)
			sourceTypes.listWindow:SetVisible(false)
			sourceTypes.listWindow:SetClickable(false)
			sourceTypes.listWindow:AddFancyText(6, 6, 0, "Sources", 0x000000, 1)
			
			local function onListSelect(index, sourceType)
				if sourceTypes.selectedTypeList then
					sourceTypes.selectedTypeList:SetVisible(false)
					sourceTypes.selectedTypeList:SetClickable(false)
				end
				local sourceList = sourceTypes.list[sourceType].listWindow
				if sourceList then
					sourceList:SetVisible(true)
					sourceList:SetClickable(true)
					sourceTypes.selectedTypeList = sourceList
				end
			end
			sourceTypes.listObject = sourceTypes.listWindow:AddList(5, 25, 0, 140, 50, onListSelect, {})
			
			sourceTypes.add = function(sourceType, name)
				local sourceData = sourceTypes.list[sourceType]
				if sourceData then
					local configName = userConfig:Get(table.concat({"source", sourceType, name}, ".")) or name
					local window = newGraphWindow(windowHandler, surfaceHandler, name, sourceData.width, sourceData.height, sourceTypes.update, sourceType, configName)
					local sourceObject = sourceTypes.list[sourceType].add(name, window, userConfig)
					sourceTypes.list[sourceType].list[name] = sourceObject
					sourceTypes.list[sourceType].listObject:AddItem(1, {name, configName})
				end
			end
			sourceTypes.update = function(sourceType, sourceName, sourceNewName)
				if string.len(sourceNewName) == 0 then
					sourceNewName = sourceName
				end
				userConfig:Set(table.concat({"source", sourceType, sourceName}, "."), sourceNewName)
				userConfig:Save()
				
				if sourceTypes.list[sourceType] then
					local list = sourceTypes.list[sourceType].listObject
					
					for index, itemData in ipairs(list.items) do
						if itemData[1] == sourceName then
							list:SetItem(index, {itemData[1], sourceNewName})
							break
						end
					end
				end
				return sourceNewName
			end
			sourceTypes.remove = function(sourceType, name)
				local sourceObject = sourceTypes.list[sourceType].list[name]
				if sourceObject then
					windowHandler:Delete(sourceObject.windowID)
					for index, itemName in ipairs(sourceTypes.list[sourceType].listObject.items) do
						if itemName[1] == name then
							sourceTypes.list[sourceType].listObject:RemoveItem(index)
							break
						end
					end
					sourceTypes.list[sourceType].list[name] = nil
				end
			end
		end


		for peripheralType, peripheralData in pairs(peripherals) do
		
			local name = peripheralData.display_name or peripheralType
		
			peripheralData.list = {}
			
			peripheralData.listWindow = guiTiles.newBasicWindow(peripheralTypes.listWindow:AddSubTile(155, 0, 0), 150, 80)
			peripheralData.listWindow:SetVisible(false)
			peripheralData.listWindow:SetClickable(false)
			
			peripheralData.listWindow:AddFancyText(6, 6, 0, textToSize(name, 138), 0x000000, 1)
			
			local function onListSelect(index, name)
				peripheralData.listObject:SetSelected(false, true)
				peripheralData.listObject:SetHighlighted(false, true)
				local windowID = peripheralData.list[name] and peripheralData.list[name].windowID
				if windowID then
					local window = windowHandler:GetWindow(windowID)
					if window then
						windowHandler:ToFront(windowID)
						if not window:GetDrawn() then
							window:SetDrawn(true)
						else
							window:SetX(-(window:GetWidth()/2))
							window:SetY(-(window:GetHeight()/2))
						end
					end
				end
			end
			peripheralData.listObject = peripheralData.listWindow:AddList(5, 25, 0, 140, 50, onListSelect, {})
			
			peripheralTypes.listObject:AddItem(1, {peripheralType, name})
			
			peripheralTypes.list[peripheralType] = peripheralData
		end

		for sourceType, sourceData in pairs(sources) do
		
			local name = sourceData.display_name or sourceType
		
			sourceData.list = {}
			
			sourceData.listWindow = guiTiles.newBasicWindow(sourceTypes.listWindow:AddSubTile(155, 0, 0), 150, 80)
			sourceData.listWindow:SetVisible(false)
			sourceData.listWindow:SetClickable(false)

			sourceData.listWindow:AddFancyText(6, 6, 0, textToSize(name, 138), 0x000000, 1)

			local function onListSelect(index, name)
				sourceData.listObject:SetSelected(false, true)
				sourceData.listObject:SetHighlighted(false, true)
				local windowID = sourceData.list[name] and sourceData.list[name].windowID
				if windowID then
					local window = windowHandler:GetWindow(windowID)
					if window then
						windowHandler:ToFront(windowID)
						if not window:GetDrawn() then
							window:SetDrawn(true)
						else
							window:SetX(-(window:GetWidth()/2))
							window:SetY(-(window:GetHeight()/2))
						end
					end
				end
			end
			sourceData.listObject = sourceData.listWindow:AddList(5, 25, 0, 140, 50, onListSelect, {})
			
			sourceTypes.listObject:AddItem(1, {sourceType, name})
			
			sourceTypes.list[sourceType] = sourceData
		end

		local function peripheralChecker()
			for peripheralName, peripheralData in pairs(remotePeripherals.list) do
				if peripheralTypes.list[peripheralData.type] then
					peripheralTypes.add(peripheralData.type, peripheralName)
				end
				if peripheralData.sources then
					for source, _ in pairs(peripheralData.sources) do
						if sourceTypes.list[source] then
							sourceTypes.add(source, peripheralName)
						end
					end
				end
			end

			while true do
				local eventType, peripheralName = os.pullEvent()
				if eventType == "remote_peripheral_add" then
					print("adding peripheral = ", peripheralName)
					local peripheralData = remotePeripherals:GetAllData(peripheralName)
					if peripheralTypes.list[peripheralData.type] then
						peripheralTypes.add(peripheralData.type, peripheralName)
					end
					if peripheralData.sources then
						for source, _ in pairs(peripheralData.sources) do
							if sourceTypes.list[source] then
								sourceTypes.add(source, peripheralName)
							end
						end
					end
				elseif eventType == "remote_peripheral_remove" then
					for peripheralType, peripheralTypeData in pairs(peripheralTypes.list) do
						if peripheralTypeData.list[peripheralName] then
							peripheralTypes.remove(peripheralType, peripheralName)
						end
					end
					for sourceType, sourceTypeData in pairs(sourceTypes.list) do
						if sourceTypeData.list[peripheralName] then
							sourceTypes.remove(sourceType, peripheralName)
						end
					end
				end
			end
		end

		local function main()

			selectionWindow:SetDrawn(true)

			local UPDATE_INTERVAL = 1
			
			local updateTimer = os.startTimer(0)
			local nullClickTime, nullClickButton = -math.huge, false
			while true do
				local event = {os.pullEvent()}
				guiHandler:HandleEvent(event)
				if event[1] == "glasses_capture" then
					selectionWindow:SetVisible(true)
					for _, window in pairs(windowHandler:GetAllWindows()) do
						window:SetOpacity(1)
					end
				elseif event[1] == "glasses_release" then
					selectionWindow:SetVisible(false)
					for _, window in pairs(windowHandler:GetAllWindows()) do
						window:SetOpacity(0.75)
					end
				elseif event[1] == "glasses_mouse_down" then
					local newClickTime = os.clock()
					if nullClickButton == event[5] and newClickTime - nullClickTime < 0.25 then
						if nullClickButton == 0 then
							-- exit capture mode
							local capture = surfaceHandler:GetCapture()
							if capture then
								capture.stopCapturing()
							end
						elseif nullClickButton == 1 then
							-- reset window positions to centre of the screen
							for _, window in pairs(windowHandler:GetAllWindows()) do
								window:SetX(-(window:GetWidth()/2))
								window:SetY(-(window:GetHeight()/2))
							end
						end
						nullClickTime, nullClickButton = -math.huge, false
					else
						if event[5] == 1 then
							if peripheralTypes.listWindow:GetVisible() and peripheralTypes.selectedTypeList then
								peripheralTypes.selectedTypeList:SetVisible(false)
								peripheralTypes.selectedTypeList:SetClickable(false)
								peripheralTypes.selectedTypeList = false
							elseif sourceTypes.listWindow:GetVisible() and sourceTypes.selectedTypeList then
								sourceTypes.selectedTypeList:SetVisible(false)
								sourceTypes.selectedTypeList:SetClickable(false)
								sourceTypes.selectedTypeList = false
							else
								peripheralTypes.listWindow:SetVisible(false)
								peripheralTypes.listWindow:SetClickable(false)
								sourceTypes.listWindow:SetVisible(false)
								sourceTypes.listWindow:SetClickable(false)
							end
						end
					end
					nullClickTime = newClickTime
					nullClickButton = event[5]
				elseif event[1] == "timer" and event[2] == updateTimer then
					for _, peripheralData in pairs(peripheralTypes.list) do
						for name, object in pairs(peripheralData.list) do
							local window = windowHandler:GetWindow(object.windowID)
							if object.backgroundUpdate or (window and window:GetDrawn()) then
								peripheralData.update(name, object)
							end
						end
					end
					for _, sourceData in pairs(sourceTypes.list) do
						for name, object in pairs(sourceData.list) do
							local window = windowHandler:GetWindow(object.windowID)
							if object.backgroundUpdate or (window and window:GetDrawn()) then
								sourceData.update(name, object)
							end
						end
					end
					updateTimer = os.startTimer(UPDATE_INTERVAL)
				end
			end
		end
		
		parallel.waitForAny(main, peripheralChecker)
	end
end

local handler = tiles.newMultiSurfaceHandler(bridge, newPlayerHandler)

parallel.waitForAny(function() handler:Run() end, function() remotePeripherals:Run() end)