# Coloured Image Processing
This repository contains Verilog modules for various image processing operations such as brightness adjustment, inversion, red/green/blue filtering, embossing, sharpness, and Sobel edge detection.

## Project Structure
parameter.v: Contains parameter definitions for image dimensions, input file paths, delays, and processing values.
image_read.v: Handles reading the image data from an input file and initiates image processing.
image_write.v: Handles writing the processed image data to an output BMP file.

# Features
Brightness Adjustment: Add or subtract a value to/from the pixel values.
Invert Colors: Inverts the color of each pixel.
Color Filtering: Isolates red, green, or blue components of the image.
Emboss Effect: Applies an emboss effect to the image.
Sharpness: Enhances the sharpness of the image.
Sobel Edge Detection: Detects edges using the Sobel operator.

# Other Parameters
WIDTH: Image width (default: 768)
HEIGHT: Image height (default: 512)
START_UP_DELAY: Delay during startup (default: 100)
HSYNC_DELAY: Delay between HSYNC pulses (default: 160)
VALUE: Value for brightness adjustment (default: 50)
THRESHOLD: Threshold value for threshold operation (default: 90)
SIGN: Operation type for brightness (0: subtraction, 1: addition)

# Usage
Open the parameter.v file.
Uncomment the desired image processing operation  from the corresponding define directive.
Use Vivado to simulate the code along with the provided testbench.
Execute the simulation for 6 milliseconds.
Check the output in the .sim folder to verify the results.
