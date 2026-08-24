#!/usr/bin/env python3
"""Produce a deterministic audit packet for January Swift SDK GitBook docs."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote


DOCS_REL = Path("Documentation/GitBook")
PUBLIC_SOURCE_REL = Path("Sources/JanuaryPartnerSDK")
RELEVANT_PREFIXES = (
    "Sources/JanuaryPartnerSDK/",
    "Tests/JanuaryPartnerSDKTests/",
    "Examples/JanuaryPartnerDemo/",
    "Documentation/GitBook/",
    "Contract/sdk-vocabulary.json",
    "Package.swift",
    "README.md",
)
PUBLIC_DECLARATION = re.compile(
    r"^\s*public\s+(?:final\s+)?"
    r"(struct|class|enum|protocol|actor|typealias|func|var|let|subscript)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)"
)
PUBLIC_METHOD = re.compile(r"^\s*public\s+func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
MARKDOWN_LINK = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
SUMMARY_LINK = re.compile(r"\[[^\]]+\]\(([^)#]+)(?:#[^)]*)?\)")


def git(repo: Path, *args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=repo,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout.strip()


def lines(value: str) -> set[str]:
    return {line.strip() for line in value.splitlines() if line.strip()}


def remote_default(repo: Path) -> str:
    value = git(repo, "symbolic-ref", "--short", "refs/remotes/origin/HEAD", check=False)
    if value:
        return value
    if git(repo, "rev-parse", "--verify", "origin/main", check=False):
        return "origin/main"
    raise RuntimeError("Cannot resolve the live remote default branch; fetch origin first.")


def choose_base(repo: Path, explicit: str | None, default_ref: str, branch: str) -> str:
    if explicit:
        git(repo, "rev-parse", "--verify", explicit)
        return explicit

    default_branch = default_ref.rsplit("/", 1)[-1]
    if branch and branch != default_branch:
        return git(repo, "merge-base", default_ref, "HEAD")

    last_docs_commit = git(
        repo,
        "log",
        "-1",
        "--format=%H",
        "--",
        DOCS_REL.as_posix(),
        check=False,
    )
    return last_docs_commit or default_ref


def changed_files(repo: Path, base: str) -> list[str]:
    changed: set[str] = set()
    changed |= lines(git(repo, "diff", "--name-only", f"{base}...HEAD", check=False))
    changed |= lines(git(repo, "diff", "--name-only", check=False))
    changed |= lines(git(repo, "diff", "--cached", "--name-only", check=False))
    changed |= lines(git(repo, "ls-files", "--others", "--exclude-standard", check=False))
    return sorted(changed)


def relevant(path: str) -> bool:
    return any(path == prefix or path.startswith(prefix) for prefix in RELEVANT_PREFIXES)


def public_declarations(repo: Path, files: list[str]) -> list[str]:
    findings: list[str] = []
    for relative in files:
        if not relative.startswith(f"{PUBLIC_SOURCE_REL.as_posix()}/") or not relative.endswith(".swift"):
            continue
        path = repo / relative
        if not path.is_file():
            continue
        for number, text in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = PUBLIC_DECLARATION.match(text)
            if match:
                findings.append(f"{relative}:{number} — {match.group(1)} `{match.group(2)}`")
    return findings


def resource_methods(repo: Path, docs_text: str) -> list[str]:
    findings: list[str] = []
    source_root = repo / PUBLIC_SOURCE_REL
    candidates = sorted(source_root.rglob("*Resource.swift"))
    client = source_root / "Core/JanuaryPartnerClient.swift"
    if client.is_file():
        candidates.append(client)

    for path in candidates:
        relative = path.relative_to(repo).as_posix()
        for number, text in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = PUBLIC_METHOD.match(text)
            if not match:
                continue
            method = match.group(1)
            mention = "mentioned" if re.search(rf"\b{re.escape(method)}\b", docs_text) else "review"
            findings.append(f"{relative}:{number} — `{method}(…)` — {mention} in docs")
    return findings


def package_facts(repo: Path) -> list[str]:
    package = repo / "Package.swift"
    if not package.is_file():
        return ["Package.swift is missing"]
    text = package.read_text(encoding="utf-8")
    facts: list[str] = []
    tools = re.search(r"swift-tools-version:\s*([^\s]+)", text)
    if tools:
        facts.append(f"Swift tools version: `{tools.group(1)}`")
    for platform, version in re.findall(r"\.(iOS|macOS|tvOS|watchOS)\(\.v(\d+)\)", text):
        facts.append(f"{platform}: `{version}+`")
    tags = git(repo, "tag", "--sort=-version:refname", check=False).splitlines()[:5]
    facts.append("Recent tags: " + (", ".join(f"`{tag}`" for tag in tags) if tags else "none"))
    return facts


def markdown_state(repo: Path) -> tuple[list[Path], list[str], list[str]]:
    docs_root = repo / DOCS_REL
    pages = sorted(docs_root.rglob("*.md")) if docs_root.is_dir() else []
    broken: list[str] = []

    for page in pages:
        text = page.read_text(encoding="utf-8")
        for raw_target in MARKDOWN_LINK.findall(text):
            target = raw_target.strip().split()[0].strip("<>")
            if not target or target.startswith(("#", "http://", "https://", "mailto:")):
                continue
            target_path = unquote(target.split("#", 1)[0])
            if not target_path:
                continue
            resolved = (page.parent / target_path).resolve()
            if not resolved.exists():
                broken.append(f"{page.relative_to(repo)} → {target}")

    summary = docs_root / "SUMMARY.md"
    listed: set[Path] = set()
    if summary.is_file():
        for target in SUMMARY_LINK.findall(summary.read_text(encoding="utf-8")):
            listed.add((summary.parent / unquote(target)).resolve())

    unlisted = [
        page.relative_to(repo).as_posix()
        for page in pages
        if page.name != "SUMMARY.md" and page.resolve() not in listed
    ]
    return pages, broken, unlisted


def print_section(title: str, items: list[str], empty: str) -> None:
    print(f"\n## {title}\n")
    if items:
        for item in items:
            print(f"- {item}")
    else:
        print(f"- {empty}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".", help="partner-sdk-ios repository root")
    parser.add_argument("--base-ref", help="explicit Git comparison base")
    parser.add_argument("--check", action="store_true", help="fail on broken or unlisted docs pages")
    args = parser.parse_args()

    repo = Path(args.repo_root).expanduser().resolve()
    if not git(repo, "rev-parse", "--git-dir", check=False):
        print(f"error: {repo} is not a Git repository", file=sys.stderr)
        return 2

    try:
        default_ref = remote_default(repo)
        branch = git(repo, "branch", "--show-current", check=False) or "detached HEAD"
        base = choose_base(repo, args.base_ref, default_ref, branch)
        base_commit = git(repo, "rev-parse", base)
        head_commit = git(repo, "rev-parse", "HEAD")
        default_commit = git(repo, "log", "-1", "--format=%H %ci", default_ref)
        all_changed = changed_files(repo, base)
        relevant_changed = [path for path in all_changed if relevant(path)]

        pages, broken, unlisted = markdown_state(repo)
        docs_text = "\n".join(page.read_text(encoding="utf-8") for page in pages)

        print("# SDK documentation audit packet")
        print(f"\n- Repository: `{repo}`")
        print(f"- Current branch: `{branch}`")
        print(f"- Remote default: `{default_ref}`")
        print(f"- Remote default commit: `{default_commit}`")
        print(f"- Comparison base: `{base}` → `{base_commit}`")
        print(f"- Current HEAD: `{head_commit}`")

        print_section("Relevant changed files", [f"`{path}`" for path in relevant_changed], "None")
        print_section(
            "Public declarations in changed SDK files",
            public_declarations(repo, relevant_changed),
            "No changed public Swift declarations detected; still review current resource methods below.",
        )
        print_section("Current public resource methods", resource_methods(repo, docs_text), "None found")
        print_section("Package and release facts", package_facts(repo), "No package facts found")
        print_section("GitBook pages", [f"`{page.relative_to(repo)}`" for page in pages], "No Markdown pages found")
        print_section("Broken local Markdown links", broken, "None")
        print_section("Pages missing from SUMMARY.md", [f"`{path}`" for path in unlisted], "None")

        if args.check and (broken or unlisted or not pages):
            return 1
        return 0
    except RuntimeError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
