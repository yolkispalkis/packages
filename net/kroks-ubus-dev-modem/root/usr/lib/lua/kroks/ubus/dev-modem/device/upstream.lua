local upstream = {}

upstream.modem = {}

function upstream.modem.condition(input)
	input.modemObject.condition = input.modemObject.condition or {}

	if input.modemObject.config.powerGpio then
		local execute = {this.utility.execute({command = string.format("cat '%s/value'", input.modemObject.config.powerGpio)})}

		if execute[2] or execute[1].result ~= 0 then
			this.log.error("dev-modem.device:upstream.modem.condition", "read gpio power", execute[2] or execute[1].output or "no message")
		else
			input.modemObject.condition[".powerGpio"] = tonumber(execute[1].output or "") or 0
		end
	else
		input.modemObject.condition[".powerGpio"] = 1
	end
	input.modemObject.condition.powerGpio = input.modemObject.condition[".powerGpio"]


	if not (input.modemObject.condition[".simcard"]) then
		input.modemObject.condition[".simcard"] = input.modemObject.config.simcard or "simcardY"
	end
	input.modemObject.condition.simcard = input.modemObject.condition[".simcard"]


	this.log.debug("dev-modem.device:upstream.modem.condition", "update", "ok")
end


function upstream.modem.storage(input)
	input.modemObject.storage = input.modemObject.storage or {}

	if not (input.modemObject.config.device) then
		this.log.warn("dev-modem.device:upstream.modem.storage", "check device path", "not exist")
		return false
	end

	if not (input.modemObject.condition[".powerGpio"] == 1) then
		this.log.warn("dev-modem.device:upstream.modem.storage", "check device power", "modem disabled")
		return false
	end


	local device = {
		general = this.utility.mmcli({command = string.format("-m '%s'", input.modemObject.config.device)}),
		signal = {},
		location = {}
	}

	if not (device.general.modem) then
		this.log.warn("dev-modem.device:upstream.modem.storage", "check modem data", "error")
	else
		os.execute(string.format("mmcli -m '%s' -e 1>/dev/null", input.modemObject.config.device))
		os.execute(string.format("mmcli -m '%s' --signal-setup 1 1>/dev/null", input.modemObject.config.device))
		--os.execute(string.format("mmcli -m '%s' --location-set-enable-signal 1>/dev/null", input.modemObject.config.device))

		device.signal = this.utility.mmcli({command = string.format("-m '%s' --signal-get", input.modemObject.config.device)})

		if input.modemObject.config.service_location == "1" then
			os.execute(string.format("mmcli -m '%s' --location-enable-gps-raw 1>/dev/null", input.modemObject.config.device))
			os.execute(string.format("mmcli -m '%s' --location-enable-gps-nmea 1>/dev/null", input.modemObject.config.device))

			os.execute(string.format("mmcli -m '%s' --location-set-gps-refresh-rate=10 1>/dev/null", input.modemObject.config.device))
		else
			os.execute(string.format("mmcli -m '%s' --location-disable-gps-raw 1>/dev/null", input.modemObject.config.device))
			os.execute(string.format("mmcli -m '%s' --location-disable-gps-nmea 1>/dev/null", input.modemObject.config.device))
		end

		device.location = this.utility.mmcli({command = string.format("-m '%s' --location-get", input.modemObject.config.device)})
	end

	for className, classObject in pairs(device) do
		for fieldName, fieldObject in pairs(classObject.modem or {}) do
			input.modemObject.storage[fieldName] = fieldObject
		end
	end

	this.log.debug("dev-modem.device:upstream.modem.storage", "update", "ok")
end


upstream.simcard = {}

function upstream.simcard.condition(input)
	input.simcardObject.condition = input.simcardObject.condition or {}

	if input.simcardObject.config.powerGpio then
		local execute = {this.utility.execute({command = string.format("cat '%s/value'", input.simcardObject.config.powerGpio)})}

		if execute[2] or execute[1].result ~= 0 then
			this.log.error("dev-modem.device:upstream.simcard.condition", "read gpio power", execute[2] or execute[1].output or "no message")
		else
			input.simcardObject.condition[".powerGpio"] = tonumber(execute[1].output or "") or 0
		end
	else
		input.simcardObject.condition[".powerGpio"] = 1
	end
	input.simcardObject.condition.powerGpio = input.simcardObject.condition[".powerGpio"]


	if input.simcardObject.condition[".powerGpio"] == 1 then
		if input.modemObject.condition[".simcard"] ~= input.simcardName then
			local execute = {this.utility.execute({command = "cat /proc/uptime"})}

			if execute[1] and execute[1].result == 0 then
				local time = {}
				time.up, time.idle = execute[1].output:match("([%d%.]+)%s+([%d%.]+)")
				time.up = tonumber(time.up) or 0
				time.idle = tonumber(time.idle) or 0

				if 120 <= time.up then
					input.modemObject.condition[".simcard"] = input.simcardName
					input.modemObject.condition.simcard = input.modemObject.condition[".simcard"]
					this.log.warn("dev-modem.device:upstream.simcard.condition", "set current simcard", "ok")
				end
			end
		end
	end

	this.log.debug("dev-modem.device:upstream.simcard.condition", "update", "ok")
end

function upstream.simcard.storage(input)
	input.simcardObject.storage = input.simcardObject.storage or {}

	if input.simcardObject.condition[".powerGpio"] ~= 1 then
		this.log.warn("dev-modem.device:upstream.simcard.storage", "check simcard power", "disable")
		return
	end

	if not (input.modemObject.storage.generic) then
		this.log.warn("dev-modem.device:upstream.simcard.storage", "check modem storage", "empty")
		return
	end

	local device = this.utility.mmcli({command = string.format("-i '%s'", input.modemObject.storage.generic.sim or "")})

	if device.sim then
		for fieldName, fieldObject in pairs(device.sim) do
			input.simcardObject.storage[fieldName] = fieldObject
		end

		if not (input.simcardObject.config.apn) or
			input.simcardObject.condition.autoapn then

			if #(input.simcardObject.storage.properties['operator-code'] or '') >= 4 then
				local mcc, mnc = input.simcardObject.storage.properties['operator-code']:sub(1, 3), input.simcardObject.storage.properties['operator-code']:sub(4)

				local apnConfigFile = io.open("/usr/share/kroks/apns-full-config.json", "r")
				local apnConfigObject = this.require.json.decode(apnConfigFile:read("*a"));

				local apnCursor = (apnConfigObject[mcc] or {})[mnc]

				if apnCursor then
					for index, object in pairs(apnCursor) do
						if object.type and object.type:find("default") then
							input.simcardObject.config.apn = object.apn
							input.simcardObject.config.username = input.simcardObject.config.username or object.user
							input.simcardObject.config.password = input.simcardObject.config.password or object.password

							input.simcardObject.condition.autoapn = true
							break;
						end
					end
				end

				if not (input.simcardObject.config.apn) then
					input.simcardObject.config.apn = "internet"
					input.simcardObject.config.username = "username"
					input.simcardObject.config.password = "password"
					input.simcardObject.condition.autoapn = true
				end
			end
		end
	end

	this.log.debug("dev-modem.device:upstream.simcard.storage", "update", "ok")
end

upstream.sms = {}

function upstream.sms.import(input)
	input.simcardObject.sms = input.simcardObject.sms or {}

	if input.simcardObject.condition[".powerGpio"] ~= 1 then
		this.log.warn("dev-modem.device:upstream.sms.import", "check simcard power", "disable")
		return
	end

	if not (input.modemObject.config.device) then
		this.log.warn("dev-modem.device:upstream.sms.import", "check device path", "not exist")
		return false
	end

	if not (input.modemObject.storage.generic) then
		this.log.warn("dev-modem.device:upstream.sms.import", "check modem storage", "empty")
		return false
	end

	local smsList = this.utility.mmcli({command = string.format("-m '%s' --messaging-list-sms", input.modemObject.config.device)})

	for index, smsDbusPath in pairs(smsList["modem.messaging.sms"] or {}) do
		local smsRaw = this.utility.mmcli({command = string.format("-s '%s'", smsDbusPath)})

		if not (smsRaw.sms) then
			this.log.warn("dev-modem.device:upstream.sms.import", "read sms object", "error")
		else
			smsRaw.sms.content.number = smsRaw.sms.content.number or "CORE"
			local smsPhone = smsRaw.sms.content.number

			input.simcardObject.sms[smsPhone] = input.simcardObject.sms[smsPhone] or {}
			local smsArray = input.simcardObject.sms[smsPhone]

			local cursor = false

			for smsIndex, smsObject in pairs(smsArray) do
				if smsObject.storage["dbus-path"] == smsDbusPath then
					cursor = smsObject
					break
				end
			end

			if not (cursor) then
				cursor = table.insert(smsArray, {})
				cursor = smsArray[#smsArray]
			end

			cursor.condition = {}
			cursor.storage = smsRaw.sms
		end
	end

	this.log.debug("dev-modem.device:upstream.sms.import", "update", "ok")
end

function upstream.sms.process(input)
	if input.smsObject.storage.properties["pdu-type"] == "submit" and input.smsObject.storage.properties["state"] == "--" then
		local execute = {this.utility.execute({command = string.format("mmcli -s '%s' --send", input.smsObject.storage["dbus-path"])})}

		if execute[2] or execute[1].result ~= 0 then
			this.log.error("dev-modem.device:upstream.sms.process", "send sms ", execute[2] or execute[1].output or "no message")
		else
			local smsRaw = this.utility.mmcli({command = string.format("-s '%s'", input.smsObject.storage["dbus-path"])})

			if not ((smsRaw.sms or {}).content or {}).number then
				this.log.warn("dev-modem.device:upstream.sms.detect", "read sms object", "error")
			else
				for fieldName, fieldObject in pairs(smsRaw.sms) do
					input.smsObject.storage[fieldName] = fieldObject
				end
			end
		end
	end

	if input.smsObject.storage.properties.timestamp then
		local function timestamp_gsm2unix(timestamp)
			if timestamp then
				local y, m, d, H, M, S, zone = tostring(timestamp):match('(%d%d)(%d%d)(%d%d)(%d%d)(%d%d)(%d%d)([+-]%d%d)')

				if y and m and d and H and M and S and zone then
					local unix = os.time({ year = tonumber('20' ..y),
						month = tonumber(m),
						day = tonumber(d),
						hour = tonumber(H),
						min = tonumber(M),
						sec = tonumber(S)
					})

					return unix - 60 * 60 * tonumber(zone)
				end
			end

			return os.time()
		end

		if input.smsObject.storage.properties.timestamp == "--" or input.smsObject.storage.properties.timestamp:find("%+%d%d") then
			input.smsObject.storage.properties.timestamp = tostring(timestamp_gsm2unix(input.smsObject.storage.properties.timestamp))
		end
	end

	if input.smsObject.storage.properties.state == "received" or input.smsObject.storage.properties.state == "sent" then
		this.utility.execute({command = string.format("mmcli -m '%s' --messaging-delete-sms='%s'", input.modemObject.config.device, input.smsObject.storage["dbus-path"])})
	end

	this.log.debug("dev-modem.device:upstream.sms.process", "update", "ok")
end

function upstream.update()
	for modemName, modemObject in pairs(this.device.storage) do
		local input = {}
		input.modemName = modemName
		input.modemObject = modemObject

		upstream.modem.condition(input)
		upstream.modem.storage(input)

		for simcardName, simcardObject in pairs(modemObject.simcard) do
			input.simcardName = simcardName
			input.simcardObject = simcardObject

			upstream.simcard.condition(input)
			upstream.simcard.storage(input)

			upstream.sms.import(input)

			for smsPhone, smsArray in pairs(simcardObject.sms) do
				input.smsPhone = smsPhone
				input.smsArray = smsArray

				for smsIndex, smsObject in pairs(input.smsArray) do
					input.smsIndex = smsIndex
					input.smsObject = smsObject

					if not (input.smsObject.storage.properties) then
						this.log.warn("dev-modem.device:upstream.sms.update", "remove bad sms object", smsIndex)
						table.remove(smsArray, smsIndex)
					else
						upstream.sms.process(input)
					end
				end

				table.sort(input.smsArray, function (A, B)
					return (A.storage.properties.timestamp or 0) < (B.storage.properties.timestamp or 0)
				end)
			end
		end
	end
end

return upstream
