#!/usr/bin/luajit

this = require("kroks.ubus.generic")

this.utility = require("kroks.ubus.dev-modem.utility")
this.config = require("kroks.ubus.dev-modem.config")

this.config.import()

this.device = require("kroks.ubus.dev-modem.device")

this.device.import()
this.device.upstream.update()
this.device.downstream.update()

this.uloop = require("kroks.ubus.dev-modem.uloop")
this.require.uloop.init()

this.ubus = require("kroks.ubus.dev-modem.ubus")

this.ubus.registration()

this.require.uloop.run()
