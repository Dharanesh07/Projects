module gesture_recognition #(
    parameter WIDTH = 16
) (
    input wire clk,
    input wire r_rstn,
    input wire signed [WIDTH-1:0] x_axis_datain,
    input wire signed [WIDTH-1:0] y_axis_datain,
    input wire signed [WIDTH-1:0] z_axis_datain,
    output reg [7:0] gesture_data
);

  // Threshold parameters - adjust these based on your requirements

  parameter signed POS_X_NITRO = 150;  // nitro 
  parameter signed POS_X_THRESH = 80;  // Forward movement 
  parameter signed NEG_X_THRESH = -80;  // Reverse movement 
  parameter signed POS_Y_THRESH = 80;  // Right  
  parameter signed NEG_Y_THRESH = -80;  // Left 
  parameter signed POS_Z_THRESH = 50;  // Positive Z threshold
  parameter signed NEG_Z_THRESH = -50;  // Negative Z threshold

  parameter ASCII_f = 8'h66;
  parameter ASCII_b = 8'h62;
  parameter ASCII_r = 8'h72;
  parameter ASCII_l = 8'h6C;
  parameter ASCII_n = 8'h6E;
  parameter DEFAULT_ASCII = 8'h3B;

  /*
  // Direction indicators (can map to LEDs or other outputs)
  reg x_pos_detected, x_neg_detected;
  reg y_pos_detected, y_neg_detected;
  reg z_pos_detected, z_neg_detected;
  reg x_nitro_detected;

  assign gesture_data = {
    1'b0,
    x_nitro_detected,
    z_neg_detected,
    z_pos_detected,
    y_neg_detected,
    y_pos_detected,
    x_neg_detected,
    x_pos_detected
  };
*/

  // Movement detection with direction sensing
  always @(posedge clk) begin
    if (!r_rstn) begin
      gesture_data <= 0;
      /*
      x_nitro_detected <= 1'b0;
      x_pos_detected <= 1'b0;
      x_neg_detected <= 1'b0;
      y_pos_detected <= 1'b0;
      y_neg_detected <= 1'b0;
      z_pos_detected <= 1'b0;
      z_neg_detected <= 1'b0;
        */
    end else begin



      if (x_axis_datain > POS_X_NITRO) gesture_data <= ASCII_n;
      else if (x_axis_datain > POS_X_THRESH) gesture_data <= ASCII_f;
      else if (x_axis_datain < NEG_X_THRESH) gesture_data <= ASCII_b;
      else if (y_axis_datain > POS_Y_THRESH) gesture_data <= ASCII_r;
      else if (y_axis_datain < NEG_Y_THRESH) gesture_data <= ASCII_l;
      else gesture_data <= DEFAULT_ASCII;

      // Z-axis detection (account for gravity)
      //z_pos_detected <= (z_axis_datain > (16'sd256 + POS_Z_THRESH)) ? 1'b1 : 1'b0;
      //z_neg_detected <= (z_axis_datain < (16'sd256 + NEG_Z_THRESH)) ? 1'b1 : 1'b0;
    end
  end
endmodule
