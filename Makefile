PROJECT=t9500
SOURCES=$(PROJECT).c
MMCU=atmega328
F_CPU = 10000000

CFLAGS=-mmcu=$(MMCU) -Wall -Os -DF_CPU=$(F_CPU)

$(PROJECT).hex: $(PROJECT).out
	avr-objcopy -O ihex $(PROJECT).out $(PROJECT).c.hex;\
	avr-size --mcu=$(MMCU) --format=avr $(PROJECT).out
 
$(PROJECT).out: $(SOURCES)
	avr-gcc $(CFLAGS) -I./ -o $(PROJECT).out $(SOURCES)

upload: $(PROJECT).hex
	avrdude -p m328p  -cusbtiny -U flash:w:$(PROJECT).c.hex

# /Users/flux/Library/Arduino15/packages/arduino/tools/avrdude/6.3.0-arduino17/bin/avrdude -C/Users/flux/Library/Arduino15/packages/arduino/tools/avrdude/6.3.0-arduino17/etc/avrdude.conf -v -patmega328p -cusbtiny -Uflash:w:/var/folders/_9/f38mbm3d1cjdlkfhy2h6nb3h0000gn/T/arduino_build_106805/sketch_feb06a.ino.hex:i 