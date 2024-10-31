module usb_host
(
    //ULPI
    input   logic           clk,
    input   logic           rst,
    input   logic   [7:0]   data_i, //output for ULPI
    input   logic           dir_i,    //output for ULPI
    input   logic           nxt_i,    //output for ULPI

    output  logic   [7:0]   data_o,
    output  logic           stp_o,

    //cdc
    output  logic   [63:0]  reg_o,
    output  logic           reg_valid_o
);
    logic           host_connect_w;
    logic           reg_flush;
    logic           reg_push;
    logic   [7:0]   reg_data_i;
    logic           reg_active_read;
    logic   [63:0]  reg_o_tmp;
    logic   [3:0]   reg_count;
    logic           reg_active_IN;

    usb_fsm usb_fsm(
        .clk(clk),
        .rst(rst),
        .data_i(data_i),
        .dir_i(dir_i),
        .nxt_i(nxt_i),
        .data_o(data_o),
        .stp_o(stp_o),
        .host_connect_o(host_connect_w),
        .new_read(reg_flush),
        .data_store_valid(reg_push),
        .data_store_o(reg_data_i),
        .active_read(reg_active_read),
        .active_IN(reg_active_IN),
        .*
    );

    always_ff @( posedge clk ) begin 
        if(rst || reg_flush) begin
            reg_o_tmp <= '0;
            reg_count <= '0;
        end
        // in rx_data + valid input data
        else if(reg_active_read && reg_push) begin
            reg_count <= reg_count + 1'b1;
            reg_o_tmp <= {reg_o_tmp[55:0],reg_data_i};
        end
        // in rx_data + no valid input data
        else begin
            reg_count <= reg_count;
            reg_o_tmp <= reg_o_tmp;
        end
    end

    always_comb begin 
        if(rst || reg_flush || ~host_connect_w) begin
            reg_o = '0;
            reg_valid_o = '0;
        end
        else if(~reg_active_read && reg_active_IN) begin
            reg_valid_o = 1'b1;
            case(reg_count)
                4'd3:   reg_o = {reg_o_tmp[23:16], 56'b0};
                4'd4:   reg_o = {reg_o_tmp[31:16], 48'b0};
                4'd5:   reg_o = {reg_o_tmp[39:16], 40'b0};
                4'd6:   reg_o = {reg_o_tmp[47:16], 32'b0};
                4'd7:   reg_o = {reg_o_tmp[55:16], 24'b0};
                4'd8:   reg_o = {reg_o_tmp[63:16], 16'b0};
                default: reg_o = '0;
            endcase
        end
        else begin
            reg_o = '0;
            reg_valid_o = 1'b0;
        end
    end
    // always_ff @( posedge clk) begin 
    //     if(rst || reg_flush || host_disconnect_w) begin
    //         reg_o <= '0;
    //         reg_valid_o <= '0;
    //     end
    //     else if(~reg_active_read && reg_active_IN) begin
    //         reg_valid_o <= 1'b1;
    //         case(reg_count)
    //             4'd3:   reg_o <= {reg_o_tmp[23:16], 56'b0};
    //             4'd4:   reg_o <= {reg_o_tmp[31:16], 48'b0};
    //             4'd5:   reg_o <= {reg_o_tmp[39:16], 40'b0};
    //             4'd6:   reg_o <= {reg_o_tmp[47:16], 32'b0};
    //             4'd7:   reg_o <= {reg_o_tmp[55:16], 24'b0};
    //             4'd8:   reg_o <= {reg_o_tmp[63:16], 16'b0};
    //             default: reg_o <= '0;
    //         endcase
    //     end
    //     else begin
    //         reg_o <= reg_o;
    //         reg_valid_o <= reg_valid_o;
    //     end
    // end
endmodule