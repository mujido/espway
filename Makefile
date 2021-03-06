PROGRAM = espway
SRC_DIR = ./src
PROGRAM_SRC_DIR = $(SRC_DIR) $(SRC_DIR)/lib
PROGRAM_INC_DIR = $(SRC_DIR)
BUILD_DIR = ./build/
FIRMWARE_DIR = ./firmware/

ESPBAUD ?= 115200
FLASH_SIZE ?= 4M
FLASH_MODE ?= qio
FLASH_FREQ ?= 80m
PRINTF_SCANF_FLOAT_SUPPORT ?= 1
SPLIT_SECTIONS ?= 0
WARNINGS_AS_ERRORS ?= 0

N_PROCESSES = 3

EXTRA_COMPONENTS = extras/dhcpserver extras/i2c extras/i2s_dma extras/ws2812_i2s extras/mbedtls extras/httpd

EXTRA_C_CXX_FLAGS = -DLWIP_HTTPD_CGI=1 -DHTTPD_USE_CUSTOM_FSDATA \
	-Isrc -DESP_OPEN_RTOS -DLWIP_HTTPD_SUPPORT_WEBSOCKET=1
EXTRA_CXXFLAGS =

# FLAVOR = debug
# EXTRA_C_CXX_FLAGS += -DLWIP_DEBUG=1 -DHTTPD_DEBUG=LWIP_DBG_ON

include esp-open-rtos/common.mk

ESPTOOL_ARGS = --flash_freq $(FLASH_FREQ) --flash_mode $(FLASH_MODE) --flash_size $(FLASH_SIZE)

HTTPD_DIR = $(LWIP_DIR)apps/http/
FSDATA = $(SRC_DIR)/fsdata_custom.c

all: $(FSDATA)

$(FSDATA): $(HTTPD_DIR)makefsdata/makefsdata.c $(HTTPD_DIR)makefsdata/tinydir.h frontend/src/* 
	cd frontend; npm run build
	tcc -w -I$(lwip_ROOT)include -I$(LWIP_DIR)include -Iesp-open-rtos/core/include \
		-run $< frontend/output -f:$@
	sed -i \
		-e 's!lwip/apps/fs.h!httpd/fs.h!' \
		-e 's!lwip/def.h!httpd/fsdata.h!' \
		-e 's!\<fsdata_!httpd_fsdata_!g' $(FSDATA)

clean: clean-fsdata

clean-fsdata:
	$(Q) rm -f $(FSDATA)

parallel:
	$(MAKE) clean
	$(MAKE) $(FSDATA)
	$(MAKE) -j$(N_PROCESSES) all

flash-only:
	$(ESPTOOL) -p $(ESPPORT) --baud $(ESPBAUD) write_flash $(ESPTOOL_ARGS) \
		0x0 $(RBOOT_BIN) 0x1000 $(RBOOT_CONF) 0x2000 $(FW_FILE) $(SPIFFS_ESPTOOL_ARGS)
