cjson = require("cjson");

utility = {};

function utility.file(fileName, fileContent)
	if not fileName then
		return false, -1;
	end

	local pcallStatus, fileDescriptor, fileError = pcall(io.open, fileName, fileContent and "w" or "r");

	if not (pcallStatus and fileDescriptor) then
		return false, -1, fileError or fileDescriptor or "no message";
	end

	local pcallStatus, fileContent, fileError = pcall(fileContent and fileDescriptor.write or fileDescriptor.read, fileDescriptor, fileContent or "*a");

	if not (pcallStatus and fileContent) then
		return false, -2, fileError or fileContent or "no message";
	end

	pcall(fileDescriptor.close, fileDescriptor);

	return fileContent;
end

pcall(function()
	local procStat = utility.file("/proc/self/stat");
	local procStatPid = procStat:match("(%d+)");

	os.tmpname = function()
		return string.format("/dev/shm/lua_%s_%s", procStatPid, os.clock());
	end
end)

function utility.execute(command)
	local stdoutFilename = os.tmpname();
	local stderrFilename = os.tmpname();

	command = string.format([[%s 1>%s 2>%s]], command or "", stdoutFilename, stderrFilename);

	local code = os.execute(command);

	local stdoutContent = utility.file(stdoutFilename);
	os.remove(stdoutFilename);

	local stderrContent = utility.file(stderrFilename);
	os.remove(stderrFilename);

	return code, stdoutContent, stderrContent;
end

function modemObjectProcessed(modemObject)
	if not ((((modemObject or {}).storage or {}).generic or {})["active-bands"]) then
		return false;
	end

	modemObject.storage.generic["processed-bands"] = {};

	if modemObject.storage.generic["active-bands"] and #modemObject.storage.generic["active-bands"] > 0 then
		local tech = modemObject.storage.generic["access-technologies"][1];

		if tech then
			local bands_table = utility.file(string.format("/usr/lib/lua/luci/controller/modem/bands_table/%s.csv", tech));

			for bandIndex, bandName in pairs(modemObject.storage.generic["active-bands"]) do
				modemObject.storage.generic["processed-bands"][bandIndex] = {};
				local cursor = modemObject.storage.generic["processed-bands"][bandIndex];

				cursor["band-name"] = bandName;

				local bandNumber = bandName:match("(%d+)") or 0;

				local channel = tonumber(modemObject.storage.generic["active-channels"][bandIndex]);
				if channel and bands_table then
					for fileLine in bands_table:gmatch("([^\n]+)\n") do
						if fileLine:match("^(%d+)") == bandNumber then
							local block = {};

							for value in (fileLine ..","):gmatch("([^,]*),") do
								table.insert(block, tonumber(value) or value);
							end

							cursor["band-number"] = block[1];
							cursor["band-alias"] = block[2];

							local channelDownload = channel;
							local channelUpload = "--";

							local channel = ((channel - block[5]) / block[11]);
							local freqDownload = channel * (block[4] - block[3]) + block[3];
							local freqDownloadUpload = "--";

							if type(block[9]) == "number" then
								channelUpload = channel - block[5] + block[9];
								freqDownloadUpload = channel * (block[8] - block[7]) + block[7];
							end

							cursor["channel-download"] = channelDownload;
							cursor["channel-upload"] = channelUpload;

							cursor["freq-download"] = freqDownload;
							cursor["freq-upload"] = freqDownloadUpload;

							cursor["bandwidth"] = tonumber(modemObject.storage.generic["active-bandwidths"][bandIndex])
							cursor["bandwidth"] = cursor["bandwidth"] and cursor["bandwidth"] / 1000000 or block[12] or "--";

							cursor["duplex-spacing"] = block[13] or "--";

							break;
						end
					end
				end
			end
		end
	end
end

module("luci.controller.modem.index", package.seeall)

function index()
	local checkProto = false;

	for sectionName, sectionObject in pairs(luci.model.uci:get_all("network")) do
		if sectionObject[".type"] == "interface" and sectionObject["proto"] == "modemmanager" then
			checkProto = true;
			break;
		end
	end

	if not checkProto then
		return true;
	end

	if not luci.http.getenv("REQUEST_URI"):find('/admin/network/modem') then
		entry({"admin", "network", "modem"}, alias("admin", "network", "modem"), _("Modem"), 1);
		return true;
	end

	local pcallStatus, ubusConnector = pcall(function()
		local ubus = require("ubus");

		if not ubus then
			return false;
		end

		return ubus.connect();
	end);

	if not ubusConnector then
		return true;
	end

	local mmcliStorage = ubusConnector:call("kroks.dev.modem", "object", {});

	if not mmcliStorage then
		os.execute("sleep 5")
		luci.http.redirect(luci.http.getenv("REQUEST_URI"));
		return true;
	end

	for modemName, modemObject in pairs(mmcliStorage) do
		modemName = tostring(modemName);

		local tabIndex = modemName:match("(%d+)") or "1";
		local tabName = string.format("%s: %s", modemName, (modemObject.storage["3gpp"] or {})["operator-name"] or ((modemObject.simcard[modemObject.condition.simcard].storage or {}).properties or {})["operator-name"] or "No SIM");

		entry({"admin", "network", "modem", modemName}, firstchild(), tabName, tabIndex);

		local data = {
			modemName = modemName,
			modemObject = modemObject,
			ubusConnector = ubusConnector,
		}

		entry({"admin", "network", "modem", modemName, "information"}, call("informationPage", data), _("Information"), 1);
		entry({"admin", "network", "modem", modemName, "configuration"}, call("configurationPage", data), _("Configuration"), 2);
		entry({"admin", "network", "modem", modemName, "ussd"}, call("ussdPage", data), _("USSD"), 3);
		entry({"admin", "network", "modem", modemName, "sms"}, call("smsPage", data), _("SMS"), 4);
		entry({"admin", "network", "modem", modemName, "terminal"}, call("terminalPage", data), _("Terminal"), 5);
		entry({"admin", "network", "modem", modemName, "antenna_pointing"}, call("antennaPointingPage", data), _("Antenna pointing"), 6);

		entry({"admin", "network", "modem"}, alias("admin", "network", "modem", modemName), _("Modem"), 1)
	end

	entry({"admin", "network", "modem", 'control_panel'}, call("controlPanelPage", {
		ubusConnector = ubusConnector,
		mmcliStorage = mmcliStorage,
	}), _("Control panel"), 2);
end

function informationPage(data)
	modemObjectProcessed(data.modemObject);

	data.formvalue = luci.http.formvalue();

	if data.formvalue.html or not data.formvalue.json then
		luci.template.render("modem/information", data);
	elseif data.formvalue.json then
		luci.http.prepare_content("application/json");
		luci.http.write_json(data);
	end

	return true;
end

function configurationPage(data)
	data.formvalue = luci.http.formvalue();

	if data.formvalue.html or not data.formvalue.json then
		luci.template.render("modem/configuration/index", data);
	elseif data.formvalue.json then
		luci.http.prepare_content("application/json");
		luci.http.write_json(data);
	end
end

function ussdPage(data)
	data.formvalue = luci.http.formvalue();

	if data.formvalue.html or not data.formvalue.method then
		luci.template.render("modem/ussd", data);
	elseif data.formvalue.method then
		if not ((data.modemObject.storage or {}).generic  or {}).device then
			luci.http.prepare_content("application/json");
			luci.http.write_json({
				error = "no detect modem " ..(data.modemName or "modemX")
			});
			return false;
		end

		local output = {};

		if data.formvalue.method == "status" then
			local executeCode, executeStdout, executeStderr = utility.execute('mmcli -m "%s" --timeout=60 --3gpp-ussd-status -J' % { data.modemObject.storage.generic.device });

			if executeCode == 0 then
				output.result = ((cjson.decode(tostring(executeStdout or "{}")).modem or {})["3gpp"] or {}).ussd;
			else
				output.error = executeStderr;
			end
		elseif data.formvalue.method == "initiate" and data.formvalue.params and #data.formvalue.params > 0 then
			data.formvalue.params = luci.http.urldecode(data.formvalue.params);

			local executeCode, executeStdout, executeStderr = utility.execute('mmcli -m "%s" --timeout=60 --3gpp-ussd-initiate="%s"' % { data.modemObject.storage.generic.device, data.formvalue.params });

			if executeCode == 0 then
				output.result = tostring(executeStdout):match('\'(.-)\'');
			else
				output.error = executeStderr;
			end
		elseif data.formvalue.method == "respond" and data.formvalue.params and #data.formvalue.params > 0 then
			data.formvalue.params = luci.http.urldecode(data.formvalue.params);

			local executeCode, executeStdout, executeStderr = utility.execute('mmcli -m "%s" --timeout=60 --3gpp-ussd-respond="%s"' % { data.modemObject.storage.generic.device, data.formvalue.params });

			if executeCode == 0 then
				output.result = tostring(executeStdout):match('\'(.-)\'');
			else
				output.error = executeStderr;
			end
		elseif data.formvalue.method == "cancel" then
			local executeCode, executeStdout, executeStderr = utility.execute('mmcli -m "%s" --timeout=60 --3gpp-ussd-cancel' % { data.modemObject.storage.generic.device });

			if executeCode == 0 then
				output.result = tostring(executeStdout);
			else
				output.error = executeStderr;
			end
		end

		luci.http.prepare_content("application/json");
		if not (output.error or	 output.result) then
			output.error = "no result";
		end
		luci.http.write_json(output);
	end
end

function smsPage(data)
	data.formvalue = luci.http.formvalue();

	if data.formvalue.html or not data.formvalue.method then
		luci.template.render("modem/sms", data);
	elseif data.formvalue.method then
		data.formvalue.params = data.formvalue.params and data.formvalue.params ~= '' and luci.http.urldecode(data.formvalue.params) or nil;
		local output = {}

		if data and data.modemObject and data.modemObject.simcard then
			if data.formvalue.method == 'list' then
				if data.formvalue.params then
					if data.device.messaging[tostring(data.formvalue.params)] then
						output.result = data.device.messaging[tostring(data.formvalue.params)]
					else
						output.error = "no found messaging"
					end
				else
					output.result = (data.modemObject.simcard[data.modemObject.condition.simcard] or {}).sms
				end
			elseif data.formvalue.method == 'create' then
				data.formvalue.params = tostring(data.formvalue.params)

				local identifier, other1 = data.formvalue.params:match('\'(.-)\'(.*)')
				local content, other2 = tostring(other1):match('\'(.-)\'(.*)')
				local class, other3 = tostring(other2):match('\'(.-)\'(.*)')

				content = content or 'empty content fields'
				class = class or '1'

				data.formvalue.params = {
					identifier = identifier,
					content = content,
					class = class
				}

				if identifier and identifier:match('(%a)') == nil then
					local executeCode, executeStdout, executeStderr = utility.execute([[mmcli -m "%s" --messaging-create-sms="number=\'%s\',text=\'%s\',class=\'%s\'" --timeout=%s]] % {data.modemObject.config.device, identifier, content, class, output.timeout})

					if executeCode == 0 then
						output.result = executeStdout
					else
						output.error = executeStderr or 'no message'
					end
				else
					output.error = "no identifier fields"
				end
			else
				output.error = 'no supported command'
			end
		else
			output.error = "no messaging table"
		end


		luci.http.prepare_content("application/json");
		if not (output.error or	 output.result) then
			output.error = "no result";
		end
		luci.http.write_json(output);
	end
end

function terminalPage(data)
	data.formvalue = luci.http.formvalue();

	if data.formvalue.html or not data.formvalue.request then
		luci.template.render("modem/terminal", data);
	elseif data.formvalue.request then
		data.formvalue.request = string.upper(luci.http.urldecode(data.formvalue.request));

		local output = {};

		local executeCode, executeStdout, executeStderr = utility.execute([[mmcli -m "%s" --command='%s' --timeout=60]] % { data.modemObject.storage.generic.device, data.formvalue.request })

		output.result = tostring(executeStdout):match('response: \'(.*)\'')
		output.error = executeStderr and #executeStderr > 0 and executeStderr or nil;

		luci.http.prepare_content("application/json");
		if not (output.error or	 output.result) then
			output.error = "no result";
		end
		luci.http.write_json(output);
	end
end

function antennaPointingPage(data)
	data.formvalue = luci.http.formvalue();

	if data.formvalue.html or not data.formvalue.json then
		data.formvalue["3gpp"] = true;
		data.formvalue["signal"] = true;
		data.formvalue["network"]  = true;
		data.formvalue["network_device"] = true;
		data.formvalue["bands"] = true;
	end

	local output = {};

	if ((data.modemObject.storage or {}).location or {})["3gpp"] and data.formvalue["3gpp"] then
		output["3gpp"] = {
			["mcc"] = data.modemObject.storage.location["3gpp"]["mcc"],
			["mnc"] = data.modemObject.storage.location["3gpp"]["mnc"],
			["lac"] = data.modemObject.storage.location["3gpp"]["lac"],
			["tac"] = data.modemObject.storage.location["3gpp"]["tac"],
			["cid"] = data.modemObject.storage.location["3gpp"]["cid"],
			["tech"] = data.modemObject.storage.generic["access-technologies"][1],
		};
	end

	if (data.modemObject.storage or {}).generic and (data.modemObject.storage or {}).signal and data.formvalue["signal"] then
		output["signal"] = {
			["quality"] = data.modemObject.storage.generic["signal-quality"].value,
			["tech"] = data.modemObject.storage.generic["access-technologies"][1],
			["detail"] = {},
		};

		output["signal"]["detail"] = data.modemObject.storage.signal[output.signal["tech"]];
	end

	if data.formvalue["network"] then
		output.network = {};

		local interfaceStatus = data.ubusConnector:call("network.interface", "status", { interface = data.modemName });

		if interfaceStatus then
			output.network.interface = {
				["device"] = interfaceStatus.l3_device,
				["uptime"] = interfaceStatus.uptime,
				["ipv4-address"] = ((interfaceStatus["ipv4-address"] or {})[1] or {})["address"],
				["ipv4-mask"] = ((interfaceStatus["ipv4-address"] or {})[1] or {})["mask"],
				["ipv4-gateway"] = ((interfaceStatus["ipv4-address"] or {})[1] or {})["ptpaddress"],
			};
		end

		if not (output.network.interface or {})["device"] then
			output.network.interface = nil;
		end

		if output.network.interface and data.formvalue["network_ping"] then
			data.formvalue["network_ping_host"] = data.formvalue["network_ping_host"] or "8.8.8.8";

			local executeCode, executeStdout, executeStderr = utility.execute(string.format([[ping -c 10 -A -I %s -W 10 -q %s]], output.network.interface["ipv4-address"], data.formvalue["network_ping_host"]));

			output.network.ping = {
				status = executeCode,
			}

			pcall(function()
				local transmitted, successfully = executeStdout:match("(%d+) packets transmitted, (%d+) packets received");
				transmitted = tonumber(transmitted);
				successfully = tonumber(successfully);

				output.network.ping["reliability"] = transmitted and ((successfully * 100) / transmitted) or 0;
			end);

			pcall(function()
				local min, avg, max = executeStdout:match("min/avg/max = ([%d%.]+)/([%d%.]+)/([%d%.]+) ms");

				output.network.ping["rtt"] = tonumber(avg);
			end);
		end

		if output.network.interface and data.formvalue["network_device"] then
			local deviceStatus = data.ubusConnector:call("network.device", "status", { name = output.network.interface["device"] or "" });

			if deviceStatus then
				output.network.device = deviceStatus;
			end
		end

	end

	if data.formvalue["bands"] then
		modemObjectProcessed(data.modemObject);
		output["bands"] = data.modemObject.storage.generic["processed-bands"]
	end

	if data.formvalue.html or not data.formvalue.json then
		luci.template.render("modem/antenna_pointing", {
			antenna_pointing = output,
			modemName = data.modemName
		});
	else
		luci.http.prepare_content("application/json");
		luci.http.write_json(output);
	end
end

function controlPanelPage(data)
	data.formvalue = luci.http.formvalue();

	if data.formvalue.html or not data.formvalue.request then
		luci.template.render("modem/control_panel", data);
	end
end
