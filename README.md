# GlucoLink A2 – Group 2 (32113 Advanced Database)

Shared folder for our Assignment 2 SQL scripts and documents.
This repository is private. Do not upload course slides or workbooks.

## Folders

| Folder | What goes in it |
|---|---|
| `sql/` | the numbered SQL scripts (run order below) |
| `docs/` | diagrams (.png + .drawio), rules and plans |
| `tests/` | test plan, hand checks, test results |
| `evidence/` | screenshots showing a query and its result |

## How to upload (no git commands needed)

1. Open the folder, then **Add file → Upload files**.
2. Drag your file in, write a short message (for example `C: 01_src_tables first version`), then **Commit changes**.
3. To update a file, upload it again with the same name. GitHub keeps every version.

## Run order

| # | File | Owner |
|---|---|---|
| 00 | `00_setup.sql` | B Zhihao |
| 01 | `01_src_tables.sql` | C Quang |
| 02 | `02_src_data.sql` | C Quang |
| 02b | `02b_src_lab_messages.sql` | B Zhihao |
| 03 | `03_raw_extract.sql` | C Quang |
| 04 | `04_cleansed_standardise.sql` | D Yutong |
| 05 | `05_identity_resolution.sql` | D Yutong |
| 06 | `06_curated_dimensions.sql` | E Shuo |
| 07 | `07_curated_facts.sql` | E Shuo |
| 08 | `08_reporting_views.sql` | E Shuo + D Yutong |
| 09 | `09_tests.sql` | F Minha |
| 10 | `10_demo_queries.sql` | F Minha |

## Ground rules (Build Plan v2, section 3)

- Every table and row comes from a saved script. No typing into CloudBeaver's data grid.
- Always write `schema.table`. Only change your own tables.
- Every script has the header comment, a comment above each block, and can be run twice.
- After each finished file, post the file name and a screenshot of its check in Teams.
