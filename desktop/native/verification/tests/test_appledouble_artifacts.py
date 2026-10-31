# SPDX-License-Identifier: MIT
"""Transport metadata must not become a schema, receipt or inventory member."""
import hashlib,json,shutil,subprocess,sys,tempfile,unittest
from pathlib import Path

V=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(V),str(V/'U6'),str(V/'bin')]
import receipt_schema
import synthetic_batch as sb

MAGIC=b'\x00\x05\x16\x07'

class AppleDoubleArtifactTests(unittest.TestCase):
    def test_seed_digest_and_copy_ignore_metadata_only(self):
        import homeseed
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);seed=root/'home-seed';seed.mkdir();(seed/'x.json').write_text('{}')
            before=homeseed.tree_sha256(seed)
            (seed/'._x.json').write_bytes(MAGIC);(seed/'._metadata').mkdir();(seed/'._metadata/y.json').write_bytes(MAGIC)
            self.assertEqual(homeseed.tree_sha256(seed),before)
            home=root/'home';home.mkdir()
            homeseed.copy_into(dict(syntheticHome=str(home),syntheticHomeSeed=str(seed),syntheticHomeSeedSHA256=before),home)
            self.assertEqual([p.name for p in home.iterdir()],['x.json'])
    def test_schema_loader_ignores_appledouble_but_not_real_corruption(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)/'schemas';shutil.copytree(receipt_schema.ROOT,root)
            baseline=receipt_schema.Registry(root)
            (root/'._common.json').write_bytes(MAGIC)
            (root/'native/._refresh.json').write_bytes(MAGIC+b'\xff')
            self.assertEqual(receipt_schema.Registry(root).documents,baseline.documents)
            (root/'broken.json').write_bytes(MAGIC)
            with self.assertRaises(ValueError):receipt_schema.Registry(root)

    def test_real_final_entry_and_inventory_unchanged_with_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);clone=root/'kit'
            for name in ('bin','U6'):
                shutil.copytree(V/name,clone/'desktop/native/verification'/name,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
            helper=V/'artifact_paths.py'
            if helper.exists():shutil.copy2(helper,clone/'desktop/native/verification/artifact_paths.py')
            schemas=clone/'schema/verification';shutil.copytree(receipt_schema.ROOT,schemas)
            args=sb.kit_batch(sb.context(),sb.valid().files(),root/'run');batch=Path(args[3])
            def run():
                final=subprocess.run([sys.executable,'-B',str(clone/'desktop/native/verification/bin/evidence-u6.py'),*args],capture_output=True,text=True)
                self.assertEqual(final.returncode,0,final.stderr)
                inventory=subprocess.run([sys.executable,'-B',str(clone/'desktop/native/verification/U6/inventory_evidence.py'),'--config',args[1]],capture_output=True,text=True)
                self.assertEqual(inventory.returncode,0,inventory.stderr)
                return json.loads(final.stdout),{n:(batch/n).read_bytes() for n in ('manifest.json','README.md','filelist.txt')}
            baseline=run();self.assertEqual(baseline[0]['outcome'],'pass')
            for name in baseline[1]:(batch/name).unlink() # only this test's generated outputs
            (schemas/'native/._refresh.json').write_bytes(MAGIC+b'\xff')
            (batch/'._x.json').write_bytes(MAGIC)
            (batch/'._launch-cleanup.json').write_bytes(MAGIC+b'\xff')
            self.assertEqual(run(),baseline)

    def test_kit_verification_ignores_only_transport_metadata(self):
        import importlib.util
        spec=importlib.util.spec_from_file_location('appledouble_kit_guard',V/'U6/verify_kit.py')
        guard=importlib.util.module_from_spec(spec);spec.loader.exec_module(guard)
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);payload=b'public synthetic payload'
            (root/'payload.txt').write_bytes(payload)
            digest=hashlib.sha256(payload).hexdigest()
            (root/'manifest.json').write_text(json.dumps(dict(sourceHead='a'*40,files=[dict(path='payload.txt',sha256=digest,size=len(payload))])))
            (root/'filelist.txt').write_text(''.join(hashlib.sha256((root/n).read_bytes()).hexdigest()+'  '+n+'\n' for n in ('manifest.json','payload.txt')))
            baseline=guard.verify(root)
            (root/'._payload.txt').write_bytes(MAGIC)
            self.assertEqual(guard.verify(root),baseline)
            (root/'orphan.txt').write_bytes(payload)
            with self.assertRaises(ValueError):guard.verify(root)

if __name__=='__main__':unittest.main()
