#!/usr/bin/luajit

this = require("kroks.ubus.generic")

function this.utility.ping(input)
	input = input or {}
	input.count = tonumber(input.count) or 5
	input.deadline = tonumber(input.deadline) or 1000
	input.packetsize = tonumber(input.packetsize) or 56
	input.ttl = tonumber(input.ttl) or 64
	input.interface = tostring(input.interface or "eth0.2")
	input.destination = tostring(input.destination or "8.8.8.8")

	local execute = {this.utility.execute({
			command = string.format("/bin/busybox ping -q -c %s -A -w %s -s %s -t %s -I %s %s",
						input.count, math.ceil(input.deadline / 1000), input.packetsize, input.ttl, input.interface, input.destination)
		})
	}

	if execute[2] then
		this.log.error("utility.ping", "execute", execute[2])
		return false, execute[2]
	end

	execute = execute[1]

	local output = {
		condition = {
			reliability = 0,
			status = execute.result
		},
		packet = {
			transmitted = false,
			successfully = false,
			unsuccessfully = false
		},
		rtt = {
			min = false,
			avg = false,
			max = false
		}
	}

	output.packet.transmitted, output.packet.successfully = execute.output:match("(%d+) packets transmitted, (%d+) packets received")

	if output.packet.transmitted and output.packet.successfully then
		output.packet.transmitted = tonumber(output.packet.transmitted) or 0
		output.packet.successfully = tonumber(output.packet.successfully) or 0
		output.packet.unsuccessfully = output.packet.transmitted - output.packet.successfully
		output.condition.reliability = math.ceil((output.packet.successfully * 100) / output.packet.transmitted)
	else
		output.condition.status = 2
		output.packet.transmitted = false
		output.packet.successfully = false
	end

	if output.condition.reliability > 0 then
		output.rtt.min, output.rtt.avg, output.rtt.max = execute.output:match("min/avg/max = ([%d%.]+)/([%d%.]+)/([%d%.]+) ms")

		output.rtt.min = tonumber(output.rtt.min) or -1
		output.rtt.avg = tonumber(output.rtt.avg) or -1
		output.rtt.max = tonumber(output.rtt.max) or -1
	end

	return output
end


this.config = {}
this.config.storage = {}

function this.config.import(input)
	input = input or {}

	if not (this.require.uci) then
		this.log.fatal("ping.config import", "check require", "error")
		error("check require")
	else
		this.config.storage = {}

		input.uciConfig = input.uciConfig or "kroks-util-ping"
		input.uciFilePath = input.uciFilePath or "/etc/config"
		input.uciStatePath = input.uciStatePath or "/var/state"
		input.uciCursor = this.require.uci.cursor(input.uciFilePath, input.uciStatePath)

		local function importKeywords (sectionType, keywords)
			local storage = this.config.storage
			storage[sectionType] = {}

			input.uciCursor:foreach(input.uciConfig, sectionType, function (section)
				local sectionName = section[".name"]
				storage[sectionType][sectionName] = {}

				for keywordIndex, keywordName in pairs(keywords) do
					storage[sectionType][sectionName][keywordName] = section[keywordName]
				end
			end)
		end

		importKeywords("ping", {"count", "deadline", "packetsize", "ttl"})
		importKeywords("interface", {"host"})

		this.log.debug("ping.config import", "import config", "ok")
	end
end

this.config.import()

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
			host = {}
		}

		local interfaceObject = this.service.storage[interfaceName]

		for hostIndex, hostAddress in pairs(interfaceConfigObject.host or {}) do
			interfaceObject.host[hostAddress] = {
				condition = {},

				config = {
					host = hostAddress,
					method = "ping"
				}
			}

			local cursor = interfaceObject.host[hostAddress]

			for fieldName, fieldObject in pairs(this.config.storage.ping.ubus) do
				cursor.config[fieldName] = fieldObject
			end
		end
	end
end

function this.service.process()
	for interfaceName, interfaceObject in pairs(this.service.storage or {}) do
		interfaceObject.condition = interfaceObject.condition or {}

		if not (interfaceObject.condition.device) then
			interfaceObject.condition.updated = true

			local ubusNetworkInterfaceStatus = this.ubus.connector:call("network.interface", "status", {interface = interfaceName})

			if ubusNetworkInterfaceStatus then
				interfaceObject.condition.device = ubusNetworkInterfaceStatus.l3_device
			end

			if not(interfaceObject.condition.device) then
				for hostName, hostObject in pairs(interfaceObject.host or {}) do
					for structName, structObject in pairs(hostObject.storage or {}) do
						for fieldName, fieldValue in pairs(structObject or {}) do
							structObject[fieldName] = false
						end
					end
				end
			end
		else
			if not (interfaceObject.condition.updated) then
				local updated = false

				for hostName, hostObject in pairs(interfaceObject.host or {}) do
					if not (hostObject.condition.updated) then
						hostObject.condition.updated = true
						updated = true

						local method = this.utility[hostObject.config.method]
						local methodInput = {}

						for fieldName, fieldObject in pairs(hostObject.config) do
							methodInput[fieldName] = fieldObject
						end

						methodInput.interface = interfaceObject.condition.device
						methodInput.destination = hostObject.config.host

						local methodResult = {method(methodInput)}

						if methodResult[1] then
							hostObject.storage = methodResult[1]
						end

						if hostObject.storage then
							if hostObject.storage.condition.status == 2 then
								interfaceObject.condition.device = false
							end
						end

						break
					end
				end

				if not (updated) then
					interfaceObject.condition.updated = true

					for hostName, hostObject in pairs(interfaceObject.host or {}) do
						hostObject.condition.updated = false
					end
				end
			end
		end
	end
end

this.service.import()

this.uloop = {
	["process"] = uloop.timer(function()
		this.service.process()

		for interfaceName, interfaceObject in pairs(this.service.storage or {}) do
			if interfaceObject.condition.updated then
				this.uloop["review"]:set(100)
				break
			end
		end

		this.uloop["process"]:set(1000)
	end, 1000),

	["review"] = uloop.timer(function()
		local eventObject = false

		for interfaceName, interfaceObject in pairs(this.service.storage or {}) do
			if interfaceObject.condition.updated then
				interfaceObject.condition.updated = false

				local storage = {
					condition = {
						reliability = false,
						status = false,
						trigger = {}
					},
					packet = {
						transmitted = false,
						successfully = false,
						unsuccessfully = false
					},
					rtt = {
						min = false,
						avg = false,
						max = false
					}
				}

				for structName, structObject in pairs(storage) do
					for fieldName, fieldValue in pairs(structObject) do
						local count = 0

						for hostName, hostObject in pairs(interfaceObject.host or {}) do
							local cursor = (((hostObject.storage or {})[structName] or {})[fieldName])

							if type(cursor) == "number" then
								count = count + 1

								structObject[fieldName] = (count == 1 and 0 or structObject[fieldName]) + cursor
							end
						end

						if count > 0 then
							structObject[fieldName] = math.floor(structObject[fieldName] / count)
						end
					end
				end

				storage.condition.status = storage.condition.status or 2

				local trigger = false

				if interfaceObject.storage then
					if interfaceObject.storage.condition.status ~= storage.condition.status then
						storage.condition.trigger["condition.status"] = true
						trigger = true
					end

					if interfaceObject.storage.condition.reliability ~= storage.condition.reliability then
						storage.condition.trigger["condition.reliability"] = true
						trigger = true
					end

					if interfaceObject.storage.rtt.avg ~= storage.rtt.avg then
						storage.condition.trigger["rtt.avg"] = true
						trigger = true
					end
				else
					storage.condition.trigger["condition.detect"] = true
					trigger = true
				end

				if trigger then
					eventObject = eventObject or {}
					eventObject[interfaceName] = {
						storage = storage,
						config = interfaceObject.config,
						condition = interfaceObject.condition
					}
				end

				interfaceObject.storage = storage
			end
		end

		if eventObject then
			this.ubus.connector:send("kroks.util.ping", eventObject)
		end
	end)
}

this.require.uloop.init()

this.ubus.handler = {
	["kroks.util.ping"] = {
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
		},

		--[[
		["request"] = {
			function (request, message)
				local pingInput = {}

				pingInput.interface, pingInput.destination = message.interface, message.destination

				local pingOutput = this.utility.ping(pingInput)

				this.ubus.connector:reply(request, pingOutput)
			end, { interface = ubus.STRING, destination = ubus.STRING }
		}
		]]
	}
}

this.ubus.registration()

this.require.uloop.run()