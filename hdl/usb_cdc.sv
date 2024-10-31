module usb_cdc
(
    // setup
    input   logic           usb_clk,
    input   logic           axi_clk,
    input   logic           rst, 
    // ULPI
    input   logic   [7:0]   data_i, //output for ULPI
    input   logic           dir_i,    //output for ULPI
    input   logic           nxt_i,    //output for ULPI
    output  logic   [7:0]   data_o,
    output  logic           stp_o,
    // CDC
    output  logic   [63:0]  usb_data_o,
    output  logic           usb_data_valid_o
);
logic   [63:0]  reg_w;
logic           reg_valid_w;


usb_host usb_host(
    .clk(usb_clk),
    .rst(rst),
    .data_i(data_i),
    .dir_i(dir_i),
    .nxt_i(nxt_i),
    .data_o(data_o),
    .stp_o(stp_o),
    .reg_o(reg_w),
    .reg_valid_o(reg_valid_w),
    .*
);

cdc cdc(
    .usb_clk(usb_clk),
    .axi_clk(axi_clk),
    .rst(rst),
    .usb_data_i(reg_w),
    .usb_data_valid_i(reg_valid_w),
    .usb_data_o(usb_data_o),
    .usb_data_valid_o(usb_data_valid_o),
    .*
);

endmodule