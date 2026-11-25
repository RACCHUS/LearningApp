# OpenStax archive fixtures (importer regression tests)

Recorded responses from the OpenStax archive for two small slices, so
`tool/import_open_textbook.py --replay` and `tool/tests/test_import_open_textbook.py`
run offline and deterministically (ingestion plan v1.2 §7.3, slice 6):

- `prealgebra/`: *Prealgebra* (1st edition), section 6.3, with its book tree, chapter 6 answer key and key terms.
- `college_algebra/`: *College Algebra* (1st edition), section 1.3, with its book tree, chapter 1 answer key and key terms.

Each `<hash>.json` holds `{"url", "body"}`; the file name is the first 24 hex characters of the URL's SHA-256.
`golden.yaml` is the manifest the importer must produce from these responses (fixed retrieval time, no practice merge).

Content © OpenStax, Rice University, licensed under CC BY 4.0
(https://creativecommons.org/licenses/by/4.0/): *Prealgebra* (https://openstax.org/books/prealgebra/pages/preface)
and *College Algebra* (https://openstax.org/books/college-algebra/pages/preface). Stored unchanged as test data;
redistribution is approved for these editions in `data/content_sources.json` (owner decision D-7).

Re-record (only when the archive version in `tool/build_open_content_index.py` changes):

    python tool/import_open_textbook.py --source openstax-prealgebra-1e --chapters 6 --sections 6.3 --record tool/tests/fixtures/openstax/prealgebra --out <tmp>
