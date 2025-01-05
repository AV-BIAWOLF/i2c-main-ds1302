`timescale 1ns / 1ps


module tb_i2c_main;

    `include "params.vh"

    // === Parameters ===
//    parameter CLK_PERIOD = 10; 

    // === Signals ===
    logic clk;
    logic reset;

    tri io_SDA; // SDA line (inout)

    logic i_wr_en;
    logic [4:0] i_addr; // 5-bit address
    logic [7:0] i_wr_data;
    logic o_wr_done;

    logic i_rd_en;
    logic [7:0] o_rd_data;
    logic o_rd_done;

    logic o_SCLK;
    logic o_CE;
    logic o_rx_data_valid;
    
    logic i_Read_Clock;
    logic last_bit;

    // === Global variables to check ===
    logic [15:0] shift_reg_tx; // Shift register for data verification
    logic [4:0] count_tx;     // Transmitted bit counter

    i2c_main dut (
        .clk(clk),
        .reset(reset),
        .io_SDA(io_SDA),
        .i_wr_en(i_wr_en),
        .i_addr(i_addr),
        .i_wr_data(i_wr_data),
        .o_wr_done(o_wr_done),
        .i_rd_en(i_rd_en),
        .o_rd_data(o_rd_data),
        .o_rd_done(o_rd_done),
        .o_rx_data_valid(o_rx_data_valid),
        .o_SCLK(o_SCLK),
        .o_CE(o_CE),
        .i_Read_Clock(i_Read_Clock),
        .last_bit(last_bit)
    );

    logic slave_sda_out;
    assign io_SDA = o_rx_data_valid ? slave_sda_out : 1'bz;

    logic [7:0] slave_memory [0:31]; 
    logic [7:0] slave_data_out;      

    // === Clock signal generation ===
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // === Test tasks ===
    task automatic write_to_slave(input [4:0] addr, input [7:0] data);
        begin
        
            count_tx = 0;
            
            i_wr_en = 1;
            i_Read_Clock = $urandom % 2; 
            i_addr = addr;
            i_wr_data = data;
            $display("Write to Slave: Address = %h = %b, Data = %h = %b \n", addr, addr, data, data);
    
            @(posedge clk); 
            i_wr_en = 0;

            fork
                begin
                    Check_TX(addr, data, i_Read_Clock); 
                end
                begin
                    wait(o_wr_done); 
                end
            join
            @(posedge clk);
            @(posedge clk);
            $display("END");
        end
    endtask

    task automatic Check_TX(input [4:0] expected_addr, input [7:0] expected_data, Read_Clock);
        begin
        
            $display("START CHECKING");

            // Wait for o_CE to activate before starting data capture
            wait(o_CE);

            while (count_tx < 16) begin
                @(negedge o_SCLK); // Capture SCLK leading edge data only when o_CE is active
                if (o_CE) begin
                    shift_reg_tx = {shift_reg_tx[14:0], io_SDA}; 
                    count_tx = count_tx + 1'b1;
                    $display("Captured Bit %0d: SDA = %b", count_tx, io_SDA);
                end
            end

            $display("\nFinal shift_reg_tx = %h = %b", shift_reg_tx, shift_reg_tx);
            $display("1st 8 bits = %h = %b", shift_reg_tx[15:8], shift_reg_tx[15:8]);
            $display("R/W = %b, addr = %h = %b, R/C = %b, Last bit = %b \n", shift_reg_tx[15], shift_reg_tx[14:10], shift_reg_tx[14:10], shift_reg_tx[9], shift_reg_tx[8]);
            $display("Data = %h = %b", shift_reg_tx[7:0], shift_reg_tx[7:0]);
            
            assert(shift_reg_tx[15] == 1'b0) else $fatal("Error: R/W bit mismatch!"); 
            assert(shift_reg_tx[14:10] == expected_addr) else $fatal("Error: Address mismatch!"); 
            assert(shift_reg_tx[9] == Read_Clock) else $fatal("Error: R/C mismatch!");
            assert(shift_reg_tx[8] == 1'b1) else $fatal("Error: Last bit mismatch!");
            assert(shift_reg_tx[7:0] == expected_data) else $fatal("Error: Data mismatch!");
            
            count_tx = 0;
            repeat(4) @(posedge clk);
        end
    endtask

    logic [7:0] read_data;
    logic [4:0] count_rx;
    logic [7:0] shift_reg_rx; 
    logic [7:0] slave_tx_reg; // Shift register for data transfer
    logic [3:0] bit_counter_tx; // Transmit bit counter
    
    // === Reading test === 
    task reading_master(input [4:0] addr, input [7:0] data);
        begin
            count_rx = 1'b0;
            bit_counter_tx = 4'b0;
            shift_reg_rx = 8'b0; // Resetting the reception register
            slave_tx_reg = data; // Initializing the transfer register
    
            i_rd_en = 1'b1; 
            i_Read_Clock = $urandom % 2; 
            i_addr = addr;
            $display("Reading master (expected): Address = %h = %b, Data = %h = %b \n", addr, addr, data, data);
            
            @(posedge clk);
            i_rd_en = 1'b0;
            
            // Verification of address acceptance by master
            Check_RX_addr(addr, i_Read_Clock);
    
    
            if (last_bit) begin
                $display("Last bit in reading_master");
            end
    
            // Data transfer to the io_SDA signal
            Transmit_data_to_master(data);
            
            // Waiting for the master to finish reading
            wait(o_rd_done);
            
            // Checking the value accepted by the wizard
            Check_received_data(data);
            
            @(posedge clk);
            @(posedge clk);
            $display("END");
        end
    endtask 
    
    task automatic Check_RX_addr(input [4:0] expected_addr, input Read_Clock);
        begin
            $display("START CHECKING RX");
            $display("Address");
    
            // Wait for o_CE to activate before starting data capture
            wait(o_CE);
    
            while (count_rx < 8) begin
                @(negedge o_SCLK); // Capture SCLK leading edge data
                if (o_CE) begin
                    shift_reg_rx = {shift_reg_rx[6:0], io_SDA}; // Shifting data
                    count_rx = count_rx + 1'b1;
                    $display("Captured Bit %0d: SDA = %b", count_rx, io_SDA);
                end
            end
    
            $display("\nAddress shift_reg_rx = %h = %b", shift_reg_rx, shift_reg_rx);
            $display("R/W = %b, addr = %h = %b, R/C = %b, Last bit = %b \n", shift_reg_rx[7], shift_reg_rx[6:2], shift_reg_rx[6:2], shift_reg_rx[1], shift_reg_rx[0]);
            
            assert(shift_reg_rx[7] == 1'b1) else $fatal("Error: R/W bit mismatch!"); 
            assert(shift_reg_rx[6:2] == expected_addr) else $fatal("Error: Address mismatch!");
            assert(shift_reg_rx[1] == Read_Clock) else $fatal("Error: R/C mismatch!");
            assert(shift_reg_rx[0] == 1'b1) else $fatal("Error: Last bit mismatch!");
            
            count_rx = 0;
            
            $display("Last bit");
        end
    endtask
    
    task automatic Transmit_data_to_master(input [7:0] data);
        begin
            $display("START TRANSMITTING DATA TO MASTER");
            bit_counter_tx = 0;
            slave_tx_reg = data; // Initializing the transfer register
    
            // Set the first bit before the cycle starts
            slave_sda_out = slave_tx_reg[7]; // Set the high bit on the SDA line
            $display("Initial bit: SDA = %b, slave_tx_reg = %b", slave_sda_out, slave_tx_reg);
    
            while (bit_counter_tx < 7) begin
                @(negedge o_SCLK); // Waiting for the back front
                slave_tx_reg = {slave_tx_reg[6:0], 1'b0}; // Data Shift
                bit_counter_tx = bit_counter_tx + 1'b1;
    
                @(posedge o_SCLK); // Waiting for the front
                slave_sda_out = slave_tx_reg[7]; // Set the next bit on the SDA line
                $display("At SCLK posedge: SCLK = %b, SDA = %b, slave_sda_out = %b, slave_tx_reg = %b", 
                          o_SCLK, io_SDA, slave_sda_out, slave_tx_reg);
            end
    
            @(o_SCLK);
    
            $display("Data transmitted: %h = %b", data, data);
            slave_sda_out = 1'bz; // Releasing the SDA line after the transfer is completed
            bit_counter_tx = 0;
        end
    endtask
    
    
    task automatic Check_received_data(input [7:0] expected_data);
        begin
            $display("START CHECKING RECEIVED DATA");
    
            $display("Received Data = %h = %b", o_rd_data, o_rd_data);
            assert(o_rd_data == expected_data) else $fatal("Error: Data mismatch!");
            
            $display("RECEIVED DATA CHECK PASSED!");
        end
    endtask
    
    
    ///////////
     // === Monitor Signal ===
    initial begin
        $monitor("Time: %0t, last_bit = %b", $time, last_bit);
    end
    /////////////
    
    initial begin
        reset = 1;
        i_wr_en = 0;
        i_rd_en = 0;
        count_tx = 0; 
        repeat (10) @(posedge clk);
        reset = 0;

        // === Writing test ===
        for (int i = 0; i < WRITE_TEST_COUNT; i++) begin
            logic [4:0] addr = $urandom % 32; 
            logic [7:0] data = $urandom % 256; 
            write_to_slave(addr, data);
            repeat(10) @(posedge clk);
            $display("Write Test %0d passed! Addr = %h, Data = %h", i + 1, addr, data);
        end
    
        // === Reading test ===
        for (int j = 0; j < READ_TEST_COUNT; j++) begin
            logic [4:0] addr = $urandom % 32; 
            logic [7:0] data = $urandom % 256; 
            reading_master(addr, data);
            repeat(10) @(posedge clk);
            $display("Read Test %0d passed! Addr = %h, Data = %h", j + 1, addr, data);
        end

        $display("All tests passed!");
        $stop;
    end

endmodule
