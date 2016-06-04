if not guiTiles then
	error("this API requires guiTiles to work")
end

local charOffset = {
	["!"] = 2, ["'"] = 2, ["("] = 1, [")"] = 1, ["*"] = 1, [","] = 2, ["."] = 2, [":"] = 2,
	[";"] = 2,	["<"] = 1, [">"] = 1, ["I"] = 1, ["["] = 1, ["["] = 1, ["`"] = 2, ["f"] = 1,
	["i"] = 2, ["k"] = 1, ["l"] = 2, ["t"] = 1, ["{"] = 1, ["|"] = 2, ["}"] = 1,
}

local string_sub = string.sub
local string_rep = string.rep
local string_gsub = string.gsub
local string_find = string.find
local table_concat = table.concat
local table_insert = table.insert

local nullChar = "\000"
local nullPattern = "[^\000]+"

local CCC_TO_RGB = {
	[colours.white] = 0xf0f0f0,
	[colours.orange] = 0xf2b233,
	[colours.magenta] = 0xe57fd8,
	[colours.lightBlue] = 0x99b2f2,
	[colours.yellow] = 0xdede6c,
	[colours.lime] = 0x7fcc19,
	[colours.pink] = 0xf2b2cc,
	[colours.grey] = 0x4c4c4c,
	[colours.lightGrey] = 0x999999,
	[colours.cyan] = 0x4c99b2,
	[colours.purple] = 0xb266e5,
	[colours.blue] = 0x3366cc,
	[colours.brown] = 0x7f664c,
	[colours.green] = 0x57a64e,
	[colours.red] = 0xcc4c4c,
	[colours.black] = 0x000000,
}

local RGB_TO_CCC = {}
for ccCol, glassesRGB in pairs(CCC_TO_RGB) do
	RGB_TO_CCC[glassesRGB] = ccCol
end

local HEX_COLOUR = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}
local HEX_TO_RGB = {}
for i = 1, 16 do
	HEX_TO_RGB[HEX_COLOUR[i]] = CCC_TO_RGB[2^(i-1)]
end

local RGB_TO_HEX = {}
for hex, rgb in pairs(HEX_TO_RGB) do
	RGB_TO_HEX[rgb] = hex
end

function new(tile, playerUUID, ID, xOffset, yOffset, zOffset, startWidth, startHeight)

	-- check args
	
	local playerUUID = playerUUID
	
	local tile = tile
	tile:SetX(xOffset or 0)
	tile:SetY(yOffset or 0)
	tile:SetZ(zOffset or 1)
	
	local backgroundTile = tile:AddSubTile(0, 0, 0)
	
	local function windowOnKeyDown(tile, object, keyCode, keyChar, isRepeat)
		os.queueEvent("glasses_custom_event", "unknown", ID, playerUUID, "key", keyCode, isRepeat)
		if keyChar then
			os.queueEvent("glasses_custom_event", "unknown", ID, playerUUID, "char", keyChar)
		end
	end
	backgroundTile:SetOnKeyDown(windowOnKeyDown)

	local function windowOnKeyUp(tile, object, keyCode)
		os.queueEvent("glasses_custom_event", "unknown", ID, playerUUID, "key_up", keyCode, isRepeat)
	end
	backgroundTile:SetOnKeyUp(windowOnKeyUp)
	
	local textTile = tile:AddSubTile(0, 0, 1)
	textTile:SetClickable(false)
			
	local toolbar = tile:AddSubTile(0, 0, 1)

	local width, height = 0, 0
	local coords = {}
	local windowCursor = textTile:AddText(0, 0, "_", 0xffffff)
	windowCursor:SetVisible(false)
	windowCursor:SetZ(1)
	
	local bezelColour = 0xdcd56c
	local topBezel = tile:AddBox(-6, -9, (width + 2)*6, 9, bezelColour, 1)
	local bottomBezel = tile:AddBox(-6, height*9, (width + 2)*6, 9, bezelColour, 1)
	local leftBezel = tile:AddBox(-6, 0, 6, height*9, bezelColour, 1)
	local rightBezel = tile:AddBox(width*6, 0, 6, height*9, bezelColour, 1)
	local function bezelDrag(object, button, deltaX, deltaY, actualDeltaX, actualDeltaY)
		tile:SetX(tile:GetX() + actualDeltaX)
		tile:SetY(tile:GetY() + actualDeltaY)
	end
	topBezel:SetOnDrag(bezelDrag)
	bottomBezel:SetOnDrag(bezelDrag)
	leftBezel:SetOnDrag(bezelDrag)
	rightBezel:SetOnDrag(bezelDrag)
	
	local function drawTextObject(xPos, yPos, text, textColour)
		return textTile:AddText((xPos-1)*6 + (charOffset[text] or 0), (yPos-1)*9, text, textColour)
	end
	
	local lastClickX, lastClickY, lastClickButton, lastClickCoordX, lastClickCoordY
	local function drawBackgroundObject(xPos, yPos, backgroundColour)
		local backgroundObject = backgroundTile:AddBox((xPos-1)*6, (yPos-1)*9, 6, 9, backgroundColour, 1)
		backgroundObject:SetOnScroll(
			function(object, scrollDir)
				os.queueEvent("glasses_custom_event", "unknown", ID, playerUUID, "mouse_scroll", -scrollDir/math.abs(scrollDir), xPos, yPos)
			end
		)
		backgroundObject:SetOnClick(
			function(object, button, relX, relY)
				lastClickX = (xPos - 1)*6 + relX
				lastClickY = (yPos - 1)*9 + relY
				lastClickButton = button + 1
				lastClickCoordX, lastClickCoordY = xPos, yPos
				os.queueEvent("glasses_custom_event", "unknown", ID, playerUUID, "mouse_click", button + 1, xPos, yPos)
			end
		)
		backgroundObject:SetOnDrag(
			function(object, button, deltaX, deltaY)
				lastClickX, lastClickY = lastClickX + deltaX, lastClickY + deltaY
				local newCoordX = math.ceil(lastClickX / 6)
				local newCoordY = math.ceil(lastClickY / 9)
				if newCoordX >= 1 and newCoordX <= width and newCoordY >= 1 and newCoordY <= height then
					lastClickCoordX, lastClickCoordY = newCoordX, newCoordY
					os.queueEvent("glasses_custom_event", "unknown", ID, playerUUID, "mouse_drag", lastClickButton, lastClickCoordX, lastClickCoordY)
				end
			end
		)
		backgroundObject:SetOnRelease(
			function()
				os.queueEvent("glasses_custom_event", "unknown", ID, playerUUID, "mouse_up", lastClickButton, lastClickCoordX, lastClickCoordY)
			end
		)
		--set click release scoll and drag functions here
		return backgroundObject
	end

	local function updateCursor(cursorX, cursorY, cursorBlink, cursorColour)
		windowCursor:SetX((cursorX-1)*6)
		windowCursor:SetY((cursorY-1)*9)
		windowCursor:SetVisible(cursorBlink)
		windowCursor:SetColor(cursorColour)
	end
		
	local function addCoord(xPos, yPos, text, textColour, backgroundColour)
		if not coords[yPos] then
			coords[yPos] = {}
		end
		if not coords[yPos][xPos] then
			coords[yPos][xPos] = {
				drawTextObject(xPos, yPos, text, textColour),
				drawBackgroundObject(xPos, yPos, backgroundColour),
			}
			return true
		end
		return false -- already exists
	end
	
	local function updateCoord(xPos, yPos, text, textColour, backgroundColour)
		if coords[yPos] and coords[yPos][xPos] then
			local textObject = coords[yPos][xPos][1]
			textObject:SetText(text)
			textObject:SetColor(textColour)
			textObject:SetX((xPos-1)*6 + (charOffset[text] or 0))
			local background = coords[yPos][xPos][2]
			background:SetColor(backgroundColour)
			return true
		end
		return false
	end
	local function removeCoord(xPos, yPos)
		if coords[yPos] and coords[yPos][xPos] then
			local coord = coords[yPos][xPos]
			coord[1]:Delete()
			coord[2]:Delete()
			coords[yPos][xPos] = nil
			if not next(coords[yPos]) then
				coords[yPos] = nil
			end
			return true
		end
		return false
	end
	
	local currentTextColour = CCC_TO_RGB[colours.white]
	local currentBackgroundColour = CCC_TO_RGB[colours.black]
	
	local updateLines = {}
	local updateCursorX = 1
	local updateCursorY = 1
	local updateCursorBlink = false
	
	local activeLines = {}
	local activeCursorX = 1
	local activeCursorY = 1
	local activeCursorBlink = false
	
	local hasUpdates = false
	
	local nullLine
	local emptySpaceLine
	local emptyColourLines = {}
	
	local function updateCursor()
		activeCursorX, activeCursorY, activeCursorBlink = updateCursorX, updateCursorY, updateCursorBlink
		windowCursor:SetX((activeCursorX-1)*6)
		windowCursor:SetY((activeCursorY-1)*9)
		windowCursor:SetVisible(activeCursorBlink and activeCursorX >= 1 and activeCursorX <= width and activeCursorY >= 1 and activeCursorY <= height)
		windowCursor:SetColor(currentTextColour)
	end
	
	local endX, line, clippedText, clippedTextColour, clippedBackgroundColour
	local clipStartX, clipEndX
	local oldText, oldTextColour, oldBackgroundColour
	local newText, newTextColour, newBackgroundColour
	local oldEndX, oldStartX
	local function updateBlit(text, textColour, backgroundColour, length)
		endX = updateCursorX + length - 1
		if updateCursorY >= 1 and updateCursorY <= height then
			if updateCursorX <= width and endX >= 1 then
				-- Modify line
				line = updateLines[updateCursorY]
				if updateCursorX == 1 and endX == width then
					line[1] = text
					line[2] = textColour
					line[3] = backgroundColour
				else
					if updateCursorX < 1 then
						clipStartX = 1 - updateCursorX + 1
						clipEndX = width - updateCursorX + 1
						clippedText = string_sub(text, clipStartX, clipEndX)
						clippedTextColour = string_sub(textColour, clipStartX, clipEndX)
						clippedBackgroundColour = string_sub(backgroundColour, clipStartX, clipEndX)
					elseif endX > width then
						clipEndX = width - updateCursorX + 1
						clippedText = string_sub(text, 1, clipEndX)
						clippedTextColour = string_sub(textColour, 1, clipEndX)
						clippedBackgroundColour = string_sub(backgroundColour, 1, clipEndX)
					else
						clippedText = text
						clippedTextColour = textColour
						clippedBackgroundColour = backgroundColour
					end

					oldText, oldTextColour, oldBackgroundColour = line[1], line[2], line[3]
					if updateCursorX > 1 then
						oldEndX = updateCursorX - 1
						newText = string_sub(oldText, 1, oldEndX)..clippedText
						newTextColour = string_sub(oldTextColour, 1, oldEndX)..clippedTextColour
						newBackgroundColour = string_sub(oldBackgroundColour, 1, oldEndX)..clippedBackgroundColour
					else
						newText = clippedText
						newTextColour = clippedTextColour
						newBackgroundColour = clippedBackgroundColour
					end
					if endX < width then
						oldStartX = endX + 1
						newText = newText..string_sub(oldText, oldStartX, width)
						newTextColour = newTextColour..string_sub(oldTextColour, oldStartX, width)
						newBackgroundColour = newBackgroundColour..string_sub(oldBackgroundColour, oldStartX, width)
					end

					line[1] = newText
					line[2] = newTextColour
					line[3] = newBackgroundColour
				end
			end
		end

		-- Move and redraw cursor
		updateCursorX = updateCursorX + length
		hasUpdates = true
	end

	local function combineLines(updateLine, activeLine)
		local segments = {}
		local currentX = 1
		local startX, endX = string_find(updateLine, nullPattern, currentX)
		while startX do
			if startX > currentX then
				table_insert(segments, string_sub(activeLine, currentX, startX - 1))
			end
			table_insert(segments, string_sub(updateLine, startX, endX))
			currentX = endX + 1
			startX, endX = string_find(updateLine, nullPattern, currentX)
		end
		if currentX <= width then
			table_insert(segments, string_sub(activeLine, currentX, width))
		end
		return table_concat(segments)
	end
	
	local isLocked = false
	local glassWindow = {
		getTile = function()
			return tile
		end,

		getPlayerUUID = function()
			return playerUUID
		end,
		setPlayerUUID = function(newPlayerUUID)
			playerUUID = newPlayerUUID
		end,
	
		getDrawn = function()
			return tile:GetDrawn()
		end,
		setDrawn = function(drawn)
			return tile:SetDrawn(drawn)
		end,
		
		getAlignment = function()
			return tile:GetScreenAnchor()
		end,
		setAlignment = function(horizontal, vertical)
			return tile:SetScreenAnchor(horizontal, vertical)
		end,
	
		getVisible = function()
			return toolbar:GetVisible()
		end,
		setVisible = function(visible)
			if type(visible) == "boolean" then
				tile:SetVisible(visible or isLocked)
				tile:SetClickable(visible or isLocked)
				toolbar:SetVisible(visible)
				toolbar:SetClickable(visible)
				return true
			end
			return false
		end,
		
		getOpacity = function()
			return backgroundTile:GetOpacity()
		end,
		setOpacity = function(opacity)
			if type(opacity) == "number" and opacity >= 0 and opacity <= 1 then
				return backgroundTile:SetOpacity(opacity)
			end
			return false
		end,
	
		getOffset = function()
			return tile:GetX(), tile:GetY(), tile:GetZ()
		end,
		setOffset = function(xOffset, yOffset, zOffset)
			if tonumber(xOffset) then tile:SetX(tonumber(xOffset)) end
			if tonumber(yOffset) then tile:SetY(tonumber(yOffset)) end
			if tonumber(zOffset) then tile:SetZ(math.min(500, math.max(1, math.floor(tonumber(zOffset))))) end
			return true
		end,
		
		getSize = function()
			return width, height
		end,
		setSize = function(newWidth, newHeight)
			local newWidth = math.max(0, math.floor(tonumber(newWidth) or width))
			local newHeight = math.max(0, math.floor(tonumber(newHeight) or height))
			if newWidth ~= width or newHeight ~= height then
				nullLine = string_rep(nullChar, newWidth)
				emptySpaceLine = string_rep(" ", newWidth)
				for rgb, hex in pairs(RGB_TO_HEX) do
					emptyColourLines[rgb] = string_rep(hex, newWidth)
				end
				
				if newHeight < height then
					-- remove excess lines
					for yPos = newHeight + 1, height do
						updateLines[yPos] = nil
						activeLines[yPos] = nil
						for xPos = 1, width do
							removeCoord(xPos, yPos)
						end
					end
				elseif newHeight > height then
					-- add new lines
					for yPos = height + 1, newHeight do
						updateLines[yPos] = {
							nullLine,
							nullLine,
							nullLine,
						}
						activeLines[yPos] = {
							emptySpaceLine,
							emptyColourLines[currentTextColour],
							emptyColourLines[currentBackgroundColour],
						}
						for xPos = 1, newWidth do
							addCoord(xPos, yPos, " ", currentTextColour, currentBackgroundColour)
						end
					end
				end
				
				if newWidth < width then
					-- reduce line length for existing lines only
					local updateLine, activeLine
					for yPos = 1, math.min(height, newHeight) do
						updateLine, activeLine = updateLines[yPos], activeLines[yPos]
						updateLines[yPos] = {
							string_sub(updateLine[1], 1, newWidth),
							string_sub(updateLine[2], 1, newWidth),
							string_sub(updateLine[3], 1, newWidth),
						}
						activeLines[yPos] = {
							string_sub(activeLine[1], 1, newWidth),
							string_sub(activeLine[2], 1, newWidth),
							string_sub(activeLine[3], 1, newWidth),
						}
						for xPos = newWidth + 1, width do
							removeCoord(xPos, yPos)
						end
					end
				elseif newWidth > width then
					-- extend line length for existing lines only
					local updateLine, activeLine
					
					local partialNullLine = string_rep(nullChar, newWidth - width)
					local partialEmptySpaceLine = string_rep(" ", newWidth - width)
					local partialEmptyTextColourLine = string_rep(RGB_TO_HEX[currentTextColour], newWidth - width)
					local partialEmptyBackgroundColourLine = string_rep(RGB_TO_HEX[currentBackgroundColour], newWidth - width)
					
					for yPos = 1, math.min(height, newHeight) do
						updateLine, activeLine = updateLines[yPos], activeLines[yPos]
						updateLines[yPos] = {
							updateLine[1]..partialNullLine,
							updateLine[2]..partialNullLine,
							updateLine[3]..partialNullLine,
						}
						activeLines[yPos] = {
							activeLine[1]..partialEmptySpaceLine,
							activeLine[2]..partialEmptyTextColourLine,
							activeLine[3]..partialEmptyBackgroundColourLine,
						}
						for xPos = width + 1, newWidth do
							addCoord(xPos, yPos, " ", currentTextColour, currentBackgroundColour)
						end
					end
				end
				-- redraw bezel
				updateCursor()
				topBezel:SetWidth((newWidth + 2)*6)
				bottomBezel:SetWidth((newWidth + 2)*6)
				leftBezel:SetHeight(newHeight*9)
				rightBezel:SetHeight(newHeight*9)
				bottomBezel:SetY(newHeight*9)
				rightBezel:SetX(newWidth*6)
				
				width, height = newWidth, newHeight
				return true
			end
			return false
		end,
	
		hasUpdates = function()
			return hasUpdates
		end,
		pushUpdates = function()
			if hasUpdates then
				local currentX = 1
				local startX, endX
				local updateLine, activeLine
				local updateTextLine, updateTextColourLine, updateBackgroundColourLine
				local activeTextLine, activeTextColourLine, activeBackgroundColourLine
				local textSegments, textColourSegments, backgroundColourSegments
				local newText, newTextColour, newBackgroundColour
				for yPos = 1, height do
					updateLine = updateLines[yPos]
					updateTextLine = updateLine[1]
					startX, endX = string_find(updateTextLine, nullPattern, currentX) -- find first modified segment in this update line
					if startX then -- if we have one then proceed to push the updates to active
						activeLine = activeLines[yPos]
						textSegments, textColourSegments, backgroundColourSegments = {}, {}, {}
						updateTextColourLine, updateBackgroundColourLine = updateLine[2], updateLine[3]
						activeTextLine, activeTextColourLine, activeBackgroundColourLine = activeLine[1], activeLine[2], activeLine[3]
						repeat
							if startX > currentX then
								table_insert(textSegments, string_sub(activeTextLine, currentX, startX - 1))
								table_insert(textColourSegments, string_sub(activeTextColourLine, currentX, startX - 1))
								table_insert(backgroundColourSegments, string_sub(activeBackgroundColourLine, currentX, startX - 1))
							end
							--push changes to parent
							for xPos = startX, endX do
								newText = string_sub(updateTextLine, xPos, xPos)
								newTextColour = HEX_TO_RGB[string_sub(updateTextColourLine, xPos, xPos)] or currentTextColour
								newBackgroundColour = HEX_TO_RGB[string_sub(updateBackgroundColourLine, xPos, xPos)] or currentBackgroundColour
								updateCoord(xPos, yPos, newText, newTextColour, newBackgroundColour)
							end
							table_insert(textSegments, string_sub(updateTextLine, startX, endX))
							table_insert(textColourSegments, string_sub(updateTextColourLine, startX, endX))
							table_insert(backgroundColourSegments, string_sub(updateBackgroundColourLine, startX, endX))
							currentX = endX + 1
							startX, endX = string_find(updateTextLine, nullPattern, currentX)
						until not startX
						if currentX <= width then
							table_insert(textSegments, string_sub(activeTextLine, currentX, width))
							table_insert(textColourSegments, string_sub(activeTextColourLine, currentX, width))
							table_insert(backgroundColourSegments, string_sub(activeBackgroundColourLine, currentX, width))
						end
						activeLines[yPos] = {
							table_concat(textSegments),
							table_concat(textColourSegments),
							table_concat(backgroundColourSegments),
						}
						updateLines[yPos] = {
							nullLine,
							nullLine,
							nullLine,
						}
						currentX = 1
					end
				end
				updateCursor()
				hasUpdates = false
				return true
			end
			return false
		end,
	}
	
	local lockButton = guiTiles.addButton(toolbar, 0, -10, 0, "L", 0x57a64e, 0x7fcc19, 0xcc4c4c, 0xf2b233, 10, 10)
	local function onLockButtonRelease()
		isLocked = not isLocked
		if isLocked then
			lockButton:SetInactiveMainColour(0xcc4c4c)
			lockButton:SetInactiveTextColour(0xf2b233)
		else
			lockButton:SetInactiveMainColour(0x57a64e)
			lockButton:SetInactiveTextColour(0x7fcc19)
		end
	end
	lockButton:SetOnRelease(onLockButtonRelease)

	local opacityModifier = guiTiles.addSlider(toolbar, -10, 50, 1, 50, 10)
	opacityModifier:SetRotation(270)
	local function onSliderUpdate(percent)
		glassWindow.setOpacity(percent)
	end
	opacityModifier:SetOnChanged(onSliderUpdate)
	opacityModifier:SetVisible(false)
	opacityModifier:SetClickable(false)
	
	local opacityButton = guiTiles.addButton(toolbar, 10, -10, 0, "S", 0xdede6c, 0x000000, 0x57a64e, 0x000000, 10, 10)
	local function onOpacityButtonRelease()
		opacityModifier:SetClickable(not opacityModifier:GetClickable())
		opacityModifier:SetVisible(not opacityModifier:GetVisible())
	end
	opacityButton:SetOnRelease(onOpacityButtonRelease)

	local terminateText = toolbar:AddText(25, -5, "T", 0xf2b233)
	terminateText:SetZ(1)
	terminateText:SetObjectAnchor("MIDDLE", "MIDDLE")
	terminateText:SetClickable(false)
	local terminateBG = toolbar:AddBox(20, -10, 10, 10, 0xcc4c4c, 1)
	local function terminateClick()
		terminateBG:SetColor(0xdede6c)
		terminateBG:SetUserdata(os.clock())
	end
	local function terminateRelease()
		terminateBG:SetColor(0xcc4c4c)
		local terminateClickTime = terminateBG:GetUserdata()
		if terminateClickTime and os.clock() - terminateClickTime > 0.5 then
			os.queueEvent("glasses_custom_event", "unknown", ID, playerUUID, "terminate")
		end
	end
	terminateBG:SetOnClick(terminateClick)
	terminateBG:SetOnRelease(terminateRelease)
	
	local sizeModifier = toolbar:AddSubTile(51*6, 19*9, 1)
	
	local sizeModifierText = sizeModifier:AddText(0, 0, "x", 0x000000)
	sizeModifierText:SetZ(1)
	sizeModifierText:SetClickable(false)
	
	local sizeModifierBox = sizeModifier:AddBox(0, 0, 6, 9, 0xffffff, 1)
	local sizeClickX, sizeClickY, sizeClickTime, sizeClickButton = false, false, false, false
	local function sizeClick(object, button, clickX, clickY)
		local xPos, yPos = sizeModifier:GetX(), sizeModifier:GetY()
		sizeClickX, sizeClickY = xPos + clickX, yPos + clickY
		if button == 0 then
			sizeModifierBox:SetColor(0x57a64e)
		elseif button == 1 then
			sizeModifierBox:SetColor(0xcc4c4c)
		end
		local newClickTime = os.clock()
		if sizeClickTime and sizeClickButton == button and newClickTime - sizeClickTime < 0.25 then
			if button == 0 then
				glassWindow.setSize(51, 19)
				sizeModifier:SetX(51*6)
				sizeModifier:SetY(19*9)
				os.queueEvent("glasses_custom_event", "unknown", ID, playerUUID, "term_resize")
			elseif button == 1 then
				tile:SetRotation(0)
				tile:SetScale(1)
			end
		end
		sizeClickTime = newClickTime
		sizeClickButton = button
	end
	local function sizeDrag(object, button, deltaX, deltaY)
		if button == 0 then -- left click
			sizeClickX, sizeClickY = sizeClickX + deltaX, sizeClickY + deltaY
			local newWidth = math.max(10, math.floor((sizeClickX)/6))
			local newHeight = math.max(6, math.floor((sizeClickY)/9))
			glassWindow.setSize(newWidth, newHeight)
			sizeModifier:SetX(newWidth*6)
			sizeModifier:SetY(newHeight*9)
			os.queueEvent("glasses_custom_event", "unknown", ID, playerUUID, "term_resize")
		elseif button == 1 then
			local newClickX, newClickY = sizeClickX + deltaX, sizeClickY + deltaY
			
			--rotation
			local prevRot = math.deg(math.atan2(sizeClickX, sizeClickY))
			local currRot = math.deg(math.atan2(newClickX, newClickY))
			tile:SetRotation((tile:GetRotation() - currRot + prevRot) % 360)
			
			--scale
			local prevLength = math.sqrt((sizeClickX*sizeClickX) + (sizeClickY*sizeClickY))
			local currLength = math.sqrt((newClickX*newClickX) + (newClickY*newClickY))
			local deltaPercent = currLength/prevLength
			tile:SetScale(tile:GetScale() * deltaPercent)
		end
	end
	local function sizeRelease()
		sizeClickX, sizeClickY = false, false
		sizeModifierBox:SetColor(0xffffff)
	end
	sizeModifierBox:SetOnClick(sizeClick)
	sizeModifierBox:SetOnDrag(sizeDrag)
	sizeModifierBox:SetOnRelease(sizeRelease)
	
	local glassWindowTerm = {
		write = function(text)
			local textType = type(text)
			if textType == "string" or textType == "number" then
				text = string_gsub(tostring(text), "%c", " ")
				local length = #text
				updateBlit(text, string_rep(RGB_TO_HEX[currentTextColour], length), string_rep(RGB_TO_HEX[currentBackgroundColour], length), length)
			end
		end,
		blit = function(text, textColour, backgroundColour)
			if type(text) ~= "string" or type(textColour) ~= "string" or type(backgroundColour) ~= "string" then
				error( "Expected string, string, string", 2 )
			end
			text = string_gsub(tostring(text), "%c", " ")
			local length = #text
			if #textColour ~= length or #backgroundColour ~= length then
				error( "Arguments must be the same length", 2 )
			end
			updateBlit(text, textColour, backgroundColour, length)
		end,
		clear = function()
			local emptyTextColour = emptyColourLines[currentTextColour]
			local emptyBackgroundColour = emptyColourLines[currentBackgroundColour]
			for yPos = 1, height do
				updateLines[yPos] = {
					emptySpaceLine,
					emptyTextColour,
					emptyBackgroundColour,
				}
			end
			hasUpdates = true
		end,
		clearLine = function()
			if updateLines[updateCursorY] then
				updateLines[updateCursorY] = {
					emptySpaceLine,
					emptyColourLines[currentTextColour],
					emptyColourLines[currentBackgroundColour],
				}
				hasUpdates = true
			end
		end,
		getCursorPos = function()
			return updateCursorX, updateCursorY
		end,
		setCursorPos = function(xPos, yPos)
			updateCursorX = math.floor(tonumber(xPos) or updateCursorX)
			updateCursorY = math.floor(tonumber(yPos) or updateCursorY)
			hasUpdates = true
		end,
		setCursorBlink = function(blink)
			if type(blink) == "boolean" then
				updateCursorBlink = blink
				hasUpdates = true
			end
		end,
		isColour = function()
			return true
		end,
		getSize = function()
			return width, height
		end,
		scroll = function(noOfLines)
			local n = math.floor(tonumber(noOfLines) or 0)
			if n ~= 0 and height > 0 then
				local emptyTextColour = emptyColourLines[currentTextColour]
				local emptyBackgroundColour = emptyColourLines[currentBackgroundColour]
				local updateLine, activeLine
				for yPos = (n > 0 and 1) or height, (n < 0 and 1) or height, n/math.abs(n) do
					updateLine = updateLines[yPos + n]
					activeLine = activeLines[yPos + n]
					if updateLine then
						updateLines[yPos] = {
							combineLines(updateLine[1], activeLine[1]),
							combineLines(updateLine[2], activeLine[2]),
							combineLines(updateLine[3], activeLine[3]),
						}
					else
						updateLines[yPos] = {
							emptySpaceLine,
							emptyTextColour,
							emptyBackgroundColour,
						}
					end
				end
				hasUpdates = true
			end
		end,
		setTextColour = function(colour)
			local newColour = CCC_TO_RGB[tonumber(colour)]
			if newColour then
				currentTextColour = newColour
				hasUpdates = true
			end
		end,
		getTextColour = function()
			return RGB_TO_CCC[currentTextColour]
		end,
		setBackgroundColour = function(colour)
			local newColour = CCC_TO_RGB[tonumber(colour)]
			if newColour then
				currentBackgroundColour = newColour
			end
		end,
		getBackgroundColour = function()
			return RGB_TO_CCC[currentBackgroundColour]
		end,
	}
	glassWindowTerm.isColor = glassWindowTerm.isColour
	glassWindowTerm.setTextColor = glassWindowTerm.setTextColour
	glassWindowTerm.getTextColor = glassWindowTerm.getTextColour
	glassWindowTerm.setBackgroundColor = glassWindowTerm.setBackgroundColour
	glassWindowTerm.getBackgroundColor = glassWindowTerm.getBackgroundColour
	
	glassWindow.term = glassWindowTerm
	
	glassWindow.setSize(startWidth, startHeight)
	
	return glassWindow
	
end
