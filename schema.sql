
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
