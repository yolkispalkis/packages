include $(TOPDIR)/rules.mk

PKG_NAME:=kroks-modemhalt
PKG_VERSION:=0.0.6-1
PKG_RELEASE:=1

PKG_LICENSE:=4pda
PKG_MAINTAINER:=Kroks <info@kroks.ru>

LUCI_TITLE:=This package contains an service for halting builting modems.
LUCI_DEPENDS:=+libc
LUCI_PKGARCH:=all

define Package/kroks-modemhalt
  SECTION:=net
  CATEGORY:=Network
  TITLE:=This package contains an service for halting builting modems.
  DEPENDS:= \
	+libc
endef

include $(TOPDIR)/feeds/luci/luci.mk