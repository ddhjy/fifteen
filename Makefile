SHELL := /bin/bash

PROJECT ?= fifteen.xcodeproj
SCHEME ?= fifteen
CONFIGURATION ?= Debug
DERIVED_DATA_PATH ?= .build/DerivedData
APP_NAME ?= $(SCHEME)
APP_PATH ?= $(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)-iphoneos/$(APP_NAME).app
DEVICE_FILTER ?= deviceProperties.bootState == 'booted' AND connectionProperties.pairingState == 'paired'
XCODEBUILD_FLAGS ?= -allowProvisioningUpdates -allowProvisioningDeviceRegistration

.PHONY: help build install devices clean

help:
	@printf "Targets:\\n"
	@printf "  make build                      Build for the first connected real device\\n"
	@printf "  make install                    Build and install on the first connected real device\\n"
	@printf "  make devices                    List connected devices detected by devicectl\\n"
	@printf "  make clean                      Remove derived data\\n"
	@printf "\\n"
	@printf "Overrides:\\n"
	@printf "  DEVICE_NAME='My iPhone'         Build/install to a specific device name\\n"
	@printf "  CONFIGURATION=Release           Use a different build configuration\\n"

devices:
	@xcrun devicectl list devices --filter "$(DEVICE_FILTER)"

build:
	@set -euo pipefail; \
	device_name="$(DEVICE_NAME)"; \
	if [[ -z "$$device_name" ]]; then \
		device_name="$$(xcrun devicectl list devices --filter "$(DEVICE_FILTER)" --hide-default-columns --hide-headers --columns Name | sed -n '1p' | sed 's/[[:space:]]*$$//')"; \
	fi; \
	if [[ -z "$$device_name" ]]; then \
		echo "No paired, booted iOS device found. Run 'make devices' or pass DEVICE_NAME='...'" >&2; \
		exit 1; \
	fi; \
	echo "Building $(SCHEME) for $$device_name..."; \
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "platform=iOS,name=$$device_name" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		$(XCODEBUILD_FLAGS) \
		build

install:
	@set -euo pipefail; \
	device_name="$(DEVICE_NAME)"; \
	if [[ -z "$$device_name" ]]; then \
		device_name="$$(xcrun devicectl list devices --filter "$(DEVICE_FILTER)" --hide-default-columns --hide-headers --columns Name | sed -n '1p' | sed 's/[[:space:]]*$$//')"; \
	fi; \
	if [[ -z "$$device_name" ]]; then \
		echo "No paired, booted iOS device found. Run 'make devices' or pass DEVICE_NAME='...'" >&2; \
		exit 1; \
	fi; \
	echo "Building $(SCHEME) for $$device_name..."; \
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "platform=iOS,name=$$device_name" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		$(XCODEBUILD_FLAGS) \
		build; \
	if [[ ! -d "$(APP_PATH)" ]]; then \
		echo "Built app not found at $(APP_PATH)" >&2; \
		exit 1; \
	fi; \
	echo "Installing $(APP_PATH) to $$device_name..."; \
	xcrun devicectl device install app --device "$$device_name" "$(APP_PATH)"

clean:
	@rm -rf "$(DERIVED_DATA_PATH)"
	@build_dir="$$(dirname "$(DERIVED_DATA_PATH)")"; \
	if [[ -d "$$build_dir" ]]; then \
		rmdir "$$build_dir" 2>/dev/null || true; \
	fi
