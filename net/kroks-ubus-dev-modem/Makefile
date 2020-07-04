include $(TOPDIR)/rules.mk

PKG_NAME:=kroks-ubus-dev-modem
PKG_VERSION:=0.0.6-1
PKG_RELEASE:=1

PKG_LICENSE:=4pda
PKG_MAINTAINER:=Kroks <info@kroks.ru>

LUCI_TITLE:=Kroks ubus service for controll ModemManager device
LUCI_DEPENDS:=+libc +kroks-ubus-generic +kroks-ubus-util-ping +luajit +modemmanager
LUCI_PKGARCH:=all

define Package/kroks-ubus-dev-modem
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Kroks ubus service for controll ModemManager device
  DEPENDS:= \
	+libc \
	+kroks-ubus-generic \
	+kroks-ubus-util-ping \
	+luajit \
	+modemmanager
endef

include $(TOPDIR)/feeds/luci/luci.mk