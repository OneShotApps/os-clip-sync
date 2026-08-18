# Clip Sync Agent Instructions

These instructions apply to the entire repository.

## Product scope and YAGNI

- Follow YAGNI (You Aren't Gonna Need It) when deciding which features, abstractions, integrations, configuration options, and extension points to include.
- Implement only behavior required by the current approved product scope in `README.md` or by an explicit user request.
- Do not add speculative capabilities for possible future requirements.
- Prefer the smallest clear implementation that satisfies the current requirement and can be safely maintained.
- When a proposed change expands the approved scope, identify the expansion and obtain a product decision before implementing it.

## Delivery philosophy

- Follow a fail-forward, rolling-release, one-shot delivery philosophy.
- Do not delay a useful feature while attempting to answer every possible future question or edge case.
- Make reasonable, documented assumptions when they are safe and remain within the approved product scope.
- Deliver the smallest complete vertical slice that provides user value, validate it, and improve it in later releases as real needs become clear.
- Keep every change deployable. Do not accumulate large batches of unrelated, unfinished work before integration.
- When a deployed change fails, prefer a small corrective release that moves the application forward. Preserve enough diagnostics and version information to understand and correct the failure safely.
- A one-shot implementation should aim to leave the requested feature complete, documented, tested in proportion to its risk, and ready to deploy within the same task.
- Speed does not override security, privacy, data integrity, required validation, or the repository's documented standards.

## Briskhaven standards

- Use the `briskhaven-standards` skill before creating or changing repository structure, application architecture, source code, tests, scripts, configuration, or technical documentation.
- Read and apply the relevant current references provided by that skill; do not rely on remembered versions of the standards.
- Keep the repository structure and source code aligned with those standards unless a project-specific requirement explicitly takes priority.
- If a project requirement conflicts with a Briskhaven standard, do not silently choose one. Explain the conflict, follow the decision priority defined by the skill, and document any approved deviation.
- Apply standards in proportion to the current one-shot/MVP stage. Do not introduce deferred production complexity solely because a production standard exists.

## Application and package structure

- Create every application in its own self-contained folder beneath the repository-root `apps/` folder.
- Create every package in its own self-contained folder beneath the repository-root `packages/` folder.
- Keep each application's or package's source code, manifest, tests, configuration, Dockerfile, and package-specific documentation inside its folder whenever those files are required.
- Do not create applications or packages directly at the repository root.

## Database and API design

- Use the `database-designer` skill before designing or changing database schemas, persisted data models, relationships, indexes, API data contracts, or related data-layer artifacts.
- Also use `database-designer` when reviewing or correcting an existing schema or API-facing persistence design.
- Use the skill's required workflow and read its relevant source-of-truth references before producing a design.
- Skill Miser currently targets MongoDB. Use the Database Designer skill to guide requirements analysis, entity and relationship discovery, constraints, indexing, and review, but do not mechanically apply relational-only conventions to MongoDB.
- For MongoDB decisions, also use the relevant MongoDB and data-layer references from the `briskhaven-standards` skill. Surface any conflict or ambiguity before implementation.
- Keep persisted schemas and API contracts documented and synchronized with their implementation as required by the applicable Briskhaven standards.

## Docker Compose deployment

- Deploy the complete Skill Miser stack with Docker Compose on a single large Amazon Elastic Compute Cloud (EC2) host.
- Once the application stack exists, maintain these root-level Compose files:
  - `compose.local.yaml` for local development.
  - `compose.dev.yaml` for the shared development environment.
  - `compose.prod.yaml` for production.
- Each Compose file must be able to start the full stack required for its environment, including the web application, APIs, workers, MongoDB, and any other required service introduced into the approved scope.
- Keep service names, networks, health checks, dependency behavior, and container interfaces consistent across environments. Limit differences to configuration that genuinely varies by environment.
- Each deployable application must own an appropriate Dockerfile.
- Use `docker compose`, not the deprecated `docker-compose` command.
- Do not add the obsolete top-level `version` field to Compose files.
- Never commit real credentials, tokens, private keys, or production secrets. Inject sensitive values through the deployment environment or an approved secret store.
- Validate all required environment variables at startup and fail with a clear message when configuration is missing or invalid.
- Document the exact commands for building, starting, validating, troubleshooting, and stopping each environment.
- A feature that changes runtime dependencies, configuration, ports, or services is not complete until all affected Compose environments and deployment documentation are updated and validated.

## AI Git workflow

- Any single AI task that creates or modifies two or more repository files must finish by staging, committing, and pushing the task's changes.
- Inspect `git status` and the relevant diffs before staging. Stage only files changed for the current task; never include unrelated user or agent changes.
- Run the relevant validation before committing. Do not commit known failing work unless the user explicitly requests a checkpoint commit and the failure is clearly documented.
- Use an appropriate Conventional Commit message, such as `feat: add skill import`, `fix: preserve skill version history`, or `docs: clarify deployment workflow`.
- Push the new commit to the current branch's configured upstream after the commit succeeds.
- Never amend an existing commit, force-push, create a remote, or guess a destination branch to satisfy this rule.
- If staging, committing, or pushing cannot be completed safely because of missing Git identity, missing upstream configuration, authentication failure, branch protection, merge conflicts, or unrelated overlapping changes, stop and clearly report the blocker. Do not bypass repository protections.
- Report the commit identifier and push result when handing the task back to the user.

## Junior-developer readability

- Write all documentation and source code so a junior developer can understand, run, debug, and safely change it.
- Use direct language, descriptive names, small focused modules, and straightforward control flow.
- Define acronyms and domain-specific terms on first use.
- Explain the reason behind non-obvious decisions, validation rules, security boundaries, and constraints.
- Document prerequisites, configuration, commands, expected outcomes, and common failure cases.
- Avoid clever code, hidden behavior, unexplained conventions, premature abstractions, and unnecessary indirection.
- Add JSDoc and other code-level documentation where required by the Briskhaven standards, especially for shared interfaces and functions used across files.
- Keep examples accurate and runnable whenever practical.

## Required pre-change check

Before making a material change:

1. Confirm that the change is required by the current product scope.
2. Use `briskhaven-standards` and read the references relevant to the change.
3. If the change concerns a database, API contract, or data layer, also use `database-designer` and reconcile its guidance with the selected datastore.
4. Choose the simplest compliant approach a junior developer can maintain.
5. Update affected documentation in the same change.

After making a material change:

1. Run validation appropriate to the change.
2. Confirm that Docker Compose definitions and deployment documentation remain accurate when runtime behavior changed.
3. If two or more files were created or modified, follow the required AI Git workflow and push the resulting commit.
