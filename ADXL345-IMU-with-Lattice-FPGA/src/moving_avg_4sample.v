module moving_average_4sample #(
    parameter DATA_WIDTH = 16
) (
    input wire clk,
    input wire i_rstn,
    input wire i_dataval,
    input wire signed [DATA_WIDTH-1:0] data_in,
    output reg signed [DATA_WIDTH-1:0] data_out,
    output reg filtering_completed
);

  // Sample registers
  reg signed [DATA_WIDTH-1:0] sample_reg[3:0];

  // Accumulator - needs to be wider to handle sum of 4 signed numbers
  reg signed [DATA_WIDTH+1:0] accumulator;

  // Initialization counter
  reg [1:0] init_counter;
  wire initialized = (init_counter == 2'b11);

  // State machine
  reg [1:0] state;
  localparam IDLE = 2'b00;
  localparam START = 2'b01;
  localparam PROCESS = 2'b10;
  localparam FINISH = 2'b11;

  integer i;

  always @(posedge clk) begin
    if (!i_rstn) begin
      accumulator <= 0;
      init_counter <= 0;
      data_out <= 0;
      filtering_completed <= 1'b0;
      state <= IDLE;

      for (i = 0; i < 4; i = i + 1) begin
        sample_reg[i] <= 0;
      end

    end else begin
      case (state)
        IDLE: begin
          filtering_completed <= 1'b0;
          if (i_dataval) begin
            state <= START;
          end
        end

        START: begin
          if (!initialized) begin
            // Fill buffer initially
            sample_reg[init_counter] <= data_in;
            accumulator <= accumulator + data_in;
            init_counter <= init_counter + 1;

            if (init_counter == 2'b11) begin
              data_out <= (accumulator + data_in) >>> 2;
              state <= FINISH;
            end else begin
              state <= IDLE;  // Wait for next sample
            end
          end else begin
            state <= PROCESS;
          end
        end

        PROCESS: begin
          // Calculate new accumulator value
          accumulator <= accumulator - sample_reg[3] + data_in;

          // Shift register (move samples)
          for (i = 3; i > 0; i = i - 1) begin
            sample_reg[i] <= sample_reg[i-1];
          end
          sample_reg[0] <= data_in;

          // Output average using the new accumulator value
          data_out <= accumulator /4;
          state <= FINISH;
        end

        FINISH: begin
          filtering_completed <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
