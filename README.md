# edge-functions
##Edge functions in NodeJS for the Mediverse sync layer
- These functions in the psql-functions folder are the postgres PLPGSQL functions that run the sync in Mediverse. The NodeJs functions are not here but moved to the `functions-container` repo for clear separation - JS from SQL.

## Collaborative editing via CRDT
- For collaborative editing and character-level CRDT merging, you need to register every column that needs such along with their table name into a `rich_text_columns` table defined as something like this:
- ```sql
  CREATE TABLE public.rich_text_columns (
  table_name  text,
  column_name text,
  PRIMARY KEY (table_name, column_name)
);

-- Then you register the columns that need character-level merging like so (e.g. title and content columns of a `blog_posts` table)
INSERT INTO public.rich_text_columns VALUES
  ('blog_posts', 'title'),
  ('blog_posts', 'content');

  ```
