--!strict

--[[
	TITLE: ROLLBAR ERROR HANDLING SERVICE MANAGER

	DESC: Manages communication between game place and Rollbar web api, allows for easy configuration and
		  customisation of error logging such as automated output logging for both client and server and
		  manual logging functions for both client and server.
	
	AUTHOR: RoyallyFlushed
	
	CREATION DATE: 02/27/2022
	MODIFIED DATE: 03/09/2022
--]]


--[[SERVICES]]--
local ReplicatedStorage = game.ReplicatedStorage
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

type Array<T> 		= { [number]: T }
type Dictionary 	= { [string]: any }
type Enumeration 	= { [string]: number }

type schema = {
	DEBUG_MODE					:		boolean,
	IgnoreStudio				: 		boolean,
	ManualMode					: 		boolean,
	IgnoreDuplicates			: 		boolean,
	GeneraliseClientErrors		: 		boolean,
	_initialised				: 		boolean,
	
	DefaultEnvironment			: 		string,
	
	Connection					: 		RemoteEvent,
	
	NextCallMetadata			: 		boolean | Dictionary,
	
	DefaultMetadata				: 		Dictionary,
	
	Auth						: 		Dictionary,
	
	ConnectionRequest			: 		Enumeration,
	
	Level						: 		Enumeration,
	
	RollbarLevel				: 		Array<string>,
	
	Total						:		Enumeration,
	
	Logs						: 		Array<string>,
	
	Url							: 		string,
	
	SendEvent: (
		manualCall				: 		boolean,
		level					: 		number, 
		message					: 		string
	) -> ()?,
	
	Configure: (
								  		schema, 
		metadata   				: 		Dictionary
	) -> ()?,
	
	GetLogTotal: ((
								  		schema,
		level					: 		number
	) -> (number?))?,
	
	LogCritical: (
								  		schema,
		message					: 		string
	) -> ()?,
	
	LogError: (
								  		schema,
		message					: 		string
	) -> ()?,
	
	LogWarning: (
								  		schema,
		message					: 		string
	) -> ()?,
	
	LogInfo: (
								  		schema,
		message					: 		string
	) -> ()?,
	
	LogDebug: (
								  		schema,
		message					: 		string
	) -> ()?,
	
	init: () -> ()?,
	
	_funcCount					:		number
}


local module: schema = {
	
	--[[SETTINGS]]--
	IgnoreStudio = false,
	ManualMode = false,
	IgnoreDuplicates = false,
	GeneraliseClientErrors = false,
	NextCallMetadata = false,
	_initialised = false,
	Connection = ReplicatedStorage.SendRollbarEvent,
	DEBUG_MODE = true,
	
	DefaultEnvironment = tostring(game.PlaceId),
	DefaultMetadata = {
		["build"] = game.PlaceVersion,
		["server-id"] = game.JobId
	},
	
	Auth = {
		ServerToken = "dc90a86abd614555b6de84f07c8640d4",
		ClientToken = "7df77ad7c2d34e379dc8eea507ce773e"
	},
	
	--[[INTERNAL PROPERTIES]]--
	ConnectionRequest = {
		SETMETADATA = 0,
		LOGEVENT = 1,
		LOGTOTAL = 2
	},
	Level = {
		DEBUG    = 0,
		INFO     = 1,
		WARNING  = 2,
		ERROR    = 3,
		CRITICAL = 4
	},
	RollbarLevel = {
		"debug",
		"info",
		"warning",
		"error",
		"critical"
	},
	Total = {
		DEBUG    = 0,
		INFO     = 0,
		WARNING  = 0,
		ERROR    = 0,
		CRITICAL = 0
	},
	
	Url = "https://api.rollbar.com/api/1/item/",
	Logs = {},
	
	SendEvent 	 = nil,
	GetLogTotal  = nil,
	Configure 	 = nil,
	LogCritical  = nil,
	LogError     = nil,
	LogWarning   = nil,
	LogInfo      = nil,
	LogDebug     = nil,
	init         = nil,
	_funcCount = 9
	
}


-- Initialise module with functions
assert(module._funcCount == 9, "Exhaustive handling of module functions in initialisation stage, initialise any module functions that need to be accessed")
module.SendEvent	= _SendEvent
module.GetLogTotal 	= _GetLogTotal
module.Configure 	= _Configure
module.LogCritical 	= _LogCritical
module.LogError 	= _LogError
module.LogWarning 	= _LogWarning
module.LogInfo 		= _LogInfo
module.LogDebug 	= _LogDebug
module.init 		= _init


-- Soft assertion function to warn instead of error
local function softAssert(cond: boolean, msg: string?): ()
	if not cond then
		warn(msg or "Assertion failed!")
	end
end

-- Function to find values in tables
local function find(t: any, q: any): any?
	for k,v in next, t do
		if v == q then
			return k
		end
	end
	return nil
end

-- Wrapper function to retry requests
local function try(maxTries: number, func: ()->(boolean, any)): (boolean, any)
	local attempts: number = 0
	local success: boolean, result: any
	
	repeat
		success, result = pcall(func)
		attempts += 1
	until success or attempts >= maxTries
	
	return success, result
end

-- Handles the actual http request
local function sendRequest(timestamp: number, messageType: string, environment: string, metadata: Dictionary, message: string): ()
	-- Send request to rollbar
	
	if module.DEBUG_MODE then
		print("SENDING ROLLBAR EVENT!")
		return
	end
	
	local success, result = try(3, function()
		return game:service'HttpService':RequestAsync({
			Url = module.Url,
			Method = "POST",
			Headers = {
				['Content-Type'] = "application/json",
				['X-Rollbar-Access-Token'] = module.Auth.ServerToken
			},
			Body = game:service'HttpService':JSONEncode({
				['data'] = {
					['environment'] = environment,
					['body'] = {
						['telemetry'] = {
							{
								['level'] = messageType,
								['type'] = "error",
								['source'] = "server",
								['timestamp_ms'] = timestamp * 1000,
								['body'] = {
									['subtype'] = "xhr",
									['message'] = message,
								}
							}
						},
						['message'] = {
							['body'] = message
						}
					},
					['level'] = messageType,
					['timestamp'] = timestamp,
					['Custom'] = metadata
				}
			})
		})
	end)
	
	-- Handle success pcall request (no network failure)
	if success then
		local response = result
		
		-- Handle failure of Rollbar request (Rollbar API failure)
		if not response.Success then
			warn(("$ Rollbar request contained %d errors!\n-->Response: %s\n-->Status Code: %d"):format(
				response.Body.err,
				response.Body.message,
				response.StatusCode
			))
		end
	else
		warn(("$ Network error occured when trying to send request to Rollbar\n %s"):format(result))
	end
end

-- Handle logic for sending events to Rollbar
function _SendEvent(manualCall: boolean, level: number, message: string): ()
	
	-- If IgnoreStudio flag is set, drop request entirely
	if RunService:IsStudio() and module.IgnoreStudio then
		warn("$ Rollbar is disabled in Studio! Request dropped!")
		return
	end
	
	-- Stringify message argument and define variables
	message = tostring(message)
	local metadata: Dictionary = module.DefaultMetadata
	local environment: string = module.DefaultEnvironment
	
	-- Check for manual metadata and apply
	if manualCall and module.NextCallMetadata then
		-- Check to see if manual metadata has an Environment datum, if so, separate from metadata
		local nextCallMetadata: Dictionary = module.NextCallMetadata :: Dictionary
		if nextCallMetadata.Environment then
			environment = nextCallMetadata.Environment
			metadata = {}
			
			-- Reset the metadata table to remove the Environment datum
			for i,v in next, module.NextCallMetadata :: Dictionary do
				if i ~= "Environment" then
					metadata[i] = v
				end
			end
		else
			-- No Environment datum so just set the metadata
			metadata = module.NextCallMetadata :: {}
		end
	end
	
	-- Check for duplicate error
	if module.IgnoreDuplicates and table.find(module.Logs, message :: string) then
		return
	end
	
	-- Check to see if should generalise client errors
	if module.GeneraliseClientErrors then
		message = (string.gsub(message :: string, "Players.%w+.", "Players.<PLAYER>."))
	end
	
	-- Add to log cache
	table.insert(module.Logs, message :: string)
	-- Increment log type counter
	module.Total[find(module.Level, level) :: string] += 1
	-- Send request
	sendRequest(
		os.time(),
		module.RollbarLevel[level],
		environment,
		metadata,
		message :: string
	)
	
	-- Reset nextCallMetadata for subsequent calls
	module.NextCallMetadata = false
end



-- Handles log service event fires and sends server log
local function clientLogServiceHandler(message: string, messageType: number): ()
	module.Connection:FireServer(module.ConnectionRequest.LOGEVENT, {
		message = message, 
		messageType = messageType, 
		manualCall = false
	})
end

-- Handles log service event fires on the server side
local function serverLogServiceHandler(message: string, messageType: number): ()
	assert(module.SendEvent ~= nil, "This could be a bug with function assigning")
	module.SendEvent(false, messageType, message)
end

-- Handles all server responses over connection on client
local function connectionClientHandler(level: number, total: number): ()
	if RunService:IsClient() then
		if level and total then
			module.Total[find(module.Level, level) :: string] = total
		end
	end
end

-- Handles all client requests over connection on server
local function connectionServerHandler(player: Player, requestType: number, data: Dictionary): ()
	assert(requestType ~= nil, "$ requestType is required!")
	assert(data ~= nil, "$ data is required!")
	assert(data ~= {}, "$ data must contain data!")
	
	if requestType == module.ConnectionRequest.SETMETADATA and data.metadata then
		module.NextCallMetadata = data.metadata
	elseif requestType == module.ConnectionRequest.LOGEVENT and data.message and data.messageType and data.manualCall then
		assert(module.SendEvent ~= nil, "This could be a bug with function assigning")
		module.SendEvent(data.manualCall, data.messageType, data.message :: string)
	elseif requestType == module.ConnectionRequest.LOGTOTAL and data.level then
		module.Connection:FireClient(player, data.level, module.Total[find(module.Level, data.level) :: string])
	end
end


-- Sends Client current total for log level
function _GetLogTotal(self: schema, level: number): number?
	assert(module.Total[find(module.Level, level) :: string], "$ level must be a listed level!")
	
	if RunService:IsClient() then
		module.Connection:FireServer(module.ConnectionRequest.LOGTOTAL, {level = level})
		return nil
	else
		return module.Total[find(module.Level, level) :: string]
	end
end

-- Configure the log metadata for the next manual log call
function _Configure(self: schema, metadata: {}): ()
	assert(metadata ~= nil, "$ metadata is required!")
	assert(metadata ~= {}, "$ metadata must contain data!")
	
	-- If client, then ask server to set
	if RunService:IsClient() then
		module.Connection:FireServer(module.ConnectionRequest.SETMETADATA, {metadata = metadata})
	else
		module.NextCallMetadata = metadata
	end
end

-- Manually send a critical log to Rollbar
function _LogCritical(self: schema, message: string): ()
	-- If client, then ask server to set
	if RunService:IsClient() then
		module.Connection:FireServer(module.ConnectionRequest.LOGEVENT, {
			message = message, 
			messageType = module.Level.CRITICAL
		})
	else
		assert(module.SendEvent ~= nil, "This could be a bug with function assigning")
		module.SendEvent(true, module.Level.CRITICAL, message)
	end
end

-- Manually send an error log to Rollbar
function _LogError(self: schema, message: string): ()
	-- If client, then ask server to set
	if RunService:IsClient() then
		module.Connection:FireServer(module.ConnectionRequest.LOGEVENT, {
			message = message, 
			messageType = module.Level.ERROR
		})
	else
		assert(module.SendEvent ~= nil, "This could be a bug with function assigning")
		module.SendEvent(true, module.Level.ERROR, message)
	end
end

-- Manually send a warning log to Rollbar
function _LogWarning(self: schema, message: string): ()
	-- If client, then ask server to set
	if RunService:IsClient() then
		module.Connection:FireServer(module.ConnectionRequest.LOGEVENT, {
			message = message, 
			messageType = module.Level.WARNING
		})
	else
		assert(module.SendEvent ~= nil, "This could be a bug with function assigning")
		module.SendEvent(true, module.Level.WARNING, message)
	end
end

-- Manually send an info log to Rollbar
function _LogInfo(self: schema, message: string): ()
	-- If client, then ask server to set
	if RunService:IsClient() then
		module.Connection:FireServer(module.ConnectionRequest.LOGEVENT, {
			message = message, 
			messageType = module.Level.INFO
		})
	else
		assert(module.SendEvent ~= nil, "This could be a bug with function assigning")
		module.SendEvent(true, module.Level.INFO, message)
	end
end

-- Manually send a debug log to Rollbar
function _LogDebug(self: schema, message: string): ()
	-- If client, then ask server to set
	if RunService:IsClient() then
		module.Connection:FireServer(module.ConnectionRequest.LOGEVENT, {
			message = message, 
			messageType = module.Level.DEBUG
		})
	else
		assert(module.SendEvent ~= nil, "This could be a bug with function assigning")
		module.SendEvent(true, module.Level.DEBUG, message)
	end
end

-- Initiation for client and server
function _init(): ()
	softAssert(not module._initialised, "$ Rollbar has already been initialised in this environment!")
	
	-- Initiate logging services for output on client and server
	if RunService:IsStudio() and module.IgnoreStudio then
		warn("$ Rollbar is disabled in Studio!")
	elseif RunService:IsServer() then
		module.Connection.OnServerEvent:Connect(connectionServerHandler)
		
		if not module.ManualMode then
			LogService.MessageOut:Connect(serverLogServiceHandler)
		end
	elseif RunService:IsClient() then
		module.Connection.OnClientEvent:Connect(connectionClientHandler)
		
		if not module.ManualMode then
			LogService.MessageOut:Connect(clientLogServiceHandler)
		end
	end
	
	-- Set init flag to stop further initialisation calls
	module._initialised = true
end


--[[
	 TODO:
	 	- Test everything :(
--]]



return module
