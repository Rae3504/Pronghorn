--!strict
--[[
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║                                         ▓███                         ║
║             ▄█▀▄▄▓█▓                   █▓█ ██                        ║
║            ▐████                         █ ██                        ║
║             ████                        ▐█ ██                        ║
║             ▀████                       ▐▌▐██                        ║
║              ▓█▌██▄                     █████                        ║
║               ▀█▄▓██▄                  ▐█████                        ║
║                ▀▓▓████▄   ▄▓        ▓▄ █████     ▓ ▌                 ║
║             ▀██████████▓  ██▄       ▓██████▓    █   ▐                ║
║                 ▀▓▓██████▌▀ ▀▄      ▐██████    ▓  █                  ║
║                    ▀███████   ▀     ███████   ▀  █▀                  ║
║                      ███████▀▄     ▓███████ ▄▓  ▄█   ▐               ║
║                       ▀████   ▀▄  █████████▄██  ▀█   ▌               ║
║                        ████      █████  ▄ ▀██    █  █                ║
║                       ██▀▀███▓▄██████▀▀▀▀▀▄▀    ▀▄▄▀                 ║
║                       ▐█ █████████ ▄██▓██ █  ▄▓▓                     ║
║                      ▄███████████ ▄████▀███▓  ███                    ║
║                    ▓███████▀  ▐     ▄▀▀▀▓██▀ ▀██▌                    ║
║                ▄▓██████▀▀▌▀   ▄        ▄▀▓█     █▌                   ║
║               ████▓▓                 ▄▓▀▓███▄   ▐█                   ║
║               ▓▓                  ▄  █▓██████▄▄███▌                  ║
║                ▄       ▌▓█     ▄██  ▄██████████████                  ║
║                   ▀▀▓▓████████▀   ▄▀███████████▀████                 ║
║                          ▀████████████████▀▓▄▌▌▀▄▓██                 ║
║                           ██████▀██▓▌▀▌ ▄     ▄▓▌▐▓█▌                ║
║                                                                      ║
║                                                                      ║
║                    Pronghorn Framework  Rev. B53-r                   ║
║             https://github.com/Iron-Stag-Games/Pronghorn             ║
║                GNU Lesser General Public License v2.1                ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║      Pronghorn is a Roblox framework with a direct approach to       ║
║         Module scripting that facilitates rapid development.         ║
║                                                                      ║
║        No Controllers or Services, just Modules and Remotes.         ║
║                                                                      ║
╠═══════════════════════════════ Usage ════════════════════════════════╣
║                                                                      ║
║ - Pronghorn:Import() is used in a Script to import your Modules.     ║
║ - Modules as descendants of other Modules are not imported.          ║
║ - Pronghorn:SetEnabledChannels() controls the output of Modules.     ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
]]

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dependencies
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Core
local New = require(script.New)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helper Variables
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

type Module = {
	Object: ModuleScript;
	Return: any?;
}

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function addModules(allModules: {Module}, object: Instance)
	for _, child in object:GetChildren() do
		if child:IsA("ModuleScript") then
			if child ~= script then
				table.insert(allModules, {Object = child, Return = require(child) :: any})
			end
		else
			addModules(allModules, child)
		end
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Import Core Modules --

local coreModules = {}

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		coreModules[child.Name] = require(child) :: any
	end
end

-- Init
for _, coreModule in coreModules do
	if type(coreModule) == "table" and coreModule.Init then
		coreModule:Init()
	end
end

-- Deferred
for _, coreModule in coreModules do
	if type(coreModule) == "table" and coreModule.Deferred then
		task.spawn(coreModule.Deferred, coreModule)
	end
end

return {
	SetEnabledChannels = coreModules.Debug.SetEnabledChannels;

	Import = function(_, paths: {Instance})
		local allModules: {Module} = {}

		for _, object in paths do
			addModules(allModules, object)
		end

		-- Init
		for _, moduleTable in allModules do
			if type(moduleTable.Return) == "table" and moduleTable.Return.Init then
				local thread = task.spawn(moduleTable.Return.Init, moduleTable.Return)
				if coroutine.status(thread) ~= "dead" then
					error(`{moduleTable.Object:GetFullName()}: Yielded during Init function`, 0)
				end
			end
		end

		-- Deferred
		local deferredComplete = New.Event()
		local startWaits = 0
		for _, moduleTable in allModules do
			if type(moduleTable.Return) == "table" and moduleTable.Return.Deferred then
				startWaits += 1
				task.spawn(function()
					local running = true
					task.delay(5, function()
						if running then
							warn(`{moduleTable.Object:GetFullName()}: Infinite yield possible in Deferred function`)
						end
					end)
					moduleTable.Return:Deferred()
					running = false
					startWaits -= 1
					if startWaits == 0 then
						deferredComplete:Fire()
					end
				end)
			end
		end

		-- PlayerAdded
		local function playerAdded(player: Player)
			for _, moduleTable in allModules do
				if type(moduleTable.Return) == "table" and moduleTable.Return.PlayerAddedInit then
					task.spawn(moduleTable.Return.PlayerAddedInit, moduleTable.Return, player)
				end
			end
			for _, moduleTable in allModules do
				if type(moduleTable.Return) == "table" and moduleTable.Return.PlayerAdded then
					task.spawn(moduleTable.Return.PlayerAdded, moduleTable.Return, player)
				end
			end
		end
		Players.PlayerAdded:Connect(playerAdded)
		for _, player in Players:GetPlayers() do
			playerAdded(player)
		end

		-- PlayerRemoving
		Players.PlayerRemoving:Connect(function(player: Player)
			for _, moduleTable in allModules do
				if type(moduleTable.Return) == "table" and moduleTable.Return.PlayerRemovingInit then
					task.spawn(moduleTable.Return.PlayerRemovingInit, moduleTable.Return, player)
				end
			end
			for _, moduleTable in allModules do
				if type(moduleTable.Return) == "table" and moduleTable.Return.PlayerRemoving then
					task.spawn(moduleTable.Return.PlayerRemoving, moduleTable.Return, player)
				end
			end
		end)

		-- Wait for Deferred Functions to complete
		while startWaits > 0 do
			deferredComplete:Wait()
		end
	end;
}
