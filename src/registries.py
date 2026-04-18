from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger(__name__)

DOCKER_HUB_ALIASES = {"docker.io", "index.docker.io", "registry-1.docker.io"}

_TAG_DIGEST_RE = re.compile(r"^(?P<path>.+?)(?:(?P<sep>[:@])(?P<ref>[^/]+))?$")


@dataclass(frozen=True)
class RegistryRule:
    host: str
    ecr_prefix: str
    dockerhub: bool = False


@dataclass
class Rewriter:
    aws_account_id: str
    aws_region: str
    rules: list[RegistryRule] = field(default_factory=list)

    @property
    def ecr_host(self) -> str:
        return f"{self.aws_account_id}.dkr.ecr.{self.aws_region}.amazonaws.com"

    def _find_rule(self, host: str) -> Optional[RegistryRule]:
        for rule in self.rules:
            if rule.dockerhub and host in DOCKER_HUB_ALIASES:
                return rule
            if rule.host == host:
                return rule
        return None

    def rewrite(self, image: str) -> Optional[str]:
        if not image:
            return None

        host, path, ref_suffix = _split_image(image)

        if host is None:
            dockerhub_rule = next((r for r in self.rules if r.dockerhub), None)
            if dockerhub_rule is None:
                return None
            if "/" not in path:
                path = f"library/{path}"
            return f"{self.ecr_host}/{dockerhub_rule.ecr_prefix}/{path}{ref_suffix}"

        rule = self._find_rule(host)
        if rule is None:
            return None

        if rule.dockerhub and "/" not in path:
            path = f"library/{path}"

        return f"{self.ecr_host}/{rule.ecr_prefix}/{path}{ref_suffix}"

    def rule_for(self, image: str) -> Optional[RegistryRule]:
        host, _, _ = _split_image(image)
        if host is None:
            return next((r for r in self.rules if r.dockerhub), None)
        return self._find_rule(host)


def _split_image(image: str) -> tuple[Optional[str], str, str]:
    """Return (host, path, ref_suffix). ref_suffix includes leading ':' or '@' when present."""
    first, _, rest = image.partition("/")
    if rest and _looks_like_host(first):
        host = first
        remainder = rest
    else:
        host = None
        remainder = image

    digest_idx = remainder.find("@")
    if digest_idx != -1:
        return host, remainder[:digest_idx], remainder[digest_idx:]

    last_slash = remainder.rfind("/")
    tag_idx = remainder.find(":", last_slash + 1)
    if tag_idx != -1:
        return host, remainder[:tag_idx], remainder[tag_idx:]

    return host, remainder, ""


def _looks_like_host(segment: str) -> bool:
    return "." in segment or ":" in segment or segment == "localhost"


def load_rules(raw: list[dict]) -> list[RegistryRule]:
    rules: list[RegistryRule] = []
    for entry in raw:
        host = entry.get("host")
        prefix = entry.get("ecr_prefix")
        if not host or not prefix:
            logger.warning("Skipping registry entry missing host/ecr_prefix: %s", entry)
            continue
        rules.append(
            RegistryRule(
                host=host,
                ecr_prefix=prefix,
                dockerhub=bool(entry.get("dockerhub", False)),
            )
        )
    return rules


DEFAULT_RULES: list[dict] = [
    {"host": "docker.io", "ecr_prefix": "docker.io", "dockerhub": True},
    {"host": "quay.io", "ecr_prefix": "quay.io"},
    {"host": "ghcr.io", "ecr_prefix": "ghcr.io"},
    {"host": "registry.gitlab.com", "ecr_prefix": "registry.gitlab.com"},
    {"host": "cgr.dev", "ecr_prefix": "cgr.dev"},
]
