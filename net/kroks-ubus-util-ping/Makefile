include $(TOPDIR)/rules.mk

PKG_NAME:=kroks-ubus-util-ping
PKG_VERSION:=0.0.4-1
PKG_RELEASE:=1

PKG_LICENSE:=4pda
PKG_MAINTAINER:=Kroks <info@kroks.ru>

LUCI_TITLE:=Kroks ubus module for ping
LUCI_DEPENDS:=+libc +kroks-ubus-generic +luajit
LUCI_PKGARCH:=all

define Package/kroks-ubus-util-ping
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Kroks ubus module for ping
  DEPENDS:= \
	+libc \
	+kroks-ubus-generic \
	+luajit
endef

include $(TOPDIR)/feeds/luci/luci.mk