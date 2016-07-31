--===== LOAD APIS =====--
if not routineHandler then
	if not os.loadAPI(routineHandler) then
		error("Could not load API: routineHandler")
	end
end

--===== UTILS =====--
local function makeMetatable(methodsTable)
	return {
		__index = function(t, k)
			return methodsTable[k] or t.object[k]
		end,
	}
end

--===== ASYNCHRONOUS BUTTON =====--
local function buttonRoutineFunc(asynchronousButton, mouseButton)
	local text, textCol, backgroundColour = asynchronousButton.onRelease(mouseButton)
	asynchronousButton.clicked = false
	if text then asynchronousButton:SetText(text) end
	if textCol then asynchronousButton:SetInactiveTextColour(textCol) end
	if backgroundColour then asynchronousButton:SetInactiveMainColour(backgroundColour) end
end

local asynchronousButtonMethods = {
	GetClickedText = function(self)
		return self.clickedText
	end,
	SetClickedText = function(self, text)
		if type(text) == "string" or type(text) == "boolean" then
			self.clickedText = text
			return true
		end
		return false
	end,
	GetClickedTextColour = function(self)
		return self.clickedTextCol
	end,
	SetClickedTextColour = function(self, colour)
		if tiles.checkProperty.colour(colour) or type(colour) == "boolean" then
			self.clickedTextCol = colour
			return true
		end
		return false
	end,
	GetClickedBackgroundColour = function(self)
		return self.clickedBackgroundCol
	end,
	SetClickedBackgroundColour = function(self, colour)
		if tiles.checkProperty.colour(colour) or type(colour) == "boolean" then
			self.clickedBackgroundCol = colour
			return true
		end
		return false
	end,

	GetOnRelease = function(self)
		return self.onRelease
	end,
	SetOnRelease = function(self, func)
		if type(func) == "function" or type(func) == "boolean" then
			self.onRelease = func
			return true
		end
		return false
	end,
}
local asynchronousButtonMetatable = makeMetatable(asynchronousButtonMethods)

local function newAsynchronousButton(handler, window, xPos, yPos, zPos, text, inactiveMainColour, inactiveTextColour, activeMainColour, activeTextColour, width, height)
	local asynchronousButton = {
		clickedText = false,
		clickedTextCol = false,
		clickedBackgroundCol = false,
		onRelease = false,
		clicked = false,
	}
	local button = window:AddButton(xPos, yPos, zPos, text, inactiveMainColour, inactiveTextColour, activeMainColour, activeTextColour, width, height)
	local function onButtonRelease(mouseButton)
		if not asynchronousButton.clicked and asynchronousButton.onRelease then
			asynchronousButton.clicked = true
			if asynchronousButton.clickedText then
				button:SetText(asynchronousButton.clickedText)
			end
			if asynchronousButton.clickedTextCol then
				button:SetInactiveTextColour(asynchronousButton.clickedTextCol)
			end
			if asynchronousButton.clickedBackgroundCol then
				button:SetInactiveMainColour(asynchronousButton.clickedBackgroundCol)
			end
			handler.routines:Add(buttonRoutineFunc, asynchronousButton, mouseButton)
		end
	end
	button:SetOnRelease(onButtonRelease)
	asynchronousButton.object = button
	return setmetatable(asynchronousButton, asynchronousButtonMetatable)
end

--===== ASYNCHRONOUS HANDLER =====--
local asynchronousHandlerMethods = {
	AddButton = newAsynchronousButton,
	HandleEvent = function(self, ...)
		return self.routines:HandleEvent(...)
	end,
	Run = function(self)
		return self.routines:Run()
	end,
}
local asynchronousHandlerMetatable = {__index = asynchronousHandlerMethods}

function newHandler(optional_routines)
	local asynchronousHandler = {
		routines = optional_routines or routineHandler.new(),
	}
	return setmetatable(asynchronousHandler, asynchronousHandlerMetatable)
end
