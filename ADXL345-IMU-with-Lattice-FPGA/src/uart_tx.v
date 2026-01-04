// When transmit is complete o_Tx_done will be driven high for one clock cycle.

// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_clk)/(Frequency of UART)
// Example: 12 MHz Clock, 115200 baud UART
// (12000000)/(115200) = 104.16
// 12000000 / 9600 = 1250

module uart_tx #(
    parameter CLKS_PER_BIT = 1250
) (
    input            i_clk,
    input            i_rstn,
    input            i_txsenddata,
    input      [7:0] i_txbyte,
    output           o_txactive,
    output reg       o_uarttx,
    output           o_txdone
);

  parameter IDLE = 3'b000;
  parameter TX_START_BIT = 3'b001;
  parameter TX_DATA_BITS = 3'b010;
  parameter TX_STOP_BIT = 3'b011;
  parameter CLEANUP = 3'b100;

  reg [ 2:0] r_state = 0;
  reg [15:0] r_clkcnt = 0;
  reg [ 2:0] r_bitindex = 0;
  reg [ 7:0] r_txdata = 0;
  reg        r_txdone = 1;
  reg        r_txactive = 0;

  initial begin
    r_state = IDLE;
  end

  always @(posedge i_clk) begin
    if (!i_rstn) begin
      // Reset all registers
      r_state    <= IDLE;
      r_clkcnt   <= 0;
      r_bitindex <= 0;
      r_txdata   <= 0;
      r_txdone   <= 1'b1;
      r_txactive <= 1'b0;
      o_uarttx   <= 1'b1;  // UART line should be high when idle
    end else begin
      case (r_state)
        IDLE: begin
          o_uarttx   <= 1'b1;  // Drive Line High for Idle
          r_txdone   <= 1'b1;
          r_clkcnt   <= 0;
          r_bitindex <= 0;

          if (i_txsenddata == 1'b1) begin
            r_txdone <= 1'b0;
            r_txactive <= 1'b1;
            r_txdata <= i_txbyte;
            r_state <= TX_START_BIT;
          end else r_state <= IDLE;
        end  // case: IDLE


        // Send out Start Bit. Start bit = 0
        TX_START_BIT: begin
          o_uarttx <= 1'b0;

          // Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
          if (r_clkcnt < CLKS_PER_BIT - 1) begin
            r_clkcnt <= r_clkcnt + 1;
            r_state  <= TX_START_BIT;
          end else begin
            r_clkcnt <= 0;
            r_state  <= TX_DATA_BITS;
          end
        end  // case: TX_START_BIT


        // Wait CLKS_PER_BIT-1 clock cycles for data bits to finish         
        TX_DATA_BITS: begin
          o_uarttx <= r_txdata[r_bitindex];

          if (r_clkcnt < CLKS_PER_BIT - 1) begin
            r_clkcnt <= r_clkcnt + 1;
            r_state  <= TX_DATA_BITS;
          end else begin
            r_clkcnt <= 0;

            // Check if we have sent out all bits
            if (r_bitindex < 7) begin
              r_bitindex <= r_bitindex + 1;
              r_state <= TX_DATA_BITS;
            end else begin
              r_bitindex <= 0;
              r_state <= TX_STOP_BIT;
            end
          end
        end  // case: TX_DATA_BITS


        // Send out Stop bit.  Stop bit = 1
        TX_STOP_BIT: begin
          o_uarttx <= 1'b1;

          // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
          if (r_clkcnt < CLKS_PER_BIT - 1) begin
            r_clkcnt <= r_clkcnt + 1;
            r_state  <= TX_STOP_BIT;
          end else begin
            r_txdone   <= 1'b1;
            r_clkcnt   <= 0;
            r_state    <= CLEANUP;
            r_txactive <= 1'b0;
          end
        end  // case: s_Tx_STOP_BIT


        // Stay here 1 clock
        CLEANUP: begin
          r_txdone <= 1'b1;
          r_state  <= IDLE;
        end


        default: r_state <= IDLE;

      endcase
    end
  end

  assign o_txactive = r_txactive;
  assign o_txdone   = r_txdone;

endmodule
