# checkconfig_lua
CA UIM Checkconfig LUA for NAS 

**Note:** Sorry all codes comment are in french 

# Configuration

Change all variables at the start of the script 

```lua
-------------------------------------------------------
-- Database information
-------------------------------------------------------
local dbname = 'checkconfig.db';

-------------------------------------------------------
-- Variable to log or not
-------------------------------------------------------
local debug = false;
local echo = false;

-- Path for the log file.
local logpath = "E:\\Program Files (x86)\\Nimsoft\\probes\\service\\nas\\scripts\\EXT-Conf\\ext-configuration.log";

-------------------------------------------------------
-- List of hubs we want to exclude 
-------------------------------------------------------
local exclude_hubs = {
    CA_UIM_PARKING = true,
    CA_UIM_NT4_W2000 = true,
    CA_UIM_INTEGRATION = true,
    CA_UIM_CENTRAL = true
};

-------------------------------------------------------
-- List of robots we want to exclude 
-------------------------------------------------------
local exclude_robots = {};

-------------------------------------------------------
-- The list of probe we want to monitore (get info in our base).
-------------------------------------------------------
local accepted_probes = {
    controller = true,
    cdm = true,
    logmon = true,
    processes = true,
    ntservices = true,
    ntevl = true
};

-------------------------------------------------------
-- Configuration we retrieve on each probes
-------------------------------------------------------
local check_probe = {
    cdm = {
        _cpu_alarm = {
            active = true
        },
        _cpu_alarm_error = {
            active = true,
            threshold = true
        },
        _memory = {
            qos_memory_physical_perc = true
        }
    },
    ntevl = {
        _logs = {
            application = true
        }
    }
};
```
