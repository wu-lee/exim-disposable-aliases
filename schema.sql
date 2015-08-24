-- Maps stems to one or more recipients
create table aliases (
   stem text,
   recipient text,
   primary key (stem, recipient)
)

-- Maps stems to zero or one counter
create table counters {
   stem text primary key;
   counter int;
}

-- Maps stems to zero or more failure modes
create table failmodes {
   stem text primary key;
   mode text;
}
