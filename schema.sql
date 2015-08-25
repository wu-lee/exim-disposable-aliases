
-- Maps stems to one or more recipients
CREATE TABLE aliases (
   stem TEXT NOT NULL,
   recipients TEXT NOT NULL,
   PRIMARY KEY (stem, recipients)
);

-- Maps stems to zero or one counter
CREATE TABLE counters (
   stem TEXT PRIMARY KEY NOT NULL,
   counter INTEGER NOT NULL
);

-- Maps stems to zero or more failure modes
CREATE TABLE failmodes (
   stem TEXT PRIMARY KEY NOT NULL,
   mode TEXT NOT NULL
);
