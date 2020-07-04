'use strict';
'require rpc';
'require form';
'require network';

var getModemList = rpc.declare({
	object: 'kroks.dev.modem',
	method: 'object',
	params: [ 'folder' ],
	expect: { '': {} }
});

network.registerPatternVirtual(/^mobiledata-.+$/);
network.registerErrorCode('CALL_FAILED', _('Call failed'));
network.registerErrorCode('NO_CID',      _('Unable to obtain client ID'));
network.registerErrorCode('PLMN_FAILED', _('Setting PLMN failed'));

return network.registerProtocol('modemmanager', {
	getI18n: function() {
		return _('ModemManager');
	},

	getIfname: function() {
		return this._ubus('l3_device') || 'modemmanager-%s'.format(this.sid);
	},

	getOpkgPackage: function() {
		return 'modemmanager';
	},

	isFloating: function() {
		return true;
	},

	isVirtual: function() {
		return true;
	},

	getDevices: function() {
		return null;
	},

	containsDevice: function(ifname) {
		return (network.getIfnameOf(ifname) == this.getIfname());
	},

	renderFormOptions: function(s) {
		var dev = this.getL3Device() || this.getDevice(), o;

		o = s.taboption('general', form.ListValue, 'device', _('Modem device'));
		o.rmempty = false;
		o.load = function(section_id) {
			return getModemList('').then(L.bind(function(modems) {
				for(let idx in modems) {
					const modemGeneric = (((modems[idx] || {}).storage || {}).generic || {});
					const modemManufacture = modemGeneric.plugin && modemGeneric.plugin != 'Generic' && modemGeneric.plugin || modemGeneric.manufacturer || 'No name';
					const modemModel = (modemGeneric.model || '').length < 15 && modemGeneric.model || 'modem';
					const modemImei = modemGeneric['equipment-identifier'] && '. IMEI: ' + modemGeneric['equipment-identifier'] || '';
					this.value(modemGeneric.device, `${modemManufacture}: ${modemModel}${modemImei}`);
				}
				return form.Value.prototype.load.apply(this, [section_id]);
			}, this));
		};

		o = s.taboption('general', form.ListValue, 'iptype', _('IP Type'));
		o.value('ipv4v6', _('IPv4/IPv6 (both - defaults to IPv4)'))
		o.value('ipv4', _('IPv4 only'));
		o.value('ipv6', _('IPv6 only'));
		o.default = 'ipv4v6';

		o = s.taboption('advanced', form.Value, 'mtu', _('Override MTU'));
		o.placeholder = dev ? (dev.getMTU() || '1500') : '1500';
		o.datatype    = 'max(9200)';

		o = s.taboption('general', form.Value, 'metric', _('Gateway metric'));
		o.placeholder = 0;
	}
});
