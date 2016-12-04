--- Compositing API for Terminal Glasses.
-- The Tiles API offers a new fundamental way of interacting with the Terminal Glasses drawing surface by allowing one to draw to subsurfaces called "Tiles".  This allows for the modular and composable creation of graphical elements from smaller constituent parts, and to treat such compositions as a single entity in a rational manner.
-- @author <a href=https://github.com/blunty666>Blunty666</a> (code) 
-- @author <a href=https://github.com/Fizzixnerd>Fizzixnerd</a> (docs)
-- @copyright <a href=https://github.com/blunty666>Blunty666</a>
-- @license <a href=https://opensource.org/licenses/MIT>MIT</a>

local widths = {
	[0]=0,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
	8,3,1,4,5,5,5,5,2,4,4,4,5,1,5,1,5,5,5,5,5,5,5,5,5,5,5,1,1,4,5,4,
	5,6,5,5,5,5,5,5,5,5,3,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,3,5,3,5,5,
	2,5,5,5,5,5,4,5,5,1,5,4,2,5,5,5,5,5,5,5,3,5,5,5,5,5,5,4,1,4,6,8,
}
--- Return the on-screen width of a string.
-- @string str
-- @raise error when str is not a string.
-- @treturn int width
function getStringWidth(str)
	if type(str) ~= "string" then
		error("getStringWidth: string expected", 2)
	end
	local width = 0
	local str_width = string.len(str)
	for i = 1, str_width do
		width = width + (widths[string.byte(string.sub(str, i, i))] or 5)
	end
	width = width + str_width - 1
	return width
end

--- Return the longest length of a substring of `str' starting at
-- `startPos' which will fit within a line of length `width'.
-- @string str
-- @number width
-- @number startPos
-- @raise error when str is not a string.
-- @treturn int width
function getMaxStringLength(str, width, startPos)
	if type(str) ~= "string" then
		error("getMaxStringLength: expected string, got "..type(str), 2)
	end
	local endPos = string.len(str)
	while getStringWidth(string.sub(str, startPos or 1, endPos)) > width do
		endPos = endPos - 1
	end
	return endPos
end

--- Return a table containing the locations of the sides, as well as
-- the width and height, of a bounding box for the points.
-- @{point, ...} points
local function findBounds(points)
	local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
	for _, point in ipairs(points) do
		if point.x < left then
			left = point.x
		end
		if point.x > right then
			right = point.x
		end
		if point.y < top then
			top = point.y
		end
		if point.y > bottom then
			bottom = point.y
		end
	end
	local width = right - left
	local height = bottom - top
	return {left = left, top = top, width = width, height = height, right = right, bottom = bottom}
end

--- Used to typecheck alignments
local ALIGNMENT = {
	HORIZONTAL = {
		LEFT = true,
		MIDDLE = true,
		RIGHT = true,
	},
	VERTICAL = {
		TOP = true,
		MIDDLE = true,
		BOTTOM = true,
	},
}

--- Contains functions for type-checking arguments.
-- @see tiles.checkProperty
local _checkProperty = {
	name = function(value)
		return value == nil or type(value) == "string"
	end,
	number = function(value)
		return type(value) == "number"
	end,
	positive_number = function(value)
		return type(value) == "number" and value >= 0
	end,
	string = function(value)
		return type(value) == "string"
	end,
	boolean = function(value)
		return type(value) == "boolean"
	end,
	alignment = function(horizontal, vertical)
		return ALIGNMENT.HORIZONTAL[string.upper(tostring(horizontal))] and ALIGNMENT.VERTICAL[string.upper(tostring(vertical))]
	end,
	userdata = function(value)
		return true
	end,
	["function"] = function(value)
		return type(value) == "function"
	end,
	percent = function(value)
		return type(value) == "number" and value >= 0 and value <= 1
	end,
	alpha = function(value)
		return type(value) == "number" and value >= 0 and value <= 255
	end,
	colour = function(value)
		return type(value) == "number" and value >= 0 and value <= 16777215
	end,
	gradient = function(value)
		return type(value) == "number" and (value == 1 or value == 2)
	end,
	simplePoint = function(value)
		return type(value) == "table" and type(value.x) == "number" and type(value.y) == "number"
	end,
	complexPoint = function(value)
		return type(value) == "table" and type(value.x) == "number" and type(value.y) == "number" and (value.rgb == nil or (type(value.rgb) == "number" and value.rgb >= 0 and value.rgb <= 16777215)) and (value.opacity == nil or (type(value.opacity) == "number" and value.opacity >= 0 and value.opacity <= 1))
	end,
	simplePoints = function(value)
		if type(value) == "table" then
			for index, point in pairs(value) do
				if type(index) ~= "number" or not (type(point) == "table" and type(point.x) == "number" and type(point.y) == "number") then
					return false
				end
			end
			return true
		end
		return false
	end,
	complexPoints = function(value)
		if type(value) == "table" then
			for index, point in pairs(value) do
				if type(index) ~= "number" or not (type(point) == "table" and type(point.x) == "number" and type(point.y) == "number" and (point.rgb == nil or (type(point.rgb) == "number" and point.rgb >= 0 and point.rgb <= 16777215)) and (point.opacity == nil or (type(point.opacity) == "number" and point.opacity >= 0 and point.opacity <= 1))) then
					return false
				end
			end
			return true
		end
		return false
	end,
	meta = function(value)
		return type(value) == "number" and value >= 0 and value <= 15
	end,
	surface = function(value)
		return type(value) == "table" and type(value.listSources) == "function" and value.listSources().glasses_container
	end,
	capture = function(value)
		return value == nil or (type(value) == "table" and type(value.listSources) == "function" and value.listSources().glasses_capture)
	end,
	bridge = function(value)
		return value == nil or (type(value) == "table" and type(value.listSources) == "function" and value.listSources().openperipheral_bridge)
	end,
	functionOrNil = function(value)
		return value == nil or type(value) == "function"
	end,
}

--- Contains functions for type-checking arguments.
-- If a function expects an argument of type `typename', then
-- `checkProperty[typename](val)` returns true iff `val' is of type
-- `typename'.
-- @field name A Lua string or nil.
-- @field number A Lua number.
-- @field positive_number A _non-negative_ Lua number.
-- @fixme positive_number lies about its name!
-- @field string A Lua string.
-- @field boolean A Lua boolean.
-- @field alignment A valid pair of alignment specifiers.
-- @field userdata Any value.
-- @field function A Lua function.
-- @field percent A Lua number between 0 and 1 (inclusive).
-- @field alpha An integer between 0 and 255 (inclusive).
-- @field colour An integer between 0x000000 and 0xFFFFFF (inclusive).
-- @fixme alias `color' for 'muricans.
-- @field gradient An integer equal to either 1 or 2.
-- @field simplePoint A table which has fields `x' and `y' with values which are Lua numbers.
-- @field complexPoint A `simplePoint' which optionally contains the fields `rgb' or `opacity' with values which are a `colour' and a `percent' respectively.
-- @field simplePoints An array of `simplePoint' values.
-- @field complexPoints An array of `complexPoint' values.
-- @field meta An integer between 0 and 15 (inclusive).  Represents a Minecraft item meta value.
-- @field surface A `surface' object as exposed by the Terminal Glasses API.
-- @field capture A `capture' object as exposed by the Terminal Glasses API.
-- @field bridge A wrapped Terminal Glasses Bridge (for example, the object returned by the call peripheral.wrap(sideOfBridge)).
-- @field functionOrNil A Lua function or nil.
checkProperty = {}
for property, checker in pairs(_checkProperty) do
	checkProperty[property] = checker
end

--- No idea.
-- @todo What exactly do these do...?
local formatPropertyIn = {
	alignment = function(horizontal, vertical)
		return {tostring(string.upper(horizontal)), tostring(string.upper(vertical))}
	end,
	simplePoint = function(point)
		return {x = point.x, y = point.y}
	end,
	complexPoint = function(point)
		return {x = point.x, y = point.y, rgb = point.rgb or 0xffffff, opacity = point.opacity or 1}
	end,
	simplePoints = function(points)
		local formatted = {}
		for index, point in pairs(points) do
			formatted[index] = {x = point.x, y = point.y}
		end
		return formatted
	end,
	complexPoints = function(points)
		local formatted = {}
		for index, point in pairs(points) do
			formatted[index] = {x = point.x, y = point.y, rgb = point.rgb or 0xffffff, opacity = point.opacity or 1}
		end
		return formatted
	end,
}

local formatPropertyOut = {
	alignment = function(alignment)
		return unpack(alignment)
	end,
	simplePoint = formatPropertyIn.simplePoint,
	complexPoint = formatPropertyIn.complexPoint,
	simplePoints = formatPropertyIn.simplePoints,
	complexPoints = formatPropertyIn.complexPoints,
}

local degToRadConstant = math.pi/180
local function degToRad(degree)
	return degree*degToRadConstant
end

--- Each function returns the value of the specified property
-- calculated with respect to a parent.
local calculateProperty = {
	X = function(parent, child)
		local rotation = degToRad(parent.Rotation)
		return parent.X + parent.Scale*(child.X*math.cos(rotation) - child.Y*math.sin(rotation))
	end,
	Y = function(parent, child)
		local rotation = degToRad(parent.Rotation)
		return parent.Y + parent.Scale*(child.Y*math.cos(rotation) + child.X*math.sin(rotation))
	end,
	Z = function(parent, child)
		return parent.Z + child.Z
	end,
	Rotation = function(parent, child)
		return (parent.Rotation + child.Rotation) % 360
	end,
	Scale = function(parent, child)
		return parent.Scale*child.Scale
	end,
	Opacity = function(parent, child)
		local opacity = parent.Opacity*child.Opacity
		return (opacity >= 0.01 and opacity) or 0
	end,
	Opacity1 = function(parent, child)
		local opacity = parent.Opacity*child.Opacity1
		return (opacity >= 0.01 and opacity) or 0
	end,
	Opacity2 = function(parent, child)
		local opacity = parent.Opacity*child.Opacity2
		return (opacity >= 0.01 and opacity) or 0
	end,
	Alpha = function(parent, child)
		local alpha = parent.Opacity*child.Alpha
		return (alpha >= 0.01 and alpha) or 0
	end,
	Visible = function(parent, child)
		return parent.Visible and child.Visible
	end,
	Clickable = function(parent, child)
		return parent.Clickable and child.Clickable
	end,
	Width = function(parent, child)
		return parent.Scale*child.Width
	end,
	Height = function(parent, child)
		return parent.Scale*child.Height
	end,
	Points = function(parent, child)
		local parentX, parentY = parent.X, parent.Y
		local parentScale, parentOpacity = parent.Scale, parent.Opacity
		local parentRotation = degToRad(parent.Rotation)
		local bounds = findBounds(child.Points)
		local relX = bounds.left*math.cos(parentRotation) - bounds.top*math.sin(parentRotation) - bounds.left
		local relY = bounds.top*math.cos(parentRotation) + bounds.left*math.sin(parentRotation) - bounds.top
		local points = {}
		for index, point in ipairs(child.Points) do
			local newPoint = {
				x = parentX + parentScale*(point.x + relX),
				y = parentY + parentScale*(point.y + relY),
			}
			newPoint.rgb = point.rgb
			newPoint.opacity = (point.opacity and parentOpacity*point.opacity) or nil
			if newPoint.opacity and newPoint.opacity < 0.01 then
				newPoint.opacity = 0
			end
			points[index] = newPoint
		end
		return points
	end,
	Coord = function(parent, child)
		local rotation = degToRad(parent.Rotation)
		return {
			x = parent.X + parent.Scale*(child.Coord.x*math.cos(rotation) - child.Coord.y*math.sin(rotation)),
			y = parent.Y + parent.Scale*(child.Coord.y*math.cos(rotation) + child.Coord.x*math.sin(rotation)),
		}
	end,
	Size = function(parent, child)
		return parent.Scale*child.Size
	end,
	Drawn = function(parent, child)
		return parent.Drawn and child.Drawn
	end,
}

--===== OBJECTS =====--
local setObjectProperty = {}
local drawObjectWithType = {}
local objectMetatables = {}

-- Metaprogramming magic below.
do -- create default object setters
	local simpleObjectProperties = {
		"Color", "Color1", "Color2",
		"Fluid", "Gradient", "Text",
		"ItemId", "Meta", "DamageBar", "Label",
	}
	for _, propertyName in ipairs(simpleObjectProperties) do
		setObjectProperty[propertyName] = {
			default = function(tile, object)
				object.drawable["set"..propertyName](object[propertyName])
			end,
		}
	end
	local complexObjectProperties = {
		"Z", "Rotation", "Scale",
		"Opacity", "Opacity1", "Opacity2", "Alpha",
		"Visible", "Clickable",
		"Width", "Height",
		"P1", "P2", "P3", "P4",
		"Points", "Coord", "Size",
	}
	for _, propertyName in ipairs(complexObjectProperties) do
		setObjectProperty[propertyName] = {
			default = function(tile, object)
				object.drawable["set"..propertyName](calculateProperty[propertyName](tile.current, object))
			end,
		}
	end
	setObjectProperty.X = {
		default = function(tile, object)
			object.drawable.setX(calculateProperty.X(tile.current, object))
			object.drawable.setY(calculateProperty.Y(tile.current, object))
		end,
	}
	setObjectProperty.Y = {
		default = function(tile, object)
			object.drawable.setX(calculateProperty.X(tile.current, object))
			object.drawable.setY(calculateProperty.Y(tile.current, object))
		end,
	}
	setObjectProperty.ObjectAnchor = {
		default = function(tile, object)
			object.drawable.setObjectAnchor(unpack(object.ObjectAnchor))
		end,
	}
	setObjectProperty.PosAndScale = {
		default = function(tile, object)
			object.drawable.setX(calculateProperty.X(tile.current, object))
			object.drawable.setY(calculateProperty.Y(tile.current, object))
			object.drawable.setScale(calculateProperty.Scale(tile.current, object))
		end,
	}
	setObjectProperty.PosAndRotation = {
		default = function(tile, object)
			object.drawable.setX(calculateProperty.X(tile.current, object))
			object.drawable.setY(calculateProperty.Y(tile.current, object))
			object.drawable.setRotation(calculateProperty.Rotation(tile.current, object))
		end,
	}
end

--- All Objects share these methods.
-- Objects are the drawable things in the API.  Note that Objects in
-- the same Tile _cannot_ share a name.
-- @type Object
-- @see Box
-- @see Fluid
-- @see GradientBox
-- @see GradientLine

--- Delete the Object and remove it from its parent Tile.
-- @function Object:Delete
-- @treturn bool success

--- Return ID of Object.
-- @function Object:GetID
-- @treturn int id

--- Return type of Object.
-- @function Object:GetType
-- @treturn string type

--- Return parent Tile of Object.
-- @function Object:GetTile
-- @treturn tiles.Tile parent

--- Return name of Object or nil if not named.
-- @function Object:GetName
-- @treturn ?string name

--- Sets name of Object and return true, or return false if name was not set.  Passing nil will unname the Object.
-- @function Object:SetName
-- @tparam ?string name
-- @treturn bool success

--- Return the arbitrary userdata associated with the Object.
-- @function Object:GetUserdata
-- @treturn ?any data

--- Set the arbitrary userdata associated with the Object.
-- @function Object:SetUserdata
-- @tparam ?any data
-- @treturn bool success

--- Set the anchoring of the Object.
-- @function Object:SetObjectAnchor
-- @tparam string horizontal One of "left", "middle", or "right".
-- @tparam string vertical One of "top", "middle", or "bottom".

--- Return the anchoring of the Object.
-- @function Object:GetObjectAnchor
-- @treturn string horizontal
-- @treturn string vertical

--- Set whether the Object can receive OnClick events.
-- @function Object:SetClickable
-- @bool isClickable
-- @treturn bool success

--- Return whether the Object can receive OnClick events.
-- @function Object:GetClickable
-- @treturn bool isClickable

--- Set the rotation angle of the Object in degrees.
-- @function Object:SetRotation
-- @number angle
-- @treturn bool success

--- Return the rotation angle of the Object in degrees.
-- @function Object:GetRotation
-- @treturn number angle

--- Set whether the Object is visible.
-- @function Object:SetVisible
-- @bool isVisible
-- @treturn bool success

--- Return whether the Object is visible.
-- @function Object:GetVisible
-- @treturn bool isVisible

--- Set the Z coordinate of the Object.
-- @function Object:SetZ
-- @number z
-- @treturn bool success

--- Return the Z coordinate of the Object.
-- @function Object:GetZ
-- @treturn number z

--- Set the callback for when the Object is clicked.  Pass nil to remove the callback.
-- @function Object:SetOnClick
-- @tparam ?func callback
-- @treturn bool success

--- Return the callback for when the Object is clicked.  Return nil if no such callback is set.
-- @function Object:GetOnClick
-- @treturn ?func callback

--- Set the callback for when the Object is unclicked.  Pass nil to remove the callback.
-- @function Object:SetOnRelease
-- @tparam ?func callback
-- @treturn bool success

--- Return the callback for when the Object is unclicked.  Return nil if no such callback is set.
-- @function Object:GetOnRelease
-- @treturn ?func callback

--- Set the callback for when the Object is dragged.  Pass nil to remove the callback.
-- @function Object:SetOnDrag
-- @tparam ?func callback
-- @treturn bool success

--- Return the callback for when the Object is dragged.  Return nil if no such callback is set.
-- @function Object:GetOnDrag
-- @treturn ?func callback

--- Set the callback for when the Object is scrolled.  Pass nil to remove the callback.
-- @function Object:SetOnScroll
-- @tparam ?func callback
-- @treturn bool success

--- Return the callback for when the Object is scrolled.  Return nil if no such callback is set.
-- @function Object:GetOnScroll
-- @treturn ?func callback

--- Set the callback for when the Object has a key pressed on it.  Pass nil to remove the callback.
-- @function Object:SetOnKeyDown
-- @tparam ?func callback
-- @treturn bool success

--- Return the callback for when the Object has a key pressed on it.  Return nil if no such callback is set.
-- @function Object:GetOnKeyDown
-- @treturn ?func callback

--- Set the callback for when the Object has a key unpressed on it.  Pass nil to remove the callback.
-- @function Object:SetOnKeyUp
-- @tparam ?func callback
-- @treturn bool success

--- Return the callback for when the Object has a key unpressed on it.  Return nil if no such callback is set.
-- @function Object:GetOnKeyUp
-- @treturn ?func callback

--- Set the callback for when the Object is selected.  Pass nil to remove the callback.
-- @function Object:SetOnSelect
-- @tparam ?func callback
-- @treturn bool success

--- Return the callback for when the Object is selected.  Return nil if no such callback is set.
-- @function Object:GetOnSelect
-- @treturn ?func callback

--- Set the callback for when the Object is deselected.  Pass nil to remove the callback.
-- @function Object:SetOnDeselect
-- @tparam ?func callback
-- @treturn bool success

--- Return the callback for when the Object is deselected.  Return nil if no such callback is set.
-- @function Object:GetOnDeselect
-- @treturn ?func callback

local baseObjectMethods = {
	GetID = function(self)
		return self.ID
	end,
	GetType = function(self)
		return self.Type
	end,
	GetTile = function(self)
		return self.tile
	end,
	GetName = function(self)
		return self.Name
	end,
	SetName = function(self, name)
		if _checkProperty.name(name) then
			if name == nil and self.Name ~= nil then
				self.tile.objects.nameToID[self.Name] = nil
				self.tile.surfaceHandler.objects.nameToID[self.Name] = nil
				self.Name = nil
				return true
			elseif name ~= nil and not self.tile.surfaceHandler.objects.nameToID[self.Name] then
				self.tile.objects.nameToID[name] = self.ID
				self.tile.surfaceHandler.objects.nameToID[name] = self.ID
				self.Name = name
				return true
			end
		end
		return false
	end,
	
	GetUserdata = function(self)
		return self.Userdata
	end,
	SetUserdata = function(self, userdata)
		self.Userdata = userdata
		return true
	end,
	Delete = function(self)
		if self.drawable then
			self.drawable.delete()
			self.drawable = false
			self.tile.surfaceHandler.changed = true
		end
		self.tile.objects.list[self.ID] = nil
		self.tile.surfaceHandler.objects.list[self.ID] = nil
		if self.Name then
			self.tile.objects.nameToID[self.Name] = nil
			self.tile.surfaceHandler.objects.nameToID[self.Name] = nil
		end
		setmetatable(self, nil)
		local index = next(self)
		while index do
			self[index] = nil
			index = next(self)
		end
		return true
	end,
}

local baseObjectProperties = {
	ObjectAnchor = "alignment",
	Clickable = "boolean", Rotation = "number",
	Visible = "boolean", Z = "number",
	OnClick = "functionOrNil", OnDrag = "functionOrNil",
	OnRelease = "functionOrNil", OnScroll = "functionOrNil",
	OnKeyDown = "functionOrNil", OnKeyUp = "functionOrNil",
	OnSelect = "functionOrNil", OnDeselect = "functionOrNil",
}

local function setDrawableProperties(tile, object, drawable)
	drawable.setVisible(calculateProperty.Visible(tile.current, object))
	drawable.setClickable(calculateProperty.Clickable(tile.current, object))
	drawable.setScreenAnchor(unpack(tile.current.ScreenAnchor))
	drawable.setObjectAnchor(unpack(object.ObjectAnchor))
	drawable.setZ(calculateProperty.Z(tile.current, object))
	drawable.setRotation(calculateProperty.Rotation(tile.current, object))
	drawable.setUserdata(object.ID)
end

local function newObject(tile, objectType, name)
	local name = (not _checkProperty.name(name) and error("name: expected string, got "..type(name))) or name
	if name and tile.surfaceHandler.objects.nameToID[name] then
		error("object name in use", 2)
	end
	local objectID = tile.surfaceHandler.objects.nextID
	tile.surfaceHandler.objects.nextID = objectID + 1
	local object = {
		ID = objectID,
		Type = objectType,
		
		tile = tile,
		
		Z = 0,
		Rotation = 0,
		Visible = true,
		Clickable = true,
		ObjectAnchor = {"LEFT", "TOP"},
		Userdata = nil,
		Name = name,
	}
	setmetatable(object, objectMetatables[objectType])
	
	tile.objects.list[objectID] = object
	tile.surfaceHandler.objects.list[objectID] = object
	
	if name then
		tile.objects.nameToID[name] = objectID
		tile.surfaceHandler.objects.nameToID[name] = objectID
	end
	if tile.current.Drawn then
		tile.surfaceHandler.changed = true
	end
	return object
end

local function setBoxPosAndScale(tile, object)
	object.drawable.setX(calculateProperty.X(tile.current, object))
	object.drawable.setY(calculateProperty.Y(tile.current, object))
	object.drawable.setWidth(calculateProperty.Width(tile.current, object))
	object.drawable.setHeight(calculateProperty.Height(tile.current, object))
end

local function setPoints(tile, object)
	local points = {Points = {object.P1, object.P2, object.P3, object.P4}}
	points = calculateProperty.Points(tile.current, points)
	for n, point in ipairs(points) do
		object.drawable["setP"..n](point)
	end
end

--- A colored box Object.
-- @type Box
-- @see Tile:AddBox
-- @see Object

--- Set the X coordinate of the Box.
-- @function Box:SetX
-- @number x
-- @treturn bool success

--- Get the X coordinate of the Box.
-- @function Box:GetX
-- @treturn number x

--- Set the Y coordinate of the Box.
-- @function Box:SetY
-- @number y
-- @treturn bool success

--- Get the Y coordinate of the Box.
-- @function Box:GetY
-- @treturn number y

--- Set the width of the Box.
-- @function Box:SetWidth
-- @tparam positive_number width
-- @treturn bool success
-- @see checkProperty

--- Get the width of the Box.
-- @function Box:GetWidth
-- @treturn positive_number width
-- @see checkProperty

--- Set the height of the Box.
-- @function Box:SetHeight
-- @tparam positive_number height
-- @treturn bool success
-- @see checkProperty

--- Get the height of the Box.
-- @function Box:GetHeight
-- @treturn positive_number height
-- @see checkProperty

--- Set the color of the Box.
-- @function Box:SetColor
-- @tparam color color
-- @treturn bool success
-- @see checkProperty

--- Get the color of the Box.
-- @function Box:GetColor
-- @treturn color color
-- @see checkProperty

--- Set the opacity of the Box.
-- @function Box:SetOpacity
-- @tparam percent opacity
-- @treturn bool success
-- @see checkProperty

--- Get the opacity of the Box.
-- @function Box:GetOpacity
-- @treturn percent opacity
-- @see checkProperty

--- A fluid textured box Object
-- @type Fluid
-- @see Tile:AddFluid
-- @see Object

--- Set the X coordinate of the Fluid.
-- @function Fluid:SetX
-- @number x
-- @treturn bool success

--- Get the X coordinate of the Fluid.
-- @function Fluid:GetX
-- @treturn number x

--- Set the Y coordinate of the Fluid.
-- @function Fluid:SetY
-- @number y
-- @treturn bool success

--- Get the Y coordinate of the Fluid.
-- @function Fluid:GetY
-- @treturn number y

--- Set the width of the Fluid.
-- @function Fluid:SetWidth
-- @tparam positive_number width
-- @treturn bool success
-- @see checkProperty

--- Get the width of the Fluid.
-- @function Fluid:GetWidth
-- @treturn positive_number width
-- @see checkProperty

--- Set the height of the Fluid.
-- @function Fluid:SetHeight
-- @tparam positive_number height
-- @treturn bool success
-- @see checkProperty

--- Get the height of the Fluid.
-- @function Fluid:GetHeight
-- @treturn positive_number height
-- @see checkProperty

--- Set the fluid which is displayed.
-- @function Fluid:SetFluid
-- @string fluid
-- @treturn bool success

--- Get the fluid which is displayed.
-- @function Fluid:GetFluid
-- @treturn string fluid

--- Set the alpha (opacity) of the Fluid.
-- @function Fluid:SetAlpha
-- @tparam percent alpha
-- @treturn success
-- @see checkProperty

--- Get the alpha (opacity) of the Fluid.
-- @function Fluid:GetAlpha
-- @treturn percent alpha
-- @see checkProperty

--- A colored box Object with a gradient.
-- @type GradientBox
-- @see Tile:AddGradientBox
-- @see Object

--- Set the X coordinate of the GradientBox.
-- @function GradientBox:SetX
-- @number x
-- @treturn bool success

--- Get the X coordinate of the GradientBox.
-- @function GradientBox:GetX
-- @treturn number x

--- Set the Y coordinate of the GradientBox.
-- @function GradientBox:SetY
-- @number y
-- @treturn bool success

--- Get the Y coordinate of the GradientBox.
-- @function GradientBox:GetY
-- @treturn number y

--- Set the width of the GradientBox.
-- @function GradientBox:SetWidth
-- @tparam positive_number width
-- @treturn bool success
-- @see checkProperty

--- Get the width of the GradientBox.
-- @function GradientBox:GetWidth
-- @treturn positive_number width
-- @see checkProperty

--- Set the height of the GradientBox.
-- @function GradientBox:SetHeight
-- @tparam positive_number height
-- @treturn bool success
-- @see checkProperty

--- Get the height of the GradientBox.
-- @function GradientBox:GetHeight
-- @treturn positive_number height
-- @see checkProperty

--- Set the first color of the GradientBox.
-- @todo be more explicit with these color things.
-- @function GradientBox:SetColor1
-- @tparam color color1
-- @treturn bool success
-- @see checkProperty

--- Get the first color of the GradientBox.
-- @function GradientBox:GetColor1
-- @treturn color color1
-- @see checkProperty

--- Set the second color of the GradientBox.
-- @todo be more explicit with these color things.
-- @function GradientBox:SetColor2
-- @tparam color color2
-- @treturn bool success
-- @see checkProperty

--- Get the second color of the GradientBox.
-- @function GradientBox:GetColor2
-- @treturn color color2
-- @see checkProperty

--- Set the first opacity of the GradientBox.
-- @function GradientBox:SetOpacity1
-- @tparam percent opacity1
-- @treturn bool success
-- @see checkProperty

--- Get the first opacity of the GradientBox.
-- @function GradientBox:GetOpacity1
-- @treturn percent opacity1
-- @see checkProperty

--- Set the second opacity of the GradientBox.
-- @function GradientBox:SetOpacity2
-- @tparam percent opacity2
-- @treturn bool success
-- @see checkProperty

--- Get the second opacity of the GradientBox.
-- @function GradientBox:GetOpacity2
-- @treturn percent opacity2
-- @see checkProperty

--- Set the gradient of the GradientBox
-- @todo what does this even mean?
-- @function GradientBox:SetGradient
-- @tparam gradient gradient
-- @treturn bool success
-- @see checkProperty

--- Get the gradient of the GradientBox
-- @todo what does this even mean?
-- @function GradientBox:GetGradient
-- @treturn gradient gradient
-- @see checkProperty

--- A line Object with a color gradient.
-- @type GradientLine
-- @see Tile:AddGradientLine
-- @see Line

--- Set the first point of the GradientLine. Copies the point, so modification of them after setting will not affect the Object.
-- @function GradientLine:SetP1
-- @tparam complexPoint p1
-- @treturn bool success
-- @see checkProperty

--- Get the first point of the GradientLine. Copies the point, so modification of them after getting will not affect the Object.
-- @function GradientLine:GetP1
-- @treturn complexPoint p1
-- @see checkProperty

--- Set the second point of the GradientLine. Copies the point, so modification of them after setting will not affect the Object.
-- @function GradientLine:SetP2
-- @tparam complexPoint p2
-- @treturn bool success
-- @see checkProperty

--- Get the second point of the GradientLine. Copies the point, so modification of them after getting will not affect the Object.
-- @function GradientLine:GetP2
-- @treturn complexPoint p2
-- @see checkProperty

--- A bunch of Gradient Lines (I think?)
-- @type GradientLineList
-- @fixme I've never actually used one of these.  Is just a bunch of lines?

--- Set the terminal points of the GradientLineList.  Copies the points, so modification of them after setting will not affect the Object.
-- @function GradientLineList:SetPoints
-- @tparam {complexPoint,...} points
-- @treturn bool success
-- @see checkProperty

--- Get the array of terminal points of the GradientLineList.  Copies the points, so modification of them after getting will not affect the Object.
-- @function GradientLineList:GetPoints
-- @treturn {complexPoint,...} points
-- @see checkProperty

--- Here we create the templates for each object and specify special functions.
local objects = {
	Box = {
		properties = {
			X = "number", Y = "number",
			Width = "positive_number", Height = "positive_number",
			Color = "colour", Opacity = "percent",
		},
		draw = function(tile, boxObject)
			local xPos = calculateProperty.X(tile, boxObject)
			local yPos = calculateProperty.Y(tile, boxObject)
			local width = calculateProperty.Width(tile, boxObject)
			local height = calculateProperty.Height(tile, boxObject)
			local opacity = calculateProperty.Opacity(tile, boxObject)
			local drawable = boxObject.tile.surfaceHandler.surface.addBox(xPos, yPos, width, height, boxObject.Color, opacity)
			setDrawableProperties(boxObject.tile, boxObject, drawable)
			return drawable
		end,
		new = function(tile, xPos, yPos, width, height, colour, opacity, name)
			if not _checkProperty.number(xPos) then error("Check xPos", 2) end
			if not _checkProperty.number(yPos) then error("Check yPos", 2) end
			if not _checkProperty.positive_number(width) then error("Check width", 2) end
			if not _checkProperty.positive_number(height) then error("Check height", 2) end
			if not _checkProperty.colour(colour) then error("Check colour", 2) end
			if not _checkProperty.percent(opacity) then error("Check opacity", 2) end
			local boxObject = newObject(tile, "Box", name) -- create tile object
			boxObject.X = xPos
			boxObject.Y = yPos
			boxObject.Width = width
			boxObject.Height = height
			boxObject.Opacity = opacity
			boxObject.Color = colour
			if tile.current.Drawn then
				boxObject.drawable = drawObjectWithType.Box(tile.current, boxObject)
			end
			return boxObject
		end,
		setProperty = {
			PosAndScale = setBoxPosAndScale,
		},
	},
	Fluid = {
		properties = {
			X = "number", Y = "number",
			Width = "positive_number", Height = "positive_number",
			Fluid = "string", Alpha = "percent",
		},
		draw = function(tile, fluidObject)
			local xPos = calculateProperty.X(tile, fluidObject)
			local yPos = calculateProperty.Y(tile, fluidObject)
			local width = calculateProperty.Width(tile, fluidObject)
			local height = calculateProperty.Height(tile, fluidObject)
			local alpha = calculateProperty.Alpha(tile, fluidObject)
			local drawable = fluidObject.tile.surfaceHandler.surface.addFluid(xPos, yPos, width, height, fluidObject.Fluid)
			drawable.setAlpha(alpha)
			setDrawableProperties(fluidObject.tile, fluidObject, drawable)
			return drawable
		end,
		new = function(tile, xPos, yPos, width, height, fluid)
			if not _checkProperty.number(xPos) then error("Check xPos", 2) end
			if not _checkProperty.number(yPos) then error("Check yPos", 2) end
			if not _checkProperty.positive_number(width) then error("Check width", 2) end
			if not _checkProperty.positive_number(height) then error("Check height", 2) end
			if not _checkProperty.string(fluid) then error("Check fluid", 2) end
			local fluidObject = newObject(tile, "Fluid", name) -- create tile object
			fluidObject.X = xPos
			fluidObject.Y = yPos
			fluidObject.Width = width
			fluidObject.Height = height
			fluidObject.Fluid = fluid
			fluidObject.Alpha = 1
			if tile.current.Drawn then
				fluidObject.drawable = drawObjectWithType.Fluid(tile.current, fluidObject)
			end
			return fluidObject
		end,
		setProperty = {
			Opacity = function(tile, fluidObject)
				fluidObject.drawable.setAlpha(calculateProperty.Alpha(tile.current, fluidObject))
			end,
			PosAndScale = setBoxPosAndScale,
		},
	},
	GradientBox = {
		properties = {
			X = "number", Y = "number",
			Width = "positive_number", Height = "positive_number",
			Color1 = "colour", Opacity1 = "percent",
			Color2 = "colour", Opacity2 = "percent",
			Gradient = "gradient",
		},
		draw = function(tile, gradientBoxObject)
			local xPos = calculateProperty.X(tile, gradientBoxObject)
			local yPos = calculateProperty.Y(tile, gradientBoxObject)
			local width = calculateProperty.Width(tile, gradientBoxObject)
			local height = calculateProperty.Height(tile, gradientBoxObject)
			local opacity1 = calculateProperty.Opacity1(tile, gradientBoxObject)
			local opacity2 = calculateProperty.Opacity2(tile, gradientBoxObject)
			local drawable = gradientBoxObject.tile.surfaceHandler.surface.addGradientBox(xPos, yPos, width, height, gradientBoxObject.Color1, opacity1, gradientBoxObject.Color2, opacity2, gradientBoxObject.Gradient)
			setDrawableProperties(gradientBoxObject.tile, gradientBoxObject, drawable)
			return drawable
		end,
		new = function(tile, xPos, yPos, width, height, colour1, opacity1, colour2, opacity2, gradient, name)
			if not _checkProperty.number(xPos) then error("Check xPos", 2) end
			if not _checkProperty.number(yPos) then error("Check yPos", 2) end
			if not _checkProperty.positive_number(width) then error("Check width", 2) end
			if not _checkProperty.positive_number(height) then error("Check height", 2) end
			if not _checkProperty.colour(colour1) then error("Check colour1", 2) end
			if not _checkProperty.percent(opacity1) then error("Check opacity1", 2) end
			if not _checkProperty.colour(colour2) then error("Check colour2", 2) end
			if not _checkProperty.percent(opacity2) then error("Check opacity2", 2) end
			if not _checkProperty.gradient(gradient) then error("Check gradient", 2) end
			local gradientBoxObject = newObject(tile, "GradientBox", name)
			gradientBoxObject.X = xPos
			gradientBoxObject.Y = yPos
			gradientBoxObject.Width = width
			gradientBoxObject.Height = height
			gradientBoxObject.Opacity1 = opacity1
			gradientBoxObject.Color1 = colour1
			gradientBoxObject.Opacity2 = opacity2
			gradientBoxObject.Color2 = colour2
			gradientBoxObject.Gradient = gradient
			if tile.current.Drawn then
				gradientBoxObject.drawable = drawObjectWithType.GradientBox(tile.current, gradientBoxObject)
			end
			return gradientBoxObject
		end,
		setProperty = {
			Opacity = function(tile, gradientBoxObject)
				gradientBoxObject.drawable.setOpacity1(calculateProperty.Opacity1(tile.current, gradientBoxObject))
				gradientBoxObject.drawable.setOpacity2(calculateProperty.Opacity2(tile.current, gradientBoxObject))
			end,
			PosAndScale = setBoxPosAndScale,
		},
	},
	GradientLine = {
		properties = {
			P1 = "complexPoint", P2 = "complexPoint", Width = "positive_number",
		},
		draw = function(tile, gradientLineObject)
			local points = {Points = {gradientLineObject.P1, gradientLineObject.P2}}
			points = calculateProperty.Points(tile, points)
			local width = calculateProperty.Width(tile, gradientLineObject)
			local drawable = gradientLineObject.tile.surfaceHandler.surface.addGradientLine(points[1], points[2])
			drawable.setWidth(width)
			setDrawableProperties(gradientLineObject.tile, gradientLineObject, drawable)
			return drawable
		end,
		new = function(tile, p1, p2, name)
			if not _checkProperty.complexPoint(p1) then error("check P1", 2) end
			if not _checkProperty.complexPoint(p2) then error("check P2", 2) end
			local gradientLineObject = newObject(tile, "GradientLine", name)
			gradientLineObject.P1 = formatPropertyIn.complexPoint(p1)
			gradientLineObject.P2 = formatPropertyIn.complexPoint(p2)
			gradientLineObject.Width = 1
			if tile.current.Drawn then
				gradientLineObject.drawable = drawObjectWithType.GradientLine(tile.current, gradientLineObject)
			end
			return gradientLineObject
		end,
		setProperty = {
			P1 = setPoints,
			P2 = setPoints,
			X = setPoints,
			Y = setPoints,
			Opacity = setPoints,
			PosAndScale = function(tile, gradientLineObject)
				setPoints(tile, gradientLineObject)
				gradientLineObject.drawable.setWidth(calculateProperty.Width(tile.current, gradientLineObject))
			end,
			PosAndRotation = function(tile, gradientLineObject)
				setPoints(tile, gradientLineObject)
				gradientLineObject.drawable.setRotation(calculateProperty.Rotation(tile.current, gradientLineObject))
			end,
		},
	},
	GradientLineList = {
		properties = {
			Points = "complexPoints", Width = "positive_number",
		},
		draw = function(tile, gradientLineListObject)
			local points = calculateProperty.Points(tile, gradientLineListObject)
			local width = calculateProperty.Width(tile, gradientLineListObject)
			local drawable = gradientLineListObject.tile.surfaceHandler.surface.addGradientLineList(unpack(points))
			drawable.setWidth(width)
			setDrawableProperties(gradientLineListObject.tile, gradientLineListObject, drawable)
			return drawable
		end,
		new = function(tile, points, name)
			if not _checkProperty.complexPoints(points) then error("check points", 2) end
			local gradientLineListObject = newObject(tile, "GradientLineList", name)
			gradientLineListObject.Points = formatPropertyIn.complexPoints(points)
			gradientLineListObject.Width = 1
			if tile.current.Drawn then
				gradientLineListObject.drawable = drawObjectWithType.GradientLineList(tile.current, gradientLineListObject)
			end
			return gradientLineListObject
		end,
		setProperty = {
			X = function(tile, gradientLineListObject)
				gradientLineListObject.drawable.setPoints(calculateProperty.Points(tile.current, gradientLineListObject))
			end,
			Y = function(tile, gradientLineListObject)
				gradientLineListObject.drawable.setPoints(calculateProperty.Points(tile.current, gradientLineListObject))
			end,
			Opacity = function(tile, gradientLineListObject)
				gradientLineListObject.drawable.setPoints(calculateProperty.Points(tile.current, gradientLineListObject))
			end,
			PosAndScale = function(tile, gradientLineListObject)
				gradientLineListObject.drawable.setPoints(calculateProperty.Points(tile.current, gradientLineListObject))
				gradientLineListObject.drawable.setWidth(calculateProperty.Width(tile.current, gradientLineListObject))
			end,
			PosAndRotation = function(tile, gradientLineListObject)
				gradientLineListObject.drawable.setPoints(calculateProperty.Points(tile.current, gradientLineListObject))
				gradientLineListObject.drawable.setRotation(calculateProperty.Rotation(tile.current, gradientLineListObject))
			end,
		},
	},
	GradientPolygon = {
		properties = {
			Points = "complexPoints",
		},
		draw = function(tile, gradientPolygonObject)
			local points = calculateProperty.Points(tile, gradientPolygonObject)
			local drawable = gradientPolygonObject.tile.surfaceHandler.surface.addGradientPolygon(unpack(points))
			setDrawableProperties(gradientPolygonObject.tile, gradientPolygonObject, drawable)
			return drawable
		end,
		new = function(tile, points, name)
			if not _checkProperty.complexPoints(points) then error("check points", 2) end
			local gradientPolygonObject = newObject(tile, "GradientPolygon", name)
			gradientPolygonObject.Points = formatPropertyIn.complexPoints(points)
			if tile.current.Drawn then
				gradientPolygonObject.drawable = drawObjectWithType.GradientPolygon(tile.current, gradientPolygonObject)
			end
			return gradientPolygonObject
		end,
		setProperty = {
			X = function(tile, gradientPolygonObject)
				gradientPolygonObject.drawable.setPoints(calculateProperty.Points(tile.current, gradientPolygonObject))
			end,
			Y = function(tile, gradientPolygonObject)
				gradientPolygonObject.drawable.setPoints(calculateProperty.Points(tile.current, gradientPolygonObject))
			end,
			Opacity = function(tile, gradientPolygonObject)
				gradientPolygonObject.drawable.setPoints(calculateProperty.Points(tile.current, gradientPolygonObject))
			end,
			PosAndScale = function(tile, gradientPolygonObject)
				gradientPolygonObject.drawable.setPoints(calculateProperty.Points(tile.current, gradientPolygonObject))
			end,
			PosAndRotation = function(tile, gradientPolygonObject)
				gradientPolygonObject.drawable.setPoints(calculateProperty.Points(tile.current, gradientPolygonObject))
				gradientPolygonObject.drawable.setRotation(calculateProperty.Rotation(tile.current, gradientPolygonObject))
			end,
		},
	},
	GradientQuad = {
		properties = {
			P1 = "complexPoint", P2 = "complexPoint",
			P3 = "complexPoint", P4 = "complexPoint",
		},
		draw = function(tile, gradientQuadObject)
			local points = {Points = {gradientQuadObject.P1, gradientQuadObject.P2, gradientQuadObject.P3, gradientQuadObject.P4}}
			points = calculateProperty.Points(tile, points)
			local drawable = gradientQuadObject.tile.surfaceHandler.surface.addGradientQuad(points[1], points[2], points[3], points[4])
			setDrawableProperties(gradientQuadObject.tile, gradientQuadObject, drawable)
			return drawable
		end,
		new = function(tile, p1, p2, p3, p4, name)
			if not _checkProperty.complexPoint(p1) then error("check P1") end
			if not _checkProperty.complexPoint(p2) then error("check P2") end
			if not _checkProperty.complexPoint(p3) then error("check P3") end
			if not _checkProperty.complexPoint(p4) then error("check P4") end
			local gradientQuadObject = newObject(tile, "GradientQuad", name)
			gradientQuadObject.P1 = formatPropertyIn.complexPoint(p1)
			gradientQuadObject.P2 = formatPropertyIn.complexPoint(p2)
			gradientQuadObject.P3 = formatPropertyIn.complexPoint(p3)
			gradientQuadObject.P4 = formatPropertyIn.complexPoint(p4)
			if tile.current.Drawn then
				gradientQuadObject.drawable = drawObjectWithType.GradientQuad(tile.current, gradientQuadObject)
			end
			return gradientQuadObject
		end,
		setProperty = {
			P1 = setPoints,
			P2 = setPoints,
			P3 = setPoints,
			P4 = setPoints,
			X = setPoints,
			Y = setPoints,
			Opacity = setPoints,
			PosAndScale = setPoints,
			PosAndRotation = function(tile, gradientQuadObject)
				setPoints(tile, gradientQuadObject)
				gradientQuadObject.drawable.setRotation(calculateProperty.Rotation(tile.current, gradientQuadObject))
			end,
		},
	},
	GradientTriangle = {
		properties = {
			P1 = "complexPoint", P2 = "complexPoint", P3 = "complexPoint",
		},
		draw = function(tile, gradientTriangleObject)
			local points = {Points = {gradientTriangleObject.P1, gradientTriangleObject.P2, gradientTriangleObject.P3}}
			points = calculateProperty.Points(tile, points)
			local drawable = gradientTriangleObject.tile.surfaceHandler.surface.addGradientTriangle(points[1], points[2], points[3])
			setDrawableProperties(gradientTriangleObject.tile, gradientTriangleObject, drawable)
			return drawable
		end,
		new = function(tile, p1, p2, p3, name)
			if not _checkProperty.complexPoint(p1) then error("check P1") end
			if not _checkProperty.complexPoint(p2) then error("check P2") end
			if not _checkProperty.complexPoint(p3) then error("check P3") end
			local gradientTriangleObject = newObject(tile, "GradientTriangle", name)
			gradientTriangleObject.P1 = formatPropertyIn.complexPoint(p1)
			gradientTriangleObject.P2 = formatPropertyIn.complexPoint(p2)
			gradientTriangleObject.P3 = formatPropertyIn.complexPoint(p3)
			if tile.current.Drawn then
				gradientTriangleObject.drawable = drawObjectWithType.GradientTriangle(tile.current, gradientTriangleObject)
			end
			return gradientTriangleObject
		end,
		setProperty = {
			P1 = setPoints,
			P2 = setPoints,
			P3 = setPoints,
			P4 = setPoints,
			X = setPoints,
			Y = setPoints,
			Opacity = setPoints,
			PosAndScale = setPoints,
			PosAndRotation = function(tile, gradientTriangleObject)
				setPoints(tile, gradientTriangleObject)
				gradientTriangleObject.drawable.setRotation(calculateProperty.Rotation(tile.current, gradientTriangleObject))
			end,
		},
	},
	Icon = {
		properties = {
			X = "number", Y = "number",
			ItemId = "string", Meta = "positive_number",
			DamageBar = "percent", Label = "string",
			Scale = "positive_number",
		},
		draw = function(tile, iconObject)
			local xPos = calculateProperty.X(tile, iconObject)
			local yPos = calculateProperty.Y(tile, iconObject)
			local scale = calculateProperty.Scale(tile, iconObject)
			local drawable = iconObject.tile.surfaceHandler.surface.addIcon(xPos, yPos, iconObject.ItemId, iconObject.Meta)
			drawable.setDamageBar(iconObject.DamageBar)
			drawable.setLabel(iconObject.Label)
			drawable.setScale(scale)
			setDrawableProperties(iconObject.tile, iconObject, drawable)
			return drawable
		end,
		new = function(tile, xPos, yPos, itemId, meta, name)
			if not _checkProperty.number(xPos) then error("Check xPos", 2) end
			if not _checkProperty.number(yPos) then error("Check yPos", 2) end
			if not _checkProperty.string(itemId) then error("Check itemId", 2) end
			if meta ~= nil and not _checkProperty.positive_number(meta) then error("Check meta", 2) end
			local iconObject = newObject(tile, "Icon", name)
			iconObject.X = xPos
			iconObject.Y = yPos
			iconObject.ItemId = itemId
			iconObject.Meta = meta or 0
			iconObject.DamageBar = 0
			iconObject.Label = ""
			iconObject.Scale = 1
			if tile.current.Drawn then
				iconObject.drawable = drawObjectWithType.Icon(tile.current, iconObject)
			end
			return iconObject
		end,
		setProperty = {
			Opacity = function()
				-- Icons cannot have their opacity altered so do nothing here
			end,
		},
	},
	Line = {
		properties = {
			P1 = "simplePoint", P2 = "simplePoint",
			Color = "colour", Opacity = "percent",
			Width = "positive_number",
		},
		draw = function(tile, lineObject)
			local points = {Points = {lineObject.P1, lineObject.P2}}
			points = calculateProperty.Points(tile, points)
			local opacity = calculateProperty.Opacity(tile, lineObject)
			local width = calculateProperty.Width(tile, lineObject)
			local drawable = lineObject.tile.surfaceHandler.surface.addLine(points[1], points[2], lineObject.Color, opacity)
			drawable.setWidth(width)
			setDrawableProperties(lineObject.tile, lineObject, drawable)
			return drawable
		end,
		new = function(tile, p1, p2, colour, opacity, name)
			if not _checkProperty.simplePoint(p1) then error("check P1") end
			if not _checkProperty.simplePoint(p2) then error("check P2") end
			if colour ~= nil and not _checkProperty.colour(colour) then error("check colour", 2) end
			if opacity ~= nil and not _checkProperty.percent(opacity) then error("check opacity", 2) end
			local lineObject = newObject(tile, "Line", name)
			lineObject.P1 = formatPropertyIn.simplePoint(p1)
			lineObject.P2 = formatPropertyIn.simplePoint(p2)
			lineObject.Color = colour or 0xffffff
			lineObject.Opacity = opacity or 1
			lineObject.Width = 1
			if tile.current.Drawn then
				lineObject.drawable = drawObjectWithType.Line(tile.current, lineObject)
			end
			return lineObject
		end,
		setProperty = {
			P1 = setPoints,
			P2 = setPoints,
			X = setPoints,
			Y = setPoints,
			PosAndScale = function(tile, lineObject)
				setPoints(tile, lineObject)
				lineObject.drawable.setWidth(calculateProperty.Width(tile.current, lineObject))
			end,
			PosAndRotation = function(tile, lineObject)
				setPoints(tile, lineObject)
				lineObject.drawable.setRotation(calculateProperty.Rotation(tile.current, lineObject))
			end,
		},
	},
	LineList = {
		properties = {
			Points = "simplePoints", Width = "positive_number",
			Color = "colour", Opacity = "percent",
		},
		draw = function(tile, lineListObject)
			local points = calculateProperty.Points(tile, lineListObject)
			local opacity = calculateProperty.Opacity(tile, lineListObject)
			local width = calculateProperty.Width(tile, lineListObject)
			local drawable = lineListObject.tile.surfaceHandler.surface.addLineList(lineListObject.Color, opacity, unpack(points))
			drawable.setWidth(width)
			setDrawableProperties(lineListObject.tile, lineListObject, drawable)
			return drawable
		end,
		new = function(tile, colour, opacity, points, name)
			if colour ~= nil and not _checkProperty.colour(colour) then error("check colour", 2) end
			if opacity ~= nil and not _checkProperty.percent(opacity) then error("check opacity", 2) end
			if not _checkProperty.simplePoints(points) then error("check points", 2) end
			local lineListObject = newObject(tile, "LineList", name)
			lineListObject.Points = formatPropertyIn.simplePoints(points)
			lineListObject.Color = colour
			lineListObject.Opacity = opacity
			lineListObject.Width = 1
			if tile.current.Drawn then
				lineListObject.drawable = drawObjectWithType.LineList(tile.current, lineListObject)
			end
			return lineListObject
		end,
		setProperty = {
			X = function(tile, lineListObject)
				lineListObject.drawable.setPoints(calculateProperty.Points(tile.current, lineListObject))
			end,
			Y = function(tile, lineListObject)
				lineListObject.drawable.setPoints(calculateProperty.Points(tile.current, lineListObject))
			end,
			PosAndScale = function(tile, lineListObject)
				lineListObject.drawable.setPoints(calculateProperty.Points(tile.current, lineListObject))
				lineListObject.drawable.setWidth(calculateProperty.Width(tile.current, lineListObject))
			end,
			PosAndRotation = function(tile, lineListObject)
				lineListObject.drawable.setPoints(calculateProperty.Points(tile.current, lineListObject))
				lineListObject.drawable.setRotation(calculateProperty.Rotation(tile.current, lineListObject))
			end,
		},
	},
	Point = {
		properties = {
			Coord = "simplePoint", Size = "positive_number",
			Color = "colour", Opacity = "percent",
		},
		draw = function(tile, pointObject)
			local coord = calculateProperty.Coord(tile, pointObject)
			local opacity = calculateProperty.Opacity(tile, pointObject)
			local size = calculateProperty.Size(tile, pointObject)
			local drawable = pointObject.tile.surfaceHandler.surface.addPoint(coord, pointObject.Color, opacity)
			drawable.setSize(size)
			setDrawableProperties(pointObject.tile, pointObject, drawable)
			return drawable
		end,
		new = function(tile, coord, colour, opacity, name)
			if not _checkProperty.simplePoint(coord) then error("Check coord", 2) end
			if colour ~= nil and not _checkProperty.colour(colour) then error("Check colour", 2) end
			if opacity ~= nil and not _checkProperty.percent(opacity) then error("Check opacity", 2) end
			local pointObject = newObject(tile, "Point", name)
			pointObject.Coord = formatPropertyIn.simplePoint(coord)
			pointObject.Color = colour or 0xffffff
			pointObject.Opacity = opacity or 1
			pointObject.Size = 1
			if tile.current.Drawn then
				pointObject.drawable = drawObjectWithType.Point(tile.current, pointObject)
			end
			return pointObject
		end,
		setProperty = {
			X = function(tile, pointObject)
				pointObject.drawable.setCoord(calculateProperty.Coord(tile.current, pointObject))
			end,
			Y = function(tile, pointObject)
				pointObject.drawable.setCoord(calculateProperty.Coord(tile.current, pointObject))
			end,
			PosAndScale = function(tile, pointObject)
				pointObject.drawable.setCoord(calculateProperty.Coord(tile.current, pointObject))
				pointObject.drawable.setSize(calculateProperty.Size(tile.current, pointObject))
			end,
			PosAndRotation = function(tile, pointObject)
				pointObject.drawable.setCoord(calculateProperty.Coord(tile.current, pointObject))
				pointObject.drawable.setRotation(calculateProperty.Rotation(tile.current, pointObject))
			end,
		},
	},
	Polygon = {
		properties = {
			Points = "simplePoints", Color = "colour", Opacity = "percent",
		},
		draw = function(tile, polygonObject)
			local points = calculateProperty.Points(tile, polygonObject)
			local opacity = calculateProperty.Opacity(tile, polygonObject)
			local drawable = polygonObject.tile.surfaceHandler.surface.addPolygon(polygonObject.Color, opacity, unpack(points))
			setDrawableProperties(polygonObject.tile, polygonObject, drawable)
			return drawable
		end,
		new = function(tile, colour, opacity, points, name)
			if colour ~= nil and not _checkProperty.colour(colour) then error("check colour", 2) end
			if opacity ~= nil and not _checkProperty.percent(opacity) then error("check opacity", 2) end
			if not _checkProperty.simplePoints(points) then error("check points", 2) end
			local polygonObject = newObject(tile, "Polygon", name)
			polygonObject.Points = formatPropertyIn.simplePoints(points)
			polygonObject.Color = colour
			polygonObject.Opacity = opacity
			if tile.current.Drawn then
				polygonObject.drawable = drawObjectWithType.Polygon(tile.current, polygonObject)
			end
			return polygonObject
		end,
		setProperty = {
			X = function(tile, polygonObject)
				polygonObject.drawable.setPoints(calculateProperty.Points(tile.current, polygonObject))
			end,
			Y = function(tile, polygonObject)
				polygonObject.drawable.setPoints(calculateProperty.Points(tile.current, polygonObject))
			end,
			PosAndScale = function(tile, polygonObject)
				polygonObject.drawable.setPoints(calculateProperty.Points(tile.current, polygonObject))
			end,
			PosAndRotation = function(tile, polygonObject)
				polygonObject.drawable.setPoints(calculateProperty.Points(tile.current, polygonObject))
				polygonObject.drawable.setRotation(calculateProperty.Rotation(tile.current, polygonObject))
			end,
		},
	},
	Quad = {
		properties = {
			P1 = "simplePoint", P2 = "simplePoint",
			P3 = "simplePoint", P4 = "simplePoint",
			Color = "colour", Opacity = "percent",
		},
		draw = function(tile, quadObject)
			local points = {Points = {quadObject.P1, quadObject.P2, quadObject.P3, quadObject.P4}}
			points = calculateProperty.Points(tile, points)
			local opacity = calculateProperty.Opacity(tile, quadObject)
			local drawable = quadObject.tile.surfaceHandler.surface.addQuad(points[1], points[2], points[3], points[4], quadObject.Color, opacity)
			setDrawableProperties(quadObject.tile, quadObject, drawable)
			return drawable
		end,
		new = function(tile, p1, p2, p3, p4, colour, opacity, name)
			if not _checkProperty.simplePoint(p1) then error("check P1") end
			if not _checkProperty.simplePoint(p2) then error("check P2") end
			if not _checkProperty.simplePoint(p3) then error("check P3") end
			if not _checkProperty.simplePoint(p4) then error("check P4") end
			if colour ~= nil and not _checkProperty.colour(colour) then error("check colour", 2) end
			if opacity ~= nil and not _checkProperty.percent(opacity) then error("check opacity", 2) end
			local quadObject = newObject(tile, "Quad", name)
			quadObject.P1 = formatPropertyIn.simplePoint(p1)
			quadObject.P2 = formatPropertyIn.simplePoint(p2)
			quadObject.P3 = formatPropertyIn.simplePoint(p3)
			quadObject.P4 = formatPropertyIn.simplePoint(p4)
			quadObject.Color = colour or 0xffffff
			quadObject.Opacity = opacity or 1
			if tile.current.Drawn then
				quadObject.drawable = drawObjectWithType.Quad(tile.current, quadObject)
			end
			return quadObject
		end,
		setProperty = {
			P1 = setPoints,
			P2 = setPoints,
			P3 = setPoints,
			P4 = setPoints,
			X = setPoints,
			Y = setPoints,
			PosAndScale = setPoints,
			PosAndRotation = function(tile, quadObject)
				setPoints(tile, quadObject)
				quadObject.drawable.setRotation(calculateProperty.Rotation(tile.current, quadObject))
			end,
		},
	},
	Text = {
		properties = {
			X = "number", Y = "number",
			Text = "string", Color = "colour",
			Alpha = "percent", Scale = "positive_number",
		},
		draw = function(tile, textObject)
			local xPos = calculateProperty.X(tile, textObject)
			local yPos = calculateProperty.Y(tile, textObject)
			local alpha = calculateProperty.Alpha(tile, textObject)
			local scale = calculateProperty.Scale(tile, textObject)
			local drawable = textObject.tile.surfaceHandler.surface.addText(xPos, yPos, textObject.Text, textObject.Color)
			drawable.setAlpha(alpha)
			drawable.setScale(scale)
			setDrawableProperties(textObject.tile, textObject, drawable)
			return drawable
		end,
		new = function(tile, xPos, yPos, text, colour, name)
			if not _checkProperty.number(xPos) then error("Check xPos", 2) end
			if not _checkProperty.number(yPos) then error("Check yPos", 2) end
			if not _checkProperty.string(text) then error("Check text", 2) end
			if colour ~= nil and not _checkProperty.colour(colour) then error("Check colour", 2) end
			local textObject = newObject(tile, "Text", name)
			textObject.X = xPos
			textObject.Y = yPos
			textObject.Text = text
			textObject.Color = colour or 0xffffff
			textObject.Alpha = 1
			textObject.Scale = 1
			if tile.current.Drawn then
				textObject.drawable = drawObjectWithType.Text(tile.current, textObject)
			end
			return textObject
		end,
		setProperty = {
			Opacity = function(tile, textObject)
				textObject.drawable.setAlpha(calculateProperty.Alpha(tile.current, textObject))
			end,
		},
	},
	Triangle = {
		properties = {
			P1 = "simplePoint", P2 = "simplePoint", P3 = "simplePoint",
			Color = "colour", Opacity = "percent",
		},
		draw = function(tile, triangleObject)
			local points = {Points = {triangleObject.P1, triangleObject.P2, triangleObject.P3}}
			points = calculateProperty.Points(tile, points)
			local opacity = calculateProperty.Opacity(tile, triangleObject)
			local drawable = triangleObject.tile.surfaceHandler.surface.addTriangle(points[1], points[2], points[3], triangleObject.Color, opacity)
			setDrawableProperties(triangleObject.tile, triangleObject, drawable)
			return drawable
		end,
		new = function(tile, p1, p2, p3, colour, opacity, name)
			if not _checkProperty.simplePoint(p1) then error("check P1") end
			if not _checkProperty.simplePoint(p2) then error("check P2") end
			if not _checkProperty.simplePoint(p3) then error("check P3") end
			if colour ~= nil and not _checkProperty.colour(colour) then error("check colour", 2) end
			if opacity ~= nil and not _checkProperty.percent(opacity) then error("check opacity", 2) end
			local triangleObject = newObject(tile, "Triangle", name)
			triangleObject.P1 = formatPropertyIn.simplePoint(p1)
			triangleObject.P2 = formatPropertyIn.simplePoint(p2)
			triangleObject.P3 = formatPropertyIn.simplePoint(p3)
			triangleObject.Color = colour or 0xffffff
			triangleObject.Opacity = opacity or 1
			if tile.current.Drawn then
				triangleObject.drawable = drawObjectWithType.Triangle(tile.current, triangleObject)
			end
			return triangleObject
		end,
		setProperty = {
			P1 = setPoints,
			P2 = setPoints,
			P3 = setPoints,
			X = setPoints,
			Y = setPoints,
			PosAndScale = setPoints,
			PosAndRotation = function(tile, triangleObject)
				setPoints(tile, triangleObject)
				triangleObject.drawable.setRotation(calculateProperty.Rotation(tile.current, triangleObject))
			end,
		},
	},
}

local function makeObjectGetter(propertyName, propertyType)
	return function(self)
		if formatPropertyOut[propertyType] then
			return formatPropertyOut[propertyType](self[propertyName])
		else
			return self[propertyName]
		end
	end
end

local function makeObjectSetter(objectType, propertyName, propertyType)
	return function(self, ...)
		if _checkProperty[propertyType](...) then
			self[propertyName] = formatPropertyIn[propertyType] and formatPropertyIn[propertyType](...) or ...
			if setObjectProperty[propertyName] and self.drawable then
				if setObjectProperty[propertyName][objectType] then
					setObjectProperty[propertyName][objectType](self.tile, self)
				else
					setObjectProperty[propertyName].default(self.tile, self)
				end
				self.tile.surfaceHandler.changed = true
			end
			return true
		end
		return false
	end
end

local function makeObjectActualGetter(propertyName, propertyType)
	return function(self)
		return calculateProperty[propertyName](self.tile.current, self)
	end
end

do -- initialise objects from templates

	-- fill out baseObjectMethods with global properties
	for propertyName, propertyType in pairs(baseObjectProperties) do
		baseObjectMethods["Get"..propertyName] = makeObjectGetter(propertyName, propertyType)
		baseObjectMethods["Set"..propertyName] = makeObjectSetter(objectType, propertyName, propertyType)
		if calculateProperty[propertyName] then
			baseObjectMethods["GetActual"..propertyName] = makeObjectActualGetter(propertyName, propertyType)
		end
	end
	
	-- process object templates for each objectType
	for objectType, objectData in pairs(objects) do
	
		-- create object metatable for this objectType
		local objectMetatable = {}
		
		-- copy in baseObjectMethods
		for key, func in pairs(baseObjectMethods) do
			objectMetatable[key] = func
		end
		
		-- create getters and setters for custom properties
		for propertyName, propertyType in pairs(objectData.properties) do
			objectMetatable["Get"..propertyName] = makeObjectGetter(propertyName, propertyType)
			objectMetatable["Set"..propertyName] = makeObjectSetter(objectType, propertyName, propertyType)
			if calculateProperty[propertyName] then
				objectMetatable["GetActual"..propertyName] = makeObjectActualGetter(propertyName, propertyType)
			end
		end
		
		-- add metatable to list
		objectMetatable.__index = objectMetatable
		objectMetatables[objectType] = objectMetatable
		
		-- add drawable creation function to list
		drawObjectWithType[objectType] = objectData.draw
		
		-- fill in custom object setProperty methods
		for propertyName, propertyFunc in pairs(objectData.setProperty) do
			setObjectProperty[propertyName][objectType] = propertyFunc
		end
		
	end
end

--===== TILES =====--

local setTileProperty

local function newTilePropertySetter(property)
	return function(parent, tile)
		tile.current[property] = calculateProperty[property](parent, tile.relative)
		if tile.current.Drawn then
			local setObjectPropertyProp = setObjectProperty[property]
			for _, object in pairs(tile.objects.list) do
				local setter = setObjectPropertyProp[object.Type] or setObjectPropertyProp.default
				setter(tile, object)
			end
		end
		for _, subTile in pairs(tile.subTiles.list) do
			setTileProperty[property](tile.current, subTile)
		end
	end
end

setTileProperty = {
	X = function(parent, tile)
		tile.current.X = calculateProperty.X(parent, tile.relative)
		tile.current.Y = calculateProperty.Y(parent, tile.relative)
		if tile.current.Drawn then
			local setObjectPropertyX = setObjectProperty.X
			for _, object in pairs(tile.objects.list) do
				local setter = setObjectPropertyX[object.Type] or setObjectPropertyX.default
				setter(tile, object)
			end
		end
		for _, subTile in pairs(tile.subTiles.list) do
			setTileProperty.X(tile.current, subTile)
		end
	end,
	Y = function(parent, tile)
		tile.current.X = calculateProperty.X(parent, tile.relative)
		tile.current.Y = calculateProperty.Y(parent, tile.relative)
		if tile.current.Drawn then
			local setObjectPropertyY = setObjectProperty.Y
			for _, object in pairs(tile.objects.list) do
				local setter = setObjectPropertyY[object.Type] or setObjectPropertyY.default
				setter(tile, object)
			end
		end
		for _, subTile in pairs(tile.subTiles.list) do
			setTileProperty.Y(tile.current, subTile)
		end
	end,
	
	Z = newTilePropertySetter("Z"),
	Opacity = newTilePropertySetter("Opacity"),
	Visible = newTilePropertySetter("Visible"),
	Clickable = newTilePropertySetter("Clickable"),

	Scale = function(parent, tile)
		tile.current.Scale = calculateProperty.Scale(parent, tile.relative)
		if tile.current.Drawn then
			local setObjectPropertyPosAndScale = setObjectProperty.PosAndScale
			for _, object in pairs(tile.objects.list) do
				local setter = setObjectPropertyPosAndScale[object.Type] or setObjectPropertyPosAndScale.default
				setter(tile, object)
			end
		end
		for _, subTile in pairs(tile.subTiles.list) do
			setTileProperty.PosAndScale(tile.current, subTile)
		end
	end,
	PosAndScale = function(parent, tile)
		tile.current.X = calculateProperty.X(parent, tile.relative)
		tile.current.Y = calculateProperty.Y(parent, tile.relative)
		tile.current.Scale = calculateProperty.Scale(parent, tile.relative)
		if tile.current.Drawn then
			local setObjectPropertyPosAndScale = setObjectProperty.PosAndScale
			for _, object in pairs(tile.objects.list) do
				local setter = setObjectPropertyPosAndScale[object.Type] or setObjectPropertyPosAndScale.default
				setter(tile, object)
			end
		end
		for _, subTile in pairs(tile.subTiles.list) do
			setTileProperty.PosAndScale(tile.current, subTile)
		end
	end,

	Rotation = function(parent, tile)
		tile.current.Rotation = calculateProperty.Rotation(parent, tile.relative)
		if tile.current.Drawn then
			local setObjectPropertyPosAndRotation = setObjectProperty.PosAndRotation
			for _, object in pairs(tile.objects.list) do
				local setter = setObjectPropertyPosAndRotation[object.Type] or setObjectPropertyPosAndRotation.default
				setter(tile, object)
			end
		end
		for _, subTile in pairs(tile.subTiles.list) do
			setTileProperty.PosAndRotation(tile.current, subTile)
		end
	end,
	PosAndRotation = function(parent, tile)
		tile.current.X = calculateProperty.X(parent, tile.relative)
		tile.current.Y = calculateProperty.Y(parent, tile.relative)
		tile.current.Rotation = calculateProperty.Rotation(parent, tile.relative)
		if tile.current.Drawn then
			local setObjectPropertyPosAndRotation = setObjectProperty.PosAndRotation
			for _, object in pairs(tile.objects.list) do
				local setter = setObjectPropertyPosAndRotation[object.Type] or setObjectPropertyPosAndRotation.default
				setter(tile, object)
			end
		end
		for _, subTile in pairs(tile.subTiles.list) do
			setTileProperty.PosAndRotation(tile.current, subTile)
		end
	end,

	Drawn = function(parent, tile)
		local newDrawn = calculateProperty.Drawn(parent, tile.relative)
		if newDrawn ~= tile.current.Drawn then
			tile.current.Drawn = newDrawn
			if tile.current.Drawn then -- draw objects
				for _, object in pairs(tile.objects.list) do
					if not object.drawable then
						object.drawable = drawObjectWithType[object.Type](tile.current, object)
					end
				end
			else -- erase objects
				for _, object in pairs(tile.objects.list) do
					if object.drawable then
						object.drawable.delete()
						object.drawable = false
					end
				end
			end
			for _, subTile in pairs(tile.subTiles.list) do
				setTileProperty.Drawn(tile.current, subTile)
			end
		end
	end,
	ScreenAnchor = function(parent, tile)
		tile.current.ScreenAnchor = parent.ScreenAnchor
		if tile.current.Drawn then
			for _, object in pairs(tile.objects.list) do
				if object.drawable then
					object.drawable.setScreenAnchor(unpack(tile.current.ScreenAnchor))
				end
			end
		end
		for _, subTile in pairs(tile.subTiles.list) do
			setTileProperty.ScreenAnchor(tile.current, subTile)
		end
	end,
}

local function clearTile(tile)
	local isDrawn = tile.current.Drawn
	for _, object in pairs(tile.objects.list) do
		object.drawable = (isDrawn and drawObjectWithType[object.Type](tile.current, object)) or false
	end
	for _, subTile in pairs(tile.subTiles.list) do
		clearTile(subTile)
	end
end

local function newTile(parentTile, ID, xPos, yPos, zPos, name)
	local tile = {
		ID = ID,
		name = name,
		
		parent = parentTile,
		surfaceHandler = parentTile.surfaceHandler,
		
		relative = {
			X = xPos, Y = yPos, Z = zPos,
			Scale = 1, Rotation = 0, Opacity = 1,
			Visible = true, Clickable = true,
			Drawn = true,
		},
		current = {
			X = 0, Y = 0, Z = 0,
			Scale = 1, Rotation = 0, Opacity = 1,
			Visible = true, Clickable = true,
			ScreenAnchor = parentTile.current.ScreenAnchor,
			Drawn = false,
		},
		
		objects = {
			list = {},
			nameToID = {},
		},
		subTiles = {
			list = {},
			nameToID = {},
		},
	}
	tile.current.X = calculateProperty.X(parentTile.current, tile.relative)
	tile.current.Y = calculateProperty.Y(parentTile.current, tile.relative)
	tile.current.Z = calculateProperty.Z(parentTile.current, tile.relative)
	tile.current.Scale = calculateProperty.Scale(parentTile.current, tile.relative)
	tile.current.Rotation = calculateProperty.Rotation(parentTile.current, tile.relative)
	tile.current.Opacity = calculateProperty.Opacity(parentTile.current, tile.relative)
	tile.current.Visible = calculateProperty.Visible(parentTile.current, tile.relative)
	tile.current.Clickable = calculateProperty.Clickable(parentTile.current, tile.relative)
	tile.current.Drawn = calculateProperty.Drawn(parentTile.current, tile.relative)
	return tile
end

local tileMethods = {
	GetID = function(self)
		return self.ID
	end,
	IsMasterTile = function(self)
		return (self.isMasterTile and true) or false
	end,
	GetParent = function(self)
		return (self:IsMasterTile() and self) or self.parent
	end,
	
	GetName = function(self)
		return self.Name
	end,
	SetName = function(self, name)
		if _checkProperty.name(name) then
			if name == nil and self.Name ~= nil then
				self.surfaceHandler.tiles.nameToID[self.Name] = nil
				if not self.isMasterTile then
					self.parent.subTiles.nameToID[self.Name] = nil
				end
				self.Name = nil
				return true
			elseif name ~= nil and not self.surfaceHandler.tiles.nameToID[self.Name] then
				self.surfaceHandler.tiles.nameToID[name] = self.ID
				if not self.isMasterTile then
					self.parent.subTiles.nameToID[name] = self.ID
				end
				self.Name = name
				return true
			end
		end
		return false
	end,
	
	GetSubTile = function(self, tileID)
		return self.subTiles.list[tileID] or false
	end,
	GetSubTileByName = function(self, tileName)
		if tileName then
			local tileID = self.subTiles.nameToID[tileName]
			if tileID then
				return self:GetSubTile(tileID)
			end
		end
		return false
	end,
	GetAllSubTiles = function(self)
		local subTiles = {}
		for tileID, subTile in pairs(self.subTiles.list) do
			subTiles[tileID] = subTile
		end
		return subTiles
	end,
	GetAllSubTilesByName = function(self)
		local subTiles = {}
		for tileName, tileID in pairs(self.subTiles.nameToID) do
			subTiles[tileName] = self.subTiles.list[tileID]
		end
		return subTiles
	end,
	DeleteSubTile = function(self, tileID)
		local subTile = self:GetSubTile(tileID)
		if subTile then
			return subTile:Delete()
		end
		return false
	end,
	DeleteSubTileByName = function(self, tileName)
		local subTile = self:GetSubTileByName(tileName)
		if subTile then
			return subTile:Delete()
		end
		return false
	end,
	DeleteAllSubTiles = function(self)
		local subTiles = self:GetAllSubTiles()
		for _, subTile in pairs(subTiles) do
			subTile:Delete()
		end
		return true
	end,
	
	GetObject = function(self, objectID)
		return self.objects.list[objectID] or false
	end,
	GetObjectByName = function(self, objectName)
		if objectName then
			local objectID = self.objects.nameToID[objectName]
			if objectID then
				return self:GetObject(objectID)
			end
		end
		return false
	end,
	GetAllObjects = function(self)
		local objects = {}
		for objectID, object in pairs(self.objects.list) do
			objects[objectID] = object
		end
		return objects
	end,
	GetAllObjectsByName = function(self)
		local objects = {}
		for objectName, objectID in pairs(self.objects.nameToID) do
			objects[objectName] = self.objects.list[objectID]
		end
		return objects
	end,
	DeleteObject = function(self, objectID)
		local object = self:GetObject(objectID)
		if object then
			return object:Delete()
		end
		return false
	end,
	DeleteObjectByName = function(self, objectName)
		local object = self:GetObjectByName(objectName)
		if object then
			return object:Delete()
		end
		return false
	end,
	DeleteAllObjects = function(self)
		local objects = self:GetAllObjects()
		for _, object in pairs(objects) do
			object:Delete()
		end
		return true
	end,
	
	Delete = function(self)
	
		self:DeleteAllSubTiles()
		self:DeleteAllObjects()
		
		self.surfaceHandler.tiles.list[self.ID] = nil
		if not self.isMasterTile then
			self.parent.subTiles.list[self.ID] = nil
		end
		
		if self.Name then
			self.surfaceHandler.tiles.nameToID[self.Name] = nil
			if not self.isMasterTile then
				self.parent.subTiles.nameToID[self.Name] = nil
			end
		end
		
		self.surfaceHandler.changed = true
		
		setmetatable(self, nil)
		
		local index = next(self)
		while index do
			self[index] = nil
			index = next(self)
		end
		
		return true
	end,
}
local tileMetatable = {__index = tileMethods}

tileMethods.AddSubTile = function(self, xPos, yPos, zPos, name)
	local name = (not _checkProperty.name(name) and error("name: expected string, got "..type(name))) or name
	if name and self.surfaceHandler.tiles.nameToID[name] then
		error("name already in use: "..name)
	end
	if not _checkProperty.number(xPos) then error("xPos: number expected") end
	if not _checkProperty.number(yPos) then error("yPos: number expected") end
	if zPos ~= nil and not _checkProperty.number(zPos) then error("zPos: number expected") end
	
	local tileID = self.surfaceHandler.tiles.nextID
	self.surfaceHandler.tiles.nextID = tileID + 1
	
	local tile = newTile(self, tileID, xPos, yPos, zPos or 0, name)
	setmetatable(tile, tileMetatable)
	
	self.subTiles.list[tileID] = tile
	self.surfaceHandler.tiles.list[tileID] = tile
	
	if name then
		self.subTiles.nameToID[name] = tileID
		self.surfaceHandler.tiles.nameToID[name] = tileID
	end
	
	return tile	
end

do --add tile getters and setters to tileMethods
	local function makeTileGetter(propertyName, propertyType)
		return function(self)
			if formatPropertyOut[propertyType] then
				return formatPropertyOut[propertyType](self.relative[propertyName])
			else
				return self.relative[propertyName]
			end
		end
	end

	local function makeTileSetter(propertyName, propertyType)
		return function(self, value)
			if _checkProperty[propertyType](value) then
				self.relative[propertyName] = formatPropertyIn[propertyType] and formatPropertyIn[propertyType](value) or value
				if setTileProperty[propertyName] then
					setTileProperty[propertyName](self.parent.current, self)
					self.surfaceHandler.changed = true
				end
				return true
			end
			return false
		end
	end
	
	local function makeTileActualGetter(propertyName, propertyType)
		return function(self)
			if formatPropertyOut[propertyType] then
				return formatPropertyOut[propertyType](self.current[propertyName])
			else
				return self.current[propertyName]
			end
		end
	end

	local tileProperties = {
		X = "number", Y = "number", Z = "number",
		Scale = "positive_number", Rotation = "number", Opacity = "percent",
		Visible = "boolean", Clickable = "boolean",
		Drawn = "boolean",
		OnKeyDown = "functionOrNil", OnKeyUp = "functionOrNil",
		OnSelect = "functionOrNil", OnDeselect = "functionOrNil",
		Userdata = "userdata",
	}

	for propertyName, propertyType in pairs(tileProperties) do
		tileMethods["Get"..propertyName] = makeTileGetter(propertyName, propertyType)
		tileMethods["Set"..propertyName] = makeTileSetter(propertyName, propertyType)
		if calculateProperty[propertyName] then
			tileMethods["GetActual"..propertyName] = makeTileActualGetter(propertyName, propertyType)
		end
	end
end

-- add in object creation functions to tileMethods
for objectType, objectData in pairs(objects) do
	tileMethods["Add"..objectType] = objectData.new
end

local masterTileMethods = {	
	GetScreenAnchor = function(self)
		return unpack(self.parent.current.ScreenAnchor)
	end,
	SetScreenAnchor = function(self, horizontal, vertical)
		if _checkProperty.alignment(horizontal, vertical) then
			self.parent.current.ScreenAnchor = {string.upper(tostring(horizontal)), string.upper(tostring(vertical))}
			setTileProperty.ScreenAnchor(self.parent.current, self)
			self.surfaceHandler.changed = true
			return true
		end
		return false
	end,
}
setmetatable(masterTileMethods, tileMetatable)
local masterTileMetatable = {__index = masterTileMethods}

local function newMasterTile(surfaceHandler, xPos, yPos, zPos, name)
	local name = (not _checkProperty.name(name) and error("name: expected string, got "..type(name))) or name
	if name and surfaceHandler.tiles.nameToID[name] then
		error("name already in use: "..name)
	end
	if not _checkProperty.number(xPos) then error("xPos: number expected") end
	if not _checkProperty.number(yPos) then error("yPos: number expected") end
	if zPos ~= nil and not _checkProperty.positive_number(zPos) then error("zPos: number expected") end
	
	local tileID = surfaceHandler.tiles.nextID
	surfaceHandler.tiles.nextID = tileID + 1
	
	local masterTileProxy = {
		current = {
			X = 0, Y = 0, Z = 0,
			Scale = 1, Rotation = 0, Opacity = 1,
			Visible = true, Clickable = true,
			ScreenAnchor = {"LEFT", "TOP"},
			Drawn = true,
		},
	}
	local masterTile = newTile(masterTileProxy, tileID, xPos, yPos, zPos or 1, name)
	masterTile.relative.Drawn = false
	masterTile.current.Drawn = false
	masterTile.surfaceHandler = surfaceHandler
	masterTile.isMasterTile = true
	setmetatable(masterTile, masterTileMetatable)
	
	surfaceHandler.tiles.list[tileID] = masterTile
	if name then
		surfaceHandler.tiles.nameToID[name] = tileID
	end
	
	return masterTile	
end

--===== SURFACE HANDLER =====--
local surfaceHandlerMethods = {
	GetChanged = function(self)
		return self.changed
	end,
	ResetChanged = function(self)
		local hasChanged = self.changed
		self.changed = false
		return hasChanged
	end,

	GetCapture = function(self)
		return self.capture
	end,
	SetCapture = function(self, capture)
		if _checkProperty.capture(capture) then
			self.capture = capture
			return true
		end
		return false
	end,
	GetSurface = function(self)
		return self.surface
	end,
	SetSurface = function(self, surface, capture)
		if _checkProperty.surface(surface) and _checkProperty.capture(capture) then
			self.surface.clear()
			self.surface = surface
			self.capture = capture
			local tiles = self:GetAllMasterTiles()
			for _, tile in pairs(tiles) do
				clearTile(tile)
			end
			self.changed = true
			return true
		end
		return false
	end,
	
	AddTile = newMasterTile,
	GetTile = function(self, tileID)
		return self.tiles.list[tileID] or false
	end,
	GetTileByName = function(self, tileName)
		if tileName then
			local tileID = self.tiles.nameToID[tileName]
			if tileID then
				return self:GetTile(tileID)
			end
		end
		return false
	end,
	GetAllTiles = function(self)
		local tiles = {}
		for tileID, tile in pairs(self.tiles.list) do
			tiles[tileID] = tile
		end
		return tiles
	end,
	GetAllTilesByName = function(self)
		local tiles = {}
		for tileName, tileID in pairs(self.tiles.nameToID) do
			tiles[tileName] = self.tiles.list[tileID]
		end
		return tiles
	end,
	GetAllMasterTiles = function(self)
		local tiles = {}
		for tileID, tile in pairs(self.tiles.list) do
			if tile.isMasterTile then
				tiles[tileID] = tile
			end
		end
		return tiles
	end,
	GetAllMasterTilesByName = function(self)
		local tiles = {}
		for tileName, tileID in pairs(self.tiles.nameToID) do
			local tile = self.tiles.list[tileID]
			if tile and tile.isMasterTile then
				tiles[tileName] = tile
			end
		end
		return tiles
	end,
	DeleteTile = function(self, tileID)
		local tile = self:GetTile(tileID)
		if tile then
			return tile:Delete()
		end
		return false
	end,
	DeleteTileByName = function(self, tileName)
		local tile = self:GetTileByName(tileName)
		if tile then
			return tile:Delete()
		end
		return false
	end,
	DeleteAllTiles = function(self)
		local tiles = self:GetAllMasterTiles()
		for _, tile in pairs(tiles) do
			if tile.Delete then
				tile:Delete()
			end
		end
		return true
	end,
	
	GetObject = function(self, objectID)
		return self.objects.list[objectID] or false
	end,
	GetObjectByName = function(self, objectName)
		if objectName then
			local objectID = self.objects.nameToID[objectName]
			if objectID then
				return self:GetObject(objectID)
			end
		end
		return false
	end,
	GetAllObjects = function(self)
		local objects = {}
		for objectID, object in pairs(self.objects.list) do
			objects[objectID] = object
		end
		return objects
	end,
	GetAllObjectsByName = function(self)
		local objects = {}
		for objectName, objectID in pairs(self.objects.nameToID) do
			objects[objectName] = self.objects.list[objectID]
		end
		return objects
	end,
	DeleteObject = function(self, objectID)
		local object = self:GetObject(objectID)
		if object then
			return object:Delete()
		end
		return false
	end,
	DeleteObjectByName = function(self, objectName)
		local object = self:GetObjectByName(objectName)
		if object then
			return object:Delete()
		end
		return false
	end,
	DeleteAllObjects = function(self)
		local objects = self:GetAllObjects()
		for _, object in pairs(objects) do
			object:Delete()
		end
		return true
	end,
}
local surfaceHandlerMetatable = {__index = surfaceHandlerMethods}

function newSurfaceHandler(surface, capture)
	if not _checkProperty.surface(surface) then
		error("new: expected surface, got "..type(surface))
	end
	if not _checkProperty.capture(capture) then
		error("new: expected capture, got "..type(capture))
	end
	surface.clear()
	local surfaceHandler = {
		surface = surface,
		
		capture = capture,
		
		tiles = {
			list = {},
			nameToID = {},
			nextID = 1,
		},
		objects = {
			list = {},
			nameToID = {},
			nextID = 1,
		},
		changed = true,
	}
	setmetatable(surfaceHandler, surfaceHandlerMetatable)
	return surfaceHandler
end

--===== MULTI SURFACE HANDLER =====--
local mainTerminalEvents = {
	char = true,
	key = true,
	key_up = true,
	mouse_click = true,
	mouse_drag = true,
	mouse_scroll = true,
	mouse_up = true,
	paste = true,
	term_resize = true,
	terminate = true,
}
local glassesEvents = {
	glasses_attach = true,
	glasses_detach = true,
	glasses_capture = true,
	glasses_release = true,
	glasses_chat_command = true,
	glasses_chat_message = true,
	glasses_key_down = true,
	glasses_key_up = true,
	glasses_mouse_scroll = true,
	glasses_mouse_down = true,
	glasses_mouse_up = true,
	glasses_mouse_drag = true,
	glasses_component_mouse_wheel = true,
	glasses_component_mouse_down = true,
	glasses_component_mouse_up = true,

	glasses_custom_event = true,
}

local function setupPlayer(multiSurfaceHandler, playerUUID)
	local playerSurface = multiSurfaceHandler.bridge.getSurfaceByUUID(playerUUID)
	playerSurface.clear()
	
	local playerCapture = multiSurfaceHandler.bridge.getCaptureControl(playerUUID)
	playerCapture.stopCapturing()
	
	local surfaceHandler = newSurfaceHandler(playerSurface, playerCapture)
	
	local thread = coroutine.create(multiSurfaceHandler.newPlayerHandler(playerUUID, surfaceHandler))
	
	local ok, passback = coroutine.resume(thread)
	if not ok then
		printError(passback)
	else
		return {
			surfaceHandler = surfaceHandler,
			thread = thread,
		}
	end
end

local multiSurfaceHandlerMethods = {
	GetConnectedPlayers = function(self)
	end,
	Run = function(self)
		local function main()
			local event, eventType
			local playerUUID, player
			local exit = false
			
			while not exit do
				event = {coroutine.yield()}
				eventType = event[1]
				if glassesEvents[eventType] then
					playerUUID = event[4]
					player = self.players[playerUUID]
					if not player then
						self.players[playerUUID] = setupPlayer(self, playerUUID)
					else
						if eventType == "glasses_attach" then
							local playerSurface = self.bridge.getSurfaceByUUID(playerUUID)
							local playerCapture = self.bridge.getCaptureControl(playerUUID)
							player.surfaceHandler:SetSurface(playerSurface, playerCapture)
						elseif eventType == "glasses_detach" then
							player.surfaceHandler:SetCapture(nil)
						end
						if coroutine.status(player.thread) ~= "dead" then
							local ok, passback = coroutine.resume(player.thread, unpack(event))
							if not ok then
								printError(passback)
							end
						end
					end
				elseif not mainTerminalEvents[eventType] then
					for _, player in pairs(self.players) do
						if coroutine.status(player.thread) ~= "dead" then
							local ok, passback = coroutine.resume(player.thread, unpack(event))
							if not ok then
								printError(passback)
							end
						end
					end
				elseif eventType == "key" then
					if event[2] == keys.backspace then
						exit = true
					end
				elseif eventType == "terminate" then
					exit = true
				end			
			end
		end

		local function renderLoopManager()

			local coroutine_resume = coroutine.resume
			local coroutine_create = coroutine.create
			local bridge_sync = self.bridge.sync
			local os_clock = os.clock
			local coroutine_yield = coroutine.yield

			local shouldSync = false
			local syncStartTime = false
			local function mainRenderLoop()
				while true do
					while true do
						for _, player in pairs(self.players) do
							shouldSync = player.surfaceHandler:ResetChanged() or shouldSync
						end
						if shouldSync then
							shouldSync = false
							syncStartTime = os_clock()
							bridge_sync()
							syncStartTime = false
						else
							break
						end
					end
					coroutine_yield()
				end
			end

			local MAX_RENDER_INTERVAL = 0.5
			local currentRenderThread = coroutine_create(mainRenderLoop)

			local ok, filter
			while true do
				ok, filter = coroutine_resume(currentRenderThread, coroutine_yield(filter))
				if not ok or (syncStartTime and os_clock() - syncStartTime > MAX_RENDER_INTERVAL) then
					syncStartTime = false
					currentRenderThread = coroutine_create(mainRenderLoop)
					ok, filter = coroutine_resume(currentRenderThread)
				end
			end
		end

		for _, playerData in ipairs(self.bridge.getUsers()) do
			self.players[playerData.uuid] = setupPlayer(self, playerData.uuid)
		end

		parallel.waitForAny(main, renderLoopManager)

		--clean up
		for _, playerData in ipairs(self.bridge.getUsers()) do
			local player = self.players[playerData.uuid]
			if player then
				local capture = player.surfaceHandler:GetCapture()
				if capture then
					capture.stopCapturing()
				end
				local playerSurface = self.bridge.getSurfaceByUUID(playerData.uuid)
				playerSurface.clear()
			end
		end
		self.bridge.sync()
	end,
}
local multiSurfaceHandlerMetatable = {__index = multiSurfaceHandlerMethods}

function newMultiSurfaceHandler(bridge, newPlayerHandler)
	if not _checkProperty.bridge(bridge) then
		error("newMultiSurfaceHandler: expected bridge, got "..type(bridge))
	end
	if not _checkProperty["function"](newPlayerHandler) then
		error("newMultiSurfaceHandler: expected function, got "..type(newPlayerHandler))
	end
	local multiSurfaceHandler = {
		bridge = bridge,
		newPlayerHandler = newPlayerHandler,
		players = {},
	}
	setmetatable(multiSurfaceHandler, multiSurfaceHandlerMetatable)
	return multiSurfaceHandler
end
