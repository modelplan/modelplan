# SPDX-License-Identifier: MIT
"""Negative controls for the packaged-app assertion gate; no Swift, GUI or network."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('app_smoke', Path(__file__).with_name('check-app-smoke.py'))
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class AppSmokeAssertionsTests(unittest.TestCase):
    def setUp(self):
        self.helper = Path('/synthetic/Community.app/Contents/Helpers/modelplan')
        self.home = Path('/synthetic/home')
        self.report = {'schemaVersion': 1, 'dockHostType': 'ProductionDockHost',
                       'connectionServicePresent': True, 'connectionAvailable': True,
                       'firstRunConnectionStatus': 'Connection service is ready.',
                       'consentPortPresent': True, 'consentAPIAvailable': True,
                       'cliHelp': 'Usage:\n  modelplan consent --json\n', 'cliHelpExitCode': 0,
                       'cliSupportsConsentJSON': True, 'cliPath': str(self.helper), 'showDock': True, 'autoHide': True,
                       'edge': 'right', 'home': str(self.home), 'visibleWindows': 0}

    def results(self):
        return {name: bool(passed) for name, passed, _ in smoke.assertions(self.report, self.helper, self.home)}

    def test_complete_live_report_can_pass(self):
        self.assertTrue(all(self.results().values()))

    def test_missing_objects_do_not_pass_as_false_defaults(self):
        self.report.update(dockHostType=None, connectionServicePresent=False, connectionAvailable=False,
                           consentPortPresent=False, consentAPIAvailable=None, cliHelp='Usage: modelplan --help')
        result = self.results()
        for name in ['dock-host', 'connection-service', 'consent-port', 'consent-capability']:
            self.assertFalse(result[name], name)
        self.assertTrue(result['connection-availability'])

    def test_preview_and_self_test_hosts_are_rejected(self):
        for name in ['StaticDockPreviewHost', 'OfficialSelfTestDock', 'WindowProbe']:
            self.report['dockHostType'] = name
            self.assertFalse(self.results()['dock-host'], name)

    def test_raw_or_empty_status_is_rejected(self):
        for status in ['', None, 'unavailable', 'not_connected_yet', 'unavailable: unavailable']:
            self.report['firstRunConnectionStatus'] = status
            self.assertFalse(self.results()['first-run-status'], status)
        self.report['firstRunConnectionStatus'] = '连接服务不可用'
        self.assertTrue(self.results()['first-run-status'])

    def test_generic_help_cannot_invent_consent_support(self):
        for text in ['Usage of consent:\n --json', 'modelplan connect --json\n', 'consent is unavailable --json']:
            self.report['cliHelp'] = text
            self.assertFalse(self.results()['consent-capability'], text)
            self.assertFalse(self.results()['connection-availability'], text)

    def test_api_false_does_not_require_an_unimplemented_consent_command(self):
        self.report.update(consentAPIAvailable=False, cliHelp='modelplan connect --json\n')
        self.assertTrue(self.results()['consent-capability'])

    def test_helper_home_and_ui_are_observed_not_assumed(self):
        self.report.update(cliPath='/usr/local/bin/modelplan', home='/real/home', visibleWindows=1)
        for name in ['bundled-cli', 'synthetic-home', 'no-visible-ui']:
            self.assertFalse(self.results()[name], name)

    def test_reported_cli_capability_must_match_the_actual_help(self):
        self.report['cliSupportsConsentJSON'] = False
        self.assertFalse(self.results()['bundled-cli'])

    def test_missing_or_changed_defaults_fail(self):
        self.report.pop('showDock')
        self.assertFalse(self.results()['dock-defaults'])


if __name__ == '__main__':
    unittest.main()
