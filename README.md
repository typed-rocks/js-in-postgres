# What do we need for Zod to run

## A postgres database version 13 or later

## The plv8 extension installed on our postgres -> https://github.com/plv8/plv8
## Zod bundled into one runnable js file
```typescript
import {z} from 'zod';

globalThis.z = z;
```

```shell

npx esbuild src/index.js \
  --bundle \
  --outfile=bundle.js \
  --format=iife \
  --minify
```

## A way to store the lib
```sql
-- create a table like this: js_libraries(name text, source text)
insert into js_libraries('zod', $$
--Put the string from the bundle.js in here
$$);
```

## A way to load the lib
```sql
CREATE OR REPLACE FUNCTION require(lib_name text) RETURNS VOID as
$$
function require(lib_name) {
    const lib = plv8.execute("SELECT source from js_libraries where name = $1", [lib_name]);
    eval(lib[0].source);
}

return require(lib_name);
$$ LANGUAGE plv8 IMMUTABLE strict;
```

The you load it like this:

```sql
select require('zod');
```

Now `z` is available in your sql context.

## Example: A trigger which loads the library

```sql
DROP FUNCTION IF EXISTS validatePerson() CASCADE;

CREATE OR REPLACE FUNCTION validatePerson() RETURNS TRIGGER AS
$$
function validatePerson(NEW, OLD) {
    const require = plv8.find_function("require");
    require('zod');
    const person = z.object({
        firstname: z.string().min(3).max(20),
        lastname: z.string().min(3).max(20),
        email: z.string().email()
    })
    person.parse(NEW);
    return NEW;
}

return validatePerson(NEW, OLD)
$$ LANGUAGE plv8 IMMUTABLE
                 STRICT;

CREATE OR REPLACE TRIGGER trg_validate_person
    BEFORE INSERT OR UPDATE
    ON person
    FOR EACH ROW
EXECUTE FUNCTION validatePerson();
```


