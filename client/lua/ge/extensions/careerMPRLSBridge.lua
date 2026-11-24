-- CareerMP 2.0: bridge that lets RLS Career Overhaul (2.8.x, overhaul_* extensions) run its
-- career inside a CareerMP/BeamMP session. Nothing in RLS is edited: the few functions that
-- assume single player are wrapped at runtime while connected and restored on leave.

local M = {}

local patched = false
local originals = {}

local function isRLSLoaded()
	return overhaul_career_career ~= nil and overhaul_shell_extensionManager ~= nil
end

-- Deletes only vehicles this client owns; other players' vehicles are BeamMP's to manage.
local function removeOwnVehiclesOnly()
	if not MPVehicleGE then
		return originals.removeAll and originals.removeAll()
	end
	for i = be:getObjectCount() - 1, 0, -1 do
		local obj = be:getObject(i)
		if obj and MPVehicleGE.isOwn(obj:getID()) then
			obj:delete()
		end
	end
end

local function patch()
	if patched or not isRLSLoaded() then return patched end
	local em = overhaul_shell_extensionManager
	-- RLS refuses to start whenever BeamMP is enabled. Inside a CareerMP session that is the point.
	originals.refuseCareerStart = em.refuseCareerStart
	em.refuseCareerStart = function() return false end
	-- RLS clears the level with core_vehicles.removeAll() when a career starts in the current level.
	originals.removeAll = core_vehicles.removeAll
	core_vehicles.removeAll = removeOwnVehiclesOnly
	patched = true
	log('W', 'careerMP', 'CareerMP RLS bridge: RLS career enabled for this multiplayer session')
	return true
end

local function unpatch()
	if not patched then return end
	if overhaul_shell_extensionManager and originals.refuseCareerStart then
		overhaul_shell_extensionManager.refuseCareerStart = originals.refuseCareerStart
	end
	if originals.removeAll then
		core_vehicles.removeAll = originals.removeAll
	end
	originals = {}
	patched = false
end

-- Career API CareerMP should drive: RLS when it is loaded, otherwise the stock career (careerMP).
local function getCareer()
	if patch() then
		return overhaul_career_career
	end
	return career_career
end

-- Starts or loads a career on the level BeamMP already loaded, never switching maps.
local function createOrLoadCareerAndStart(name)
	local career = getCareer()
	if career == overhaul_career_career then
		local level = getCurrentLevelIdentifier()
		-- (name, specificAutosave, tutorial/startingOptions, hardcore, challengeId, cheats, startingMap)
		return career.createOrLoadCareerAndStart(name, nil, nil, false, nil, false, level)
	end
	return career.createOrLoadCareerAndStart(name, false, false)
end

local function deactivateCareer()
	local career = isRLSLoaded() and overhaul_career_career or career_career
	if career and career.isActive and career.isActive() then
		career.deactivateCareer()
	end
	unpatch()
end

-- Career modules CareerMP touches, resolved to RLS's overhaul_* equivalents when RLS runs the career.
-- The RLS functions CareerMP calls keep the vanilla signatures (getInventoryIdFromVehicleId,
-- getVehicleIdFromInventoryId, getVehicles, getAttribute, addAttributes, saveCurrent).
local function getInventory()
	if isRLSLoaded() then return overhaul_career_garage_inventory end
	return career_modules_inventory
end

local function getPlayerAttributes()
	if isRLSLoaded() then return overhaul_career_economy_playerAttributes end
	return career_modules_playerAttributes
end

local function getSaveSystem()
	if isRLSLoaded() then return overhaul_career_saveSystem end
	return career_saveSystem
end

M.isRLSLoaded = isRLSLoaded
M.getInventory = getInventory
M.getPlayerAttributes = getPlayerAttributes
M.getSaveSystem = getSaveSystem
M.getCareer = getCareer
M.createOrLoadCareerAndStart = createOrLoadCareerAndStart
M.deactivateCareer = deactivateCareer
M.onExtensionLoaded = function() log('W', 'careerMP', 'CareerMP RLS bridge LOADED!') end
M.onExtensionUnloaded = function() unpatch() end
M.onInit = function() setExtensionUnloadMode(M, 'manual') end

return M
