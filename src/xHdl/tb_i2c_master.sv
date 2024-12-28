`timescale 1ns / 1ps

module tb_i2c_main;

    // === ��������� ===
    parameter CLK_PERIOD = 10; // ������ ��������� ������� (100 ���)

    // === ������� ===
    logic clk;
    logic reset;

    tri io_SDA; // ����� SDA (inout)

    logic i_wr_en;
    logic [4:0] i_addr; // 5-������ �����
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

    // === ���������� ���������� ��� �������� ===
    logic [15:0] shift_reg_tx; // ��������� ������� ��� �������� ������
    logic [4:0] count_tx;     // ������� ���������� �����

    // === ��������� DUT ===
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

    // === ������ �������� ���������� I2C ===
    logic slave_sda_out;
    assign io_SDA = o_rx_data_valid ? slave_sda_out : 1'bz;

    logic [7:0] slave_memory [0:31]; // ������ �� 32 �������� �� 8 ��� (� ������ 5-������� ������)
    logic [7:0] slave_data_out;      

    // === ��������� ��������� ������� ===
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // === �������� ������ ===
    task automatic write_to_slave(input [4:0] addr, input [7:0] data);
        begin
        
            count_tx = 0; // ������������� ��������
            
            i_wr_en = 1;
//            i_Read_Clock = 1'b0; 
            i_Read_Clock = $urandom % 2; 
            i_addr = addr;
            i_wr_data = data;
            $display("Write to Slave: Address = %h = %b, Data = %h = %b \n", addr, addr, data, data);
    
            @(posedge clk); // ���� ���� ��� ������ �������� ������
            i_wr_en = 0;

            fork
                begin
                    Check_TX(addr, data, i_Read_Clock); // �������� �������� ������
                end
                begin
                    wait(o_wr_done); // ���� ���������� �������� ������
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

            // ���� ��������� o_CE ����� ������� ������� ������
            wait(o_CE);

            while (count_tx < 16) begin
//                @(posedge o_SCLK); // ����������� ������ �� ��������� ������ SCLK ������ ��� �������� o_CE
                @(negedge o_SCLK); // ����������� ������ �� ��������� ������ SCLK ������ ��� �������� o_CE
                if (o_CE) begin
                    shift_reg_tx = {shift_reg_tx[14:0], io_SDA}; // �������� ������
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

    // === �������� �������� ��������� ===
    initial begin
        // === ������������� ===
        reset = 1;
        i_wr_en = 0;
        i_rd_en = 0;
        count_tx = 0; // ����� ��������
//        shift_reg_tx = 0; // ������� ��������
        repeat (10) @(posedge clk);
        reset = 0;

        // === ���� ������ ===
//        write_to_slave(5'b01010, 8'h15);
        write_to_slave(5'b11111, 8'h15);
        repeat(10) @(posedge clk);
        $display("Test 1 passed!");
        write_to_slave(5'b11011, 8'h22);

        $display("All tests passed!");
        $stop;
    end

endmodule
