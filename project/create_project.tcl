# ============================================
# CLEAN TCL RECREATE PROJECT FOR SDR (ADI + ZU2EG)
# ============================================

set proj_name "sdr"
set proj_dir  [file normalize "./sdr_project_out"]

# 1. Create empty project
create_project $proj_name $proj_dir -part xczu2eg-sfvc784-1-e -force

# Force Vivado into real project-mode
close_project
open_project "$proj_dir/$proj_name.xpr"


# 2. Add ADI HDL IP library
if {[file exists "../library"]} {
    puts "Using ADI IP repo at ../library"
    set_property ip_repo_paths [file normalize "../library"] [current_project]
    update_ip_catalog
}


# 3. Recreate Block Design
puts "\nLoading Block Design..."
source ./system_bd.tcl

save_bd_design


# 4. Generate IP cores
puts "\nGenerating IP targets..."

foreach ip [get_ips] {
    puts "Generating: $ip"
    catch { generate_target all $ip } result
    if {[string match "*ERROR*" $result]} {
        puts "WARNING: nested IP skipped: $result"
    }
}


# 5. Generate wrapper
puts "\nGenerating wrapper..."

set bd_file "$proj_dir/$proj_name.srcs/sources_1/bd/system/system.bd"
set bd_file [file normalize $bd_file]

if {![file exists $bd_file]} {
    puts "ERROR: Block design not found at: $bd_file"
} else {
    open_bd_design $bd_file
    make_wrapper -files [get_files $bd_file] -top
}


# Auto-detect wrapper file
set wrapper_file [glob -nocomplain "$proj_dir/$proj_name.gen/sources_1/bd/system/hdl/*wrapper*.v"]
if {$wrapper_file ne ""} {
    add_files $wrapper_file
    puts "Wrapper added: $wrapper_file"
} else {
    puts "ERROR: Wrapper file not found!"
}


# 6. Add RTL
add_files ./system_top.v


# 7. Add constraints
add_files -fileset constrs_1 ./system_constr.xdc


# 8. ROM init (optional)
if {[file exists "./mem_init_sys.txt"]} {
    add_files ./mem_init_sys.txt
}


# 9. Save project (guaranteed)
puts "\nSaving project..."

if {[catch {save_project} err]} {
    puts "save_project failed: $err"
    save_project_as $proj_name $proj_dir
}


puts "\n============================================"
puts " Vivado project recreated successfully!"
puts " Output directory: $proj_dir"
puts "============================================\n"

close_project

