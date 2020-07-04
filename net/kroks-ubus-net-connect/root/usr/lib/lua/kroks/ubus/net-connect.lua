#!/usr/bin/luajit

this = require("kroks.ubus.generic")

this.config = {}
this.config.storage = {}

function this.config.import(input)
	input = input or {}

	if not (this.require.uci) then
		this.log.fatal("connect.config import", "check require", "error")
		error("check require")
	else
		this.config.storage = {}
		input.uciFilePath = input.uciFilePath or "/etc/config"
		input.uciStatePath = input.uciStatePath or "/var/state"
		input.uciCursor = this.require.uci.cursor(input.uciFilePath, input.uciStatePath)

		this.config.storage.interface = {}

		input.uciCursor:foreach("firewall", "zone", function (section)
			if section.name == "wan" then
				for interfaceName in (section.network or ""):gmatch("([^%s]+)") do
					if input.uciCursor:get("kroks-util-ping", interfaceName) == "interface" then
						this.config.storage.interface[interfaceName] = {
							attemptInterval = 30,
							attemptCount = 5,
							sleepInterval = 120
						}

						local cursor = this.config.storage.interface[interfaceName]

						local network = input.uciCursor:get_all("network", interfaceName) or {}

						for fieldName, fieldObject in pairs(network) do
							cursor[fieldName] = fieldObject
						end

						cursor.force_link = input.uciCursor:get("kroks-util-ping", interfaceName, "host") and cursor.force_link or "0"
					end
				end
			end
		end)

		this.log.debug("connect.config import", "import config", "ok")
	end
end

this.config.import()


this.interface = {}


function this.interface.generic(input)
	input = input or {}

	input.interfaceName = input.interfaceName or "wan"

	if not (input.interfaceObject) then
		input.interfaceObject = this.service.storage[input.interfaceName]

		if not (input.interfaceObject) then
			return false, "not founded interface"
		end
	end

	input.method = input.method or {"up"}
	input.method = type(input.method) == "table" and input.method or {tostring(input.method)}

	for methodIndex, methodName in pairs(input.method) do
		this.ubus.connector:call("network", "reload", {})

		local call = {this.ubus.connector:call("network.interface", methodName, {interface = input.interfaceName})}

		os.execute("sleep 1")

		if call[2] then
			return false, call[2]
		end
	end

	return true
end

function this.interface.down(input)
	input = input or {}
	input.method = {"down", "remove"}

	return this.interface.generic(input)
end

function this.interface.up(input)
	input = input or {}

	this.interface.down(input)

	input.method = {"up"}

	return this.interface.generic(input)
end


this.service = {}
this.service.storage = {}

function this.service.import()
	if not (this.config.storage) then
		this.log.fatal("service:import", "loading config", "no exist")
		error("STOP")
	end

	this.service.storage = {}

	for interfaceName, interfaceConfigObject in pairs(this.config.storage.interface or {}) do
		this.service.storage[interfaceName] = {
			condition = {},
			config = interfaceConfigObject,
			storage = {}
		}

		local interfaceObject = this.service.storage[interfaceName]

		interfaceObject.condition.force_link = tonumber(interfaceConfigObject.force_link or 0)
		interfaceObject.condition.attemptCount = tonumber(interfaceConfigObject.attemptCount or 0)
		interfaceObject.condition.attemptInterval = tonumber(interfaceConfigObject.attemptInterval or 0)
		interfaceObject.condition.sleepInterval = tonumber(interfaceConfigObject.sleepInterval or 0)
	end
end

this.service.import()


this.uloop = {
	["process"] = uloop.timer(function()
		local eventObject = false

		for interfaceName, interfaceObject in pairs(this.service.storage or {}) do
			local storage = (interfaceObject.storage or {})
			interfaceObject.condition.trigger = {}
			local trigger = false

			local function interfaceSend(message)
				interfaceObject.condition.trigger[message] = true
				trigger = true
			end

			local function interfaceUp()
				this.interface.up({interfaceName = interfaceName, interfaceObject = interfaceObject})
				interfaceObject.condition.changed = true
				interfaceObject.condition.attemptInterval = 0
			end


			if not (storage.condition) then
				local ubusKroksUtilPing = this.ubus.connector:call("kroks.util.ping", "object", {folder = string.format("/%s/storage/", interfaceName)})

				if ubusKroksUtilPing then
					interfaceObject.storage = ubusKroksUtilPing

					interfaceSend("storage")
				else
					interfaceSend("condition.connect")
					interfaceUp()
				end
			else
				interfaceObject.storage.condition.status = interfaceObject.storage.condition.status or 3

				if interfaceObject.condition.attemptInterval >= interfaceObject.config.attemptInterval then
					if interfaceObject.condition.force_link == 1 then
						if interfaceObject.storage.condition.status ~= 0 then
							if interfaceObject.condition.attemptCount > 0 then
								interfaceObject.condition.changed = true
								interfaceObject.condition.attemptCount = interfaceObject.condition.attemptCount - 1

								interfaceSend("condition.attemptCount")
								interfaceUp()
							else
								if interfaceObject.condition.sleepInterval > 0 then
									if interfaceObject.condition.sleepInterval == interfaceObject.config.sleepInterval then
										interfaceSend("condition.sleepInterval")
									end

									interfaceObject.condition.changed = true
									interfaceObject.condition.sleepInterval = interfaceObject.condition.sleepInterval - 1
								else
									interfaceObject.condition.changed = true
								end
							end
						end
					end

					if interfaceObject.condition.changed then
						if interfaceObject.storage.condition.status == 0 or interfaceObject.condition.sleepInterval <= 0 then
							interfaceObject.condition.attemptCount = tonumber(interfaceObject.config.attemptCount or 0)
							interfaceObject.condition.attemptInterval = tonumber(interfaceObject.config.attemptInterval or 0)
							interfaceObject.condition.sleepInterval = tonumber(interfaceObject.config.sleepInterval or 0)

							interfaceSend("condition.reset")
						end

						interfaceObject.condition.changed = false
					end
				else
					interfaceObject.condition.changed = true
					interfaceObject.condition.attemptInterval = interfaceObject.condition.attemptInterval + 1
				end
			end


			if trigger then
				eventObject = eventObject or {}
				eventObject[interfaceName] = interfaceObject
			end
		end

		if eventObject then
			this.ubus.connector:send("kroks.net.connect", eventObject)
		end

		this.uloop["process"]:set(1000)
	end, 1000),

}

this.require.uloop.init()


this.ubus.handler = {
	["kroks.net.connect"] = {
		["object"] = {
			function (request, message)
				message = message or {}
				message.folder = tostring(message.folder or "/")

				local object = this.service.storage
				for jump in message.folder:gmatch("/([^/]+)") do
					object = (object[tonumber(jump) or -1] or object[jump] or {})
				end

				object = object or {}
				object = type(object) == "table" and object or {value = object}

				if #object ~= 0 then
					object = {array = object}
				end

				this.ubus.connector:reply(request, object)
			end, { folder = this.require.ubus.STRING }
		},

		["reload"] = {
			function (request, message)
				this.config.import()
				this.service.import()
			end, { }
		}
	}
}

for interfaceName, interfaceObject in pairs(this.service.storage or {}) do
	local cursorName = string.format("kroks.net.connect.%s", interfaceName)
	this.ubus.handler[cursorName] = {}
	local cursorObject = this.ubus.handler[cursorName]

	cursorObject["object"] = {
		function (request, message)
			message = message or {}
			message.folder = tostring(message.folder or "/")

			local object = interfaceObject
			for jump in message.folder:gmatch("/([^/]+)") do
				object = (object[tonumber(jump) or -1] or object[jump] or {})
			end

			object = object or {}
			object = type(object) == "table" and object or {value = object}

			if #object ~= 0 then
				object = {array = object}
			end

			this.ubus.connector:reply(request, object)
		end, { folder = this.require.ubus.STRING }
	}

	cursorObject["up"] = {
		function (request, message)
			local up = {this.interface.up({interfaceName = interfaceName, interfaceObject = interfaceObject})}

			if up[2] then
				this.ubus.connector:reply(request, {[".error"] = up[2]})
				return false
			end

			interfaceObject.condition.force_link = 1
			this.ubus.connector:reply(request, interfaceObject or {})
		end, {  }
	}

	cursorObject["down"] = {
		function (request, message)
			local down = {this.interface.down({interfaceName = interfaceName, interfaceObject = interfaceObject})}

			if down[2] then
				this.ubus.connector:reply(request, {[".error"] = down[2]})
				return false
			end

			interfaceObject.condition.force_link = 0
			this.ubus.connector:reply(request, interfaceObject or {})
		end, {  }
	}

	cursorObject["reset"] = {
		function (request, message)
			for fieldName, fieldObject in pairs(interfaceObject.condition) do
				if interfaceObject.config[fieldName] then
					interfaceObject.condition[fieldName] = tonumber(interfaceObject.config[fieldName])
				end
			end

			this.ubus.connector:reply(request, interfaceObject or {})
		end, {  }
	}
end



this.ubus.listener = {
	["kroks.util.ping"] = function (message)
		message = message or {}

		for interfaceName, interfaceObject in pairs(this.service.storage) do
			local pingObject = message[interfaceName]

			if pingObject then
				interfaceObject.storage = pingObject.storage

				interfaceObject.storage.condition = interfaceObject.storage.condition or {}
				interfaceObject.storage.condition.status = interfaceObject.storage.condition.status or 3
			end
		end
	end,
	["network.interface"] = function (message)
		message = message or {}
		local interfaceName = message.interface;
		local interfaceObject = this.service.storage[interfaceName];
	
		if not interfaceObject then
			return false;
		end
	
		if message.action == "ifdown" and interfaceObject.condition.attemptInterval > 0 then
			interfaceObject.condition.attemptInterval = 0;
		elseif message.action == "ifup" then
			interfaceObject.condition.attemptInterval = -tonumber(interfaceObject.config.attemptInterval or 0)
		end
	end
}

this.ubus.registration()

this.require.uloop.run()