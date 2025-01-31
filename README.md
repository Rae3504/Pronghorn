# What is Pronghorn Framework?

Pronghorn is a Roblox framework with a direct approach to Module scripting that facilitates rapid development.

No Controllers or Services, just Modules and Remotes.

## Usage
- Pronghorn:Import() is used in a Script to import your Modules.
- Modules as descendants of other Modules are not imported.
- Pronghorn:SetEnabledChannels() controls the output of Modules.

# How does Pronghorn compare to others?

### Pros
- Luau typechecking and autocomplete.
- Obvious and concise error stack traces.
- Requiring Pronghorn only in the Script and not in every Module.
- Obvious Remote behavior in both creation and invocation.
- Addition of Event, QueuedEvent, and TrackedVariable.

### Cons
- No automatic Remote creation using Services.
- No Remote packing optimization techniques (due to [ordering breakage](https://en.wikipedia.org/wiki/Out-of-order_delivery).)

### Preference
- No Controller or Service structure.
- Not Promise based.

# Core Module Functions

## Remotes
```lua
-- Creation
local exampleRemote = Remotes:CreateToClient(name: string, requiredParameterTypes: {string}, returns: boolean?): any
local exampleRemote = Remotes:CreateToServer(name: string, requiredParameterTypes: {string}, returns: boolean?, func: (any) -> (any)): any

-- Server Invocation Absolute
Remotes.ExampleModule.ExampleRemote:Fire(players: Player | {Player}, ...)
Remotes.ExampleModule.ExampleRemote:FireAll(...)
Remotes.ExampleModule.ExampleRemote:FireAllExcept(ignorePlayer: Player, ....)

-- Server Invocation Shortcut
exampleRemote:Fire(players: Player | {Player}, ...)
exampleRemote:FireAll(...)
exampleRemote:FireAllExcept(ignorePlayer: Player, ....)

-- Client Invocation Absolute
Remotes.ExampleModule:ExampleRemote(...)
Remotes.ExampleModule.ExampleRemote:Fire(...)

-- Client Invocation Shortcut
local exampleRemote = Remotes.ExampleModule.ExampleRemote
exampleRemote:Fire(...)
```

## Debug
```lua
Print(...)
Warn(...)
Trace(...)
```

## New
```lua
New.Instance(className: string, parent: Instance?, name: string?, properties: {[string]: any, Children: {Instance}?, Attributes: {[string]: any}?, Tags: {string}?}?): Instance
New.Clone(instance: Instance?, parent: Instance?, name: string?, properties: {[string]: any, Children: {Instance}?, Attributes: {[string]: any}?, Tags: {string}?}?): 
	-- New.Instance / New.Clone
		-- Parent, Name, and Properties optional parameters can be provided in any combination and order.
			-- Ex. New.Instance("Part", {Properties})
		-- Properties parameter special cases
			-- Can contain a "Children" key with type {Instance}.
			-- Can contain an "Attributes" key with type {[string]: any}.
			-- Can contain a "Tags" key with type {string}.
			-- RBXScriptSignal properties (e.g. "Changed") can be assigned a function.
New.Event(): {
	Fire: (self: any, ...any?) -> ();
	Connect: (self: any, callback: Callback) -> ({Disconnect: (self: any) -> ()});
	Once: (self: any, callback: Callback) -> ({Disconnect: (self: any) -> ()});
	Wait: (self: any) -> (any);
	DisconnectAll: (self: any) -> ();
}
New.QueuedEvent(): {
	Fire: (self: any, ...any?) -> ();
	Connect: (self: any, callback: Callback) -> ({Disconnect: (self: any) -> ()});
	Once: (self: any, callback: Callback) -> ({Disconnect: (self: any) -> ()});
	Wait: (self: any) -> (any);
	DisconnectAll: (self: any) -> ();
}
New.TrackedVariable(Variable: any): {
	Get: (self: any) -> (any);
	Set: (self: any, value: any) -> ();
	Connect: (self: any, callback: Callback) -> ({Disconnect: (self: any) -> ()});
	Once: (self: any, callback: Callback) -> ({Disconnect: (self: any) -> ()});
	Wait: (self: any) -> (any);
	DisconnectAll: (self: any) -> ();
}
```

# Code Snippets

## Script Boilerplate
```lua
local Pronghorn = require(game:GetService("ReplicatedStorage").Pronghorn)
Pronghorn:SetEnabledChannels({
	ExampleModule = true;
})

-- Global Variables
shared.ExampleVariable = "Example"

-- Somewhere after assigning global variables
Pronghorn:Import({
	ExampleModuleDirectory;
})
```

## Module Boilerplate
```lua
local ExampleModule = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Core
local Print = require(ReplicatedStorage.Modules.Pronghorn.Debug).Print
local Warn = require(ReplicatedStorage.Modules.Pronghorn.Debug).Warn
local Trace = require(ReplicatedStorage.Modules.Pronghorn.Debug).Trace
local New = require(ReplicatedStorage.Modules.Pronghorn.New)
local Remotes = require(ReplicatedStorage.Modules.Pronghorn.Remotes)

-- Modules
local OtherExampleModule = require(ReplicatedStorage.Modules.OtherExampleModule)

--[[
	Module Body
]]

return ExampleModule
```

## Automated Module Functions
```lua
function ExampleModule:Init()
	-- Runs after all modules are imported. Cannot yield.
end

function ExampleModule:Deferred()
	-- Runs after all modules have initialized.
end

function ExampleModule.PlayerAdded(player: Player)
	-- Players.PlayerAdded shortcut.
end

function ExampleModule.PlayerAddedDeferred(player: Player)
	-- Players.PlayerAdded shortcut. Runs after all PlayerAdded functions.
end

function ExampleModule.PlayerRemoving(player: Player)
	-- Players.PlayerRemoving shortcut.
end

function ExampleModule.PlayerRemovingDeferred(player: Player)
	-- Players.PlayerRemoving shortcut. Runs after all PlayerRemoving functions.
end
```

## Creating and Invoking a Remote
```lua
-- On Server

local tableCounted = Remotes:CreateToClient("TableCounted", {"string"})
-- Second parameter is nil, so this Remote is non-returning.

Remotes:CreateToServer("CountTable", {"table"}, true, function(player: Player, tableToCount: {any})
	Remotes.ExampleServerModule.TableCounted:FireAll(player.Name) -- Absolute method
	tableCounted:FireAll(player.Name) -- Shortcut method
	return #tableToCount
end)
-- Second parameter is true, so this Remote returns.
```
```lua
-- On Client

Remotes.ExampleServerModule.TableCounted:Connect(function(playerName: string)
	Print(playerName, "requested a Table to be counted.")
end)

function ExampleClientModule:Deferred()
	Print(Remotes.ExampleServerModule:CountTable({"A", "B", "C"}))
end
```

# Useful Modules

https://github.com/Iron-Stag-Games/Useful-Modules

A collection of useful modules compatible with the Pronghorn Framework.

# Games made with Pronghorn

- **[ExoTech](https://www.roblox.com/games/7634484468)** - Iron Stag Games
- **[Traitor Town](https://www.roblox.com/games/255236425)** - Traitor Town
- **[RB Battles](https://www.roblox.com/games/5036207802)** - RB Battles Games
- **[Mansion Tycoon](https://www.roblox.com/games/12912731475)** - Capybara's Productions
- **NDA title** - RB Battles PVP
- **NDA title #1** - Fund For Games
- **NDA title #2** - Fund For Games
