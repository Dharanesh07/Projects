`timescale 1ns / 1ps

module top_tb ();

  parameter DURATION = 10000000;
  parameter CLK_PERIOD = 20;  // 20ns = 50MHz
  parameter SLAVE_ADDR = 7'h68;  // Slave address
  reg  r_clk;
  wire scl;
  wire sda;
  reg [3:0] bit_cnt;
  reg ack_drive;

  initial begin
    r_clk = 0;
    bit_cnt = 0;
    ack_drive=0;
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


always @(negedge scl) begin
  bit_cnt <= bit_cnt + 1;

  // Prepare ACK before 9th rising edge
  if (bit_cnt == 7)
    ack_drive <= 1'b1;   // drive SDA low
  else if (bit_cnt == 8) begin
    ack_drive <= 1'b0;   // release SDA
    bit_cnt <= 0;        // ready for next byte
  end
end

assign sda = ack_drive ? 1'b0 : 1'bz;

  
  initial begin
    #(DURATION);  // Duration for simulation
    $finish;
  end
endmodule



