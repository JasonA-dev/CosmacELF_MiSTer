`timescale 1ns / 1ps

module pixie_dp_front_end (
    input wire clk,
    input wire clk_enable,
    input wire reset,
    input wire [1:0] sc,
    input wire disp_on,
    input wire disp_off,
    input wire [7:0] data,

    output wire dmao,
    output reg int_pixie,
    output reg efx,

    output wire [9:0] mem_addr,
    output wire [7:0] mem_data,
    output wire mem_wr_en
);

    parameter bytes_per_line = 14;
    parameter lines_per_frame = 262;

    wire sc_fetch = (sc == 2'b00);
    wire sc_execute = (sc == 2'b01);
    wire sc_dma = (sc == 2'b10);
    wire sc_interrupt = (sc == 2'b11);

    reg enabled;

    reg [3:0] horizontal_counter;
    wire horizontal_end = (horizontal_counter == (bytes_per_line - 1));

    reg [8:0] vertical_counter;
    wire vertical_end = (vertical_counter == (lines_per_frame - 1));

    reg v_active;

    wire dma_xfer;
    reg [9:0] addr_counter;

    always @(posedge clk) begin
        if (clk_enable) begin
            if (reset)
                enabled <= 1'b0;
            else if (disp_on)
                enabled <= 1'b1;
            else if (disp_off)
                enabled <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (clk_enable) begin
            if (horizontal_end)
                horizontal_counter <= 4'b0;
            else
                horizontal_counter <= horizontal_counter + 1;
        end
    end

    always @(posedge clk) begin
        if (clk_enable && horizontal_end) begin
            if (vertical_end)
                vertical_counter <= 9'b0;
            else
                vertical_counter <= vertical_counter + 1;

            if ((vertical_counter >= 76 && vertical_counter < 80) || (vertical_counter >= 204 && vertical_counter < 208)) begin
                efx <= 1'b1;
                //$display("efx");
            end
            else
                efx <= 1'b0;

            if (enabled && vertical_counter >= 78 && vertical_counter < 80) begin
                int_pixie <= 1'b1;
                //$display("int_pixie");
            end
            else
                int_pixie <= 1'b0;

            if (enabled && vertical_counter >= 80 && vertical_counter < 208)
                v_active <= 1'b1;
            else
                v_active <= 1'b0;
        end
    end

    assign dmao = (enabled && v_active && horizontal_counter >= 1 && horizontal_counter < 9);

    assign dma_xfer = (enabled && sc_dma);

    always @(posedge clk) begin
        if (clk_enable) begin
            if (reset || (horizontal_end && vertical_end))
                addr_counter <= 10'b0;
            else if (dma_xfer)
                addr_counter <= addr_counter + 1;
        end
    end

    assign mem_addr = addr_counter;
    assign mem_data = data;
    assign mem_wr_en = dma_xfer;

endmodule
