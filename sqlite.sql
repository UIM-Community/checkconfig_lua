CREATE TABLE hubs_list (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain TEXT NOT NULL,
    origin TEXT NOT NULL,
    name TEXT NOT NULL,
    ip TEXT NOT NULL,
    versions TEXT NOT NULL
)

CREATE TABLE robots_list (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hubid INTEGER NOT NULL,
    name TEXT NOT NULL,
    ip TEXT NOT NULL,
    origin TEXT NOT NULL,
    versions TEXT NOT NULL,
    FOREIGN KEY(hubid) REFERENCES hubs_list(id)
)

CREATE TABLE probes_list (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    robotid INTEGER NOT NULL ,
    name TEXT NOT NULL,
    active TEXT NOT NULL,
    versions TEXT NOT NULL,
    FOREIGN KEY(robotid) REFERENCES robots_list(id)
)

CREATE TABLE probes_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    probeid INTEGER NOT NULL,
    section TEXT NOT NULL,
    skey TEXT NOT NULL,
    svalue TEXT NOT NULL,
    FOREIGN KEY(probeid) REFERENCES robots_list(id)
)
