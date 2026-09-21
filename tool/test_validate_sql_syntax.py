"""2026-09-21: offline %ROWTYPE false-positive regression; not DB semantics."""
import tempfile
import unittest
from pathlib import Path
from validate_sql_syntax import check


class RowtypeSyntaxTests(unittest.TestCase):
    def validate(self, body):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'fixture.sql'
            path.write_text(body)
            return check(path)

    source='''CREATE FUNCTION public.synthetic_rowtype() RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  profile public.profiles%ROWTYPE;
BEGIN
  SELECT * INTO profile FROM public.profiles LIMIT 1;
  profile.full_name := 'Synthetic';
  IF profile.full_name IS NULL THEN RETURN; END IF;
END;
$$;'''

    def test_catalog_independent_procedural_structure(self):
        self.assertEqual(self.validate(self.source),[])

    def test_missing_end_if_is_still_rejected(self):
        self.assertTrue(self.validate(self.source.replace('END IF;','')))

    def test_top_level_sql_is_not_normalized_away(self):
        self.assertTrue(self.validate(self.source+'\nALTER TABLE ;'))


if __name__=='__main__':
    unittest.main()
