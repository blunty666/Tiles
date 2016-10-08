local tArgs = {...}
local bridge
if type(tArgs[1]) == "string" and peripheral.getType(tArgs[1]) == "openperipheral_bridge" then
	bridge = peripheral.wrap(tArgs[1])
	bridge.clear()
else
	error("could not find bridge on side: "..tostring(tArgs[1]))
end

do -- API installing / loading
	local program = fs.getDir(shell.getRunningProgram())

	local function get(url)
		local response = http.get(url)			
		if response then
			local fileData = response.readAll()
			response.close()
			return fileData
		end
		return false
	end

	local function save(fileData, path)
		local handle = fs.open(path, "w")
		if handle then
			handle.write(fileData)
			handle.close()
			return true
		else
			return false
		end
	end

	local function fetch(url, path)
		local fileData = get(url)			
		if fileData then
			if save(fileData, path) then
				return true
			else
				printError("Save failed: ", path)
			end
		else
			printError("Download failed: ", url)
		end
		return false
	end

	local apiList = {
		{"tiles", "https://raw.githubusercontent.com/blunty666/Tiles/master/tiles.lua"},
		{"guiTiles", "https://raw.githubusercontent.com/blunty666/Tiles/master/apis/guiTiles.lua"},
		{"glassWindow", "https://raw.githubusercontent.com/blunty666/Tiles/master/apis/glassWindow.lua"},
	}

	for _, api in ipairs(apiList) do
		local apiName, apiURL = unpack(api)
		local apiPath = fs.combine(program, apiName)
		if not _G[apiName] then -- api not loaded already
			if not fs.exists(apiPath) then -- api file does not exist
				print("Downloading API: "..apiName)
				if not fetch(apiURL, apiPath) then
					printError("Could not load API: "..apiName)
					return
				end
			elseif fs.isDir(apiPath) then -- there is an invalid directory
				printError("Invalid directory at: "..apiPath)
				printError("Could not load API: "..apiName)
				return
			end
			if not os.loadAPI(apiPath) then
				printError("Could not load API: "..apiName)
				return
			end
		end
	end
end

local function newPlayerSurfaceHandler(playerUUID, surfaceHandler)
	
	local guiHandler = guiTiles.newGuiHandler(surfaceHandler)

	local windows = {
		list = {},
		windowToThread = {},
		orderedList = {},
	}
	windows.new = function(playerUUID, threadID, tile, width, height, xOffset, yOffset, zOffset)
		local uniqueID
		repeat
			uniqueID = math.random(0, 9999)
		until not windows.list[uniqueID]
		
		local redirect = glassWindow.new(tile, playerUUID, uniqueID, xOffset, yOffset, zOffset, width, height)
		
		windows.list[uniqueID] = redirect
		table.insert(windows.orderedList, uniqueID)
		redirect.setOffset(nil, nil, 5*#windows.orderedList)
		windows.windowToThread[uniqueID] = threadID
		return redirect
	end
	windows.reorder = function()
		for i, windowID in ipairs(windows.orderedList) do
			windows.list[windowID].setOffset(nil, nil, 5*i)
		end
	end
	windows.toFront = function(windowID)
		for i, winID in ipairs(windows.orderedList) do
			if winID == windowID then
				table.insert(windows.orderedList, table.remove(windows.orderedList, i))
				windows.reorder()
				return true
			end
		end
		return false
	end
	windows.toBack = function(windowID)
		for i, winID in ipairs(windows.orderedList) do
			if winID == windowID then
				table.insert(windows.orderedList, 1, table.remove(windows.orderedList, i))
				windows.reorder()
				return true
			end
		end
		return false
	end
	windows.delete = function(windowID)
		local window = windows.list[windowID]
		if window then
			local tile = window.getTile()
			tile:Delete()
			windows.list[windowID] = nil
			windows.windowToThread[windowID] = nil
			for i, winID in ipairs(windows.orderedList) do
				if winID == windowID then
					table.remove(windows.orderedList, i)
					windows.reorder()
					break
				end
			end
			return true
		end
		return false
	end

	local threads = {
		list = {},
		orderedList = {},
	}
	threads.new = function(func, terminal)
		local uniqueID
		repeat
			uniqueID = math.random(0, 9999)
		until not threads.list[uniqueID]
		
		local thread = {
			ID = uniqueID,
			running = true,
			filter = nil,
			thread = coroutine.create(func),
			term = terminal,
		}
		
		threads.list[uniqueID] = thread
		table.insert(threads.orderedList, uniqueID)
		return thread
	end
	threads.resume = function(threadInfo, eventType, ...)
		if threadInfo.running then
			if not threadInfo.filter or eventType == threadInfo.filter or eventType == "terminate" then
				threadInfo.filter = nil

				local prevTerm = threadInfo.term and term.redirect(threadInfo.term)
				local ok, passback = coroutine.resume(threadInfo.thread, eventType, ...)
				if prevTerm then
					term.redirect(prevTerm)
				end

				if not ok and coroutine.status(threadInfo.thread) == "dead" then
					threadInfo.running = false
					printError(passback)
				elseif coroutine.status(threadInfo.thread) == "dead" then
					threadInfo.running = false
				else
					threadInfo.filter = passback
				end
			end
		end
	end
	threads.launch = function(path, xOffset, yOffset, visible)
		local thread
		local fnFile, err = loadfile(path)
		if fnFile then
			local tEnv = {
				shell = shell,
			}
			setmetatable( tEnv, { __index = _G } )
			setfenv( fnFile, tEnv )
			thread = threads.new(fnFile, nil)
		else
			error(err)
		end
		
		local tile = surfaceHandler:AddTile(0, -50, 1)
		tile:SetScreenAnchor("MIDDLE", "MIDDLE")
		
		local window = windows.new(playerUUID, thread.ID, tile, 51, 19, xOffset, yOffset, 1)
		
		thread.term = window.term
		threads.resume(thread)
		
		window.setVisible(visible)
		window.setDrawn(true)
		
		return thread, window
	end

	local function main()

		threads.launch("rom/programs/advanced/multishell", -(51*6/2), -(19*9/2), false)
			
		local activeWindowID = windows.orderedList[#windows.orderedList] or false
		local nullClickTime, nullClickButton = -math.huge, false

		local eventHandlers = {
			glasses_capture = function(event)
				for _, window in pairs(windows.list) do
					window.setVisible(true)
				end
			end,
			glasses_release = function(event)
				for _, window in pairs(windows.list) do
					window.setVisible(false)
				end
			end,
			glasses_mouse_down = function(event)
				local newClickTime = os.clock()
				if nullClickButton == event[5] and newClickTime - nullClickTime < 0.25 then
					if nullClickButton == 0 then
						for _, window in pairs(windows.list) do
							window.setVisible(false)
						end
						local capture = surfaceHandler:GetCapture()
						if capture then
							capture.stopCapturing()
						end
					elseif nullClickButton == 1 then
						threads.launch("rom/programs/advanced/multishell", -(51*6/2) + math.random(-30, 30), -(19*9/2) + math.random(-30, 30), true)
					end
					nullClickTime, nullClickButton = -math.huge, false
				end
				nullClickTime = newClickTime
				nullClickButton = event[5]
			end,
			glasses_custom_event = function(event)
				-- glasses_custom_event - "unknown" - windowID - playerUUID - {event details (...)}
				if activeWindowID ~= event[3] then
					windows.toFront(event[3])
					activeWindowID = event[3]
				end
				local threadID = windows.windowToThread[event[3]]
				if threadID then
					local thread = threads.list[threadID]
					if thread then
						threads.resume(thread, unpack(event, 5))
					end
				end
			end,
		}
		local event = {}
		local handler
		while true do
			guiHandler:HandleEvent(event)
			
			handler = eventHandlers[ event[1] ]
			if handler then -- pass event to handler
				handler(event)
			else -- resume all threads with the event
				for _, thread in pairs(threads.list) do
					threads.resume(thread, unpack(event))
				end
			end
			
			-- check for dead threads
			local newThreadOrderedList = {}
			for _, threadID in ipairs(threads.orderedList) do
				local thread = threads.list[threadID]
				if not thread then
					
				elseif not thread.running then
					-- find all windows belonging to this thread
					local threadWindows = {}
					for windowID, _threadID in pairs(windows.windowToThread) do
						if threadID == _threadID then
							table.insert(threadWindows, windowID)
						end
					end
					-- delete windows
					for _, windowID in ipairs(threadWindows) do
						windows.delete(windowID)
					end
					-- remove thread
					threads.list[threadID] = nil
				
					activeWindowID = windows.orderedList[#windows.orderedList] or false
				else
					table.insert(newThreadOrderedList, threadID)
				end
			end
			threads.orderedList = newThreadOrderedList
			
			-- check if all threads are dead	
			if #newThreadOrderedList == 0 then
				-- stop capturing
				local capture = surfaceHandler:GetCapture()
				if capture then
					capture.stopCapturing() -- if connected
				end
				-- create new thread with window
				threads.launch("rom/programs/advanced/multishell", -(51*6/2), -(19*9/2), false)
			end
				
			event = {coroutine.yield()}
		end
	end

	local function pushUpdates()
		while true do
			for ID, window in pairs(windows.list) do
				if window.hasUpdates() then
					window.pushUpdates()
				end
			end
			coroutine.yield()
		end
	end
	
	return function() parallel.waitForAny(main, pushUpdates) end
end

local handler = tiles.newMultiSurfaceHandler(bridge, newPlayerSurfaceHandler)

handler:Run()
