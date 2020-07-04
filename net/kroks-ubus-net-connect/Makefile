include $(TOPDIR)/rules.mk

PKG_NAME:=kroks-ubus-net-connect
PKG_VERSION:=0.0.6-1
PKG_RELEASE:=1

PKG_LICENSE:=4pda
PKG_MAINTAINER:=Kroks <info@kroks.ru>

LUCI_TITLE:=Kroks ubus service for controll network connect
LUCI_DEPENDS:=+libc +kroks-ubus-generic +kroks-ubus-util-ping +luajit
LUCI_PKGARCH:=all

define Package/kroks-ubus-net-connect
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Kroks ubus service for controll network connect
  DEPENDS:= \
	+libc \
	+kroks-ubus-generic \
	+kroks-ubus-util-ping \
	+luajit
endef

include $(TOPDIR)/feeds/luci/luci.mk