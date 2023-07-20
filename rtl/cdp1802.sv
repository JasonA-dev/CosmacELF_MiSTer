module cdp1802(
    input wire clk,
    input wire clk_enable,
    input wire clear,
    input wire dma_in_req,
    input wire dma_out_req,
    input wire int_req,
    input wire wait_req,
    input wire [4:1] ef,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    output reg [15:0] address,
    output wire mem_read,
    output wire mem_write,
    output wire [2:0] io_port, // n0-2 in RCA docs
    output reg q_out,
    output wire [1:0] sc
);

    //typedef reg [3:0] nibble_t;
    //typedef reg [15:0] word_t;

    // Instructions
    localparam reg [7:0] inst_idl = 8'h00;
    localparam reg [7:0] inst_ldn = {4'h0, 4'bxxxx};
    localparam reg [7:0] inst_inc = {4'h1, 4'bxxxx};
    localparam reg [7:0] inst_dec = {4'h2, 4'bxxxx};

    localparam reg [7:0] inst_short_branch = {4'h3, 4'bxxxx};
    localparam reg [7:0] inst_lda = {4'h4, 4'bxxxx};
    localparam reg [7:0] inst_str = {4'h5, 4'bxxxx};
    localparam reg [7:0] inst_irx = 8'h60;
    localparam reg [7:0] inst_out = {4'h6, 4'b0xxx};
    localparam reg [7:0] inst_extend = 8'h68;
    localparam reg [7:0] inst_inp = {4'h6, 4'b1xxx};
    localparam reg [7:0] inst_ret = 8'h70;
    localparam reg [7:0] inst_dis = 8'h71;
    localparam reg [7:0] inst_ldxa = 8'h72;
    localparam reg [7:0] inst_stxd = 8'h73;
    localparam reg [7:0] inst_adc = 8'h74;
    localparam reg [7:0] inst_sdb = 8'h75;
    localparam reg [7:0] inst_shrc = 8'h76;
    localparam reg [7:0] inst_smb = 8'h77;
    localparam reg [7:0] inst_sav = 8'h78;
    localparam reg [7:0] inst_mark = 8'h79;
    localparam reg [7:0] inst_req = 8'h7a;
    localparam reg [7:0] inst_seq = 8'h7b;
    localparam reg [7:0] inst_adci = 8'h7c;
    localparam reg [7:0] inst_sdbi = 8'h7d;
    localparam reg [7:0] inst_shlc = 8'h7e;
    localparam reg [7:0] inst_smbi = 8'h7f;
    localparam reg [7:0] inst_glo = {4'h8, 4'bxxxx};
    localparam reg [7:0] inst_ghi = {4'h9, 4'bxxxx};
    localparam reg [7:0] inst_plo = {4'ha, 4'bxxxx};
    localparam reg [7:0] inst_phi = {4'hb, 4'bxxxx};
    localparam reg [7:0] inst_long_branch_skip = {4'hc, 4'bxxxx};
    localparam reg [7:0] inst_sep = {4'hd, 4'bxxxx};
    localparam reg [7:0] inst_sex = {4'he, 4'bxxxx};
    localparam reg [7:0] inst_ldx = 8'hf0;
    localparam reg [7:0] inst_or = 8'hf1;
    localparam reg [7:0] inst_and = 8'hf2;
    localparam reg [7:0] inst_xor = 8'hf3;
    localparam reg [7:0] inst_add = 8'hf4;
    localparam reg [7:0] inst_sub = 8'hf5;
    localparam reg [7:0] inst_shr = 8'hf6;
    localparam reg [7:0] inst_sm = 8'hf7;
    localparam reg [7:0] inst_ldi = 8'hf8;
    localparam reg [7:0] inst_ori = 8'hf9;
    localparam reg [7:0] inst_ani = 8'hfa;
    localparam reg [7:0] inst_xri = 8'hfb;
    localparam reg [7:0] inst_adi = 8'hfc;
    localparam reg [7:0] inst_sdi = 8'hfd;
    localparam reg [7:0] inst_shl = 8'hfe;
    localparam reg [7:0] inst_smi = 8'hff;

    // Constants
    localparam [1:0] sc_fetch = 2'b00;
    localparam [1:0] sc_execute = 2'b01;
    localparam [1:0] sc_dma = 2'b10;
    localparam [1:0] sc_interrupt = 2'b11;

    // CPU registers
    reg [3:0] state;
    reg [3:0] next_state;
    localparam [3:0] state_clear = 4'b0000;       // sc_execute
    localparam [3:0] state_clear_2 = 4'b0001;     // sc_execute
    localparam [3:0] state_load = 4'b0010;        // sc_execute
    localparam [3:0] state_fetch = 4'b0011;       // sc_fetch
    localparam [3:0] state_execute = 4'b0100;     // sc_execute
    localparam [3:0] state_execute_2 = 4'b0101;   // sc_execute
    localparam [3:0] state_dma_in = 4'b0110;      // sc_dma
    localparam [3:0] state_dma_out = 4'b0111;     // sc_dma
    localparam [3:0] state_interrupt = 4'b1000;   // sc_interrupt

    reg [7:0] r_low [0:15] = '{default:8'b00000000};
    reg [7:0] r_high [0:15] = '{default:8'b00000000};

    reg [7:0] ir;     // instruction register
    wire [3:0] i = ir[7:4]; // high nibble of ir
    wire [3:0] n = ir[3:0]; // low nibble of ir

    reg [7:0] d;
    reg df;

    reg [3:0] x;
    reg [3:0] p;

    reg [7:0] t;   // holds old X, P after interrupt

    reg ie;  // interrupt enable
    reg q;   // output flip-flop

    // other data path signals
    wire d_zero;

    reg [7:0] prev_data_in;  // prev cycle value of data_in, used for long branch
    reg cond_branch;
    reg cond_no_skip;

    reg [3:0] r_addr;
    reg [15:0] r_write_data;
    reg [15:0] r_read_data;
    reg [7:0] r_read_data_byte;

    reg [15:0] adder_opb;
    reg [15:0] adder_result;

    wire [0:0] alu_carry_in;
    reg [8:0] alu_op_d;
    reg [8:0] alu_op_data_in;
    reg [8:0] alu_sum;
    reg [7:0] alu_out;

    reg rotate_in; // bit rotated in, 0 for shifts

    reg [7:0] shifter_out;

    // control signals
    reg waiting;

    reg [2:0] r_addr_sel;
    parameter r_addr_sel_p  = 3'b000;
    parameter r_addr_sel_n  = 3'b001;
    parameter r_addr_sel_2  = 3'b010;
    parameter r_addr_sel_x  = 3'b011;
    parameter r_addr_sel_0  = 3'b100;

    reg [2:0] r_write_data_sel;
    parameter r_write_data_sel_adder   = 3'b000;
    parameter r_write_data_sel_branch  = 3'b001;
    parameter r_write_data_sel_d       = 3'b010;
    parameter r_write_data_sel_data_in = 3'b011;
    parameter r_write_data_sel_0       = 3'b100;

    reg r_write_low;
    reg r_write_high;

    reg [1:0] data_out_sel;
    parameter data_out_sel_d  = 2'b00;
    parameter data_out_sel_xp = 2'b01; // mark
    parameter data_out_sel_t  = 2'b10; // sav

    reg [2:0] d_sel;
    parameter d_sel_hold     = 3'b000;
    parameter d_sel_data_in  = 3'b001;
    parameter d_sel_alu      = 3'b010;
    parameter d_sel_shifter  = 3'b011;
    parameter d_sel_r        = 3'b100;
    parameter d_sel_0        = 3'b101;

    reg [1:0] df_sel;
    parameter df_sel_hold  = 2'b00;
    parameter df_sel_carry = 2'b01;
    parameter df_sel_d0    = 2'b10;
    parameter df_sel_d7    = 2'b11;

    reg [2:0] xp_sel;
    parameter xp_sel_hold      = 3'b000;
    parameter xp_sel_clear     = 3'b001; // clear
    parameter xp_sel_interrupt = 3'b010; // p<=1, x<=2
    parameter xp_sel_data_in   = 3'b011; // ret, dis
    parameter xp_sel_mark      = 3'b100; // x<=p
    parameter xp_sel_sep       = 3'b101; // p<=n
    parameter xp_sel_sex       = 3'b110; // x<=n

    reg [1:0] ie_sel;
    parameter ie_sel_hold      = 2'b00;
    parameter ie_sel_not_ir0   = 2'b01;
    parameter ie_sel_0         = 2'b10;
    parameter ie_sel_1         = 2'b11;

    reg [1:0] q_sel;
    parameter q_sel_hold       = 2'b00;
    parameter q_sel_ir0        = 2'b01;
    parameter q_sel_0          = 2'b10;
    parameter q_sel_1          = 2'b11;

    reg load_ir; // true to load IR from data in
    reg load_t;  // true to load T from X & P

    reg [1:0] adder_opb_sel;
    parameter adder_opb_sel_0  = 2'b00;
    parameter adder_opb_sel_1  = 2'b01;
    parameter adder_opb_sel_m1 = 2'b11;
    parameter adder_opb_sel_m2 = 2'b10; // not used


always @* begin
    q_out = q;

    r_read_data = {r_high[r_addr], r_low[r_addr]};

    address = r_read_data;

    adder_opb = (adder_opb_sel == adder_opb_sel_1) ? 16'h0001 :
                (adder_opb_sel == adder_opb_sel_m1) ? 16'hffff :
                (adder_opb_sel == adder_opb_sel_m2) ? 16'hfffe : 
                                                      16'h0000;

    adder_result = r_read_data + adder_opb;

    r_read_data_byte = (ir[4]) ? r_read_data[15:8] : r_read_data[7:0];

    alu_op_d = (ir[1:0] == 2'b01) ? {1'b0, ~d} : {1'b0, d};

    alu_op_data_in = (ir[1:0] == 2'b11) ? {1'b0, ~data_in} : {1'b0, data_in};

    alu_carry_in[0] = (ir[7] == 1'b0) ? df : ir[0];

    alu_sum = alu_op_d + alu_op_data_in + alu_carry_in;

    alu_out = (ir[2:0] == 3'b001) ? (d | data_in) : 
              (ir[2:0] == 3'b010) ? (d & data_in) :
              (ir[2:0] == 3'b011) ? (d ^ data_in) : 
                                    alu_sum[7:0]; // alu_op_add 

    rotate_in = (ir[7] == 1'b0) ? df : 1'b0;

    shifter_out = (ir[3] == 1'b1) ? {d[6:0], rotate_in} : {rotate_in, d[7:1]};

    r_addr = (r_addr_sel == r_addr_sel_p) ? p :  // inst fetch, branch, skip, immed
             (r_addr_sel == r_addr_sel_n) ? n : 
             (r_addr_sel == r_addr_sel_x) ? x : 
             (r_addr_sel == r_addr_sel_2) ? 4'h2 : // mark
                                           4'h0;  // clear, dma in, dma out

    r_write_data = (r_write_data_sel == r_write_data_sel_data_in) ? {data_in, data_in} :
                   (r_write_data_sel == r_write_data_sel_d) ? {d, d} : 
                   (r_write_data_sel == r_write_data_sel_0) ? 16'h0000 :
                   (r_write_data_sel == r_write_data_sel_branch && cond_branch == 1'b1) ? {prev_data_in, data_in} : 
                                                                                         adder_result;

    data_out = (data_out_sel == data_out_sel_xp) ? {x, p} : // mark
               (data_out_sel == data_out_sel_t) ? t :       // sav
                                                    d;

    io_port = (state == state_execute && i == inst_out[7:4]) ? n[2:0] : 3'b000;

    waiting = (wait_req == 1'b1 && clear == 1'b0) ? 1'b1 : 1'b0;
end

always @(posedge clk) begin  // process r_p
    if (clk_enable == 1'b1) begin 
        if (waiting == 1'b0) begin 
            if (r_write_low == 1'b1) begin
                r_low[r_addr] <= r_write_data[7:0];
            end
            if (r_write_high == 1'b1) begin
                r_high[r_addr] <= r_write_data[15:8];
            end
        end
    end
end

always @(posedge clk) begin  // process xp_p
    if (clk_enable == 1'b1) begin
        if (waiting == 1'b0) begin
            case (xp_sel)
                xp_sel_clear: begin
                    p <= 4'h0;
                    x <= 4'h0;
                end
                xp_sel_interrupt: begin
                    p <= 4'h1;
                    x <= 4'h2;
                end
                xp_sel_data_in: begin
                    p <= data_in[3:0];
                    x <= data_in[7:4];
                end
                xp_sel_mark: begin
                    x <= p;
                end
                xp_sel_sep: begin
                    p <= n;
                end
                xp_sel_sex: begin
                    x <= n;
                end
                default: begin
                    // xp_sel_hold: x and p unchanged
                end
            endcase
        end
    end
end

always @(posedge clk) begin  // process d_p
    if (clk_enable == 1'b1) begin
        if (waiting == 1'b0) begin
            case (d_sel)
                d_sel_data_in: begin
                    d <= data_in;
                end
                d_sel_alu: begin
                    d <= alu_out;
                end
                d_sel_shifter: begin
                    d <= shifter_out;
                end
                d_sel_r: begin
                    d <= r_read_data_byte;
                end
                d_sel_0: begin
                    d <= 8'b00000000;
                end
                default: begin
                    // d_sel_hold: d unchanged
                end
            endcase
        end
    end
end

always @(posedge clk) begin  // process df_p
    if (clk_enable == 1'b1) begin
        if (waiting == 1'b0) begin
            case (df_sel)
                df_sel_carry: begin
                    df <= alu_sum[8];
                end
                df_sel_d0: begin
                    df <= d[0];
                end
                df_sel_d7: begin
                    df <= d[7];
                end
                default: begin
                    // df_sel_hold: df unchanged
                end
            endcase
        end
    end
end

always @(posedge clk) begin  // process ir_p
    if (clk_enable == 1'b1) begin
        if (waiting == 1'b0) begin
            if (load_ir == 1'b1) begin
              ir <= data_in;
            end
        end
    end
end

always @(posedge clk) begin  // process t_p
    if (clk_enable == 1'b1) begin
        if (waiting == 1'b0) begin
            if (load_t == 1'b1) begin
              t <= {x, p};
            end
        end
    end
end

always @(posedge clk) begin  // process q_p
    if (clk_enable == 1'b1) begin
        if (waiting == 1'b0) begin
            if (q_sel == q_sel_0) begin
              q <= 1'b0;
            end
            else if (q_sel == q_sel_1) begin
              q <= 1'b1;
            end
            else if (q_sel == q_sel_ir0) begin
              q <= ir[0];
            end
            // q_sel_hold: q unchanged
        end
    end
end

always @(posedge clk) begin  // process ie_p
    if (clk_enable == 1'b1) begin
        if (waiting == 1'b0) begin
            if (ie_sel == ie_sel_0) begin
              ie <= 1'b0;
            end
            else if (ie_sel == ie_sel_1) begin
              ie <= 1'b1;
            end
            else if (ie_sel == ie_sel_not_ir0) begin
              ie <= ~ir[0];
            end
            // ie_sel_hold: ie unchanged
        end
    end
end

always @(posedge clk) begin  // process prev_data_in_p
    if (clk_enable == 1'b1) begin
        if (waiting == 1'b0) begin
            prev_data_in <= data_in;
        end
    end
end

reg cond_branch_no_pol;
always @(*) begin  // process cond_branch_p
    case (ir[2:0])
        3'b000: cond_branch_no_pol = 1'b1;
        3'b001: cond_branch_no_pol = q;
        3'b010: cond_branch_no_pol = d_zero;
        3'b011: cond_branch_no_pol = df;
        3'b100: cond_branch_no_pol = ef[1];
        3'b101: cond_branch_no_pol = ef[2];
        3'b110: cond_branch_no_pol = ef[3];
        3'b111: cond_branch_no_pol = ef[4];
        default: cond_branch_no_pol = 1'bz;
    endcase
    cond_branch = cond_branch_no_pol ^ ir[3];
end

reg cond_no_skip_no_pol;
always @(*) begin  // process cond_no_skip_p
    case (ir[1:0])
        2'b00: begin
            if (ir[3] == 1'b1) begin
                cond_no_skip_no_pol = ie;
            end
            else begin
                cond_no_skip_no_pol = 1'b1;
            end
        end
        2'b01: cond_no_skip_no_pol = q;
        2'b10: cond_no_skip_no_pol = d_zero;
        2'b11: cond_no_skip_no_pol = df;
        default: cond_no_skip_no_pol = 1'bz;
    endcase
    cond_no_skip = cond_no_skip_no_pol ^ ir[3];
end

always @(*) begin  // process control_p
    // default control outputs:
    r_addr_sel = r_addr_sel_p;
    r_write_data_sel = r_write_data_sel_adder;
    r_write_high = 1'b0;
    r_write_low = 1'b0;
    mem_read = 1'b0;
    mem_write = 1'b0;
    data_out_sel = data_out_sel_d;
    d_sel = d_sel_hold;
    df_sel = df_sel_hold;
    load_ir = 1'b0;
    load_t = 1'b0;
    q_sel = q_sel_hold;
    ie_sel = ie_sel_hold;
    xp_sel = xp_sel_hold;
    adder_opb_sel = adder_opb_sel_1;
    sc = sc_execute;
    next_state = state;

    // control outputs based on state, ir:
    case (state)

        state_clear: begin
            //$display("state_clear");
            sc = sc_execute;
            next_state = state_clear_2;
            d_sel = d_sel_0;
            xp_sel = xp_sel_clear;
            q_sel = q_sel_0;
            ie_sel = ie_sel_1;
            r_addr_sel = r_addr_sel_0;
            r_write_data_sel = r_write_data_sel_0;
            r_write_high = 1'b1;
            r_write_low = 1'b1;
        end

        state_clear_2: begin
            //$display("state_clear_2");
            sc = sc_execute;
            df_sel = df_sel_d0;
            if (clear == 1'b0) begin
                next_state = state_fetch;
            end else if (wait_req == 1'b1) begin
                // subtract one from PC
                r_addr_sel = r_addr_sel_p;
                adder_opb_sel = adder_opb_sel_m1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                mem_read = 1'b1;
                next_state = state_load;
            end
        end

        state_load: begin
            //$display("state_load");
            sc = sc_execute;
            r_addr_sel = r_addr_sel_p;
            mem_read = 1'b1;
            if (dma_in_req == 1'b1) begin
                // add one to PC
                r_addr_sel = r_addr_sel_p;
                adder_opb_sel = adder_opb_sel_1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                next_state = state_dma_in;
            end else if (dma_out_req == 1'b1) begin
                // add one to PC
                r_addr_sel = r_addr_sel_p;
                adder_opb_sel = adder_opb_sel_1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                next_state = state_dma_out;
            end else if (clear == 1'b0) begin
                // We don't need to explicitly handle the transition from
                // load to reset, but we do need to handle a transition
                // from load to run, forcing a reset.
                next_state = state_clear;
            end
        end

        state_fetch: begin
           //$display("state_fetch");
            sc = sc_fetch;
            // if (data_in == inst_extend) begin
            //     next_state = state_fetch_2;
            // end else begin
            next_state = state_execute;
            // end
            r_addr_sel = r_addr_sel_p;
            adder_opb_sel = adder_opb_sel_1;
            r_write_data_sel = r_write_data_sel_adder;
            r_write_high = 1'b1;
            r_write_low = 1'b1;
            mem_read = 1'b1;
            load_ir = 1'b1;
        end

        state_execute: begin
            //$display("state_execute");
            sc = sc_execute;
            if (dma_in_req == 1'b1) begin
                next_state = state_dma_in;
                //$display("next_state = state_dma_in");
            end else if (dma_out_req == 1'b1) begin
                next_state = state_dma_out;
                //$display("next_state = state_dma_out");
            end else if ((int_req == 1'b1) && (ie == 1'b1)) begin
                next_state = state_interrupt;
                //$display("next_state = state_interrupt");
            end else if (ir == inst_idl) begin
                next_state = state_execute;
                //$display("next_state = state_execute");
            end else begin
                next_state = state_fetch;
                //$display("next_state = state_fetch");
            end

            if (ir == inst_idl) begin
                //$display("inst_idl");
                r_addr_sel = r_addr_sel_0;
                mem_read = 1'b1;
            end else if (i == inst_ldn[7:4]) begin
                //$display("inst_ldn[7:4]");
                r_addr_sel = r_addr_sel_n;
                mem_read = 1'b1;
                d_sel = d_sel_data_in;
            end else if (i == inst_inc[7:4]) begin
                //$display("inst_inc[7:4]");
                r_addr_sel = r_addr_sel_n;
                adder_opb_sel = adder_opb_sel_1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
            end else if (i == inst_dec[7:4]) begin
                //$display("inst_dec[7:4]");
                r_addr_sel = r_addr_sel_n;
                adder_opb_sel = adder_opb_sel_m1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
            end else if (i == inst_short_branch[7:4]) begin
                //$display("inst_short_branch[7:4]");
                r_addr_sel = r_addr_sel_p;
                adder_opb_sel = adder_opb_sel_1;
                r_write_data_sel = r_write_data_sel_branch;
                r_write_high = 1'b0;
                r_write_low = 1'b1;
                mem_read = 1'b1;
            end else if (i == inst_lda[7:4]) begin
                //$display("inst_lda[7:4]");
                r_addr_sel = r_addr_sel_n;
                adder_opb_sel = adder_opb_sel_1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                mem_read = 1'b1;
                d_sel = d_sel_data_in;
            end else if (i == inst_str[7:4]) begin
                //$display("inst_str[7:4]");
                r_addr_sel = r_addr_sel_n;
                data_out_sel = data_out_sel_d;
                mem_write = 1'b1;
            end
            else if ((i == inst_inp[7:4]) && (n[3] == 1'b1)) begin
                //$display("inst_inp[7:4] && n[3]");
                r_addr_sel = r_addr_sel_x;
                mem_write = 1'b1;
                d_sel = d_sel_data_in;
            end else if ((ir == inst_ret) || (ir == inst_dis)) begin
                //$display("inst_ret inst_dis");
                r_addr_sel = r_addr_sel_x;
                adder_opb_sel = adder_opb_sel_1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                mem_read = 1'b1;
                xp_sel = xp_sel_data_in;
                ie_sel = ie_sel_not_ir0;
            end else if (ir == inst_ldxa) begin
                //$display("inst_ldxa");
                r_addr_sel = r_addr_sel_x;
                adder_opb_sel = adder_opb_sel_1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                mem_read = 1'b1;
                d_sel = d_sel_data_in;
            end else if (ir == inst_stxd) begin
                //$display("inst_stxd");
                r_addr_sel = r_addr_sel_x;
                adder_opb_sel = adder_opb_sel_m1;
                data_out_sel = data_out_sel_d;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                mem_write = 1'b1;
            end else if ((ir == inst_adc) || (ir == inst_sdb) || (ir == inst_smb) ||
                        (ir == inst_add) || (ir == inst_sub) || (ir == inst_sm)) begin
                //$display("inst_adc inst_sdb inst_smb inst_add inst_sub inst_sm");
                r_addr_sel = r_addr_sel_x;
                mem_read = 1'b1;
                d_sel = d_sel_alu;
                df_sel = df_sel_carry;
            end else if ((ir == inst_shrc) || (ir == inst_shr)) begin
                //$display("inst_shrc inst_shr");
                d_sel = d_sel_shifter;
                df_sel = df_sel_d0;
            end else if (ir == inst_sav) begin
                //$display("inst_sav");
                r_addr_sel = r_addr_sel_x;
                data_out_sel = data_out_sel_t;
                mem_write = 1'b1;
            end else if (ir == inst_mark) begin
                //$display("inst_mark");
                r_addr_sel = r_addr_sel_2;
                adder_opb_sel = adder_opb_sel_m1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                data_out_sel = data_out_sel_xp;
                load_t = 1'b1;
                xp_sel = xp_sel_mark;
            end
            else if ((ir == inst_req) || (ir == inst_seq)) begin
                //$display("inst_req inst_seq");
                q_sel = q_sel_ir0;
            end else if ((ir == inst_adci) || (ir == inst_sdbi) || (ir == inst_smbi) ||
                         (ir == inst_adi)  || (ir == inst_sdi)  || (ir == inst_smi)) begin
                //$display("inst_adci inst_sdbi inst_smbi inst_adi inst_sdi inst_smi");
                r_addr_sel = r_addr_sel_p;
                adder_opb_sel = adder_opb_sel_1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                mem_read = 1'b1;
                d_sel = d_sel_alu;
                df_sel = df_sel_carry;
            end else if ((ir == inst_shlc) || (ir == inst_shl)) begin
                //$display("inst_shlc inst_shl");
                d_sel = d_sel_shifter;
                df_sel = df_sel_d7;
            end else if ((i == inst_glo[7:4]) || (i == inst_ghi[7:4])) begin
                //$display("inst_glo[7:4] inst_ghi[7:4]");
                r_addr_sel = r_addr_sel_n;
                d_sel = d_sel_r;
            end else if (i == inst_plo[7:4]) begin
                //$display("inst_plo[7:4]");
                r_addr_sel = r_addr_sel_n;
                r_write_data_sel = r_write_data_sel_d;
                r_write_high = 1'b0;
                r_write_low = 1'b1;
            end else if (i == inst_phi[7:4]) begin
                //$display("inst_phi[7:4]");
                r_addr_sel = r_addr_sel_n;
                r_write_data_sel = r_write_data_sel_d;
                r_write_high = 1'b1;
                r_write_low = 1'b0;
            end else if (i == inst_long_branch_skip[7:4]) begin
                //$display("inst_long_branch_skip[7:4]");
                next_state = state_execute_2;
                if (ir[2] == 1'b0) begin
                    r_addr_sel = r_addr_sel_p;
                    adder_opb_sel = adder_opb_sel_1;
                    r_write_data_sel = r_write_data_sel_adder;
                    r_write_high = 1'b1;
                    r_write_low = 1'b1;
                    mem_read = 1'b1;
                end else begin
                    r_addr_sel = r_addr_sel_p;
                    if (cond_no_skip == 1'b1) begin
                        adder_opb_sel = adder_opb_sel_0;
                    end else begin
                        adder_opb_sel = adder_opb_sel_1;
                    end
                    r_write_data_sel = r_write_data_sel_adder;
                    r_write_high = 1'b1;
                    r_write_low = 1'b1;
                end
            end else if (i == inst_sep[7:4]) begin
                //$display("inst_sep[7:4]");
                xp_sel = xp_sel_sep;
            end else if (i == inst_sex[7:4]) begin
                //$display("inst_sex[7:4]");
                xp_sel = xp_sel_sex;
            end else if (ir == inst_ldx) begin
                //$display("inst_ldx");
                r_addr_sel = r_addr_sel_x;
                mem_read = 1'b1;
                d_sel = d_sel_data_in;
            end else if ((ir == inst_or) || (ir == inst_and) || (ir == inst_xor)) begin
                //$display("inst_or inst_and inst_xor");
                r_addr_sel = r_addr_sel_x;
                mem_read = 1'b1;
                d_sel = d_sel_alu;
            end else if (ir == inst_ldi) begin
                //$display("inst_ldi");
                r_addr_sel = r_addr_sel_p;
                adder_opb_sel = adder_opb_sel_1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                mem_read = 1'b1;
                d_sel = d_sel_data_in;
            end else if ((ir == inst_ori) || (ir == inst_ani) || (ir == inst_xri)) begin
                //$display("inst_ori inst_ani inst_xri");
                r_addr_sel = r_addr_sel_p;
                adder_opb_sel = adder_opb_sel_1;
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                mem_read = 1'b1;
                d_sel = d_sel_alu;
            end else begin
                //$display("illegal instruction");
            // illegal instruction, shouldn't happen
            // Nothing to do here
            end
        end

        state_execute_2: begin
            //$display("state_execute_2");
            sc = sc_execute;
            if (dma_in_req == 1'b1) begin
                next_state = state_dma_in;
                //$display("next_state = state_dma_in");
            end else if (dma_out_req == 1'b1) begin
                next_state = state_dma_out;
                //$display("next_state = state_dma_out");
            end else if ((int_req == 1'b1) && (ie == 1'b1)) begin
                next_state = state_interrupt;
                //$display("next_state = state_interrupt");
            end else begin
                next_state = state_fetch;
                //$display("next_state = state_fetch");
            end
            if (ir[2] == 1'b0) begin
                // second execute cycle of long branch
                r_addr_sel = r_addr_sel_p;
                r_write_data_sel = r_write_data_sel_branch;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
                mem_read = 1'b1;
            end else begin
                // second execute cycle of long skip
                r_addr_sel = r_addr_sel_p;
                if (cond_no_skip == 1'b1) begin
                    adder_opb_sel = adder_opb_sel_0;
                end else begin
                    adder_opb_sel = adder_opb_sel_1;
                end
                r_write_data_sel = r_write_data_sel_adder;
                r_write_high = 1'b1;
                r_write_low = 1'b1;
            end
        end

        state_dma_in: begin
            //$display("state_dma_in");
            sc = sc_dma;
            r_addr_sel = r_addr_sel_0;
            adder_opb_sel = adder_opb_sel_1;
            r_write_data_sel = r_write_data_sel_adder;
            r_write_high = 1'b1;
            r_write_low = 1'b1;
            mem_write = 1'b1;
            if (dma_in_req == 1'b1) begin
                next_state = state_dma_in;
                //$display("next_state = state_dma_in");
            end else if (dma_out_req == 1'b1) begin
                next_state = state_dma_out;
                //$display("next_state = state_dma_out");
            end else if (clear == 1'b1) begin
                r_write_high = 1'b0;
                r_write_low = 1'b0;
                next_state = state_load;
                //$display("next_state = state_load");
            end else if ((int_req == 1'b1) && (ie == 1'b1)) begin
                next_state = state_interrupt;
                //$display("next_state = state_interrupt");
            end else begin
                next_state = state_fetch;
                //$display("next_state = state_fetch");
            end
        end

        state_dma_out: begin
            //$display("state_dma_out");
            sc = sc_dma;
            r_addr_sel = r_addr_sel_0;
            adder_opb_sel = adder_opb_sel_1;
            r_write_data_sel = r_write_data_sel_adder;
            r_write_high = 1'b1;
            r_write_low = 1'b1;
            mem_read = 1'b1;
            if (dma_in_req == 1'b1) begin
                next_state = state_dma_in;
                //$display("next_state = state_dma_in");
            end else if (dma_out_req == 1'b1) begin
                next_state = state_dma_out;
                //$display("next_state = state_dma_out");
            end else if (clear == 1'b1) begin
                r_write_high = 1'b0;
                r_write_low = 1'b0;
                next_state = state_load;
                //$display("next_state = state_load");
            end else if ((int_req == 1'b1) && (ie == 1'b1)) begin
                next_state = state_interrupt;
                //$display("next_state = state_interrupt");
            end else begin
                next_state = state_fetch;
                //$display("next_state = state_fetch");
            end
        end

        state_interrupt: begin
            //$display("state_interrupt");
            sc = sc_interrupt;
            if (dma_in_req == 1'b1) begin
                next_state = state_dma_in;
                //$display("next_state = state_dma_in");
            end else if (dma_out_req == 1'b1) begin
                next_state = state_dma_out;
                //$display("next_state = state_dma_out");
            end else begin
                next_state = state_fetch;
                //$display("next_state = state_fetch");
            end
            load_t = 1'b1;
            xp_sel = xp_sel_interrupt;
            ie_sel = ie_sel_0;
        end

        default: begin
            sc = sc_execute;
            next_state = state_clear;      // should never happen
        end

    endcase
end

always @(posedge clk or posedge clk_enable) begin
    if (clk_enable == 1'b1) begin
        if ((clear == 1'b1) && (wait_req == 1'b0)) begin
            state <= state_clear;
        end else if (waiting == 1'b0) begin
            state <= next_state;
        end
    end
end

endmodule