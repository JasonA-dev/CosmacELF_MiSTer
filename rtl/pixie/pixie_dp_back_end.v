// PIXIE graphics core, back end, dual-port memory version
// Copyright 2017 Eric Smith <spacewar@gmail.com>
// SPDX-License-Identifier: GPL-3.0

module pixie_dp_back_end
(
  input  wire clk,
  output reg fb_read_en,
  output wire [9:0] fb_addr,
  input  wire [7:0] fb_data,
  output wire csync,
  output reg video
);

  parameter pixels_per_line = 112;
  parameter active_h_pixels = 64;
  parameter hsync_start_pixel = 82;  
  parameter hsync_width_pixels = 12;

  parameter lines_per_frame = 262;
  parameter active_v_lines = 128;
  parameter vsync_start_line = 182;
  parameter vsync_height_lines = 16;

  reg [7:0] pixel_shift_reg;

  reg [7:0] horizontal_counter;
  wire hsync;
  reg active_h_adv2;
  reg active_h_adv1;
  wire active_h;
  wire advance_v;

  reg [8:0] vertical_counter;
  reg vsync;
  wire active_v;

  wire active_video;

  assign fb_addr = {vertical_counter[6:0], horizontal_counter[5:3]};
  assign active_h = active_h_adv1;
  assign hsync = horizontal_counter >= hsync_start_pixel && horizontal_counter < hsync_start_pixel + hsync_width_pixels;
  assign advance_v = horizontal_counter == (pixels_per_line - 1);
  assign active_v = vertical_counter < active_v_lines;
  assign csync = hsync ^ vsync;
  assign active_video = active_h && active_v;

  always @(posedge clk) begin
    if (horizontal_counter == (pixels_per_line - 1))
      horizontal_counter <= 8'h0;
    else
      horizontal_counter <= horizontal_counter + 1;

    fb_read_en <= horizontal_counter[2:0] == 3'b000;
    pixel_shift_reg[7] <= horizontal_counter[2:0] == 3'b001;
    active_h_adv2 <= horizontal_counter < active_h_pixels;
    active_h_adv1 <= active_h_adv2;

    if (advance_v) begin
      if (vertical_counter == (lines_per_frame - 1))
        vertical_counter <= 9'h0;
      else
        vertical_counter <= vertical_counter + 1;
    end

    vsync <= vertical_counter >= vsync_start_line && vertical_counter < vsync_start_line + vsync_height_lines;

    if (pixel_shift_reg[7])
      pixel_shift_reg <= {fb_data, 1'b0};
    else
      pixel_shift_reg <= {pixel_shift_reg[6:0], 1'b0};
    
    video <= active_video && pixel_shift_reg[7];
  end
endmodule
