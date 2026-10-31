# SPDX-License-Identifier: MIT
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import macos_runner as mac
from contracts import digest, load_json, validate
from shape_home import build_home


class MacosHarnessTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix='u14-macos-test-')
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.home = self.root / 'home'
        self.baseline = build_home(load_json(ROOT/'examples/synthetic-shape.json'), self.home)

    def test_scenario_selection_rejects_unknown_duplicates_and_engine_ids(self):
        self.assertEqual(mac.select_scenarios('A01,A19'), ['A01', 'A19'])
        self.assertEqual(len(mac.select_scenarios('all')), 19)
        for value in ['A00', 'A20', 'U3-backpressure', 'A01,A01', 'A01;touch x', '']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                mac.select_scenarios(value)

    def test_synthetic_child_env_never_inherits_host_credentials_or_real_home(self):
        with mock.patch.dict(os.environ, {'HOME':'/owner', 'ANTHROPIC_API_KEY':'canary',
                                         'GITHUB_TOKEN':'canary', 'CODEX_HOME':'/owner/.codex'}):
            env = mac.child_environment(self.home)
        self.assertEqual(env['HOME'], str(self.home))
        self.assertEqual(env['CFFIXED_USER_HOME'], str(self.home))
        self.assertEqual(env['MODELPLAN_READERS'], 'off')
        self.assertEqual(env['MODELPLAN_NATIVE'], 'off')
        self.assertEqual(env['MODELPLAN_HISTORY'], 'off')
        self.assertFalse(any('canary' in value or '/owner' in value for value in env.values()))
        self.assertNotIn('GITHUB_TOKEN',env)

    def test_baseline_is_verified_before_any_launch(self):
        mac.verify_home(self.home,self.baseline)
        path=self.home/self.baseline['files'][0]['path']
        path.write_bytes(b'changed')
        with self.assertRaises(ValueError):mac.verify_home(self.home,self.baseline)

    def test_bundle_rejects_wrong_missing_or_linked_helper(self):
        app=self.root/'Community.app'
        for directory in ['Contents/MacOS','Contents/Helpers','Contents/Resources']:
            (app/directory).mkdir(parents=True,exist_ok=True)
        import plistlib
        (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable':'ModelPlanCommunity'}))
        executable=app/'Contents/MacOS/ModelPlanCommunity';executable.write_bytes(b'app');executable.chmod(0o700)
        helper=app/'Contents/Helpers/modelplan';helper.write_bytes(b'helper');helper.chmod(0o700)
        pin=app/'Contents/Resources/modelplan.sha256';pin.write_text(digest(b'helper')+'\n')
        self.assertEqual(mac.verify_app(app)[1],helper)
        pin.write_text('0'*64+'\n')
        with self.assertRaises(ValueError):mac.verify_app(app)
        pin.write_text(digest(b'helper')+'\n')
        helper.unlink();helper.symlink_to(executable)
        with self.assertRaises(ValueError):mac.verify_app(app)

    def test_all_UI_scenarios_stay_unsupported_despite_infrastructure_passes(self):
        report=self.root/'report.json';report.write_text('{}')
        checks=[{'id':'macos-ax','outcome':'pass','evidence':[str(report)]}]
        spec=mac.bundle_spec(self.root,self.baseline,['A01'],checks,None,None,report)
        self.assertEqual(len(spec['results']),19)
        self.assertTrue(all(item['outcome']=='unsupported' for item in spec['results']))
        self.assertNotIn('native-ui',spec['availableCapabilities'])
        self.assertNotIn('real-input',spec['availableCapabilities'])
        validate(spec,'candidate-input.schema.json')

    def test_non_macos_or_unadmitted_host_never_builds_or_launches(self):
        for system,env in [('Linux',{}),('Darwin',{})]:
            with self.subTest(system=system), mock.patch.object(mac.platform,'system',return_value=system), \
                    mock.patch.dict(os.environ,env,clear=True),mock.patch.object(mac,'build_app') as build, \
                    mock.patch.object(mac,'run_native') as native,mock.patch.object(mac,'generate_bundle') as bundle, \
                    mock.patch.object(mac,'git',side_effect=lambda repo,*args: '' if args[0]=='status' else 'a'*40):
                output=self.root/('run-'+system)
                bundle.return_value={'scenarios':[]}
                mac.run(output)
                build.assert_not_called();native.assert_not_called()
                spec=bundle.call_args.args[0]
                self.assertTrue(all(item['outcome']=='unsupported' for item in spec['results']))

    def test_probe_cannot_turn_foreign_PID_or_missing_capture_into_pass(self):
        for receipt in [
            {'schemaVersion':1,'pid':999,'ax':{'outcome':'pass'},'screenshot':{'outcome':'pass'}},
            {'schemaVersion':1,'pid':123,'ax':{'outcome':'pass'},'screenshot':{'outcome':'pass'}},
        ]:
            with self.assertRaises(ValueError):mac.probe_checks(receipt,123,self.root)

    def test_only_selected_registered_driver_can_report_an_evidenced_result(self):
        evidence=self.root/'assertion.json';evidence.write_text('{}')
        process=mock.Mock();process.poll.return_value=None
        context=mock.Mock(deadline=mac.time.monotonic()+30,process=process,work=self.root)
        chosen=mock.Mock(return_value={'outcome':'pass','evidence':[str(evidence)]})
        other=mock.Mock()
        with mock.patch.dict(mac.SCENARIO_DRIVERS,{'A01':chosen,'A02':other},clear=True):
            results=mac.drive_scenarios(context,['A01','A19'])
        chosen.assert_called_once_with(context);other.assert_not_called()
        self.assertEqual(set(results),{'A01'})
        report=self.root/'report.json';report.write_text('{}')
        spec=mac.bundle_spec(self.root,self.baseline,['A01'],[],None,None,report,results)
        self.assertEqual(spec['results'][0]['outcome'],'pass')
        self.assertTrue(all(r['outcome']=='unsupported' for r in spec['results'][1:]))
        chosen.return_value={'outcome':'pass','evidence':[]}
        with mock.patch.dict(mac.SCENARIO_DRIVERS,{'A01':chosen},clear=True),self.assertRaises(ValueError):
            mac.drive_scenarios(context,['A01'])

    def test_probe_rejects_foreign_descendant_even_when_root_PID_matches(self):
        from contracts import encoded
        (self.root/'ax-tree.json').write_bytes(encoded({'pid':123,'windows':[
            {'pid':123,'children':[{'pid':999}]}]}))
        receipt={'schemaVersion':1,'pid':123,'ax':{'outcome':'pass'},'screenshot':{'outcome':'unsupported'}}
        with self.assertRaises(ValueError):mac.probe_checks(receipt,123,self.root)

    def test_command_timeout_stops_only_owned_group_and_keeps_bounded_diagnostics(self):
        process=mock.Mock(pid=1234,stdout=__import__('io').BytesIO(b'build failed'))
        process.wait.side_effect=[mac.subprocess.TimeoutExpired(['build'],1),0]
        process.poll.return_value=None
        with mock.patch.object(mac.subprocess,'Popen',return_value=process),mock.patch.object(mac.os,'killpg') as kill:
            with self.assertRaises(mac.HarnessTimeout):
                mac.command(['build'],self.root,{},1,self.root/'build.log')
        kill.assert_called_once_with(1234,mac.signal.SIGTERM)
        self.assertEqual((self.root/'build.log').read_bytes(),b'build failed')

    def test_owned_group_cleanup_never_uses_global_kill(self):
        process=mock.Mock(pid=1234)
        process.poll.return_value=None
        with mock.patch.object(mac.os,'killpg') as kill:
            mac.stop_owned(process)
        self.assertEqual(kill.call_args_list,[mock.call(1234,mac.signal.SIGTERM)])
        process.wait.assert_called_once()

    def test_cleanup_still_stops_descendants_after_group_leader_exits(self):
        process=mock.Mock(pid=1234)
        process.poll.return_value=0
        with mock.patch.object(mac.os,'killpg') as kill:
            mac.stop_owned(process)
        kill.assert_called_once_with(1234,mac.signal.SIGTERM)

    def test_workflow_uses_only_ready_PRs_dispatch_and_hosted_macos(self):
        workflow=(ROOT.parent.parent/'.github/workflows/u14-macos.yml').read_text()
        self.assertIn('workflow_dispatch:',workflow)
        self.assertIn('ready_for_review',workflow)
        self.assertIn('!github.event.pull_request.draft',workflow)
        self.assertIn('tools/u14/**',workflow)
        self.assertIn('desktop/native/**',workflow)
        self.assertIn('runs-on: macos-latest',workflow)
        self.assertNotIn('self-hosted',workflow)
        self.assertIn('if: always()',workflow)
        self.assertIn('/bundle',workflow)

    def test_missing_approved_credential_artifact_stops_before_build(self):
        work=self.root/'missing-artifact-build';work.mkdir()
        with mock.patch.object(mac.credential_artifact,'acquire',side_effect=ValueError('approval missing')), \
                mock.patch.object(mac,'command') as command:
            with self.assertRaisesRegex(ValueError,'approval missing'):
                mac.build_app(work)
            command.assert_not_called()

    def test_build_keeps_its_owned_module_cache_writable(self):
        commands=[]
        def build_command(args,cwd,env,timeout,log):
            commands.append((args,env))
            if args[0]=='go':
                Path(args[args.index('-o')+1]).write_bytes(b'synthetic executable')
        work=self.root/'build';work.mkdir()
        binding={'environment':{'MODELPLAN_CREDENTIAL_AGENT_ARTIFACT':str(work/'verified-artifact'),
                                'MODELPLAN_CREDENTIAL_AGENT_SHA256':'b'*64}}
        with mock.patch.object(mac.credential_artifact,'acquire',return_value=binding), \
                mock.patch.object(mac,'command',side_effect=build_command), \
                mock.patch.object(mac,'verify_app'),mock.patch.object(mac,'git',return_value='a'*40), \
                mock.patch.dict(os.environ,{'GOFLAGS':'-race','GOMODCACHE':'/shared-cache',
                                           'GH_TOKEN':'synthetic-download-auth','GITHUB_TOKEN':'synthetic-download-auth'}):
            mac.build_app(work)
        go_commands=[(args,env) for args,env in commands if args[0]=='go']
        self.assertEqual(len(go_commands),2)
        for args,env in go_commands:
            self.assertIn('-modcacherw',env['GOFLAGS'].split())
            self.assertEqual(env['GOMODCACHE'],str(work/'go-mod'))
        self.assertEqual({env['GOARCH'] for args,env in go_commands},{'arm64','amd64'})
        package=next(env for args,env in commands if args[0]=='bash')
        self.assertEqual(package['MODELPLAN_CREDENTIAL_AGENT_SHA256'],'b'*64)
        self.assertEqual(package['MODELPLAN_CREDENTIAL_AGENT_ARTIFACT'],str(work/'verified-artifact'))
        for _,env in commands:
            self.assertNotIn('GH_TOKEN',env)
            self.assertNotIn('GITHUB_TOKEN',env)

    def test_cleanup_failure_is_separate_from_already_uploaded_scenario_evidence(self):
        import json
        import subprocess
        import textwrap
        workflow=(ROOT.parent.parent/'.github/workflows/u14-macos.yml').read_text()
        name="      - name: Remove this job's generated scratch"
        self.assertLess(workflow.index('uses: actions/upload-artifact@v4'),workflow.index(name))
        harness=workflow.split('      - name: Build actual bundle',1)[1].split('      - name: Preserve only',1)[0]
        self.assertNotIn('continue-on-error:',harness)
        step=workflow.split(name,1)[1]
        self.assertIn('if: always()',step)
        self.assertIn('continue-on-error: true',step)
        run=step.split('        run: ',1)[1]
        script=textwrap.dedent(run[2:]) if run.startswith('|\n') else run.splitlines()[0]
        bundle=self.root/'.tmp/u14-macos/bundle';bundle.mkdir(parents=True)
        manifest=bundle/'manifest.json'
        original=json.dumps({'scenarios':[{'id':'A01','outcome':'unsupported'}]}).encode()
        manifest.write_bytes(original)
        tools=self.root/'cleanup-bin';tools.mkdir()
        remove=tools/'rm';remove.write_text('#!/bin/sh\nexit 73\n');remove.chmod(0o700)
        summary=self.root/'job-summary.md'
        result=subprocess.run(['bash','-e','-c',script],capture_output=True,text=True,
                              env={'PATH':str(tools)+':/usr/bin:/bin','GITHUB_WORKSPACE':str(self.root),
                                   'GITHUB_STEP_SUMMARY':str(summary)})
        self.assertEqual(result.returncode,1)
        self.assertIn('::warning',result.stdout)
        self.assertIn('cleanup',summary.read_text())
        self.assertIn('failed',summary.read_text())
        self.assertEqual(manifest.read_bytes(),original)
