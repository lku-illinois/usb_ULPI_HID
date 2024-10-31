module timer
(
    // setup
    input   logic           clk,
    input   logic           rst,
    // cdc
    input   logic   [63:0]  data_i,
    input   logic           data_valid,
    // axi
    output  logic           bmem_resp,
    output  logic           bmem_wr_en,
    output  logic   [63:0]  bmem_wr_data,
    output  logic   [31:0]  bmem_wr_addr
);
    localparam TIMER_COUNT = 18'd200000;

    logic   [17:0]  counter;
    // ready for new request
    logic   new_request_q;
    // trigger request
    logic   grant;
    
    


    // new request
    always_ff @( posedge clk ) begin 
        if(rst) 
            new_request_q <= 1'b0;
        else if(data_valid)
            new_request_q <= 1'b1;
        else if(bmem_resp)
            new_request_q <= 1'b0;
        else
            new_request_q <= new_request_q;
    end



endmodule