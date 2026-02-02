# Define a procedure (function)
# It will compile all the .sv, .v, and .vhd files in a directory.
# top is the name of the top level module in the design
proc compile {top src_dir output_dir device} {
    puts "Closing any designs that are currently open..."
    puts ""
    close_project -quiet
    puts "Continuing..."
    
    # Change to source directory
    set original_dir [pwd]
    
    # IP
    set_part $device
    
    #read_ip ip/ila_0/ila_0.xci
    #upgrade_ip [get_ips]
    #generate_target all [get_ips]
    # synthesize if already not synthesized
    #synth_ip [get_ips]

    link_design -part $device
    cd $src_dir
    


    # Compile any .sv, .v, and .vhd files that exist in the current directory
    if {[glob -nocomplain *.sv] != ""} {
        puts "Reading SV files..."
        read_verilog -sv [glob *.sv]
    }
    if {[glob -nocomplain *.v] != ""} {
        puts "Reading Verilog files..."
        read_verilog [glob *.v]
    }
    if {[glob -nocomplain *.vhd] != ""} {
        puts "Reading VHDL files..."
        read_vhdl [glob *.vhd]
    }

    puts "Reading constraints..."
    
    # Check for constraints file
    if {[file exists pins.xdc]} {
        read_xdc pins.xdc
    } else {
        puts "Warning: pins.xdc not found"
    }

    cd $original_dir
    # Change to output directory for all output files

    puts "Synthesizing design..."
    synth_design -top $top -flatten_hierarchy full 

    cd $output_dir


    # Configuration voltage settings
    set_property CFGBVS VCCO [current_design]
    set_property CONFIG_VOLTAGE 3.3 [current_design]

    puts "Optimizing design..."
    opt_design

    puts "Placing Design..."
    place_design
    
    puts "Routing Design..."
    route_design


    # puts "Setting up debug cores..."
    # set debug_file "${top}_debug_nets.ltx"
    # write_debug_probes -force $debug_file 

    puts "Writing checkpoint"
    write_checkpoint -force $top.dcp

    puts "Writing bitstream"
    write_bitstream -force $top.bit
    
    puts "All done..."

    cd $original_dir


    # Comprehensive resource reporting
    puts "\n=================== DETAILED RESOURCE REPORT ==================="

    # Basic utilization
    report_utilization -file "${output_dir}/${top}_post_route_util.rpt"

    # Hierarchical utilization
    report_utilization -hierarchical -hierarchical_depth 5 -file "${output_dir}/${top}_hierarchical_util.rpt"

    # Per-IP utilization
    #if {[llength [get_ips]] > 0} {
        #report_utilization -cells [get_ips] -file "${output_dir}/${top}_ip_util.rpt"
    #}

    # Power estimation
    report_power -file "${output_dir}/${top}_power_estimation.rpt"

    # Timing summary
    report_timing_summary -file "${output_dir}/${top}_timing_summary.rpt"

    # Console output
    puts "exported resource utlization to ${output_dir}"
    puts "===============================================================\n"



}

if {$argc == 4} {
    set top_module [lindex $argv 0]
    set source_dir [lindex $argv 1]
    set output_dir [lindex $argv 2]
    set device     [lindex $argv 3]
    
    # Create output directory if it doesn't exist
    if {![file exists $output_dir]} {
        file mkdir $output_dir
    }
    
    compile $top_module $source_dir $output_dir $device
} else {
    puts "arg error"
    exit 1
}
