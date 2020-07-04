include $(TOPDIR)/rules.mk

PKG_NAME:=kroks-luci-modem-mpci-app
PKG_VERSION:=0.0.6-1
PKG_RELEASE:=1

PKG_LICENSE:=4pda
PKG_MAINTAINER:=Kroks <info@kroks.ru>

LUCI_TITLE:=Support for ModemManager webinterface
LUCI_DEPENDS:=+libc +luci-compat +kroks-ubus-dev-modem +kroks-modemhalt +kroks-luci-modem-mpci-proto
LUCI_PKGARCH:=all

define Package/kroks-luci-modem-mpci-app
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Support for ModemManager webinterface
  DEPENDS:= \
	+libc \
	+luci-compat \
	+kroks-ubus-dev-modem \
	+kroks-modemhalt \
	+kroks-luci-modem-mpci-proto
endef

include $(TOPDIR)/feeds/luci/luci.mk