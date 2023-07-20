
module cosmacelf
(
	input         clk,
	input         reset,
	input         clk_1m76,
	input         clk_vid,

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

	output reg    video
);

reg int_req     = 1'b0;
reg wait_req    = 1'b0;
reg dma_in_req  = 1'b0;
reg dma_out_req = 1'b0;

reg  [1:0] sc = 2'b00;
reg  [3:0] ef = 4'b1111;
wire       q_out;

reg  [3:0] EF = 4'b0010;
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

reg  [15:0] vram_addr;
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
	.address_b(vram_addr[11:0]),
	.data_b(),
	.q_b(video_din)
);

reg efx;
reg csync;

/*
always @* begin
	if (ram_a >= 12'h0900 && ram_a < 12'h0a00) begin
			video_din <= ram_d;
			//$display("video_din = %h, ram_a = %h", video_din, ram_a);
		end
		else begin
			video_din <= 8'h00;
		end
end
*/

/*
pixie_dp pixie_dp 
(
	// Inputs
	.clk(clk),
    .clk_enable(1'b1),
	.reset(reset),
	.sc(sc), // [1:0]
	.disp_on(1'b1),
	.disp_off(1'b0),
    .data(video_din), // [7:0]
    .video_clk(clk),

	// Outputs
    .dmao(dma_out_req),
    .int_pixie(int_req),
    .efx(efx),

    .csync(csync),
	.hsync(HSync),
	.vsync(VSync),
	.VBlank(VBlank),
	.HBlank(HBlank),

    .video(video)
);
*/

pixie_video pixie_video (
    // front end, CDP1802 bus clock domain
    .clk        (clk),    // I
    .reset      (reset),      // I
    .clk_enable (ce_pix),     // I      

    .SC         (SC),         // I [1:0]
    //Temp hard coded display always on.
//    .disp_on    (io_n[0]),    // I
//    .disp_off   (~io_n[0]),   // I 
    .disp_on    (1'b1),    // I
    .disp_off   (1'b0),   // I 

    .data_addr  (vram_addr),  // O [15:0]
    .data_in    (video_din),  // I [7:0]    

    .DMAO       (dma_out_req),       // O
    .INT        (int_req),        // O
    .EFx        (efx),        // O

    // back end, video clock domain
    .video_clk  (clk),    // I
    .csync      (csync),           // O
    .video      (video),      // O

    .VSync      (VSync),      // O
    .HSync      (HSync),      // O
    .VBlank     (VBlank),     // O
    .HBlank     (HBlank),     // O
    .video_de   (video_de)    // O    
);


endmodule
