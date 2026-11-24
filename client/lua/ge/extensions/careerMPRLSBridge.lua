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

-- RLS spawns traffic and parked cars from overhaul_career_police_playerDriving, which ignores the
-- CareerMP server config. Every one of those cars is synced as this player's vehicle, so clamp
-- the amounts the same way CareerMP's own playerDriving does.
local function limitedSetupTrafficHelper(trafficAmount, options, parkingAmount, ...)
	local config = careerMPEnabler and careerMPEnabler.getClientConfig and careerMPEnabler.getClientConfig()
	if config then
		trafficAmount = config.roadTrafficEnabled and math.min(trafficAmount or 0, config.roadTrafficAmount or trafficAmount or 0) or 0
		parkingAmount = config.parkedTrafficEnabled and math.min(parkingAmount or 0, config.parkedTrafficAmount or parkingAmount or 0) or 0
	end
	if (trafficAmount or 0) <= 0 and (parkingAmount or 0) <= 0 then
		log('I', 'careerMP', 'CareerMP RLS bridge: traffic and parked cars disabled by server config')
		-- RLS holds the loading screen until traffic reports ready; nothing will spawn, so report it now.
		local driving = overhaul_career_police_playerDriving
		if driving and driving.onTrafficOrParkingReady then
			driving.onTrafficOrParkingReady()
		elseif core_gamestate.getLoadingStatus('careerVehicles') then
			core_gamestate.requestExitLoadingScreen('careerVehicles')
		end
		return
	end
	return originals.setupTrafficHelper(trafficAmount, options, parkingAmount, ...)
end

-- BeamMP's Leave unloads the level without going through returnToMainMenu/quit, the exits RLS
-- patches to flush its save, so progress since the last 5-minute autosave was lost. Flush first.
local function leaveServerAfterSave(...)
	local args, count = {...}, select('#', ...)
	local saveSystem = overhaul_career_saveSystem
	local career = overhaul_career_career
	if saveSystem and saveSystem.flushSaveForExit and career and career.isActive and career.isActive() then
		log('I', 'careerMP', 'CareerMP RLS bridge: saving the RLS career before leaving the server')
		return saveSystem.flushSaveForExit(function() originals.leaveServer(unpack(args, 1, count)) end)
	end
	return originals.leaveServer(unpack(args, 1, count))
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
	if gameplay_traffic then
		originals.setupTrafficHelper = gameplay_traffic.setupTrafficHelper
		gameplay_traffic.setupTrafficHelper = limitedSetupTrafficHelper
	end
	if MPCoreNetwork and MPCoreNetwork.leaveServer then
		originals.leaveServer = MPCoreNetwork.leaveServer
		MPCoreNetwork.leaveServer = leaveServerAfterSave
	end
	patched = true
	log('W', 'careerMP', 'CareerMP RLS bridge: RLS career enabled for this multiplayer session')
	return true
end

local function unpatch()
	if not patched then return end
	if overhaul_shell_extensionManager and originals.refuseCareerStart then
		overhaul_shell_extensionManager.refuseCareerStart = originals.refuseCareerStart
	end
	if gameplay_traffic and originals.setupTrafficHelper then
		gameplay_traffic.setupTrafficHelper = originals.setupTrafficHelper
	end
	if MPCoreNetwork and originals.leaveServer then
		MPCoreNetwork.leaveServer = originals.leaveServer
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
