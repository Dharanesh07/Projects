`timescale 1ns / 1ps

module i2c #(
    parameter I2C_FREQ    = 100000,
    parameter IP_CLK_FREQ = 50000000
) (
    input            i_clk,
    input            i_rstn,
    input            i_i2c_start,
    input            i_i2c_stop,
    input      [7:0] i_i2c_wr_byte,
    output reg       o_i2c_tx_done,
    output reg       o_i2c_ack,
    output reg       o_i2c_dataval,
    output reg [7:0] o_i2c_rd_byte,
    inout            i2c_scl,
    inout            i2c_sda
);

  // i2c clock
  // one clock cycle has both high and low pulse
  localparam CLK_DIV_FULL = IP_CLK_FREQ / (2 * I2C_FREQ);
  localparam CLK_DIV_HALF = CLK_DIV_FULL / 2;
  localparam COUNTER_WIDTH = $clog2(CLK_DIV_FULL);

  localparam IDLE = 0;
  localparam START_MODE = 1;
  localparam SEND_DATA = 2;
  localparam READ_ACK = 3;
  localparam REPEAT_START = 4;
  localparam READ_DATA = 5;
  localparam SEND_ACK = 6;
  localparam STOP1 = 7;
  localparam STOP2 = 8;
  localparam LAST_STATE = 9;

  localparam STATE_WIDTH = $clog2(LAST_STATE);

  reg [STATE_WIDTH-1:0] state;
  reg [STATE_WIDTH-1:0] state_nxt;

  // 7 bit address + 1 Read or write bit + 1 ACK bit
  reg [8:0] wr_byte;
  reg [8:0] wr_byte_nxt;
  reg [8:0] rd_byte;
  reg [8:0] rd_byte_nxt;
  reg [3:0] bit_index;
  reg [3:0] bit_index_nxt;

  reg sda_en;
  reg sda_en_nxt;
  reg scl_en;
  reg scl_en_nxt;
  wire scl_hi_clk_mid;
  wire scl_lo_clk_mid;
  reg start;
  reg start_nxt;

  reg [COUNTER_WIDTH-1:0] clk_counter;
  reg [COUNTER_WIDTH-1:0] clk_counter_nxt;

  // Clock divider
  always @(*) begin
    clk_counter_nxt = clk_counter + 1;
    scl_en_nxt = scl_en;
    if (state == IDLE || state == START_MODE) begin
      scl_en_nxt = 1'b1;
    end else if (clk_counter == CLK_DIV_FULL) begin
      clk_counter_nxt = 0;
      scl_en_nxt      = (scl_en == 0) ? 1'b1 : 1'b0;
    end
  end

  always @(posedge i_clk) begin
    if (!i_rstn) begin
      state         <= IDLE;
      sda_en        <= 0;
      scl_en        <= 0;
      wr_byte       <= 0;
      rd_byte       <= 0;
      bit_index     <= 0;
      clk_counter   <= 0;
      o_i2c_tx_done <= 0;
      start         <= 0;
    end else begin
      start       <= start_nxt;
      state       <= state_nxt;
      sda_en      <= sda_en_nxt;
      scl_en      <= scl_en_nxt;
      wr_byte     <= wr_byte_nxt;
      rd_byte     <= rd_byte_nxt;
      bit_index   <= bit_index_nxt;
      clk_counter <= clk_counter_nxt;
    end
  end


  always @(*) begin
    wr_byte_nxt   = wr_byte;
    rd_byte_nxt   = rd_byte;
    bit_index_nxt = bit_index;
    state_nxt     = state;
    start_nxt     = start;
    sda_en_nxt    = sda_en;
    o_i2c_ack     = 0;
    case (state)
      IDLE: begin
        sda_en_nxt = 1'b1;
        if (i_i2c_start == 1'b1) begin
          start_nxt = i_i2c_wr_byte[0];  //last bit denotes R/W
          // left shift and add 1'b1 to detect acknowledge signal
          wr_byte_nxt = {i_i2c_wr_byte, 1'b1};
          bit_index_nxt = 4'd8;
          state_nxt = START_MODE;
        end
      end

      START_MODE: begin
        if (scl_hi_clk_mid) begin
          sda_en_nxt = 1'b0;
          state_nxt  = SEND_DATA;
        end
      end

      SEND_DATA: begin
        if (scl_lo_clk_mid) begin
          sda_en_nxt    = (wr_byte[bit_index]);
          bit_index_nxt = bit_index - 1;
          if (bit_index == 0) begin
            state_nxt     = READ_ACK;
            bit_index_nxt = 0;
          end
        end
      end

      READ_ACK: begin
        if (scl_hi_clk_mid) begin
          o_i2c_tx_done = 1'b1;
          o_i2c_ack     = i2c_sda;
          start_nxt     = i_i2c_start;
          wr_byte_nxt   = {i_i2c_wr_byte, 1'b1};
          if (i_i2c_stop) state_nxt = STOP1;
          else if (start == 1 && wr_byte[1] == 1) begin
            //wr_byte[1] corresponds to read or write bit
            o_i2c_tx_done = 1'b0;
            start_nxt = 0;
            state_nxt = READ_DATA;
          end else state_nxt = REPEAT_START;
        end
      end

      REPEAT_START: begin
        bit_index_nxt = 8;
        if (start) state_nxt = START_MODE;
        else state_nxt = SEND_DATA;
      end

      READ_DATA: begin
        bit_index_nxt = 7;  // last bit is the ack which master needs to provide
        if (scl_hi_clk_mid) begin
          rd_byte_nxt[bit_index] = i2c_sda;
          bit_index_nxt          = bit_index - 1;
          if (bit_index == 0) begin
            bit_index_nxt = 0;
            state_nxt     = SEND_ACK;
          end
        end
      end
      SEND_ACK: begin
        if (scl_lo_clk_mid) begin
          //sda_en_nxt = 1'b0;  // i2c data acknowledge    
          sda_en_nxt = 1'b1;  // sccb do not need acknowledge
          if (sda_en == 0 || sda_en_nxt == 1) begin
            o_i2c_dataval = 1'b1;
            bit_index_nxt = 7;
            if (i_i2c_stop) state_nxt = STOP1;
            else if (i_i2c_start) begin
              start_nxt = 1;
              state_nxt = START_MODE;
            end else state_nxt = READ_DATA;
          end

        end
      end
      STOP1: begin
        if (scl_lo_clk_mid) begin
          sda_en_nxt = 1'b0;
          state_nxt  = STOP2;
        end
      end

      STOP2: begin
        if (scl_hi_clk_mid) begin
          sda_en_nxt = 1'b1;
          state_nxt  = IDLE;
        end
      end
      default: begin
        state_nxt = IDLE;
      end
    endcase

  end

  assign scl_hi_clk_mid = (scl_en == 1'b1) && (clk_counter == CLK_DIV_HALF) && (i2c_scl == 1'b1);
  assign scl_lo_clk_mid = (scl_en == 1'b0) && (clk_counter == CLK_DIV_HALF);

  // I2C Open drian (Master ACK has to be changed)
  assign i2c_scl = scl_en ? 1'b1 : 1'b0;
  assign i2c_sda = sda_en ? 1'b1 : 1'b0;

  //SCCB Operation (Master ACK has to be changed)
  //assign i2c_scl = scl_en ? 1'b1 : 1'b0;
  //assign i2c_sda = (state == READ_DATA || state == READ_ACK) ? 1'bz : (sda_en ? 1'b1 : 1'b0);
  //assign i2c_sda = sda_en ? 1'b1 : 1'b0;

endmodule

