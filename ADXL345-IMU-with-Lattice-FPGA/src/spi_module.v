module spi_module #(
    parameter SPI_MODE = 3,
    parameter CLKS_PER_HALF_BIT = 4
) (
    input            i_clk,
    input            i_spi_rst_n,
    output           o_spi_ready,
    output           o_dataval,
    input            i_spi_start,
    input            i_spi_rw_n,
    input            i_spi_multibyte_rd,
    input      [5:0] i_spi_addr,
    input      [7:0] i_spi_datain,
    output reg [7:0] o_spi_dataout,
    input            spi_miso,
    output           spi_mosi,
    output           spi_clk,
    output reg       spi_cs
);

  // SPI Master instance signals
  reg  [7:0] r_tx_byte;
  reg        r_tx_dataval;
  wire       w_tx_ready;
  wire       w_rx_dataval;
  wire [7:0] w_rx_byte;

  // SPI Master instantiation
  spi_master #(
      .SPI_MODE(SPI_MODE),
      .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
  ) inst_spi_master (
      .i_rst_n     (i_spi_rst_n),
      .i_clk       (i_clk),
      .i_tx_byte   (r_tx_byte),
      .i_tx_dataval(r_tx_dataval),
      .o_tx_ready  (w_tx_ready),
      .o_rx_dataval(w_rx_dataval),
      .o_rx_byte   (w_rx_byte),
      .o_SPI_clk   (spi_clk),
      .i_SPI_MISO  (spi_miso),
      .o_SPI_MOSI  (spi_mosi)
  );

  // State machine
  reg [3:0] r_state;

  // State definitions
  localparam IDLE = 4'b0000;
  localparam LOAD_ADDR = 4'b0001;
  localparam SEND_ADDR = 4'b0010;
  localparam WAIT_ADDR = 4'b0011;
  localparam LOAD_DATA = 4'b0100;
  localparam SEND_DATA = 4'b0101;
  localparam WAIT_DATA = 4'b0110;
  localparam LOAD_DUMMY = 4'b0111;
  localparam SEND_DUMMY = 4'b1000;
  localparam WAIT_DUMMY = 4'b1001;
  localparam FINISH = 4'b1010;
  localparam READY_TO_START = 4'b1011;

  // Control signals
  reg r_operation_complete;
  reg r_addr_sent;

  reg r_spi_start_d;
  wire w_spi_start_rising;
  reg [7:0] r_byte_counter;
  reg [7:0] r_num_bytes_to_rd;

  always @(posedge i_clk) begin
    r_spi_start_d <= i_spi_start;
  end

  assign o_spi_ready = (r_state == READY_TO_START) && w_tx_ready && r_operation_complete;
  assign o_dataval = w_rx_dataval && r_addr_sent;  // Only output data valid after address is sent
  assign w_spi_start_rising = i_spi_start && !r_spi_start_d;

  // Main state machine
  always @(posedge i_clk) begin
    if (!i_spi_rst_n) begin
      spi_cs <= 1'b1;
      r_state <= IDLE;
      r_tx_byte <= 8'h00;
      r_tx_dataval <= 1'b0;
      r_byte_counter <= 8'd0;
      r_operation_complete <= 1'b1;
      r_addr_sent <= 1'b0;
    end else begin
      case (r_state)
        IDLE: begin
          spi_cs <= 1'b1;
          r_tx_dataval <= 1'b0;
          r_addr_sent <= 1'b0;
          r_byte_counter <= 8'd0;  // Reset byte counter
          r_state <= READY_TO_START;
        end

        READY_TO_START: begin
          if (w_spi_start_rising && w_tx_ready) begin
            r_operation_complete <= 1'b0;
            r_state <= LOAD_ADDR;
          end
        end

        LOAD_ADDR: begin
          // ADXL345 protocol: Bit 7 = R/W, Bit 6 = MB (multibyte), Bits 5:0 = Address
          if (i_spi_multibyte_rd) begin
            r_tx_byte <= {i_spi_rw_n, 1'b1, i_spi_addr};  // MB=1 for multibyte
            r_num_bytes_to_rd <= i_spi_datain;
          end else begin
            r_tx_byte <= {i_spi_rw_n, 1'b0, i_spi_addr};  // MB=0 for single byte
            r_num_bytes_to_rd <= 8'd1;
          end
          spi_cs  <= 1'b0;
          r_state <= SEND_ADDR;
        end

        SEND_ADDR: begin
          if (w_tx_ready) begin
            r_tx_dataval <= 1'b1;
            r_state <= WAIT_ADDR;
          end
        end

        WAIT_ADDR: begin
          r_tx_dataval <= 1'b0;
          if (w_tx_ready) begin
            if (i_spi_rw_n) begin
              r_state <= LOAD_DUMMY;
            end else begin
              r_state <= LOAD_DATA;
            end
          end
        end

        LOAD_DATA: begin
          r_tx_byte <= i_spi_datain;
          r_state   <= SEND_DATA;
        end

        SEND_DATA: begin
          if (w_tx_ready) begin
            r_tx_dataval <= 1'b1;
            r_state <= WAIT_DATA;
          end
        end

        WAIT_DATA: begin
          r_tx_dataval <= 1'b0;
          if (w_tx_ready) begin
            r_state <= FINISH;
          end
        end

        LOAD_DUMMY: begin
          r_addr_sent <= 1'b1;
          r_tx_byte <= 8'h00;
          r_state <= SEND_DUMMY;
        end

        SEND_DUMMY: begin
          if (w_tx_ready) begin
            r_tx_dataval <= 1'b1;
            r_state <= WAIT_DUMMY;
          end
        end

        WAIT_DUMMY: begin
          r_tx_dataval <= 1'b0;
          if (w_tx_ready) begin
           r_addr_sent <= 1'b0; 
              r_byte_counter <= r_byte_counter + 1;
            if (r_byte_counter + 1 < r_num_bytes_to_rd) begin
              r_state <= LOAD_DUMMY;
            end else begin
              r_state <= FINISH;
            end
          end
        end

        FINISH: begin
          if (w_tx_ready && !r_tx_dataval) begin
            spi_cs <= 1'b1;
            r_operation_complete <= 1'b1;
            r_state <= IDLE;
          end
        end

        default: begin
          r_state <= IDLE;
        end
      endcase
    end
  end

  // Capture received data for read operations
  always @(posedge i_clk) begin
    if (!i_spi_rst_n) begin
      o_spi_dataout <= 8'h00;
    end else begin
      if (w_rx_dataval && r_addr_sent) begin
        o_spi_dataout <= w_rx_byte;
      end
    end
  end

endmodule

