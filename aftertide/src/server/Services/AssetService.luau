--!nonstrict
-- Loads the sculpted mesh packs (Config/AssetIds) once at server start and hands out clones.
-- Sources, in order: ServerStorage > Assets > <Pack> (imported in Studio), then
-- InsertService:LoadAsset(id) for uploaded packs. Missing packs => built-in fallbacks.
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AssetIds = require(Shared.Config.AssetIds)
local MeshMeta = require(Shared.Config.MeshMeta)

local AssetService = {}

local parts = {} -- [meshName] = MeshPart template
local loaded = false

-- Every mesh name the game asks for (from MeshMeta), longest first, so an importer that
-- renames parts (adds "_Mesh", ".001", wraps them in a Model) still maps back.
local known, knownList = {}, {}
for _, entry in MeshMeta do
	local groups = entry.type == "rig" and entry.segments or { entry }
	for _, group in groups do
		for _, layer in group.layers do
			if not known[layer.part] then
				known[layer.part] = true
				table.insert(knownList, layer.part)
			end
		end
	end
end
table.sort(knownList, function(a, b)
	return #a > #b
end)

local function resolveName(meshPart)
	for _, candidate in { meshPart.Name, meshPart.Parent and meshPart.Parent.Name or "" } do
		if known[candidate] then
			return candidate
		end
		local trimmed = candidate:gsub("%.%d+$", ""):gsub("_[Mm]esh$", ""):gsub("_[Pp]rimitive%d*$", "")
		if known[trimmed] then
			return trimmed
		end
	end
	for _, name in knownList do
		if meshPart.Name:find(name, 1, true) == 1 then
			return name
		end
	end
	return nil
end

local function index(container)
	local found, unknown = 0, 0
	for _, d in container:GetDescendants() do
		if d:IsA("MeshPart") then
			local name = resolveName(d)
			if name then
				-- our colours/materials come from MeshMeta, so drop imported surface looks
				for _, child in d:GetChildren() do
					if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") then
						child:Destroy()
					end
				end
				d.TextureID = ""
				parts[name] = d
				found += 1
			else
				unknown += 1
			end
		end
	end
	if unknown > 0 then
		warn(("[AssetService] %s: %d meshes matched, %d unrecognised names (e.g. check the pack was imported unchanged)"):format(container.Name, found, unknown))
	end
end

function AssetService.load()
	local cache = Instance.new("Folder")
	cache.Name = "AftertideMeshCache"
	cache.Parent = ServerStorage
	local manual = ServerStorage:FindFirstChild("Assets")
	for pack, id in AssetIds.Packs do
		local source = manual and manual:FindFirstChild(pack)
		if source then
			index(source)
		elseif type(id) == "number" and id > 0 then
			local ok, result = pcall(function()
				return InsertService:LoadAsset(id)
			end)
			if ok and result then
				result.Name = pack
				result.Parent = cache
				index(result)
			else
				warn(("[AssetService] could not load pack %s (%s): %s"):format(pack, tostring(id), tostring(result)))
			end
		end
	end
	local count = 0
	for _ in parts do
		count += 1
	end
	print(("[AssetService] %d sculpted meshes available"):format(count))
	loaded = true
end

function AssetService.waitReady(timeout)
	local deadline = os.clock() + (timeout or 20)
	while not loaded and os.clock() < deadline do
		task.wait(0.1)
	end
	return loaded
end

-- A fresh clone of a mesh by its generated name (e.g. "Crew_mara_Head_Skin"), or nil.
function AssetService.part(name)
	local template = parts[name]
	return template and template:Clone() or nil
end

-- True when every layer of a kit (from MeshMeta) is loaded.
function AssetService.hasKit(kit)
	local entry = MeshMeta[kit]
	if not entry then
		return false
	end
	local groups = entry.type == "rig" and entry.segments or { entry }
	for _, group in groups do
		for _, layer in group.layers do
			if not parts[layer.part] then
				return false
			end
		end
	end
	return true
end

function AssetService.meta(kit)
	return MeshMeta[kit]
end

function AssetService.start()
	AssetService.load()
end

return AssetService
