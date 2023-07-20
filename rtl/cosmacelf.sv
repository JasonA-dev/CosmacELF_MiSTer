
module cosmacelf
(
	input         clk,
	input         reset,
	
	input wire         ioctl_download,
	input wire   [7:0] ioctl_index,
	input wire         ioctl_wr,
	input       [24:0] ioctl_addr,
	input        [7:0] ioctl_dout,

	output reg    ce_pix,

	output reg    HBlank,
	output reg    HSync,
	output reg    VBlank,
	output reg    VSync,

	output  [7:0] video
);

reg int_req     = 1'b0;
reg wait_req    = 1'b0;
reg dma_in_req  = 1'b0;
reg dma_out_req = 1'b0;

reg  [1:0] sc = 2'b00;
reg  [3:0] ef = 4'b1111;
wire       q_out;

//assign EF = {0, 0, 1'b1, efx}; disable player controls for now
assign EF = 4'b0010 | efx;

reg [2:0] io_port;

cdp1802 cdp1802
(
	// Inputs
	.clk(clk),
    .clk_enable(1'b1),
    .clear(reset),
    .dma_in_req(dma_in_req),
    .dma_out_req(dma_out_req),
    .int_req(int_req),
    .wait_req(wait_req),
    .ef(ef), // [3:0]
    .data_in(ram_q), // [7:0]

	// Outputs
    .data_out(ram_d), // [7:0]
    .address(ram_a), // [15:0]
    .mem_read(ram_rd),
    .mem_write(ram_wr),
    .io_port(io_port), // [2:0]
    .q_out(q_out),
    .sc(sc) // [1:0]
);

reg          ram_cs;
wire         ram_rd; // RAM read enable
wire         ram_wr; // RAM write enable
reg   [7:0]  ram_d;  // RAM write data
reg  [15:0]  ram_a;  // RAM address
reg   [7:0]  ram_q;  // RAM read data

wire cpu_wr;
assign cpu_wr = (ram_a[11:0] >= 12'h800 && ram_a[11:0] < 12'hA00) ? ram_wr : 1'b0;

reg  [7:0]  video_din;

dpram #(8, 12) dpram
(
	.clock(clk),
	.address_a(ioctl_download ? ioctl_addr[11:0] + (ioctl_index > 0 ? 12'h0400 : 12'h0 ) : ram_a[11:0]),
	.ram_cs(),
	.wren_a(ioctl_wr | cpu_wr),
	.data_a(ioctl_download ? ioctl_dout : ram_d),
	.q_a(ram_q),

	.ram_cs_b(),
	.wren_b(1'b0),
	.address_b(ram_d),
	.data_b(),
	.q_b()
);

reg efx;
reg csync;

pixie_dp pixie_dp 
(
	// Inputs
	.clk(clk),
    .clk_enable(1'b1),
	.reset(reset),
	.sc(sc), // [1:0]
	.disp_on(1'b1),
	.disp_off(1'b0),
    .data(ram_a[11:0] >= 12'h900 && ram_a[11:0] < 12'ha00 ? ram_d : 8'h00), // [7:0]
    .video_clk(clk),

	// Outputs
    .dmao(dma_out_req),
    .int_pixie(int_req),
    .efx(efx),
    .csync(csync),
    .video()
);

endmodule
