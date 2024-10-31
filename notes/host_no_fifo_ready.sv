module top_tb;

    timeunit 1ps;
    timeprecision 1ps;
    
    //----------------------------------------------------------------------
    // Waveforms.
    //----------------------------------------------------------------------
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end

    //----------------------------------------------------------------------
    // Generate the clock.
    //----------------------------------------------------------------------
    bit clk;
    initial clk = 1'b1;
    always #5ns clk = ~clk;
    
    logic           rst;
    logic   [7:0]   data_i;
    logic           dir_i;
    logic           nxt_i;
    logic   [7:0]   data_o;
    logic           stp_o;
    logic           data_store_valid;
    logic   [7:0]   data_store_o;
    logic           host_disconnect_o;



    usb_fsm dut(
        .*
    );

    task do_setup();
        rst <= 1'b1;
        // data_i <= 8'b0;
        // data_i <= 1'b0;
        dir_i <= 1'b0;
        nxt_i <= 1'b0;
        repeat(3) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);
    endtask;
    localparam DATA_J_LINE_STATE = 8'b00000001;
    localparam DATA_ALL_0 = 'x;
    localparam DATA_OUT_SETUP_ADDRESS = 8'b01001101; //ULPI must start at 0100 + PID
    localparam DATA_OUT_SETUP_DATA0 =8'B01000011;
    localparam DATA_OUT_SETUP_CONFIG = 8'b01001101;
    localparam DATA_OUT_SEND_ACK = 8'b01000010;
    localparam DATA_OUT_SEND_ACK_RX_CMD = 8'b00001001;//CHECK Linestate
    localparam DATA_OUT_IN_TOKEN = 8'h49;
    localparam DATA_OUT_DISCONNECT = 8'b00100000;// 5:4 10, Linestate 00
    localparam DATA_SOF = 8'b01000101;
    localparam DATA_OUT_RX_CMD_FILLING = 8'b00010000;
    task connect_device();//checked!
        dir_i <= 1'b1;
        // data_i <= 8'b0;
        nxt_i <= 1'b0;
        @(posedge clk);// turn around cycle
        data_i <= DATA_J_LINE_STATE;
        @(posedge clk);//line state J cycle
        dir_i <= 1'b0;
        data_i <= DATA_ALL_0;// dir_i = 0, nxt_i = 0; 
    endtask

    task sof();
        // forever begin //detected that setup TX CMD 
        //     if(data_o == DATA_SOF) begin
        //         break;
        //     end
        // end
        wait (data_o == DATA_SOF);
        if(data_o == DATA_SOF) begin
            // nxt_i <= 1'b0;
            @(posedge clk); 
            nxt_i <= 1'b1;
            //todo assertion check TX_CMD
            //asserted(data_o == )
            @(posedge clk);
            //todo assertion check ADDR + ENP
            //asserted(data_o == )
            @(posedge clk);
            //todo assertion check ENP + CRC5
            //asserted(data_o == )
            $display("pass sof");
            forever begin
                @(posedge clk);
                if(stp_o) begin
                    nxt_i <= 1'b0;
                    break;
                end
            end
        end
    endtask



    task device_setup_address_PID();
        // forever begin //detected that setup TX CMD 
        //     if(data_o == DATA_OUT_SETUP_ADDRESS) begin
        //         break;
        //     end
        // end
        wait(data_o == DATA_OUT_SETUP_ADDRESS);
        @(posedge clk); 
        nxt_i <= 1'b1;
        //todo assertion check TX_CMD
        //asserted(data_o == )
        @(posedge clk);
        //todo assertion check ADDR + ENP
        //asserted(data_o == )
        @(posedge clk);
        //todo assertion check ENP + CRC5
        //asserted(data_o == )
        $display("pass address pid");
        forever begin
            @(posedge clk);
            if(stp_o) begin
                nxt_i <= 1'b0;
                break;
            end
        end
    endtask

    task device_setup_address_data();
        // forever begin //detect TX_CMD
        //     if(data_o == DATA_OUT_SETUP_DATA0) begin
        //        nxt_i <= 1'b1; 
        //        break;
        //     end
        // end
        //todo
        wait(data_o == DATA_OUT_SETUP_DATA0);
        @(posedge clk);
        nxt_i <= 1'b1;// receive TX CMD
        forever begin
            @(posedge clk);
            if(stp_o) begin //8 byte data(setup config)
                nxt_i <= 1'b0;
                break;
            end
        end
    endtask

    task device_setup_config_PID();
        // forever begin
        //     if(data_o == DATA_OUT_SETUP_CONFIG) begin
        //         break;
        //     end
        // end
        
        @(data_o == DATA_OUT_SETUP_CONFIG);
        if(data_o == DATA_OUT_SETUP_CONFIG) begin
            $display("pass config pid1111");
            @(posedge clk); 
            nxt_i <= 1'b1;
            //todo assertion check TX_CMD
            //asserted(data_o == )
            @(posedge clk);
            //todo assertion check ADDR + ENP
            //asserted(data_o == )
            @(posedge clk);
            //todo assertion check ENP + CRC5
            //asserted(data_o == )
            $display("pass config pid");
            @(stp_o); 
            @(posedge clk);   
            nxt_i <= 1'b0;
                    
                
        
        end
    endtask

    task device_setup_config_data();
        @(data_o == DATA_OUT_SETUP_ADDRESS); 
        nxt_i <= 1'b0; 
        @(posedge clk);
        nxt_i <= 1'b1; 
        $display("pass config data");
        @(posedge clk);
        nxt_i <= 1'b1;// receive TX CMD
        @(stp_o); 
        @(posedge clk);   
        nxt_i <= 1'b0;;
        $display("pass config data1111");
    endtask

    task Device2Host_ACK();
        dir_i <= 1'b1;
        @(posedge clk); //turn around
        nxt_i <= 1'b1;
        data_i <= DATA_OUT_SEND_ACK; //sending ACK PID
        @(posedge clk);
        dir_i <= 1'b0;
        nxt_i <= 1'b0;
        data_i <= DATA_ALL_0;
        @(posedge clk);
        
    endtask

    task Host2Device_ACK();
        dir_i <= 1'b0;
        //todo assertion;
        
        @(data_o == DATA_OUT_SEND_ACK) 
        @(posedge clk);
        nxt_i <= 1'b1; 
        @(posedge clk);
        nxt_i <= 1'b0;   
    endtask

    task Host2Device_INtoken();
        
        wait (data_o == DATA_OUT_IN_TOKEN);
        // if(data_o == DATA_OUT_IN_TOKEN) begin
            // $display("caonima");
            // @(posedge clk);  
            // nxt_i <= 1'b1; 
            // @(stp_o == 1'b1);
            // @(posedge clk);
            // nxt_i <= 1'b0; 
        // end 
        dir_i <= 1'b0;
        $display("caonima");
        @(posedge clk);  
        nxt_i <= 1'b1; 
        @(stp_o == 1'b1);
        @(posedge clk);
        nxt_i <= 1'b0; 
    endtask
    task Host2Device_INtoken_delay();
        dir_i <= 1'b0;
        @(posedge clk);  
        nxt_i <= 1'b1; 
        @(stp_o == 1'b1);
        @(posedge clk);
        nxt_i <= 1'b0; 
               
    endtask
    

    task Device2Host_intrrupt_send();
        nxt_i <= 1'b0;
        dir_i <= 1'b1;
        @(posedge clk);

        data_i <= DATA_OUT_SETUP_DATA0; //PID0;
        nxt_i <= 1'b1;
        @(posedge clk);

        data_i <= 8'h11;//make up transaction;
        @(posedge clk);
        data_i <= 8'h12;//make up transaction;
        @(posedge clk);
        data_i <= 8'h13;//make up transaction;
        @(posedge clk);
        data_i <= 8'h14;//make up transaction;
        @(posedge clk);
        data_i <= 8'h15;//make up transaction;
        @(posedge clk);

        data_i <= 8'hff;//crc16;
        @(posedge clk);
        data_i <= 8'hff;//crc16;
        @(posedge clk);

        data_i <= DATA_OUT_SEND_ACK_RX_CMD; // rx_cmd
        nxt_i <= 1'b0;
        dir_i <= 1'b1;
        @(posedge clk);// TURNAROUND

        nxt_i <= 1'b0;
        dir_i <= 1'b0;
        data_i <= DATA_ALL_0;
        @(posedge clk);
    endtask

    task Device2Host_intrrupt_send_delay();
        nxt_i <= 1'b0;
        dir_i <= 1'b1;
        repeat(3) begin
            @(posedge clk);
            data_i <= DATA_OUT_RX_CMD_FILLING;
            nxt_i <= 1'b0;
        end
        @(posedge clk);
        data_i <= DATA_OUT_SETUP_DATA0; //PID0;
        nxt_i <= 1'b1;
        @(posedge clk);

        data_i <= 8'h11;//make up transaction;
        @(posedge clk);
        data_i <= 8'h12;//make up transaction;
        @(posedge clk);
        data_i <= 8'h13;//make up transaction;
        @(posedge clk);
        data_i <= 8'h14;//make up transaction;
        @(posedge clk);
        data_i <= 8'h15;//make up transaction;
        @(posedge clk);

        data_i <= 8'hff;//crc16;
        @(posedge clk);
        data_i <= 8'hff;//crc16;
        @(posedge clk);

        data_i <= DATA_OUT_SEND_ACK_RX_CMD;
        nxt_i <= 1'b0;
        dir_i <= 1'b1;
        @(posedge clk);// TURNAROUND
        nxt_i <= 1'b0;
        dir_i <= 1'b0;
        data_i <= DATA_ALL_0;
        @(posedge clk);
        $display("success!!!!!!");
    endtask



    task disconnect_device();
        // turnaround
        nxt_i <= 1'b0;
        dir_i <= 1'b1;
        @(posedge clk);
        // rx_cmd
        data_i <= DATA_OUT_DISCONNECT;
        @(posedge clk);
        //turnaround
        nxt_i <= 1'b0;
        dir_i <= 1'b0;
        data_i <= DATA_ALL_0;
    endtask

    initial begin
        $display("begin!!!!!!!");
        do_setup();

        // CONNECT DEVICE
        connect_device();

        // SETUP ADDR
        device_setup_address_PID();
        device_setup_address_data();
        Device2Host_ACK();

        // SETUP CONFIG
        device_setup_config_PID();
        device_setup_config_data();
        Device2Host_ACK();

        // SOF
        sof();

        // IN
        Host2Device_INtoken();
        Device2Host_intrrupt_send();
        Host2Device_ACK();

        // IN DELAY
        Host2Device_INtoken();
        Device2Host_intrrupt_send_delay();
        Host2Device_ACK();//checked!!!

        //repeat(10) @(posedge clk);
        
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        // IN
        $display("test!!!");
        Host2Device_INtoken();
        $display("test22222222!!!");
        Device2Host_intrrupt_send();
        Host2Device_ACK();
        
        // IN
        $display("test!!!");
        Host2Device_INtoken();
        Device2Host_intrrupt_send();
        Host2Device_ACK();
        
        // IN
        $display("test!!!");
        Host2Device_INtoken();
        Device2Host_intrrupt_send();
        Host2Device_ACK();
        
        // IN DELAY
         repeat(3) begin
            Host2Device_INtoken();
            repeat(10) @(posedge clk);
            Device2Host_intrrupt_send_delay();
            Host2Device_ACK();
        end

        // sof
        sof();

        // DISCONNECT
        repeat(10) @(posedge clk);
        disconnect_device();

        repeat(10) @(posedge clk);
        $display("ALL TEST PASSED");
        $finish;
    end




    // //----------------------------------------------------------------------
    // // Fancy_style
    // //----------------------------------------------------------------------
    
    // reg     [7:0]       data_reg_i      [1023:0];
    // reg     [127:0]     dir_reg_i;
    // reg     [127:0]     nxt_i;

    // reg     [7:0]       data_reg_o      [1023:0];
    // reg     [127:0]     stp_o;
    
   
    // int in_index = 0;
    // int out_index = 0;
    
    // function logic  [7:0] return_data_out();
    //     //todo;
    // endfunction
    
    // function logic  return_stp_out();
    //     //todo
    // endfunction


    // initial begin
    //     $display("start");
    //     do_setup();
    //     repeat(3) @(posedge clk);
    //     //recording the data;
    //     fork
    //         begin
    //             // control the stp_o;
    //             forever begin
    //                 @(posedge stp_o) dir_i <= ~dir_i; 
    //                 //every time it detect posedge, it will change the direction. 
    //             end
    //         end
    //         begin
    //             forever begin
    //                 @(posedge clk);
    //                 if(dir_i) begin //transmit from PHY to USB
    //                     data_reg_o[i]  <= return_data_out();    //todo
    //                     stp_o[i]  <= return_stp_out();            //todo
    //                     data_o <= return_data_out();
    //                     stp_o <= return_stp_out();
                        
    //                 end else begin

    //                 end 
    //             end
    //         end
    //     join
    //     repeat(1000) @(posedge clk);
    //     $finish;
    // end

    //----------------------------------------------------------------------
    // Timeout.
    //----------------------------------------------------------------------
    initial begin
        #5000000000ns;
        $fatal("Timeout!");
    end

endmodule