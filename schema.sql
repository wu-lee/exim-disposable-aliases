-- See the default config value schema_version for this schema's version.

-- Global config / metadata
CREATE TABLE config (
   name STRING NOT NULL,
   value STRING NOT NULL,
   PRIMARY KEY (name)
);

-- Maps stems to one or more recipients
CREATE TABLE aliases (
   stem TEXT NOT NULL,
   recipients TEXT NOT NULL,
   PRIMARY KEY (stem, recipients)
);

-- Per stem configs
CREATE TABLE stem_configs (
   stem TEXT NOT NULL,
   default_remaining INTEGER NOT NULL DEFAULT 0,
   PRIMARY KEY (stem)
);

-- Maps prefix+stems to zero or one counter
CREATE TABLE counters (
   prefix TEXT NOT NULL,
   stem TEXT NOT NULL,
   remaining INTEGER NOT NULL DEFAULT 0,
   delivered INTEGER NOT NULL DEFAULT 0,
   rejected INTEGER NOT NULL DEFAULT 0,
   PRIMARY KEY (prefix, stem)
);

-- Indicates the authorisation ids required to control each stem
CREATE TABLE authorised (
   stem TEXT NOT NULL,
   id TEXT NOT NULL,
   driver TEXT NOT NULL,
   PRIMARY KEY (stem, id, driver)
);

-- Set the default config values
INSERT INTO config (name, value)
VALUES
   ("schema_version","1")
;