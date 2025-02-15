#
# +++ variables +++
#
# Required vars
#
# TARGET		Name of the sketch
# ARDUINO_BOARD		Board name
# ARDUINO_MK_DIR	Path to bsd.arduino.esp32.mk installation
#
# It's frequently useful to set these:
#
# SRCS			List of .ino, .cpp and .c sources
# ARDUINO_DIR		Top level of Arduino installation
# ARDUINO_LIBS		List of Arduino libraries
# ARDUINO_BOARD_CFG	List of cfg menu selections for the board
#					example: "PartitionScheme.min_spiffs CPUFreq.40 UploadSpeed.115200"
# ARDUINO_PORT		Serial port device for programming the board
#					/dev/cuaU0 will be used if not set
#

.if exists(${.CURDIR}/Makefile.inc)
.include "${.CURDIR}/Makefile.inc"
.endif

.if !defined(TARGET)
.error Please define TARGET
.endif

.if !defined(ARDUINO_BOARD)
.error Please define ARDUINO_BOARD
.endif

.if !defined(ARDUINO_MK_DIR)
.error Please define ARDUINO_MK_DIR
.elif !exists(${ARDUINO_MK_DIR})
.error ${ARDUINO_MK_DIR} (ARDUINO_MK_DIR) missing
.endif

# ARDUINO_DIR
PREFIX?=		/usr/local
ARDUINO_PREFIX?=	${PREFIX}
ARDUINO_DIR?=		${ARDUINO_PREFIX}/arduino
.if !exists(${ARDUINO_DIR})
.error ${ARDUINO_DIR} (ARDUINO_DIR) missing
.endif

# ARDUINO_ESP32_DIR
.if empty(ARDUINO_ESP32_DIR)
.if exists(${ARDUINO_DIR}/hardware/espressif/esp32)
ARDUINO_ESP32_DIR=	${ARDUINO_DIR}/hardware/espressif/esp32
.endif
.endif
.if !exists(${ARDUINO_ESP32_DIR})
.error ${ARDUINO_ESP32_DIR} (ARDUINO_ESP32_DIR) missing
.endif

# CFG_SCRIPT and base config
ARDUINO_PORT?=	/dev/cuaU0
EXTRA_CFG?=	build.project_name=${TARGET}\nbuild.path=.\nbuild.source.path=.\nbuild.variant.path=.\nserial.port=${ARDUINO_PORT}
CFG_SCRIPT=	${ARDUINO_MK_DIR}/scripts/arduino-esp32-cfg -d "${ARDUINO_ESP32_DIR}" -c "${EXTRA_CFG}" -m "${ARDUINO_BOARD_CFG}" ${ARDUINO_BOARD}


all:	size

.if !defined(SRCS)
.if exists(${.CURDIR}/${TARGET}.ino)
SRCS=	${TARGET}.ino
.else
SRCS=	${TARGET}.cpp
.endif
.endif

INCLS?=	-I. -I${.CURDIR}


.PHONY: precore core postcore libs size flash install pkg defines

${TARGET}.partitions.bin:
	${:!${CFG_SCRIPT} recipe.hooks.prebuild.1.pattern!}
	${:!${CFG_SCRIPT} recipe.hooks.prebuild.2.pattern!}
	${:!${CFG_SCRIPT} recipe.hooks.prebuild.3.pattern!}
	${:!${CFG_SCRIPT} recipe.objcopy.partitions.bin.pattern!}
CLEANFILES+=	partitions.csv ${TARGET}.partitions.bin ${TARGET}.map

${TARGET}.bootloader.bin:
	${:!${CFG_SCRIPT} recipe.hooks.prebuild.4.pattern!}
CLEANFILES+=	${TARGET}.bootloader.bin

build_opt.h:
	${:!${CFG_SCRIPT} recipe.hooks.prebuild.5.pattern!}
	${:!${CFG_SCRIPT} recipe.hooks.prebuild.6.pattern!}
CLEANFILES+=	build_opt.h

file_opts:
	${:!${CFG_SCRIPT} recipe.hooks.prebuild.7.pattern!}
CLEANFILES+=	file_opts

sdkconfig:
	${:!${CFG_SCRIPT} recipe.hooks.prebuild.8.pattern!}
CLEANFILES+=	sdkconfig



precore:
	${:!${CFG_SCRIPT} recipe.hooks.core.prebuild.1.pattern!}

postcore:
	${:!${CFG_SCRIPT} recipe.hooks.core.postbuild.1.pattern!}



.SUFFIXES: .cpp .c

INCLS+=		-I${ARDUINO_ESP32_DIR}/variants/${ARDUINO_BOARD}

CORE_SRCS=	${:!find ${ARDUINO_ESP32_DIR}/cores/esp32 -type f \( -name '*.c' -o -name '*.cpp' \) || true!}
.PATH:		${CORE_SRCS:H:O:u}
INCLS+=		${CORE_SRCS:H:O:u:C/^/-I/}
CORE_OBJS=	${CORE_SRCS:T:R:S/$/.o/g}
CLEANFILES+=	${CORE_OBJS}


LIB_SEARCH_DIRS?=	${.CURDIR} ${.CURDIR}/libraries ${ARDUINO_ESP32_DIR}/libraries ${ARDUINO_DIR}/libraries

LIB_SRCS=	${:!${ARDUINO_MK_DIR}/scripts/arduino-libsrcs-finder "${LIB_SEARCH_DIRS}" "${ARDUINO_LIBS}"!}
.PATH:		${LIB_SRCS:H:O:u}
LIB_OBJS=	${LIB_SRCS:T:R:S/$/.o/g}
INCLS+=		${:!${ARDUINO_MK_DIR}/scripts/arduino-libsrcs-finder -H "${LIB_SEARCH_DIRS}" "${ARDUINO_LIBS}"!:H:O:u:C/^/-I/}
CLEANFILES+=	${LIB_OBJS}

core:   core.a

# Don't use recipe.ar.pattern, it's  one-by-one archiver
core.a:         build_opt.h file_opts sdkconfig precore .WAIT ${CORE_OBJS} .WAIT postcore
	rm -f ${.TARGET}
	${:!${CFG_SCRIPT} compiler.path!}${:!${CFG_SCRIPT} compiler.ar.cmd!} \
	    ${:!${CFG_SCRIPT} compiler.ar.flags!} ${:!${CFG_SCRIPT} compiler.ar.extra_flags!} \
	    ${.TARGET} ${CORE_OBJS}
CLEANFILES+=	core.a


libs:           build_opt.h file_opts sdkconfig .WAIT ${LIB_OBJS}

${TARGET}.o:    build_opt.h file_opts sdkconfig

${TARGET}.bin:  ${TARGET}.partitions.bin ${TARGET}.bootloader.bin ${TARGET}.o libs core.a
	${:!${ARDUINO_MK_DIR}/scripts/arduino-esp32-cfg -d "${ARDUINO_ESP32_DIR}" -m "${ARDUINO_BOARD_CFG}" \
	    -c "${EXTRA_CFG}\nobject_files=${TARGET}.o ${LIB_OBJS}\narchive_file_path=core.a" \
	    ${ARDUINO_BOARD} recipe.c.combine.pattern!}
	${:!${CFG_SCRIPT} recipe.objcopy.bin.pattern!}
	${:!${CFG_SCRIPT} recipe.hooks.objcopy.postobjcopy.1.pattern!}
	${:!${CFG_SCRIPT} recipe.hooks.objcopy.postobjcopy.2.pattern!}
	${:!${CFG_SCRIPT} recipe.hooks.objcopy.postobjcopy.3.pattern!}

CLEANFILES+=	${TARGET}.o ${TARGET}.elf ${TARGET}.bin ${TARGET}.merged.bin


# .cpp to .o
.cpp.o:
	${:!${ARDUINO_MK_DIR}/scripts/arduino-esp32-cfg -d "${ARDUINO_ESP32_DIR}" \
	    -c "${EXTRA_CFG}\nincludes=${INCLS}\nsource_file=${.IMPSRC}\nobject_file=${.TARGET}" \
	    -m "${ARDUINO_BOARD_CFG}" ${ARDUINO_BOARD} recipe.cpp.o.pattern!}

# .c to .o
.c.o:
	${:!${ARDUINO_MK_DIR}/scripts/arduino-esp32-cfg -d "${ARDUINO_ESP32_DIR}" \
	    -c "${EXTRA_CFG}\nincludes=${INCLS}\nsource_file=${.IMPSRC}\nobject_file=${.TARGET}" \
	    -m "${ARDUINO_BOARD_CFG}" ${ARDUINO_BOARD} recipe.c.o.pattern!}


# .ino cleanup
.SUFFIXES: .ino

# Cleanup .cpp when .ino exists
.for _INOSRC in ${SRCS:M*.ino:N*/*}
.for _CPPSRC in ${_INOSRC:R}.cpp
# cleanup
CLEANFILES+=	${.OBJDIR}/${_CPPSRC}
.endfor
.endfor

# Disallow .ino when .cpp exists
.for _CPPSRC in ${SRCS:M*.cpp:N*/*}
.for _INOSRC in ${_CPPSRC:R}.ino
.if exists(${.CURDIR}/${_INOSRC}) && exists(${.CURDIR}/${_CPPSRC})
.error Both ${_CPPSRC} and ${_INOSRC} exist
.endif
.endfor
.endfor

# ino to cpp transformation
.ino.cpp:
	${ECHO} rm -f ${.IMPSRC:T:R}.cpp
	${ECHO} '#include <Arduino.h>' > ${.IMPSRC:T:R}.cpp
	${ECHO} '#line 1 "${.IMPSRC:T:R}.ino"' >> ${.IMPSRC:T:R}.cpp
	cat ${.IMPSRC} >> ${.IMPSRC:T:R}.cpp


SIZE_CMD=	${:!${CFG_SCRIPT} recipe.size.pattern!}
MAXSIZE=	${:!${CFG_SCRIPT} upload.maximum_size!}
MAXDATASIZE=	${:!${CFG_SCRIPT} upload.maximum_data_size!}

# Don't use recipe.size.regex (broken)
size: ${TARGET}.bin
	@SIZE=`${SIZE_CMD} | awk -F ' ' '/^(\.iram0\.text|\.iram0\.vectors|\.dram0\.data|\.flash\.text|\.flash\.rodata)[[:space:]]+/{ print $$2 }' | paste -sd+ - | bc`; \
	    printf "\nSketch uses %i bytes (%s%%) of program storage space. Maximum is %i bytes.\n" \
	        $${SIZE} $$(( $${SIZE}*100/${MAXSIZE} )) ${MAXSIZE}
	@SIZE=`${SIZE_CMD} | awk -F ' ' '/^(\.dram0\.data|\.dram0\.bss|\.noinit)[[:space:]]+/{ print $$2 }' | paste -sd+ - | bc`; \
	    printf "Global variables use %i bytes (%s%%) of dynamic memory, leaving %i bytes for local variables. Maximum is %i bytes.\n" \
	        $${SIZE} $$(( $${SIZE}*100/${MAXDATASIZE} ))  $$(( ${MAXDATASIZE}-$${SIZE} ))  ${MAXDATASIZE}


UPLOAD_PATTERN=	${:!${CFG_SCRIPT} tools.esptool_py.path!}/${:!${CFG_SCRIPT} tools.esptool_py.cmd!} ${:!${CFG_SCRIPT} tools.esptool_py.upload.pattern_args!}

# Upload sketch
flash: ${TARGET}.bin
	${UPLOAD_PATTERN}

# alias
install: flash

PKG_DIR?=	${.CURDIR}/pkg

# pkg: create dir with upload script and required data
pkg: ${TARGET}.bin
	@${ARDUINO_MK_DIR}/scripts/pkg-results '${PKG_DIR}' '${TARGET}' '${UPLOAD_PATTERN}'


# defines: dump out all including the board specifc ones
defines:
	${:!${CFG_SCRIPT} compiler.path!}${:!${CFG_SCRIPT} compiler.c.cmd!}   -dM -E - < /dev/null | sort

# Cleaning up
clean:
	rm -f ${CLEANFILES}
