driver build:
	make
	sudo cp ./osoyoo-panel-regulator.ko /lib/modules/$(uname -r)
	sudo cp ./osoyoo-panel-dsi.ko /lib/modules/$(uname -r)
	sudo depmod
	sudo modprobe osoyoo-panel-regulator 
	sudo modprobe osoyoo-panel-dsi 

device build:
	// 7inch
	sudo dtc -I dts -O dtb -o osoyoo-panel-dsi-7inch.dtbo osoyoo-panel-dsi-7inch.dts
	sudo cp osoyoo-panel-dsi-7inch.dtbo /boot/overlays/
	// 10.1inch
	sudo dtc -I dts -O dtb -o osoyoo-panel-dsi-10inch.dtbo osoyoo-panel-dsi-10inch.dts
	sudo cp osoyoo-panel-dsi-10inch.dtbo /boot/overlays/

config.txt:
	// 7inch
	dtoverlay=osoyoo-panel-dsi-7inch
	// 10.1inch
	dtoverlay=osoyoo-panel-dsi-10inch
	dtoverlay=osoyoo-panel-dsi-10inch,4lane
