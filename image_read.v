`include "parameter.v"
module image_read
#(
  parameter WIDTH 	= 768, 
			HEIGHT 	= 512, 						
			INFILE  = "input.hex", 				// image file
			START_UP_DELAY = 100, 				// Delay during start up time
			HSYNC_DELAY = 160,					// Delay between HSYNC pulses	
			VALUE= 50,								// value for Brightness operation
			THRESHOLD= 90,							// Threshold value for Threshold operation
			SIGN=	1							// SIGN = 0: Brightness subtraction
														// SIGN = 1: Brightness addition
)
(
	input HCLK,														
	input HRESETn,
	output VSYNC,
	output reg HSYNC,
    output reg [7:0]  DATA_R0,//even
    output reg [7:0]  DATA_G0,
    output reg [7:0]  DATA_B0,
    output reg [7:0]  DATA_R1,//odd
    output reg [7:0]  DATA_G1,
    output reg [7:0]  DATA_B1,
	output	ctrl_done
);
parameter sizeOfWidth = 8;
parameter sizeOfLengthReal = 1179648; 		// image data : 1179648 bytes: 512 * 768 *3 
//FSM
localparam		ST_IDLE 	= 2'b00,		// idle state
				ST_VSYNC	= 2'b01,			// state for creating vsync 
				ST_HSYNC	= 2'b10,			// state for creating hsync 
				ST_DATA		= 2'b11;		// state for data processing 
reg [1:0] cstate,
		  nstate;	
reg start;
reg HRESETn_d;
reg 		ctrl_vsync_run;  
reg [8:0]	ctrl_vsync_cnt;
reg 		ctrl_hsync_run;
reg [8:0]	ctrl_hsync_cnt;
reg 		ctrl_data_run;
reg [31 : 0]  in_memory    [0 : sizeOfLengthReal/4];
reg [7 : 0]   total_memory [0 : sizeOfLengthReal-1];
integer temp_BMP   [0 : WIDTH*HEIGHT*3 - 1];			
integer org_R  [0 : WIDTH*HEIGHT - 1];
integer org_G  [0 : WIDTH*HEIGHT - 1];
integer org_B  [0 : WIDTH*HEIGHT - 1];
integer i, j;
    integer gx_r, gx_g, gx_b;
    integer gy_r, gy_g, gy_b;
    integer abs_gx_r, abs_gy_r;
    integer abs_gx_g, abs_gy_g;
    integer abs_gx_b, abs_gy_b;
    integer threshold = 128;// for sobel-edge detection
    integer sum_R0, sum_G0, sum_B0;//for sharpness
    integer sum_R1, sum_G1, sum_B1;
    integer blur_R0, blur_G0, blur_B0;
    integer blur_R1, blur_G1, blur_B1;
    integer sharp_R0, sharp_G0, sharp_B0;
    integer sharp_R1, sharp_G1, sharp_B1;
    integer count;
integer tempR0,tempR1,tempG0,tempG1,tempB0,tempB1;

integer value,value1,value2,value4;
reg [ 9:0] row; 
reg [10:0] col;
reg [18:0] data_count;

//------------------------------ Reading data from input file --------------------------------

initial begin
    $readmemh(INFILE,total_memory,0,sizeOfLengthReal-1);
end
always@(start) begin
    if(start == 1'b1) begin
        for(i=0; i<WIDTH*HEIGHT*3 ; i=i+1) begin
            temp_BMP[i] = total_memory[i+0][7:0]; 
        end
        for(i=0; i<HEIGHT; i=i+1) begin
            for(j=0; j<WIDTH; j=j+1) begin
                org_R[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+0]; 
                org_G[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+1];
                org_B[WIDTH*i+j] = temp_BMP[WIDTH*3*(HEIGHT-i-1)+3*j+2];
            end
        end
    end
end
always@(posedge HCLK, negedge HRESETn)
begin
    if(!HRESETn) begin
        start <= 0;
		HRESETn_d <= 0;
    end
    else begin 				
        HRESETn_d <= HRESETn;
		if(HRESETn == 1'b1 && HRESETn_d == 1'b0)
			start <= 1'b1;
		else
			start <= 1'b0;
    end
end
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        cstate <= ST_IDLE;
    end
    else begin
        cstate <= nstate;
    end
end
always @(*) begin
	case(cstate)
		ST_IDLE: begin
			if(start)
				nstate = ST_VSYNC;
			else
				nstate = ST_IDLE;
		end			
		ST_VSYNC: begin
			if(ctrl_vsync_cnt == START_UP_DELAY) 
				nstate = ST_HSYNC;
			else
				nstate = ST_VSYNC;
		end
		ST_HSYNC: begin
			if(ctrl_hsync_cnt == HSYNC_DELAY) 
				nstate = ST_DATA;
			else
				nstate = ST_HSYNC;
		end		
		ST_DATA: begin
			if(ctrl_done)
				nstate = ST_IDLE;
			else begin
				if(col == WIDTH - 2)
					nstate = ST_HSYNC;
				else
					nstate = ST_DATA;
			end
		end
	endcase
end
always @(*) begin
	ctrl_vsync_run = 0;
	ctrl_hsync_run = 0;
	ctrl_data_run  = 0;
	case(cstate)
		ST_VSYNC: 	begin ctrl_vsync_run = 1; end
		ST_HSYNC: 	begin ctrl_hsync_run = 1; end
		ST_DATA: 	begin ctrl_data_run  = 1; end
	endcase
end
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        ctrl_vsync_cnt <= 0;
		ctrl_hsync_cnt <= 0;
    end
    else begin
        if(ctrl_vsync_run)
			ctrl_vsync_cnt <= ctrl_vsync_cnt + 1;
		else 
			ctrl_vsync_cnt <= 0;
			
        if(ctrl_hsync_run)
			ctrl_hsync_cnt <= ctrl_hsync_cnt + 1;		
		else
			ctrl_hsync_cnt <= 0;
    end
end
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        row <= 0;
		col <= 0;
    end
	else begin
		if(ctrl_data_run) begin
			if(col == WIDTH - 2) begin
				row <= row + 1;
			end
			if(col == WIDTH - 2) 
				col <= 0;
			else 
				col <= col + 2;
		end
	end
end
always@(posedge HCLK, negedge HRESETn)
begin
    if(~HRESETn) begin
        data_count <= 0;
    end
    else begin
        if(ctrl_data_run)
			data_count <= data_count + 1;
    end
end
assign VSYNC = ctrl_vsync_run;
assign ctrl_done = (data_count == 196607)? 1'b1: 1'b0;

//-----------------------------------Image processing-----------------------------------------

always @(*) begin
	HSYNC   = 1'b0;
	DATA_R0 = 0;
	DATA_G0 = 0;
	DATA_B0 = 0;                                       
	DATA_R1 = 0;
	DATA_G1 = 0;
	DATA_B1 = 0;                                         
	if(ctrl_data_run) begin
		HSYNC   = 1'b1;
		`ifdef BRIGHTNESS_OPERATION
		/**************************************/		
		/*		BRIGHTNESS ADDITION OPERATION */
		/**************************************/
		if(SIGN == 1) begin
		tempR0 = org_R[WIDTH * row + col   ] + VALUE;
		if (tempR0 > 255)
			DATA_R0 = 255;
		else
			DATA_R0 = org_R[WIDTH * row + col   ] + VALUE;
		tempR1 = org_R[WIDTH * row + col+1   ] + VALUE;
		if (tempR1 > 255)
			DATA_R1 = 255;
		else
			DATA_R1 = org_R[WIDTH * row + col+1   ] + VALUE;	
		tempG0 = org_G[WIDTH * row + col   ] + VALUE;
		if (tempG0 > 255)
			DATA_G0 = 255;
		else
			DATA_G0 = org_G[WIDTH * row + col   ] + VALUE;
		tempG1 = org_G[WIDTH * row + col+1   ] + VALUE;
		if (tempG1 > 255)
			DATA_G1 = 255;
		else
			DATA_G1 = org_G[WIDTH * row + col+1   ] + VALUE;		
		tempB0 = org_B[WIDTH * row + col   ] + VALUE;
		if (tempB0 > 255)
			DATA_B0 = 255;
		else
			DATA_B0 = org_B[WIDTH * row + col   ] + VALUE;
		tempB1 = org_B[WIDTH * row + col+1   ] + VALUE;
		if (tempB1 > 255)
			DATA_B1 = 255;
		else
			DATA_B1 = org_B[WIDTH * row + col+1   ] + VALUE;
	end
	
	else begin
	/**************************************/		
	/*	BRIGHTNESS SUBTRACTION OPERATION */
	/**************************************/
		tempR0 = org_R[WIDTH * row + col   ] - VALUE;
		if (tempR0 < 0)
			DATA_R0 = 0;
		else
			DATA_R0 = org_R[WIDTH * row + col   ] - VALUE;	
		tempR1 = org_R[WIDTH * row + col+1   ] - VALUE;
		if (tempR1 < 0)
			DATA_R1 = 0;
		else
			DATA_R1 = org_R[WIDTH * row + col+1   ] - VALUE;	
		tempG0 = org_G[WIDTH * row + col   ] - VALUE;
		if (tempG0 < 0)
			DATA_G0 = 0;
		else
			DATA_G0 = org_G[WIDTH * row + col   ] - VALUE;
		tempG1 = org_G[WIDTH * row + col+1   ] - VALUE;
		if (tempG1 < 0)
			DATA_G1 = 0;
		else
			DATA_G1 = org_G[WIDTH * row + col+1   ] - VALUE;		
		tempB0 = org_B[WIDTH * row + col   ] - VALUE;
		if (tempB0 < 0)
			DATA_B0 = 0;
		else
			DATA_B0 = org_B[WIDTH * row + col   ] - VALUE;
		tempB1 = org_B[WIDTH * row + col+1   ] - VALUE;
		if (tempB1 < 0)
			DATA_B1 = 0;
		else
			DATA_B1 = org_B[WIDTH * row + col+1   ] - VALUE;
	 end
		`endif
	
		/**************************************/		
		/*		INVERT_OPERATION  			  */
		/**************************************/
		`ifdef INVERT_OPERATION	
			DATA_R0=255-org_R[WIDTH * row + col  ];
			DATA_G0=255-org_G[WIDTH * row + col  ];
			DATA_B0=255-org_B[WIDTH * row + col  ];
			DATA_R1=255-org_R[WIDTH * row + col+1  ];
			DATA_G1=255-org_G[WIDTH * row + col+1  ];
			DATA_B1=255-org_B[WIDTH * row + col+1  ];		
		`endif
		
			/**************************************/		
		    /*		RED_FILTER_OPERATION  	      */
		    /**************************************/
		`ifdef RED_FILTER_OPERATION
    DATA_R0 = org_R[WIDTH * row + col];
    DATA_G0 = 0;
    DATA_B0 = 0;
    DATA_R1 = org_R[WIDTH * row + col + 1];
    DATA_G1 = 0;
    DATA_B1 = 0;
    `endif	
    
		/**************************************/		
		/*		GREEN_FILTER_OPERATION  	  */
		/**************************************/
		`ifdef GREEN_FILTER_OPERATION
    DATA_R0 = 0;
    DATA_G0 = org_G[WIDTH * row + col];
    DATA_B0 = 0;
    DATA_R1 = 0;
    DATA_G1 = org_G[WIDTH * row + col + 1];
    DATA_B1 = 0;
    `endif

		/**************************************/		
		/*		BLUE_FILTER_OPERATION  	      */
		/**************************************/
        `ifdef BLUE_FILTER_OPERATION
    DATA_R0 = 0;
    DATA_G0 = 0;
    DATA_B0 = org_B[WIDTH * row + col];
    DATA_R1 = 0;
    DATA_G1 = 0;
    DATA_B1 = org_B[WIDTH * row + col + 1];
    `endif
    
        `ifdef EMBOSS_OPERATION
        /**************************************/		
		/*		EMBOSS_OPERATION     	      */
		/**************************************/
    DATA_R0 = (org_R[WIDTH * row + col] - org_R[WIDTH * (row + 1) + col + 1]) + 128;
    DATA_G0 = (org_G[WIDTH * row + col] - org_G[WIDTH * (row + 1) + col + 1]) + 128;
    DATA_B0 = (org_B[WIDTH * row + col] - org_B[WIDTH * (row + 1) + col + 1]) + 128;
    DATA_R1 = (org_R[WIDTH * row + col + 1] - org_R[WIDTH * (row + 1) + col + 2]) + 128;
    DATA_G1 = (org_G[WIDTH * row + col + 1] - org_G[WIDTH * (row + 1) + col + 2]) + 128;
    DATA_B1 = (org_B[WIDTH * row + col + 1] - org_B[WIDTH * (row + 1) + col + 2]) + 128;
    `endif
    
        `ifdef SHARPNESS_OPERATION
        	/**************************************/		
		    /*		SHARPNESS_OPERATION  	      */
		    /**************************************/
    blur_R0 = (org_R[WIDTH * (row - 1) + col - 1] + org_R[WIDTH * (row - 1) + col] + org_R[WIDTH * (row - 1) + col + 1] +
               org_R[WIDTH * row + col - 1] + org_R[WIDTH * row + col] + org_R[WIDTH * row + col + 1] +
               org_R[WIDTH * (row + 1) + col - 1] + org_R[WIDTH * (row + 1) + col] + org_R[WIDTH * (row + 1) + col + 1]) / 9;
    blur_G0 = (org_G[WIDTH * (row - 1) + col - 1] + org_G[WIDTH * (row - 1) + col] + org_G[WIDTH * (row - 1) + col + 1] +
               org_G[WIDTH * row + col - 1] + org_G[WIDTH * row + col] + org_G[WIDTH * row + col + 1] +
               org_G[WIDTH * (row + 1) + col - 1] + org_G[WIDTH * (row + 1) + col] + org_G[WIDTH * (row + 1) + col + 1]) / 9;
    blur_B0 = (org_B[WIDTH * (row - 1) + col - 1] + org_B[WIDTH * (row - 1) + col] + org_B[WIDTH * (row - 1) + col + 1] +
               org_B[WIDTH * row + col - 1] + org_B[WIDTH * row + col] + org_B[WIDTH * row + col + 1] +
               org_B[WIDTH * (row + 1) + col - 1] + org_B[WIDTH * (row + 1) + col] + org_B[WIDTH * (row + 1) + col + 1]) / 9;
    sharp_R0 = 2 * org_R[WIDTH * row + col] - blur_R0;
    sharp_G0 = 2 * org_G[WIDTH * row + col] - blur_G0;
    sharp_B0 = 2 * org_B[WIDTH * row + col] - blur_B0;
    DATA_R0 = (sharp_R0 < 0) ? 0 : (sharp_R0 > 255) ? 255 : sharp_R0;
    DATA_G0 = (sharp_G0 < 0) ? 0 : (sharp_G0 > 255) ? 255 : sharp_G0;
    DATA_B0 = (sharp_B0 < 0) ? 0 : (sharp_B0 > 255) ? 255 : sharp_B0;
    blur_R1 = (org_R[WIDTH * (row - 1) + col] + org_R[WIDTH * (row - 1) + col + 1] + org_R[WIDTH * (row - 1) + col + 2] +
               org_R[WIDTH * row + col] + org_R[WIDTH * row + col + 1] + org_R[WIDTH * row + col + 2] +
               org_R[WIDTH * (row + 1) + col] + org_R[WIDTH * (row + 1) + col + 1] + org_R[WIDTH * (row + 1) + col + 2]) / 9;
    blur_G1 = (org_G[WIDTH * (row - 1) + col] + org_G[WIDTH * (row - 1) + col + 1] + org_G[WIDTH * (row - 1) + col + 2] +
               org_G[WIDTH * row + col] + org_G[WIDTH * row + col + 1] + org_G[WIDTH * row + col + 2] +
               org_G[WIDTH * (row + 1) + col] + org_G[WIDTH * (row + 1) + col + 1] + org_G[WIDTH * (row + 1) + col + 2]) / 9;
    blur_B1 = (org_B[WIDTH * (row - 1) + col] + org_B[WIDTH * (row - 1) + col + 1] + org_B[WIDTH * (row - 1) + col + 2] +
               org_B[WIDTH * row + col] + org_B[WIDTH * row + col + 1] + org_B[WIDTH * row + col + 2] +
               org_B[WIDTH * (row + 1) + col] + org_B[WIDTH * (row + 1) + col + 1] + org_B[WIDTH * (row + 1) + col + 2]) / 9;
    sharp_R1 = 2 * org_R[WIDTH * row + col + 1] - blur_R1;
    sharp_G1 = 2 * org_G[WIDTH * row + col + 1] - blur_G1;
    sharp_B1 = 2 * org_B[WIDTH * row + col + 1] - blur_B1;
    DATA_R1 = (sharp_R1 < 0) ? 0 : (sharp_R1 > 255) ? 255 : sharp_R1;
    DATA_G1 = (sharp_G1 < 0) ? 0 : (sharp_G1 > 255) ? 255 : sharp_G1;
    DATA_B1 = (sharp_B1 < 0) ? 0 : (sharp_B1 > 255) ? 255 : sharp_B1;
    `endif
    
        `ifdef SOBEL_OPERATION
        /**************************************/		
		/*		SOBEL_EDGE_DETECTION  	      */
		/**************************************/
    gx_r = (org_R[WIDTH * (row - 1) + col + 1] + 2 * org_R[WIDTH * row + col + 1] + org_R[WIDTH * (row + 1) + col + 1]) -
           (org_R[WIDTH * (row - 1) + col - 1] + 2 * org_R[WIDTH * row + col - 1] + org_R[WIDTH * (row + 1) + col - 1]);
    gy_r = (org_R[WIDTH * (row + 1) + col - 1] + 2 * org_R[WIDTH * (row + 1) + col] + org_R[WIDTH * (row + 1) + col + 1]) -
           (org_R[WIDTH * (row - 1) + col - 1] + 2 * org_R[WIDTH * (row - 1) + col] + org_R[WIDTH * (row - 1) + col + 1]);
    abs_gx_r = (gx_r < 0) ? -gx_r : gx_r;
    abs_gy_r = (gy_r < 0) ? -gy_r : gy_r;
    gx_g = (org_G[WIDTH * (row - 1) + col + 1] + 2 * org_G[WIDTH * row + col + 1] + org_G[WIDTH * (row + 1) + col + 1]) -
           (org_G[WIDTH * (row - 1) + col - 1] + 2 * org_G[WIDTH * row + col - 1] + org_G[WIDTH * (row + 1) + col - 1]);
    gy_g = (org_G[WIDTH * (row + 1) + col - 1] + 2 * org_G[WIDTH * (row + 1) + col] + org_G[WIDTH * (row + 1) + col + 1]) -
           (org_G[WIDTH * (row - 1) + col - 1] + 2 * org_G[WIDTH * (row - 1) + col] + org_G[WIDTH * (row - 1) + col + 1]);
    abs_gx_g = (gx_g < 0) ? -gx_g : gx_g;
    abs_gy_g = (gy_g < 0) ? -gy_g : gy_g;
    gx_b = (org_B[WIDTH * (row - 1) + col + 1] + 2 * org_B[WIDTH * row + col + 1] + org_B[WIDTH * (row + 1) + col + 1]) -
           (org_B[WIDTH * (row - 1) + col - 1] + 2 * org_B[WIDTH * row + col - 1] + org_B[WIDTH * (row + 1) + col - 1]);
    gy_b = (org_B[WIDTH * (row + 1) + col - 1] + 2 * org_B[WIDTH * (row + 1) + col] + org_B[WIDTH * (row + 1) + col + 1]) -
           (org_B[WIDTH * (row - 1) + col - 1] + 2 * org_B[WIDTH * (row - 1) + col] + org_B[WIDTH * (row - 1) + col + 1]);
    abs_gx_b = (gx_b < 0) ? -gx_b : gx_b;
    abs_gy_b = (gy_b < 0) ? -gy_b : gy_b;
    if ((abs_gx_r + abs_gy_r > threshold) || (abs_gx_g + abs_gy_g > threshold) || (abs_gx_b + abs_gy_b > threshold)) begin
        DATA_R0 = 255;
        DATA_G0 = 255;
        DATA_B0 = 255;
    end else begin
        DATA_R0 = 0;
        DATA_G0 = 0;
        DATA_B0 = 0;
    end
    gx_r = (org_R[WIDTH * (row - 1) + col + 2] + 2 * org_R[WIDTH * row + col + 2] + org_R[WIDTH * (row + 1) + col + 2]) -
           (org_R[WIDTH * (row - 1) + col] + 2 * org_R[WIDTH * row + col] + org_R[WIDTH * (row + 1) + col]);
    gy_r = (org_R[WIDTH * (row + 1) + col] + 2 * org_R[WIDTH * (row + 1) + col + 1] + org_R[WIDTH * (row + 1) + col + 2]) -
           (org_R[WIDTH * (row - 1) + col] + 2 * org_R[WIDTH * (row - 1) + col + 1] + org_R[WIDTH * (row - 1) + col + 2]);
    abs_gx_r = (gx_r < 0) ? -gx_r : gx_r;
    abs_gy_r = (gy_r < 0) ? -gy_r : gy_r;
    gx_g = (org_G[WIDTH * (row - 1) + col + 2] + 2 * org_G[WIDTH * row + col + 2] + org_G[WIDTH * (row + 1) + col + 2]) -
           (org_G[WIDTH * (row - 1) + col] + 2 * org_G[WIDTH * row + col] + org_G[WIDTH * (row + 1) + col]);
    gy_g = (org_G[WIDTH * (row + 1) + col] + 2 * org_G[WIDTH * (row + 1) + col + 1] + org_G[WIDTH * (row + 1) + col + 2]) -
           (org_G[WIDTH * (row - 1) + col] + 2 * org_G[WIDTH * (row - 1) + col + 1] + org_G[WIDTH * (row - 1) + col + 2]);
    abs_gx_g = (gx_g < 0) ? -gx_g : gx_g;
    abs_gy_g = (gy_g < 0) ? -gy_g : gy_g;
    gx_b = (org_B[WIDTH * (row - 1) + col + 2] + 2 * org_B[WIDTH * row + col + 2] + org_B[WIDTH * (row + 1) + col + 2]) -
           (org_B[WIDTH * (row - 1) + col] + 2 * org_B[WIDTH * row + col] + org_B[WIDTH * (row + 1) + col]);
    gy_b = (org_B[WIDTH * (row + 1) + col] + 2 * org_B[WIDTH * (row + 1) + col + 1] + org_B[WIDTH * (row + 1) + col + 2]) -
           (org_B[WIDTH * (row - 1) + col] + 2 * org_B[WIDTH * (row - 1) + col + 1] + org_B[WIDTH * (row - 1) + col + 2]);
    abs_gx_b = (gx_b < 0) ? -gx_b : gx_b;
    abs_gy_b = (gy_b < 0) ? -gy_b : gy_b;
    if ((abs_gx_r + abs_gy_r > threshold) || (abs_gx_g + abs_gy_g > threshold) || (abs_gx_b + abs_gy_b > threshold)) begin
        DATA_R1 = 255;
        DATA_G1 = 255;
        DATA_B1 = 255;
    end else begin
        DATA_R1 = 0;
        DATA_G1 = 0;
        DATA_B1 = 0;
    end
    `endif
    
        `ifdef MOTION_BLUR_OPERATION
        /**************************************/		
		/*		MOTION_BLUR_OPERATION  	      */
		/**************************************/
    sum_R0 = org_R[WIDTH * row + col];
    sum_G0 = org_G[WIDTH * row + col];
    sum_B0 = org_B[WIDTH * row + col];
    count = 1;
    if (col > 0) begin
        sum_R0 = sum_R0 + org_R[WIDTH * row + col - 1];
        sum_G0 = sum_G0 + org_G[WIDTH * row + col - 1];
        sum_B0 = sum_B0 + org_B[WIDTH * row + col - 1];
        count = count + 1;
    end
    if (col > 1) begin
        sum_R0 = sum_R0 + org_R[WIDTH * row + col - 2];
        sum_G0 = sum_G0 + org_G[WIDTH * row + col - 2];
        sum_B0 = sum_B0 + org_B[WIDTH * row + col - 2];
        count = count + 1;
    end  
    if (col < WIDTH - 1) begin
        sum_R0 = sum_R0 + org_R[WIDTH * row + col + 1];
        sum_G0 = sum_G0 + org_G[WIDTH * row + col + 1];
        sum_B0 = sum_B0 + org_B[WIDTH * row + col + 1];
        count = count + 1;
    end  
    if (col < WIDTH - 2) begin
        sum_R0 = sum_R0 + org_R[WIDTH * row + col + 2];
        sum_G0 = sum_G0 + org_G[WIDTH * row + col + 2];
        sum_B0 = sum_B0 + org_B[WIDTH * row + col + 2];
        count = count + 1;
    end
    DATA_R0 = sum_R0 / count;
    DATA_G0 = sum_G0 / count;
    DATA_B0 = sum_B0 / count;
    sum_R1 = org_R[WIDTH * row + col + 1];
    sum_G1 = org_G[WIDTH * row + col + 1];
    sum_B1 = org_B[WIDTH * row + col + 1];
    count = 1;    
    if (col + 1 > 0) begin
        sum_R1 = sum_R1 + org_R[WIDTH * row + col];
        sum_G1 = sum_G1 + org_G[WIDTH * row + col];
        sum_B1 = sum_B1 + org_B[WIDTH * row + col];
        count = count + 1;
    end
    if (col + 1 > 1) begin
        sum_R1 = sum_R1 + org_R[WIDTH * row + col - 1];
        sum_G1 = sum_G1 + org_G[WIDTH * row + col - 1];
        sum_B1 = sum_B1 + org_B[WIDTH * row + col - 1];
        count = count + 1;
    end
    if (col + 1 < WIDTH - 1) begin
        sum_R1 = sum_R1 + org_R[WIDTH * row + col + 2];
        sum_G1 = sum_G1 + org_G[WIDTH * row + col + 2];
        sum_B1 = sum_B1 + org_B[WIDTH * row + col + 2];
        count = count + 1;
    end
    if (col + 1 < WIDTH - 2) begin
        sum_R1 = sum_R1 + org_R[WIDTH * row + col + 3];
        sum_G1 = sum_G1 + org_G[WIDTH * row + col + 3];
        sum_B1 = sum_B1 + org_B[WIDTH * row + col + 3];
        count = count + 1;
    end
    DATA_R1 = sum_R1 / count;
    DATA_G1 = sum_G1 / count;
    DATA_B1 = sum_B1 / count;
    `endif
    
		`ifdef BLACKandWHITE_OPERATION	
		/**************************************/		
		/*		BLACK & WHITE_OPERATION  	  */
		/**************************************/
			value2 = (org_B[WIDTH * row + col  ] + org_R[WIDTH * row + col  ] +org_G[WIDTH * row + col  ])/3;
			DATA_R0=value2;
			DATA_G0=value2;
			DATA_B0=value2;
			value4 = (org_B[WIDTH * row + col+1  ] + org_R[WIDTH * row + col+1  ] +org_G[WIDTH * row + col+1  ])/3;
			DATA_R1=value4;
			DATA_G1=value4;
			DATA_B1=value4;		
	`endif
		`ifdef THRESHOLD_OPERATION
		/**************************************/		
		/********THRESHOLD OPERATION  *********/
		/**************************************/
		value = (org_R[WIDTH * row + col   ]+org_G[WIDTH * row + col   ]+org_B[WIDTH * row + col   ])/3;
		if(value > THRESHOLD) begin
			DATA_R0=255;
			DATA_G0=255;
			DATA_B0=255;
		end
		else begin
			DATA_R0=0;
			DATA_G0=0;
			DATA_B0=0;
		end
		value1 = (org_R[WIDTH * row + col+1   ]+org_G[WIDTH * row + col+1   ]+org_B[WIDTH * row + col+1   ])/3;
		if(value1 > THRESHOLD) begin
			DATA_R1=255;
			DATA_G1=255;
			DATA_B1=255;
		end
		else begin
			DATA_R1=0;
			DATA_G1=0;
			DATA_B1=0;
		end		
		`endif
	end
end
endmodule

