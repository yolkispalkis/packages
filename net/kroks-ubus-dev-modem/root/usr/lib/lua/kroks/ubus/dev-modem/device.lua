local device = {}

device.storage = {}

function device.import()
	if not (this.config.storage) then
		this.log.fatal("dev-modem.device:import", "loading config", "no exist")
		error("STOP")
	end

	for modemName, modemConfigObject in pairs(this.config.storage.modem or {}) do
		device.storage[modemName] = {
			config = modemConfigObject,
			simcard = {}
		}
	end

	for simcardName, simcardConfigObject in pairs(this.config.storage.simcard or {}) do
		local modemName = simcardConfigObject.modem or "modemX"

		if not (device.storage[modemName]) then
			this.log.warn("dev-modem.device:import", "adding a SIM card", string.format("no founded modem '%s'", modemName))
		else
			device.storage[modemName].simcard = device.storage[modemName].simcard or {}

			device.storage[modemName].simcard[simcardName] = {
				config = simcardConfigObject,
				sms = {}
			}
		end
	end

	this.log.debug("dev-modem.device:import", "updated", "ok")
end

device.upstream = require("kroks.ubus.dev-modem.device.upstream")
device.downstream = require("kroks.ubus.dev-modem.device.downstream")
device.event = require("kroks.ubus.dev-modem.device.event")

return device
