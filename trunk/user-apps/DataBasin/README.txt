README
------

Data Basin
Data Access Tool for Salesforce

DBSoap: classes to interact with Salesforce

Note: The Macintosh binaries are compiled for PowerPC. If you are on Intel and do not have Rosetta installed, you need to compile both the GSWS Framework and DataBasin natively.


Current Version: 0.4
--------------------

NEWS
- Query Identify: run a select on each item in the list, the single column provided in the file will be used as identifier and it must point to an Id or a unique identifier
- Http / Https login selection in the preferences

Older news:
- object list queried at login and updatable later on
- Object Inspector


LIMITATIONS
- CVS Reading and Writing does not support full quoting properly
- no field matching: create column names must match exactly salesforce field names
- semi-joins not supported
- GNUStep version does not support sorting in the object inspector table due to Gorm format limitations, hopefully solved soon

MISSING FEATURES
- Upsert
