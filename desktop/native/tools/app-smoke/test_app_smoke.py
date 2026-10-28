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
                       'dockHostPurpose': 'production', 'connectionServicePresent': True, 'connectionServiceBound': True,
                       'connectionAvailable': True, 'connectionBackendAvailable': True,
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
        self.report.update(dockHostType=None, dockHostPurpose=None, connectionServicePresent=False,
                           connectionServiceBound=False, connectionAvailable=False, connectionBackendAvailable=False,
                           consentPortPresent=False, consentAPIAvailable=None, cliHelp='Usage: modelplan --help')
        result = self.results()
        for name in ['dock-host', 'connection-service', 'consent-port', 'consent-capability']:
            self.assertFalse(result[name], name)
        self.assertTrue(result['connection-availability'])

    def test_historical_type_names_do_not_override_production_purpose(self):
        for name in ['StaticDockPreviewHost', 'OfficialSelfTestDock', 'WindowProbe']:
            with self.subTest(name=name):
                self.report['dockHostType'] = name
                self.assertTrue(all(self.results().values()))

    def test_self_test_or_missing_purpose_cannot_claim_production(self):
        for purpose in ['selfTest', 'preview', 'unknown', None, True]:
            with self.subTest(purpose=purpose):
                self.report['dockHostPurpose'] = purpose
                self.assertFalse(self.results()['dock-host'])

    def test_a_missing_host_cannot_claim_production_purpose(self):
        self.report['dockHostType'] = None
        self.assertFalse(self.results()['dock-host'])

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
        self.report.update(connectionServicePresent=True, connectionServiceBound=True,
                           connectionAvailable=False, connectionBackendAvailable=False,
                           consentPortPresent=True, consentAPIAvailable=False,
                           cliHelp='modelplan connect --json\n', cliSupportsConsentJSON=False)
        self.assertTrue(all(self.results().values()), self.results())

    def test_unverified_installed_backend_can_decline_an_advertised_api(self):
        self.report.update(connectionAvailable=False, connectionBackendAvailable=False, consentAPIAvailable=False)
        self.assertTrue(all(self.results().values()))

    def test_controller_availability_must_match_its_bound_backend(self):
        self.report['connectionBackendAvailable'] = False
        self.assertFalse(self.results()['connection-availability'])

    def test_wrong_backend_cannot_pass_as_a_bound_service(self):
        self.report['connectionServiceBound'] = False
        self.assertFalse(self.results()['connection-service'])

    def test_claimed_availability_requires_an_advertised_cli_api(self):
        self.report.update(consentAPIAvailable=False, cliHelp='modelplan connect --json\n', cliSupportsConsentJSON=False)
        self.assertFalse(self.results()['connection-availability'])
        self.report['consentAPIAvailable'] = True
        self.assertFalse(self.results()['consent-capability'])

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
