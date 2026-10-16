# Run from the fitted project directory, with its db/ present:
# quartus_sta -t <absolute>/assert_cdc.tcl radar_unified_bcd <absolute-output-dir>
load_package sta
set project [lindex $quartus(args) 0]
set out [lindex $quartus(args) 1]
if {$project eq "" || $out eq ""} {error "project and output directory required"}
file mkdir $out
project_open $project
create_timing_netlist
read_sdc
update_timing_netlist
set log [open [file join $out cdc_assertions.txt] w]
set failures 0
proc names {collection} {
 set result {}
 foreach_in_collection n $collection {lappend result [get_node_info -name $n]}
 return [lsort -unique $result]
}
proc require_single {collection description} {
 if {[get_collection_size $collection] != 1} {error "$description must resolve to exactly one fitted node: [names $collection]"}
 foreach_in_collection n $collection {return $n}
}
# Derive actual register objects, then inspect endpoint fanout across all
# combinational logic. This deliberately does not use timing-path reporting:
# false_path exceptions must not hide bypass fanout from this assertion.
foreach tuple {{sw7 {*|sw_meta[0]} {*|sw_sync[0]}} {sw6 {*|sw_meta[1]} {*|sw_sync[1]}} {echo {*|echo_meta} {*|echo_sync}}} {
 set port [lindex $tuple 0]
 if {[catch {
  set p [require_single [get_ports $port] "$port input"]
  set first [require_single [get_registers [lindex $tuple 1]] "$port first stage"]
  set second [require_single [get_registers [lindex $tuple 2]] "$port second stage"]
  if {[get_node_info -type $first] ne "reg" || [get_node_info -type $second] ne "reg" || $first eq $second} {error "two distinct registers required"}
  set raw_fanout [names [get_fanouts [get_ports $port]]]
  set first_fanout [names [get_fanouts [get_registers [lindex $tuple 1]]]]
  set n1 [get_node_info -name $first]
  set n2 [get_node_info -name $second]
  puts $log "$port raw_fanout=$raw_fanout"
  puts $log "$port first_stage_fanout=$first_fanout"
  if {$raw_fanout ne [list $n1]} {error "raw input drives endpoint(s) other than its first stage"}
  if {$first_fanout ne [list $n2]} {error "first stage drives endpoint(s) other than its second stage"}
  puts $log "PASS $port: >=2 stages; raw input only stage1; stage1 only stage2"
 } msg]} {incr failures; puts $log "FAIL $port: $msg"}
}
report_ucp -file [file join $out unconstrained.rpt]
puts $log "CDC_FAILURES=$failures"
close $log
delete_timing_netlist
project_close
if {$failures} {error "CDC assertion failed ($failures); see $out/cdc_assertions.txt"}
puts "PASS all 3 fitted-netlist CDC assertions"
