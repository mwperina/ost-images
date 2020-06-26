# This can be overriden by running with 'make DISTRO=...'
DISTRO := el8

# Accepts both ISOs and repo urls, can be overriden by running with 'make INSTALL_URL=...'
INSTALL_URL := "http://isoredirect.centos.org/centos/8/isos/x86_64/CentOS-8.2.2004-x86_64-dvd1.iso"

# The url of root of repos, can be overriden by running with 'make REPO_ROOT=...'
REPO_ROOT := "http://mirror.centos.org/centos/8/"

# Whitespace-separated list of extra repos to be added when building
# '{engine-host}-installed' layers. This allows customizing these top
# layers with custom-built artifacts.
EXTRA_REPOS :=

# Empty string when using repo-based installs, ".iso" otherwise
_USING_ISO := $(findstring .iso,$(INSTALL_URL))

# On/off switches for building layers. These options should have
# sensible defaults i.e. if you have 'ost-images-el8-base' package installed,
# then the default is not to build the base package.
# Can be overriden by running with i.e. 'make BUILD_BASE=...'.
# Any non-empty string will be treated as true and an empty string is treated as false.
# Only removing layers from the bottom is supported - you can't i.e.
# build the "base" layer, but skip the "upgrade" layer.
BUILD_BASE := $(if $(_USING_ISO),$(findstring not installed,$(shell rpm -q $(PACKAGE_NAME)-$(DISTRO)-base)),yes)
BUILD_UPGRADE := $(if $(BUILD_BASE),yes,$(findstring not installed,$(shell rpm -q $(PACKAGE_NAME)-$(DISTRO)-upgrade)))
BUILD_ENGINE_DEPS_INSTALLED := $(if $(BUILD_UPGRADE),yes,$(findstring not installed,$(shell rpm -q $(PACKAGE_NAME)-$(DISTRO)-engine-deps-installed)))
BUILD_HOST_DEPS_INSTALLED := $(if $(BUILD_UPGRADE),yes,$(findstring not installed,$(shell rpm -q $(PACKAGE_NAME)-$(DISTRO)-host-deps-installed)))

# The logic to decide if we should build '{engine,host}-installed'
# layers is a bit different. If the 'upgrade' layer is marked to be built,
# then we assume that '{engine,host}-installed' layers are also desired.
# If the 'upgrade' layer is preinstalled we have two more cases - the first
# one is when the 'EXTRA_REPOS' variable is empty, in which we also should
# built the layer (think of a nightly CI job that rebuilds the images without
# any custom repos). The second case is when 'EXTRA_REPOS' variable contains
# some URLs. Then, we use a simple script to go over the repos and see if there
# are any host/engine-related packages available (think of a user who i.e. needs
# to test a custom 'vdsm' build - no need to built the 'engine-installed' layer).
# Finally, if 'EXTRA_REPOS' is non-empty, but the script didn't found any host/engine-related
# packages in the repos an error is reported.
BUILD_ENGINE_INSTALLED := $(if $(BUILD_ENGINE_DEPS_INSTALLED),yes,$(if $(EXTRA_REPOS),$(shell ./helpers/find-packages-in-repo.sh tested-engine-packages.txt '$(EXTRA_REPOS)'),yes))
BUILD_HOST_INSTALLED := $(if $(BUILD_HOST_DEPS_INSTALLED),yes,$(if $(EXTRA_REPOS),$(shell ./helpers/find-packages-in-repo.sh tested-host-packages.txt '$(EXTRA_REPOS)'),yes))

$(if $(BUILD_ENGINE_INSTALLED),,$(if $(BUILD_HOST_INSTALLED),,$(error "Extra repos passed, but couldn't find any {engine,host}-related packages inside. Nothing to build.")))

# When using preinstalled images these point to prefixes
# of installed RPMs (usually '/usr/share/ost-images'), otherwise
# they're empty strings.
_BASE_IMAGE_PREFIX := $(if $(BUILD_BASE),,$(shell rpm -q --queryformat '%{INSTPREFIXES}' $(PACKAGE_NAME)-$(DISTRO)-base)/$(PACKAGE_NAME)/)
_UPGRADE_IMAGE_PREFIX := $(if $(BUILD_UPGRADE),,$(shell rpm -q --queryformat '%{INSTPREFIXES}' $(PACKAGE_NAME)-$(DISTRO)-upgrade)/$(PACKAGE_NAME)/)
_ENGINE_DEPS_INSTALLED_IMAGE_PREFIX := $(if $(BUILD_ENGINE_DEPS_INSTALLED),,$(shell rpm -q --queryformat '%{INSTPREFIXES}' $(PACKAGE_NAME)-$(DISTRO)-engine-deps-installed)/$(PACKAGE_NAME)/)
_HOST_DEPS_INSTALLED_IMAGE_PREFIX := $(if $(BUILD_HOST_DEPS_INSTALLED),,$(shell rpm -q --queryformat '%{INSTPREFIXES}' $(PACKAGE_NAME)-$(DISTRO)-host-deps-installed)/$(PACKAGE_NAME)/)

# When using preinstalled images these have the values of the RPM versions,
# otherwise they're empty strings. We need these in the spec to define proper dependencies.
_BASE_IMAGE_VERSION := $(if $(BUILD_BASE),,$(shell rpm -q --queryformat '%{VERSION}-%{RELEASE}' $(PACKAGE_NAME)-$(DISTRO)-base))
_UPGRADE_IMAGE_VERSION := $(if $(BUILD_UPGRADE),,$(shell rpm -q --queryformat '%{VERSION}-%{RELEASE}' $(PACKAGE_NAME)-$(DISTRO)-upgrade))
_ENGINE_DEPS_INSTALLED_IMAGE_VERSION := $(if $(BUILD_ENGINE_DEPS_INSTALLED),,$(shell rpm -q --queryformat '%{VERSION}-%{RELEASE}' $(PACKAGE_NAME)-$(DISTRO)-engine-deps-installed))
_HOST_DEPS_INSTALLED_IMAGE_VERSION := $(if $(BUILD_HOST_DEPS_INSTALLED),,$(shell rpm -q --queryformat '%{VERSION}-%{RELEASE}' $(PACKAGE_NAME)-$(DISTRO)-host-deps-installed))

# Whether to build a real upgrade layer. Upgrade layer doesn't really make
# sense in scenarios where you build from nightly repos.
# Can be overriden by running with 'make DUMMY_UPGRADE=...'. Any non-empty
# string will be treated as true and an empty string as false.
DUMMY_UPGRADE := $(if $(_USING_ISO),,yes)

# These variables point to scripts that provision "engine-installed"
# and "host-installed" layers. Can be overriden by running with i.e. 'make PROVISION_HOST_SCRIPT=...'
PROVISION_ENGINE_DEPS_SCRIPT := $(DISTRO)-provision-engine-deps.sh.in
PROVISION_HOST_DEPS_SCRIPT := $(DISTRO)-provision-host-deps.sh.in
PROVISION_ENGINE_SCRIPT := $(DISTRO)-provision-engine.sh.in
PROVISION_HOST_SCRIPT := $(DISTRO)-provision-host.sh.in

# This resolves to either smth like 'el8.iso' for ISOs or url for repository urls
_LOCATION := $(if $(_USING_ISO),$(DISTRO).iso,$(INSTALL_URL))
