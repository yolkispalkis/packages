local event = {}

event.handler = {
	["bearer"] = function (input)
		return true
	end,

	["bearer.status.state"] = function (input)
		return true
	end,

	["modem"] = function (input)
		if input.content[1] == "added" then
			this.device.upstream.update()

			for modemName, modemObject in pairs(this.device.storage) do
				if (((modemObject.storage or {}).generic or {}).sim or "--") ~= "--" then
					this.ubus.connector:call("kroks.net.connect." ..modemName , "reset", {})
				end
			end
		end

		return true
	end,

	["modem.3gpp.registration-state"] = function (input)
		local cursor = ((((input or {}).modemObject or {}).storage or {})["3gpp"])

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		cursor["registration-state"] = input.content[2] or "--"

		return true
	end,

	["modem.3gpp.operator-name"] = function (input)
		local cursor = ((((input or {}).modemObject or {}).storage or {})["3gpp"])

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		cursor["operator-name"] = input.content[1] or "--"

		return true
	end,

	["modem.location.gps"] = function (input)
		local cursor = (((((input or {}).modemObject or {}).storage or {}).location or {}).gps)

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		cursor.longitude = input.content[1] or "--"
		cursor.latitude = input.content[2] or "--"

		return true
	end,

	["modem.location.3gpp"] = function (input)
		local cursor = (((((input or {}).modemObject or {}).storage or {}).location or {})["3gpp"])

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		cursor.mcc = input.content[1] or "--"
		cursor.mnc = input.content[2] or "--"
		cursor.lac = input.content[3] or "--"
		cursor.tac = input.content[4] or "--"
		cursor.cid = input.content[5] or "--"

		if cursor.mcc ~= "--" then
			input.modemObject.storage["3gpp"]["operator-code"] = cursor.mcc .. cursor.mnc
		else
			input.modemObject.storage["3gpp"]["operator-code"] = "--"
		end

		return true
	end,

	["modem.location.cdma-bs"] = function (input)
		local cursor = (((((input or {}).modemObject or {}).storage or {}).location or {})["cdma-bs"])

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		cursor.longitude = input.content[1] or "--"
		cursor.latitude = input.content[2] or "--"

		return true
	end,

	["modem.signal.cdma1x"] = function (input)
		local cursor = (((((input or {}).modemObject or {}).storage or {}).signal or {}).cdma1x)

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		input.modemObject.storage.generic["access-technologies"][1] = "cdma1x"
		cursor.rssi = input.content[1] or "--"
		cursor.ecio = input.content[2] or "--"

		return true
	end,

	["modem.signal.evdo"] = function (input)
		local cursor = (((((input or {}).modemObject or {}).storage or {}).signal or {}).evdo)

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		input.modemObject.storage.generic["access-technologies"][1] = "evdo"
		cursor.rssi = input.content[1] or "--"
		cursor.ecio = input.content[2] or "--"
		cursor.sinr = input.content[3] or "--"
		cursor.io = input.content[4] or "--"

		return true
	end,

	["modem.signal.gsm"] = function (input)
		local cursor = (((((input or {}).modemObject or {}).storage or {}).signal or {}).gsm)

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		input.modemObject.storage.generic["access-technologies"][1] = "gsm"
		cursor.rssi = input.content[1] or "--"

		return true
	end,

	["modem.signal.umts"] = function (input)
		local cursor = (((((input or {}).modemObject or {}).storage or {}).signal or {}).umts)

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		input.modemObject.storage.generic["access-technologies"][1] = "umts"
		cursor.rssi = input.content[1] or "--"
		cursor.rscp = input.content[2] or "--"
		cursor.ecio = input.content[3] or "--"

		return true
	end,

	["modem.signal.lte"] = function (input)
		local cursor = (((((input or {}).modemObject or {}).storage or {}).signal or {}).lte)

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		input.modemObject.storage.generic["access-technologies"][1] = "lte"
		cursor.rssi = input.content[1] or "--"
		cursor.rsrq = input.content[2] or "--"
		cursor.rsrp = input.content[3] or "--"
		cursor.snr = input.content[4] or "--"

		return true
	end,

	["modem.generic.signal-quality"] = function (input)
		local cursor = (((((input or {}).modemObject or {}).storage or {}).generic)["signal-quality"])

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		cursor["value"] = input.content[1] or "--"

		return true
	end,

	["modem.generic.state"] = function (input)
		local cursor = ((((input or {}).modemObject or {}).storage or {}).generic)

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		cursor.state = input.content[2] or "--"

		return true
	end,

	["modem.generic.power-state"] = function (input)
		local cursor = ((((input or {}).modemObject or {}).storage or {}).generic)

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		cursor["power-state"] = input.content[1] or "--"

		return true
	end,

	["modem.generic.active-bands"] = function (input)
		local cursor = ((((input or {}).modemObject or {}).storage or {}).generic)

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		local bands = {}
		for bandName in input.content[1]:gmatch("([%w%-]+)") do
			table.insert(bands, bandName)
		end
		cursor["active-bands"] = bands

		local channels = {};
		for channelValue in input.content[2]:gmatch("(%d+)") do
			table.insert(channels, tonumber(channelValue))
		end
		cursor["active-channels"] = channels

		local bandwidths = {};
		for bandwidthValue in input.content[3]:gmatch("(%d+)") do
			table.insert(bandwidths, tonumber(bandwidthValue))
		end
		cursor["active-bandwidths"] = bandwidths

		return true
	end,

	["sms"] = function (input)
		local cursor = (((input or {}).modemObject or {}).simcard)

		if not (cursor) then
			this.log.error(string.format("dev-modem.device event.%s", input.folder), "make cursor", "error")
			return false, "no cursor"
		end

		if input.content[1] == "added" then
			input.simcardName = input.modemObject.condition.simcard or "simcardY"
			input.simcardObject = input.modemObject.simcard[input.simcardName]

			this.device.upstream.sms.import(input)

			for smsPhone, smsArray in pairs(input.simcardObject.sms) do
				input.smsPhone = smsPhone
				input.smsArray = smsArray

				for smsIndex, smsObject in pairs(input.smsArray) do
					input.smsIndex = smsIndex
					input.smsObject = smsObject

					if not (input.smsObject.storage.properties) then
						this.log.warn("dev-modem.device:upstream.sms.update", "remove bad sms object", smsIndex)
						table.remove(smsArray, smsIndex)
					else
						this.device.upstream.sms.process(input)
					end
				end

				table.sort(input.smsArray, function (A, B)
					return (A.storage.properties.timestamp or 0) < (B.storage.properties.timestamp or 0)
				end)
			end

			return true
		end

		return false
	end
}

function event.hook(input)
	input = input or {}
	input.modemDbusPath = tostring(input.modemDbusPath or "")

	if not (input.modemName and input.modemObject) then
		if input.modemDbusPath:match("/org/freedesktop/ModemManager1/Modem/(%d+)") then
			for modemName, modemObject in pairs(this.device.storage) do
				if (((modemObject or {}).storage or {})["dbus-path"] or "") == input.modemDbusPath then
					input.modemName = modemName
					input.modemObject = modemObject
					break
				end
			end
		end
	end

	input.modemName = input.modemName or "modemX"
	input.modemObject = input.modemObject or this.device.storage[input.modemName]

	input.folder = input.folder or ""
	input.content = input.content or {}

	if not (event.handler[input.folder]) then
		this.log.warn("dev-modem.device:event.hook", input.folder, "not exist folder")
		return
	end

	return event.handler[input.folder](input)
end

return event
