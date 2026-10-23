import json
import logging
import os
from urllib.parse import unquote, urlparse

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobClient, BlobServiceClient

app = func.FunctionApp()

ANTIMALWARE_SCAN_EVENT_TYPE = "Microsoft.Security.MalwareScanningResult"
MALICIOUS_VERDICT = "Malicious"
CLEAN_VERDICT = "No threats found"


def _required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise ValueError(f"Missing required app setting: {name}")
    return value


def _blob_path_from_uri(blob_uri: str) -> tuple[str, str, str]:
    parsed = urlparse(blob_uri)
    account_name = parsed.hostname.split(".")[0]
    path_parts = unquote(parsed.path.lstrip("/")).split("/", 1)
    if len(path_parts) != 2 or not path_parts[0] or not path_parts[1]:
        raise ValueError(f"Unable to parse container and blob name from URI: {blob_uri}")
    return account_name, path_parts[0], path_parts[1]


def _move_blob(
    source_blob_uri: str,
    destination_account_name: str,
    destination_container_name: str,
) -> None:
    credential = DefaultAzureCredential()
    source_blob = BlobClient.from_blob_url(source_blob_uri, credential=credential)

    if not source_blob.exists():
        logging.error("Source blob does not exist: %s", source_blob_uri)
        return

    destination_service = BlobServiceClient(
        account_url=f"https://{destination_account_name}.blob.core.windows.net",
        credential=credential,
    )
    destination_container = destination_service.get_container_client(destination_container_name)
    destination_blob = destination_container.get_blob_client(source_blob.blob_name)

    logging.info(
        "Copying blob from %s to %s/%s/%s",
        source_blob_uri,
        destination_account_name,
        destination_container_name,
        source_blob.blob_name,
    )
    download = source_blob.download_blob()
    destination_blob.upload_blob(download.chunks(), overwrite=True)

    logging.info("Deleting source blob %s", source_blob_uri)
    source_blob.delete_blob()
    logging.info("Blob move completed")


def _process_scan_event(event: dict) -> None:
    event_type = event.get("eventType") or event.get("EventType")
    if event_type != ANTIMALWARE_SCAN_EVENT_TYPE:
        logging.info(
            "Ignoring unsupported event type %s (expected %s)",
            event_type,
            ANTIMALWARE_SCAN_EVENT_TYPE,
        )
        return

    event_data = event.get("data") or event.get("Data") or {}
    verdict = event_data.get("scanResultType")
    blob_uri = event_data.get("blobUri")

    if not verdict or not blob_uri:
        raise ValueError("Event data must include scanResultType and blobUri")

    source_account, source_container, blob_name = _blob_path_from_uri(blob_uri)
    logging.info(
        "Received malware scan result for %s/%s/%s: %s",
        source_account,
        source_container,
        blob_name,
        verdict,
    )

    destination_account = _required_env("DEFENDER_STORAGE_ACCOUNT_NAME")
    clean_container = _required_env("CLEAN_CONTAINER_NAME")
    quarantine_container = _required_env("QUARANTINE_CONTAINER_NAME")

    if verdict == MALICIOUS_VERDICT:
        _move_blob(blob_uri, destination_account, quarantine_container)
        return

    if verdict == CLEAN_VERDICT:
        _move_blob(blob_uri, destination_account, clean_container)
        return

    logging.info("No action for scan result type: %s", verdict)


@app.function_name(name="defender_scan_result")
@app.queue_trigger(
    arg_name="msg",
    queue_name="%DEFENDER_SCAN_RESULTS_QUEUE%",
    connection="AzureWebJobsStorage",
)
def defender_scan_result(msg: func.QueueMessage) -> None:
    payload = json.loads(msg.get_body().decode("utf-8"))

    # Event Grid may deliver a single event object or a batch list.
    if isinstance(payload, list):
        for event in payload:
            _process_scan_event(event)
        return

    _process_scan_event(payload)
