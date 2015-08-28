
-- Maps stems to one or more recipients
CREATE TABLE aliases (
   stem TEXT NOT NULL,
   recipients TEXT NOT NULL,
   PRIMARY KEY (stem, recipients)
);

-- Maps prefix+stems to zero or one counter
CREATE TABLE counters (
   prefix TEXT NOT NULL,
   stem TEXT NOT NULL,
   counter INTEGER NOT NULL,
   PRIMARY KEY (prefix, stem)
);

