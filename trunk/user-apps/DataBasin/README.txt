README
------

Data Basin
Data Access Tool for Salesforce

DBSoap: classes to interact with Salesforce

Note: The Macintosh binaries are compiled for PowerPC. If you are on Intel and do not have Rosetta installed, you need to compile both the GSWS Framework and DataBasin natively.


Current Version: 0.3
--------------------

NEWS
- object list queried at login and updatable later on
- Object Inspector


LIMITATIONS
- CVS Reading and Writing does not support full quoting properly
- no field matching: create column names must match exactly salesforce field names
- semi-joins not supported
- GNUStep version does not support sorting in the object inspector table due to Gorm format limitations, hopefully solved soon

MISSING FEATURES
- Upsert
