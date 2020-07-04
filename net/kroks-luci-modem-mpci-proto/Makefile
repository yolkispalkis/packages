include $(TOPDIR)/rules.mk

PKG_NAME:=kroks-luci-modem-mpci-proto
PKG_VERSION:=0.0.6-1
PKG_RELEASE:=1

PKG_LICENSE:=4pda
PKG_MAINTAINER:=Kroks <info@kroks.ru>

LUCI_TITLE:=Support for modemmanager proto
LUCI_DEPENDS:=+libc +kroks-ubus-dev-modem
LUCI_PKGARCH:=all

define Package/kroks-luci-modem-mpci-proto
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Support for modemmanager proto
  DEPENDS:= \
	+libc \
	+kroks-ubus-dev-modem
endef

include $(TOPDIR)/feeds/luci/luci.mk