`timescale 1ns / 1ps

module pixie_dp (
    input wire clk,
    input wire clk_enable,
    input wire reset,
    input wire [1:0] sc,
    input wire disp_on,
    input wire disp_off,
    input wire [7:0] data,

    output wire dmao,
    output wire int_pixie,
    output wire efx,

    input wire video_clk,

    output wire csync,
    output wire hsync,
    output wire vsync,
    output wire VBlank,
    output wire HBlank,

    output wire video
);

    wire [9:0] fb_a_addr;
    wire [7:0] fb_a_data;
    wire fb_a_en;

    wire fb_a_en2;

    wire [9:0] fb_b_addr;
    wire [7:0] fb_b_data;
    wire fb_b_en;

    assign fb_a_en2 = clk_enable & fb_a_en;

    pixie_dp_front_end fe (
        .clk(clk),
        .clk_enable(clk_enable),
        .reset(reset),
        .sc(sc),
        .disp_on(disp_on),
        .disp_off(disp_off),
        .data(data),

        .dmao(dmao),
        .int_pixie(int_pixie),
        .efx(efx),

        .mem_addr(fb_a_addr),
        .mem_data(fb_a_data),
        .mem_wr_en(fb_a_en)
    );

    pixie_dp_frame_buffer fb (
        .clk_a(clk),
        .en_a(fb_a_en2),
        .addr_a(fb_a_addr),
        .d_in_a(fb_a_data),

        .clk_b(video_clk),
        .en_b(fb_b_en),
        .addr_b(fb_b_addr),
        .d_out_b(fb_b_data)
    );

    pixie_dp_back_end be (
        .clk(video_clk),
        .fb_read_en(fb_b_en),
        .fb_addr(fb_b_addr),
        .fb_data(fb_b_data),

        .csync(csync),
        .hsync(hsync),
        .vsync(vsync),
        .VBlank(VBlank),
        .HBlank(HBlank),

        .video(video)
    );

endmodule
