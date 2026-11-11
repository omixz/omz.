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

local function index(container)
	for _, d in container:GetDescendants() do
		if d:IsA("MeshPart") then
			parts[d.Name] = d
		end
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
