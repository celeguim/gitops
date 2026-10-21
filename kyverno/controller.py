#!/usr/bin/env python3
"""
Revocation Controller
Monitors running Pods and checks cosign attestations.
If a Pod's image has approved: false, annotates the Pod and creates a Kubernetes Event.
"""

import os
import json
import time
import logging
import subprocess
import datetime
from typing import Optional

from kubernetes import client, config, watch
from kubernetes.client.rest import ApiException

# ── Logging ────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("revocation-controller")

# ── Config ─────────────────────────────────────────────────────────────────────
NAMESPACE = os.getenv("WATCH_NAMESPACE", "cosign-poc")  # "" = all namespaces
KMS_KEY = os.getenv(
    "KMS_KEY",
    "awskms:///arn:aws:kms:us-east-1:785212834098:key/4f9d8c0f-cc9b-4408-820d-452d04a4c40f",
)
KMS_KEY="C:\\Temp\\awskms.pub"
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "60"))  # seconds
ANNOTATION_KEY = "digio.com.br/attestation-status"
ANNOTATION_REASON = "digio.com.br/attestation-reason"
CONTROLLER_NAME = "revocation-controller"


# ── Cosign helpers ─────────────────────────────────────────────────────────────


def get_attestation(image_ref: str) -> Optional[dict]:
    """
    Runs cosign verify-attestation and returns the most recent predicate payload.
    Returns None if verification fails or no attestation found.
    """
    cmd = [
        "C:\\Temp\\cosign-windows-amd64.exe",
        "verify-attestation",
        "--key",
        KMS_KEY,
        "--type",
        "custom",
        "--output",
        "json",
        image_ref,
    ]

    ecr_login = [
        "aws",
        "ecr",
        "get-login-password",
        "--region",
        "sa-east-1",
        "--profile",
        "UAT_NPRD-Infraestrutura_SSO-785212834098"
    ]

    docker_login = [
        "docker",
        "login",
        "--username",
        "AWS",
        "--password-stdin",
        "584539243974.dkr.ecr.sa-east-1.amazonaws.com",
    ]

    try:

        # aws ecr get-login-password \
        #   --region sa-east-1 | docker login --username AWS \
        #   --password-stdin 584539243974.dkr.ecr.sa-east-1.amazonaws.com
        result = subprocess.run(
            ecr_login,
            capture_output=True,
            text=True,
            timeout=30,
        )

        print("ecr_login", result)
        senha_ecr = result.stdout.strip()

        result = subprocess.run(
            docker_login,
            input=senha_ecr,
            capture_output=True,
            text=True,
            timeout=30,
        )

        print("docker_login", result)

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
        )

        if result.returncode != 0:
            log.warning(f"cosign failed for {image_ref}: {result.stderr.strip()}")
            return None

        # Output is one JSON object per line; take the last (most recent)
        lines = [l.strip() for l in result.stdout.strip().splitlines() if l.strip()]
        if not lines:
            return None

        last = json.loads(lines[-1])
        payload_b64 = last.get("payload", "")
        if not payload_b64:
            return None

        import base64

        payload = json.loads(base64.b64decode(payload_b64 + "==").decode())
        predicate = payload.get("predicate", {})

        # Data may be a JSON string or already a dict
        data = predicate.get("Data", predicate)
        if isinstance(data, str):
            data = json.loads(data)

        return data

    except subprocess.TimeoutExpired:
        log.error(f"cosign timed out for {image_ref}")
        return None
    except Exception as e:
        log.error(f"Error checking attestation for {image_ref}: {e}")
        return None


def is_revoked(data: dict) -> tuple[bool, str]:
    """
    Returns (revoked, reason).
    revoked=True if approved is False.
    """
    approved = data.get("approved", True)
    reason = data.get("reason", "No reason provided")
    return (not approved), reason


# ── Kubernetes helpers ─────────────────────────────────────────────────────────


def annotate_pod(
    v1: client.CoreV1Api, pod_name: str, namespace: str, status: str, reason: str
):
    """Patches Pod annotations with revocation status."""
    body = {
        "metadata": {
            "annotations": {
                ANNOTATION_KEY: status,
                ANNOTATION_REASON: reason,
            }
        }
    }
    try:
        v1.patch_namespaced_pod(pod_name, namespace, body)
        log.info(f"Annotated pod {namespace}/{pod_name} → {status}")
    except ApiException as e:
        log.error(f"Failed to annotate pod {namespace}/{pod_name}: {e}")


def create_event(
    v1: client.CoreV1Api,
    pod: client.V1Pod,
    reason: str,
    message: str,
    event_type: str = "Warning",
):
    """Creates a Kubernetes Event linked to the Pod."""
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    namespace = pod.metadata.namespace
    pod_name = pod.metadata.name

    event = client.CoreV1Event(
        metadata=client.V1ObjectMeta(
            name=f"{pod_name}.revocation.{int(time.time())}",
            namespace=namespace,
        ),
        involved_object=client.V1ObjectReference(
            api_version="v1",
            kind="Pod",
            name=pod_name,
            namespace=namespace,
            uid=pod.metadata.uid,
        ),
        reason=reason,
        message=message,
        type=event_type,
        event_time=None,
        first_timestamp=now,
        last_timestamp=now,
        reporting_component=CONTROLLER_NAME,
        reporting_instance=CONTROLLER_NAME,
        action="AttestationRevoked",
        source=client.V1EventSource(component=CONTROLLER_NAME),
        count=1,
    )
    try:
        v1.create_namespaced_event(namespace, event)
        log.info(f"Event created for pod {namespace}/{pod_name}: {message}")
    except ApiException as e:
        log.error(f"Failed to create event for {namespace}/{pod_name}: {e}")


# ── Main loop ──────────────────────────────────────────────────────────────────


def get_pod_images(pod: client.V1Pod) -> list[str]:
    """Returns all unique image refs (with digest when available) from a Pod."""
    images = []
    statuses = pod.status.container_statuses or []
    for cs in statuses:
        # Prefer imageID (contains digest) over image (may be tag)
        img = cs.image_id or cs.image
        # imageID often has docker-pullable:// prefix
        img = img.replace("docker-pullable://", "").strip()
        if img:
            images.append(img)
    return list(set(images))


def already_processed(pod: client.V1Pod) -> bool:
    """Skip pods already annotated as revoked to avoid re-processing."""
    annotations = pod.metadata.annotations or {}
    return annotations.get(ANNOTATION_KEY) == "revoked"


def check_pods(v1: client.CoreV1Api):
    """Iterates all running Pods and checks attestations."""
    try:
        if NAMESPACE:
            pods = v1.list_namespaced_pod(
                NAMESPACE, field_selector="status.phase=Running"
            ).items
        else:
            pods = v1.list_pod_for_all_namespaces(
                field_selector="status.phase=Running"
            ).items
    except ApiException as e:
        log.error(f"Failed to list pods: {e}")
        return

    log.info(f"Checking {len(pods)} running pod(s)...")

    for pod in pods:
        pod_name = pod.metadata.name
        namespace = pod.metadata.namespace

        if already_processed(pod):
            log.debug(f"Skipping already-revoked pod {namespace}/{pod_name}")
            continue

        images = get_pod_images(pod)
        if not images:
            log.debug(f"No images found for pod {namespace}/{pod_name}")
            continue

        for image in images:
            log.info(f"Checking {namespace}/{pod_name} → {image}")
            data = get_attestation(image)

            if data is None:
                log.warning(
                    f"No attestation found for {image} in {namespace}/{pod_name}"
                )
                continue

            revoked, reason = is_revoked(data)

            if revoked:
                log.warning(f"REVOKED: {namespace}/{pod_name} ({image}) — {reason}")
                annotate_pod(v1, pod_name, namespace, "revoked", reason)
                create_event(
                    v1,
                    pod,
                    reason="AttestationRevoked",
                    message=f"Image {image} attestation revoked: {reason}",
                )
            else:
                log.info(f"OK: {namespace}/{pod_name} ({image})")
                # Update annotation to approved if not yet set
                annotations = pod.metadata.annotations or {}
                if ANNOTATION_KEY not in annotations:
                    annotate_pod(v1, pod_name, namespace, "approved", "")


def main():
    log.info("Starting Revocation Controller")
    log.info(f"  WATCH_NAMESPACE : {NAMESPACE or 'all'}")
    log.info(f"  POLL_INTERVAL   : {POLL_INTERVAL}s")
    log.info(
        f"  KMS_KEY         : {KMS_KEY[:40]}..." if KMS_KEY else "  KMS_KEY: NOT SET"
    )

    # Load kubeconfig (in-cluster or local)
    try:
        config.load_incluster_config()
        log.info("Running in-cluster")
    except config.ConfigException:
        config.load_kube_config()
        log.info("Running with local kubeconfig")

    v1 = client.CoreV1Api()

    while True:
        try:
            check_pods(v1)
        except Exception as e:
            log.error(f"Unexpected error in check loop: {e}", exc_info=True)

        log.info(f"Sleeping {POLL_INTERVAL}s...")
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()


