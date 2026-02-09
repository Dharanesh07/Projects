`timescale 1ns / 1ps

module top_tb ();

  parameter DURATION = 10000000;
  parameter CLK_PERIOD = 20;  // 20ns = 50MHz
  parameter SLAVE_ADDR = 7'h68;  // Slave address
  reg r_clk;
  wire scl;
  wire sda;
  reg [3:0] bit_cnt;
  reg ack_drive;

  initial begin
    r_clk = 0;
    bit_cnt = 0;
    ack_drive = 1;
    forever #(CLK_PERIOD / 2) r_clk = ~r_clk;
  end

  wire rstn;
  top inst_top (
      .sys_clk(r_clk),
      .i2c_sda(sda),
      .i2c_scl(scl)
  );

  wire reg_write;
  wire [7:0] reg_addr;

  wire reg_wdata;
  wire reg_rdata;

  reg [1:0] tb_state;
  localparam START = 0;
  localparam ACK = 1;

  always @(posedge scl) begin

    case (tb_state)

      START: begin
        ack_drive <= 1'b0;  // drive SDA low
        bit_cnt   <= bit_cnt + 1;
        if (bit_cnt == 8) begin
          ack_drive <= 1'b1;  // release SDA
          tb_state  <= ACK;
        end
      end

      ACK: begin
        ack_drive <= 1'b0;
        bit_cnt   <= 0;
        tb_state  <= START;
      end

      default: begin
        tb_state <= START;
      end
    endcase
    // Prepare ACK before 9th rising edge
  end

  assign sda = ack_drive ? 1'b0 : 1'bz;

  initial begin
    $dumpfile("sim_output/top_tb.vcd");
    $dumpvars(0, top_tb);
  end
  initial begin
    #(DURATION);  // Duration for simulation
    $finish;
  end


  `define DEBUG 







endmodule



