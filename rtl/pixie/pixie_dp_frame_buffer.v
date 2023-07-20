// PIXIE graphics core, frame buffer, dual-port memory version
// Copyright 2017 Eric Smith <spacewar@gmail.com>
// SPDX-License-Identifier: GPL-3.0

module pixie_dp_frame_buffer
(
  input wire clk_a,
  input wire en_a,
  input wire [9:0] addr_a,
  input wire [7:0] d_in_a,

  input wire clk_b,
  input wire en_b,
  input wire [9:0] addr_b,
  output reg [7:0] d_out_b
);

  reg [7:0] ram [0:1023];

  always @(posedge clk_a) begin
    if (en_a) 
      ram[addr_a] <= d_in_a;
  end

  always @(posedge clk_b) begin
    if (en_b) 
      d_out_b <= ram[addr_b];
  end

endmodule
