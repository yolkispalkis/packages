include $(TOPDIR)/rules.mk

PKG_NAME:=kroks-ubus-generic
PKG_VERSION:=0.0.6-1
PKG_RELEASE:=1

PKG_LICENSE:=4pda
PKG_MAINTAINER:=Kroks <info@kroks.ru>

LUCI_TITLE:=Kroks ubus base module
LUCI_DEPENDS:=+libc +libubox-lua +libubus-lua +libuci-lua +lua-cjson
LUCI_PKGARCH:=all

define Package/kroks-ubus-generic
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Kroks ubus base module
  DEPENDS:= \
	+libc \
	+libubox-lua \
	+libubus-lua \
	+libuci-lua \
	+lua-cjson
endef

include $(TOPDIR)/feeds/luci/luci.mk