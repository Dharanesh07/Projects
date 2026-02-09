// i_i2c_start input active high initiates the i2c transaction
// Keeping it high will initiate repeated start

//i_i2c_wr_byte - 8 bit data which should be held stable for a clock before writing

//o_i2c_ack - active high signal indicates ack pulse from i2c
//o_i2c_tx_done - active high indicates i2c write completion

//o_i2c_dataval - indicates valid data from i2c read
//o_i2c_rd_byte - 8 bit data from i2c line


`timescale 1ns / 1ps


module i2c #(
    parameter I2C_FREQ    = 100000,
    parameter IP_CLK_FREQ = 50000000
) (
    input            i_clk,
    input            i_rstn,
    input            i_i2c_start,
    input            i_i2c_stop,
    output reg [3:0] state,
    input      [7:0] i_i2c_wr_byte,
    output           o_i2c_tx_done,
    output           o_i2c_ack,
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

  //reg  [  STATE_WIDTH-1:0] state;
  reg  [  STATE_WIDTH-1:0] state_nxt;

  // 7 bit address + 1 Read or write bit + 1 ACK bit
  reg  [              8:0] wr_byte;
  reg  [              8:0] wr_byte_nxt;
  reg  [              3:0] bit_index;
  reg  [              3:0] bit_index_nxt;
  reg                      o_i2c_dataval_nxt;
  reg  [              7:0] o_i2c_rd_byte_nxt;
  reg                      sda_en;
  reg                      sda_en_nxt;
  reg                      scl_en;
  reg                      scl_en_nxt;
  wire                     scl_hi_clk_mid;
  wire                     scl_lo_clk_mid;
  reg                      start;
  reg                      start_nxt;
  reg                      tx_done;
  reg                      tx_done_nxt;
  reg                      i2c_ack;
  reg                      i2c_ack_nxt;

  reg  [COUNTER_WIDTH-1:0] clk_counter;
  reg  [COUNTER_WIDTH-1:0] clk_counter_nxt;

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
      sda_en        <= 1;
      scl_en        <= 1;
      wr_byte       <= 0;
      bit_index     <= 0;
      clk_counter   <= 0;
      start         <= 0;
      tx_done       <= 0;
      i2c_ack       <= 0;
      o_i2c_rd_byte <= 0;
      o_i2c_dataval <= 0;
    end else begin
      wr_byte       <= wr_byte_nxt;
      start         <= start_nxt;
      state         <= state_nxt;
      sda_en        <= sda_en_nxt;
      scl_en        <= scl_en_nxt;
      bit_index     <= bit_index_nxt;
      clk_counter   <= clk_counter_nxt;
      tx_done       <= tx_done_nxt;
      i2c_ack       <= i2c_ack_nxt;
      o_i2c_rd_byte <= o_i2c_rd_byte_nxt;
      o_i2c_dataval <= o_i2c_dataval_nxt;
    end
  end


  always @(*) begin

    wr_byte_nxt       = wr_byte;
    bit_index_nxt     = bit_index;
    state_nxt         = state;
    start_nxt         = start;
    sda_en_nxt        = sda_en;
    i2c_ack_nxt       = 1'b1;
    tx_done_nxt       = 1'b0;
    o_i2c_dataval_nxt = o_i2c_dataval;
    o_i2c_rd_byte_nxt = o_i2c_rd_byte;

    case (state)
      IDLE: begin  //0
        sda_en_nxt = 1'b1;
        if (i_i2c_start == 1'b1) begin
          start_nxt = i_i2c_wr_byte[0];  //last bit denotes R/W
          // left shift and add 1'b1 to detect acknowledge signal
          wr_byte_nxt = {i_i2c_wr_byte, 1'b1};
          bit_index_nxt = 4'd8;
          state_nxt = START_MODE;
        end
      end

      START_MODE: begin  //1
        if (scl_hi_clk_mid) begin
          sda_en_nxt = 1'b0;
          state_nxt  = SEND_DATA;
        end
      end

      SEND_DATA: begin  //2
        if (scl_lo_clk_mid) begin
          sda_en_nxt    = (wr_byte[bit_index]);
          bit_index_nxt = bit_index - 1;
          if (bit_index == 0) begin
            bit_index_nxt = 0;
            state_nxt     = READ_ACK;
          end
        end
      end

      READ_ACK: begin  //3 
        if (scl_hi_clk_mid) begin
          tx_done_nxt = 1'b1;
          i2c_ack_nxt = i2c_sda;
          start_nxt   = i_i2c_start;
          wr_byte_nxt = {i_i2c_wr_byte, 1'b1};
          if (i_i2c_stop) begin
            state_nxt = STOP1;
          end else if (start == 1 && wr_byte[1] == 1) begin
            //wr_byte[1] == 1 corresponds to read operation
            start_nxt = 0;
            // last bit is the ack which master needs to provide
            bit_index_nxt = 7;
            state_nxt = READ_DATA;
          end else state_nxt = REPEAT_START;  // repeated start
        end
      end
      REPEAT_START: begin  //4
        bit_index_nxt = 8;
        if (start) state_nxt = START_MODE;
        else state_nxt = SEND_DATA;
      end
      READ_DATA: begin  //5
        o_i2c_dataval_nxt = 1'b0;
        if (scl_hi_clk_mid) begin
          o_i2c_rd_byte_nxt[bit_index] = i2c_sda;
          bit_index_nxt                = bit_index - 1;
          if (bit_index == 0) begin
            bit_index_nxt = 0;
            state_nxt     = SEND_ACK;
          end
        end
      end
      SEND_ACK: begin  //6
        if (scl_lo_clk_mid) begin
          sda_en_nxt = 1'b0;  // i2c data acknowledge    
          //sda_en_nxt = 1'b1;  // sccb do not need acknowledge
          if (sda_en == 0 || sda_en_nxt == 1) begin
            o_i2c_dataval_nxt = 1'b1;
            bit_index_nxt     = 7;
            if (i_i2c_stop) state_nxt = STOP1;  // stop current i2c transaction
            else if (i_i2c_start) begin  // repeated start
              start_nxt = 1;
              state_nxt = START_MODE;
            end else state_nxt = READ_DATA;  // read data without start
          end

        end
      end
      STOP1: begin  //7
        if (scl_lo_clk_mid) begin
          o_i2c_dataval_nxt = 1'b0;
          sda_en_nxt = 1'b0;
          state_nxt = STOP2;
        end
      end

      STOP2: begin  //8
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

  assign o_i2c_tx_done = tx_done;
  assign o_i2c_ack = i2c_ack;


`ifdef DEBUG
  // For testbench since there is no external pullup
  assign i2c_scl = scl_en ? 1'b1 : 1'b0;
  assign i2c_sda = sda_en ? 1'b1 : 1'b0;
`else
  // I2C Open drian (Master ACK has to be changed)
  assign i2c_scl = scl_en ? 1'bz : 1'b0;
  assign i2c_sda = sda_en ? 1'bz : 1'b0;
`endif

  //SCCB Operation (Master ACK has to be changed)
  //assign i2c_scl = scl_en ? 1'b1 : 1'b0;
  //assign i2c_sda = (state == READ_DATA || state == READ_ACK) ? 1'bz : (sda_en ? 1'b1 : 1'b0);
  //assign i2c_sda = sda_en ? 1'b1 : 1'b0;

endmodule

