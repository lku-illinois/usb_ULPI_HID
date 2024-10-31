module cdc
(
    input   logic           usb_clk,
    input   logic           axi_clk,
    input   logic           rst,

    input   logic   [63:0]  usb_data_i,
    input   logic           usb_data_valid_i,

    output  logic   [63:0]  usb_data_o,
    output  logic           usb_data_valid_o
);
    // control
    logic           src_data_valid;
    logic           dest_data_valid_ff1, dest_data_valid_ff2;
    logic           mux_data_valid_o;
    logic           dest_data_valid_ff3;

    // data
    logic   [63:0]  src_data;
    logic   [63:0]  mux_data_o;
    logic   [63:0]  dest_data_ff;

    /////////////////////////////////////////////////////////////
    // Control signal - usb_data_valid_i
    /////////////////////////////////////////////////////////////
    // FF control signal @ source clock 
    always_ff @(posedge usb_clk or posedge rst) begin 
        if(rst) src_data_valid <= 1'b0;
        else    src_data_valid <= usb_data_valid_i;
    end

    // two FF synchronization control signal from source to destination
    always_ff @( posedge axi_clk or posedge rst ) begin 
        if(rst) begin
            dest_data_valid_ff1 <= 1'b0;
            dest_data_valid_ff2 <= 1'b0;
        end
        else begin
            dest_data_valid_ff1 <= src_data_valid;
            dest_data_valid_ff2 <= dest_data_valid_ff1;
        end
    end

    /////////////////////////////////////////////////////////////
    // Data signal - usb_data
    /////////////////////////////////////////////////////////////
    // FF data signal @ source clock
    always_ff @(posedge usb_clk or posedge rst) begin 
        if(rst) src_data <= 1'b0;
        else    src_data <= usb_data_i;
    end

    // mux out
    always_comb begin 
        case(dest_data_valid_ff2)
            1'b0:       mux_data_o = dest_data_ff;
            1'b1:       mux_data_o = src_data;
            default:    mux_data_o = dest_data_ff;
        endcase
    end

    // destination data signal
    always_ff @(posedge axi_clk or posedge rst) begin 
        if(rst) dest_data_ff <= 1'b0;
        else    dest_data_ff <= mux_data_o;
    end

    /////////////////////////////////////////////////////////////
    // Data signal - usb_data_valid_i
    /////////////////////////////////////////////////////////////
    // mux out
    always_comb begin 
        case(dest_data_valid_ff2)
            1'b0:       mux_data_valid_o = dest_data_valid_ff3;
            1'b1:       mux_data_valid_o = src_data_valid;
            default:    mux_data_valid_o = dest_data_valid_ff3;
        endcase
    end

    // destination data signal
    always_ff @(posedge axi_clk or posedge rst) begin 
        if(rst) dest_data_valid_ff3 <= 1'b0;
        else    dest_data_valid_ff3 <= mux_data_valid_o;
    end

    /////////////////////////////////////////////////////////////
    // Output signal
    /////////////////////////////////////////////////////////////
    assign usb_data_valid_o = dest_data_valid_ff3;
    assign usb_data_o = dest_data_ff;

endmodule