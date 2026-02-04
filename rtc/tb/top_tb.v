`timescale 1ns / 1ps

module top_tb ();

  parameter DURATION = 10000000;
  parameter CLK_PERIOD = 20;  // 20ns = 50MHz
  parameter SLAVE_ADDR = 7'h68;  // Slave address
  reg  r_clk;
  wire scl;
  wire sda;
  reg [3:0] count;
  reg ack;

  initial begin
    r_clk = 0;
    count = 0;
    forever #(CLK_PERIOD / 2) r_clk = ~r_clk;
  end


  top inst_top (
      .sys_clk(r_clk),
      .i2c_sda(sda),
      .i2c_scl(scl)
  );

  initial begin
    $dumpfile("sim_output/top_tb.vcd");
    $dumpvars(0, top_tb);
  end

  
  always @(posedge scl) begin
    count <= count + 1;
    if(count == 8) begin
      ack <= 1'b1;
    end else ack <= 1'b0;
  end
  assign sda = ack ? 1'b1 : 1'bz;
  initial begin
    #(DURATION);  // Duration for simulation
    $finish;
  end
endmodule


