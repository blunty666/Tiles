local updateOnly = (...) == "--update"

local noOverwrite = (...) == "true"

local rootURL = "https://raw.githubusercontent.com"
local githubUsername = "blunty666"

local mainURL = table.concat({rootURL, githubUsername}, "/")

local saveDir = "baseMonitor"
if fs.exists(saveDir) and not fs.isDir(saveDir) then
	printError("Invalid saveDir: ", saveDir)
	return
end

local fileList

if not updateOnly then
	fileList = {
		["baseMonitor"] = {"Tiles", "programs/baseMonitor/baseMonitor.lua"},

		["apis/tiles"] = {"Tiles", "tiles.lua"},
		["apis/guiTiles"] = {"Tiles", "apis/guiTiles.lua"},
		["apis/advancedTiles"] = {"Tiles", "apis/advancedTiles.lua"},
		["apis/remotePeripheralClient"] = {"CC-Programs-and-APIs", "remotePeripheral/remotePeripheralClient"},
	}
else
	fileList = {}
end

local function get(url)
	local response = http.get(url)			
	if response then
		local fileData = response.readAll()
		response.close()
		return fileData
	end
	return false
end

local function getDirectoryContents(author, repository, branch, directory, filesOnly)
	local fType, fPath, fName = {}, {}, {}
	local response = get("https://api.github.com/repos/"..author.."/"..repository.."/contents/"..directory.."?ref="..branch)
	if response then
		if response ~= nil then
			for str in response:gmatch('"type":%s*"(%w+)",') do table.insert(fType, str) end
			for str in response:gmatch('"path":%s*"([^\"]+)",') do table.insert(fPath, str) end
			for str in response:gmatch('"name":%s*"([^\"]+)",') do table.insert(fName, str) end
		end
	else
		printError("Can't fetch repository information")
		return nil
	end
	local directoryContents = {}
	for i=1, #fType do
		if filesOnly ~= true or fType[i] ~= "dir" then
			directoryContents[i] = {type = fType[i], path = fPath[i], name = fName[i]}
		end
	end
	return directoryContents
end

local peripheralList = getDirectoryContents(githubUsername, "Tiles", "master", "programs/baseMonitor/peripherals", true)
if peripheralList then
	for _, file in ipairs(peripheralList) do
		local peripheralType = string.gsub(file.name, ".lua$", "")
		if not updateOnly or not fs.exists(fs.combine(saveDir, "peripherals/"..peripheralType)) then
			fileList["peripherals/"..peripheralType] = {"Tiles", file.path}
		end
	end
else
	printError("Could not download peripheralList")
end

local sourceList = getDirectoryContents(githubUsername, "Tiles", "master", "programs/baseMonitor/sources", true)
if sourceList then
	for _, file in ipairs(sourceList) do
		local sourceType = string.gsub(file.name, ".lua$", "")
		if not updateOnly or not fs.exists(fs.combine(saveDir, "sources/"..sourceType)) then
			fileList["sources/"..sourceType] = {"Tiles", file.path}
		end
	end
else
	printError("Could not download sourceList")
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

for localPath, remotePathDetails in pairs(fileList) do
	local url = table.concat({mainURL, remotePathDetails[1], "master", remotePathDetails[2]}, "/")
	local path = table.concat({saveDir, localPath}, "/")
	if not fs.exists(path) or not (fs.isDir(path) or noOverwrite) then
		local fileData = get(url)			
		if fileData then
			if save(fileData, path) then
				print("Download successful: ", localPath)
			else
				print("Save failed: ", localPath)
			end
		else
			print("Download failed: ", localPath)
		end
	else
		print("Skipping: ", localPath)
	end
end
