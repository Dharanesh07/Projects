// Parameters:  SPI_MODE, can be 0, 1, 2, or 3.  See above.
//              Can be configured in one of 4 modes:
//              Mode | Clock Polarity (CPOL/CKP) | Clock Phase (CPHA)
//               0   |             0             |        0
//               1   |             0             |        1
//               2   |             1             |        0
//               3   |             1             |        1


// Input clock frequency i_clk = 100MHz
// CLKS_PER_HALF_BIT = 2
// Clk for a bit = 4
// Resulting o_SPI_clk = 25MHz
//
// Similarly for i_clk = 12MHz
// CLKS_PER_HALF_BIT = 2
// Clk for a bit = 4
// Resulting spi clk = 3MHz


module spi_master #(
    parameter SPI_MODE = 3,
    parameter CLKS_PER_HALF_BIT = 4
) (
    input i_rst_n,
    input i_clk,

    //Tx (MOSI)
    input      [7:0] i_tx_byte,
    input            i_tx_dataval,
    output reg       o_tx_ready,

    //Rx (MISO)
    output reg o_rx_dataval,
    output reg [7:0] o_rx_byte,

    //SPI Interface
    output     o_SPI_clk,
    input      i_SPI_MISO,
    output reg o_SPI_MOSI

);


  // SPI Interface (All Runs at SPI Clock Domain)
  wire                                   w_CPOL;  // Clock polarity
  wire                                   w_CPHA;  // Clock phase

  reg  [$clog2(CLKS_PER_HALF_BIT*2)-1:0] r_spi_clk_count;
  reg                                    r_spi_clk;
  reg  [                            4:0] r_spi_clk_edges;
  reg                                    r_leading_edge;
  reg                                    r_trailing_edge;
  reg                                    r_tx_dv;
  reg  [                            7:0] r_tx_byte;

  reg  [                            2:0] r_rx_bit_count;
  reg  [                            2:0] r_tx_bit_count;

  // CPOL: Clock Polarity
  // CPOL=0 means clock idles at 0, leading edge is rising edge.
  // CPOL=1 means clock idles at 1, leading edge is falling edge.
  assign w_CPOL = (SPI_MODE == 2) | (SPI_MODE == 3);

  // CPHA: Clock Phase
  // CPHA=0 means the master changes the data on trailing edge of clock while 
  // the slave captures data on leading edge of clock
  // CPHA=1 means the master changes the data on leading edge of clock while 
  // the slave captures data on the trailing edge of clock
  assign w_CPHA = (SPI_MODE == 1) | (SPI_MODE == 3);
  assign o_SPI_clk = r_spi_clk;

  // Purpose: Generate SPI Clock correct number of times when DV pulse comes
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      o_tx_ready      <= 1'b0;
      r_spi_clk_edges <= 0;
      r_leading_edge  <= 1'b0;
      r_trailing_edge <= 1'b0;
      r_spi_clk       <= w_CPOL;  // assign default state to idle state
      r_spi_clk_count <= 0;
    end else begin

      // Default assignments
      r_leading_edge  <= 1'b0;
      r_trailing_edge <= 1'b0;

      //When new data transmission is initiated
      if (i_tx_dataval) begin
        o_tx_ready      <= 1'b0;
        r_spi_clk_edges <= 16;  // Total # edges in one byte ALWAYS 16
      end else if (r_spi_clk_edges > 0) begin
        o_tx_ready <= 1'b0;

        //if CLKS_PER_HALF_BIT = 2, then at 3 which should be falling edge of
        //the signal. So here trailing edge is the rising edge of the signal 
        if (r_spi_clk_count == CLKS_PER_HALF_BIT * 2 - 1) begin
          r_spi_clk_edges <= r_spi_clk_edges - 1'b1;
          r_trailing_edge <= 1'b1;  //signal reset at default assignments
          r_spi_clk_count <= 0;
          r_spi_clk       <= ~r_spi_clk;
        end else if (r_spi_clk_count == CLKS_PER_HALF_BIT - 1) begin
          //if CLKS_PER_HALF_BIT = 2, then at 1 which should be rising edge of
          //the signal. So here the leading edge is the rising edge of the signal 
          r_spi_clk_edges <= r_spi_clk_edges - 1'b1;
          r_leading_edge  <= 1'b1;  //signal reset at default assignments
          r_spi_clk_count <= r_spi_clk_count + 1'b1;
          r_spi_clk       <= ~r_spi_clk;
        end else begin
          r_spi_clk_count <= r_spi_clk_count + 1'b1;
        end

      end else begin
        o_tx_ready <= 1'b1;
      end
    end
  end

  // Purpose: Register i_TX_Byte when Data Valid is pulsed.
  // Keeps local storage of byte in case higher level module changes the data
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      r_tx_byte <= 8'h00;
      r_tx_dv   <= 1'b0;
    end else begin
      r_tx_dv <= i_tx_dataval;  // 1 clock cycle delay
      if (r_tx_dv) begin
        r_tx_byte <= i_tx_byte;
      end
    end
  end



  // Purpose: Generate MOSI data Works with both CPHA=0 and CPHA=1
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      o_SPI_MOSI     <= 1'b0;
      r_tx_bit_count <= 3'b111;  // send MSb first
    end else begin
      // If ready is high, reset bit counts to default
      if (o_tx_ready) begin
        r_tx_bit_count <= 3'b111;
      end  // Catch the case where we start transaction and CPHA = 0
      else if (r_tx_dv & ~w_CPHA) begin
        o_SPI_MOSI     <= r_tx_byte[3'b111];
        r_tx_bit_count <= 3'b110;
        // w_CPHA is 0, trailing edge -> Data change and leading edge -> Data
        // sample
        // w_CPHA is 1, leading edge -> Data change and trailing edge -> Data
        // sample
        // so, when w_CPHA is 0, then whenever the clock reaches trailing edge
        // the data is changed.
        // Similarly when w_CPHA is 1, whenever the clock reaches leading edge
        // the data is changed
        // The actual control is done from the clock module.
      end else if ((r_leading_edge & w_CPHA) | (r_trailing_edge & ~w_CPHA)) begin
        r_tx_bit_count <= r_tx_bit_count - 1'b1;
        o_SPI_MOSI     <= r_tx_byte[r_tx_bit_count];
      end
    end
  end


  // Purpose: Read in MISO data.
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      o_rx_byte      <= 8'h00;
      o_rx_dataval   <= 1'b0;
      r_rx_bit_count <= 3'b111;
    end else begin
      // Default Assignments
      o_rx_dataval <= 1'b0;
      // Check if ready is high, if so reset bit count to default
      if (o_tx_ready) begin
        r_rx_bit_count <= 3'b111;
      end else if ((r_leading_edge & ~w_CPHA) | (r_trailing_edge & w_CPHA)) begin
        o_rx_byte[r_rx_bit_count] <= i_SPI_MISO;  // Sample data
        r_rx_bit_count <= r_rx_bit_count - 1'b1;
        if (r_rx_bit_count == 3'b000) begin
          o_rx_dataval <= 1'b1;  // Byte done, pulse Data Valid
        end
      end
    end
  end

endmodule
