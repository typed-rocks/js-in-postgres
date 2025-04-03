/**
// index.js
import {z} from 'zod';

globalThis.z = z;

// use esbuild to bundle it:
npx esbuild src/index.js \
  --bundle \
  --outfile=bundle.js \
  --format=iife \
  --minify

*/

-- The function to load the source code
CREATE OR REPLACE FUNCTION require(lib_name text) RETURNS VOID as
$$
function require(lib_name) {
    const lib = plv8.execute("SELECT source from js_libraries where name = $1", [lib_name]);
    eval(lib[0].source);
}

return require(lib_name);
$$ LANGUAGE plv8 IMMUTABLE strict;

--Validate Function
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

INSERT INTO person values ('John', 'Doe', 'test@gmail.com');
