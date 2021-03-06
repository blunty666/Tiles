if not tiles then
	error("this API requires tiles to work")
end

--===== UTILS =====--
local function makeMetatable(methodsTable)
	return {
		__index = function(t, k)
			return methodsTable[k] or t.tile[k]
		end,
	}
end

local function actualToRelative(object, xPos, yPos)
	local rot = math.rad(-object:GetActualRotation())
	local scale = object:GetTile():GetActualScale()
	return (xPos*math.cos(rot) - yPos*math.sin(rot))/scale, (yPos*math.cos(rot) + xPos*math.sin(rot))/scale
end

local function findObject(surfaceHandler, drawableID)
	local drawable = surfaceHandler:GetSurface().getObjectById(drawableID)
	if drawable then
		objectID = drawable.getUserdata()
		if objectID then
			return surfaceHandler:GetObject(objectID)
		end
	end
	return false
end

local function isIntegerWithinBounds(value, minVal, maxVal)
	return type(value) == "number" and value % 1 == 0 and value >= minVal and value <= maxVal
end

function makeDraggable(mainTile, dragObject)
	local function drag(obj, button, relX, relY, absX, absY)
		mainTile:SetX(mainTile:GetX() + absX)
		mainTile:SetY(mainTile:GetY() + absY)
	end
	dragObject:SetOnDrag(drag)
end

--===== FANCY TEXT =====--
do
	local fancyTextMethods = {
		GetTile = function(self)
			return self.tile
		end,
		GetAlpha = function(self)
			return self.main:GetAlpha()
		end,
		SetAlpha = function(self, alpha)
			if tiles.checkProperty.alpha(alpha) then
				self.main:SetAlpha(alpha)
				self.shadow:SetAlpha(alpha/3)
				return true
			end
			return false
		end,
		GetColor = function(self)
			return self.main:GetColor()
		end,
		SetColor = function(self, colour)
			if tiles.checkProperty.colour(colour) then
				self.main:SetColor(colour)
				self.shadow:SetColor(colour/3)
				return true
			end
			return false
		end,
		GetText = function(self)
			return self.main:GetText()
		end,
		SetText = function(self, text)
			if type(text) == "string" or type(text) == "number" then
				text = tostring(text)
				self.main:SetText(text)
				self.shadow:SetText(text)
				return true
			end
			return false
		end,
	}
	local fancyTextMetatable = makeMetatable(fancyTextMethods)

	local function addText(tile, xPos, yPos, zPos, text, colour, alpha)
		local text = tile:AddText(xPos, yPos, text, colour)
		text:SetZ(zPos)
		text:SetAlpha(alpha)
		text:SetClickable(false)
		return text
	end

	function addFancyText(tile, xPos, yPos, zPos, text, colour, alpha)
		local subTile = tile:AddSubTile(xPos, yPos, zPos)
		local fancyText = {
			tile = subTile,
			main = addText(subTile, 0, 0, 1, text, colour, alpha),
			shadow = addText(subTile, 1, 1, 0, text, colour/3, alpha/3),
		}
		return setmetatable(fancyText, fancyTextMetatable)
	end
end

--===== BUTTON =====--
do
	local buttonToVariable = {
		[0] = "leftClickEnabled",
		[1] = "rightClickEnabled",
		[2] = "middleClickEnabled",
	}
	local function buttonClick(button, clicked)
		button = button:GetUserdata()
		if not button.isPressed and button[buttonToVariable[clicked]] then
			button.main:SetColor(button.activeMainColour)
			button.text:SetColor(button.activeTextColour)
			button.isPressed = true
			if button.onClick then
				button.onClick(clicked)
			end
		end
	end
	local function buttonRelease(button, clicked)
		button = button:GetUserdata()
		if button.isPressed then
			button.main:SetColor(button.inactiveMainColour)
			button.text:SetColor(button.inactiveTextColour)
			button.isPressed = false
			if button[buttonToVariable[clicked]] and button.onRelease then
				button.onRelease(clicked)
			end
		end
	end

	local buttonMethods = {
		GetTile = function(self)
			return self.tile
		end,

		GetIsPressed = function(self)
			return self.isPressed
		end,
		SetIsPressed = function(self, boolean)
			if tiles.checkProperty.boolean(boolean) then
				if self.isPressed ~= boolean then
					if self.isPressed then
						self.main:SetColor(self.inactiveMainColour)
						self.text:SetColor(self.inactiveTextColour)
					else
						self.main:SetColor(self.activeMainColour)
						self.text:SetColor(self.activeTextColour)
					end
					self.isPressed = boolean
				end
				return true
			end
			return false
		end,
		
		GetText = function(self)
			return self.text:GetText()
		end,
		SetText = function(self, text)
			if tiles.checkProperty.string(text) then
				self.text:SetText(text)
				return true
			end
		end,

		GetInactiveMainColour = function(self)
			return self.inactiveMainColour
		end,
		SetInactiveMainColour = function(self, colour)
			if tiles.checkProperty.colour(colour) then
				self.inactiveMainColour = colour
				if not self.isPressed then
					self.main:SetColor(colour)
				end
				return true
			end
			return false
		end,
		GetActiveMainColour = function(self)
			return self.activeMainColour
		end,
		SetActiveMainColour = function(self, colour)
			if tiles.checkProperty.colour(colour) then
				self.activeMainColour = colour
				if self.isPressed then
					self.main:SetColor(colour)
				end
				return true
			end
			return false
		end,
		
		GetInactiveTextColour = function(self)
			return self.inactiveTextColour
		end,
		SetInactiveTextColour = function(self, colour)
			if tiles.checkProperty.colour(colour) then
				self.inactiveTextColour = colour
				if not self.isPressed then
					self.text:SetColor(colour)
				end
				return true
			end
			return false
		end,
		GetActiveTextColour = function(self)
			return self.activeTextColour
		end,
		SetActiveTextColour = function(self, colour)
			if tiles.checkProperty.colour(colour) then
				self.activeTextColour = colour
				if self.isPressed then
					self.text:SetColor(colour)
				end
				return true
			end
			return false
		end,
		
		GetLeftClickEnabled = function(self)
			return self.leftClickEnabled
		end,
		SetLeftClickEnabled = function(self, boolean)
			if tiles.checkProperty.boolean(boolean) then
				self.leftClickEnabled = boolean
				return true
			end
			return false
		end,
		GetMiddleClickEnabled = function(self)
			return self.middleClickEnabled
		end,
		SetMiddleClickEnabled = function(self, boolean)
			if tiles.checkProperty.boolean(boolean) then
				self.middleClickEnabled = boolean
				return true
			end
			return false
		end,
		GetRightClickEnabled = function(self)
			return self.rightClickEnabled
		end,
		SetRightClickEnabled = function(self, boolean)
			if tiles.checkProperty.boolean(boolean) then
				self.rightClickEnabled = boolean
				return true
			end
			return false
		end,
		
		GetOnClick = function(self)
			return self.onClick
		end,
		SetOnClick = function(self, func)
			if tiles.checkProperty.functionOrNil(func) then
				self.onClick = func
				return true
			end
			return false
		end,
		GetOnRelease = function(self)
			return self.onRelease
		end,
		SetOnRelease = function(self, func)
			if tiles.checkProperty.functionOrNil(func) then
				self.onRelease = func
				return true
			end
			return false
		end,
	}
	local buttonMetatable = makeMetatable(buttonMethods)

	function addButton(tile, xPos, yPos, zPos, text, inactiveMainColour, inactiveTextColour, activeMainColour, activeTextColour, width, height)
		local buttonTile = tile:AddSubTile(xPos, yPos, zPos)
		local button = {
			tile = buttonTile,
			
			inactiveMainColour = inactiveMainColour,
			activeMainColour = activeMainColour,
			
			inactiveTextColour = inactiveTextColour,
			activeTextColour = activeTextColour,
			
			leftClickEnabled = true,
			middleClickEnabled = true,
			rightClickEnabled = true,

			onClick = false,
			onRelease = false,
			
			isPressed = false,
		}
		
		local width = math.max(tiles.getStringWidth(text) + 2, (type(width) == "number" and width) or 0)
		local height = math.max(10, (type(height) == "number" and height) or 0)
		
		local buttonMain = buttonTile:AddBox(0, 0, width, height, button.inactiveMainColour, 1)
		buttonMain:SetOnClick(buttonClick)
		buttonMain:SetOnRelease(buttonRelease)
		buttonMain:SetUserdata(button)
		
		local buttonText = buttonTile:AddText(width/2, height/2, text, button.inactiveTextColour)
		buttonText:SetObjectAnchor("MIDDLE", "MIDDLE")
		buttonText:SetClickable(false)
		buttonText:SetZ(1)
		
		button.main = buttonMain
		button.text = buttonText
		
		return setmetatable(button, buttonMetatable)
	end
end

--===== SLIDER =====--
do
	local function sliderClick(object, button, clickX, clickY)
		local slider = object:GetUserdata()
		slider.currX = clickX
		local handleX = math.max(3, math.min(slider.width - 3, clickX))
		slider.handle:SetX(handleX)
		if slider.onChanged then
			slider.onChanged((handleX - 3)/(slider.width - 6))
		end
	end
	local function sliderDrag(object, button, deltaX, deltaY)
		local slider = object:GetUserdata()
		slider.currX = slider.currX + deltaX
		local handleX = math.max(3, math.min(slider.width - 3, slider.currX))
		slider.handle:SetX(handleX)
		if slider.onChanged then
			slider.onChanged((handleX - 3)/(slider.width - 6))
		end
	end
	local function sliderScroll(object, dir, xPos, yPos)
		local slider = object:GetUserdata()
		local handleX = math.max(3, math.min(slider.width - 3, slider.handle:GetX() + dir/math.abs(dir)))
		slider.handle:SetX(handleX)
		if slider.onChanged then
			slider.onChanged((handleX - 3)/(slider.width - 6))
		end
	end

	local sliderMethods = {
		GetPercent = function(self)
			return self.percent
		end,
		SetPercent = function(self, percent)
			if tiles.checkProperty.percent(percent) then
				self.percent = percent
				local width = self.background:GetWidth()
				local handleX = math.floor(percent*(width - 6)) + 3
				self.handle:SetX(handleX)
				return true
			end
			return false
		end,

		GetOnChanged = function(self)
			return self.onChanged
		end,
		SetOnChanged = function(self, func)
			if tiles.checkProperty.functionOrNil(func) then
				self.onChanged = func
				return true
			end
			return false
		end,
	}
	local sliderMetatable = makeMetatable(sliderMethods)

	function addSlider(tile, xPos, yPos, zPos, width, height)
		local sliderTile = tile:AddSubTile(xPos, yPos, zPos)
		local slider = {
			tile = sliderTile,
			onChanged = false,
			width = width,
			currX = 0,
		}
		
		local background = sliderTile:AddBox(0, 0, width, height, 0xffffff, 1)
		background:SetOnClick(sliderClick)
		background:SetOnDrag(sliderDrag)
		background:SetOnScroll(sliderScroll)
		background:SetUserdata(slider)
		
		local runner = sliderTile:AddLine({x = 3, y = height/2},{x = width - 3, y = height/2}, 0x000000, 1)
		runner:SetWidth(2)
		runner:SetZ(1)
		runner:SetClickable(false)
		
		local handle = sliderTile:AddBox(width - 3, height/2, 3, height - 2, 0x000000, 1)
		handle:SetObjectAnchor("MIDDLE", "MIDDLE")
		handle:SetZ(2)
		handle:SetClickable(false)
		
		slider.runner = runner
		slider.handle = handle
		slider.background = background
		
		return setmetatable(slider, sliderMetatable)
	end
end

--===== LIST =====--
do
	local function redrawItemsTile(list, startIndex, noSliderUpdate)
		local maxItems = math.floor(list.height/10)
		local startIndex = math.max(0, math.min(#list.items - maxItems, startIndex))
		
		list.itemsTile:SetY(-(startIndex*10))
		if not noSliderUpdate then
			list.listSlider:SetPercent(1 - (startIndex/(#list.items - maxItems)))
		end
	
		local isVisible
		for index, itemTile in ipairs(list.itemTiles) do
			isVisible = index > startIndex and index <= startIndex + maxItems
			itemTile.tile:SetVisible(isVisible)
			itemTile.tile:SetClickable(isVisible)
		end
		
		list.startIndex = startIndex
	end

	local function listTileOnKey(tile, object, keyCode)
		local list = tile:GetUserdata()
		if type(list) == "table" and list.highlighted then
			if keyCode == keys.up then
				list:SetHighlighted(math.max(1, list.highlighted - 1))
			elseif keyCode == keys.down then
				list:SetHighlighted(math.min(#list.items, list.highlighted + 1))
			elseif keyCode == keys.enter then
				list:SetSelected(list.highlighted)
			end
		end
	end

	local function itemObjectClick(object)
		local list, index = unpack(object:GetUserdata())
		list:SetHighlighted(index)
	end

	local function itemObjectRelease(object)
		local list, index = unpack(object:GetUserdata())
		list:SetSelected(index)
	end

	local function itemObjectScroll(object, dir)
		local list = unpack(object:GetUserdata())
		redrawItemsTile(list, list.startIndex - dir/math.abs(dir))
	end
	
	local function updateItemTile(item, itemData, width)
		item.background:SetWidth(width)
		local itemText = itemData
		if tiles.getMaxStringLength(itemText, width - 2, 1) < string.len(itemText) then
			local textLen = tiles.getMaxStringLength(itemText, width - 8, 1)
			itemText = string.sub(itemText, 1, textLen).."..."
		end
		item.text:SetText(itemText)
	end
	
	local function updateItemTiles(list, startIndex, width)
		for i = startIndex, #list.items do
			local item, itemData = list.itemTiles[i], list.items[i][2]
			updateItemTile(item, itemData, width)
		end
	end
	
	local function updateSlider(list, newSize)
		local curSize, maxSize = #list.items, math.floor(list.height/10)
		local widthChanged, itemWidth = false, list.width
		if newSize > maxSize then
			itemWidth = list.width - 10
			if curSize <= maxSize then
				widthChanged = true
				-- make slider visible
				list.listSlider:SetVisible(true)
				list.listSlider:SetClickable(true)
			end
		else -- newSize <= maxSize
			-- itemWidth = list.width
			if curSize > maxSize then
				widthChanged = true
				-- make slider not visible
				list.listSlider:SetVisible(false)
				list.listSlider:SetClickable(false)
			end
		end
		return widthChanged, itemWidth
	end
	
	local function newItemTile(list, itemsTile, index, width, itemData)
		local itemTile = itemsTile:AddSubTile(0, (index - 1)*10, 0)
		
		local backgroundColour = ((index % 2) == 0 and 0x4c4c4c) or 0x999999
		local background = itemTile:AddBox(0, 0, width, 10, backgroundColour, 1)
		background:SetOnClick(itemObjectClick)
		background:SetOnRelease(itemObjectRelease)
		background:SetOnScroll(itemObjectScroll)
		background:SetUserdata({list, index})
		
		local itemText = itemData[2]
		if tiles.getMaxStringLength(itemText, width - 2, 1) < string.len(itemText) then
			local textLen = tiles.getMaxStringLength(itemText, width - 8, 1)
			itemText = string.sub(itemText, 1, textLen).."..."
		end
		local text = itemTile:AddText(1, 1, itemText, 0x000000)
		text:SetZ(1)
		text:SetClickable(false)
		
		local item = {
			tile = itemTile,
			background = background,
			text = text,
		}
		
		return item
	end

	local listMethods = {
		GetHighlighted = function(self)
			return self.highlighted
		end,
		SetHighlighted = function(self, index)
			if isIntegerWithinBounds(index, 1, #self.items) or index == false then
				if self.highlighted then -- set color of current highlighted to normal
					local item = self.itemTiles[self.highlighted]
					if self.highlighted == self.selected then
						item.background:SetColor(0x008800)
					else
						item.background:SetColor(((self.highlighted % 2) == 0 and 0x4c4c4c) or 0x999999)
					end
				end
				
				-- set color of new highlighted to highlighted color
				if index then
					local newItem = self.itemTiles[index]
					if index == self.selected then
						newItem.background:SetColor(0x008800)
					else
						newItem.background:SetColor(0x00ff00)
					end
					
					-- check if need to scroll
					local maxItems = math.floor(self.height/10)
					if index - 1 < self.startIndex then
						redrawItemsTile(self, index - 1)
					elseif index - maxItems > self.startIndex then
						redrawItemsTile(self, index - maxItems)
					end
				end
				
				if not noUpdate and self.onHighlightedChanged then
					self.onHighlightedChanged(index, index and unpack(self.items[index]))
				end
				
				-- update highlighted value
				self.highlighted = index
				
				return true
			end
			return false
		end,
		
		GetSelected = function(self)
			return self.selected
		end,
		SetSelected = function(self, index, noUpdate)
			if isIntegerWithinBounds(index, 1, #self.items) or index == false then
				if self.selected then -- set color of current selected to normal
					local item = self.itemTiles[self.selected]
					if self.selected == self.highlighted then
						item.background:SetColor(0x00ff00)
					else
						item.background:SetColor(((self.selected % 2) == 0 and 0x4c4c4c) or 0x999999)
					end
				end
				
				-- set color of new selected to selected color
				if index then
					local newItem = self.itemTiles[index]
					newItem.background:SetColor(0x008800)
				
					-- check if need to scroll
					local maxItems = math.floor(self.height/10)
					if index - 1 < self.startIndex then
						redrawItemsTile(self, index - 1)
					elseif index - maxItems > self.startIndex then
						redrawItemsTile(self, index - maxItems)
					end
				end
				
				if not noUpdate and self.onSelectedChanged then
					self.onSelectedChanged(index, index and unpack(self.items[index]))
				end
				
				-- update selected value
				self.selected = index
				
				return true
			end
			return false
		end,
		
		GetOnHighlightedChanged = function(self)
			return self.onHighlightedChanged
		end,
		SetOnHighlightedChanged = function(self, func)
			if tiles.checkProperty.functionOrNil(func) then
				self.onHighlightedChanged = func
				return true
			end
			return false
		end,
		
		GetOnSelectedChanged = function(self)
			return self.onSelectedChanged
		end,
		SetOnSelectedChanged = function(self, func)
			if tiles.checkProperty.functionOrNil(func) then
				self.onSelectedChanged = func
				return true
			end
			return false
		end,

		AddItem = function(self, index, itemData)
			if isIntegerWithinBounds(index, 1, #self.items + 1) then
			
				local widthChanged, itemWidth = updateSlider(self, #self.items + 1)

				table.insert(self.items, index, itemData)
				table.insert(self.itemTiles, newItemTile(self, self.itemsTile, #self.itemTiles + 1, itemWidth, {"", ""}))
				
				updateItemTiles(self, (widthChanged and 1) or index, itemWidth)
				redrawItemsTile(self, self.startIndex)
				
				if index == self.highlighted then
					self:SetHighlighted(self.highlighted + 1)
				end
				if index == self.selected then
					self:SetSelected(self.selected + 1, true)
				end
				
				return true
			end
			return false
		end,
		GetItem = function(self, index)
			if isIntegerWithinBounds(index, 1, #self.items) then
				return self.items[index]
			end
		end,
		SetItem = function(self, index, itemData)
			if isIntegerWithinBounds(index, 1, #self.items) then
				local _, itemWidth = updateSlider(self, #self.items)
				self.items[index] = itemData
				updateItemTile(self.itemTiles[index], itemData[2], itemWidth)
				return true
			end
			return false
		end,
		RemoveItem = function(self, index)
			if isIntegerWithinBounds(index, 1, #self.items) then
				
				if index == self.highlighted then
					self:SetHighlighted(false)
				end
				if index == self.selected then
					self:SetSelected(false)
				end
			
				local widthChanged, itemWidth = updateSlider(self, #self.items - 1)
				
				table.remove(self.items, index)
				local itemTile = table.remove(self.itemTiles, #self.itemTiles)
				itemTile.tile:Delete()
				
				updateItemTiles(self, (widthChanged and 1) or index, itemWidth)
				redrawItemsTile(self, self.startIndex)
				
				return true
			end
			return false
		end,
	}
	local listMetatable = makeMetatable(listMethods)

	function addList(tile, xPos, yPos, zPos, width, height, onSelectedChanged, items)
		local listTile = tile:AddSubTile(xPos, yPos, zPos)
		local itemsTile = listTile:AddSubTile(0, 0, 0)
		local list = {
			tile = listTile,
			itemsTile = itemsTile,
			onSelectedChanged = onSelectedChanged,
			items = items or {},
			itemTiles = {},
			startIndex = 0,
			selected = false,
			highlighted = false,
			width = width,
			height = height,
		}
		setmetatable(list, listMetatable)
		
		listTile:SetUserdata(list)
		listTile:SetOnKeyDown(listTileOnKey)

		local maxItems = math.floor(height/10)
		
		--local listSlider = addSlider(listTile, width, 0, 1, maxItems*10, 10)
		local listSlider = addSlider(listTile, width - 10, height, 1, maxItems*10, 10)
		local function listSliderOnChanged(percent)
			local interval = 1/(#list.items - math.floor(list.height/10))
			local index = (1 - percent)/interval
			index = math.floor(index) + math.floor(2*(index%1))
			redrawItemsTile(list, index, true)
		end
		listSlider:SetOnChanged(listSliderOnChanged)
		listSlider:SetRotation(270)
		listSlider:SetPercent(0)
		list.listSlider = listSlider
		
		local itemWidth = width
		if #items > maxItems then
			itemWidth = itemWidth - 10
		else
			listSlider:SetVisible(false)
			listSlider:SetClickable(false)
		end
		for index, itemData in ipairs(items) do
			local itemTile = newItemTile(list, itemsTile, index, itemWidth, itemData)
			if index > maxItems then
				itemTile.tile:SetVisible(false)
				itemTile.tile:SetClickable(false)
			end
			list.itemTiles[index] = itemTile
		end

		return list
	end
end

--===== TEXT BOX =====--
do
	local function redrawTextBox(textBox)
		local text
		if textBox.mask then
			text = string.rep(textBox.mask, string.len(textBox.currText))
		else
			text = textBox.currText
		end
		if textBox.cursorPos + 1 < textBox.startPos then
			textBox.startPos = textBox.cursorPos + 1
		elseif tiles.getStringWidth(string.sub(text, textBox.startPos, textBox.cursorPos)) > textBox.width - 2 then
			repeat
				textBox.startPos = textBox.startPos + 1
			until tiles.getStringWidth(string.sub(text, textBox.startPos, textBox.cursorPos)) <= textBox.width - 2
		end
		textBox.cursor:SetX(tiles.getStringWidth(string.sub(text, textBox.startPos, textBox.cursorPos)) + 1)
		textBox.text:SetText(string.sub(text, textBox.startPos, tiles.getMaxStringLength(text, textBox.width - 2, textBox.startPos)))
	end

	local function textBoxSelect(background)
		local textBox = background:GetUserdata()
		textBox.cursor:SetVisible(true)
	end

	local function textBoxDeselect(background)
		local textBox = background:GetUserdata()
		textBox.cursor:SetVisible(false)
	end

	local function textBoxKeyDown(background, keyCode, keyChar, isRepeat)
		local textBox = background:GetUserdata()
		if keyChar then
			textBox.currText = string.sub(textBox.currText, 1, textBox.cursorPos)..keyChar..string.sub(textBox.currText, textBox.cursorPos + 1)
			textBox.cursorPos = textBox.cursorPos + 1
			redrawTextBox(textBox)
		else
			if keyCode == keys.enter then
				if textBox.onEnter then
					textBox.onEnter(textBox.currText)
				end
				if textBox.resetOnEnter then
					textBox:SetText("")
				end
			elseif keyCode == keys.left then
				textBox.cursorPos = math.max(0, textBox.cursorPos - 1)
				redrawTextBox(textBox)
			elseif keyCode == keys.right then
				textBox.cursorPos = math.min(string.len(textBox.currText), textBox.cursorPos + 1)
				redrawTextBox(textBox)
			elseif keyCode == keys.backspace then
				if textBox.cursorPos > 0 then
					textBox.currText = string.sub(textBox.currText, 1, textBox.cursorPos - 1)..string.sub(textBox.currText, textBox.cursorPos + 1)
					textBox.cursorPos = textBox.cursorPos - 1
					redrawTextBox(textBox)
				end
			elseif keyCode == keys.home then
				textBox.cursorPos = 0
				redrawTextBox(textBox)
			elseif keyCode == keys.delete then
				if textBox.cursorPos < string.len(textBox.currText) then
					textBox.currText = string.sub(textBox.currText, 1, textBox.cursorPos)..string.sub(textBox.currText, textBox.cursorPos + 2)
					redrawTextBox(textBox)
				end
			elseif keyCode == keys["end"] then
				textBox.cursorPos = string.len(textBox.currText)
				redrawTextBox(textBox)
			end
		end
	end

	local function textBoxClick(background, button, xPos)
		if button == 0 then
			local textBox = background:GetUserdata()
			local text
			if textBox.mask then
				text = string.rep(textBox.mask, string.len(textBox.currText))
			else
				text = textBox.currText
			end
			for i = textBox.startPos - 1, string.len(text) do
				local width = tiles.getStringWidth(string.sub(text, textBox.startPos, i))
				textBox.cursorPos = i
				if width + 2 > xPos then
					break
				end
			end
			textBox.cursor:SetX(tiles.getStringWidth(string.sub(text, textBox.startPos, textBox.cursorPos)) + 1)
		end
	end		

	local textBoxMethods = {
		GetCursorPos = function(self)
			return self.cursorPos
		end,
		SetCursorPos = function(self, cursorPos)
			if tiles.checkProperty.positive_number(cursorPos) then
				self.cursorPos = math.min(cursorPos, string.len(self.currText))
				redrawTextBox(self)
				return true
			end
			return false
		end,
		
		GetMask = function(self)
			return self.mask
		end,
		SetMask = function(self, mask)
			if tiles.checkProperty.string(mask) then
				self.mask = string.sub(mask, 1, 1)
				redrawTextBox(self)
				return true
			elseif mask == nil then
				self.mask = nil
				redrawTextBox(self)
				return true
			end
			return false
		end,
		
		GetText = function(self)
			return self.currText
		end,
		SetText = function(self, text)
			if tiles.checkProperty.string(text) then
				self.currText = text
				self.cursorPos = math.min(self.cursorPos, string.len(text))
				redrawTextBox(self)
				return true
			end
			return false
		end,
		
		GetResetOnEnter = function(self)
			return self.resetOnEnter
		end,
		SetResetOnEnter = function(self, boolean)
			if tiles.checkProperty.boolean(boolean) then
				self.resetOnEnter = boolean
				return true
			end
			return false
		end,
		
		GetWidth = function(self)
			return self.width
		end,
		SetWidth = function(self, width)
			if tiles.checkProperty.positive_number(width) then
				self.width = width
				self.background:SetWidth(width)
				redrawTextBox(self)
				return true
			end
			return false
		end,
		
		GetOnEnter = function(self)
			return self.onEnter
		end,
		SetOnEnter = function(self, func)
			if tiles.checkProperty.functionOrNil(func) then
				self.onEnter = func
				return true
			end
			return false
		end,
	}
	local textBoxMetatable = makeMetatable(textBoxMethods)

	function addTextBox(tile, xPos, yPos, zPos, width, onEnter, mask)
		local textBoxTile = tile:AddSubTile(xPos, yPos, zPos)
		local textBox = {
			tile = textBoxTile,
			onEnter = onEnter,
			resetOnEnter = false,
			width = width,
			currText = "",
			cursorPos = 0,
			startPos = 1,
			mask = mask,
		}
		
		local text = textBoxTile:AddText(1, 1, "", 0x000000)
		text:SetZ(1)
		text:SetClickable(false)
		
		local cursor = textBoxTile:AddText(1, 1, "|", 0x000000)
		cursor:SetAlpha(0.5)
		cursor:SetZ(1)
		cursor:SetClickable(false)
		cursor:SetVisible(false)
		
		local background = textBoxTile:AddBox(0, 0, width, 10, 0xffffff, 1)
		background:SetOnSelect(textBoxSelect)
		background:SetOnKeyDown(textBoxKeyDown)
		background:SetOnClick(textBoxClick)
		background:SetOnDeselect(textBoxDeselect)
		background:SetUserdata(textBox)
		
		textBox.text = text
		textBox.cursor = cursor
		textBox.background = background
		
		return setmetatable(textBox, textBoxMetatable)
	end
end

--===== ITEM SLOT =====--
do
	local slotWidth = 16
	local function createSlotPoints(xPos, yPos)
		return {
			{x = xPos, y = yPos},
			{x = xPos + slotWidth, y = yPos},
			{x = xPos + slotWidth, y = yPos + slotWidth},
			{x = xPos, y = yPos + slotWidth},
			{x = xPos, y = yPos},
		}
	end
	
	local itemSlotMethods = {
		GetAmount = function(self)
			return self.amount
		end,
		SetAmount = function(self, amount)
			if tiles.checkProperty.positive_number(amount) then
				self.amount = amount
				self.icon:SetVisible(true)
				self.icon:SetLabel((amount ~= 1 and tostring(amount)) or "")
			elseif amount == false then
				self.amount = amount
				self.icon:SetVisible(false)
			end
		end,
		GetItemId = function(self)
			return self.icon:GetItemId()
		end,
		SetItemId = function(self, itemId)
			return self.icon:SetItemId(itemId)
		end,
		GetMeta = function(self)
			return self.icon:GetMeta()
		end,
		SetMeta = function(self, meta)
			return self.icon:SetMeta(meta)
		end,
		GetDamageBar = function(self)
			return self.icon:GetDamageBar()
		end,
		SetDamageBar = function(self, damage)
			return self.icon:SetDamageBar(damage)
		end,
	}
	local itemSlotMetatable = makeMetatable(itemSlotMethods)

	function addItemSlot(tile, xPos, yPos, zPos)
		local itemSlotTile = tile:AddSubTile(xPos, yPos, zPos)

		local itemSlotBackground = itemSlotTile:AddBox(0, 0, slotWidth, slotWidth, 0x999999, 1)
		itemSlotBackground:SetObjectAnchor("MIDDLE", "MIDDLE")

		local itemSlotBorder = itemSlotTile:AddLineList(0x000000, 1, createSlotPoints(0, 0))
		itemSlotBorder:SetZ(1)
		itemSlotBorder:SetObjectAnchor("MIDDLE", "MIDDLE")
		itemSlotBorder:SetClickable(false)

		local itemSlotIcon = itemSlotTile:AddIcon(0, 0, "minecraft:stone")
		itemSlotIcon:SetZ(2)
		itemSlotIcon:SetObjectAnchor("MIDDLE", "MIDDLE")
		itemSlotIcon:SetVisible(false)
		itemSlotIcon:SetClickable(false)
		
		local itemSlot = {
			tile = itemSlotTile,

			amount = false,

			background = itemSlotBackground,
			border = itemSlotBorder,
			icon = itemSlotIcon,
		}

		return setmetatable(itemSlot, itemSlotMetatable)
	end
end

--===== BASIC WINDOW =====--
do
	local basicWindowMethods = {
		AddFancyText = addFancyText,
		AddButton = addButton,
		AddSlider = addSlider,
		AddList = addList,
		AddTextBox = addTextBox,
		AddItemSlot = addItemSlot,

		GetBackground = function(self)
			return self.background
		end,
		GetWidth = function(self)
			return self.width
		end,
		SetWidth = function(self, width)
			self.width = width
			self.background:SetWidth(self.width)
			self.border:SetPoints({{x = 0, y = 0}, {x = self.width, y = 0}, {x = self.width, y = self.height}, {x = 0, y = self.height}, {x = 0, y = 0}})
		end,
		GetHeight = function(self)
			return self.height
		end,
		SetHeight = function(self, height)
			self.height = height
			self.background:SetHeight(self.height)
			self.border:SetPoints({{x = 0, y = 0}, {x = self.width, y = 0}, {x = self.width, y = self.height}, {x = 0, y = self.height}, {x = 0, y = 0}})
		end,
		GetColor = function(self)
			return self.background:GetColor()
		end,
		SetColor = function(self, color)
			return self.background:SetColor(color)
		end,
	}
	local basicWindowMetatable = makeMetatable(basicWindowMethods)

	function newBasicWindow(tile, width, height, draggable)
		local basicWindow = {
			tile = tile,
			width = width,
			height = height,
			draggable = false,
			background = tile:AddBox(0, 0, width, height, 0xffffff, 1),
			border = tile:AddLineList(0x000000, 1, {{x = 0, y = 0}, {x = width, y = 0}, {x = width, y = height}, {x = 0, y = height}, {x = 0, y = 0}})
		}
		basicWindow.background:SetZ(-1)
		basicWindow.border:SetClickable(false)
		
		setmetatable(basicWindow, basicWindowMetatable)
		
		if draggable == true then
			basicWindow.draggable = true
			makeDraggable(basicWindow, basicWindow:GetBackground())
		end
		
		return basicWindow
	end
end

--===== BASIC WINDOW HANDLER =====--
do
	local function onWindowSelectFunc(window)
		local handler, windowID = unpack(window:GetUserdata())
		handler:ToFront(windowID)
	end
	
	local function reorder(basicWindowHandler)
		for order, windowID in ipairs(basicWindowHandler.orderedList) do
			local window = basicWindowHandler.list[windowID]
			if window then
				window:SetZ(basicWindowHandler.spacing*order)
			end
		end
	end
	
	local basicWindowHandlerMethods = {
		New = function(self, tile, width, height, draggable)
			local windowID
			repeat
				windowID = math.random(0, 9999)
			until not self.list[windowID]

			local window = newBasicWindow(tile, width, height, draggable)

			self.list[windowID] = window
			table.insert(self.orderedList, windowID)

			window:SetZ(self.spacing*#self.orderedList)
			window:SetUserdata({self, windowID})
			window:SetOnSelect(onWindowSelectFunc)

			return window
		end,
		ToFront = function(self, windowID)
			for order, winID in ipairs(self.orderedList) do
				if winID == windowID then
					table.insert(self.orderedList, table.remove(self.orderedList, order))
					reorder(self)
					return true
				end
			end
			return false
		end,
		ToBack = function(self, windowID)
			for order, winID in ipairs(self.orderedList) do
				if winID == windowID then
					table.insert(self.orderedList, 1, table.remove(self.orderedList, order))
					reorder(self)
					return true
				end
			end
			return false
		end,
		Delete = function(self, windowID)
			local window = self.list[windowID]
			if window then
				window:Delete()
				self.list[windowID] = nil
				for order, winID in ipairs(self.orderedList) do
					if winID == windowID then
						table.remove(self.orderedList, order)
						reorder(self)
						break
					end
				end
				return true
			end
			return false
		end,
		GetWindow = function(self, windowID)
			return self.list[windowID]
		end,
		GetAllWindows = function(self)
			local windows = {}
			for windowID, window in pairs(self.list) do
				windows[windowID] = window
			end
			return windows
		end,
		GetSpacing = function(self)
			return self.spacing
		end,
		SetSpacing = function(self, spacing)
			if tiles.checkProperty.positive_number(spacing) then
				self.spacing = spacing
				reorder(self)
				return true
			end
			return false
		end,
	}
	local basicWindowHandlerMetatable = makeMetatable(basicWindowHandlerMethods)

	function newBasicWindowHandler()
		local basicWindowHandler = {
			spacing = 10,
			list = {},
			orderedList = {},
		}
		return setmetatable(basicWindowHandler, basicWindowHandlerMetatable)
	end
end

--===== GUI HANDLER =====--
do
	local function findChain(object)
		local chain = {}
		local tile = object:GetTile()
		chain[tile:GetID()] = tile
		while not tile:IsMasterTile() do
			tile = tile:GetParent()
			chain[tile:GetID()] = tile
		end
		return chain
	end

	local function passEventToObject(surfaceHandler, objectID, funcName, ...)
		local object = findObject(surfaceHandler, objectID)
		if object then
			local func = object[funcName](object)
			if func then
				func(object, ...)
			end
		end
	end

	local function passEventUpChain(surfaceHandler, object, chain, funcName, ...)
		if not object then error("here", 2) end
		local func = object[funcName](object)
		if func then
			func(object, ...)
		end
		for _, tile in pairs(chain) do
			local selectFunc = tile[funcName](tile)
			if selectFunc then
				selectFunc(tile, object, ...)
			end
		end
	end

	local surfaceEventHandlers = {
		--glasses_attach = function(handler, event)
		--end,
		glasses_detach = function(handler, event)
			if handler.lastClickedObjectID then
				passEventToObject(handler.surfaceHandler, handler.lastClickedObjectID, "GetOnRelease", handler.button, handler.relativeX, handler.relativeY, handler.actualX, handler.actualY)
			end
			handler.lastClickedObjectID, handler.actualX, handler.actualY, handler.button = false, false, false, false
			handler.relativeX, handler.relativeY = false, false
		end,
		glasses_capture = function(handler, event)
			local capture = handler.surfaceHandler:GetCapture()
			if capture then
				capture.setBackground(handler.captureBackground, handler.captureAlpha)
				capture.toggleGuiElements(handler.captureGuiElements)
				capture.setKeyRepeat(handler.captureKeyRepeat)
			end
		end,
		glasses_release = function(handler, event)
			if handler.lastClickedObjectID then
				passEventToObject(handler.surfaceHandler, handler.lastClickedObjectID, "GetOnRelease", handler.button, handler.relativeX, handler.relativeY, handler.actualX, handler.actualY)
			end
			handler.lastClickedObjectID, handler.actualX, handler.actualY, handler.button = false, false, false, false
			handler.relativeX, handler.relativeY = false, false
		end,
		--glasses_chat_command = function(handler, event)
		--end,
		--glasses_chat_message = function(handler, event)
		--end,
		glasses_key_down = function(handler, event)
			if handler.lastObjectID then
				local keyChar = event[6]:gsub("%c", "")
				keyChar = (keyChar:len() > 0 and keyChar) or nil
				local object = findObject(handler.surfaceHandler, handler.lastObjectID)
				if object then
					passEventUpChain(handler.surfaceHandler, object, findChain(object), "GetOnKeyDown", event[5], keyChar, event[7])
				end
			end
		end,
		glasses_key_up = function(handler, event)
			if handler.lastObjectID then
				local object = findObject(handler.surfaceHandler, handler.lastObjectID)
				if object then
					passEventUpChain(handler.surfaceHandler, object, findChain(object), "GetOnKeyUp", event[5])
				end
			end
		end,
		--glasses_mouse_scroll = function(handler, event)
		--end,
		glasses_mouse_down = function(handler, event)
			if handler.lastObjectID then
				local object = findObject(handler.surfaceHandler, handler.lastObjectID)
				if object then
					passEventUpChain(handler.surfaceHandler, object, findChain(object), "GetOnDeselect")
				end
			end
			handler.lastObjectID = false
		end,
		glasses_mouse_up = function(handler, event)
			if handler.lastClickedObjectID then
				passEventToObject(handler.surfaceHandler, handler.lastClickedObjectID, "GetOnRelease", handler.button, handler.relativeX, handler.relativeY, handler.actualX, handler.actualY)
			end
			handler.lastClickedObjectID, handler.actualX, handler.actualY, handler.button = false, false, false, false
			handler.relativeX, handler.relativeY = false, false
		end,
		glasses_mouse_drag = function(handler, event)
			if handler.lastClickedObjectID then
				handler.actualX, handler.actualY = handler.actualX + event[5], handler.actualY + event[6]
				local object = findObject(handler.surfaceHandler, handler.lastClickedObjectID)
				if object then
					local deltaX, deltaY = actualToRelative(object, event[5], event[6])
					handler.relativeX, handler.relativeY = handler.relativeX + deltaX, handler.relativeY + deltaY
					local func = object:GetOnDrag()
					if func then
						func(object, handler.button, deltaX, deltaY, event[5], event[6])
					end
				end
			end
		end,
		glasses_component_mouse_wheel = function(handler, event)
			local object = findObject(handler.surfaceHandler, event[5])
			if object then
				local func = object:GetOnScroll()
				if func then
					local relX, relY = actualToRelative(object, event[7], event[8])
					func(object, event[9], relX, relY, event[7], event[8])
				end
			end
		end,
		glasses_component_mouse_down = function(handler, event)
			if handler.lastClickedObjectID then
				passEventToObject(handler.surfaceHandler, handler.lastClickedObjectID, "GetOnRelease", handler.button, handler.relativeX, handler.relativeY, handler.actualX, handler.actualY)
			end
			if not handler.lastObjectID or event[5] ~= handler.lastObjectID then
				local newObject = findObject(handler.surfaceHandler, event[5])
				local selectedChain = (newObject and findChain(newObject)) or {}
				if handler.lastObjectID then
					local object = findObject(handler.surfaceHandler, handler.lastObjectID)
					if object then
						local deselectedChain = findChain(object)
						for tileID, _ in pairs(selectedChain) do
							deselectedChain[tileID] = nil
						end
						passEventUpChain(handler.surfaceHandler, object, deselectedChain, "GetOnDeselect")
					end
				end
				handler.lastObjectID = event[5]
				if newObject then
					passEventUpChain(handler.surfaceHandler, newObject, selectedChain, "GetOnSelect")
				end
			end
			local object = findObject(handler.surfaceHandler, event[5])
			if object then
				handler.lastClickedObjectID, handler.actualX, handler.actualY, handler.button = event[5], event[7], event[8], event[9]
				handler.lastObjectID = event[5]
				local scale = object:GetTile():GetActualScale()
				handler.relativeX, handler.relativeY = handler.actualX/scale, handler.actualY/scale
				local clickFunc = object:GetOnClick()
				if clickFunc then
					clickFunc(object, handler.button, handler.relativeX, handler.relativeY, handler.actualX, handler.actualY)
				end
			else
				handler.lastClickedObjectID, handler.actualX, handler.actualY, handler.button = false, false, false, false
			end
		end,
		glasses_component_mouse_up = function(handler, event)
			if handler.lastClickedObjectID then
				local object = findObject(handler.surfaceHandler, handler.lastClickedObjectID)
				if object then
					local func = object:GetOnRelease()
					if func then
						if handler.lastClickedObjectID == event[5] then
							handler.actualX, handler.actualY = event[7], event[8]
							local scale = object:GetTile():GetActualScale()
							handler.relativeX, handler.relativeY = handler.actualX/scale, handler.actualY/scale
						end
						func(object, handler.button, handler.relativeX, handler.relativeY, handler.actualX, handler.actualY)
					end
				end
			end
			handler.lastClickedObjectID, handler.actualX, handler.actualY, handler.button = false, false, false, false
			handler.relativeX, handler.relativeY = false, false
		end,
	}

	local guiHandlerMethods = {
		GetCaptureBackground = function(self)
			return self.captureBackground
		end,
		SetCaptureBackground = function(self, colour)
			if tiles.checkProperty.colour(colour) then
				self.captureBackground = colour
				local capture = self.surfaceHandler:GetCapture()
				if capture then
					capture.setBackground(self.captureBackground, self.captureAlpha)
				end
				return true
			end
			return false
		end,
		GetCaptureAlpha = function(self)
			return self.captureAlpha
		end,
		SetCaptureAlpha = function(self, alpha)
			if tiles.checkProperty.alpha(alpha) then
				self.captureAlpha = alpha
				local capture = self.surfaceHandler:GetCapture()
				if capture then
					capture.setBackground(self.captureBackground, self.captureAlpha)
				end
				return true
			end
			return false
		end,
		
		HandleEvent = function(self, event)
			if type(event) == "table" then
				local eventType = event[1]
				local handler = surfaceEventHandlers[eventType]
				if handler then
					handler(self, event)
					return true
				end
			end
			return false
		end,
	}
	local guiHandlerMetatable = {__index = guiHandlerMethods}

	function newGuiHandler(surfaceHandler)
		local guiHandler = {
			surfaceHandler = surfaceHandler,
			
			captureBackground = 0xffffff,
			captureAlpha = 0,
			captureGuiElements = {},
			captureKeyRepeat = true,
			
			lastClickedObjectID = false,
			lastObjectID = false,
			button = false,
			actualX = false,
			actualY = false,
			relativeX = false,
			relativeY = false,
		}
		for i = 2, 13 do
			guiHandler.captureGuiElements[i] = false
		end
		setmetatable(guiHandler, guiHandlerMetatable)
		return guiHandler
	end
end
