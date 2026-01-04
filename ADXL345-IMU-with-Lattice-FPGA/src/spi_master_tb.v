`timescale 1us / 1ns

module spi_master_tb ();

  parameter SPI_MODE = 3;  // CPOL = 1, CPHA = 1
  parameter CLKS_PER_HALF_BIT = 4;  // 6.25 MHz
  parameter MAIN_CLK_DELAY = 41;  // 25 MHz
  parameter DURATION = 10000000;
  reg        r_Rst_L = 1'b0;
  wire       w_SPI_Clk;
  reg        r_Clk = 1'b0;
  wire       w_SPI_loop;

  // Master Specific
  reg  [7:0] r_Master_TX_Byte = 0;
  reg        r_Master_TX_DV = 1'b0;
  wire       w_Master_TX_Ready;
  wire       r_Master_RX_DV;
  wire [7:0] r_Master_RX_Byte;

  // Clock Generators:
  always #(MAIN_CLK_DELAY) r_Clk = ~r_Clk;

  // Instantiate UUT
  spi_master #(
      .SPI_MODE(SPI_MODE),
      .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
  ) SPI_Master_UUT (
      // Control/Data Signals,
      .i_rst_n(r_Rst_L),  // FPGA Reset
      .i_clk  (r_Clk),    // FPGA Clock

      // TX (MOSI) Signals
      .i_tx_byte   (r_Master_TX_Byte),  // Byte to transmit on MOSI
      .i_tx_dataval(r_Master_TX_DV),    // Data Valid Pulse with i_TX_Byte
      .o_tx_ready  (w_Master_TX_Ready), // Transmit Ready for Byte

      // RX (MISO) Signals
      .o_rx_dataval(r_Master_RX_DV),  // Data Valid pulse (1 clock cycle)
      .o_rx_byte   (r_Master_RX_Byte),  // Byte received on MISO

      // SPI Interface
      .o_SPI_clk (w_SPI_Clk),
      .i_SPI_MISO(w_SPI_loop),
      .o_SPI_MOSI(w_SPI_loop)
  );

  reg [7:0] send_data;
  reg send_byte;

  initial begin
    // Required for EDA Playground

    repeat (10) @(posedge r_Clk);
    r_Rst_L = 1'b0;
    repeat (10) @(posedge r_Clk);
    r_Rst_L   = 1'b1;

    // Test single byte
    send_data = 8'hC1;
    send_byte = 1'b1;
    @(posedge w_Master_TX_Ready);
    $display("Sent out 0xC1, Received 0x%X", r_Master_RX_Byte);

    // Test double byte
    send_data = 8'hBE;
    send_byte = 1'b1;
    @(posedge w_Master_TX_Ready);
    $display("Sent out 0xBE, Received 0x%X", r_Master_RX_Byte);

    send_data = 8'hEF;
    send_byte = 1'b1;
    @(posedge w_Master_TX_Ready);
    $display("Sent out 0xEF, Received 0x%X", r_Master_RX_Byte);

    repeat (10) @(posedge r_Clk);
  end

  always @(posedge r_Clk) begin
    if (send_byte) begin
      r_Master_TX_Byte <= send_data;
      r_Master_TX_DV <= 1'b1;
      send_byte <= 1'b0;
    end else begin
      r_Master_TX_DV <= 1'b0;
    end
  end

  initial begin
    $dumpfile("spi_master_tb.vcd");
    $dumpvars(0, spi_master_tb);
    #(DURATION);
    $finish;
  end
endmodule
