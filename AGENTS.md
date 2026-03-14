# Agent Guidance

This repository is a personal CLI toolbox flake.

## Scope

- Keep this repo focused on reusable personal command-line tools.
- Do not move host configuration, machine setup, or Home Manager modules here unless explicitly requested.
- Prefer one cleanly packaged toolbox repo over many tiny single-tool repos.

## Packaging

- Export tools as flake packages via `packages.${system}.*`.
- Keep each tool under `pkgs/<tool>/` with a `default.nix` package definition.
- For nontrivial shell helpers, keep executable sources in separate files under the tool directory and package them explicitly.
- Prefer maintainable packaging over clever abstractions.

## Secrets and Local State

- Never commit secrets, tokens, credentials, or private data files.
- Keep runtime secrets in environment variables when a tool already expects that pattern.
- Keep operational state such as caches, ADEPT state, and personal wordlists outside the repo.
- Prefer XDG locations for user-managed data and caches when appropriate.

## Verification

- Match existing Nix style in this repo.
- Run `nix fmt` and relevant `nix flake check` or package builds before claiming success.
- Keep changes minimal and easy to understand.

## Git

- Follow Conventional Commits by default.
- Make atomic commits that match the requested step boundaries.
- Do not commit or push unless explicitly requested.
