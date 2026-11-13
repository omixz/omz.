--!nonstrict
-- Loads the sculpted mesh packs (Config/AssetIds) once at server start and hands out clones.
-- Sources, in order: ServerStorage > Assets > <Pack> (imported in Studio), then
-- InsertService:LoadAsset(id) for uploaded packs. Missing packs => built-in fallbacks.
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AssetIds = require(Shared.Config.AssetIds)
local MeshMeta = require(Shared.Config.MeshMeta)
local MeshKit = require(Shared.MeshKit)

local AssetService = {}

local parts = {} -- [meshName] = MeshPart template
local loaded = false

-- Every mesh name the game asks for (from MeshMeta), longest first, so an importer that
-- renames parts (adds "_Mesh", ".001", wraps them in a Model) still maps back.
local known, knownList = {}, {}
local canonCentre = {} -- [meshName] = Vector3 (where the piece sits in sculpt space)
local canonSize = {} -- [meshName] = Vector3 (its bounding box in sculpt space)
for _, entry in MeshMeta do
	local groups = entry.type == "rig" and entry.segments or { entry }
	for _, group in groups do
		for _, layer in group.layers do
			if not known[layer.part] then
				known[layer.part] = true
				table.insert(knownList, layer.part)
				canonCentre[layer.part] = Vector3.new(layer.center[1], layer.center[2], layer.center[3])
				canonSize[layer.part] = Vector3.new(layer.size[1], layer.size[2], layer.size[3])
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

-- The 24 axis-aligned rotations (every way an importer can turn a scene).
local ROTATIONS = {}
do
	local seen = {}
	for _, rx in { 0, 90, 180, 270 } do
		for _, ry in { 0, 90, 180, 270 } do
			for _, rz in { 0, 90, 180, 270 } do
				local cf = CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
				local key = ("%d%d%d%d%d%d"):format(
					math.round(cf.RightVector.X), math.round(cf.RightVector.Y), math.round(cf.RightVector.Z),
					math.round(cf.UpVector.X), math.round(cf.UpVector.Y), math.round(cf.UpVector.Z)
				)
				if not seen[key] then
					seen[key] = true
					table.insert(ROTATIONS, cf)
				end
			end
		end
	end
end

-- Roblox's importer may turn and scale the whole scene (glTF conventions vs Roblox's). We know
-- where every piece sits in sculpt space (MeshMeta) and where it landed in the imported
-- model, so we solve that transform (best of the 24 rotations, least-squares scale) and
-- store, on each template, the rotation and scale that undo it for that piece. MeshKit uses
-- them, so pieces come out the right way round and the right shape whatever the importer did.
local function solveImport(name, templates)
	local A, B = {}, {}
	for meshName, part in templates do
		local c = canonCentre[meshName]
		if c then
			table.insert(A, c)
			table.insert(B, part.Position)
		end
	end
	if #A < 3 then
		return
	end
	local ca, cb = Vector3.zero, Vector3.zero
	for i = 1, #A do
		ca += A[i]
		cb += B[i]
	end
	ca /= #A
	cb /= #B
	local best, bestK, bestErr = nil, 1, math.huge
	for _, G in ROTATIONS do
		local num, den = 0, 0
		for i = 1, #A do
			local a = G:VectorToWorldSpace(A[i] - ca)
			num += a:Dot(B[i] - cb)
			den += a:Dot(a)
		end
		local k = den > 1e-9 and num / den or 0
		if k > 0 then
			local err, norm = 0, 0
			for i = 1, #A do
				local b = B[i] - cb
				local d = b - G:VectorToWorldSpace(A[i] - ca) * k
				err += d:Dot(d)
				norm += b:Dot(b)
			end
			err /= math.max(norm, 1e-9)
			if err < bestErr then
				best, bestK, bestErr = G, k, err
			end
		end
	end
	if not best or bestErr > 0.02 then
		-- positions didn't survive the import: match each piece's box shape instead (recovers
		-- which axis is which; a 180 degree flip can't be told apart from shape alone)
		local fixed = 0
		for meshName, part in templates do
			local want = canonSize[meshName]
			if want and want.Magnitude > 1e-6 then
				local bestG, bestE, bestScale = nil, math.huge, 1
				for _, G in ROTATIONS do
					local r = G:VectorToWorldSpace(want)
					r = Vector3.new(math.abs(r.X), math.abs(r.Y), math.abs(r.Z))
					local k = part.Size.Magnitude / r.Magnitude
					local d = part.Size / k - r
					local e = d.Magnitude / r.Magnitude
					if e < bestE - 1e-4 then
						bestG, bestE, bestScale = G, e, k
					end
				end
				if bestG then
					part:SetAttribute("FitRot", bestG:Inverse())
					part:SetAttribute("FitScale", 1 / bestScale)
					fixed += 1
				end
			end
		end
		warn(("[AssetService] %s: positions didn't survive import (fit error %.3f); matched %d pieces by shape"):format(name, bestErr, fixed))
		return
	end
	local inv = best:Inverse()
	for _, part in templates do
		part:SetAttribute("FitRot", inv * part.CFrame.Rotation)
		part:SetAttribute("FitScale", 1 / bestK)
	end
	local rx, ry, rz = best:ToEulerAnglesXYZ()
	print(("[AssetService] %s: importer turned the scene (%d, %d, %d) deg, scale %.3f, fit error %.4f, %d pieces"):format(
		name, math.round(math.deg(rx)), math.round(math.deg(ry)), math.round(math.deg(rz)), bestK, bestErr, #A))
end

local function index(container)
	local found, unknown = 0, 0
	local templates = {}
	for _, d in container:GetDescendants() do
		if d:IsA("MeshPart") then
			local name = resolveName(d)
			if name then
				-- our colours/materials come from MeshMeta, so drop imported surface looks
				-- keep imported surface detail (normal / roughness maps) but never a colour map:
				-- colours come from MeshMeta so outfits can recolour the part
				for _, child in d:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						local okRead, colorMap = pcall(function()
							return child.ColorMap
						end)
						if okRead and colorMap ~= nil and tostring(colorMap) ~= "" then
							child:Destroy()
						end
					elseif child:IsA("Decal") or child:IsA("Texture") then
						child:Destroy()
					end
				end
				d.TextureID = ""
				parts[name] = d
				templates[name] = d
				found += 1
			else
				unknown += 1
			end
		end
	end
	if unknown > 0 then
		warn(("[AssetService] %s: %d meshes matched, %d unrecognised names (e.g. check the pack was imported unchanged)"):format(container.Name, found, unknown))
	end
	solveImport(container.Name, templates)
end

function AssetService.load()
	MeshKit.setYawFix(AssetIds.YawFix)
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

-- True when a kit (from MeshMeta) is loaded well enough to use: nearly every layer present.
-- A detail layer that's missing (e.g. an older revision of the pack still being served while
-- the new one is reviewed) is simply skipped by MeshKit instead of failing the whole body.
function AssetService.hasKit(kit)
	local entry = MeshMeta[kit]
	if not entry then
		return false
	end
	local groups = entry.type == "rig" and entry.segments or { entry }
	local total, present = 0, 0
	for _, group in groups do
		for _, layer in group.layers do
			total += 1
			if parts[layer.part] then
				present += 1
			end
		end
	end
	return total > 0 and present / total >= 0.85
end

function AssetService.meta(kit)
	return MeshMeta[kit]
end

function AssetService.start()
	AssetService.load()
end

return AssetService
