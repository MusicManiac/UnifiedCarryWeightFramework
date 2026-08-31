local function gameMode()
	if not isClient() and not isServer() then
		return "SP"
	elseif isClient() then
		return "MP_Client"
	end
	return "MP_Server"
end

local gameMode = gameMode()

-- This should be ran only if it's SP or if it's a server process
if gameMode ~= "MP_Server" then
	print("UCWF | UnifiedCarryWeightFramework_Server | Detected " .. gameMode .. " environment, skipping the file")
	return
else
	print("UCWF | UnifiedCarryWeightFramework_Server | Detected " .. gameMode .. " environment, loading the file")
end

local Commands = {}
local pendingWeightRecomputes = {}
-- Cumulative retry window: 30, 150, 450, 1050, and 1950 ticks after the
-- initial request. This spans the roughly 30-second sync delay seen in MP.
local weightRecomputeRetryDelays = { 30, 120, 300, 600, 900 }
local processPendingWeightRecomputes

require("UnifiedCarryWeightFramework")

local function stopWeightRecomputeRetriesIfIdle()
	local hasPendingRecomputes = false
	for _ in pairs(pendingWeightRecomputes) do
		hasPendingRecomputes = true
		break
	end

	if not hasPendingRecomputes then
		Events.OnTick.Remove(processPendingWeightRecomputes)
	end
end

processPendingWeightRecomputes = function()
	for player, pending in pairs(pendingWeightRecomputes) do
		pending.ticksRemaining = pending.ticksRemaining - 1
		if pending.ticksRemaining <= 0 then
			UnifiedCarryWeightFramework.log(
				"Retrying carry weight stabilization for player " .. tostring(player:getUsername())
			)
			UnifiedCarryWeightFramework.recomputeAll(player)

			pending.retryIndex = pending.retryIndex + 1
			local nextDelay = weightRecomputeRetryDelays[pending.retryIndex]
			if nextDelay then
				pending.ticksRemaining = nextDelay
			else
				pendingWeightRecomputes[player] = nil
			end
		end
	end

	stopWeightRecomputeRetriesIfIdle()
end

local function scheduleWeightRecomputeRetries(player)
	pendingWeightRecomputes[player] = {
		retryIndex = 1,
		ticksRemaining = weightRecomputeRetryDelays[1],
	}
	Events.OnTick.Remove(processPendingWeightRecomputes)
	Events.OnTick.Add(processPendingWeightRecomputes)
end

function Commands.update_weight(player, args)
	UnifiedCarryWeightFramework.recomputeAll(player)
	-- The server can receive the initial client command before vanilla has synced the
	-- player's real max weight. Retry briefly so a later vanilla overwrite is
	-- normalized and all registered modifiers are applied without waiting an hour.
	scheduleWeightRecomputeRetries(player)
end

Commands.OnClientCommand = function(module, command, player, args)
	if module == "UCWF" and Commands[command] then
		local argStr = ""
		args = args or {}
		for k, v in pairs(args) do
			argStr = argStr .. " " .. k .. "=" .. tostring(v)
		end
		if SandboxVars.UnifiedCarryWeightFramework.GatherDetailedDebug then
			print(
				"UCWF | UnifiedCarryWeightFramework_Server | Received command: " .. command .. " with args:" .. argStr
			)
		end
		Commands[command](player, args)
	end
end

Events.OnClientCommand.Add(Commands.OnClientCommand)
