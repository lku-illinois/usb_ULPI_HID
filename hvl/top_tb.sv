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
    bit usb_clk;
    initial begin
        #5ns;
        usb_clk = 1'b1;
        forever #8.33ns usb_clk = ~usb_clk;
    end
    // initial usb_clk = 1'b1;
    // always #8.33ns usb_clk = ~usb_clk;

    bit axi_clk;
    initial axi_clk = 1'b1;
    always #2.5ns axi_clk = ~axi_clk;
    
    logic           rst;
    logic   [7:0]   data_i;
    logic           dir_i;
    logic           nxt_i;
    logic   [7:0]   data_o;
    logic           stp_o;
    logic   [63:0]  usb_data_o;
    logic           usb_data_valid_o;


    usb_cdc dut(
        .*
    );

    task do_setup();
        rst <= 1'b1;
        // data_i <= 8'b0;
        // data_i <= 1'b0;
        dir_i <= 1'b0;
        nxt_i <= 1'b0;
        repeat(3) @(posedge usb_clk);
        rst <= 1'b0;
        @(posedge usb_clk);
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
        @(posedge usb_clk);// turn around cycle
        data_i <= DATA_J_LINE_STATE;
        @(posedge usb_clk);//line state J cycle
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
            @(posedge usb_clk); 
            nxt_i <= 1'b1;
            //todo assertion check TX_CMD
            //asserted(data_o == )
            @(posedge usb_clk);
            //todo assertion check ADDR + ENP
            //asserted(data_o == )
            @(posedge usb_clk);
            //todo assertion check ENP + CRC5
            //asserted(data_o == )
            $display("pass sof");
            forever begin
                @(posedge usb_clk);
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
        @(posedge usb_clk); 
        nxt_i <= 1'b1;
        //todo assertion check TX_CMD
        //asserted(data_o == )
        @(posedge usb_clk);
        //todo assertion check ADDR + ENP
        //asserted(data_o == )
        @(posedge usb_clk);
        //todo assertion check ENP + CRC5
        //asserted(data_o == )
        $display("pass address pid");
        forever begin
            @(posedge usb_clk);
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
        @(posedge usb_clk);
        nxt_i <= 1'b1;// receive TX CMD
        forever begin
            @(posedge usb_clk);
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
            @(posedge usb_clk); 
            nxt_i <= 1'b1;
            //todo assertion check TX_CMD
            //asserted(data_o == )
            @(posedge usb_clk);
            //todo assertion check ADDR + ENP
            //asserted(data_o == )
            @(posedge usb_clk);
            //todo assertion check ENP + CRC5
            //asserted(data_o == )
            $display("pass config pid");
            @(stp_o); 
            @(posedge usb_clk);   
            nxt_i <= 1'b0;
                    
                
        
        end
    endtask

    task device_setup_config_data();
        @(data_o == DATA_OUT_SETUP_ADDRESS); 
        nxt_i <= 1'b0; 
        @(posedge usb_clk);
        nxt_i <= 1'b1; 
        $display("pass config data");
        @(posedge usb_clk);
        nxt_i <= 1'b1;// receive TX CMD
        @(stp_o); 
        @(posedge usb_clk);   
        nxt_i <= 1'b0;;
        $display("pass config data1111");
    endtask

    task Device2Host_ACK();
        dir_i <= 1'b1;
        @(posedge usb_clk); //turn around
        nxt_i <= 1'b1;
        data_i <= DATA_OUT_SEND_ACK; //sending ACK PID
        @(posedge usb_clk);
        dir_i <= 1'b0;
        nxt_i <= 1'b0;
        data_i <= DATA_ALL_0;
        @(posedge usb_clk);
        
    endtask

    task Host2Device_ACK();
        dir_i <= 1'b0;
        //todo assertion;
        
        @(data_o == DATA_OUT_SEND_ACK) 
        @(posedge usb_clk);
        nxt_i <= 1'b1; 
        @(posedge usb_clk);
        nxt_i <= 1'b0;   
    endtask

    task Host2Device_INtoken();
        
        wait (data_o == DATA_OUT_IN_TOKEN);
        // if(data_o == DATA_OUT_IN_TOKEN) begin
            // $display("caonima");
            // @(posedge usb_clk);  
            // nxt_i <= 1'b1; 
            // @(stp_o == 1'b1);
            // @(posedge usb_clk);
            // nxt_i <= 1'b0; 
        // end 
        dir_i <= 1'b0;
        $display("caonima");
        @(posedge usb_clk);  
        nxt_i <= 1'b1; 
        @(stp_o == 1'b1);
        @(posedge usb_clk);
        nxt_i <= 1'b0; 
    endtask
    task Host2Device_INtoken_delay();
        dir_i <= 1'b0;
        @(posedge usb_clk);  
        nxt_i <= 1'b1; 
        @(stp_o == 1'b1);
        @(posedge usb_clk);
        nxt_i <= 1'b0; 
               
    endtask
    

    task Device2Host_intrrupt_send();
        nxt_i <= 1'b0;
        dir_i <= 1'b1;
        @(posedge usb_clk);

        data_i <= DATA_OUT_SETUP_DATA0; //PID0;
        nxt_i <= 1'b1;
        @(posedge usb_clk);

        data_i <= 8'h11;//make up transaction;
        @(posedge usb_clk);
        data_i <= 8'h12;//make up transaction;
        @(posedge usb_clk);
        data_i <= 8'h13;//make up transaction;
        @(posedge usb_clk);
        data_i <= 8'h14;//make up transaction;
        @(posedge usb_clk);
        data_i <= 8'h15;//make up transaction;
        @(posedge usb_clk);

        data_i <= 8'hff;//crc16;
        @(posedge usb_clk);
        data_i <= 8'hff;//crc16;
        @(posedge usb_clk);

        data_i <= DATA_OUT_SEND_ACK_RX_CMD; // rx_cmd
        nxt_i <= 1'b0;
        dir_i <= 1'b1;
        @(posedge usb_clk);// TURNAROUND

        nxt_i <= 1'b0;
        dir_i <= 1'b0;
        data_i <= DATA_ALL_0;
        @(posedge usb_clk);
    endtask

    task Device2Host_intrrupt_send_delay();
        nxt_i <= 1'b0;
        dir_i <= 1'b1;
        repeat(3) begin
            @(posedge usb_clk);
            data_i <= DATA_OUT_RX_CMD_FILLING;
            nxt_i <= 1'b0;
        end
        @(posedge usb_clk);
        data_i <= DATA_OUT_SETUP_DATA0; //PID0;
        nxt_i <= 1'b1;
        @(posedge usb_clk);

        data_i <= 8'h11;//make up transaction;
        @(posedge usb_clk);
        data_i <= 8'h12;//make up transaction;
        @(posedge usb_clk);
        data_i <= 8'h13;//make up transaction;
        @(posedge usb_clk);
        data_i <= 8'h14;//make up transaction;
        @(posedge usb_clk);
        data_i <= 8'h15;//make up transaction;
        @(posedge usb_clk);

        data_i <= 8'hff;//crc16;
        @(posedge usb_clk);
        data_i <= 8'hff;//crc16;
        @(posedge usb_clk);

        data_i <= DATA_OUT_SEND_ACK_RX_CMD;
        nxt_i <= 1'b0;
        dir_i <= 1'b1;
        @(posedge usb_clk);// TURNAROUND
        nxt_i <= 1'b0;
        dir_i <= 1'b0;
        data_i <= DATA_ALL_0;
        @(posedge usb_clk);
        $display("success!!!!!!");
    endtask



    task disconnect_device();
        // turnaround
        nxt_i <= 1'b0;
        dir_i <= 1'b1;
        @(posedge usb_clk);
        // rx_cmd
        data_i <= DATA_OUT_DISCONNECT;
        @(posedge usb_clk);
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



        

        fork
            begin
                while(1) begin
                    sof();
                end
            end
            begin
                #3ms;
                // IN
                Host2Device_INtoken();
                Device2Host_intrrupt_send();
                Host2Device_ACK();

                #4ms;
                // IN
                Host2Device_INtoken();
                Device2Host_intrrupt_send();
                Host2Device_ACK();
                
                #3ms;
                // IN DELAY
                Host2Device_INtoken();
                Device2Host_intrrupt_send_delay();
                Host2Device_ACK();

                #4ms;
                // IN DELAY
                Host2Device_INtoken();
                Device2Host_intrrupt_send_delay();
                Host2Device_ACK();

                repeat(10) @(posedge usb_clk);
                disconnect_device();

                repeat(10) @(posedge usb_clk);
                $display("ALL TEST PASSED");
                $finish;
            end
        join

        // // IN
        // Host2Device_INtoken();
        // Device2Host_intrrupt_send();
        // Host2Device_ACK();

        // #2000ns;

        // // IN DELAY
        // Host2Device_INtoken();
        // Device2Host_intrrupt_send_delay();
        // Host2Device_ACK();//checked!!!

        // //repeat(10) @(posedge usb_clk);
        
        // @(posedge usb_clk);
        // @(posedge usb_clk);
        // @(posedge usb_clk);
        // @(posedge usb_clk);
        // @(posedge usb_clk);
        // @(posedge usb_clk);

        // #2000ns;

        // // IN
        // $display("test!!!");
        // Host2Device_INtoken();
        // $display("test22222222!!!");
        // Device2Host_intrrupt_send();
        // Host2Device_ACK();

        // #2000ns;
        
        // // IN
        // $display("test!!!");
        // Host2Device_INtoken();
        // Device2Host_intrrupt_send();
        // Host2Device_ACK();

        // #2000ns;
        
        // // IN
        // $display("test!!!");
        // Host2Device_INtoken();
        // Device2Host_intrrupt_send();
        // Host2Device_ACK();

        // #2000ns;
        
        // // IN DELAY
        //  repeat(3) begin
        //     Host2Device_INtoken();
        //     repeat(10) @(posedge usb_clk);
        //     Device2Host_intrrupt_send_delay();
        //     Host2Device_ACK();
        //     #2000ns;
        // end

        // // sof
        // sof();

        // DISCONNECT
        // repeat(10) @(posedge usb_clk);
        // disconnect_device();

        // repeat(10) @(posedge usb_clk);
        // $display("ALL TEST PASSED");
        // $finish;
    end

    //----------------------------------------------------------------------
    // Timeout.
    //----------------------------------------------------------------------
    initial begin
        #5000000000ns;
        $fatal("Timeout!");
    end

endmodule