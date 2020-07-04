local utility = ((this or {}).utility or {})

function utility.mmcli(input)
	input = input or {}
	input.command = input.command or ""

	local command = string.format("/usr/bin/mmcli -J %s 2>/dev/null", input.command)

	local execute = {this.utility.execute({command = command})}

	if execute[2] then
		this.log.error("utility.mmcli", "execute", execute[2] or 'no message')
	else
		execute = execute[1]

		if execute.result ~= 0 then
			this.log.error("utility.mmcli", "execute.mmcli", (execute.output or "no message"):gsub("\n", ""))
		else
			return this.require.json.decode(execute.output)
		end
	end

	return {}
end

return utility