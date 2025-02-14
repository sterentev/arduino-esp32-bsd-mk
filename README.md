# Compile Arduino sketches for ESP32 MCU from command line

This Makefile was inspired by FreeBSD port devel/arduino-bsd-mk
written by Craig Leres.

It allows to build Arduino projects written for ESP32 microcontrollers
from command line (without Arduino IDE).

## Prerequisites

You'll need installation of Espressif's arduino-esp32 package
https://github.com/espressif/arduino-esp32
and their crosstool-NG (i.e. xtensa-esp-elf compiler).

The last could be found in FreeBSD ports in devel/xtensa-esp-elf.
Or you could try other complilers provided by Tomoyuki Sakurai
https://github.com/trombik/xtensa-esp32-elf

## Usage

Include bsd.arduino.esp32.mk into you your Makefile placed in
your sketch directory.

You'll need to do some settings. For example you need to define
your ESP32 board. All boards and their settings are collected
in **boards.txt** file provided by Espressif. It is located under
arduino directory in __hardware/espressif/esp32/boards.txt__.

Compiler options, paths, tools, etc are defined in **platform.txt** file, i.e.
__hardware/espressif/esp32/platform.txt__

Remember you can override settings made by Espressif in **platform.txt**
by adding **platform.local.txt** next to it with your own settings.
This file affects not just your **Makefile** but also Arduino IDE.


### Required settings

In your **Makefile** you'll be need to set following variables:

- **TARGET**		Name of the sketch
- **ARDUINO_BOARD**	Board name (find it in **boards.txt**)
- **ARDUINO_MK_DIR**	Path to [bsd.arduino.esp32.mk](bsd.arduino.esp32.mk) installation

and the inclusion
```
.include "${ARDUINO_MK_DIR}/bsd.arduino.esp32.mk"
```

### Other useful settings

First of all consider to create **obj** subdir in the directory with
your sketch. __make__ command will write all compilation results there.
(Otherwise all such files will be written in your current dir)

**SRCS** - List of .ino, .cpp and .c sources
By default only __<your sketch>.ino__ OR __<your sketch>.cpp__ is assumed.

**ARDUINO_DIR** - Top level of Arduino installation.
Default value is __/usr/local/arduino__

**ARDUINO_LIBS** - List of Arduino libraries. See below.

**ARDUINO_BOARD_CFG** - list of confg menu selections for the board
in the format __<menuA>.<valueA> <menuB>.<valueB> <menuC>.<valueC>__
Available menus and their options are defined in **boards.txt** file.
Example: __PartitionScheme.min_spiffs CPUFreq.40 UploadSpeed.115200__

**ARDUINO_PORT** - Serial port device for programming the board.
Default value is __/dev/cuaU0__


### Libraries

You'll have to list all libraries you used in your sketch (and its
dependencies) in **ARDUINO_LIBS** variable. These libraries will be searched
by __make__ as directory names.

Create subdir **libraries** in your sketch dir and place your sketch
dependencies (which are not a part of arduino and arduino-esp32 installations).

Makefile will be searching for requested libraries in the following dirs:
```
${.CURDIR} ${.CURDIR}/libraries ${ARDUINO_ESP32_DIR}/libraries ${ARDUINO_DIR}/libraries
```

This could be changed by defining **LIB_SEARCH_DIRS** variable in your Makefile.

Note about dirs sequence. In case library exists in several places
(For example there's 2 WiFi libraries in
__hardware/espressif/esp32/libraries/WiFi__ and __arduino/libraries/WiFi__)
The first will be used because __${ARDUINO_ESP32_DIR}/libraries__
precedes __${ARDUINO_DIR}/libraries__


## Targets

Actually you can use **make** to build complete firmware and
**make install** (or **make flash**) to write firmware in your
Arduino board.

Other useful targets are
- **core** - build arduino core
- **libs** - build dependencies of the sketch
- **clean** - clean all compilation results

Have fun!
