module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 15
) (
    input wire i_clk,
    input wire i_rst,
    input wire i_wren,
    input wire i_rden,
    input wire [WIDTH-1:0] i_datain,
    output reg [WIDTH-1:0] o_dataout,
    output reg full,
    output reg empty,
    output reg overflow,
    output reg underflow
);

  // Internal FIFO memory
  reg [WIDTH-1:0] mem[0:DEPTH-1];
  reg [$clog2(DEPTH)-1:0] wraddr;
  reg [$clog2(DEPTH)-1:0] rdaddr;
  wire nxtaddr;

  initial begin
    wraddr = 1'b0;
    rdaddr = 1'b0;
    full   = 1'b0;
    empty  = 1'b1;
    //o_dataout = 1'b0;
  end


  // Write operation
  always @(posedge i_clk) begin
    if (!i_rst) begin
      wraddr   <= 1'b0;
      overflow <= 1'b0;
    end else if (i_wren) begin
      mem[wraddr] <= i_datain;
      if ((!full) || (i_rden)) begin
        //if ((!full)) begin
        wraddr   <= wraddr + 1'b1;
        overflow <= 1'b0;
      end else overflow <= 1'b1;
    end

  end

  // Read operation
  always @(posedge i_clk) begin
    if (!i_rst) begin
      rdaddr <= 1'b0;
      underflow <= 1'b0;

    end else if (i_rden) begin
      o_dataout <= mem[rdaddr];

      if (!empty) begin
        rdaddr <= rdaddr + 1'b1;
        underflow <= 1'b0;
      end else underflow <= 1'b1;
    end
  end

  //assign nxtaddr = wraddr + 1'b1;
  //assign full = (nxtaddr == rdaddr);
  //assign empty = (wraddr == rdaddr);

  //efficient way to set full/empty flag in one clock cycle
  wire [$clog2(DEPTH)-1:0] dblnext, nxtread;
  assign dblnext = wraddr + 2;
  assign nxtread = rdaddr + 1'b1;
  always @(posedge i_clk) begin
    if (!i_rst) begin
      full  <= 1'b0;
      empty <= 1'b1;
    end else
      casez ({
        i_wren, i_rden, !full, !empty
      })
        4'b01?1: begin  // A successful read
          full  <= 1'b0;
          empty <= (nxtread == wraddr);
        end
        4'b101?: begin  // A successful write
          full  <= (dblnext == rdaddr);
          empty <= 1'b0;
        end
        4'b11?0: begin  // Successful write, failed read
          full  <= 1'b0;
          empty <= 1'b0;
        end
        4'b11?1: begin  // Successful read and write
          full  <= full;
          empty <= 1'b0;
        end
        default: begin
        end
      endcase

  end
endmodule
