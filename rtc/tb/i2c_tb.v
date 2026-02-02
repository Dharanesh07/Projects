`timescale 1ns / 1ps

module i2c_tb ();

  parameter DURATION = 1000000;
  parameter CLK_PERIOD = 10;  // 10ns = 100MHz

  reg r_clk;
  reg o_rst_n;
  reg start;
  reg stop;
  reg [7:0] wr_data;
  wire ack;
  wire [7:0] rd_data;
  wire scl;
  wire sda;
  wire rd_val;
  reg sda_en;

  i2c #(
      .I2C_FREQ(100_000),
      .IP_CLK_FREQ(100_000_000)
  ) inst (
      .i_clk        (r_clk),
      .i_rstn       (o_rst_n),
      .i_i2c_start  (start),
      .i_i2c_stop   (stop),
      .i_i2c_wr_byte(wr_data),
      .o_i2c_tx_done(tx_done),
      .o_i2c_ack    (ack),
      .o_i2c_dataval(rd_val),
      .o_i2c_rd_byte(rd_data),
      .i2c_scl      (scl),
      .i2c_sda      (sda)
  );


  //assign sda = sda_en ? wr_data : 1'bz;

  initial begin
    r_clk = 0;
    forever #(CLK_PERIOD / 2) r_clk = ~r_clk;
  end


  initial begin
    #50 o_rst_n = 0;
    #100 o_rst_n = 1;
    start = 0;
    stop = 0;
    wr_data = 0;
    #1000;
    wait (o_rst_n == 1);
    start_con();
    write_byte(8'h50);
    stop_con();
  end

  task write_byte;
    input [7:0] data;
    begin
      wr_data = data;
      //sda_en  = 1;
      start   = 1;
      @(posedge r_clk) start = 0;
      wait (tx_done == 1);
      @(posedge r_clk) $display("transmitted: 0x%h", wr_data);
    end
  endtask

  task start_con;
    begin
      $display("start condition");
      start = 1;
      @(posedge r_clk) start = 0;
      #10000;
    end
  endtask


  task stop_con;
    begin

      $display("stop condition");
      stop = 1;
      @(posedge r_clk) stop = 1;
      #10000;
    end
  endtask

  initial begin
    $dumpfile("sim_output/i2c_tb.vcd");
    $dumpvars(0, i2c_tb);
  end

  initial begin
    #(DURATION);  // Duration for simulation
    $finish;
  end
endmodule

