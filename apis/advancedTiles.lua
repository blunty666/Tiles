--===== UTILITIES =====--
local function makeMetatable(methodsTable)
	return {
		__index = function(t, k)
			return methodsTable[k] or t.tile[k]
		end,
	}
end

local function createBackground(tile, width, height, opacity)
	return tile:AddBox(0, 0, width, height, 0x000000, opacity)
end

local function createAxis(tile, width, height, opacity)
	local points = {
		{x = 0, y = 0},
		{x = 0, y = 0 + height},
		{x = 0 + width, y = 0 + height},
	}
	local axis = tile:AddLineList(0x000000, opacity, points)
	axis:SetZ(2)
	axis:SetClickable(false)
	axis:SetWidth(2)
	return axis
end

--===== SIMPLE BAR =====--
local simpleBarMethods = {
	GetTile = function(self)
		return self.tile
	end,
	GetBackground = function(self)
		return self.background
	end,
	GetBar = function(self)
		return self.bar
	end,
	GetWidth = function(self)
		return self.background:GetWidth()
	end,
	SetWidth = function(self, width)
		local newWidth = math.max(0, width)
		self.background:SetWidth(newWidth)
		self.bar:SetWidth(math.max(0, newWidth - 2)*self.percent)
	end,
	GetHeight = function(self)
		return self.background:GetHeight()
	end,
	SetHeight = function(self, height)
		local newHeight = math.max(0, height)
		self.background:SetHeight(newHeight)
		self.bar:SetHeight(math.max(0, newHeight - 2))
	end,
	GetPercent = function(self)
		return self.percent
	end,
	SetPercent = function(self, percent)
		if type(percent) == "number" then
			self.percent = math.max(0, math.min(1, percent))
			self.bar:SetWidth((self:GetWidth() - 2)*self.percent)
			return true
		end
		return false
	end,
}
local simpleBarMetatable = makeMetatable(simpleBarMethods)

local function createSimpleBar(tile, width, height, opacity, bar, percent)
	local simpleBar = {
		tile = tile,
		percent = 0,
		background = createBackground(tile, width, height, opacity),
		bar = bar,
	}
	bar:SetZ(1)
	bar:SetClickable(false)
	setmetatable(simpleBar, simpleBarMetatable)
	if percent then
		simpleBar:SetPercent(percent)
	end
	return simpleBar
end

function addSimpleBoxBar(tile, xPos, yPos, zPos, width, height, colour, opacity, percent)
	local subTile = tile:AddSubTile(xPos, yPos, zPos)
	local bar = subTile:AddBox(1, 1, 0, height - 2, colour, opacity)
	return createSimpleBar(subTile, width, height, opacity/2, bar, percent)
end

function addSimpleGradientBoxBar(tile, xPos, yPos, zPos, width, height, colour1, opacity1, colour2, opacity2, gradient, percent)
	local subTile = tile:AddSubTile(xPos, yPos, zPos)
	local bar = subTile:AddGradientBox(1, 1, 0, height - 2, colour1, opacity1, colour2, opacity2, gradient)
	return createSimpleBar(subTile, width, height, (opacity1 + opacity2)/4, bar, percent)
end

function addSimpleFluidBar(tile, xPos, yPos, zPos, width, height, fluid, alpha, percent)
	local subTile = tile:AddSubTile(xPos, yPos, zPos)
	local bar = subTile:AddFluid(1, 1, 0, height - 2, fluid)
	bar:SetAlpha(alpha)
	return createSimpleBar(subTile, width, height, alpha/2, bar, percent)
end

--===== COMPLEX BAR =====--
local complexBarMethods = {
	GetTile = function(self)
		return self.tile
	end,
	GetBackground = function(self)
		return self.background
	end,
	GetWidth = function(self)
		return self.background:GetWidth()
	end,
	--[[
	SetWidth = function(self, width)
		local newWidth = math.max(0, width)
		self.background:SetWidth(newWidth)
		--self.bar:SetWidth(math.max(0, newWidth - 2)*self.percent)
	end,
	]]
	GetHeight = function(self)
		return self.background:GetHeight()
	end,
	--[[
	SetHeight = function(self, height)
		local newHeight = math.max(0, height)
		self.background:SetHeight(newHeight)
		--self.bar:SetHeight(math.max(0, newHeight - 2))
	end,
	]]
	GetPercent = function(self)
		return self.percent
	end,
	SetPercent = function(self, percent)
		if type(percent) == "number" then
			self.percent = math.max(0, math.min(1, percent))
			local segmentsDrawn = self.percent*#self.segments
			segmentsDrawn = math.floor(segmentsDrawn) + math.floor(2*(segmentsDrawn%1))
			for i, segment in ipairs(self.segments) do
				segment:SetVisible(i <= segmentsDrawn)
			end
			return true
		end
		return false
	end,
}
local complexBarMetatable = makeMetatable(complexBarMethods)

function addComplexBar(tile, xPos, yPos, zPos, width, height, colour, opacity, percent)
	local subTile = tile:AddSubTile(xPos, yPos, zPos)
	local complexBar = {
		tile = subTile,
		background = createBackground(subTile, width, height, opacity/2),
		segments = {},
	}
	
	local segmentWidth = math.ceil((width - 2)/40)
	local xStart = 1
	while xStart < width - 2 do
		local thisSegmentWidth = segmentWidth
		if xStart + segmentWidth > width - 1 then
			thisSegmentWidth = thisSegmentWidth - (xStart + segmentWidth) + (width - 1)
		end
		local segment = subTile:AddGradientBox(xStart, 1, thisSegmentWidth, height - 2, colour/3, opacity, colour, opacity, 2)
		segment:SetZ(1)
		segment:SetVisible(false)
		segment:SetClickable(false)
		table.insert(complexBar.segments, segment)
		xStart = xStart + segmentWidth
	end
	
	setmetatable(complexBar, complexBarMetatable)
	if percent then
		complexBar:SetPercent(percent)
	end
	return complexBar
end

--===== BAR GRAPH =====--
local barGraphMethods = {
	GetTile = function(self)
		return self.tile
	end,
	GetBackground = function(self)
		return self.background
	end,
	GetWidth = function(self)
		return self.background:GetWidth()
	end,
	--[[
	SetWidth = function(self, width)
		local newWidth = math.max(0, width)
		self.background:SetWidth(newWidth)
		--self.bar:SetWidth(math.max(0, newWidth - 2)*self.percent)
	end,
	]]
	GetHeight = function(self)
		return self.background:GetHeight()
	end,
	--[[
	SetHeight = function(self, height)
		local newHeight = math.max(0, height)
		self.background:SetHeight(newHeight)
		--self.bar:SetHeight(math.max(0, newHeight - 2))
	end,
	]]
	Update = function(self, value)
		if type(value) == "number" then
			table.insert(self.values, math.min(1, math.max(0, value)))
			table.remove(self.values, 1)
			for i, bar in ipairs(self.bars) do
				bar:SetHeight(self:GetHeight()*self.values[i])
			end
			return true
		end
		return false
	end,
}
local barGraphMetatable = makeMetatable(barGraphMethods)

local function createBarGraph(tile, width, height, opacity, bars)
	local barGraph = {
		tile = tile,
		values = {},
		bars = bars,
		background = createBackground(tile, width, height, opacity/4),
		axis = createAxis(tile, width, height, opacity),
	}
	for i = 1, width do
		barGraph.values[i] = 0
	end
	return setmetatable(barGraph, barGraphMetatable)
end

function addBoxBarGraph(tile, xPos, yPos, zPos, width, height, colour, opacity)
	local subTile = tile:AddSubTile(xPos, yPos, zPos)
	local bars = {}
	for x = 1, width do
		local bar = subTile:AddBox(x - 1, height, 1, 0, colour, opacity)
		bar:SetZ(1)
		bar:SetObjectAnchor("LEFT", "BOTTOM")
		bar:SetClickable(false)
		table.insert(bars, bar)
	end
	return createBarGraph(subTile, width, height, opacity, bars)
end

function addGradientBoxBarGraph(tile, xPos, yPos, zPos, width, height, colour, opacity)
	local subTile = tile:AddSubTile(xPos, yPos, zPos)
	local bars = {}
	for x = 1, width do
		local bar = subTile:AddGradientBox(x - 1, height, 1, 0, colour/3, opacity, colour, opacity, 2)
		bar:SetZ(1)
		bar:SetObjectAnchor("LEFT", "BOTTOM")
		bar:SetClickable(false)
		table.insert(bars, bar)
	end
	return createBarGraph(subTile, width, height, opacity, bars)
end

function addFluidBarGraph(tile, xPos, yPos, zPos, width, height, fluid, alpha)
	local subTile = tile:AddSubTile(xPos, yPos, zPos)
	local bars = {}
	for x = 1, width do
		local bar = subTile:AddFluid(x - 1, height, 1, 0, fluid)
		bar:SetZ(1)
		bar:SetObjectAnchor("LEFT", "BOTTOM")
		bar:SetClickable(false)
		bar:SetAlpha(alpha)
		table.insert(bars, bar)
	end
	return createBarGraph(subTile, width, height, alpha, bars)
end

--===== LINE GRAPH =====--
local lineGraphMethods = {
	GetTile = function(self)
		return self.tile
	end,
	GetBackground = function(self)
		return self.background
	end,
	GetWidth = function(self)
		return self.background:GetWidth()
	end,
	--[[
	SetWidth = function(self, width)
		local newWidth = math.max(0, width)
		self.background:SetWidth(newWidth)
		--self.bar:SetWidth(math.max(0, newWidth - 2)*self.percent)
	end,
	]]
	GetHeight = function(self)
		return self.background:GetHeight()
	end,
	--[[
	SetHeight = function(self, height)
		local newHeight = math.max(0, height)
		self.background:SetHeight(newHeight)
		--self.bar:SetHeight(math.max(0, newHeight - 2))
	end,
	]]
	Update = function(self, value)
		if type(value) == "number" then
			table.insert(self.values, math.min(1, math.max(0, value)))
			table.remove(self.values, 1)
			for i, point in ipairs(self.points) do
				point.y = -((self:GetHeight() - 1)*self.values[i])
			end
			self.line:SetPoints(self.points)
			return true
		end
		return false
	end,
}
local lineGraphMetatable = makeMetatable(lineGraphMethods)

local function createLineGraph(tile, width, height, opacity, points, line)
	local lineGraph = {
		tile = tile,
		values = {},
		points = points,
		line = line,
		background = createBackground(tile, width, height, opacity/4),
		axis = createAxis(tile, width, height, opacity),
	}
	for i = 1, width do
		lineGraph.values[i] = 0
	end
	return setmetatable(lineGraph, lineGraphMetatable)
end

function addLineGraph(tile, xPos, yPos, zPos, width, height, colour, opacity)
	local subTile = tile:AddSubTile(xPos, yPos, zPos)
	local pointsTile = subTile:AddSubTile(0, height - 1, 1)
	local points = {}
	for x = 1, width do
		table.insert(points, {x = x, y = 0})
	end
	local line = pointsTile:AddLineList(colour, opacity, points)
	line:SetZ(1)
	line:SetWidth(2)
	line:SetClickable(false)
	return createLineGraph(subTile, width, height, opacity, points, line)
end
