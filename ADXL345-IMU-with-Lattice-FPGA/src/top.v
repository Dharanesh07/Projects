module top (
    input        clk,
    output [7:0] led,
    input        spi_miso,
    output       spi_mosi,
    output       spi_clk,
    output       spi_cs,
    output       uart_tx
);

  // SPI configuration
  parameter SPI_MODE = 3;
  parameter CLKS_PER_HALF_BIT = 3;  //12000000/(3x2) = 2MHz
  parameter RESET_CYCLES = 10000;  // Longer reset time
  parameter WAIT_CYCLES = 120000;  // Wait between reads

  // UART configuration
  parameter CLK_FREQ = 12_000_000;
  parameter BAUD_RATE = 19200;
  parameter CLKS_PER_BIT = 625;
  parameter UART_WAIT_CYCLES = 1200000;

  // FIFO parameters
  parameter WIDTH = 8;
  parameter FULL_WIDTH = 16;
  parameter DEPTH = 2048;

  // State definitions
  localparam RESET = 4'b0000;
  localparam SETUP_DEVID_RD = 4'b0001;
  localparam STOP_DEVID_RD = 4'b0010;
  localparam SETUP_PWR_CTRL_WR = 4'b0011;
  localparam STOP_PWR_CTRL_WR = 4'b0100;
  localparam SETUP_DATA_FORMAT_WR = 4'b0101;
  localparam STOP_DATA_FORMAT_WR = 4'b0110;
  localparam WAIT_AFTER_CONFIG = 4'b0111;  // Wait after configuration
  localparam SETUP_DATAX0_RD = 4'b1000;  // Read X-axis data instead
  localparam STOP_DATAX0_RD = 4'b1001;
  localparam WAIT_DELAY = 4'b1010;

  // ADXL345 Register Addresses
  parameter DEVID_ADDR = 6'h00;
  parameter PWR_CTL_ADDR = 6'h2D;
  parameter DATA_FORMAT_ADDR = 6'h31;
  parameter DATAX0_ADDR = 6'h32;  // X-axis data (2 bytes)
  parameter DATAY0_ADDR = 6'h34;  // Y-axis data (2 bytes)
  parameter DATAZ0_ADDR = 6'h36;  // Z-axis data (2 bytes)

  // ADXL345 Register Values
  // Defualts to 100Hz rate due to the default rate bits value at 0x0A
  parameter DATA_FORMAT_VAL = 8'h09;  // full resolution & +/- 4g
  parameter PWR_CTL_VAL = 8'h08;  // Measurement mode

  // State machine control
  reg [3:0] r_state;

  // SPI signals
  reg r_rstn;
  integer reset_counter = 0;
  integer wait_counter = 0;
  reg o_spi_rw_n;
  reg multibyte_rd;
  reg [5:0] o_spi_addr;
  reg o_spi_start;
  wire i_spi_ready;
  wire o_spi_dataval;
  reg [7:0] r_spi_tx_byte;
  wire [7:0] w_spi_rx_byte;
  reg [7:0] config_wait_counter;

  // UART signals
  reg o_uart_send;
  wire i_uart_txed;
  wire i_uart_active;
  wire uart_tx_done;
  reg [7:0] uart_txbyte;
  integer uart_wait_counter = 0;

  // FIFO signals
  reg [WIDTH-1:0] fifo_data_in;
  wire [WIDTH-1:0] fifo_data_out;
  wire fifo_full;
  wire fifo_empty;
  reg fifo_write_en;
  reg fifo_read_en;
  wire fifo_overflow;
  wire fifo_underflow;

  // Debug FIFO signals
  reg [WIDTH-1:0] dbg_fifo_data_in;
  wire [WIDTH-1:0] dbg_fifo_data_out;
  wire dbg_fifo_full;
  wire dbg_fifo_empty;
  reg dbg_fifo_wr_en;
  reg dbg_fifo_rd_en;
  wire dbg_fifo_overflow;
  wire dbg_fifo_underflow;



  // FIFO write state machine
  reg [2:0] wr_state;
  localparam WR_IDLE = 3'b000;
  localparam WR_STORE_BYTE = 3'b001;
  localparam WR_WAIT_NEXT = 3'b010;
  localparam WR_STORE_SYNC = 3'b011;
  localparam WR_STORE_FIRST = 3'b100;
  // UART transmit state machine
  reg [2:0] uart_state;
  localparam UART_IDLE = 3'b000;
  localparam UART_READ_FIFO = 3'b001;
  localparam UART_WAIT_READ = 3'b010;
  localparam UART_TRANSMIT = 3'b011;
  localparam UART_WAIT_TX = 3'b100;


  // Read fifo states 
  reg [3:0] read_fifo_state;
  localparam RD_FIFO_IDLE = 4'b0000;
  localparam RD_FIFO_WAIT = 4'b0001;
  localparam RD_FIFO_DATA = 4'b0010;


  parameter ASCII_f = 8'h66;
  parameter ASCII_b = 8'h62;
  parameter ASCII_r = 8'h72;
  parameter ASCII_l = 8'h6C;
  parameter ASCII_n = 8'h6E;
  parameter DEFAULT_ASCII = 8'h3B;
  // SPI Module instantiation
  spi_module #(
      .SPI_MODE(SPI_MODE),
      .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
  ) inst_spi_module (
      .i_clk             (clk),
      .i_spi_rst_n       (r_rstn),
      .i_spi_multibyte_rd(multibyte_rd),
      .o_spi_ready       (i_spi_ready),
      .i_spi_start       (o_spi_start),
      .i_spi_rw_n        (o_spi_rw_n),
      .i_spi_addr        (o_spi_addr),
      .i_spi_datain      (r_spi_tx_byte),
      .o_dataval         (o_spi_dataval),
      .o_spi_dataout     (w_spi_rx_byte),
      .spi_miso          (spi_miso),
      .spi_mosi          (spi_mosi),
      .spi_clk           (spi_clk),
      .spi_cs            (spi_cs)
  );

  // UART TX Module instantiation
  uart_tx #(
      .CLKS_PER_BIT(CLKS_PER_BIT)
  ) uart_tx_inst (
      .i_clk       (clk),
      .i_rstn      (r_rstn),
      .i_txbyte    (uart_txbyte),
      .i_txsenddata(o_uart_send),
      .o_txdone    (i_uart_txed),
      .o_uarttx    (uart_tx),
      .o_txactive  (i_uart_active)
  );
  // FIFO instantiation
  fifo #(
      .WIDTH(WIDTH),
      .DEPTH(DEPTH)
  ) tx_buf (
      .i_clk    (clk),
      .i_rst    (r_rstn),
      .i_wren   (fifo_write_en),
      .i_rden   (fifo_read_en),
      .i_datain (fifo_data_in),
      .o_dataout(fifo_data_out),
      .full     (fifo_full),
      .empty    (fifo_empty),
      .overflow (fifo_overflow),
      .underflow(fifo_underflow)
  );


  reg axis_dataval;
  wire signed [FULL_WIDTH-1:0] x_axis_filt_datain;
  wire signed [FULL_WIDTH-1:0] x_axis_filt_dataout;
  wire x_filt_comp;

  moving_average_4sample #(
      .DATA_WIDTH(FULL_WIDTH)
  ) x_axis_filt (
      .clk                (clk),
      .i_rstn             (r_rstn),
      .i_dataval          (axis_dataval),
      .data_in            (x_axis_filt_datain),
      .data_out           (x_axis_filt_dataout),
      .filtering_completed(x_filt_comp)
  );

  wire signed [FULL_WIDTH-1:0] y_axis_filt_datain;
  wire signed [FULL_WIDTH-1:0] y_axis_filt_dataout;
  wire y_filt_comp;

  moving_average_4sample #(
      .DATA_WIDTH(FULL_WIDTH)
  ) y_axis_filt (
      .clk                (clk),
      .i_rstn             (r_rstn),
      .i_dataval          (axis_dataval),
      .data_in            (y_axis_filt_datain),
      .data_out           (y_axis_filt_dataout),
      .filtering_completed(y_filt_comp)
  );

  wire signed [FULL_WIDTH-1:0] z_axis_filt_datain;
  wire signed [FULL_WIDTH-1:0] z_axis_filt_dataout;
  wire z_filt_comp;

  moving_average_4sample #(
      .DATA_WIDTH(FULL_WIDTH)
  ) z_axis_filt (
      .clk                (clk),
      .i_rstn             (r_rstn),
      .i_dataval          (axis_dataval),
      .data_in            (z_axis_filt_datain),
      .data_out           (z_axis_filt_dataout),
      .filtering_completed(z_filt_comp)

  );

  wire [7:0] gesture;
  gesture_recognition #(
      .WIDTH(FULL_WIDTH)
  ) inst_gesture_recognition (
      .clk(clk),
      .r_rstn(r_rstn),
      .x_axis_datain(x_axis_filt_datain),
      .y_axis_datain(y_axis_filt_datain),
      .z_axis_datain(z_axis_filt_datain),
      .gesture_data(gesture)
  );

  // LED assignments to show direction (optional)
  assign led[0] = (gesture == ASCII_f) ? 1'b1 : 1'b0;  // forward 
  assign led[1] = (gesture == ASCII_r) ? 1'b1 : 1'b0;  // right 
  assign led[2] = (gesture == ASCII_l) ? 1'b1 : 1'b0;  // left 
  assign led[3] = (gesture == ASCII_b) ? 1'b1 : 1'b0;  // back 
  assign led[4] = (gesture == ASCII_n) ? 1'b1 : 1'b0;  // nitro 
  assign led[5] = w_spi_rx_byte[4];
  assign led[6] = fifo_data_out[4];  // Negative Z
  assign led[7] = r_rstn;  // Negative Z

  //assign led = gesture;
  always @(posedge clk) begin
    if (!r_rstn) begin
      o_uart_send <= 1'b0;
      uart_txbyte <= 8'b0;
      uart_state  <= UART_IDLE;
    end else begin
      case (uart_state)
        UART_IDLE: begin
          o_uart_send <= 1'b0;
          if (gesture != 8'h3B) begin
            uart_txbyte <= gesture;
            uart_state  <= UART_TRANSMIT;
          end else uart_state <= UART_IDLE;
        end

        UART_TRANSMIT: begin
          if (!i_uart_active) begin
            o_uart_send <= 1'b1;
            uart_state  <= UART_WAIT_TX;
          end else uart_state <= UART_TRANSMIT;
        end

        UART_WAIT_TX: begin
          o_uart_send <= 1'b0;

          if (uart_wait_counter >= UART_WAIT_CYCLES) begin
            if (i_uart_txed) begin
              uart_state <= UART_IDLE;
            end
            uart_wait_counter <= 0;
          end else begin
            uart_wait_counter <= uart_wait_counter + 1;
          end
        end

        default: uart_state <= UART_IDLE;
      endcase
    end
  end
  // FIFO Write Process - Store SPI data into FIFO
  always @(posedge clk) begin
    if (!r_rstn) begin
      fifo_write_en <= 1'b0;
      fifo_data_in <= 8'b0;
      wr_state <= WR_IDLE;
    end else begin
      case (wr_state)
        WR_IDLE: begin
          fifo_write_en <= 1'b0;
          if (o_spi_dataval) begin
            fifo_data_in <= w_spi_rx_byte;
            if (!fifo_full) begin
              fifo_write_en <= 1'b1;
              wr_state <= WR_STORE_BYTE;
            end else begin
              // FIFO is full, skip this byte (or handle overflow)
              wr_state <= WR_IDLE;
            end
          end
        end

        WR_STORE_BYTE: begin
          fifo_write_en <= 1'b0;
          wr_state <= WR_IDLE;
        end

        default: wr_state <= WR_IDLE;
      endcase
    end
  end


  reg [7:0] axis_buf[5:0];
  reg [2:0] byte_position;
  always @(posedge clk) begin
    if (!r_rstn) begin
      byte_position <= 3'b0;
      fifo_read_en <= 1'b0;
      axis_dataval <= 0;
      axis_buf[0] <= 8'b0;
      axis_buf[1] <= 8'b0;
      axis_buf[2] <= 8'b0;
      axis_buf[3] <= 8'b0;
      axis_buf[4] <= 8'b0;
      axis_buf[5] <= 8'b0;
      read_fifo_state <= RD_FIFO_IDLE;

    end else begin
      case (read_fifo_state)
        RD_FIFO_IDLE: begin
          axis_dataval <= 1'b0;
          fifo_read_en <= 1'b0;
          if (!fifo_empty) begin
            fifo_read_en <= 1'b1;
            read_fifo_state <= RD_FIFO_WAIT;
          end
        end

        RD_FIFO_WAIT: begin
          fifo_read_en <= 1'b0;
          axis_buf[byte_position] <= fifo_data_out;
          // Prepare for next byte
          if (byte_position < 5) begin
            byte_position <= byte_position + 1;
            //fifo_read_en  <= 1'b1;
          end else begin
            byte_position <= 0;
            axis_dataval  <= 1'b1;
          end
          read_fifo_state <= RD_FIFO_IDLE;
        end

        default: read_fifo_state <= RD_FIFO_IDLE;
      endcase
    end
  end

  assign x_axis_filt_datain = {axis_buf[1], axis_buf[0]};
  assign y_axis_filt_datain = {axis_buf[5], axis_buf[4]};
  assign z_axis_filt_datain = {axis_buf[3], axis_buf[2]};

  // Main state machine for SPI communication
  always @(posedge clk) begin
    case (r_state)
      RESET: begin
        r_rstn <= 1'b0;
        o_spi_start <= 1'b0;
        multibyte_rd <= 1'b0;
        r_spi_tx_byte <= 8'b0;
        o_spi_rw_n <= 1'b1;
        o_spi_addr <= 6'b0;
        config_wait_counter <= 8'd0;
        if (reset_counter > RESET_CYCLES) begin
          r_rstn <= 1'b1;
          r_state <= SETUP_DEVID_RD;
          reset_counter <= 0;
        end else begin
          reset_counter <= reset_counter + 1;
        end
      end

      SETUP_DEVID_RD: begin
        if (i_spi_ready) begin
          o_spi_rw_n    <= 1'b1;  // READ
          o_spi_addr    <= DEVID_ADDR;
          multibyte_rd  <= 1'b0;  // Single byte
          r_spi_tx_byte <= 8'd1;  // Not used for single byte reads
          o_spi_start   <= 1'b1;
          r_state       <= STOP_DEVID_RD;
        end
      end

      STOP_DEVID_RD: begin
        o_spi_start <= 1'b0;
        if (i_spi_ready) begin
          r_state <= SETUP_PWR_CTRL_WR;
        end
      end

      SETUP_PWR_CTRL_WR: begin
        if (i_spi_ready) begin
          multibyte_rd  <= 1'b0;
          o_spi_rw_n    <= 1'b0;  // WRITE
          o_spi_addr    <= PWR_CTL_ADDR;
          r_spi_tx_byte <= PWR_CTL_VAL;
          o_spi_start   <= 1'b1;
          r_state       <= STOP_PWR_CTRL_WR;
        end
      end

      STOP_PWR_CTRL_WR: begin
        o_spi_start <= 1'b0;
        if (i_spi_ready) begin
          r_state <= SETUP_DATA_FORMAT_WR;
        end
      end

      SETUP_DATA_FORMAT_WR: begin
        if (i_spi_ready) begin
          multibyte_rd  <= 1'b0;
          o_spi_rw_n    <= 1'b0;  // WRITE
          o_spi_addr    <= DATA_FORMAT_ADDR;
          r_spi_tx_byte <= DATA_FORMAT_VAL;
          o_spi_start   <= 1'b1;
          r_state       <= STOP_DATA_FORMAT_WR;
        end
      end

      STOP_DATA_FORMAT_WR: begin
        o_spi_start <= 1'b0;
        if (i_spi_ready) begin
          r_state <= WAIT_AFTER_CONFIG;
        end
      end

      WAIT_AFTER_CONFIG: begin
        // Wait for ADXL345 to settle after configuration
        config_wait_counter <= config_wait_counter + 1;
        if (config_wait_counter == 8'hFF) begin
          r_state <= SETUP_DATAX0_RD;
        end
      end

      SETUP_DATAX0_RD: begin
        if (i_spi_ready) begin
          multibyte_rd  <= 1'b1;  // Multi-byte read
          o_spi_rw_n    <= 1'b1;  // READ

          o_spi_addr    <= DATAX0_ADDR;
          r_spi_tx_byte <= 8'd6;  // Read 6 bytes (X, Y, Z data - 2 bytes each)

          //o_spi_addr    <= DATAZ0_ADDR;
          //r_spi_tx_byte <= 8'd2;

          o_spi_start   <= 1'b1;
          r_state       <= STOP_DATAX0_RD;
        end
      end

      STOP_DATAX0_RD: begin
        o_spi_start <= 1'b0;
        if (i_spi_ready) begin
          r_state <= WAIT_DELAY;
          wait_counter <= 0;
        end
      end

      WAIT_DELAY: begin
        if (wait_counter >= WAIT_CYCLES) begin
          r_state <= SETUP_DATAX0_RD;
          wait_counter <= 0;
        end else begin
          wait_counter <= wait_counter + 1;
        end
      end

      default: r_state <= RESET;
    endcase
  end

endmodule
