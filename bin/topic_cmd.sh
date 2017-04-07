#!/usr/bin/expect -f

set timeout 2
set ip your_ip
set password your_password
set topic [lindex $argv 0]
set cmd "sh /home/username/topic_admin.sh ${topic}"
if { $argc == 3 } {  
	set replica [lindex $argv 1] 
    set partition [lindex $argv 2] 
	set cmd "sh /home/username/topic_admin.sh ${topic} ${replica} ${partition}"
}

spawn ssh zm@$ip
expect {
		"*yes/no" { send "yes\r"; exp_continue}
		"*password:" { send "$password\r" }
}
expect "\[*\]\$*"
send "${cmd}\r"
if { $argc == 3 } { 
	expect "*PartitionCount*"
}
expect "ok"
send  "exit\r"
expect eof