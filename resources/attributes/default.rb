#Flags
default["snort"]["registered"] = false

default["redborder"]["snort"]["service"] = "snortd"
default["redborder"]["snort"]["groups"]  = {}

default["redborder"]["enable_remote_repo"]   = false

default["redborder"]["barnyard2"]["service"] = "barnyard2"

default["redborder"]["rsyslog"]["mode"]      = "extended"

default["redborder"]["force-run-once"]       = false
default["redborder"]["chef_client_interval"] = 300

default["redborder"]["ipsrules"]  = {}