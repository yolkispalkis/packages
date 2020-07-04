local downstream = {}

downstream.modem = {}

function downstream.modem.condition(input)
	input.modemObject.condition[".simcardChanged"] = input.modemObject.condition.simcard ~= input.modemObject.condition[".simcard"]

	for simcardName, simcardObject in pairs(input.modemObject.simcard) do
		simcardObject.condition.powerGpio = input.modemObject.condition.simcard == simcardName and 1 or 0

		if simcardObject.condition.powerGpio ~= simcardObject.condition[".powerGpio"] then
			input.modemObject.condition[".simcardChanged"] = true
		end
	end

	local powerGpio = input.modemObject.condition[".powerGpio"]

	if input.modemObject.condition[".simcardChanged"] then
		input.modemObject.condition.powerGpio = 0
	end

	if input.modemObject.condition.powerGpio ~= input.modemObject.condition[".powerGpio"] then
		local execute = {this.utility.execute({command = string.format("/bin/echo '%s' > '%s/value' 2>/dev/null", input.modemObject.condition.powerGpio, input.modemObject.config.powerGpio)})}

		if execute[2] then
			this.log.error("dev-modem.device downstream.modem.condition", "set powerGpio", execute[2] or "no message")
		else
			input.modemObject.condition[".powerGpio"] = input.modemObject.condition.powerGpio
		end
	end

	input.modemObject.condition.powerGpio = input.modemObject.condition[".powerGpio"]

	if input.modemObject.condition[".simcardChanged"] then
		input.modemObject.condition.powerGpio = powerGpio
	end

	this.log.debug("dev-modem.device downstream.modem.condition", "update", "ok")
end


downstream.simcard = {}

function downstream.simcard.condition(input)
	if input.simcardObject.condition.powerGpio ~= input.simcardObject.condition[".powerGpio"] then
		local execute = {this.utility.execute({command = string.format("/bin/echo '%s' > '%s/value' 2>/dev/null", input.simcardObject.condition.powerGpio, input.simcardObject.config.powerGpio)})}

		if execute[2] then
			this.log.error("dev-modem.device downstream.simcard.condition", "set powerGpio", execute[2] or "no message")
		else
			input.simcardObject.condition[".powerGpio"] = input.simcardObject.condition.powerGpio
		end
	end

	input.simcardObject.condition.powerGpio = input.simcardObject.condition[".powerGpio"]

	input.modemObject.condition[".simcard"] = input.modemObject.condition.simcard

	this.log.debug("dev-modem.device downstream.simcard.condition", "update", "ok")
end


function downstream.update()
	for modemName, modemObject in pairs(this.device.storage) do
		local input = {}
		input.modemName = modemName
		input.modemObject = modemObject

		downstream.modem.condition(input)

		for simcardName, simcardObject in pairs(modemObject.simcard) do
			input.simcardName = simcardName
			input.simcardObject = simcardObject

			downstream.simcard.condition(input)
		end

		downstream.modem.condition(input)
	end
end

return downstream