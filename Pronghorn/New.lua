--!strict
--[[
╔═══════════════════════════════════════════════╗
║              Pronghorn Framework              ║
║  https://iron-stag-games.github.io/Pronghorn  ║
╚═══════════════════════════════════════════════╝
]]

local New = {}

local Signal = require(game:GetService('ReplicatedStorage').SharedModules.Signal)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helper Variables
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Types
type Callback = (...any) -> ()
type Connection = {Disconnect: () -> ()}
export type Event = {
	Fire: (self: Event, ...any) -> ();
	Connect: (self: Event, callback: Callback) -> (Connection);
	Once: (self: Event, callback: Callback) -> (Connection);
	Wait: (self: Event, timeout: number?) -> (any);
}
export type TrackedVariable = {
	Get: (self: TrackedVariable) -> (any);
	Set: (self: TrackedVariable, value: any) -> ();
	Connect: (self: TrackedVariable, callback: Callback) -> (Connection);
	Once: (self: TrackedVariable, callback: Callback) -> (Connection);
	Wait: (self: TrackedVariable, timeout: number?) -> (any);
}
type Properties = {
	[string]: any,
	Children: {Instance}?,
	Attributes: {[string]: any}?,
	Tags: {string}?
}

-- Constants
local QUEUED_EVENT_QUEUE_SIZE = 256

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Module Functions
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Creates and returns a new Instance.
--- @param className -- The ClassName for the Instance being created.
--- @param parent? -- The Parent for the Instance after creation.
--- @param name? -- The Name for the Instance.
--- @param properties? -- A table of properties to apply to the Instance.
--- @return Instance -- The new Instance.
function New.Instance(className: string, parent: Instance?, name: string?, properties: Properties?): any
	local newInstance = Instance.new(className)

	if name then
		newInstance.Name = name
	end
	if properties then
		for key, value in properties do
			if key == "Children" then
				for _, child in value do
					child.Parent = newInstance
				end
			elseif key == "Attributes" then
				for attributeName, attribute in value do
					newInstance:SetAttribute(attributeName, attribute)
				end
			elseif key == "Tags" then
				for _, tag in value do
					newInstance:AddTag(tag)
				end
			else
				(newInstance :: any)[key] = value
			end
		end
	end
	if parent then
		newInstance.Parent = parent
	end

	return newInstance
end

--- Clones and returns and Instance.
--- @param instance -- The Instance to clone from.
--- @param parent? -- The Parent for the cloned Instance after creation.
--- @param name? -- The Name for the cloned Instance.
--- @param properties? -- A table of properties to apply to the cloned Instance.
--- @return Instance -- The cloned Instance.
--- @error Parent parameter used more than once -- Incorrect usage.
--- @error Name parameter used more than once -- Incorrect usage.
--- @error Properties parameter used more than once -- Incorrect usage.
function New.Clone<T>(instance: T, parent: Instance?, name: string?, properties: Properties?): T
	assert(typeof(instance) == "Instance", "Attempt to clone non-Instance")

	local newInstance = instance:Clone()

	if name then
		newInstance.Name = name
	end
	if properties then
		for key, value in properties do
			if key == "Children" then
				for _, child in value do
					child.Parent = newInstance
				end
			elseif key == "Attributes" then
				for attributeName, attribute in value do
					newInstance:SetAttribute(attributeName, attribute)
				end
			elseif key == "Tags" then
				for _, tag in value do
					newInstance:AddTag(tag)
				end
			else
				(newInstance :: any)[key] = value
			end
		end
	end
	if parent then
		newInstance.Parent = parent
	end

	return newInstance
end

--- Creates and returns an Event.
--- @return Event -- The new Event.
function New.Event()
	return Signal.new()
end

--- Creates and returns a QueuedEvent.
--- @param nameHint? -- The name of the QueuedEvent for debugging.
--- @return QueuedEvent -- The new QueuedEvent.
function New.QueuedEvent(nameHint: string?): Event
	local callbacks: {Callback} = {}
	local waiting: {Callback | thread} = {}
	local queueCount = 0
	local queuedEventCoroutines: {thread} = {}

	local function resumeQueuedEventCoroutines()
		for _, co in queuedEventCoroutines do
			task.spawn(co)
		end
		table.clear(queuedEventCoroutines)
		queueCount = 0
	end

	local actions: Event = {
		Fire = function(_, ...: any?)
			if not next(callbacks) and not next(waiting) then
				if queueCount >= QUEUED_EVENT_QUEUE_SIZE then
					task.spawn(error, `QueuedEvent invocation queue exhausted{if nameHint then ` for '{nameHint}'` else ""}; did you forget to connect to it?`, 0)
				end
				queueCount += 1
				table.insert(queuedEventCoroutines, coroutine.running())
				coroutine.yield()
			end
			for _, callback in callbacks do
				task.spawn(callback, ...)
			end
			local currentlyWaiting = table.clone(waiting)
			table.clear(waiting)
			for _, callback in currentlyWaiting do
				task.spawn(callback, ...)
			end
		end;

		Connect = function(_, callback: Callback)
			resumeQueuedEventCoroutines()
			table.insert(callbacks, callback)
			return {Disconnect = function()
				table.remove(callbacks, table.find(callbacks, callback))
			end}
		end;

		Once = function(_, callback: Callback)
			resumeQueuedEventCoroutines()
			table.insert(waiting, callback)
			return {Disconnect = function()
				table.remove(waiting, table.find(waiting, callback))
			end}
		end;

		Wait = function(_, timeout: number?)
			resumeQueuedEventCoroutines()
			local co = coroutine.running()
			table.insert(waiting, co)
			if timeout then
				task.delay(timeout, function()
					local index = table.find(waiting, co)
					if index then
						table.remove(waiting, index)
					end
					task.spawn(co)
				end)
			end
			return coroutine.yield()
		end;

		DisconnectAll = function(_)
			table.clear(callbacks)
			for _, callback in waiting do
				if type(callback) == "thread" then
					task.cancel(callback)
				end
			end
			table.clear(waiting)
		end;
	}

	table.freeze(actions)

	return actions
end

--- Creates and returns a TrackedVariable.
--- @param variable -- The initial value of the TrackedVariable.
--- @return QueuedEvent -- The new TrackedVariable.
function New.TrackedVariable(variable: any): TrackedVariable
	local callbacks: {Callback} = {}
	local waiting: {Callback | thread} = {}

	local actions: TrackedVariable = {
		Get = function(_): any
			return variable
		end;

		Set = function(_, value: any)
			if variable ~= value then
				variable = value
				for _, callback in callbacks do
					task.spawn(callback, value)
				end
				local currentlyWaiting = table.clone(waiting)
				table.clear(waiting)
				for _, callback in currentlyWaiting do
					task.spawn(callback, value)
				end
			end
		end;

		Connect = function(_, callback: Callback)
			table.insert(callbacks, callback)
			return {Disconnect = function()
				table.remove(callbacks, table.find(callbacks, callback))
			end}
		end;

		Once = function(_, callback: Callback)
			table.insert(waiting, callback)
			return {Disconnect = function()
				table.remove(waiting, table.find(waiting, callback))
			end}
		end;

		Wait = function(_, timeout: number?)
			local co = coroutine.running()
			table.insert(waiting, co)
			if timeout then
				task.delay(timeout, function()
					local index = table.find(waiting, co)
					if index then
						table.remove(waiting, index)
					end
					task.spawn(co)
				end)
			end
			return coroutine.yield()
		end;

		DisconnectAll = function(_)
			table.clear(callbacks)
			for _, callback in waiting do
				if type(callback) == "thread" then
					task.cancel(callback)
				end
			end
			table.clear(waiting)
		end;
	}

	table.freeze(actions)

	return actions
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

return New
