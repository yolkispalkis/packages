local config = {}

config.storage = {}

function config.import(input)
	input = input or {}

	if not (this.require.uci) then
		this.log.fatal("dev-modem.config import", "check require", "error")
		error("check require")
	else
		input.uciConfig = input.uciConfig or "kroks-dev-modem"
		input.uciFilePath = input.uciFilePath or "/etc/config"
		input.uciStatePath = input.uciStatePath or "/var/state"
		input.uciCursor = this.require.uci.cursor(input.uciFilePath, input.uciStatePath)

		local function importKeywords (sectionType, keywords)
			local storage = config.storage
			storage[sectionType] = {}

			input.uciCursor:foreach(input.uciConfig, sectionType, function (section)
				local sectionName = section[".name"]
				storage[sectionType][sectionName] = {}

				for keywordIndex, keywordName in pairs(keywords) do
					storage[sectionType][sectionName][keywordName] = section[keywordName]
				end
			end)
		end

		importKeywords("modem", {"powerGpio", "device", "simcard", "simcardSwitch", "service_location"})
		importKeywords("simcard", {"powerGpio", "enabled", "modem", "pincode", "pukcode", "apn", "auth", "username", "password"})

		this.log.debug("dev-modem.config import", "import config", "ok")
	end
end

return config