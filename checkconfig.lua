-------------------------------------------------------
-- Database information
-------------------------------------------------------
local dbname = 'checkconfig.db';

-------------------------------------------------------
-- Variable qui permet de log ou non.
-------------------------------------------------------
local debug = false;
local echo = false;

-- Path for the log file.
local logpath = "E:\\Program Files (x86)\\Nimsoft\\probes\\service\\nas\\scripts\\EXT-Conf\\ext-configuration.log";

-------------------------------------------------------
-- Liste des HUBS que l'on ne souhaite pas prendre en compte
-------------------------------------------------------
local exclude_hubs = {
    CA_UIM_PARKING = true,
    CA_UIM_NT4_W2000 = true,
    CA_UIM_R_PARKING = true,
    --CA_UIM_PARKING_LYB = true,
    CA_UIM_INTERNET_GTW = true,
    CA_UIM_MESURE_A = true,
    CA_UIM_MESURE_B = true,
    CA_UIM_UMP = true,
    CA_UIM_HOMOLOGATION = true,
    CA_UIM_LYBERNET = true,
    CA_UIM_INTEGRATION = true,
    CA_UIM_CENTRAL = true
};

-------------------------------------------------------
-- Liste des robots qu'on ne souhaite pas prendre en compte
-------------------------------------------------------
local exclude_robots = {};

-------------------------------------------------------
-- Liste des probes que l'ont souhaite monitorer.
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
-- Configuration que l'on récupère dans chaque probe
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

-------------------------------------------------------
-- Fonction qui va écrire des nouvelles lignes dans la log !
-------------------------------------------------------
local function log(text,force_debug)
    if echo then
        print(text);
    end
    force_debug = force_debug or false;
    if debug or force_debug then
        -- gain de performance
        local fl = file;
        local ts = timestamp;

        b,nread = fl.read(logpath);
        if b == nil then
            fl.create(logpath);
        end
        time = ts.format( ts.now (),"%c" );
        fl.write(logpath,time.." - "..text.."\n");
    end
end

-------------------------------------------------------
-- Fonction de visualitation du contenu des tables
-------------------------------------------------------
local function tdump(t)
    local search = pairs;
    local sf = string.format;
    local sr = string.rep;
    local perf_type = type;
    local ts = tostring;
    local function dmp(t, l, k)
        if perf_type(t) == "table" then
            log(sf("%s%s:", sr(" ", l*2), ts(k)));
            for k, v in search(t) do
                dmp(v, l+1, k);
            end
        else
            log(sf("%s%s:%s", sr(" ", l*2), ts(k), ts(t)));
        end
    end
    dmp(t, 1, "root");
end

-------------------------------------------------------
-- On ouvre la connexion avec la database !
-------------------------------------------------------
local SQL = database.open(dbname);

-------------------------------------------------------
-- Si l'on arrive pas à ce connecter a la database
-------------------------------------------------------
if not SQL then
    log("Unable to open database connection!",true);
    os.exit();
end

-------------------------------------------------------
-- Fonction qui s'implifie la récupération d'une FK
-------------------------------------------------------
local function getFK(requete)
    local fk, rc = database.query(requete);
    if #fk > 0 and rc == 0 then
        return fk[1].id;
    end
end


-- Amélioration des performances process
local search = pairs;
local nimrequest = nimbus.request;
local gsub = string.gsub;

-------------------------------------------------------
-- On récupère la liste des HUBS !
-------------------------------------------------------
do
    local hublist , hublist_rc = nimrequest('hub','gethubs')["hublist"];

    if hublist ~= nil then
        for _,hub in search(hublist) do

            -------------------------------------------------------
            -- On vérifie que le hub n'est pas exclu
            -------------------------------------------------------
            if exclude_hubs[gsub(hub.name,'-','_')] == nil then

                -------------------------------------------------------
                -- On vérifie l'origin du hub, car si elle n'est pas présente c'est très certainement que le HUB n'est pas bon.
                -------------------------------------------------------
                if hub.origin ~= nil then

                    log('--HUB => '..hub.name,true);

                    -------------------------------------------------------
                    -- On insert ou update en fonction de si le hub est présent ou non dans la database.
                    -------------------------------------------------------
                    local hub_find = true;
                    do

                        local result, rc = database.query("SELECT * FROM hubs_list WHERE name LIKE '"..hub.name.."'");

                        if #result > 0 and rc == 0 then
                            local hubResult = result[1];
                            if(hubResult.domain ~= hub.domain or hubResult.ip ~= hub.ip or hubResult.origin ~= hub.origin or hubResult.version ~= hub.version) then
                                local _, u_rc = database.query("UPDATE hubs_list SET domain='"..hub.domain.."',ip='"..hub.ip.."',origin='"..hub.origin.."',version='"..hub.version.."' WHERE name LIKE '"..hub.name.."'");
                                if u_rc ~= 4 then
                                    log("       HUB "..hub.name.." : Update failed",true);
                                end
                            end
                        else
                            local insert = "INSERT INTO hubs_list(id,domain,name,ip,origin,version) ";
                            local values = "VALUES (NULL,'"..hub.domain.."','"..hub.name.."','"..hub.ip.."','"..hub.origin.."','"..hub.version.."')";
                            local _, i_rc = database.query(insert..values);
                            if i_rc ~= 4 then
                                log("       HUB "..hub.name.." : Insert failed",true);
                                hub_find = false;
                            end
                        end

                    end

                    if hub_find then
                        -------------------------------------------------------
                        -- On récupère la foreign key du hub
                        -------------------------------------------------------
                        local HUB_FK = getFK("SELECT id FROM hubs_list WHERE name LIKE '"..hub.name.."'");

                        -------------------------------------------------------
                        -- On récupère les robots de notre hub
                        -------------------------------------------------------
                        robotlist, robotlist_rc = nimrequest(hub.addr,'getrobots')["robotlist"];

                        -------------------------------------------------------
                        -- On vérifie que la robotlist n'est pas nil
                        -------------------------------------------------------
                        if robotlist ~= nil then

                            -------------------------------------------------------
                            -- On boucle la liste de robots récupérer
                            -------------------------------------------------------
                            for _,robot in search(robotlist) do

                                -------------------------------------------------------
                                -- On vérifie que le robot n'est pas exclu ou down.
                                -------------------------------------------------------
                                if robot.status ~= 2 then
                                    if exclude_robots[gsub(robot.name,'-','_')] == nil then
                                        log('   ROBOT__NAME : '..robot.name);

                                        -------------------------------------------------------
                                        -- On vérifie que le robot est dans la table ou non (si oui on met à jour le robot en table)
                                        -------------------------------------------------------
                                        local find_robot = true;
                                        do
                                            result, rc = database.query("SELECT * FROM robots_list WHERE hubid='"..HUB_FK.."' AND name LIKE '"..robot.name.."'");

                                            if #result > 0 and rc == 0 then
                                                local robotResult = result[1];
                                                if(robotResult.ip ~= robot.ip or robotResult.origin ~= robot.origin or robotResult.version ~= robot.version) then
                                                    local _, u_rc = database.query("UPDATE robots_list SET ip='"..robot.ip.."',origin='"..robot.origin.."',version='"..robot.version.."' WHERE name LIKE '"..robot.name.."'");
                                                    if u_rc ~= 4 then
                                                        log("       => Robot update failed on robot : "..robot.name,true);
                                                    end
                                                end
                                            else
                                                local insert = "INSERT INTO robots_list(id,hubid,name,ip,origin,version) ";
                                                local values = "VALUES (NULL,'"..HUB_FK.."','"..robot.name.."','"..robot.ip.."','"..robot.origin.."','"..robot.version.."')";
                                                local _, i_rc = database.query(insert..values);
                                                if i_rc ~= 4 then
                                                    log("       => Robot insert failed on robot : "..robot.name,true);
                                                end
                                            end

                                        end

                                        if find_robot then
                                            -------------------------------------------------------
                                            -- On récupère la FK des robots
                                            -------------------------------------------------------
                                            local ROBOT_FK = getFK("SELECT id FROM robots_list WHERE name LIKE '"..robot.name.."'");

                                            -------------------------------------------------------
                                            -- On récupère la liste des probes de notre robot
                                            -------------------------------------------------------
                                            probe_list, probe_list_rc = nimrequest(robot.addr..'/controller','probe_list');

                                            -------------------------------------------------------
                                            -- On vérifie que le controller nous répond
                                            -------------------------------------------------------
                                            if probe_list ~= nil then

                                                -------------------------------------------------------
                                                -- On boucle la liste de probes récupérer du controller de notre robot
                                                -------------------------------------------------------
                                                for probeName,probe in search(probe_list) do

                                                    -------------------------------------------------------
                                                    -- On vérifie que la probe nous intéresse
                                                    -------------------------------------------------------
                                                    if accepted_probes[probeName] then -- and probe.active == 1

                                                        -------------------------------------------------------
                                                        -- On vérifie si la probe est en base ou non.
                                                        -------------------------------------------------------
                                                        do
                                                            local select = "SELECT * FROM probes_list WHERE robotid='"..ROBOT_FK.."' AND name LIKE '"..probeName.."'";
                                                            local result, rc = database.query(select);

                                                            -------------------------------------------------------
                                                            -- On vérifie que les probes ont des versions
                                                            -------------------------------------------------------
                                                            local temp_version = probe.pkg_version or "N.A";
                                                            if probe.pkg_version == nil then
                                                                log("       -- "..probeName.." version undefined",true);
                                                            end

                                                            if #result > 0 and rc == 0 then
                                                                if(result[1].active ~= probe.active or result[1].version ~= probe.pkg_version) then
                                                                    local _,u_rc = database.query("UPDATE probes_list SET active='"..probe.active.."',version='"..temp_version.."' WHERE name LIKE '"..probeName.."'");
                                                                    if u_rc ~= 4 then
                                                                        log("       Fail update from probe => "..probeName,true);
                                                                    end
                                                                end
                                                            else
                                                                local insert = "INSERT INTO probes_list(id,robotid,name,active,version) ";
                                                                local values = "VALUES (NULL,'"..ROBOT_FK.."','"..probeName.."','"..probe.active.."','"..temp_version.."')";
                                                                local _, i_rc = database.query(insert..values);
                                                                if i_rc ~= 4 then
                                                                    log("       Failed insert probe => "..probeName,true);
                                                                end
                                                            end

                                                        end

                                                    end
                                                end

                                            -------------------------------------------------------
                                            -- Si le controller ne répond rien on claque une erreur
                                            -------------------------------------------------------
                                            else
                                                log("   Failed to reach controller => "..robot.addr..'/controller',true);
                                            end

                                        else
                                            log("   Failed to get Foreign key from robot => "..robot.name);
                                        end

                                    end

                                else
                                    log("   => "..robot.addr.." is down!",true)
                                end

                            end

                        -------------------------------------------------------
                        -- Nous n'avons pas réussie à avoir une liste de robot sur notre hub, on claque une log.
                        -------------------------------------------------------
                        else
                            log("   Failed to get robotlist from => "..hub.addr,true);
                        end

                    else
                        log("   Failed to get Foreign Key from hub => "..hub.name)
                    end

                -------------------------------------------------------
                -- Le hub ne possède pas d'origin, on claque une log
                -------------------------------------------------------
                else
                    log(hub.name.." have no origin !",true);
                end

            end

        end
    end

end

log("=================> Get probes configuration :",true);
-------------------------------------------------------
-- Maintenant que nous avons toutes les informations sur nos probes nous allons chercher leur configuration
-------------------------------------------------------
local R, rc = database.query("SELECT R.id AS robotid,R.name AS robotname,H.name AS hubname,H.domain FROM robots_list AS R LEFT OUTER JOIN hubs_list AS H ON R.hubid = H.id");
if R ~= nil and rc == 0 then

    for _,v in search(R) do

        local ADDR = "/"..v.domain.."/"..v.hubname.."/"..v.robotname.."/controller";
        local probes_list, pl_rc = database.query("SELECT name,id FROM probes_list WHERE robotid LIKE '"..v.robotid.."'");

        if #probes_list > 0 and pl_rc == 0 then
            -------------------------------------------------------
            -- on boucle la liste des probes
            -------------------------------------------------------
            for _,probe in search(probes_list) do

                local probe_configuration = check_probe[probe.name];
                if probe_configuration ~= nil then

                    -------------------------------------------------------
                    -- On récupère la configuration de notre probe
                    -------------------------------------------------------
                    local probeConfig, probe_rc;
                    do
                        local temp_pds = pds;
                        local args = temp_pds.create();
                        temp_pds.putString(args,"name",probe.name);
                        probeConfig, probe_rc = nimrequest(ADDR,'probe_config_get', args);
                    end
                    -------------------------------------------------------
                    -- On vérifie que le configuration est présente / vivante
                    -------------------------------------------------------
                    if probeConfig ~= nil then

                        -------------------------------------------------------
                        -- On boucle le contenu local de la configuration
                        -------------------------------------------------------
                        for S_msg,S_content in search(probe_configuration) do

                            -- On change les caractères _ de notre message en / (leur valeur réel)
                            S_msg = gsub(S_msg,"_","/");

                            -------------------------------------------------------
                            -- On boucle la conf de la prob en fonction de notre message locaux
                            -------------------------------------------------------
                            for k,v in search(probeConfig[S_msg]) do

                                for i,j in search(S_content) do

                                    -------------------------------------------------------
                                    -- Le profil et la configuration probe match
                                    -------------------------------------------------------
                                    if i == k and j then

                                        -------------------------------------------------------
                                        -- On vérifie en database si le profil à besoin d'être mis à jour ou d'être insérer (car non existant)
                                        -------------------------------------------------------
                                        do
                                            local selectROBOT,robotRC = database.query("SELECT * FROM probes_config WHERE probeid='"..probe.id.."' AND section='"..S_msg.."' AND skey='"..k.."'");

                                            if selectROBOT ~= nil and robotRC == 0 then
                                                if selectROBOT[1].svalue ~= v then
                                                    local _,u_rc = database.query("UPDATE probes_config SET svalue='"..v.."' WHERE id='"..selectROBOT[1].id.."'");
                                                    if u_rc ~= 4 then
                                                        log("   Probe configuration update failed, probe name : "..probe.name,true);
                                                    end
                                                end
                                            else
                                                local insert = "INSERT INTO probes_config(id,probeid,section,skey,svalue) ";
                                                local values = "VALUES (NULL,'"..probe.id.."','"..S_msg.."','"..k.."','"..v.."')";
                                                local _,i_rc = database.query(insert..values);
                                                if i_rc ~= 4 then
                                                    log("   Probe configuration insert failed, probe name : "..probe.name,true);
                                                end
                                            end

                                        end

                                    end

                                end

                            end

                        end

                    -------------------------------------------------------
                    -- La configuration n'existe pas, on clauqe une log
                    -------------------------------------------------------
                    else
                        log(" => failed to get probes configuration on "..ADDR,true);
                    end

                end

            end

        else
            log("   => No probes find on robot =>  "..v.robotname,true);
        end

    end

else
    log(" Impossible de récupérer la liste des robots end database !",true)
end

-------------------------------------------------------
-- Close database!
-------------------------------------------------------
database.close();

log("=================> Script finish !",true);
