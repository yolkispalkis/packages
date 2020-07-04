local function generateChangedList(input)
	input.supported = input.supported or {}
	input.current = input.current or {}
	input.change = input.change or {}

	local function table_index2name_space(input)
		local output = {}

		for index, name in pairs(input) do
			output[name] = true
		end

		return output
	end

	local function table_copy(input)
		local output = {}

		for index, name in pairs(input) do
			output[index] = name
		end

		return output
	end

	local output = {
		supported = table_index2name_space(input.supported),
		current = table_index2name_space(input.current),
		requested = table_copy(input.change),
		changed = false
	}

	for optionName in pairs(output.supported) do
		output.current[optionName] = output.current[optionName] == true

		if output.requested[optionName] == nil then
			if output.requested["*"] ~= nil then
				output.requested[optionName] = output.requested["*"]
			else
				output.requested[optionName] = output.current[optionName]
			end
		end

		if output.requested[optionName] ~= output.current[optionName] then
			output.changed = true
		end
	end

	return output
end


local ubus = ((this or {}).ubus or {})

ubus.handler = {
	["kroks.dev.modem"] = {
		["object"] = {
			function (request, message)
				message = message or {}
				message.folder = tostring(message.folder or "/")

				local object = this.device.storage
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
				this.device.import()
				this.device.upstream.update()
				this.device.downstream.update()
				this.ubus.registration()
			end, { }
		}
	}
}

for modemName, modemObject in pairs(this.device.storage) do
	local cursorName = string.format("kroks.dev.modem.%s", modemName)
	this.ubus.handler[cursorName] = {}
	local cursorObject = this.ubus.handler[cursorName]

	cursorObject["object"] = {
		function (request, message)
			message = message or {}
			message.folder = tostring(message.folder or "/")

			local object = modemObject
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


	cursorObject["capabilities"] = {
		function (request, message)
			local options = generateChangedList({
				supported = (((modemObject or {}).storage or {}).generic or {})["supported-capabilities"],
				current = (((modemObject or {}).storage or {}).generic or {})["current-capabilities"],
				change = message
			})

			if not (options.changed) then
				this.ubus.connector:reply(request, options.current)
				return true
			end

			local mmcli_request = {}
			for name, value in pairs(options.requested) do
				if name == "*" then
					options.requested[name] = nil
					value = false
				end

				if value then
					table.insert(mmcli_request, name)
				end
			end
			mmcli_request = table.concat(mmcli_request, ", "):gsub(", ", "|")

			local execute = {this.utility.execute({command = string.format("/usr/bin/mmcli -m '%s' --set-current-capabilities='%s'", modemObject.config.device, mmcli_request)})}

			if execute[1] and execute[1].result == 0 then
				(((modemObject or {}).storage or {}).generic or {})["current-bands"] = {}

				for bandIndex, bandName in pairs((((modemObject or {}).storage or {}).generic or {})["supported-capabilities"] or {}) do
					if options.requested[bandName] then
						table.insert((((modemObject or {}).storage or {}).generic or {})["current-capabilities"], bandName)
					end
				end

				this.ubus.connector:reply(request, options.requested)
				return true
			else
				options.current[".error"] = execute[1].output or "no message"
				this.ubus.connector:reply(request, options.current)
				return false, options.current[".error"]
			end
		end, {}
	}

	cursorObject["modes"] = {
		function (request, message)
			local options = generateChangedList({
				supported = (((modemObject or {}).storage or {}).generic or {})["supported-modes"],
				current = {(((modemObject or {}).storage or {}).generic or {})["current-modes"]},
				change = message
			})

			if not (options.changed) then
				this.ubus.connector:reply(request, options.current)
				return true
			end

			local mmcli_request = {}
			for name, value in pairs(message or {}) do
				if value then
					table.insert(mmcli_request, name)
					break
				end
			end
			mmcli_request = mmcli_request or {(((modemObject or {}).storage or {}).generic or {})["current-modes"]}

			if not (mmcli_request and mmcli_request[1] and #mmcli_request[1] > 5) then
				options.current[".error"] = "no current"
				this.ubus.connector:reply(request, options.current)
				return false, options.current[".error"]
			end

			mmcli_request.allowed, mmcli_request.preferred = mmcli_request[1]:match("^allowed: ([^;]+); preferred: (.*)$")
			mmcli_request.allowed = mmcli_request.allowed:gsub(", ", "|")
			mmcli_request.preferred = mmcli_request.preferred:gsub(", ", "|")

			local execute = {this.utility.execute({command = string.format("/usr/bin/mmcli -m '%s' --set-allowed-modes='%s' --set-preferred-mode='%s'", modemObject.config.device, mmcli_request.allowed, mmcli_request.preferred)})}

			if execute[1] and execute[1].result == 0 then
				(((modemObject or {}).storage or {}).generic or {})["current-modes"] = mmcli_request[1]

				local output = {}
				for name in pairs(options.supported) do
					options.requested[name] = mmcli_request[1] == name
				end

				this.ubus.connector:reply(request, options.requested)
				return true
			else
				options.current[".error"] = execute[1].output or "no message"
				this.ubus.connector:reply(request, options.current)
				return false, options.current[".error"]
			end
		end, {}
	}

	cursorObject["bands"] = {
		function (request, message)
			local options = generateChangedList({
				supported = (((modemObject or {}).storage or {}).generic or {})["supported-bands"],
				current = (((modemObject or {}).storage or {}).generic or {})["current-bands"],
				change = message
			})

			if not (options.changed) then
				this.ubus.connector:reply(request, options.current)
				return true
			end

			local mmcli_request = {}
			for name, value in pairs(options.requested) do
				if name == "*" then
					options.requested[name] = nil
					value = false
				end

				if value then
					table.insert(mmcli_request, name)
				end
			end
			mmcli_request = table.concat(mmcli_request, "|")

			local execute = {this.utility.execute({command = string.format("/usr/bin/mmcli -m '%s' --set-current-bands='%s'", modemObject.config.device, mmcli_request)})}

			if execute[1] and execute[1].result == 0 then
				(((modemObject or {}).storage or {}).generic or {})["current-bands"] = {}

				for bandIndex, bandName in pairs((((modemObject or {}).storage or {}).generic or {})["supported-bands"] or {}) do
					if options.requested[bandName] then
						table.insert((((modemObject or {}).storage or {}).generic or {})["current-bands"], bandName)
					end
				end

				this.ubus.connector:reply(request, options.requested)
				return true
			else
				options.current[".error"] = execute[1].output or "no message"
				this.ubus.connector:reply(request, options.current)
				return false, options.current[".error"]
			end
		end, {}
	}

	cursorObject["simcard"] = {
		function (request, message)
			local supported_simcard = {}
			for simcardName in pairs(modemObject.simcard) do
				table.insert(supported_simcard, simcardName)
			end

			local options = generateChangedList({
				supported = supported_simcard,
				current = {modemObject.condition.simcard},
				change = message
			})

			if not (options.changed) then
				this.ubus.connector:reply(request, options.current)
				return true
			end

			local mmcli_request = {}
			for index, name in pairs(supported_simcard) do
				if message[name] then
					table.insert(mmcli_request, name)
					break
				end
			end
			mmcli_request = mmcli_request and mmcli_request[1] or modemObject.condition.simcard

			modemObject.condition.simcard = mmcli_request
			this.device.downstream.update()

			if not (modemObject.condition[".simcard"] == mmcli_request) then
				options.current[".error"] = true
				this.ubus.connector:reply(request, options.current)
				return false, options.current[".error"]
			end

			for simcardName in pairs(modemObject.simcard) do
				options.current[simcardName] = simcardName == mmcli_request
			end

			this.ubus.connector:reply(request, options.current)
		end, { }
	}

	cursorObject["power"] = {
		function (request, message)
			local supported_power = {"off", "on"}

			local options = generateChangedList({
				supported = supported_power,
				current = {modemObject.condition.powerGpio == 1 and "on" or "off"},
				change = message
			})

			if not (options.changed) then
				this.ubus.connector:reply(request, options.current)
				return true
			end

			local device_request = {}
			for index, name in pairs(supported_power) do
				if message[name] then
					table.insert(device_request, name)
					break
				end
			end
			device_request = device_request and device_request[1] or (modemObject.condition.powerGpio == 1 and "on" or "off")

			modemObject.condition.powerGpio = device_request == "on" and 1 or 0
			this.device.downstream.update()

			if not (modemObject.condition[".powerGpio"] == (device_request == "on" and 1 or 0)) then
				options.current[".error"] = true
				this.ubus.connector:reply(request, options.current)
				return false, options.current[".error"]
			end

			for powerIndex, powerName in pairs(supported_power) do
				options.current[powerName] = powerName == device_request
			end

			this.ubus.connector:reply(request, options.current)
		end, { }
	}


	for simcardName, simcardObject in pairs(modemObject.simcard) do
		local cursorName = string.format("kroks.dev.modem.%s.simcard.%s", modemName, simcardName)
		this.ubus.handler[cursorName] = {}
		local cursorObject = this.ubus.handler[cursorName]

		cursorObject["object"] = {
			function (request, message)
				message = message or {}
				message.folder = tostring(message.folder or "/")

				local object = simcardObject
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
	end

	local cursorName = string.format("kroks.dev.modem.%s.simcard", modemName)
	this.ubus.handler[cursorName] = {}
	local cursorObject = this.ubus.handler[cursorName]

	for methodIndex, methodName in pairs({"object"}) do
		local cursorLink = string.format("kroks.dev.modem.%s.simcard.%s", modemName, modemObject.condition.simcard)

		cursorObject[methodName] = {
			function (request, message)
				local cursorLink = string.format("kroks.dev.modem.%s.simcard.%s", modemName, modemObject.condition.simcard)

				message = message or {}
				message.folder = tostring(message.folder or "/")

				this.ubus.handler[cursorLink][methodName][1](request, message)
			end, {}
		}
	end


	local cursorName = string.format("kroks.dev.modem.%s.sms", modemName)
	this.ubus.handler[cursorName] = {}
	local cursorObject = this.ubus.handler[cursorName]

	cursorObject["object"] = {
		function (request, message)
			message = message or {}
			message.folder = tostring(message.folder or "/")

			local object = {}

			for simcardName, simcardObject in pairs(modemObject.simcard or {}) do
				if simcardObject.sms then
					object[simcardName] = simcardObject.sms
				end
			end

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

	cursorObject["send"] = {
		function (request, message)
			message = message or {}

			local output = {}

			if not (message.number) then
				this.ubus.connector:reply(request, {
					[".error"] = "not found phone number"
				})
				return false
			end

			if not (message.text) then
				this.ubus.connector:reply(request, {
					[".error"] = "not found text message"
				})
				return false
			end

			local simcardNameCurrent = modemObject.condition.simcard or "simcardY"
			local simcardObjectCurrent = modemObject.simcard[simcardNameCurrent]

			if not (simcardObjectCurrent) then
				this.ubus.connector:reply(request, {
					[".error"] = "not found current simcard"
				})
				return false
			end


			local smsArray = ((simcardObjectCurrent.sms or {})[message.number] or {})
			local smsArray_size = #smsArray


			local execute = {this.utility.execute({command = string.format(
				[[/usr/bin/mmcli -m '%s' --messaging-create-sms='number="%s", text="%s"']],
					modemObject.config.device,
					message.number,
					message.text
				)})
			}

			if execute[2] or execute[1].result ~= 0 then
				this.ubus.connector:reply(request, {
					[".error"] = execute[2] or execute[1].output or "no message"
				})
				return false
			else
				this.ubus.connector:reply(request, {
					["folder"] = string.format("/%s/%s/%s", simcardNameCurrent, message.number, smsArray_size + 1)
				})
			end

		end, {
			number = this.require.ubus.STRING,
			text = this.require.ubus.STRING,
			smsc = this.require.ubus.STRING,
			validity = this.require.ubus.STRING,
			class = this.require.ubus.INT32,
			["delivery-report-request"] = this.require.ubus.BOOLEAN,
			storage = this.require.ubus.STRING
		}
	}
end


ubus.listener["kroks.dev.modem:mm-listener"] = function (message)
	this.device.event.hook(message)
	this.ubus.connector:send("kroks.dev.modem", this.device.storage)
end


for modemName, modemObject in pairs(this.device.storage or {}) do
	modemObject["kroks.util.ping"] = modemObject["kroks.util.ping"] or {}
	if not (modemObject["kroks.util.ping"].storage) then
		modemObject["kroks.util.ping"] = this.ubus.connector:call("kroks.util.ping", "object", {folder = string.format("/%s/", modemName)}) or {}
		modemObject["kroks.util.ping"] = modemObject["kroks.util.ping"].storage or {}
	end
end

ubus.listener["kroks.util.ping"] = function (message)
	for modemName, modemObject in pairs(this.device.storage or {}) do
		local pingObject = message[modemName]

		if pingObject and pingObject.storage then
			modemObject["kroks.util.ping"] = pingObject.storage

			modemObject["kroks.util.ping"].condition = modemObject["kroks.util.ping"].condition or {}
			modemObject["kroks.util.ping"].condition.status = modemObject["kroks.util.ping"].condition.status or 3
		end
	end
end


return ubus
