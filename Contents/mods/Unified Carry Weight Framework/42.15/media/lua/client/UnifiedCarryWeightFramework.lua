require("UCWF_ModOptions")

UnifiedCarryWeightFramework = UnifiedCarryWeightFramework or {}

UnifiedCarryWeightFramework.baseModifiers = UnifiedCarryWeightFramework.baseModifiers or {}
UnifiedCarryWeightFramework.maxModifiers = UnifiedCarryWeightFramework.maxModifiers or {}

local function initializeModOptions(playerIndex, player)
	modOptions = PZAPI.ModOptions:getOptions("UCWFModOptions")
end

Events.OnCreatePlayer.Remove(initializeModOptions)
Events.OnCreatePlayer.Add(initializeModOptions)

local log = function(...)
	if modOptions and modOptions:getOption("GatherDetailedDebugUCWF"):getValue() then
		print("UCWF | " .. ...)
	end
end

local systemShouldRun = false

---Function that applies a list of modifiers to a starting value, returning the final modified value.
---@param startValue number
---@param modifiers table
---@param context table
---@return number
local function applyModifierPipeline(startValue, modifiers, context)
	local totalAdd = 0
	local totalMult = 1.0

	for _, modifier in pairs(modifiers) do
		local result = modifier.resolve(context)

		if result then
			if result.add ~= nil then
				totalAdd = totalAdd + result.add
			end

			if result.mult ~= nil then
				totalMult = totalMult * result.mult
			end
		end
	end

	return (startValue + totalAdd) * totalMult
end

--- Function that registers a modifier to be applied to base carry weight
--- @param def any
function UnifiedCarryWeightFramework.registerBaseModifier(def)
	assert(type(def) == "table", "registerBaseModifier(def): def must be a table")
	assert(def.id ~= nil, "registerBaseModifier(def): def.id is required")
	assert(type(def.resolve) == "function", "registerBaseModifier(def): def.resolve must be a function")

	print("UCWF | Registering base modifier: " .. tostring(def.id))

	UnifiedCarryWeightFramework.baseModifiers[def.id] = def
	systemShouldRun = true
end

--- Function that registers a modifier to be applied to max carry weight after base weight is calculated
--- @param def any
function UnifiedCarryWeightFramework.registerMaxModifier(def)
	assert(type(def) == "table", "registerMaxModifier(def): def must be a table")
	assert(def.id ~= nil, "registerMaxModifier(def): def.id is required")
	assert(type(def.resolve) == "function", "registerMaxModifier(def): def.resolve must be a function")

	print("UCWF | Registering max modifier: " .. tostring(def.id))
	UnifiedCarryWeightFramework.maxModifiers[def.id] = def
	systemShouldRun = true
end

--- Function that recomputes the carry weight for a player, applying all modifiers in the correct ordering
---@param player IsoPlayer
function UnifiedCarryWeightFramework.recomputeAll(player)
	if not systemShouldRun then
		log("No carry weight modifiers registered, skipping recompute and unregistering events")
		Events.EveryHours.Remove(recomputeCarryWeight_EveryHours)
		Events.EveryHours.Remove(debugDumpCarryWeight_EveryHours)
		return
	end
	player = player or getPlayer()
	log("Recomputing carry weight")
	local originalBaseWeight = 8
	player:setMaxWeightDelta(1)

	local baseContext = {
		player = player,
	}

	local newBaseWeight =
		applyModifierPipeline(originalBaseWeight, UnifiedCarryWeightFramework.baseModifiers, baseContext)
	log("New base weight: " .. tostring(newBaseWeight))
	player:setMaxWeightBase(newBaseWeight)

	player:getBodyDamage():Update()

	local maxContext = {
		player = player,
	}
	local currentMaxWeight = player:getMaxWeight()
	log("Current max weight before max modifiers: " .. tostring(currentMaxWeight))
	local newMaxWeight = applyModifierPipeline(currentMaxWeight, UnifiedCarryWeightFramework.maxModifiers, maxContext)
	if SandboxVars.UnifiedCarryWeightFramework.CapWeight then
		newMaxWeight = math.min(newMaxWeight, 50)
	end
	log("New max weight: " .. tostring(newMaxWeight))
	local deltaToSet = newMaxWeight / player:getMaxWeight()
	log("Setting max weight delta to: " .. tostring(deltaToSet))

	player:setMaxWeightDelta(deltaToSet)
end

---Function responsible for initializing all traits logic
---@param playerIndex number
---@param player IsoPlayer
local function recomputeCarryWeight_OnCreatePlayer(playerIndex, player)
	if not player or not instanceof(player, "IsoPlayer") then
		player = getPlayer()
	end
	UnifiedCarryWeightFramework.recomputeAll(player)
end

local function recomputeCarryWeight_EveryHours()
	UnifiedCarryWeightFramework.recomputeAll(nil)
end

local function debugDumpCarryWeight_EveryHours()
	local player = getPlayer()
	for id, modifier in pairs(UnifiedCarryWeightFramework.baseModifiers) do
		local result = modifier.resolve({ player = player }) or {}
		log(
			"Base Modifier: "
				.. tostring(id)
				.. " resolved to: { add="
				.. tostring(result.add)
				.. ", mult="
				.. tostring(result.mult)
				.. "}"
		)
	end
	for id, modifier in pairs(UnifiedCarryWeightFramework.maxModifiers) do
		local result = modifier.resolve({ player = player }) or {}
		log(
			"Max Modifier: "
				.. tostring(id)
				.. " resolved to: { add="
				.. tostring(result.add)
				.. ", mult="
				.. tostring(result.mult)
				.. "}"
		)
	end
end

Events.OnCreatePlayer.Remove(recomputeCarryWeight_OnCreatePlayer)
Events.OnCreatePlayer.Add(recomputeCarryWeight_OnCreatePlayer)
Events.EveryHours.Remove(recomputeCarryWeight_EveryHours)
Events.EveryHours.Add(recomputeCarryWeight_EveryHours)
Events.EveryHours.Remove(debugDumpCarryWeight_EveryHours)
Events.EveryHours.Add(debugDumpCarryWeight_EveryHours)

return UnifiedCarryWeightFramework
