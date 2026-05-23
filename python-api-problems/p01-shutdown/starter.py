#!/usr/bin/env python3
"""
p01 — Shutdown the Server
Fill in the function body. Do not look at solution.py yet.
"""

import requests


def shutdown_server(base_url: str) -> dict:
    """
    POST to {base_url}/shutdown, parse JSON, return the dict.
    Handle connection drop gracefully.
    """
    # TODO: implement
    pass


def main():
    base_url = "http://localhost:8080"
    result = shutdown_server(base_url)
    # TODO: print result["status"] and result["message"]


if __name__ == "__main__":
    main()
