`timescale 1ns / 1ps

module i2c_main(
    input clk,
    input reset,

    inout io_SDA,
    
    input i_wr_en,
    input [7:0] i_wr_data,
    output logic o_wr_done,
    
    //
    input [4:0] i_addr,
    input i_Read_Clock,
    output logic last_bit,
    //
    
    input i_rd_en,
    output logic [7:0] o_rd_data,
    output logic o_rd_done,
    output logic o_rx_data_valid,

    output logic o_SCLK,
    output logic o_CE,
    output logic o_data_enable
);

    // === Внутренние сигналы ===
    logic r_wr_data;
    logic r_rd_data;
    logic r_buf_state;
    logic [7:0] r_buf_data;
    logic [3:0] bit_counter;   // Для отслеживания передачи 8 бит
    
    //
    logic r_read_write_flag;
    //

    // === IOBUF для управления SDA ===
    IOBUF iobuf_inst (
        .O(r_rd_data),  // Буферный выход
        .IO(io_SDA),    // Буферный ввод-вывод
        .I(r_wr_data),  // Буферный вход
        .T(r_buf_state) // Вход управления трехстабильным состоянием
    );
  
    
    typedef enum logic [3:0] {
        IDLE       = 4'b0001,
        RW_selec   = 4'b0010,
        TX_ADD     = 4'b0011,
        RC_selec   = 4'b0100,
        LAST_BIT   = 4'b0101,
        TX_DATA    = 4'b0111,
        RX_DATA    = 4'b1000,
        DONE       = 4'b1001
    } state_t;
    
    state_t state;

    // === Формирование стабильного SCLK ===
    logic [7:0] clk_div_counter;

    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            o_SCLK <= 0;
        end else if (o_CE) begin
            o_SCLK <= ~o_SCLK;
        end else begin
            o_SCLK <= 0; 
        end
    end

    // === Логика FSM ===
        always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Сброс всех сигналов
            state <= IDLE;
            o_wr_done <= 0;
            o_rd_done <= 0;
            o_rx_data_valid <= 0;
            o_data_enable <= 0;
            r_buf_state <= 1'b1; // Высокий импеданс
            r_buf_data <= 8'b0;
            bit_counter <= 0;
            o_CE <= 0;
            last_bit <= 0;
    
            // Явный сброс проблемных сигналов
            r_wr_data <= 1'b0;
            r_read_write_flag <= 1'b0;
            o_rd_data <= 8'b0;
    
        end else begin
            case (state)
                // === IDLE: ожидание команд ===
                IDLE: begin
                    o_CE <= 0;
                    last_bit <= 0;
                    o_wr_done <= 0;
                    o_rd_done <= 0;
                    o_rx_data_valid <= 0;
                    r_buf_state <= 1'b1; // Высокий импеданс
                    o_data_enable <= 0;
    
                    if (i_wr_en) begin
                        r_buf_data[7:3] <= i_addr;
                        r_buf_state <= 1'b0; // Управление линией SDA
                        o_CE <= 1;
                        state <= RW_selec;
                        r_wr_data <= 1'b0; // Устанавливаем для записи
                        r_read_write_flag <= 1'b0; // Пишем
                    end else if (i_rd_en) begin
                        r_buf_data[7:3] <= i_addr;
                        r_buf_state <= 1'b0; // Управление линией SDA
                        o_CE <= 1;
                        state <= RW_selec;
                        r_wr_data <= 1'b1; // Устанавливаем для чтения
                        r_read_write_flag <= 1'b1; // Читаем
                    end else begin
                        r_wr_data <= 1'b0; // Сброс при отсутствии команды
                    end
                end
    
                // Остальные состояния
                RW_selec: begin
                    if (o_SCLK) begin
                        state <= TX_ADD;
                        bit_counter <= 0;
                    end
                end
    
                TX_ADD: begin
                    r_wr_data <= r_buf_data[7]; // Передача старшего бита
                    if (o_SCLK) begin
                        bit_counter <= bit_counter + 1;
                        r_buf_data <= {r_buf_data[6:0], 1'b0}; // Сдвиг данных
//                        if (bit_counter == 3) begin
                        if (bit_counter == 4) begin
//                        if (bit_counter == 5) begin
                            bit_counter <= 0;
                            r_buf_data <= i_wr_data; // Готовим данные для передачи
                            state <= RC_selec;
                        end
                    end
                end
    
                RC_selec: begin
                    r_wr_data <= i_Read_Clock;
                    if (o_SCLK) begin
                        state <= LAST_BIT;
                    end
                end
    
                LAST_BIT: begin
                    r_wr_data <= 1'b1;
                    last_bit <= 1'b1;
                    if (o_SCLK) begin
                        if (r_read_write_flag) begin 
                            state <= RX_DATA;
                            r_buf_state <= 1'b1; // Переключаем SDA в режим входа
                            last_bit <= 1'b0;
                        end else begin 
                            state <= TX_DATA;
                            last_bit <= 1'b0;
                        end
                    end
                end
    
                TX_DATA: begin
                    r_wr_data <= r_buf_data[7]; // Передача старшего бита
                    if (o_SCLK) begin
                        bit_counter <= bit_counter + 1;
                        r_buf_data <= {r_buf_data[6:0], 1'b0}; // Сдвиг данных
                        if (bit_counter == 7) begin
                            state <= DONE;
                            bit_counter <= 0;
                            o_wr_done <= 1;
                        end
                    end
                end
    
                RX_DATA: begin
                    if (o_SCLK) begin
                        r_buf_data <= {r_buf_data[6:0], r_rd_data}; // Сдвиг входных данных
                        bit_counter <= bit_counter + 1;
                        if (bit_counter == 7) begin
                            o_rd_data <= r_buf_data;
                            o_rd_done <= 1;
                            state <= DONE;
                            bit_counter <= 0;
                            r_buf_state <= 1'b0; // Высокий импеданс
                        end
                    end
                end
    
                DONE: begin
                    if (o_SCLK) begin
                        state <= IDLE;
                        o_rx_data_valid <= 1'b0;
                        o_wr_done <= 0;
                        o_CE <= 0;
                        r_buf_state <= 1'b1; // Высокий импеданс
                        r_wr_data <= 1'b0; // Сброс значения
                    end
                end
            endcase
        end
    end

endmodule