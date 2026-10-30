import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import function_app


def test_required_env_returns_configured_value(monkeypatch):
    monkeypatch.setenv("SETTING", "configured")

    assert function_app._required_env("SETTING") == "configured"


@pytest.mark.parametrize("value", [None, ""])
def test_required_env_rejects_missing_or_empty_value(monkeypatch, value):
    if value is None:
        monkeypatch.delenv("SETTING", raising=False)
    else:
        monkeypatch.setenv("SETTING", value)

    with pytest.raises(ValueError, match="Missing required app setting: SETTING"):
        function_app._required_env("SETTING")


def test_blob_path_from_uri_decodes_container_and_blob_path():
    assert function_app._blob_path_from_uri(
        "https://sourceaccount.blob.core.windows.net/container%20name/folder/file%20name.txt"
    ) == ("sourceaccount", "container name", "folder/file name.txt")


@pytest.mark.parametrize(
    "blob_uri",
    [
        "https://sourceaccount.blob.core.windows.net/container",
        "https://sourceaccount.blob.core.windows.net/container/",
        "https://sourceaccount.blob.core.windows.net//blob",
    ],
)
def test_blob_path_from_uri_rejects_invalid_container_or_blob(blob_uri):
    with pytest.raises(ValueError, match="Unable to parse container and blob name"):
        function_app._blob_path_from_uri(blob_uri)


def test_move_blob_logs_and_returns_when_source_does_not_exist(caplog):
    credential = object()
    source_blob = MagicMock()
    source_blob.exists.return_value = False

    with (
        patch.object(function_app, "DefaultAzureCredential", return_value=credential),
        patch.object(function_app.BlobClient, "from_blob_url", return_value=source_blob),
        patch.object(function_app, "BlobServiceClient") as blob_service,
        caplog.at_level("ERROR"),
    ):
        function_app._move_blob(
            "https://sourceaccount.blob.core.windows.net/container/file.txt",
            "destinationaccount",
            "quarantine",
        )

    assert "Source blob does not exist" in caplog.text
    blob_service.assert_not_called()
    source_blob.download_blob.assert_not_called()
    source_blob.delete_blob.assert_not_called()


def test_move_blob_copies_then_deletes_source():
    credential = object()
    source_blob = MagicMock()
    source_blob.exists.return_value = True
    source_blob.blob_name = "folder/file.txt"
    download = source_blob.download_blob.return_value
    destination_blob = MagicMock()
    destination_service = MagicMock()
    destination_service.get_container_client.return_value.get_blob_client.return_value = (
        destination_blob
    )

    with (
        patch.object(function_app, "DefaultAzureCredential", return_value=credential),
        patch.object(function_app.BlobClient, "from_blob_url", return_value=source_blob) as source,
        patch.object(function_app, "BlobServiceClient", return_value=destination_service) as service,
    ):
        function_app._move_blob(
            "https://sourceaccount.blob.core.windows.net/container/folder/file.txt",
            "destinationaccount",
            "clean",
        )

    source.assert_called_once_with(
        "https://sourceaccount.blob.core.windows.net/container/folder/file.txt",
        credential=credential,
    )
    service.assert_called_once_with(
        account_url="https://destinationaccount.blob.core.windows.net",
        credential=credential,
    )
    destination_service.get_container_client.assert_called_once_with("clean")
    destination_service.get_container_client.return_value.get_blob_client.assert_called_once_with(
        "folder/file.txt"
    )
    destination_blob.upload_blob.assert_called_once_with(download.chunks.return_value, overwrite=True)
    source_blob.delete_blob.assert_called_once_with()


@pytest.fixture
def scan_settings(monkeypatch):
    monkeypatch.setenv("DEFENDER_STORAGE_ACCOUNT_NAME", "defenderaccount")
    monkeypatch.setenv("CLEAN_CONTAINER_NAME", "clean-scans")
    monkeypatch.setenv("QUARANTINE_CONTAINER_NAME", "quarantine-scans")


def test_process_scan_event_ignores_unsupported_event(caplog):
    with caplog.at_level("INFO"):
        function_app._process_scan_event({"eventType": "OtherEvent"})

    assert "Ignoring unsupported event type OtherEvent" in caplog.text


def test_process_scan_event_uses_legacy_event_and_data_keys(scan_settings):
    blob_uri = "https://sourceaccount.blob.core.windows.net/uploads/file.txt"
    event = {
        "EventType": function_app.ANTIMALWARE_SCAN_EVENT_TYPE,
        "Data": {"scanResultType": function_app.MALICIOUS_VERDICT, "blobUri": blob_uri},
    }

    with patch.object(function_app, "_move_blob") as move_blob:
        function_app._process_scan_event(event)

    move_blob.assert_called_once_with(blob_uri, "defenderaccount", "quarantine-scans")


@pytest.mark.parametrize(
    "event_data",
    [
        {},
        {"scanResultType": function_app.CLEAN_VERDICT},
    ],
)
def test_process_scan_event_rejects_missing_verdict_or_blob_uri(event_data):
    event = {"eventType": function_app.ANTIMALWARE_SCAN_EVENT_TYPE, "data": event_data}

    with pytest.raises(ValueError, match="Event data must include scanResultType and blobUri"):
        function_app._process_scan_event(event)


@pytest.mark.parametrize(
    ("missing_setting", "verdict"),
    [
        ("DEFENDER_STORAGE_ACCOUNT_NAME", function_app.MALICIOUS_VERDICT),
        ("CLEAN_CONTAINER_NAME", function_app.MALICIOUS_VERDICT),
        ("QUARANTINE_CONTAINER_NAME", function_app.CLEAN_VERDICT),
    ],
)
def test_process_scan_event_reports_missing_settings(
    scan_settings, monkeypatch, missing_setting, verdict
):
    monkeypatch.delenv(missing_setting)
    event = {
        "eventType": function_app.ANTIMALWARE_SCAN_EVENT_TYPE,
        "data": {
            "scanResultType": verdict,
            "blobUri": "https://sourceaccount.blob.core.windows.net/uploads/file.txt",
        },
    }

    with pytest.raises(ValueError, match=f"Missing required app setting: {missing_setting}"):
        function_app._process_scan_event(event)


def test_process_scan_event_routes_clean_verdict(scan_settings):
    blob_uri = "https://sourceaccount.blob.core.windows.net/uploads/file.txt"
    event = {
        "eventType": function_app.ANTIMALWARE_SCAN_EVENT_TYPE,
        "data": {"scanResultType": function_app.CLEAN_VERDICT, "blobUri": blob_uri},
    }

    with patch.object(function_app, "_move_blob") as move_blob:
        function_app._process_scan_event(event)

    move_blob.assert_called_once_with(blob_uri, "defenderaccount", "clean-scans")


def test_process_scan_event_logs_unknown_verdict_without_moving_blob(
    scan_settings, caplog
):
    event = {
        "eventType": function_app.ANTIMALWARE_SCAN_EVENT_TYPE,
        "data": {
            "scanResultType": "Unknown",
            "blobUri": "https://sourceaccount.blob.core.windows.net/uploads/file.txt",
        },
    }

    with patch.object(function_app, "_move_blob") as move_blob, caplog.at_level("INFO"):
        function_app._process_scan_event(event)

    assert "No action for scan result type: Unknown" in caplog.text
    move_blob.assert_not_called()


class QueueMessage:
    def __init__(self, body):
        self.body = body

    def get_body(self):
        return self.body


def test_queue_trigger_processes_single_event():
    event = {"eventType": "OtherEvent"}
    message = QueueMessage(json.dumps(event).encode("utf-8"))

    with patch.object(function_app, "_process_scan_event") as process:
        function_app.defender_scan_result(message)

    process.assert_called_once_with(event)


@pytest.mark.parametrize("events", [[], [{"eventType": "first"}, {"eventType": "second"}]])
def test_queue_trigger_processes_event_batches(events):
    message = QueueMessage(json.dumps(events).encode("utf-8"))

    with patch.object(function_app, "_process_scan_event") as process:
        function_app.defender_scan_result(message)

    assert [call.args[0] for call in process.call_args_list] == events


def test_queue_trigger_rejects_malformed_json():
    message = QueueMessage(b"{")

    with pytest.raises(json.JSONDecodeError):
        function_app.defender_scan_result(message)
