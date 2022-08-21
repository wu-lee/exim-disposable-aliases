Disposable aliases for Exim
===========================

If you know the excellent free service offered by
[Spamgourmet](http://spamgourmet.org), this aims to offer something
similar: disposable email aliases convenient for for ad-hoc logins,
that can auto-delete after a fixed number of deliveries to prevent
spammers from harvesting the addresses for nafarious ends.

[Exim](http://exim.org) is a mail transfer agent, *AKA* MTA, *AKA*
mail server software, written for Unix, commonly installed on
[Debian](http://debian.org).

This project consists primarily of an Exim router configuration with
an associated Exim filter script, which performs the logic by means of
a lookup into a [SQLite](http://sqlite.org) database file.

Synopsis
--------

You need to register on a website, let's call it *Spammr.net*. It
requires an email address to validate the login.  You don't trust
them. So you register using a disposable email alias on your mail
server's domain like this:

    spammr.5.pimpernel@example.com

On seeing a delivery to this alias, your mail server will allow it and
permit 4 more, after which they are rejected. If the site turns out to
be responsible, you can enable the alias permanently. If the site
abuses your this email, you can allow it to expire, or disable it!

Description
-----------

The aliases handled by this filter emulate Spamgourmet's, having the
form:

    <prefix>.<N>.<stem>@<domain>

or: 

    <prefix>.<stem>@<domain>

Where:

 - `<domain>` is (one of) the domains handled by the MTA
 - `<stem>` is a common local part shared by all variants of the alias
 - `<prefix>` is a unique identifier which has a counter associated
 - `<N>` is a number defining the initial number of deliveries permitted

The stem defines the alias's recipient list. For example, you may
define an alias stem `pimpernel` which forwards to a local user called
`percy`.  (The recipients don't have to be local).  This stem may have
any number of different prefixes associated, such as:

    spammr.5.pimpernel@example.com
    dropbox.10.pimpernel@example.com
    github.20.pimpernel@example.com
    twitter.3.pimpernel@example.com
    ...

The rule is, all aliases ending in (in this example) `.pimpernel` go
to your real email address, which is hidden.  The prefix such as
`spammr.5` can be invented at the point of registration on
*Spammr.net*.

The number (for example, 5) defines how many deliveries to allow
before mail gets rejected instead of forwarded. It gets set on the
server when it makes the first delivery, after which the number is
ignored.  This means only you (or an authorised user of your server)
can change it after this first delivery.  If the number is omitted,
like `spammr.pimpernel`, the default is zero.

Thus, at the point of registering on the *Spammr* website, you don't
need to have done more than defined the common `pimpernel` stem as
routing to your real email address.

You can query or modify the counters by emailing the alias via an
authenticated SMTP connection to your mail server, with a special
subject starting with an exclaimation mark, such as the following.

 - `!on`  - allow unlimited deliveries to this prefix
 - `!off` - allow no more deliveries
 - `!20`  - allow 20 more deliveries
 - `!report` - reply with a report of all prefixes for this stem and their counters

This means as an alternative you can set the number of deliveries
prior to registering.  Disabling an email alias is a simple matter of
emailing with the subject "!off".

Requirements
------------

Exim requires a Unix-like operating system. Refer to the Exim
documentation for further information.

This project was tested on Debian Wheezy using Exim 4.80 with SQLite
extensions, and SQLite 3.7.13.  At the time of writing, since it just
consists of a user filter and a router, I believe it should in
principle work on any installation of Exim 3 or better, so long as it
has SQLite lookups, but this has not been verified.

On Debian Squeeze, this means you will require the packages
`exim4-daemon-heavy` and `sqlite3`.

Installation
------------

Having installed the requirements, check paths, and the Exim user and
group in the `install` script.  If you are installing on Debian, these
should be acceptable as-is, but if not you may need to adjust them for
your case.

The installer script creates:

 - A router config fragment
 - A filter
 - A SQLite database
 - An Exim macro definition fragment
 - An Exim data ACL fragment

When in use, the filter also generates log files in a common directory.

If you have checked out this project in `BASEDIR`, installation on a
clean server can be started using the command:

    cd $BASEDIR
    ./install

By default the installer will refuse to overwrite an existing SQLite
database, to avoid clobbering an existing configuration by
mistake. You can override this and replace an existing database with a
fresh one like this:

    FORCE=1 ./install

Or leave an existing database alone like this:

    FORCE=0 ./install

But be aware that if the existing database's schema is for a different
version this may not subsequently work.


Building a .deb package
-----------------------

This requires dpkg-deb and lintian to be installed.

    ./mkdir out
    ./package -t out

This should result in a .deb file being created in `./out/`, with the
version taken from the `version` file.


Controlling an alias
--------------------

Aliases can be in four states:

 - Undefined: no mail to it has been seen (no counter).
 - Limited: a finite number of deliveries is permitted (counter > 0)
 - Disabled: no deliveries are permitted (counter is 0).
 - Enabled: all deliveries are permitted (counter is -1).

Control emails have a subject starting with an exclaimation mark,
followed by a command, and nothing else, except whitespace.  The body
of the email is ignored.

Thus the following subjects can set the counter:

 - `!on` sets it to -1
 - `!off` sets it to 0
 - `!N` sets it to N, where N is one to five digits
 - `!report` requests a report, see section below.

And an initial delivery to an alias with an embedded counter N sets
the counter to N.  N must be one to five digits for it to be
recognised as an alias.  After which the counter is ignored, if
present, and aliases with and without the counter are treated
identically.

These commands are only recognised on deliveries to Exim locally by
the user `root`, or deliveries which match a
`$authenticated_id`/`$sender_host_authenticated` pair associated with
the alias stem defined in the `authorised` table in the SQLite
database. The former is the name of authentication diver which was
used, and the latter is a driver dependent user identifier.  For more
details of these, see the Exim documentation for [String
expansions](http://www.exim.org/exim-html-current/doc/html/spec_html/ch-string_expansions.html)

Deliveries with these subject lines from elsewhere are treated like any
other, and forwarded or rejected as per the counter state.

Querying an alias
-----------------

The special command subject `!report` is designed to tell authorised
users about the state of all the prefixes for a given stem.  A reply
to the sender containing a sorted text dump of the counters for that
stem is sent. For example:

    All *.wu-lee alias deliveries remaining:

    prefix=dropbox remaining=5 delivered=0 rejected=0 
    prefix=github remaining=-1 delivered=10 rejected=0 
    prefix=spammr remaining=0 delivered=5 rejected=1
    prefix=twitter remaining=-1 delivered=30 rejected=0 


Creating new aliases, authorisation, and other administration
-------------------------------------------------------------

This is currently done by manipulating the SQLite database
directly. It is assumed the administrator will be able to do this on
behalf of users.  Possibly command-line utilities could be added, or a
web interface, but so far this suffices for me.

SQL commands to the database can be invoked using the `sqlite3`
command.  For example, if the database is in the standard location:

    sqlite3 /var/spool/exim4/db/disposable-aliases.db
    sqlite> 

To add a new alias "foo" delivering to a local user "bob" and a remote
one "alice@example.com"

    insert into aliases (stem, recipients) values ('foo', 'bob'), ('foo', 'alice@example.com');

To remove it, simply delete all records for that stem:

    delete from aliases where stem = 'foo';

Associated records from the other tables can be deleted too, but this
is optional.

Authorisation for sending control emails is done by adding records to
the authorised table.  For example, to allow the user bob to send them
via a dovecot SASLD authenticated connection:

    insert into authorised (stem, id, driver) values ('foo', 'bob', 'dovecot_plain');

The counter can be updated this way too, for example:

    update counters set remaining = 100 where stem = 'foo' and prefix = 'widgets';

Logs
----

When in use, the filter writes log files, one per alias, named after the alias without the domain or the counter, and a `.log` suffix.  For example `spammr.foo.log`.

The content is a tab-delimited text file without headers, like this:

    2015-09-30 00:14:14	spammr.3.	delivered=3	sender@spammr.net	bounces@spammr.net	Hello suckers!
    2015-09-30 21:46:07	spammr.	report	alice@example.com	alice@example.com	!report
    2015-09-30 21:47:35	spammr.3.	delivered=2	sender@spammr.net	bounces@spammr.net	oink
    2015-09-30 22:19:20	spammr.3.	delivered=1	miscreant@nonesuch.ru	miscreant@nonesuch.ru	!report
    2015-09-30 22:24:31	spammr.3.	rejected	miscreant@nonesuch.ru	miscreant@nonesuch.ru	!report
    2015-09-30 22:25:38	spammr.3.	report	alice@example.com	alice@example.com	!report
    2015-09-30 22:26:46	spammr.	enabled	alice@example.com	alice@example.com	!on
    2015-09-30 00:14:14	spammr.3.	delivered=-1	sender@spammr.net	bounces@spammr.net	No, but really...
    2015-09-30 22:33:02	spammr.	disabled	bob@mydomain.com	bob@mydomain.com	!off

Columns are:

 - time of day
 - local-part prefix
 - action
 - sender address
 - return path
 - subject

Uninstalling
------------

This is not currently automated. Removing all of the files listed in
the 'installing' section and restarting Exim should do the trick.
Consult the installer script to find out where these are.

Tests
-----

There is a test script under t/ aimed at developers which can be run
to verify correct operation.  It is reasonably complete, but could no
doubt be improved.


Author
------

Nick Stokoe - github dot wu-lee at noodlefactory dot co dot uk
October 2015, updated August 2022
