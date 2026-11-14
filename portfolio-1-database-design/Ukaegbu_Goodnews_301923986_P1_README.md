# Portfolio 1 — Database Design and Modelling

I organised the data into customer, account, payment. The design document explains the fields, keys, relationships, business rules and indexes. The normalisation document takes the sample data from unnormalised records through 1NF, 2NF and 3NF and checks that the decomposition is lossless.

## Database checks

| Table | Rows |
| --- | --- |
| customer | 3 |
| account | 4 |
| payment | 10 |

The 28 invalid inserts were each rejected at their expected constraint with the expected SQLSTATE, and the valid sample rows remained unchanged.

| Test group | Tests | SQLSTATE | Result |
| --- | --- | --- | --- |
| Duplicate primary keys | 1–3 | 23505 | 3 of 3 rejected |
| Missing parent rows (foreign keys) | 4–5 | 23503 | 2 of 2 rejected |
| NULL in required columns | 6–21 | 23502 | 16 of 16 rejected |
| Negative balance, zero amount (CHECK) | 22–23 | 23514 | 2 of 2 rejected |
| Duplicate non-null external_reference (partial unique index) | 24 | 23505 | 1 of 1 rejected |
| Status and currency values outside the allowed set (CHECK) | 25–28 | 23514 | 4 of 4 rejected |

`P1_Verify.sql` also lists every constraint and index from the system catalog (11 constraints, 6 indexes) and runs the lossless-join check: the 10 rows of the 1NF relation are rebuilt exactly from the three 3NF relations (0 missing, 0 extra).

## Files

- [Design](Ukaegbu_Goodnews_301923986_P1_Design.md)
- [ER diagram](Ukaegbu_Goodnews_301923986_P1_ERDiagram.md)
- [Normalisation](Ukaegbu_Goodnews_301923986_P1_Normalisation.md)
- [Schema](Ukaegbu_Goodnews_301923986_P1_Schema.sql)
- [Sample data](Ukaegbu_Goodnews_301923986_P1_SampleData.sql)
- [Constraint tests](Ukaegbu_Goodnews_301923986_P1_ConstraintTests.sql)
- [Verification queries](Ukaegbu_Goodnews_301923986_P1_Verify.sql)
- [Table and constraint evidence](screenshots/Ukaegbu_Goodnews_301923986_P1_DatabaseResults.png)
- Raw output: [schema and data](evidence/Ukaegbu_Goodnews_301923986_P1_SchemaAndData.txt) · [constraint tests](evidence/Ukaegbu_Goodnews_301923986_P1_ConstraintTests.txt) · [verification](evidence/Ukaegbu_Goodnews_301923986_P1_Verify.txt)

## Run the SQL

Create a fresh PostgreSQL database. Run the schema first, then the sample data. Run the deliberately invalid statements in ConstraintTests.sql outside a transaction so each one fails on its own; each is expected to produce an error. Then run Verify.sql.

```bash
createdb mit_portfolio
psql -d mit_portfolio -f Ukaegbu_Goodnews_301923986_P1_Schema.sql
psql -d mit_portfolio -f Ukaegbu_Goodnews_301923986_P1_SampleData.sql
psql -d mit_portfolio -v ON_ERROR_STOP=0 -v VERBOSITY=verbose -f Ukaegbu_Goodnews_301923986_P1_ConstraintTests.sql
psql -d mit_portfolio -f Ukaegbu_Goodnews_301923986_P1_Verify.sql
```

`run_all.sh` in the repository root runs these steps and saves the output in `evidence/`.

## References

- [PostgreSQL — constraints](https://www.postgresql.org/docs/16/ddl-constraints.html)
- [PostgreSQL — partial indexes](https://www.postgresql.org/docs/16/indexes-partial.html)
