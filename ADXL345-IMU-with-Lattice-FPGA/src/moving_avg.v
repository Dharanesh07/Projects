module recursive_moving_average #(
    parameter WINDOW_SIZE = 8,
    parameter DATA_WIDTH  = 16
) (
    input wire clk,
    input wire i_rstn,
    input wire [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out
);

  // Memory for oldest sample
  reg [DATA_WIDTH-1:0] oldest_sample;

  // Accumulator with extra bits
  reg [DATA_WIDTH+$clog2(WINDOW_SIZE)-1:0] accumulator;

  // Counter for initialization
  reg [$clog2(WINDOW_SIZE):0] init_counter;
  wire initialized = init_counter == WINDOW_SIZE;

  // Average calculation
  reg [DATA_WIDTH-1:0] average;

  always @(posedge clk ) begin
    if (!i_rstn) begin
      accumulator <= 0;
      oldest_sample <= 0;
      init_counter <= 0;
      average <= 0;
    end else begin
      if (!initialized) begin
        // Initial filling phase
        accumulator  <= accumulator + data_in;
        init_counter <= init_counter + 1;

        if (init_counter == WINDOW_SIZE - 1) oldest_sample <= data_in;
      end else begin
        // Normal operation
        accumulator   <= accumulator - oldest_sample + data_in;
        oldest_sample <= data_in;
      end

      // Calculate average (registered output)
      if (initialized) average <= accumulator / WINDOW_SIZE;
    end
  end

  assign data_out = average;

endmodule
