"""Application-level search constraints shared by the agent and its wrapper."""

import os

DEFAULT_EXCLUDED_DOMAINS = (
    "x.com",
    "twitter.com",
    "reddit.com",
)
SEARCH_EXCLUDE_DOMAINS_ENV = "SEARCH_EXCLUDE_DOMAINS"


def excluded_search_domains() -> list[str]:
    """Return normalized domains that Tavily must omit from search results."""
    configured = os.environ.get(SEARCH_EXCLUDE_DOMAINS_ENV)
    domains = (
        configured.split(",") if configured is not None else DEFAULT_EXCLUDED_DOMAINS
    )

    normalized: list[str] = []
    for domain in domains:
        value = domain.strip().lower()
        if value and value not in normalized:
            normalized.append(value)
    return normalized
