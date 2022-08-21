Implementation notes.
=====================

Writing this proved to be far harder than I anticipated.  In fact it
turned into a bit of a fight with Exim, in which each time I thought I
had it cracked, I'd discover another reason it my solution wouldn't
work.

I was not very familiar with Exim beyond configuring it in the usual
ways. I progressed from trying to use simple redirecting router
config, to this plus a user filter (filters have nicer conditionals),
to an acl config (because Exim 4.80 allows $acl_m_* variables, whereas
filters only allow counter variables), to a router plus a system
filter using mail headers as variables (because the acl logic would be
entirely skipped if an earlier acl allowed or rejected delivery) back
to a router config plus a filter (because system filters cannot
actually be used in routers).

I was keen to avoid too many dependencies or convoutions like Perl or
procmail or maildrop, or anything low level and hard to debug, like
dynamically-linked C.  This is not to say I don't like Perl or
procmail or maildrop, they just seemed overkill, and the SQLite
integration not directly supported as it is in Exim.

Possibly this was a mistake, and the compromises I had to make in
order to have this where:

 - No variables to speak of, bar:
   - those predefined by exim
   - filter `matches` regex captures $1, $2 etc.
   - string-expansion regex captures $1, $2 etc.
   - numeric filter counter variables $n0, $n1 etc.
 - Abuse of regexes as required to preserve regex captures used as
   variable substitutes
 - Abuse of conditionals and other filter commands for the
   side-effects of a SQL lookup
 - Enduring Exim's braces-heavy syntax
 - Expanding "macros" in the filter myself

The logic of the filter is somewhat obtuse as a result. I did my best
to comment the code in detail to offset this, but it will undoubted be
tricky for others, and future versions of myself to pick up.

The advantage is that it is small and simple to install. It is also
*relatively* easy to test using `exim -bf` and/or `exim -bd` (see the
test script in `t/`).  Hopefully the logic can be mostly left as is!

I am not an Exim expert. Advice, and especially patches with tests,
welcomed.

