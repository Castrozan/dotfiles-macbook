import importlib
import time
from pathlib import Path
from unittest.mock import patch

application_launcher = importlib.import_module("application-launcher")


class TestDiscoverInstalledApplications:
    def test_discovers_app_bundles_from_directories(self, tmp_path):
        app_directory = tmp_path / "Applications"
        app_directory.mkdir()
        (app_directory / "Safari.app").mkdir()
        (app_directory / "Firefox.app").mkdir()
        (app_directory / "not-an-app.txt").touch()

        with patch.object(
            application_launcher,
            "APPLICATION_SEARCH_DIRECTORIES",
            [app_directory],
        ):
            result = application_launcher.discover_installed_applications()

        assert result == ["Firefox", "Safari"]

    def test_returns_empty_list_when_no_directories_exist(self):
        with patch.object(
            application_launcher,
            "APPLICATION_SEARCH_DIRECTORIES",
            [Path("/nonexistent/directory")],
        ):
            result = application_launcher.discover_installed_applications()

        assert result == []

    def test_deduplicates_applications_across_directories(self, tmp_path):
        directory_one = tmp_path / "Apps1"
        directory_two = tmp_path / "Apps2"
        directory_one.mkdir()
        directory_two.mkdir()
        (directory_one / "Safari.app").mkdir()
        (directory_two / "Safari.app").mkdir()

        with patch.object(
            application_launcher,
            "APPLICATION_SEARCH_DIRECTORIES",
            [directory_one, directory_two],
        ):
            result = application_launcher.discover_installed_applications()

        assert result == ["Safari"]


class TestFrecencySorting:
    def test_applications_with_history_appear_before_unknown(self):
        applications = ["Alfred", "Brave Browser", "Calendar"]
        history = {
            "Calendar": {"launch_count": 5, "last_launched_at": time.time()},
        }

        result = application_launcher.sort_applications_by_frecency(
            applications, history
        )

        assert result[0] == "Calendar"
        assert set(result[1:]) == {"Alfred", "Brave Browser"}

    def test_recently_launched_application_scores_higher(self):
        now = time.time()
        applications = ["App A", "App B"]
        history = {
            "App A": {"launch_count": 10, "last_launched_at": now - 30 * 86400},
            "App B": {"launch_count": 10, "last_launched_at": now},
        }

        result = application_launcher.sort_applications_by_frecency(
            applications, history
        )

        assert result[0] == "App B"

    def test_frequently_launched_application_scores_higher(self):
        now = time.time()
        applications = ["App A", "App B"]
        history = {
            "App A": {"launch_count": 2, "last_launched_at": now},
            "App B": {"launch_count": 50, "last_launched_at": now},
        }

        result = application_launcher.sort_applications_by_frecency(
            applications, history
        )

        assert result[0] == "App B"

    def test_empty_history_sorts_alphabetically(self):
        applications = ["Zed", "Alfred", "Bear"]

        result = application_launcher.sort_applications_by_frecency(applications, {})

        assert result == ["Alfred", "Bear", "Zed"]


class TestCalculateFrecencyScore:
    def test_recent_launch_has_higher_score(self):
        now = time.time()
        recent_entry = {"launch_count": 1, "last_launched_at": now}
        old_entry = {"launch_count": 1, "last_launched_at": now - 30 * 86400}

        recent_score = application_launcher.calculate_frecency_score(recent_entry)
        old_score = application_launcher.calculate_frecency_score(old_entry)

        assert recent_score > old_score

    def test_more_launches_means_higher_score(self):
        now = time.time()
        many_launches = {"launch_count": 100, "last_launched_at": now}
        few_launches = {"launch_count": 1, "last_launched_at": now}

        many_score = application_launcher.calculate_frecency_score(many_launches)
        few_score = application_launcher.calculate_frecency_score(few_launches)

        assert many_score > few_score


class TestLaunchHistory:
    def test_load_returns_empty_dict_when_file_missing(self, tmp_path):
        with patch.object(
            application_launcher,
            "LAUNCH_HISTORY_FILE_PATH",
            tmp_path / "nonexistent" / "history.json",
        ):
            result = application_launcher.load_launch_history()

        assert result == {}

    def test_save_and_load_roundtrip(self, tmp_path):
        history_file = tmp_path / "history.json"
        history = {"Safari": {"launch_count": 3, "last_launched_at": 1000.0}}

        with patch.object(
            application_launcher, "LAUNCH_HISTORY_FILE_PATH", history_file
        ):
            application_launcher.save_launch_history(history)
            loaded = application_launcher.load_launch_history()

        assert loaded == history

    def test_record_launch_increments_count(self, tmp_path):
        history_file = tmp_path / "history.json"
        history = {"Safari": {"launch_count": 3, "last_launched_at": 1000.0}}

        with patch.object(
            application_launcher, "LAUNCH_HISTORY_FILE_PATH", history_file
        ):
            application_launcher.record_application_launch_in_history(history, "Safari")

        assert history["Safari"]["launch_count"] == 4
        assert history["Safari"]["last_launched_at"] > 1000.0

    def test_record_launch_creates_new_entry(self, tmp_path):
        history_file = tmp_path / "history.json"
        history = {}

        with patch.object(
            application_launcher, "LAUNCH_HISTORY_FILE_PATH", history_file
        ):
            application_launcher.record_application_launch_in_history(
                history, "Firefox"
            )

        assert history["Firefox"]["launch_count"] == 1

    def test_load_handles_corrupted_json(self, tmp_path):
        history_file = tmp_path / "history.json"
        history_file.write_text("not valid json{{{")

        with patch.object(
            application_launcher, "LAUNCH_HISTORY_FILE_PATH", history_file
        ):
            result = application_launcher.load_launch_history()

        assert result == {}


class TestDisplayLineFormatting:
    def test_running_application_gets_indicator(self):
        result = application_launcher.build_display_line_for_application(
            "Safari", {"Safari", "Finder"}
        )

        assert result == "● Safari"

    def test_not_running_application_gets_space(self):
        result = application_launcher.build_display_line_for_application(
            "Firefox", {"Safari"}
        )

        assert result == "  Firefox"

    def test_extract_name_from_running_display_line(self):
        result = application_launcher.extract_application_name_from_display_line(
            "● Safari"
        )

        assert result == "Safari"

    def test_extract_name_from_not_running_display_line(self):
        result = application_launcher.extract_application_name_from_display_line(
            "  Firefox"
        )

        assert result == "Firefox"


class TestOpenApplicationWithNewWindow:
    @patch.object(application_launcher, "launch_application")
    @patch.object(
        application_launcher, "is_application_currently_running", return_value=False
    )
    def test_launches_application_when_not_running(self, mock_running, mock_launch):
        application_launcher.open_application_with_new_window_if_running("Safari")

        mock_launch.assert_called_once_with("Safari")

    @patch.object(
        application_launcher, "find_wezterm_binary", return_value="/usr/bin/wezterm"
    )
    @patch.object(
        application_launcher, "is_application_currently_running", return_value=True
    )
    @patch("subprocess.run")
    def test_uses_wezterm_start_for_wezterm(self, mock_run, mock_running, mock_find):
        application_launcher.open_application_with_new_window_if_running("WezTerm")

        mock_run.assert_called_once_with(["/usr/bin/wezterm", "start"], timeout=5)

    @patch.object(application_launcher, "open_new_window_via_applescript")
    @patch.object(
        application_launcher, "is_application_currently_running", return_value=True
    )
    def test_uses_applescript_for_browsers(self, mock_running, mock_applescript):
        application_launcher.open_application_with_new_window_if_running(
            "Brave Browser"
        )

        mock_applescript.assert_called_once_with("Brave Browser")

    @patch.object(application_launcher, "open_new_window_via_keystroke")
    @patch.object(
        application_launcher, "is_application_currently_running", return_value=True
    )
    def test_falls_back_to_keystroke_for_unknown_apps(
        self, mock_running, mock_keystroke
    ):
        application_launcher.open_application_with_new_window_if_running("SomeApp")

        mock_keystroke.assert_called_once_with("SomeApp")
