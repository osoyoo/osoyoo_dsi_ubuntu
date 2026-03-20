
#include <linux/delay.h>
#include <linux/device.h>
#include <linux/err.h>
#include <linux/errno.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/of.h>

#include <linux/gpio/consumer.h>
#include <linux/regulator/consumer.h>

#include <drm/drm_mipi_dsi.h>
#include <drm/drm_modes.h>
#include <drm/drm_panel.h>

#include <video/mipi_display.h>

enum panel_cmd_type {
	_SWITCH_PAGE,
	_INIT_COMMAND,
};

struct panel_init_config {
	enum panel_cmd_type type;
	u8 cmd;
	u8 data;
};

struct osoyoo_desc {
	const struct panel_init_config *init;
	const size_t init_length;
	const struct drm_display_mode *mode;
	const unsigned long mode_flags;
	unsigned int lanes;
};

struct osoyoo_panel {
	struct drm_panel panel;
	struct mipi_dsi_device *dsi;
	const struct osoyoo_desc *desc;
	struct gpio_desc *reset;
	struct regulator *power;
	enum drm_panel_orientation orientation;
};

#define PANEL_SWITCH_PAGE(_page)	\
	{				\
		.type = _SWITCH_PAGE,	\
		.cmd = (_page), 	\
	}

#define PANEL_INIT_CMD(_cmd, _data)	\
	{				\
		.type = _INIT_COMMAND,	\
		.cmd = (_cmd),		\
		.data = (_data),	\
	}

static const struct panel_init_config osoyoo_7_0_inch_init[] = {
	PANEL_SWITCH_PAGE(3),
	PANEL_INIT_CMD(0x01, 0x00),
	PANEL_INIT_CMD(0x02, 0x00),
	PANEL_INIT_CMD(0x03, 0x73),
	PANEL_INIT_CMD(0x04, 0x00),
	PANEL_INIT_CMD(0x05, 0x00),
	PANEL_INIT_CMD(0x06, 0x0A),
	PANEL_INIT_CMD(0x07, 0x00),
	PANEL_INIT_CMD(0x08, 0x00),
	PANEL_INIT_CMD(0x09, 0x00),
	PANEL_INIT_CMD(0x0a, 0x00),
	PANEL_INIT_CMD(0x0b, 0x00),
	PANEL_INIT_CMD(0x0c, 0x01),
	PANEL_INIT_CMD(0x0d, 0x00),
	PANEL_INIT_CMD(0x0e, 0x00),
	PANEL_INIT_CMD(0x0f, 0x17),
	PANEL_INIT_CMD(0x10, 0x17),
	PANEL_INIT_CMD(0x11, 0x00),
	PANEL_INIT_CMD(0x12, 0x00),
	PANEL_INIT_CMD(0x13, 0x00),
	PANEL_INIT_CMD(0x14, 0x00),
	PANEL_INIT_CMD(0x15, 0x00),
	PANEL_INIT_CMD(0x16, 0x00),
	PANEL_INIT_CMD(0x17, 0x00),
	PANEL_INIT_CMD(0x18, 0x00),
	PANEL_INIT_CMD(0x19, 0x00),
	PANEL_INIT_CMD(0x1a, 0x00),
	PANEL_INIT_CMD(0x1b, 0x00),
	PANEL_INIT_CMD(0x1c, 0x00),
	PANEL_INIT_CMD(0x1d, 0x00),
	PANEL_INIT_CMD(0x1e, 0x40),
	PANEL_INIT_CMD(0x1f, 0x80),
	PANEL_INIT_CMD(0x20, 0x06),
	PANEL_INIT_CMD(0x21, 0x01),
	PANEL_INIT_CMD(0x22, 0x00),
	PANEL_INIT_CMD(0x23, 0x00),
	PANEL_INIT_CMD(0x24, 0x00),
	PANEL_INIT_CMD(0x25, 0x00),
	PANEL_INIT_CMD(0x26, 0x00),
	PANEL_INIT_CMD(0x27, 0x00),
	PANEL_INIT_CMD(0x28, 0x33),
	PANEL_INIT_CMD(0x29, 0x03),
	PANEL_INIT_CMD(0x2a, 0x00),
	PANEL_INIT_CMD(0x2b, 0x00),
	PANEL_INIT_CMD(0x2c, 0x00),
	PANEL_INIT_CMD(0x2d, 0x00),
	PANEL_INIT_CMD(0x2e, 0x00),
	PANEL_INIT_CMD(0x2f, 0x00),
	PANEL_INIT_CMD(0x30, 0x00),
	PANEL_INIT_CMD(0x31, 0x00),
	PANEL_INIT_CMD(0x32, 0x00),
	PANEL_INIT_CMD(0x33, 0x00),
	PANEL_INIT_CMD(0x34, 0x04),
	PANEL_INIT_CMD(0x35, 0x00),
	PANEL_INIT_CMD(0x36, 0x00),
	PANEL_INIT_CMD(0x37, 0x00),
	PANEL_INIT_CMD(0x38, 0x3C),
	PANEL_INIT_CMD(0x39, 0x00),
	PANEL_INIT_CMD(0x3a, 0x00),
	PANEL_INIT_CMD(0x3b, 0x00),
	PANEL_INIT_CMD(0x3c, 0x00),
	PANEL_INIT_CMD(0x3d, 0x00),
	PANEL_INIT_CMD(0x3e, 0x00),
	PANEL_INIT_CMD(0x3f, 0x00),
	PANEL_INIT_CMD(0x40, 0x00),
	PANEL_INIT_CMD(0x41, 0x00),
	PANEL_INIT_CMD(0x42, 0x00),
	PANEL_INIT_CMD(0x43, 0x00),
	PANEL_INIT_CMD(0x44, 0x00),
	PANEL_INIT_CMD(0x50, 0x10),
	PANEL_INIT_CMD(0x51, 0x32),
	PANEL_INIT_CMD(0x52, 0x54),
	PANEL_INIT_CMD(0x53, 0x76),
	PANEL_INIT_CMD(0x54, 0x98),
	PANEL_INIT_CMD(0x55, 0xba),
	PANEL_INIT_CMD(0x56, 0x10),
	PANEL_INIT_CMD(0x57, 0x32),
	PANEL_INIT_CMD(0x58, 0x54),
	PANEL_INIT_CMD(0x59, 0x76),
	PANEL_INIT_CMD(0x5a, 0x98),
	PANEL_INIT_CMD(0x5b, 0xba),
	PANEL_INIT_CMD(0x5c, 0xdc),
	PANEL_INIT_CMD(0x5d, 0xfe),
	PANEL_INIT_CMD(0x5e, 0x00),
	PANEL_INIT_CMD(0x5f, 0x0e), // GCL
	PANEL_INIT_CMD(0x60, 0x0f), // VSD
	PANEL_INIT_CMD(0x61, 0x0c), // STV3
	PANEL_INIT_CMD(0x62, 0x0d), // STV1
	PANEL_INIT_CMD(0x63, 0x06), // CKL1
	PANEL_INIT_CMD(0x64, 0x07), // CKL3
	PANEL_INIT_CMD(0x65, 0x02), // CKL5
	PANEL_INIT_CMD(0x66, 0x02), // CKL7
	PANEL_INIT_CMD(0x67, 0x02),
	PANEL_INIT_CMD(0x68, 0x02),
	PANEL_INIT_CMD(0x69, 0x01),
	PANEL_INIT_CMD(0x6a, 0x00),
	PANEL_INIT_CMD(0x6b, 0x02),
	PANEL_INIT_CMD(0x6c, 0x15),
	PANEL_INIT_CMD(0x6d, 0x14),
	PANEL_INIT_CMD(0x6e, 0x02),
	PANEL_INIT_CMD(0x6f, 0x02),
	PANEL_INIT_CMD(0x70, 0x02), // VGL
	PANEL_INIT_CMD(0x71, 0x02), // VGL
	PANEL_INIT_CMD(0x72, 0x02), // VGL
	PANEL_INIT_CMD(0x73, 0x02), // GCH
	PANEL_INIT_CMD(0x74, 0x02), // VDS
	PANEL_INIT_CMD(0x75, 0x0e),
	PANEL_INIT_CMD(0x76, 0x0f),
	PANEL_INIT_CMD(0x77, 0x0c),
	PANEL_INIT_CMD(0x78, 0x0d),
	PANEL_INIT_CMD(0x79, 0x06),
	PANEL_INIT_CMD(0x7a, 0x07),
	PANEL_INIT_CMD(0x7b, 0x02),
	PANEL_INIT_CMD(0x7c, 0x02),
	PANEL_INIT_CMD(0x7d, 0x02),
	PANEL_INIT_CMD(0x7e, 0x02),
	PANEL_INIT_CMD(0x7f, 0x01),
	PANEL_INIT_CMD(0x80, 0x00),
	PANEL_INIT_CMD(0x81, 0x02),
	PANEL_INIT_CMD(0x82, 0x14),
	PANEL_INIT_CMD(0x83, 0x15),
	PANEL_INIT_CMD(0x84, 0x02),
	PANEL_INIT_CMD(0x85, 0x02),
	PANEL_INIT_CMD(0x86, 0x02),
	PANEL_INIT_CMD(0x87, 0x02),
	PANEL_INIT_CMD(0x88, 0x02),
	PANEL_INIT_CMD(0x89, 0x02),
	PANEL_INIT_CMD(0x8A, 0x02),

	PANEL_SWITCH_PAGE(4),
	PANEL_INIT_CMD(0x6C, 0x15),
	PANEL_INIT_CMD(0x6E, 0x2A), // di_pwr_reg=0 VGH clamp 1A=>12.13V 2A=15V
	PANEL_INIT_CMD(0x6F, 0x37), // reg vcl + pumping ratio VGH=2.5x VGL=-3x
	PANEL_INIT_CMD(0x3B, 0x98),
	PANEL_INIT_CMD(0x3a, 0x94), // Power Saving
	PANEL_INIT_CMD(0x8D, 0x1F), // VGL Clamp -12V
	PANEL_INIT_CMD(0x87, 0xBA),
	PANEL_INIT_CMD(0x26, 0x76),
	PANEL_INIT_CMD(0xB2, 0xD1),
	PANEL_INIT_CMD(0xB5, 0x06),
	PANEL_INIT_CMD(0x38, 0x01),
	PANEL_INIT_CMD(0x39, 0x00),

	PANEL_SWITCH_PAGE(1),
	PANEL_INIT_CMD(0xB7, 0x03), // EN 2LANE
	PANEL_INIT_CMD(0x22, 0x0A), // BGR,SS,GS
	PANEL_INIT_CMD(0x2E, 0xC8), // 1280 GATE Numble
	PANEL_INIT_CMD(0x31, 0x00), // Column inversion
	PANEL_INIT_CMD(0x53, 0x5d), // VCOM1 
	PANEL_INIT_CMD(0x55, 0x5d), // VCOM2
	PANEL_INIT_CMD(0x40, 0x33), // Pump VGH_DC 8T 
	PANEL_INIT_CMD(0x50, 0x85), // VREG1OUT= 4.30V
	PANEL_INIT_CMD(0x51, 0x85), // VREG2OUT=-4.36V
	PANEL_INIT_CMD(0x60, 0x26), // SDT
	PANEL_INIT_CMD(0xA0, 0x08), // VP255 Gamma P
	PANEL_INIT_CMD(0xA1, 0x0B), // VP251
	PANEL_INIT_CMD(0xA2, 0x18), // VP247
	PANEL_INIT_CMD(0xA3, 0x15), // VP243
	PANEL_INIT_CMD(0xA4, 0x16), // VP239
	PANEL_INIT_CMD(0xA5, 0x29), // VP231
	PANEL_INIT_CMD(0xA6, 0x1E), // VP219
	PANEL_INIT_CMD(0xA7, 0x1E), // VP203
	PANEL_INIT_CMD(0xA8, 0x57), // VP175
	PANEL_INIT_CMD(0xA9, 0x1C), // VP144
	PANEL_INIT_CMD(0xAA, 0x2A), // VP111
	PANEL_INIT_CMD(0xAB, 0x43), // VP80
	PANEL_INIT_CMD(0xAC, 0x1F), // VP52
	PANEL_INIT_CMD(0xAD, 0x20), // VP36
	PANEL_INIT_CMD(0xAE, 0x52), // VP24
	PANEL_INIT_CMD(0xAF, 0x2A), // VP16
	PANEL_INIT_CMD(0xB0, 0x30), // VP12
	PANEL_INIT_CMD(0xB1, 0x32), // VP8
	PANEL_INIT_CMD(0xB2, 0x60), // VP4
	PANEL_INIT_CMD(0xB3, 0x39), // VP0
	PANEL_INIT_CMD(0xC0, 0x08), // VN255 GAMMA N
	PANEL_INIT_CMD(0xC1, 0x24), // VN251
	PANEL_INIT_CMD(0xC2, 0x2E), // VN247
	PANEL_INIT_CMD(0xC3, 0x0D), // VN243
	PANEL_INIT_CMD(0xC4, 0x12), // VN239
	PANEL_INIT_CMD(0xC5, 0x23), // VN231
	PANEL_INIT_CMD(0xC6, 0x18), // VN219
	PANEL_INIT_CMD(0xC7, 0x1B), // VN203
	PANEL_INIT_CMD(0xC8, 0x85), // VN175
	PANEL_INIT_CMD(0xC9, 0x1B), // VN144
	PANEL_INIT_CMD(0xCA, 0x27), // VN111
	PANEL_INIT_CMD(0xCB, 0x75), // VN80
	PANEL_INIT_CMD(0xCC, 0x1a), // VN52
	PANEL_INIT_CMD(0xCD, 0x18), // VN36
	PANEL_INIT_CMD(0xCE, 0x50), // VN24
	PANEL_INIT_CMD(0xCF, 0x22), // VN16
	PANEL_INIT_CMD(0xD0, 0x22), // VN12
	PANEL_INIT_CMD(0xD1, 0x50), // VN8
	PANEL_INIT_CMD(0xD2, 0x67), // VN4
	PANEL_INIT_CMD(0xD3, 0x39), // VN0
};

static const struct panel_init_config osoyoo_10_1_inch_2lane_init[] = {
	PANEL_SWITCH_PAGE(3),
	PANEL_INIT_CMD(0x01, 0x00),
	PANEL_INIT_CMD(0x02, 0x00),
	PANEL_INIT_CMD(0x03, 0x53),
	PANEL_INIT_CMD(0x04, 0xD3),
	PANEL_INIT_CMD(0x05, 0x00),
	PANEL_INIT_CMD(0x06, 0x0D),
	PANEL_INIT_CMD(0x07, 0x08),       
	PANEL_INIT_CMD(0x08, 0x00),
	PANEL_INIT_CMD(0x09, 0x00),
	PANEL_INIT_CMD(0x0a, 0x00),
	PANEL_INIT_CMD(0x0b, 0x00),
	PANEL_INIT_CMD(0x0c, 0x00),
	PANEL_INIT_CMD(0x0d, 0x00),  
	PANEL_INIT_CMD(0x0e, 0x00), 
	PANEL_INIT_CMD(0x0f, 0x28),      
	PANEL_INIT_CMD(0x10, 0x28), 
	PANEL_INIT_CMD(0x11, 0x00),      
	PANEL_INIT_CMD(0x12, 0x00),  
	PANEL_INIT_CMD(0x13, 0x00),
	PANEL_INIT_CMD(0x14, 0x00),
	PANEL_INIT_CMD(0x15, 0x00),
	PANEL_INIT_CMD(0x16, 0x00),
	PANEL_INIT_CMD(0x17, 0x00), 
	PANEL_INIT_CMD(0x18, 0x00), 
	PANEL_INIT_CMD(0x19, 0x00),
	PANEL_INIT_CMD(0x1a, 0x00),
	PANEL_INIT_CMD(0x1b, 0x00),
	PANEL_INIT_CMD(0x1c, 0x00),
	PANEL_INIT_CMD(0x1d, 0x00),
	PANEL_INIT_CMD(0x1e, 0x40),
	PANEL_INIT_CMD(0x1f, 0x80), 
	PANEL_INIT_CMD(0x20, 0x06),
	PANEL_INIT_CMD(0x21, 0x01),
	PANEL_INIT_CMD(0x22, 0x00), 
	PANEL_INIT_CMD(0x23, 0x00),
	PANEL_INIT_CMD(0x24, 0x00), 
	PANEL_INIT_CMD(0x25, 0x00),
	PANEL_INIT_CMD(0x26, 0x00),
	PANEL_INIT_CMD(0x27, 0x00),
	PANEL_INIT_CMD(0x28, 0x33),
	PANEL_INIT_CMD(0x29, 0x33),
	PANEL_INIT_CMD(0x2a, 0x00),
	PANEL_INIT_CMD(0x2b, 0x00),
	PANEL_INIT_CMD(0x2c, 0x00),
	PANEL_INIT_CMD(0x2d, 0x00),
	PANEL_INIT_CMD(0x2e, 0x00),   
	PANEL_INIT_CMD(0x2f, 0x00),
	PANEL_INIT_CMD(0x30, 0x00),
	PANEL_INIT_CMD(0x31, 0x00),
	PANEL_INIT_CMD(0x32, 0x00),
	PANEL_INIT_CMD(0x33, 0x00),
	PANEL_INIT_CMD(0x34, 0x03),
	PANEL_INIT_CMD(0x35, 0x00),             
	PANEL_INIT_CMD(0x36, 0x00),
	PANEL_INIT_CMD(0x37, 0x00),       
	PANEL_INIT_CMD(0x38, 0x96), 
	PANEL_INIT_CMD(0x39, 0x00),
	PANEL_INIT_CMD(0x3a, 0x00), 
	PANEL_INIT_CMD(0x3b, 0x00),
	PANEL_INIT_CMD(0x3c, 0x00),
	PANEL_INIT_CMD(0x3d, 0x00),
	PANEL_INIT_CMD(0x3e, 0x00),
	PANEL_INIT_CMD(0x3f, 0x00),
	PANEL_INIT_CMD(0x40, 0x00),
	PANEL_INIT_CMD(0x41, 0x00),
	PANEL_INIT_CMD(0x42, 0x00),
	PANEL_INIT_CMD(0x43, 0x00),  
	PANEL_INIT_CMD(0x44, 0x00),
	PANEL_INIT_CMD(0x50, 0x00),
	PANEL_INIT_CMD(0x51, 0x23),
	PANEL_INIT_CMD(0x52, 0x45),
	PANEL_INIT_CMD(0x53, 0x67),
	PANEL_INIT_CMD(0x54, 0x89),
	PANEL_INIT_CMD(0x55, 0xAB),
	PANEL_INIT_CMD(0x56, 0x01),
	PANEL_INIT_CMD(0x57, 0x23),
	PANEL_INIT_CMD(0x58, 0x45),
	PANEL_INIT_CMD(0x59, 0x67),
	PANEL_INIT_CMD(0x5a, 0x89),
	PANEL_INIT_CMD(0x5b, 0xAB),
	PANEL_INIT_CMD(0x5c, 0xCD),
	PANEL_INIT_CMD(0x5d, 0xEF),
	PANEL_INIT_CMD(0x5e, 0x00),
	PANEL_INIT_CMD(0x5f, 0x08),
	PANEL_INIT_CMD(0x60, 0x08),
	PANEL_INIT_CMD(0x61, 0x06),
	PANEL_INIT_CMD(0x62, 0x06),
	PANEL_INIT_CMD(0x63, 0x01),
	PANEL_INIT_CMD(0x64, 0x01),
	PANEL_INIT_CMD(0x65, 0x00),
	PANEL_INIT_CMD(0x66, 0x00),
	PANEL_INIT_CMD(0x67, 0x02),
	PANEL_INIT_CMD(0x68, 0x15),
	PANEL_INIT_CMD(0x69, 0x15),
	PANEL_INIT_CMD(0x6a, 0x14),
	PANEL_INIT_CMD(0x6b, 0x14),
	PANEL_INIT_CMD(0x6c, 0x0D),
	PANEL_INIT_CMD(0x6d, 0x0D),
	PANEL_INIT_CMD(0x6e, 0x0C),
	PANEL_INIT_CMD(0x6f, 0x0C),
	PANEL_INIT_CMD(0x70, 0x0F),
	PANEL_INIT_CMD(0x71, 0x0F),
	PANEL_INIT_CMD(0x72, 0x0E),
	PANEL_INIT_CMD(0x73, 0x0E),
	PANEL_INIT_CMD(0x74, 0x02),
	PANEL_INIT_CMD(0x75, 0x08),
	PANEL_INIT_CMD(0x76, 0x08),
	PANEL_INIT_CMD(0x77, 0x06),
	PANEL_INIT_CMD(0x78, 0x06),
	PANEL_INIT_CMD(0x79, 0x01),
	PANEL_INIT_CMD(0x7a, 0x01),
	PANEL_INIT_CMD(0x7b, 0x00),
	PANEL_INIT_CMD(0x7c, 0x00),
	PANEL_INIT_CMD(0x7d, 0x02),
	PANEL_INIT_CMD(0x7e, 0x15),
	PANEL_INIT_CMD(0x7f, 0x15),
	PANEL_INIT_CMD(0x80, 0x14),
	PANEL_INIT_CMD(0x81, 0x14),
	PANEL_INIT_CMD(0x82, 0x0D),
	PANEL_INIT_CMD(0x83, 0x0D),
	PANEL_INIT_CMD(0x84, 0x0C),
	PANEL_INIT_CMD(0x85, 0x0C),
	PANEL_INIT_CMD(0x86, 0x0F),
	PANEL_INIT_CMD(0x87, 0x0F),
	PANEL_INIT_CMD(0x88, 0x0E),
	PANEL_INIT_CMD(0x89, 0x0E),
	PANEL_INIT_CMD(0x8A, 0x02),

	PANEL_SWITCH_PAGE(4),
	PANEL_INIT_CMD(0x6E, 0x2B),
	PANEL_INIT_CMD(0x6F, 0x37),
	PANEL_INIT_CMD(0x3A, 0xA4),
	PANEL_INIT_CMD(0x8D, 0x1A),
	PANEL_INIT_CMD(0x87, 0xBA),
	PANEL_INIT_CMD(0xB2, 0xD1),
	PANEL_INIT_CMD(0x88, 0x0B),
	PANEL_INIT_CMD(0x38, 0x01),
	PANEL_INIT_CMD(0x39, 0x00),
	PANEL_INIT_CMD(0xB5, 0x07),
	PANEL_INIT_CMD(0x31, 0x75),
	PANEL_INIT_CMD(0x3B, 0x98),

	PANEL_SWITCH_PAGE(1),
	PANEL_INIT_CMD(0xB7, 0x03), // 2Lane
	PANEL_INIT_CMD(0x22, 0x0A),
	PANEL_INIT_CMD(0x31, 0x00),
	PANEL_INIT_CMD(0x53, 0x40),
	PANEL_INIT_CMD(0x55, 0x40),
	PANEL_INIT_CMD(0x50, 0x99),
	PANEL_INIT_CMD(0x51, 0x94),
	PANEL_INIT_CMD(0x60, 0x10),
	PANEL_INIT_CMD(0x62, 0x20),
	PANEL_INIT_CMD(0xA0, 0x00),
	PANEL_INIT_CMD(0xA1, 0x00),
	PANEL_INIT_CMD(0xA2, 0x15),
	PANEL_INIT_CMD(0xA3, 0x14),
	PANEL_INIT_CMD(0xA5, 0x2F),
	PANEL_INIT_CMD(0xA6, 0x25),
	PANEL_INIT_CMD(0xA7, 0x24),
	PANEL_INIT_CMD(0xA8, 0x80),
	PANEL_INIT_CMD(0xA9, 0x1F),
	PANEL_INIT_CMD(0xAA, 0x2C),
	PANEL_INIT_CMD(0xAB, 0x6C),
	PANEL_INIT_CMD(0xAC, 0x16),
	PANEL_INIT_CMD(0xAD, 0x14),
	PANEL_INIT_CMD(0xAE, 0x4D),
	PANEL_INIT_CMD(0xAF, 0x20),
	PANEL_INIT_CMD(0xB0, 0x29),
	PANEL_INIT_CMD(0xB1, 0x4F),
	PANEL_INIT_CMD(0xB2, 0x5F),
	PANEL_INIT_CMD(0xB3, 0x23),
	PANEL_INIT_CMD(0xC0, 0x00),
	PANEL_INIT_CMD(0xC1, 0x2E),
	PANEL_INIT_CMD(0xC2, 0x3B),
	PANEL_INIT_CMD(0xC3, 0x15),
	PANEL_INIT_CMD(0xC4, 0x16),
	PANEL_INIT_CMD(0xC5, 0x28),
	PANEL_INIT_CMD(0xC6, 0x1A),
	PANEL_INIT_CMD(0xC7, 0x1C),
	PANEL_INIT_CMD(0xC8, 0xA7),
	PANEL_INIT_CMD(0xC9, 0x1B),
	PANEL_INIT_CMD(0xCA, 0x28),
	PANEL_INIT_CMD(0xCB, 0x92),
	PANEL_INIT_CMD(0xCC, 0x1F),
	PANEL_INIT_CMD(0xCD, 0x1C),
	PANEL_INIT_CMD(0xCE, 0x4B),
	PANEL_INIT_CMD(0xCF, 0x1F),
	PANEL_INIT_CMD(0xD0, 0x28),
	PANEL_INIT_CMD(0xD1, 0x4E),
	PANEL_INIT_CMD(0xD2, 0x5C),
	PANEL_INIT_CMD(0xD3, 0x23),
};

static const struct panel_init_config osoyoo_10_1_inch_4lane_init[] = {
	PANEL_SWITCH_PAGE(3),
	PANEL_INIT_CMD(0x01, 0x00),
	PANEL_INIT_CMD(0x02, 0x00),
	PANEL_INIT_CMD(0x03, 0x53),
	PANEL_INIT_CMD(0x04, 0xD3),
	PANEL_INIT_CMD(0x05, 0x00),
	PANEL_INIT_CMD(0x06, 0x0D),
	PANEL_INIT_CMD(0x07, 0x08),       
	PANEL_INIT_CMD(0x08, 0x00),
	PANEL_INIT_CMD(0x09, 0x00),
	PANEL_INIT_CMD(0x0a, 0x00),
	PANEL_INIT_CMD(0x0b, 0x00),
	PANEL_INIT_CMD(0x0c, 0x00),
	PANEL_INIT_CMD(0x0d, 0x00),  
	PANEL_INIT_CMD(0x0e, 0x00), 
	PANEL_INIT_CMD(0x0f, 0x28),      
	PANEL_INIT_CMD(0x10, 0x28), 
	PANEL_INIT_CMD(0x11, 0x00),      
	PANEL_INIT_CMD(0x12, 0x00),  
	PANEL_INIT_CMD(0x13, 0x00),
	PANEL_INIT_CMD(0x14, 0x00),
	PANEL_INIT_CMD(0x15, 0x00),
	PANEL_INIT_CMD(0x16, 0x00),
	PANEL_INIT_CMD(0x17, 0x00), 
	PANEL_INIT_CMD(0x18, 0x00), 
	PANEL_INIT_CMD(0x19, 0x00),
	PANEL_INIT_CMD(0x1a, 0x00),
	PANEL_INIT_CMD(0x1b, 0x00),
	PANEL_INIT_CMD(0x1c, 0x00),
	PANEL_INIT_CMD(0x1d, 0x00),
	PANEL_INIT_CMD(0x1e, 0x40),
	PANEL_INIT_CMD(0x1f, 0x80), 
	PANEL_INIT_CMD(0x20, 0x06),
	PANEL_INIT_CMD(0x21, 0x01),
	PANEL_INIT_CMD(0x22, 0x00), 
	PANEL_INIT_CMD(0x23, 0x00),
	PANEL_INIT_CMD(0x24, 0x00), 
	PANEL_INIT_CMD(0x25, 0x00),
	PANEL_INIT_CMD(0x26, 0x00),
	PANEL_INIT_CMD(0x27, 0x00),
	PANEL_INIT_CMD(0x28, 0x33),
	PANEL_INIT_CMD(0x29, 0x33),
	PANEL_INIT_CMD(0x2a, 0x00),
	PANEL_INIT_CMD(0x2b, 0x00),
	PANEL_INIT_CMD(0x2c, 0x00),
	PANEL_INIT_CMD(0x2d, 0x00),
	PANEL_INIT_CMD(0x2e, 0x00),   
	PANEL_INIT_CMD(0x2f, 0x00),
	PANEL_INIT_CMD(0x30, 0x00),
	PANEL_INIT_CMD(0x31, 0x00),
	PANEL_INIT_CMD(0x32, 0x00),
	PANEL_INIT_CMD(0x33, 0x00),
	PANEL_INIT_CMD(0x34, 0x03),
	PANEL_INIT_CMD(0x35, 0x00),             
	PANEL_INIT_CMD(0x36, 0x00),
	PANEL_INIT_CMD(0x37, 0x00),       
	PANEL_INIT_CMD(0x38, 0x96), 
	PANEL_INIT_CMD(0x39, 0x00),
	PANEL_INIT_CMD(0x3a, 0x00), 
	PANEL_INIT_CMD(0x3b, 0x00),
	PANEL_INIT_CMD(0x3c, 0x00),
	PANEL_INIT_CMD(0x3d, 0x00),
	PANEL_INIT_CMD(0x3e, 0x00),
	PANEL_INIT_CMD(0x3f, 0x00),
	PANEL_INIT_CMD(0x40, 0x00),
	PANEL_INIT_CMD(0x41, 0x00),
	PANEL_INIT_CMD(0x42, 0x00),
	PANEL_INIT_CMD(0x43, 0x00),  
	PANEL_INIT_CMD(0x44, 0x00),
	PANEL_INIT_CMD(0x50, 0x00),
	PANEL_INIT_CMD(0x51, 0x23),
	PANEL_INIT_CMD(0x52, 0x45),
	PANEL_INIT_CMD(0x53, 0x67),
	PANEL_INIT_CMD(0x54, 0x89),
	PANEL_INIT_CMD(0x55, 0xAB),
	PANEL_INIT_CMD(0x56, 0x01),
	PANEL_INIT_CMD(0x57, 0x23),
	PANEL_INIT_CMD(0x58, 0x45),
	PANEL_INIT_CMD(0x59, 0x67),
	PANEL_INIT_CMD(0x5a, 0x89),
	PANEL_INIT_CMD(0x5b, 0xAB),
	PANEL_INIT_CMD(0x5c, 0xCD),
	PANEL_INIT_CMD(0x5d, 0xEF),
	PANEL_INIT_CMD(0x5e, 0x00),
	PANEL_INIT_CMD(0x5f, 0x08),
	PANEL_INIT_CMD(0x60, 0x08),
	PANEL_INIT_CMD(0x61, 0x06),
	PANEL_INIT_CMD(0x62, 0x06),
	PANEL_INIT_CMD(0x63, 0x01),
	PANEL_INIT_CMD(0x64, 0x01),
	PANEL_INIT_CMD(0x65, 0x00),
	PANEL_INIT_CMD(0x66, 0x00),
	PANEL_INIT_CMD(0x67, 0x02),
	PANEL_INIT_CMD(0x68, 0x15),
	PANEL_INIT_CMD(0x69, 0x15),
	PANEL_INIT_CMD(0x6a, 0x14),
	PANEL_INIT_CMD(0x6b, 0x14),
	PANEL_INIT_CMD(0x6c, 0x0D),
	PANEL_INIT_CMD(0x6d, 0x0D),
	PANEL_INIT_CMD(0x6e, 0x0C),
	PANEL_INIT_CMD(0x6f, 0x0C),
	PANEL_INIT_CMD(0x70, 0x0F),
	PANEL_INIT_CMD(0x71, 0x0F),
	PANEL_INIT_CMD(0x72, 0x0E),
	PANEL_INIT_CMD(0x73, 0x0E),
	PANEL_INIT_CMD(0x74, 0x02),
	PANEL_INIT_CMD(0x75, 0x08),
	PANEL_INIT_CMD(0x76, 0x08),
	PANEL_INIT_CMD(0x77, 0x06),
	PANEL_INIT_CMD(0x78, 0x06),
	PANEL_INIT_CMD(0x79, 0x01),
	PANEL_INIT_CMD(0x7a, 0x01),
	PANEL_INIT_CMD(0x7b, 0x00),
	PANEL_INIT_CMD(0x7c, 0x00),
	PANEL_INIT_CMD(0x7d, 0x02),
	PANEL_INIT_CMD(0x7e, 0x15),
	PANEL_INIT_CMD(0x7f, 0x15),
	PANEL_INIT_CMD(0x80, 0x14),
	PANEL_INIT_CMD(0x81, 0x14),
	PANEL_INIT_CMD(0x82, 0x0D),
	PANEL_INIT_CMD(0x83, 0x0D),
	PANEL_INIT_CMD(0x84, 0x0C),
	PANEL_INIT_CMD(0x85, 0x0C),
	PANEL_INIT_CMD(0x86, 0x0F),
	PANEL_INIT_CMD(0x87, 0x0F),
	PANEL_INIT_CMD(0x88, 0x0E),
	PANEL_INIT_CMD(0x89, 0x0E),
	PANEL_INIT_CMD(0x8A, 0x02),

	PANEL_SWITCH_PAGE(4),
	PANEL_INIT_CMD(0x6E, 0x2B),
	PANEL_INIT_CMD(0x6F, 0x37),
	PANEL_INIT_CMD(0x3A, 0xA4),
	PANEL_INIT_CMD(0x8D, 0x1A),
	PANEL_INIT_CMD(0x87, 0xBA),
	PANEL_INIT_CMD(0xB2, 0xD1),
	PANEL_INIT_CMD(0x88, 0x0B),
	PANEL_INIT_CMD(0x38, 0x01),
	PANEL_INIT_CMD(0x39, 0x00),
	PANEL_INIT_CMD(0xB5, 0x07),
	PANEL_INIT_CMD(0x31, 0x75),
	PANEL_INIT_CMD(0x3B, 0x98),

	PANEL_SWITCH_PAGE(1),
	PANEL_INIT_CMD(0x22, 0x0A),
	PANEL_INIT_CMD(0x31, 0x00),
	PANEL_INIT_CMD(0x53, 0x40),
	PANEL_INIT_CMD(0x55, 0x40),
	PANEL_INIT_CMD(0x50, 0x99),
	PANEL_INIT_CMD(0x51, 0x94),
	PANEL_INIT_CMD(0x60, 0x10),
	PANEL_INIT_CMD(0x62, 0x20),
	PANEL_INIT_CMD(0xA0, 0x00),
	PANEL_INIT_CMD(0xA1, 0x00),
	PANEL_INIT_CMD(0xA2, 0x15),
	PANEL_INIT_CMD(0xA3, 0x14),
	PANEL_INIT_CMD(0xA5, 0x2F),
	PANEL_INIT_CMD(0xA6, 0x25),
	PANEL_INIT_CMD(0xA7, 0x24),
	PANEL_INIT_CMD(0xA8, 0x80),
	PANEL_INIT_CMD(0xA9, 0x1F),
	PANEL_INIT_CMD(0xAA, 0x2C),
	PANEL_INIT_CMD(0xAB, 0x6C),
	PANEL_INIT_CMD(0xAC, 0x16),
	PANEL_INIT_CMD(0xAD, 0x14),
	PANEL_INIT_CMD(0xAE, 0x4D),
	PANEL_INIT_CMD(0xAF, 0x20),
	PANEL_INIT_CMD(0xB0, 0x29),
	PANEL_INIT_CMD(0xB1, 0x4F),
	PANEL_INIT_CMD(0xB2, 0x5F),
	PANEL_INIT_CMD(0xB3, 0x23),
	PANEL_INIT_CMD(0xC0, 0x00),
	PANEL_INIT_CMD(0xC1, 0x2E),
	PANEL_INIT_CMD(0xC2, 0x3B),
	PANEL_INIT_CMD(0xC3, 0x15),
	PANEL_INIT_CMD(0xC4, 0x16),
	PANEL_INIT_CMD(0xC5, 0x28),
	PANEL_INIT_CMD(0xC6, 0x1A),
	PANEL_INIT_CMD(0xC7, 0x1C),
	PANEL_INIT_CMD(0xC8, 0xA7),
	PANEL_INIT_CMD(0xC9, 0x1B),
	PANEL_INIT_CMD(0xCA, 0x28),
	PANEL_INIT_CMD(0xCB, 0x92),
	PANEL_INIT_CMD(0xCC, 0x1F),
	PANEL_INIT_CMD(0xCD, 0x1C),
	PANEL_INIT_CMD(0xCE, 0x4B),
	PANEL_INIT_CMD(0xCF, 0x1F),
	PANEL_INIT_CMD(0xD0, 0x28),
	PANEL_INIT_CMD(0xD1, 0x4E),
	PANEL_INIT_CMD(0xD2, 0x5C),
	PANEL_INIT_CMD(0xD3, 0x23),
};

static inline struct osoyoo_panel *panel_to_osoyoo(struct drm_panel *panel)
{
	return container_of(panel, struct osoyoo_panel, panel);
}

static int osoyoo_switch_page(struct osoyoo_panel *ctx, u8 page)
{
	u8 buf[4] = { 0xff, 0x98, 0x81, page };

	int ret = mipi_dsi_dcs_write_buffer(ctx->dsi, buf, sizeof(buf));

	return ret;
}

static int osoyoo_send_cmd_data(struct osoyoo_panel *ctx, u8 cmd, u8 data)
{
	u8 buf[2] = { cmd, data };

	int ret = mipi_dsi_dcs_write_buffer(ctx->dsi, buf, sizeof(buf));

	return ret;
}

static int osoyoo_panel_prepare(struct drm_panel *panel)
{
	struct osoyoo_panel *ctx = panel_to_osoyoo(panel);
	unsigned int i;
	int ret;

	gpiod_set_value_cansleep(ctx->reset, 0);
	msleep(60);
	
	gpiod_set_value_cansleep(ctx->reset, 1);
	msleep(60);

	for (i = 0; i < ctx->desc->init_length; i++) {
		const struct panel_init_config *instr = &ctx->desc->init[i];
		if (instr->type == _SWITCH_PAGE)
			ret = osoyoo_switch_page(ctx, instr->cmd);
		else if (instr->type == _INIT_COMMAND)
			ret = osoyoo_send_cmd_data(ctx, instr->cmd, instr->data);
		if (ret)
			return ret;
	}
	
	ret = osoyoo_switch_page(ctx, 0);
	if (ret)
		return ret;
	ret = mipi_dsi_dcs_set_tear_on(ctx->dsi, MIPI_DSI_DCS_TEAR_MODE_VBLANK);
	if (ret)
		return ret;
	ret = mipi_dsi_dcs_exit_sleep_mode(ctx->dsi);
	if (ret)
		return ret;

	msleep(120);

	ret = mipi_dsi_dcs_set_display_on(ctx->dsi);
	return ret;
}

static int osoyoo_panel_enable(struct drm_panel *panel)
{
	return 0;
}

static int osoyoo_panel_disable(struct drm_panel *panel)
{
	return 0;
}

static int osoyoo_panel_unprepare(struct drm_panel *panel)
{
	struct osoyoo_panel *ctx = panel_to_osoyoo(panel);
	mipi_dsi_dcs_set_display_off(ctx->dsi);
	mipi_dsi_dcs_enter_sleep_mode(ctx->dsi);
	if (ctx->reset != NULL)
		gpiod_set_value_cansleep(ctx->reset, 0);

	return 0;
}

static const struct drm_display_mode osoyoo_7_0_inch_mode = {
	.clock          = 51200,

	.hdisplay	= 720,
	.hsync_start	= 720 + 20,
	.hsync_end	= 720 + 20 + 6,
	.htotal		= 720 + 20 + 6 + 10,

	.vdisplay	= 1280,
	.vsync_start	= 1280 + 50,
	.vsync_end	= 1280 + 50 + 6,
	.vtotal		= 1280 + 50 + 6 + 20,

	.width_mm	= 90,
	.height_mm	= 151,
};

static const struct drm_display_mode osoyoo_10_1_inch_2lane_mode = {
	.clock		= 74673,
	.hdisplay	= 800,
	.hsync_start	= 800 + 60,
	.hsync_end	= 800 + 60 + 20,
	.htotal		= 800 + 60 + 20 + 60,

	.vdisplay	= 1280,
	.vsync_start	= 1280 + 16,
	.vsync_end	= 1280 + 16 + 6,
	.vtotal		= 1280 + 16 + 6 + 22,

	.width_mm	= 135,
	.height_mm	= 216,
};

static const struct drm_display_mode osoyoo_10_1_inch_4lane_mode = {
	.clock		= 74673,
	.hdisplay	= 800,
	.hsync_start	= 800 + 60,
	.hsync_end	= 800 + 60 + 20,
	.htotal		= 800 + 60 + 20 + 60,

	.vdisplay	= 1280,
	.vsync_start	= 1280 + 16,
	.vsync_end	= 1280 + 16 + 6,
	.vtotal		= 1280 + 16 + 6 + 22,

	.width_mm	= 135,
	.height_mm	= 216,
};

static int osoyoo_panel_get_modes(struct drm_panel *panel, struct drm_connector *connector)
{
	struct osoyoo_panel *ctx = panel_to_osoyoo(panel);
	struct drm_display_mode *mode;

	mode = drm_mode_duplicate(connector->dev, ctx->desc->mode);
	if (!mode) {
		dev_err(&ctx->dsi->dev, "failed to add mode %ux%ux@%u\n",
			ctx->desc->mode->hdisplay,
			ctx->desc->mode->vdisplay,
			drm_mode_vrefresh(ctx->desc->mode));
		return -ENOMEM;
	}

	drm_mode_set_name(mode);
	mode->type = DRM_MODE_TYPE_DRIVER | DRM_MODE_TYPE_PREFERRED;
	drm_mode_probed_add(connector, mode);
	connector->display_info.width_mm = mode->width_mm;
	connector->display_info.height_mm = mode->height_mm;
	
	// 兼容性处理：检查函数是否存在
#ifdef CONFIG_DRM_PANEL_ORIENTATION_QUIRKS
	drm_connector_set_panel_orientation(connector, ctx->orientation);
#endif

	return 1;
}

static enum drm_panel_orientation osoyoo_panel_get_orientation(struct drm_panel *panel)
{
	struct osoyoo_panel *ctx = panel_to_osoyoo(panel);
	return ctx->orientation;
}

static const struct drm_panel_funcs osoyoo_panel_funcs = {
	.prepare = osoyoo_panel_prepare,
	.unprepare = osoyoo_panel_unprepare,
	.enable = osoyoo_panel_enable,
	.disable = osoyoo_panel_disable,
	.get_modes = osoyoo_panel_get_modes,
	.get_orientation = osoyoo_panel_get_orientation,
};

static int osoyoo_panel_dsi_probe(struct mipi_dsi_device *dsi)
{
	struct osoyoo_panel *ctx;
	int ret;
	dev_info(&dsi->dev, "osoyoo panel.: %s\n", (char *)of_get_property(dsi->dev.of_node, "compatible", NULL));

	ctx = devm_kzalloc(&dsi->dev, sizeof(*ctx), GFP_KERNEL);
	if (!ctx)
		return -ENOMEM;
	
	mipi_dsi_set_drvdata(dsi, ctx);
	ctx->dsi = dsi;
	ctx->desc = of_device_get_match_data(&dsi->dev);

	ctx->panel.prepare_prev_first = true;
	drm_panel_init(&ctx->panel, &dsi->dev, &osoyoo_panel_funcs, DRM_MODE_CONNECTOR_DSI);
	ctx->reset = devm_gpiod_get_optional(&dsi->dev, "reset", GPIOD_OUT_LOW);
	if (IS_ERR(ctx->reset))
		return dev_err_probe(&dsi->dev, PTR_ERR(ctx->reset), "Couldn't get our reset GPIO\n");
	ret = of_drm_get_panel_orientation(dsi->dev.of_node, &ctx->orientation);
	if (ret) {
		dev_err(&dsi->dev, "%pOF: failed to get orientation: %d\n", dsi->dev.of_node, ret);
		return ret;
	}
	ctx->panel.prepare_prev_first = true;
	
	// 兼容性处理：检查drm_panel_of_backlight函数
#ifdef CONFIG_BACKLIGHT_CLASS_DEVICE
	ret = drm_panel_of_backlight(&ctx->panel);
	if (ret)
		return ret;
#endif
	
	drm_panel_add(&ctx->panel);

	dsi->mode_flags = ctx->desc->mode_flags;
	dsi->format = MIPI_DSI_FMT_RGB888;
	dsi->lanes = ctx->desc->lanes;
	dev_info(&dsi->dev, "lanes: %d\n", dsi->lanes);
	ret = mipi_dsi_attach(dsi);
	if (ret)
		drm_panel_remove(&ctx->panel);

	return ret;
}

static void osoyoo_panel_dsi_remove(struct mipi_dsi_device *dsi)
{
	struct osoyoo_panel *ctx = mipi_dsi_get_drvdata(dsi);
	mipi_dsi_detach(dsi);
	drm_panel_remove(&ctx->panel);
	gpiod_set_value_cansleep(ctx->reset, 0);
}

static const struct osoyoo_desc osoyoo_7_0_inch_desc = {
	.init = osoyoo_7_0_inch_init,
	.init_length = ARRAY_SIZE(osoyoo_7_0_inch_init),
	.mode = &osoyoo_7_0_inch_mode,
	.mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_LPM,
	.lanes = 2,
};

static const struct osoyoo_desc osoyoo_10_1_inch_2lane_desc = {
	.init = osoyoo_10_1_inch_2lane_init,
	.init_length = ARRAY_SIZE(osoyoo_10_1_inch_2lane_init),
	.mode = &osoyoo_10_1_inch_2lane_mode,
	.mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_LPM,
	.lanes = 2,
};

static const struct osoyoo_desc osoyoo_10_1_inch_4lane_desc = {
	.init = osoyoo_10_1_inch_4lane_init,
	.init_length = ARRAY_SIZE(osoyoo_10_1_inch_4lane_init),
	.mode = &osoyoo_10_1_inch_4lane_mode,
	.mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_LPM,
	.lanes = 4,
};

static const struct of_device_id osoyoo_of_match[] = {
	{ .compatible = "osoyoo,dsi-7inch", &osoyoo_7_0_inch_desc },
	{ .compatible = "osoyoo,dsi-10.1inch-2lane", &osoyoo_10_1_inch_2lane_desc },
	{ .compatible = "osoyoo,dsi-10.1inch-4lane", &osoyoo_10_1_inch_4lane_desc },
	{ }
};

MODULE_DEVICE_TABLE(of, osoyoo_of_match);

static struct mipi_dsi_driver osoyoo_panel_dsi_driver = {
	.probe = osoyoo_panel_dsi_probe,
	.remove = osoyoo_panel_dsi_remove,
	.driver = {
		.name = "osoyoo-dsi",
		.of_match_table = osoyoo_of_match,
	},
};

module_mipi_dsi_driver(osoyoo_panel_dsi_driver);

MODULE_AUTHOR("QDJ");
MODULE_DESCRIPTION("OSOYOO DSI Driver");
MODULE_LICENSE("GPL v2");
