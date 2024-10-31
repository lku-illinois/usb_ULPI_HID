module usb_fsm(
    input   logic           clk,
    input   logic           rst,
    input   logic   [7:0]   data_i,
    input   logic           dir_i,
    input   logic           nxt_i,

    output  logic   [7:0]   data_o,
    output  logic           stp_o,
    // output  logic           host_disconnect_o,
    output  logic           host_connect_o,

    //signal a fifo flush
    output  logic           new_read,
    //fifo push
    output  logic           data_store_valid,
    //fifo data_i
    output  logic   [7:0]   data_store_o,
    //actively reading
    output  logic           active_read,
    output  logic           active_IN
);

// // States            
// localparam STATE_IDLE       = 4'd0;
// localparam STATE_RX_DATA    = 4'd1;
// localparam STATE_TX_PID     = 4'd2;
// localparam STATE_TX_DATA    = 4'd3;
// localparam STATE_TX_CRC1    = 4'd4;
// localparam STATE_TX_CRC2    = 4'd5;
// localparam STATE_TX_TOKEN1  = 4'd6;
// localparam STATE_TX_TOKEN2  = 4'd7;
// localparam STATE_TX_TOKEN3  = 4'd8;
// localparam STATE_TX_ACKNAK  = 4'd9;
// localparam STATE_TX_WAIT   = 4'd10;
// localparam STATE_RX_WAIT1   = 4'd11;
// localparam STATE_RX_WAIT2   = 4'd12;
// localparam STATE_TX_IFS     = 4'd13;
// localparam STATE_TX_TURNAROUND = 4'd14;

enum int unsigned{
    STATE_IDLE, STATE_RX_DATA, STATE_TX_PID, STATE_TX_DATA,
    STATE_TX_CRC1, STATE_TX_CRC2, STATE_TX_TOKEN1, STATE_TX_TOKEN2, STATE_TX_TOKEN3,
    STATE_TX_ACKNAK, STATE_TX_WAIT, STATE_RX_WAIT1, STATE_RX_WAIT2,
    STATE_TX_IFS, STATE_TX_TURNAROUND, STATE_RESET, STATE_INIT1, STATE_INIT2, STATE_INIT3
} state_q, next_state_r;

//local param
localparam SOF_PID   = 8'h45;           //8'b01000101;
localparam SETUP_PID = 8'h4d;           //8'b01001101;
localparam IN_PID    = 8'h49;           //8'b01001001;
localparam OUT_PID   = 8'h41;           //8'b01000001;
localparam DATA0_PID = 8'h43;           //8'b01000011;
localparam DATA1_PID = 8'h4b;           //8'b01001011;
localparam ACK_PID   = 8'h42;           //8'b01000010;

localparam TOKEN_SOF_CRC5 = 5'b11111;
localparam TOKEN_IN_CRC5 = 5'b11111;
localparam TOKEN_OUT_CRC5 = 5'b11111;
localparam TOKEN_SETUP_ADDR_CRC5 = 5'b11111;
localparam TOKEN_SETUP_CFG_CRC5 = 5'b11111;


localparam ADDR0     = 7'h00;
localparam ADDR1     = 7'h01;
localparam EP0       = 4'h0;
localparam EP1       = 4'h1;

localparam SETUP_ADDR_bmRequestType = 8'h00;
localparam SETUP_ADDR_bRequest      = 8'h05;
localparam SETUP_ADDR_wValue        = 16'h0001;
localparam SETUP_ADDR_wIndex        = 16'h0000;
localparam SETUP_ADDR_wLength       = 16'h0000;

localparam SETUP_CFG_bmRequestType = 8'h00;
localparam SETUP_CFG_bRequest      = 8'h09;
localparam SETUP_CFG_wValue        = 16'h0001;
localparam SETUP_CFG_wIndex        = 16'h0000;
localparam SETUP_CFG_wLength       = 16'h0000;

localparam DATA_OUT_CRC16 = 16'hffff;
localparam DATA_SETUP_ADDR_CRC16 = 16'hffff;
localparam DATA_SETUP_CFG_CRC16 = 16'hffff;

localparam LINESTATE_SE0    = 2'b00;
localparam LINESTATE_SE1    = 2'b11;
localparam LINESTATE_J      = 2'b01;
localparam LINESTATE_K      = 2'b10;

localparam SOF_COUNT = 16'd60000;
localparam RX_TIMEOUT_DIR = 6'd60;
localparam RX_TIMEOUT_NXT = 15'd30000;
localparam TX_TIMEOUT_DIR = 6'd60;

localparam INIT1 = 8'h85;
localparam INIT2 = 8'h20;


// flag for what token packet to send
logic token_sof_q, token_sof_q_delay;
logic token_in_q;
logic token_setup_addr_q,token_setup_addr_q_delay;
logic token_setup_cfg_q, token_setup_cfg_q_delay;
// flag if the token packet is sent
logic token_sof_done;
// logic token_in_done;
logic token_setup_addr_done;
logic token_setup_cfg_done;
// logic token_out_done;

// flag for what data packet to send
logic data_setup_addr_q;
logic data_setup_cfg_q;
// flag if the data packet is sent
logic data_setup_addr_done;
logic data_setup_cfg_done;
logic data_out_done;

// sof frame number (increments every sof)
logic [10:0] sof_frame_num;

// alternate between data0 (0) or data1 (1)
logic       data_pid;

// // crc5 for token packet
// logic [4:0] crc5;
// // crc16 for data packet
// logic [15:0] crc16

// data packet, how many bytes left to send
logic [3:0] data_byte_count_q;

logic [7:0] data_o_tmp;
logic       stp_o_tmp;
logic       data_store_valid_tmp;
logic [7:0] data_store_o_tmp;
// logic       host_disconnect_o_tmp;

// timeout at recieve wait state
logic       rx_resp_timeout_1, rx_resp_timeout_2;
// data timeout counter
logic [5:0]  rx_dir_counter;
logic [14:0] rx_nxt_counter;
logic [5:0]  tx_dir_counter;

// rx signals
logic       rx_active_w;
logic       rx_error_w;
logic       rx_hostdisconnect_w;
logic       send_ack_q;
logic       crc_error_w;
logic [7:0] status_response_q; 

// ack signals
logic       tx_resp_timeout;

// determine if my device is connected: 0: disconnect  1:connect
logic       connect_q, connect_w;
logic       connect_trigger;

// determine turnaround cycle
logic turnaround_w;
logic dir_delay;
// determine rx_cmd
logic rx_cmd_fnd_w;
// record current linestate
logic [1:0] rx_linestate_w, rx_linestate_q;

// sof control signal
logic [15:0] sof_counter;
logic        sof_pulse;

logic        start;

logic   nxt_delay;
logic   data_PID_flag;

logic   new_read_tmp;
logic   active_read_tmp;
logic   active_IN_q;
logic   active_IN_start, active_IN_stop;

//-----------------------------------------------------------------
// State Machine
//-----------------------------------------------------------------
// logic [3:0] state_q;
// logic [3:0] next_state_r;

always_comb begin
    next_state_r = state_q;
    data_o_tmp = 'x;
    token_sof_done = 1'b0;
    token_setup_addr_done = 1'b0;
    token_setup_cfg_done = 1'b0;
    stp_o_tmp = 1'b0;
    data_setup_addr_done = 1'b0;
    data_setup_cfg_done  = 1'b0;
    data_out_done        = 1'b0;
    data_store_o_tmp = 8'b00000000;
    data_store_valid_tmp = 1'b0;
    new_read_tmp = 1'b0;
    active_read_tmp = 1'b0;
    active_IN_start = 1'b0;
    active_IN_stop = 1'b0;
    // host_disconnect_o_tmp = 1'b0;
    // rx_active_w         = 1'b0;
    // rx_error_w          = 1'b0;
    // rx_hostdisconnect_w = 1'b0;
    // token_in_done = 1'b0;
    // token_out_done = 1'b0;
        
    //-----------------------------------------
    // Tx State Machine
    //-----------------------------------------
    case (state_q)

        //-----------------------------------------
        // TX_TOKEN1 (byte 1 of token) - PID packet (tx_cmd)
        //-----------------------------------------
        STATE_TX_TOKEN1 :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                if(!dir_i) begin
                    // if setup is required
                    if(token_setup_addr_q || token_setup_cfg_q) data_o_tmp = SETUP_PID;
                    // if sof is required
                    else if(token_sof_q) data_o_tmp = SOF_PID;
                    // if IN is required
                    else if(token_in_q) data_o_tmp = IN_PID;
                    // if out is required
                    else data_o_tmp = OUT_PID;
                end 
                //check if ULPI is ready to recieve data
                if (nxt_i)
                    next_state_r = STATE_TX_TOKEN2;
            end
        end
        //-----------------------------------------
        // TX_TOKEN2 (byte 2 of token) - Address and Endpoint
        //-----------------------------------------
        STATE_TX_TOKEN2 :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                if(!dir_i)begin
                    // setup addr: ADDR0 EP0
                    if(token_setup_addr_q) data_o_tmp = {ADDR0, EP0[3]};
                    // setup config: ADDR1 EP0
                    else if(token_setup_cfg_q) data_o_tmp = {ADDR1, EP0[3]};
                    // sof: frame number [7:0]
                    else if(token_sof_q) data_o_tmp = sof_frame_num[7:0];
                    // In: ADDR1 EP1
                    else if(token_in_q) data_o_tmp = {ADDR1, EP1[3]};
                    // Out: ADDR1 EP1
                    else data_o_tmp = {ADDR1, EP1[3]};
                end
                //check if ULPI is ready to recieve data
                if (nxt_i)
                    next_state_r = STATE_TX_TOKEN3;      
            end  
        end
        //-----------------------------------------
        // TX_TOKEN3 (byte 3 of token) - CRC5
        //-----------------------------------------
        STATE_TX_TOKEN3 :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                if(!dir_i)begin
                    // sof: frame number [7:0]
                    if(token_sof_q) data_o_tmp = {sof_frame_num[10:8], TOKEN_SOF_CRC5};
                    // setup addr: ADDR0 EP0
                    else if(token_setup_addr_q) data_o_tmp = {EP0[2:0], TOKEN_SETUP_ADDR_CRC5};
                    // setup config: ADDR1 EP0
                    else if(token_setup_cfg_q) data_o_tmp = {EP0[2:0], TOKEN_SETUP_CFG_CRC5};
                    // In: ADDR1 EP1
                    else if(token_in_q) data_o_tmp = {EP1[2:0], TOKEN_IN_CRC5};
                    // Out: ADDR1 EP1
                    else data_o_tmp = {EP1[2:0], TOKEN_OUT_CRC5};
                end
                // Data sent?
                if (nxt_i)
                begin
                    //needs pause before new packet - Inter Frame Pausing
                    // OUT/SETUP - Send data or ZLP
                    //needs pause before new packet - Inter Frame Pausing 
                    if (token_setup_addr_q)begin
                        token_setup_addr_done = 1'b1;
                        next_state_r = STATE_TX_IFS;
                    end
                    else if (token_setup_cfg_q)begin
                        token_setup_cfg_done = 1'b1;
                        next_state_r = STATE_TX_IFS;
                    end
                    // SOF - no data packet
                    else if (token_sof_q) begin
                        token_sof_done = 1'b1;
                        next_state_r = STATE_TX_IFS;
                    end 
                    // IN - wait for data
                    else if (token_in_q) begin
                        // token_in_done = 1'b1;
                        next_state_r = STATE_RX_WAIT1;
                    end 
                    else begin
                        // token_out_done = 1'b1;
                        next_state_r = STATE_TX_IFS;
                    end
                end
            end
        end
        //-----------------------------------------
        // TX_IFS   -  Inter Frame Pausing: wait one cycle
        //-----------------------------------------
        STATE_TX_IFS :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                // after done sending token packet, we set stp high for 1 cycle
                stp_o_tmp = 1'b1;
                
                if (token_setup_addr_q_delay || token_setup_cfg_q_delay)
                    next_state_r = STATE_TX_PID;
                // SOF - no data packet
                else if (token_sof_q_delay)
                    next_state_r = STATE_IDLE;
                // OUT/SETUP - Send data or ZLP
                else
                    next_state_r = STATE_TX_PID;
            end
       
        end
        //-----------------------------------------
        // TX_PID   -   data packet is generated and sent (PID: data0/data1 for this state)
        //-----------------------------------------
        STATE_TX_PID :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                //setup is always data0
                if(data_setup_addr_q || data_setup_cfg_q) data_o_tmp = DATA0_PID;
                // data0 or data1
                else data_o_tmp = data_pid ? DATA1_PID : DATA0_PID;

                if(nxt_i) next_state_r = STATE_TX_DATA;
            end
        end
        //-----------------------------------------
        // TX_DATA  -   this is where all data packet is sent (1byte per cycle), break if all sent
        //-----------------------------------------
        STATE_TX_DATA :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                // setup address data packet
                if(data_setup_addr_q) begin
                    if(data_byte_count_q == 4'd8) data_o_tmp = SETUP_ADDR_bmRequestType;
                    if(data_byte_count_q == 4'd7) data_o_tmp = SETUP_ADDR_bRequest;
                    if(data_byte_count_q == 4'd6) data_o_tmp = SETUP_ADDR_wValue[15:8];
                    if(data_byte_count_q == 4'd5) data_o_tmp = SETUP_ADDR_wValue[7:0];
                    if(data_byte_count_q == 4'd4) data_o_tmp = SETUP_ADDR_wIndex[15:8];
                    if(data_byte_count_q == 4'd3) data_o_tmp = SETUP_ADDR_wIndex[7:0]; 
                    if(data_byte_count_q == 4'd2) data_o_tmp = SETUP_ADDR_wLength[15:8];
                    if(data_byte_count_q == 4'd1) data_o_tmp = SETUP_ADDR_wLength[7:0];
                end
                // setup configuration data packet
                else if(data_setup_cfg_q) begin
                    if(data_byte_count_q == 4'd8) data_o_tmp = SETUP_CFG_bmRequestType;
                    if(data_byte_count_q == 4'd7) data_o_tmp = SETUP_CFG_bRequest;
                    if(data_byte_count_q == 4'd6) data_o_tmp = SETUP_CFG_wValue[15:8];
                    if(data_byte_count_q == 4'd5) data_o_tmp = SETUP_CFG_wValue[7:0];
                    if(data_byte_count_q == 4'd4) data_o_tmp = SETUP_CFG_wIndex[15:8];
                    if(data_byte_count_q == 4'd3) data_o_tmp = SETUP_CFG_wIndex[7:0]; 
                    if(data_byte_count_q == 4'd2) data_o_tmp = SETUP_CFG_wLength[15:8];
                    if(data_byte_count_q == 4'd1) data_o_tmp = SETUP_CFG_wLength[7:0];
                end
                // OUT data packet
                else begin
                    if(data_byte_count_q == 4'd8) data_o_tmp = 8'h01;
                    if(data_byte_count_q == 4'd7) data_o_tmp = 8'h01;
                    if(data_byte_count_q == 4'd6) data_o_tmp = 8'h01;
                    if(data_byte_count_q == 4'd5) data_o_tmp = 8'h01;
                    if(data_byte_count_q == 4'd4) data_o_tmp = 8'h01;
                    if(data_byte_count_q == 4'd3) data_o_tmp = 8'h01;
                    if(data_byte_count_q == 4'd2) data_o_tmp = 8'h01;
                    if(data_byte_count_q == 4'd1) data_o_tmp = 8'h01;
                end

                // Last data byte sent?
                if (nxt_i && (data_byte_count_q == 16'd1)) begin
                    // when all data packet is sent, start generating crc16
                    next_state_r = STATE_TX_CRC1;
                end
            end
        end
        //-----------------------------------------
        // TX_CRC1 (first byte)
        // for data packet, crc is 16 bit, need 2 cycle to send, 1byte each
        //-----------------------------------------
        STATE_TX_CRC1 :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                if(data_setup_addr_q) 
                    data_o_tmp = DATA_SETUP_ADDR_CRC16[7:0];
                else if(data_setup_cfg_q) 
                    data_o_tmp = DATA_SETUP_CFG_CRC16[7:0];
                else 
                    data_o_tmp = DATA_OUT_CRC16[7:0];

                // Data sent?
                if (nxt_i)
                    next_state_r = STATE_TX_CRC2;
            end
        end
        //-----------------------------------------
        // TX_CRC (second byte)
        //-----------------------------------------
        STATE_TX_CRC2 :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                if(data_setup_addr_q) 
                    data_o_tmp = DATA_SETUP_ADDR_CRC16[15:8];
                else if(data_setup_cfg_q) 
                    data_o_tmp = DATA_SETUP_CFG_CRC16[15:8];
                else 
                    data_o_tmp = DATA_OUT_CRC16[15:8];

                // Data sent?
                if (nxt_i) begin
                    next_state_r = STATE_RX_WAIT1;

                    if(data_setup_addr_q) begin
                        data_setup_addr_done = 1'b1;
                        data_setup_cfg_done  = 1'b0;
                        data_out_done        = 1'b0;
                    end
                    else if (data_setup_cfg_q) begin
                        data_setup_addr_done = 1'b0;
                        data_setup_cfg_done  = 1'b1;
                        data_out_done        = 1'b0;
                    end
                    else begin
                        data_setup_addr_done = 1'b0;
                        data_setup_cfg_done  = 1'b0;
                        data_out_done        = 1'b1;
                    end                          
                end
            end
        end     
        //-----------------------------------------
        // STATE_TX_WAIT    -   turnaround cycle
        //-----------------------------------------
        STATE_TX_WAIT :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                // turnaround cycle has successfully deasserted dir_i
                if (~dir_i) begin
                    active_IN_start = 1'b1;
                    next_state_r = STATE_TX_ACKNAK;
                end
                    // Waited long enough?
                else if (tx_resp_timeout)
                    next_state_r = STATE_IDLE;
            end
        end    
        //-----------------------------------------
        // STATE_TX_ACKNAK  -   send ack signal back to device
        //-----------------------------------------
        STATE_TX_ACKNAK :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                data_o_tmp = ACK_PID;
                // Data sent?
                if (nxt_i)
                    next_state_r = STATE_IDLE;
            end
        end
        //-----------------------------------------
        // STATE_RX_WAIT1   -   rise stp
        //-----------------------------------------
        STATE_RX_WAIT1 :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                stp_o_tmp = 1'b1;
                // Data received?
                next_state_r = STATE_RX_WAIT2;
            end
        end
        //-----------------------------------------
        // STATE_RX_WAIT2    -   turnaround cycle
        //-----------------------------------------
        STATE_RX_WAIT2 :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                // turnaround cycle has successfully asserted dir_i
                if (dir_i) begin
                    next_state_r = STATE_RX_DATA;
                    new_read_tmp = 1'b1;
                    active_IN_stop = 1'b1;
                end
                    // Waited long enough?
                else if (rx_resp_timeout_1) begin
                    next_state_r = STATE_IDLE;
                    new_read_tmp = 0;
                end
            end
        end
        //-----------------------------------------
        // RX_DATA
        //-----------------------------------------
        STATE_RX_DATA :
        begin
            if(rx_hostdisconnect_w || rx_error_w)begin
                data_o_tmp = 'x;
                next_state_r = STATE_IDLE;
            end
            else begin
                active_read_tmp = token_in_q;

                // valid data
                if(dir_i) begin
                    if(nxt_i && token_in_q) begin
                        data_store_o_tmp = data_i;

                        if(data_i != DATA0_PID && data_i != DATA1_PID) begin
                            data_store_valid_tmp = 1'b1;
                        end
                    end
                end


                if(rx_error_w) next_state_r = STATE_IDLE;
                else if(data_i == ACK_PID) next_state_r = STATE_TX_TURNAROUND;
                else if(rx_resp_timeout_2) next_state_r = STATE_IDLE;
                // Receive complete
                else if (~rx_active_w && ~nxt_i)
                begin
                    // Send ACK but incoming data had CRC error, do not ACK
                    if (send_ack_q && crc_error_w)
                        next_state_r = STATE_IDLE;
                    // Send an ACK response if the recieved data is valid (data0 or data1)
                    else if (send_ack_q && (status_response_q == DATA0_PID || status_response_q == DATA1_PID))
                        next_state_r = STATE_TX_WAIT;
                    else 
                        next_state_r = STATE_TX_TURNAROUND;
                end
            end
        end

        //-----------------------------------------
        // STATE_TX_TURNAROUND
        // --------------------------------------------------
        STATE_TX_TURNAROUND :
        begin
            next_state_r = STATE_IDLE;
        end
        //-----------------------------------------
        // IDLE / RECEIVE BEGIN
        //-----------------------------------------
        STATE_IDLE :
        begin
           // Token transfer request
           if (start)
              next_state_r  = STATE_TX_TOKEN1;
        end
        STATE_RESET:
        begin
            if(!dir_i)
                next_state_r = STATE_INIT1;
        end
        STATE_INIT1:
        begin
            data_o_tmp = INIT1;
            if(nxt_i)
                next_state_r = STATE_INIT2;
        end
        STATE_INIT2:
        begin
            data_o_tmp = INIT2;
            if(nxt_i)
                next_state_r = STATE_INIT3;
        end
        STATE_INIT3:
        begin
            stp_o_tmp = 1'b1;
            next_state_r = STATE_IDLE;
        end
        default :
        begin
            // data_o_tmp = 8'b00000000;
            // token_sof_done = 1'b0;
            // token_setup_addr_done = 1'b0;
            // token_setup_cfg_done = 1'b0;
            // stp_o_tmp = 1'b0;
            // data_setup_addr_done = 1'b0;
            // data_setup_cfg_done  = 1'b0;
            // data_out_done        = 1'b0;
            // data_store_o_tmp = 8'b00000000;
            // data_store_valid_tmp = 1'b0;
            // host_disconnect_o_tmp = 1'b0;
            // // rx_active_w         = 1'b0;
            // // rx_error_w          = 1'b0;
            // // rx_hostdisconnect_w = 1'b0;
            // token_in_done = 1'b0;
            // token_out_done = 1'b0;
        end
    endcase
end

// Update state
always_ff @( posedge clk ) begin 
    if(rst) 
        state_q   <= STATE_RESET;
    else 
        state_q   <= next_state_r;
end

// // Update state
// always_ff @( posedge clk ) begin 
//     if(rst) 
//         state_q   <= STATE_IDLE;
//     else 
//         state_q   <= next_state_r;
// end



// determine if there is a turnaround
always_ff @( posedge clk ) begin 
    if(rst) dir_delay <= 1'b0;
    else dir_delay <= dir_i;
end
assign turnaround_w = dir_delay ^ dir_i;

// determine if there is a rx_cmd sent in
assign rx_cmd_fnd_w = dir_i && !nxt_i && !turnaround_w;
// record rx_cmd values
always_comb begin 
    // default
    rx_active_w         = 1'b0;
    rx_error_w          = 1'b0;
    rx_hostdisconnect_w = 1'b0;
    rx_linestate_w      = 2'b00;
    // only when rx_cmd is sent in
    if(rx_cmd_fnd_w) begin
        rx_active_w         = data_i[4];
        rx_error_w          = data_i[5];
        rx_hostdisconnect_w = (data_i[5:4] == 2'b10);
        rx_linestate_w      = data_i[1:0];
    end
end

// determine if there is a connected device
always_ff @( posedge clk ) begin 
    if(rst)                  rx_linestate_q <= LINESTATE_SE0;
    else if(rx_cmd_fnd_w)    rx_linestate_q <= rx_linestate_w;
    else                     rx_linestate_q <= rx_linestate_q;
end
always_ff @( posedge clk ) begin 
    if(rst) 
        connect_q <= 1'b0;
    else if(rx_hostdisconnect_w)
        connect_q <= 1'b0;
    else if(rx_cmd_fnd_w && (rx_linestate_q==LINESTATE_SE0) && (rx_linestate_w==LINESTATE_J))
        connect_q <= 1'b1;
    else 
        connect_q <= connect_q;
end

// determine if connection just happened (the moment it connected)
assign connect_w = (rx_cmd_fnd_w && (rx_linestate_q==LINESTATE_SE0) && (rx_linestate_w==LINESTATE_J));
assign connect_trigger      = (connect_w==1'b1 && connect_q==1'b0);

// set control signals for token packet
// sof counter: sof is sent by host every 1ms -> 60,000cycles
always_ff @( posedge clk ) begin 
    if(rst) begin
        sof_counter <= 16'h00;
        sof_pulse <= 1'b0;
    end
    else if(sof_counter == SOF_COUNT - 1) begin
        sof_counter <= 16'h00;
        sof_pulse <= 1'b1;
    end
    else begin
        sof_counter <= sof_counter + 1;
        sof_pulse <= 1'b0;
    end
end
// sof frame number
always_ff @( posedge clk ) begin 
    if(rst)             sof_frame_num <= '0;
    else if(token_sof_done) sof_frame_num <= sof_frame_num + 1;
    // else if(sof_pulse)  sof_frame_num <= sof_frame_num + 1;
    else                sof_frame_num <= sof_frame_num;
end

// TOKEN SOF
always_ff @( posedge clk ) begin 
    if(rst)
        token_sof_q <= 1'b0;
    else if(connect_trigger)
        token_sof_q <= 1'b1;
    else if(sof_pulse)
        token_sof_q <= 1'b1;
    else if(token_sof_done)
        token_sof_q <= 1'b0;
    else 
        token_sof_q <= token_sof_q;
end
// TOKEN SOF DELAY
always_ff @( posedge clk ) begin 
    if(rst) token_sof_q_delay <= '0;
    else    token_sof_q_delay <= token_sof_q;
end


// TOKEN SETUP ADDR
always_ff @( posedge clk ) begin 
    if(rst)
        token_setup_addr_q <= 1'b0;
    else if(connect_trigger)
        token_setup_addr_q <= 1'b1;
    else if(token_setup_addr_done)
        token_setup_addr_q <= 1'b0;
    else 
        token_setup_addr_q <= token_setup_addr_q;
end
// TOKEN SETUP ADDR DELAY
always_ff @( posedge clk ) begin 
    if(rst) token_setup_addr_q_delay <= '0;
    else    token_setup_addr_q_delay <= token_setup_addr_q;
end


// TOKEN SETUP CFG
always_ff @( posedge clk ) begin 
    if(rst) 
        token_setup_cfg_q <= 1'b0;
    else if(token_setup_addr_done)
        token_setup_cfg_q <= 1'b1;
    else if(token_setup_cfg_done)
        token_setup_cfg_q <= 1'b0;
    else 
        token_setup_cfg_q <= token_setup_cfg_q;
end
// TOKEN SOF DELAY
always_ff @( posedge clk ) begin 
    if(rst) token_setup_cfg_q_delay <= '0;
    else    token_setup_cfg_q_delay <= token_setup_cfg_q;
end


// TOKEN IN
// *stop when device disconnected
always_ff @( posedge clk ) begin 
    if(rst)
        token_in_q <= 1'b0;
    else if(token_sof_done)
        token_in_q <= 1'b1; 
    else if(rx_hostdisconnect_w)
        token_in_q <= 1'b0;
    else 
        token_in_q <= token_in_q;
end


// set control signals for data packet
// DATA SETUP ADDR
always_ff @( posedge clk ) begin 
    if(rst)
        data_setup_addr_q <= 1'b0;
    else if(token_setup_addr_done)
        data_setup_addr_q <= 1'b1;
    else if(data_setup_addr_done)
        data_setup_addr_q <= 1'b0;
    else 
        data_setup_addr_q <= data_setup_addr_q;
end

// DATA SETUP CFG
always_ff @( posedge clk ) begin 
    if(rst)
        data_setup_cfg_q <= 1'b0;
    else if(token_setup_cfg_done)
        data_setup_cfg_q <= 1'b1;       
    else if(data_setup_cfg_done)
        data_setup_cfg_q <= 1'b0;
    else 
        data_setup_cfg_q <= data_setup_cfg_q;
end


// alternate data0 and data1 for data packet PID
always_ff @( posedge clk ) begin 
    if(rst)                 data_pid <= 1'b0;
    else if(data_out_done)  data_pid <= ~data_pid;
    else                    data_pid <= data_pid;
end

// set transmit data byte count
always_ff @( posedge clk ) begin
    if(rst)                             
        data_byte_count_q <= 4'd0;
    else if(state_q == STATE_TX_PID)    
        data_byte_count_q <= 4'd8;
    else if(state_q == STATE_TX_DATA && nxt_i)
        data_byte_count_q <= data_byte_count_q - 1;
    else 
        data_byte_count_q <= data_byte_count_q;  
end

// assign send_ack_q
always_ff @( posedge clk ) begin 
    if(rst)                             send_ack_q <= '0;
    else if(state_q == STATE_RX_DATA && (data_i == DATA0_PID || data_i == DATA1_PID))   send_ack_q <= '1;
    else if(state_q == STATE_TX_ACKNAK) send_ack_q <= '0;
    else                                send_ack_q <= send_ack_q;  
end

// crc_error_w: crc16 check in rx_data
assign crc_error_w = 1'b0;

// status_response_q: read the recieved data PID
always_ff @( posedge clk ) begin 
    if(rst)     nxt_delay <= '0;
    else        nxt_delay <= nxt_i;
end

assign data_PID_flag = ((nxt_delay ^ nxt_i) && dir_i && !turnaround_w);

always_ff @( posedge clk ) begin 
    if(rst) 
        status_response_q <= '0;
    else if(data_PID_flag) 
        status_response_q <= data_i;
    else if((state_q == STATE_IDLE) || (state_q == STATE_TX_WAIT))
        status_response_q <= '0;
    else    
        status_response_q <= status_response_q;
end

// implement recieve timeout
always_ff @( posedge clk ) begin 
    if(rst) begin
        rx_dir_counter <= '0;
        rx_resp_timeout_1 <= 1'b0;
    end
    else if(rx_dir_counter == RX_TIMEOUT_DIR - 1) begin
        rx_dir_counter <= '0;
        rx_resp_timeout_1 <= 1'b1;
    end
    else if(state_q == STATE_RX_WAIT2) begin
        rx_dir_counter <= rx_dir_counter + 1;
        rx_resp_timeout_1 <= 1'b0;
    end
    else begin
        rx_dir_counter <= rx_dir_counter;
        rx_resp_timeout_1 <= 1'b0;
    end 
end
always_ff @( posedge clk ) begin 
    if(rst) begin
        rx_nxt_counter <= 16'h00;
        rx_resp_timeout_2 <= 1'b0;
    end
    else if(rx_nxt_counter == RX_TIMEOUT_NXT - 1) begin
        rx_nxt_counter <= 16'h00;
        rx_resp_timeout_2 <= 1'b1;
    end
    else if(state_q == STATE_RX_DATA) begin
        rx_nxt_counter <= rx_nxt_counter + 1;
        rx_resp_timeout_2 <= 1'b0;
    end
    else begin
        rx_nxt_counter <= rx_nxt_counter;
        rx_resp_timeout_2 <= 1'b0;
    end 
end

//implement transmit timeout
always_ff @( posedge clk ) begin 
    if(rst) begin
        tx_dir_counter <= '0;
        tx_resp_timeout <= 1'b0;
    end
    else if(tx_dir_counter == TX_TIMEOUT_DIR - 1) begin
        tx_dir_counter <= '0;
        tx_resp_timeout <= 1'b1;
    end
    else if(state_q == STATE_TX_WAIT) begin
        tx_dir_counter <= tx_dir_counter + 1;
        tx_resp_timeout <= 1'b0;
    end
    else begin
        tx_dir_counter <= tx_dir_counter;
        tx_resp_timeout <= 1'b0;
    end 
end

always_ff @( posedge clk ) begin
    if(rst) active_IN_q <= 1'b0;
    else if (active_IN_start) active_IN_q <= 1'b1;
    else if (active_IN_stop) active_IN_q <= 1'b0;
    else active_IN_q <= active_IN_q;
end

assign start = connect_q && (state_q==STATE_IDLE);

// output signals
assign data_o = data_o_tmp;
assign stp_o = stp_o_tmp;
assign data_store_valid = data_store_valid_tmp;
assign data_store_o = data_store_o_tmp;
// assign host_disconnect_o = rx_hostdisconnect_w;
assign host_connect_o = connect_q;
assign new_read = new_read_tmp && token_in_q;
assign active_read = active_read_tmp;
assign active_IN = active_IN_q;
endmodule