local uloop = ((this or {}).uloop or {})

uloop.storage = uloop.storage or {}
uloop.storage["simcardSwitch"] = {}

uloop["simcardSwitch"] = this.require.uloop.timer(function()
	local storage = uloop.storage["simcardSwitch"]

	for modemName, modemObject in pairs(this.device.storage or {}) do
		if modemObject.config.simcardSwitch then
			storage[modemName] = storage[modemName] or {}
			local storage = storage[modemName]
			storage.simcardSwitch = false

			local trigger, other = modemObject.config.simcardSwitch:match("([^:]+):*(.*)")
			local argument = {}
			for arg in other:gmatch('([%-%d]+)') do
				table.insert(argument, tonumber(arg) or 0)
			end

			if trigger == "none" then
				modemObject.config.simcardSwitch = nil
			elseif trigger == "reliability" then
				argument[1] = argument[1] or 50
				argument[2] = argument[2] or 120
				argument[2] = argument[2] or -120

				if modemObject["kroks.util.ping"] then
					local reliability = (modemObject["kroks.util.ping"].condition or {}).reliability or 0

					if reliability < argument[1] then
						storage.downTime = storage.downTime and (storage.downTime + 1) or 0

						if storage.downTime >= argument[2] then
							storage.downTime = argument[3]
							storage.simcardSwitch = true
						end
					else
						storage.downTime = 0
					end
				end
			elseif trigger == "rtt" then
				argument[1] = argument[1] or 500
				argument[2] = argument[2] or 120
				argument[2] = argument[2] or -120

				if modemObject["kroks.util.ping"] then
					local rtt = (modemObject["kroks.util.ping"].rtt or {}).avg or 10000

					if rtt > argument[1] then
						storage.downTime = storage.downTime and (storage.downTime + 1) or 0

						if storage.downTime >= argument[2] then
							storage.downTime = argument[3]
							storage.simcardSwitch = true
						end
					else
						storage.downTime = 0
					end
				end
			else

			end

			if storage.simcardSwitch then
				storage.simcardSwitch = false

				local index = 0
				local simcardArray = {}
				local simcardCurrentIndex = 0
				local uciCursor = this.require.uci.cursor()

				uciCursor:foreach("kroks-dev-modem", "simcard", function (section)
					if section.modem == modemName and tonumber(section.enabled) == 1 then
						local simcardName = section[".name"]

						if modemObject.simcard[simcardName] then
							index = index + 1

							if simcardName == modemObject.condition.simcard then
								simcardCurrentIndex = index
							end

							table.insert(simcardArray, simcardName)
						end
					end
				end)

				if #simcardArray > 1 then
					local simcardNextIndex = (simcardCurrentIndex + #simcardArray) % #simcardArray + 1
					local simcardNextName = simcardArray[simcardNextIndex]

					modemObject.condition.simcard = simcardNextName
					this.device.downstream.update()
				end
			end
		end
	end

	uloop["simcardSwitch"]:set(1000)
end, 1000)

return uloop
