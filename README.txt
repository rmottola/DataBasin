README
------

Data Basin
Data Access Tool for Salesforce

DBSoap: classes to interact with Salesforce


Current Version: 0.9
--------------------

NEWS

- multi-threading: concurrent operations with interrupt
- down batch size
- handle multiple errors in update or create
- filter line-breaks when writing CSV



Older news:
- Query gets parsed and this allows to write fields in Query Order
- Query parsing allows for fields to be empty and still preserve the correct number of columns in the CSV file
- Download batch size settable
- CVS qualifier and separator settable in both reading and writing
- Support LIMIT clause in Select Identify
- Improved Exception catching and display for Select Identify
- Object Inspector supports selection of items
- Support count and aggregate queries
- Select Identify works with multiple columns (all in AND as condition)
- Support "." as Semi-Join
- Query Identify: run a select on each item in the list, the single column provided in the file will be used as identifier and it must point to an Id or a unique identifier
- improved exception trapping and display
- support for reading quoted CSV files


LIMITATIONS
- CVS Reading and Writing does not support full quoting properly (but it improved vastly in 0.5)
- no field matching: create column names must match exactly salesforce field names

MISSING FEATURES
- Upsert
