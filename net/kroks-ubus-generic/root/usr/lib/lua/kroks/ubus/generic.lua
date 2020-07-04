this = {}

this.require = {}
this.require.uci = require("uci")
this.require.ubus = require("ubus")
this.require.uloop = require("uloop")
this.require.json = require("cjson")


this.log = {
	timestamp = os.time(),

	print = function (input)
		print(input)
	end,

	generic = function (input)
		input = input or {}
		input.template = input.template or "[@TIMESTAMP]\t@CLASS :\t@MESSAGE"
		input.method = input.method or this.log.print

		local output = input.template

		local keywords = {"template", "method"}
		input.timestamp = string.format("%s %s", os.time() - this.log.timestamp, os.clock())

		for key, value in pairs(input) do
			if not keywords[key] then
				output = output:gsub(string.format("@%s", string.upper(key)), value)
			end
		end

		return input.method(output)
	end,


	throw = function (class, source, message, reason)
		local output = {
			class = class or "throw",
			message = {
				string.format("source = '%s'", source or ""),
				string.format("message = '%s'", message or ""),
				string.format("reason = '%s'", reason or "")
			}
		}

		output.message = table.concat(output.message, ";\t") ..";"

		return output
	end,

	debug = function (source, message, reason)
		this.log.generic(this.log.throw("debug", source, message, reason))
	end,

	info = function (source, message, reason)
		this.log.generic(this.log.throw("info", source, message, reason))
	end,

	warn = function (source, message, reason)
		this.log.generic(this.log.throw("warn", source, message, reason))
	end,

	error = function (source, message, reason)
		this.log.generic(this.log.throw("error", source, message, reason))
	end,

	fatal = function (source, message, reason)
		this.log.generic(this.log.throw("fatal", source, message, reason))
	end
}

this.log.debug("log", "initializing", "ok")

this.utility = {
	execute = function (input)
		input = input or {}

		input.command = input.command or ""

		local output = {
			command = string.format("%s 2>&1; echo $?", input.command),
			result = "",
			output = ""
		}

		local safe = {}
		safe[1] = {pcall(io.popen, output.command, "r")}

		if not safe[1][1] or not safe[1][2] then
			this.log.error("utility.execute", "open pipe", safe[1][3] or safe[1][2] or 'no message')
			return false, safe[1][3] or safe[1][2] or 'no message'
		end

		safe[2] = {pcall(safe[1][2].read, safe[1][2], "*a")}

		if not safe[2][1] or not safe[2][2] then
			this.log.error("utility.execute", "read pipe", safe[2][3] or safe[2][2] or 'no message')
			return false, safe[2][3] or safe[2][2] or 'no message'
		end

		safe[3] = {pcall(safe[1][2].close, safe[1][2])}

		output.output, output.result = safe[2][2]:match("(.*)(%d+)\n$")
		output.result = tonumber(output.result)

		return output
	end,
}

this.log.debug("utility", "initializing", "ok")


this.ubus = {
	connector = {},

	connect = function ()
		if not (this.require.ubus) then
			this.log.fatal("ubus", "check require", "error")
			error("check require")
		else
			this.ubus.connector = {this.require.ubus.connect()}

			if this.ubus.connector[1] then
				this.log.debug("ubus", "make connector", "ok")

				this.ubus.connector = this.ubus.connector[1]
			else
				this.log.fatal("ubus", "failed make connector", this.ubus.connector[2])
				error("failed make connector")
			end
		end
	end,

	handler = {},
	listener = {},

	registration = function ()
		this.log.debug("ubus", "registration handler", "ok")
		this.ubus.connector:add(this.ubus.handler)

		this.log.debug("ubus", "registration listener", "ok")
		this.ubus.connector:listen(this.ubus.listener)
	end
}

this.ubus.connect()

return this