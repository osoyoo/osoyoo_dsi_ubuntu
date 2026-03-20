TARGET = osoyoo-panel-dsi
TARGET2 = osoyoo-panel-regulator

KDIR = /lib/modules/$(shell uname -r)/build

PWD = $(shell pwd)

obj-m := $(TARGET).o
obj-m += $(TARGET2).o


default:

	make -C $(KDIR) M=$(PWD) modules

clean:

	$(RM) *.o *.ko *.mod.c Module.symvers modules.order *.mod
