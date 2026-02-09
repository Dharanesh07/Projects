`timescale 1ns / 1ps

module top (
    input            sys_clk,
    inout            i2c_scl,
    inout            i2c_sda,
    output reg [7:0] debug_led
);


  reg rstn = 0;
  reg rst_done = 0;
  reg [14:0] r_rst_cycle = 0;

  localparam DS3231M_WR_ADDR = 8'hD0;
  localparam DS3231M_RD_ADDR = 8'hD1;
  localparam DS3231M_SEC_REG = 8'h00;


  always @(posedge sys_clk) begin
    if ((r_rst_cycle < 10000) && (!rst_done)) begin
      r_rst_cycle <= r_rst_cycle + 1;
      rstn        <= 1'b0;
    end else begin
      rstn <= 1'b1;
      rst_done <= 1'b1;
    end
  end

  localparam I2C_FREQ = 100000;
  localparam CLK_FREQ = 50000000;


  localparam START = 0;
  localparam DEV_ADDR = 1;
  localparam WRITE_DATA = 2;
  localparam READ_ADDR = 3;
  localparam READ_DATA = 4;
  localparam WAIT_STATE1 = 5;
  localparam WAIT_STATE2 = 6;


  reg  [2:0] rstate;
  reg  [2:0] rstate_nxt;
  reg        i2c_tx_start;
  reg        i2c_tx_start_nxt;
  reg        i2c_tx_stop;
  reg        i2c_tx_stop_nxt;
  reg  [7:0] i2c_wrbyte;
  reg  [7:0] i2c_wrbyte_nxt;
  wire [7:0] i2c_rdbyte;
  wire       i2c_ack;
  wire       i2c_dataval;
  wire       i2c_tx_done;


  wire [7:0] i2cstate;

  i2c #(
      .I2C_FREQ   (I2C_FREQ),
      .IP_CLK_FREQ(CLK_FREQ)
  ) inst_i2c (
      .i_clk        (sys_clk),
      .i_rstn       (rstn),
      .i_i2c_start  (i2c_tx_start),
      .i_i2c_stop   (i2c_tx_stop),
      .state        (i2cstate),
      .i_i2c_wr_byte(i2c_wrbyte),
      .o_i2c_tx_done(i2c_tx_done),
      .o_i2c_ack    (i2c_ack),
      .o_i2c_dataval(i2c_dataval),
      .o_i2c_rd_byte(i2c_rdbyte),
      .i2c_scl      (i2c_scl),
      .i2c_sda      (i2c_sda)
  );

  //assign debug_led = ~(i2cstate);

  always @(posedge sys_clk) begin
    if (!rstn) begin
      rstate       <= 0;
      i2c_wrbyte   <= 0;
      i2c_tx_start <= 1'b0;
      i2c_tx_stop  <= 1'b0;
    end else begin
      rstate       <= rstate_nxt;
      i2c_tx_start <= i2c_tx_start_nxt;
      i2c_tx_stop  <= i2c_tx_stop_nxt;
      i2c_wrbyte   <= i2c_wrbyte_nxt;
      debug_led    <= ~(i2c_rdbyte);
    end
  end

  always @(*) begin

    rstate_nxt       = rstate;
    i2c_wrbyte_nxt   = i2c_wrbyte;
    i2c_tx_start_nxt = i2c_tx_start;
    //i2c_tx_stop_nxt  = i2c_tx_stop;
    i2c_tx_start_nxt = 1'b0;
    case (rstate)
      START: begin  //0
        if (rst_done) begin
          i2c_wrbyte_nxt = DS3231M_WR_ADDR;
          rstate_nxt = DEV_ADDR;
        end
      end
      DEV_ADDR: begin  // 1
        i2c_tx_start_nxt = 1'b1;
        if (!i2c_ack) begin
          i2c_wrbyte_nxt = 8'h00;
          rstate_nxt = WAIT_STATE1;
        end
      end
      WAIT_STATE1: begin
        rstate_nxt = WRITE_DATA;
      end

      WRITE_DATA: begin  // 2
        i2c_tx_start_nxt = 1'b1;
        //i2c_tx_stop_nxt = 1'b1;
        if (!i2c_ack) begin
          i2c_wrbyte_nxt   = DS3231M_RD_ADDR;
          i2c_tx_start_nxt = 1'b0;
          rstate_nxt       = WAIT_STATE2;
        end
      end

      WAIT_STATE2: begin
        rstate_nxt = READ_ADDR;
      end

      READ_ADDR: begin  // 3
        i2c_tx_start_nxt = 1'b1;
        if (!i2c_ack) begin
          i2c_wrbyte_nxt = DS3231M_RD_ADDR;
          rstate_nxt     = READ_DATA;
        end
      end

      READ_DATA: begin  // 4
        i2c_tx_start_nxt = 1'b1;
        if (!i2c_ack) begin
          i2c_tx_stop_nxt = 1'b1;
          rstate_nxt      = READ_DATA;
        end
      end

      default: begin
        rstate_nxt = START;
      end
    endcase
  end

endmodule
