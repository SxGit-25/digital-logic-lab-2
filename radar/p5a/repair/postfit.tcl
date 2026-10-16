# quartus_sta -t postfit.tcl PROJECT OUTPUT_DIRECTORY
load_package sta
set project [lindex $quartus(args) 0]
set out [lindex $quartus(args) 1]
file mkdir $out
project_open $project
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 10 -detail full_path -file [file join $out setup10.rpt]
report_timing -hold -npaths 10 -detail full_path -file [file join $out hold10.rpt]
report_ucp -file [file join $out unconstrained.rpt]
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
foreach tuple {{sw7 {*|sw_meta[0]} {*|sw_sync[0]}} {sw6 {*|sw_meta[1]} {*|sw_sync[1]}} {echo {*|echo_meta} {*|echo_sync}}} {
 set port [lindex $tuple 0]
 if {[catch {
  set p [require_single [get_ports $port] "$port input"]
  set first [require_single [get_registers [lindex $tuple 1]] "$port first stage"]
  set second [require_single [get_registers [lindex $tuple 2]] "$port second stage"]
  if {[get_node_info -type $first] ne "reg" || [get_node_info -type $second] ne "reg" || $first eq $second} {error "two distinct registers required"}
  set raw_fanout [names [get_fanouts [get_ports $port]]]
  set first_fanout [names [get_fanouts [get_registers [lindex $tuple 1]]]]
  puts $log "$port raw_fanout=$raw_fanout"
  puts $log "$port first_stage_fanout=$first_fanout"
  if {$raw_fanout ne [list [get_node_info -name $first]]} {error "raw input drives endpoint(s) other than its first stage"}
  if {$first_fanout ne [list [get_node_info -name $second]]} {error "first stage drives endpoint(s) other than its second stage"}
  puts $log "PASS $port: >=2 stages; raw input only stage1; stage1 only stage2"
 } msg]} {incr failures; puts $log "FAIL $port: $msg"}
}
puts $log "CDC_FAILURES=$failures"
close $log
delete_timing_netlist
project_close
if {$failures} {error "CDC assertion failed ($failures); evidence is retained"}
